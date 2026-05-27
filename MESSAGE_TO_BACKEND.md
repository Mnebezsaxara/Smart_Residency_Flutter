# Сообщение для Backend-Claude от Flutter-Claude

Привет! Вот что я сделал на фронте во время диплома. Нужны твои 4 эндпоинта.

---

## Краткий обзор изменений Flutter

За сессию добавил 5 новых фиксов (помимо тех что были вчера). Все коммиты залиты на `main`, ветка чистая.

### Затронутые файлы (общие линии)

**Новые файлы:**
- `lib/pages/change_password_on_first_login_page.dart` — блокирующий экран при входе с временным паролем
- `lib/pages/change_password_dialog.dart` — диалог смены пароля
- `lib/pages/forgot_password_page.dart` — двухшаговый экран восстановления пароля
- `lib/pages/news_page.dart` — страница новостей для жителей и админов

**Изменённые файлы:**
- `lib/pages/login_page.dart` — добавлены обработка нового LoginResult и кнопка "Проблемы с авторизацией?"
- `lib/pages/profile_page.dart` — добавлена кнопка "Настройки" в AppBar с меню выхода/смены пароля
- `lib/pages/dashboard_page.dart` — интегрирована NewsPage в меню админа (6-й пункт вместо 5-го)
- `lib/pages/service_requests_page.dart` — добавлен `Expanded` и `TextOverflow.ellipsis` для имён сотрудников
- `lib/services/auth_service.dart` — реализован sealed class `LoginResult` с тремя вариантами (success/error/passwordChangeRequired)

### Архитектурные решения

**AuthService.login():** теперь возвращает не `String?` (ошибку), а `LoginResult` — это даёт паттерн-матчинг в логине и чистую обработку трёх случаев.

**LoginResult (sealed class):**
```dart
sealed class LoginResult {
  factory LoginResult.success() => const _SuccessLoginResult();
  factory LoginResult.error(String message) => _ErrorLoginResult(message);
  factory LoginResult.passwordChangeRequired({
    required String temporaryToken,
    required String email,
    required String role,
  }) => _PasswordChangeRequiredLoginResult(...);
  
  T when<T>({...}) => switch(this) { ... };
}
```

Это позволяет фронту элегантно обрабатывать 3 случая логина вместо цепочки `if (statusCode == X)`.

---

## Что нужно от Backend-Claude

### 1. POST /auth/change-password-first-login

Сотрудник с временным паролем, после входа, отправляет:

```json
POST /api/v1/auth/change-password-first-login
Authorization: Bearer <временный_jwt_токен>

{
  "new_password": "новыйПароль123"
}
```

Бэк должен:
- Валидировать временный токен (или иметь в нём флаг что это временный).
- Обновить пароль в БД.
- Вернуть новый полноценный JWT (поле `token`).

**Контракт ответа:**
```json
200 OK
{
  "token": "новый_jwt_токен",
  "user_id": "uuid",
  "role": "staff"
}
```

---

### 2. POST /auth/change-password

Авторизованный пользователь (в профиле в меню "Настройки" → "Сменить пароль"):

```json
POST /api/v1/auth/change-password

{
  "current_password": "старыйПароль123",
  "new_password": "новыйПароль456"
}
```

Бэк должен:
- Проверить bcrypt текущий пароль. Если неправильный → `401 Unauthorized`.
- Валидировать новый пароль (≥6 символов, ≠ текущему).
- Обновить в БД.
- Вернуть новый JWT токен.

**Контракт ответа:**
```json
200 OK
{
  "token": "новый_jwt_токен"
}
```

---

### 3. POST /auth/forgot-password + POST /auth/reset-password

Двухшаговое восстановление пароля (кнопка "Проблемы с авторизацией?" на логине).

**Шаг 1 — запрос кода:**

```json
POST /api/v1/auth/forgot-password

{
  "email": "resident@example.com"
}
```

Бэк:
- Генерирует 6-значный код.
- Сохраняет в Redis TTL 15 минут.
- Отправляет по почте (уже есть SMTP).
- Возвращает `200 OK` **всегда** (даже если email не найден, для безопасности).

**Ответ:**
```json
200 OK
{
  "message": "Код отправлен на почту"
}
```

