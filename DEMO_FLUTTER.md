# DEMO_FLUTTER.md — SmartResidency, клиентская часть
> Защита диплома. Читать с телефона. Без воды.

---

## 1. Архитектура Flutter-приложения

### Структура `lib/`
```
lib/
├── core/           # AppState (legacy demo-state)
├── models/         # Sensor, BarrierEvent, ParkingSpot, …
├── services/       # Вся бизнес-логика: API, FCM, SSE, Auth
├── pages/          # Экраны (20+)
├── widgets/        # Переиспользуемые виджеты (сенсор-карточки, шит заявки)
├── theme/          # AppTheme (light + dark)
└── main.dart       # Точка входа: Firebase init, FCM, runApp
```

### Ключевые пакеты и зачем они
| Пакет | Зачем |
|---|---|
| `dio ^5.4.0` | HTTP-клиент с interceptor (подставляет JWT в каждый запрос) |
| `shared_preferences ^2.2.2` | Хранение JWT-токена, user_id, роли между сессиями |
| `firebase_messaging ^15.1.3` | Push-уведомления от FCM (датчики, шлагбаум, парковка) |
| `flutter_local_notifications ^17.2.3` | Показывает Android-уведомление когда приложение открыто |
| `flutter_client_sse ^2.0.3` | Живая подписка на SSE-поток от Go-бэка (сетка датчиков для Админа) |
| `image_picker ^1.1.2` | Выбор фото из камеры/галереи (заявки в УК) |
| `file_picker ^8.1.6` | Выбор PDF/JPG документов (верификация собственника) |
| `provider ^6.1.1` | State-management |
| `google_maps_flutter ^2.5.0` | Карта ЖК |

### Сервисы-синглтоны
```
ApiClient       — Dio-обёртка, хранит токен
AuthService     — login / register / logout / refreshToken
NotificationsService — FCM + flutter_local_notifications
SseService      — SSE-стрим датчиков для Админа
SensorService   — REST-запросы сенсоров + привязка к SSE
BarrierService  — шлагбаум
ParkingService  — парковка
```

---

## 2. Push-уведомления — FCM

### Инициализация (main.dart)
```dart
await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
FirebaseMessaging.onBackgroundMessage(firebaseBackgroundHandler);
await NotificationsService.instance.init();
```

### Background handler (notifications_service.dart)
```dart
@pragma('vm:entry-point')
Future<void> firebaseBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(...);
  await NotificationsService._showFromData(message.data);
}
```
`@pragma('vm:entry-point')` — обязательно, иначе Dart-компилятор вырежет функцию.  
Запускается в **отдельном изоляте**, UI недоступен — только показ уведомления.

### Когда приложение открыто — onMessage
```dart
FirebaseMessaging.onMessage.listen((RemoteMessage msg) async {
  await _showFromData(msg.data);   // показываем local notification
  _emitIfSensorAlert(msg.data);    // обновляем стрим сенсоров
});
```

### Типы payload
| `kind` | Событие |
|---|---|
| `sensor_alert` | Датчик воды / дыма |
| `unknown_vehicle` | Незнакомая машина у шлагбаума |
| `guest_arrived` | Гость вошёл в ЖК |
| `parking_alert` / `parking_spot_freed` | Парковка |

### Навигация по тапу на пуш
При тапе срабатывает `onMessageOpenedApp` (или `getInitialMessage` при холодном старте):
```dart
// Сохраняем event_id в SharedPreferences
prefs.setString('pending_notification_event_id', eventId);
// DashboardPage при загрузке читает ключ и открывает SensorEventDetailPage
```
Пользователь видит пуш → тапает → приложение открывается на **экране с таймлайном события**.

### FCM-токен и бэк
После логина: `POST /users/me/fcm-token {token, platform: "android"}`.  
При ротации токена: `FirebaseMessaging.instance.onTokenRefresh` — автосинхронизация.  
При логауте: `POST /users/me/fcm-token/delete`.

---

