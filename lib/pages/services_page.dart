import 'package:flutter/material.dart';

import '../services/api_client.dart';
import '../services/staff_service.dart';
import 'service_requests_page.dart' show buildPhotoUrl;

class ServiceInfo {
  final String title;
  final String subtitle;
  final IconData icon;
  final String staffName;
  final String phone;
  final String hours;
  final bool available;
  final String description;
  final List<String> categories;

  const ServiceInfo({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.staffName,
    required this.phone,
    required this.hours,
    required this.available,
    required this.description,
    required this.categories,
  });
}

/// UI-метаданные служб ЖК, индексированы по `specialty` сотрудника.
/// Живые данные (ФИО, телефон, часы, описание) подтягиваются из API `/staff`.
class _SpecialtyMeta {
  final String title;
  final String subtitle;
  final IconData icon;
  final List<String> categories;
  final String fallbackDescription;
  const _SpecialtyMeta({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.categories,
    required this.fallbackDescription,
  });
}

const Map<String, _SpecialtyMeta> _kSpecialtyMeta = {
  'plumbing': _SpecialtyMeta(
    title: 'Сантехник',
    subtitle: 'Протечки, краны, трубы',
    icon: Icons.plumbing_outlined,
    categories: ['Протечка'],
    fallbackDescription:
        'Устранение протечек, ремонт и замена кранов, труб и сантехнических приборов.',
  ),
  'electrical': _SpecialtyMeta(
    title: 'Электрик',
    subtitle: 'Розетки, освещение, автоматы',
    icon: Icons.electrical_services_outlined,
    categories: ['Электричество', 'Освещение'],
    fallbackDescription:
        'Монтаж и ремонт электропроводки, розеток, выключателей и осветительных приборов.',
  ),
  'cleaning': _SpecialtyMeta(
    title: 'Уборка',
    subtitle: 'Подъезд / двор / после ремонта',
    icon: Icons.cleaning_services_outlined,
    categories: ['Уборка'],
    fallbackDescription:
        'Уборка подъездов, придомовой территории и мест общего пользования.',
  ),
  'garbage': _SpecialtyMeta(
    title: 'Вывоз мусора',
    subtitle: 'Мусор, мебель, стройматериалы',
    icon: Icons.local_shipping_outlined,
    categories: ['Другое'],
    fallbackDescription:
        'Вывоз крупногабаритного мусора, старой мебели и строительных отходов.',
  ),
  'intercom': _SpecialtyMeta(
    title: 'Домофон',
    subtitle: 'Ключи, доступ, трубка',
    icon: Icons.door_front_door_outlined,
    categories: ['Домофон'],
    fallbackDescription:
        'Ремонт домофонного оборудования, изготовление дубликатов ключей и карт доступа.',
  ),
  'elevator': _SpecialtyMeta(
    title: 'Ремонт лифтов',
    subtitle: 'Техническое обслуживание',
    icon: Icons.elevator_outlined,
    categories: ['Лифт'],
    fallbackDescription:
        'Плановое техническое обслуживание и аварийный ремонт лифтового оборудования.',
  ),
  'security': _SpecialtyMeta(
    title: 'Охрана',
    subtitle: 'Вопросы безопасности',
    icon: Icons.security_outlined,
    categories: ['Паркинг'],
    fallbackDescription:
        'Контроль доступа на территорию ЖК, видеонаблюдение, реагирование на вызовы.',
  ),
};

ServiceInfo _buildServiceInfo(_SpecialtyMeta meta, StaffMember? staff) {
  if (staff == null) {
    return ServiceInfo(
      title: meta.title,
      subtitle: meta.subtitle,
      icon: meta.icon,
      staffName: 'Сотрудник не назначен',
      phone: '—',
      hours: '—',
      available: false,
      description: meta.fallbackDescription,
      categories: meta.categories,
    );
  }
  return ServiceInfo(
    title: meta.title,
    subtitle: meta.subtitle,
    icon: meta.icon,
    staffName: staff.fullName,
    phone: staff.phone.isEmpty ? '—' : staff.phone,
    hours: staff.workSchedule.isEmpty ? '—' : staff.workSchedule,
    available: staff.isAvailable,
    description: staff.description.isEmpty
        ? meta.fallbackDescription
        : staff.description,
    categories: meta.categories,
  );
}