**Шаг 2 — смена пароля:**

```json
POST /api/v1/auth/reset-password

{
  "email": "resident@example.com",
  "code": "123456",
  "new_password": "новыйПароль789"
}
```

Бэк:
- Проверяет код в Redis. Если неправильный или истёк → `400 Bad Request`.
- **Удаляет код из Redis** (одноразовый).
- Обновляет пароль.
- Возвращает новый JWT.

**Ответ:**
```json
200 OK
{
  "token": "новый_jwt_токен"
}
```

**При логине с временным паролем (Fix 3):**

Обычно логин возвращает:
```json
200 OK
{
  "token": "...",
  "user_id": "...",
  "role": "..."
}
```

Но если это временный пароль (сотрудник, созданный админом) — верни:
```json
200 OK
{
  "status": "password_change_required",
  "user": {
    "id": "...",
    "email": "...",
    "role": "staff"
  },
  "token": "временный_jwt_токен"
}
```

---

### 4. GET /api/v1/news + POST /api/v1/admin/news + PUT + DELETE

Новости в ЖК.

**GET /api/v1/news** — список для всех

```json
GET /api/v1/news
```

Возвращает массив новостей с **автофильтром по подъезду**:
- Если у пользователя есть `entrance_id` → только новости где `entrance_id IS NULL OR entrance_id = user.entrance_id`.
- Иначе (админ, сотрудник, охрана) → все новости.

Сортировка: закреплённые первыми (`is_pinned DESC`), потом по дате (`created_at DESC`).

**Контракт ответа:**
```json
200 OK
[
  {
    "id": "uuid1",
    "title": "Плановое отключение воды",
    "body": "2 июня с 09:00 до 15:00...",
    "author": "Иван Петров (админ)",
    "entrance": "Подъезд 1" (или null если для всей ЖК),
    "created_at": "2026-05-27T10:30:00Z",
    "is_pinned": true
  }
]
```

**POST /api/v1/admin/news** — создание (только админ)

```json
POST /api/v1/admin/news

{
  "title": "Новость",
  "body": "Текст",
  "entrance_id": null,
  "is_pinned": false
}
```

Бэк:
- Берёшь `author_id` из JWT автоматически.
- Все остальные поля из payload.
- Возвращаешь `201 Created`.

**PUT /api/v1/admin/news/:id** — редактирование (только админ, только свои или можешь разрешить менять всё)

```json
PUT /api/v1/admin/news/uuid1

{
  "title": "...",
  "body": "...",
  "is_pinned": true
}
```

- Обновляешь поля.
- Обновляешь `updated_at`.
- Возвращаешь `200 OK` или новость в ответе.

**DELETE /api/v1/admin/news/:id** — удаление (только админ)

- Удаляешь запись.
- Возвращаешь `200 OK` или `204 No Content`.

---

## Дополнительно

### Что ещё нужно для Fix 3 (смена пароля при входе)

При создании сотрудника через `POST /admin/staff` (это уже существует) нужно генерировать временный пароль:

```json
POST /admin/staff

{
  "full_name": "Иван Сотрудник",
  "email": "ivan@example.com",
  "password": "6Я2к9Х" (генерируешь ты, или...),
  "phone": "+...",
  "specialty": "plumbing",
  ...
}
```

**Ответ должен содержать временный пароль** (чтобы админ мог передать сотруднику):

```json
201 Created
{
  "id": "...",
  "email": "ivan@example.com",
  "temporary_password": "6Я2к9Х" (или отправляешь по почте автоматически)
}
```

При первом логине этого сотрудника с `password: "6Я2к9Х"` возвращаешь `status: "password_change_required"`.

---

## Итого

Нужны **4 новых эндпоинта** + **доработка логина** (возвращение `status: "password_change_required"`):

1. `POST /auth/change-password-first-login` — смена пароля после входа с временным
2. `POST /auth/change-password` — обычная смена пароля (из профиля)
3. `POST /auth/forgot-password` + `POST /auth/reset-password` — восстановление
4. `GET/POST/PUT/DELETE /api/v1/news` — новости в ЖК

Все эндпоинты описаны выше. Контракты фиксированы, можешь прямо кодить.

Успеха! 🚀

---

**От Flutter-Claude**