## 3. SSE — живые обновления сетки датчиков

### Пакет
`flutter_client_sse ^2.0.3` — `SSEClient.subscribeToSSE()`

### Подключение (sse_service.dart)
```dart
final url = '${ApiClient.baseHost}/api/v1/admin/sensors/stream?token=$token';
_sub = SSEClient.subscribeToSSE(
  method: SSERequestType.GET,
  url: url,
  header: const {},
).listen(_onFrame, onError: _onError, onDone: _onDone);
```
Токен передаётся **в URL** (SSE не поддерживает заголовки в браузере, сделали единообразно).

### Типы SSE-событий
| event | Что происходит в UI |
|---|---|
| `sensor_update` | Карточка датчика меняет цвет (NORMAL→ALERT→OFFLINE) |
| `sensor_offline` | Иконка датчика становится серой |
| `event_new` | В список событий добавляется новая строка |
| `event_status` | Статус события в таймлайне обновляется |

### Переподключение
Экспоненциальный backoff: 2 → 5 → 10 → 30 секунд.

### Как обновляется UI без перезагрузки
`SseService` → парсит фрейм → кладёт в `SensorService.sensorsStream` (StreamController) → `AdminSensorsPage` слушает стрим через `StreamBuilder` → Flutter перерисовывает только изменившуюся карточку.

---

## 4. Авторизация — JWT в Flutter

### Хранение токена
```dart
// Сохранение (после login/register)
await _prefs.setString('token', token);
await _prefs.setString('user_id', userId);
await _prefs.setString('user_role', role);  // resident / admin / staff / guard

// Чтение
_prefs.getString('token')
```
**SharedPreferences** — персистентное key-value хранилище Android. Токен сохраняется между перезапусками.

### Interceptor Dio — автоматическая подстановка JWT
```dart
_dio.interceptors.add(InterceptorsWrapper(
  onRequest: (options, handler) {
    final token = _prefs.getString('token');
    if (token != null) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  },
));
```
Программист **не думает** про токен при каждом запросе — interceptor добавляет его всегда.

### При 401
Токен просрочен → вызываем `POST /auth/refresh` → если бэк вернул новый токен, сохраняем и повторяем запрос. Если refresh тоже упал — `AuthService.logout()` → редирект на `LoginPage`.

### Базовый URL
```dart
static const _host = String.fromEnvironment('SERVER_HOST',
    defaultValue: '192.168.1.84');
static String get baseUrl => 'http://$_host:8080/api/v1';
```
IP задаётся при сборке: `flutter run --dart-define=SERVER_HOST=192.168.1.84`.

---

## 5. Загрузка файлов — multipart/form-data

### Фото к заявке в УК (create_request_sheet.dart)
```dart
// 1. Создаём заявку (JSON)
final res = await _api.post('/service-requests', data: {
  'category': _selected,
  'description': _desc.text.trim(),
});
final requestId = res.data['id'] as String;

// 2. Загружаем каждое фото отдельным multipart-запросом
for (final photo in _photos) {
  final formData = FormData.fromMap({
    'photo': await MultipartFile.fromFile(photo.path, filename: photo.name),
  });
  await _api.postForm('/service-requests/$requestId/photos', formData);
}
```
**image_picker** даёт путь к файлу → `MultipartFile.fromFile` читает байты → Dio кодирует в `multipart/form-data`.

### Документы верификации собственника (auth_service.dart)
```dart
final formData = FormData();
for (final doc in documents) {
  formData.files.add(MapEntry(
    'documents',
    await MultipartFile.fromFile(doc.path!, filename: doc.name),
  ));
}
await _api.postForm('/verification/requests/$verId/documents', formData);
```
Несколько файлов (PDF / JPG) → одним запросом.

---

## 6. Экраны на защите — что показывать