class ServicesPage extends StatefulWidget {
  const ServicesPage({super.key});

  @override
  State<ServicesPage> createState() => _ServicesPageState();
}

class _ServicesPageState extends State<ServicesPage> {
  bool _loading = true;
  String? _error;
  List<ServiceInfo> _services = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  late Map<String, List<StaffMember>> _staffBySpecialty = {};

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final staff = await StaffService.instance.getStaff();
      // Группируем всех сотрудников по специальности.
      final bySpecialty = <String, List<StaffMember>>{};
      for (final s in staff) {
        bySpecialty.putIfAbsent(s.specialty, () => []).add(s);
      }
      _staffBySpecialty = bySpecialty;

      final services = <ServiceInfo>[];
      _kSpecialtyMeta.forEach((specialty, meta) {
        // Берём первого сотрудника для отображения в карточке
        final staffList = bySpecialty[specialty];
        final firstStaff = staffList?.isNotEmpty == true ? staffList!.first : null;
        services.add(_buildServiceInfo(meta, firstStaff));
      });
      if (!mounted) return;
      setState(() {
        _services = services;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      // Fallback: показываем все специальности как «не назначен», чтобы UI не пустовал.
      final services = <ServiceInfo>[];
      _kSpecialtyMeta.forEach((_, meta) {
        services.add(_buildServiceInfo(meta, null));
      });
      setState(() {
        _services = services;
        _error = 'Не удалось загрузить сотрудников: $e';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Сервисы')),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text('Службы ЖК',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 10),
              if (_loading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 32),
                  child: Center(child: CircularProgressIndicator()),
                )
              else ...[
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Card(
                      color: Colors.orange.withValues(alpha: 0.12),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Text(
                          _error!,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                    ),
                  ),
                ..._services.map(
                  (s) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Card(
                      child: ListTile(
                        leading: Icon(s.icon),
                        title: Text(s.title),
                        subtitle: Text(s.subtitle),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: s.available ? Colors.green : Colors.grey,
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Icon(Icons.chevron_right),
                          ],
                        ),
                        onTap: () {
                          final specialty = _kSpecialtyMeta.entries
                              .firstWhere(
                                (e) => e.value.title == s.title,
                                orElse: () =>
                                    const MapEntry('', _SpecialtyMeta(
                                      title: '',
                                      subtitle: '',
                                      icon: Icons.help,
                                      categories: [],
                                      fallbackDescription: '',
                                    )),
                              )
                              .key;
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ServiceDetailPage(
                                service: s,
                                staffList: specialty.isNotEmpty
                                    ? _staffBySpecialty[specialty]
                                    : null,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Детальная страница службы: информация о сотруднике + заявки по категории.
// ─────────────────────────────────────────────────────────────────────────────

class ServiceDetailPage extends StatefulWidget {
  final ServiceInfo service;
  final List<StaffMember>? staffList;

  const ServiceDetailPage({
    super.key,
    required this.service,
    this.staffList,
  });

  @override
  State<ServiceDetailPage> createState() => _ServiceDetailPageState();
}

class _ServiceDetailPageState extends State<ServiceDetailPage> {
  final ApiClient _api = ApiClient.instance;

  bool get _isAdmin => _api.userRole == 'admin';

  bool _loading = true;
  String? _error;
  List<_SvcRequest> _requests = [];
  String? _selectedStaffId;

  @override
  void initState() {
    super.initState();
    _initializeSelectedStaff();
    _load();
  }

  void _initializeSelectedStaff() {
    final staffList = widget.staffList;
    if (staffList != null && staffList.isNotEmpty) {
      _selectedStaffId = staffList.first.id;
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      if (!_api.isLoggedIn) {
        setState(() {
          _requests = [];
          _loading = false;
        });
        return;
      }
      final res = await _api.get('/service-requests');
      final all = (res.data as List)
          .map((r) => _SvcRequest.fromMap(Map<String, dynamic>.from(r as Map)))
          .toList();

      var filtered = all;

      // Filter by category if available
      final cats = widget.service.categories;
      if (cats.isNotEmpty) {
        filtered = filtered.where((r) => cats.contains(r.category)).toList();
      }

      // Filter by selected staff member if multiple staff members for this specialty
      if (widget.staffList != null && widget.staffList!.length > 1 && _selectedStaffId != null) {
        filtered = filtered.where((r) => r.assignedTo == _selectedStaffId).toList();
      }

      filtered.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      if (!mounted) return;
      setState(() {
        _requests = filtered;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Ошибка загрузки заявок: $e';
        _loading = false;
      });
    }
  }

  Future<void> _changeStatus(_SvcRequest req, String status) async {
    try {
      await _api.put('/service-requests/${req.id}', data: {'status': status});
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Статус обновлён')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.service;
    final staffList = widget.staffList ?? [];
    final hasMultipleStaff = staffList.length > 1;

    StaffMember? selectedStaff;
    if (hasMultipleStaff && _selectedStaffId != null) {
      selectedStaff = staffList.firstWhere(
        (staff) => staff.id == _selectedStaffId,
        orElse: () => staffList.first,
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(s.title)),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // ── Выбор сотрудника (если их несколько) ─────────────────────
              if (hasMultipleStaff) ...[
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: staffList.map((staff) {
                      final isSelected = _selectedStaffId == staff.id;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: FilterChip(
                          selected: isSelected,
                          label: Text(staff.fullName),
                          onSelected: (_) {
                            setState(() {
                              _selectedStaffId = staff.id;
                            });
                            _load();
                          },
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 16),
              ],
              // ── Карточка сотрудника ─────────────────────────────────────
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Theme.of(context)
                                  .colorScheme
                                  .primaryContainer,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(s.icon,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onPrimaryContainer),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  hasMultipleStaff && selectedStaff != null
                                      ? selectedStaff.fullName
                                      : s.staffName,
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium,
                                ),
                                const SizedBox(height: 2),
                                Row(
                                  children: [
                                    Container(
                                      width: 8,
                                      height: 8,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: (selectedStaff?.isAvailable ??
                                                s.available)
                                            ? Colors.green
                                            : Colors.grey,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      (selectedStaff?.isAvailable ??
                                              s.available)
                                          ? 'Доступен'
                                          : 'Недоступен',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                            color: (selectedStaff
                                                        ?.isAvailable ??
                                                    s.available)
                                                ? Colors.green
                                                : Colors.grey,
                                          ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      _InfoRow(
                        icon: Icons.phone_outlined,
                        text: selectedStaff?.phone.isEmpty ?? true
                            ? '—'
                            : selectedStaff!.phone,
                      ),
                      const SizedBox(height: 8),
                      _InfoRow(
                        icon: Icons.access_time_outlined,
                        text: selectedStaff?.workSchedule.isEmpty ?? true
                            ? '—'
                            : selectedStaff!.workSchedule,
                      ),
                      const SizedBox(height: 8),
                      _InfoRow(
                        icon: Icons.info_outline,
                        text: selectedStaff?.description.isEmpty ?? true
                            ? s.description
                            : selectedStaff!.description,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                widget.service.categories.isEmpty
                    ? 'Все заявки'
                    : 'Заявки: ${widget.service.categories.join(', ')}',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 10),
              if (_loading)
                const Center(
                    child: Padding(
                        padding: EdgeInsets.all(24),
                        child: CircularProgressIndicator()))
              else if (_error != null)
                _ErrorCard(message: _error!, onRetry: _load)
              else if (_requests.isEmpty)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      'Заявок по этой теме пока нет',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                )
              else
                ..._requests.map(
                  (r) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _SvcRequestCard(
                      request: r,
                      isAdmin: _isAdmin,
                      onStatusChanged: (status) => _changeStatus(r, status),
                    ),
                  ),
                ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String text;

  const _InfoRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: Theme.of(context).colorScheme.onSurfaceVariant),
        const SizedBox(width: 8),
        Expanded(
          child: Text(text, style: Theme.of(context).textTheme.bodyMedium),
        ),
      ],
    );
  }
}

class _SvcRequest {
  final String id;
  final String category;
  final String description;
  final String status;
  final DateTime createdAt;
  final List<String> photos;
  final String? assignedTo;

  const _SvcRequest({
    required this.id,
    required this.category,
    required this.description,
    required this.status,
    required this.createdAt,
    required this.photos,
    this.assignedTo,
  });

  factory _SvcRequest.fromMap(Map<String, dynamic> m) {
    final photosRaw = m['photos'];
    final photos = <String>[];
    if (photosRaw is List) {
      for (final p in photosRaw) {
        if (p != null) photos.add(p.toString());
      }
    }
    return _SvcRequest(
      id: (m['id'] ?? '').toString(),
      category: (m['category'] ?? '').toString(),
      description: (m['description'] ?? '').toString(),
      status: (m['status'] ?? 'new').toString(),
      createdAt: DateTime.tryParse((m['created_at'] ?? '').toString()) ??
          DateTime.now(),
      photos: photos,
      assignedTo: m['assigned_to'] as String?,
    );
  }
}

class _SvcRequestCard extends StatelessWidget {
  final _SvcRequest request;
  final bool isAdmin;
  final ValueChanged<String> onStatusChanged;

  const _SvcRequestCard({
    required this.request,
    required this.isAdmin,
    required this.onStatusChanged,
  });

  Color _statusColor(String s) {
    switch (s) {
      case 'done':
        return Colors.green;
      case 'in_progress':
        return Colors.orange;
      default:
        return Colors.blue;
    }
  }

  String _statusLabel(String s) => switch (s) {
        'new' => 'Новая',
        'in_progress' => 'В работе',
        'done' => 'Выполнено',
        _ => s,
      };

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(request.status);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    request.category,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _statusLabel(request.status),
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: color,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(request.description),
            const SizedBox(height: 8),
            Text(
              _formatDate(request.createdAt),
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (request.photos.isNotEmpty) ...[
              const SizedBox(height: 10),
              SizedBox(
                height: 80,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: request.photos.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (ctx, i) => ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.network(
                      buildPhotoUrl(request.photos[i]),
                      headers: ApiClient.instance.token != null
                          ? {
                              'Authorization':
                                  'Bearer ${ApiClient.instance.token}'
                            }
                          : null,
                      width: 80,
                      height: 80,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        width: 80,
                        height: 80,
                        color: Colors.grey.shade200,
                        alignment: Alignment.center,
                        child: const Icon(Icons.broken_image,
                            color: Colors.grey),
                      ),
                    ),
                  ),
                ),
              ),
            ],
            if (isAdmin) ...[
              const SizedBox(height: 10),
              PopupMenuButton<String>(
                tooltip: 'Изменить статус',
                onSelected: onStatusChanged,
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'new', child: Text('Новая')),
                  PopupMenuItem(
                      value: 'in_progress', child: Text('В работе')),
                  PopupMenuItem(value: 'done', child: Text('Выполнено')),
                ],
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.edit_outlined, size: 16),
                    const SizedBox(width: 6),
                    Text('Изменить статус',
                        style: Theme.of(context).textTheme.labelMedium),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  static String _formatDate(DateTime dt) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(dt.day)}.${two(dt.month)}.${dt.year}  ${two(dt.hour)}:${two(dt.minute)}';
  }
}

class _ErrorCard extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorCard({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(message),
            const SizedBox(height: 10),
            FilledButton.tonal(
                onPressed: onRetry, child: const Text('Повторить')),
          ],
        ),
      ),
    );
  }
}