| Экран | Файл | Роль | Что показать |
|---|---|---|---|
| **Сетка датчиков** | `admin_sensors_page.dart` | Админ | Вкладки по подъездам, живое обновление через SSE, карточки NORMAL/ALERT/OFFLINE |
| **Таймлайн события** | `sensor_event_detail_page.dart` | Оба | DETECTED→CHECKING→CONFIRMED, кнопки Админа, комментарий |
| **Список заявок** | `service_requests_page.dart` | Оба | Статусы, фото, фильтры |
| **Создание заявки** | `create_request_sheet.dart` | Житель | Bottom-sheet: категория + описание + фото |
| **Верификация** | `ownership_verification_page.dart` | Житель | Загрузка документов, адрес |
| **Адм. верификация** | `admin_verification_page.dart` | Админ | PDF-документы, кнопки Approve/Reject |
| **Профиль** | `profile_page.dart` | Оба | Роль, статус верификации |
| **Шлагбаум** | `barrier_page.dart` | Оба | История въездов/выездов, неизвестные авто |
| **Push история** | `notifications_history_page.dart` | Оба | Все пришедшие пуши из SharedPreferences |

### Навигация
Нет named routes — только `Navigator.push(MaterialPageRoute(...))`.  
`DashboardPage` — главная оболочка с `BottomNavigationBar`, количество вкладок зависит от роли.

---

## 7. Сценарий демо со стороны Flutter

### Подготовка (до выхода к доске)
- Эмулятор / реальный Android запущен, приложение открыто
- Зайти под **Администратором** → вкладка «Датчики»
- Второй телефон / браузер — под **Жителем**

---

### Шаг 1 — Сетка датчиков (Админ)
**Говорить:** «Это экран администратора. Каждая карточка — реальный IoT-датчик. Статус обновляется в реальном времени через SSE-поток без перезагрузки страницы.»

Показать: вкладки «Подъезд 1 / 2 / 3», карточки с иконкой воды/дыма.

---

### Шаг 2 — Триггер тревоги (из Node-RED или Swagger)
Бэк-коллега публикует MQTT-сообщение → датчик уходит в ALERT.

**Что видит Админ:** карточка краснеет (SSE `sensor_update`), счётчик alert растёт.  
**Что видит Житель:** на телефон приходит пуш «Обнаружена протечка — Подъезд 1, этаж 3».

**Говорить:** «Без единого перезапроса — Go-сервер рассылает SSE-событие всем подключённым клиентам. Параллельно FCM доставляет пуш на телефон Жителя.»

---

### Шаг 3 — Тап на пуш (Житель)
Житель тапает на пуш-уведомление.

**Что происходит:** `onMessageOpenedApp` читает `event_id` из payload → сохраняет в SharedPreferences → `DashboardPage` открывает `SensorEventDetailPage`.

**Говорить:** «Тап на уведомление открывает именно то событие — через event_id в payload пуша. Вижу таймлайн: DETECTED с временем обнаружения.»

---

### Шаг 4 — Таймлайн события
Показать: хронология DETECTED → CHECKING → CONFIRMED/FALSE_ALARM с временными метками.

**Говорить:** «Каждый шаг подписан: кто изменил статус, когда, с каким комментарием. Тип угрозы — протечка или пожар.»

Если демо делает Админ: нажать «На проверке» → «Подтвердить» → ввести тип угрозы → «Отправить».  
Состояние сразу меняется через повторный запрос к API.

---

### Шаг 5 — Создание заявки с фото (Житель)
Перейти: Услуги → «+» → `CreateRequestSheet` (bottom-sheet).

1. Выбрать категорию (сантехника / электрика / …)
2. Написать описание
3. Нажать «Добавить фото» → выбрать из галереи
4. «Отправить»

**Говорить:** «Сначала создаётся заявка (JSON POST), получаем ID, потом каждое фото отправляется отдельным multipart-запросом. Это стандарт — форма и медиафайлы не смешиваются в одном запросе.»

---

### Шаг 6 — Верификация собственника
Показать `OwnershipVerificationPage`: выбрать тип документа, ввести адрес, прикрепить PDF.

**Говорить:** «Житель загружает правоустанавливающие документы. Администратор видит их в панели верификации, может открыть PDF прямо в приложении и одобрить или отклонить заявку.»

---

## 8. Вопросы комиссии — готовые ответы

**— Почему Flutter, а не React Native?**  
Flutter компилируется в нативный ARM-код без JavaScript-моста. Одна кодовая база — Android и iOS. Dart строго типизирован, виджеты рисуются через собственный движок Skia — единый рендеринг на всех устройствах. Для нашей задачи (сложный UI + WebSocket-подобный SSE + камера) Flutter дал лучшую производительность.

**— Как работает IP 192.168.1.84 — не 10.0.2.2?**  
`10.0.2.2` — это адрес хоста внутри AVD-эмулятора. Мы запускаем бэк на реальной машине в локальной сети, а Flutter-клиент — на реальном Android-телефоне. Реальный телефон видит сервер по обычному LAN-IP. IP задаётся при сборке через `--dart-define=SERVER_HOST=192.168.1.84`, не зашит в код.

**— Как Flutter знает, что пуш пришёл именно ему?**  
FCM доставляет пуш на конкретный FCM-токен устройства. Токен уникален для пары «приложение + устройство». Мы сохраняем его на бэке привязанным к `user_id` после логина. Когда бэк вызывает FCM API — он указывает именно этот токен.

**— Что такое google-services.json?**  
Файл конфигурации Firebase для Android. Содержит `project_id`, `api_key`, `app_id` (наш: `smart-residency-e3404`). Кладётся в `android/app/`, Gradle читает его при сборке и регистрирует приложение в Firebase. Без него FCM не работает.

**— Как хранится токен — безопасно ли?**  
SharedPreferences на Android хранит данные в XML-файле в приватной директории приложения (`/data/data/...`). Без root другие приложения не имеют доступа. Для production можно использовать `flutter_secure_storage` (Android Keystore), но для диплома SharedPreferences достаточно.

**— Почему SSE, а не WebSocket?**  
SSE — однонаправленный канал сервер→клиент. Для сетки датчиков нам нужно только получать обновления. SSE проще (обычный HTTP), хорошо работает через прокси и Firebase Hosting. WebSocket — двунаправленный, избыточен для этой задачи.

**— Как работает background handler изолированно?**  
`@pragma('vm:entry-point')` запрещает компилятору вырезать функцию. FCM запускает её в отдельном Dart-изоляте без доступа к UI. Поэтому мы инициализируем Firebase заново и показываем локальное уведомление через `FlutterLocalNotificationsPlugin` — этого достаточно без UI.

**— Где хранится история пушей?**  
В SharedPreferences, ключ `notifications_history`. Каждое уведомление сериализуется в JSON: `event_id`, `title`, `body`, `threat_type`, `received_at`. Экран `NotificationsHistoryPage` читает этот список.

---

## 9. Быстрая шпаргалка — цифры и факты Flutter

| | |
|---|---|
| Flutter SDK | Dart >=3.0.0 |
| Firebase Project | `smart-residency-e3404` |
| FCM Sender ID | `46403008307` |
| Бэк-порт | `8080` |
| Бэк-IP (LAN) | `192.168.1.84` |
| SSE endpoint | `GET /api/v1/admin/sensors/stream?token=…` |
| FCM-токен endpoint | `POST /api/v1/users/me/fcm-token` |
| SharedPrefs ключи | `token`, `user_id`, `user_role`, `notifications_history`, `pending_notification_event_id` |
| Экранов всего | 20+ |
| Ролей | `resident`, `admin`, `staff`, `guard` |
| SSE reconnect | 2 → 5 → 10 → 30 сек (backoff) |
| Local notification каналы | `sensor_alerts_v2`, `barrier_events_v2`, `parking_events_v2` |
| Multipart: фото заявки | `POST /service-requests/{id}/photos`, field: `photo` |
| Multipart: документы | `POST /verification/requests/{id}/documents`, field: `documents` |
