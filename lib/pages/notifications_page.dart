import 'dart:async';

import 'package:flutter/material.dart';
import '../models/notification_item.dart';
import '../services/api_client.dart';
import '../services/notification_center_service.dart';
import '../services/notifications_service.dart';
import 'news_page.dart';
import 'service_requests_page.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  late final NotificationCenterService _svc;
  List<NotificationItem> _items = [];
  bool _loading = true;
  StreamSubscription<Map<String, String>>? _reqSub;
  StreamSubscription<Map<String, String>>? _newsSub;

  @override
  void initState() {
    super.initState();
    _svc = NotificationCenterService(ApiClient.instance);
    _load();
    _reqSub = NotificationsService.instance.serviceRequestEvents.listen((_) {
      if (mounted) _load();
    });
    _newsSub = NotificationsService.instance.newsEvents.listen((_) {
      if (mounted) _load();
    });
  }

  @override
  void dispose() {
    _reqSub?.cancel();
    _newsSub?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final items = await _svc.getNotifications();
      if (mounted) setState(() { _items = items; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _markAllRead() async {
    await _svc.markAllRead();
    await _load();
  }

  Future<void> _onTileTap(NotificationItem item) async {
    if (item.isUnread) {
      await _svc.markRead(item.id);
      await _load();
    }
    if (!mounted) return;
    final kind = item.kind;
    if (kind.startsWith('service_request_')) {
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const ServiceRequestsPage()),
      );
    } else if (kind == 'news_post') {
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const NewsPage()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final unread = _items.where((n) => n.isUnread).length;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Уведомления'),
        actions: [
          if (unread > 0)
            TextButton(
              onPressed: _markAllRead,
              child: const Text('Прочитать все'),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _items.isEmpty
              ? const Center(child: Text('Нет уведомлений'))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.separated(
                    itemCount: _items.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, i) {
                      final n = _items[i];
                      return _NotificationTile(
                        item: n,
                        onTap: () => _onTileTap(n),
                      );
                    },
                  ),
                ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  final NotificationItem item;
  final VoidCallback onTap;

  const _NotificationTile({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      child: Container(
        color: item.isUnread
            ? theme.colorScheme.primary.withOpacity(0.06)
            : null,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _KindIcon(
              kind: item.kind,
              threatType: item.data?['threat_type']?.toString(),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          item.title,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: item.isUnread
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                      ),
                      if (item.isUnread)
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary,
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(item.body, style: theme.textTheme.bodySmall),
                  const SizedBox(height: 4),
                  Text(
                    _formatTime(item.createdAt),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.outline,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'только что';
    if (diff.inHours < 1) return '${diff.inMinutes} мин назад';
    if (diff.inDays < 1) return '${diff.inHours} ч назад';
    return '${dt.day}.${dt.month.toString().padLeft(2, '0')} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}

class _KindIcon extends StatelessWidget {
  final String kind;
  final String? threatType;
  const _KindIcon({required this.kind, this.threatType});

  @override
  Widget build(BuildContext context) {
    IconData icon;
    Color color;
    switch (kind) {
      case 'unknown_vehicle':
        icon = Icons.no_crash;
        color = Colors.red;
      case 'guest_arrived':
        icon = Icons.person_add;
        color = Colors.green;
      case 'parking_alert':
        icon = Icons.local_parking;
        color = Colors.orange;
      case 'parking_no_permit':
        icon = Icons.no_meeting_room;
        color = Colors.red;
      case 'parking_spot_freed':
        icon = Icons.local_parking;
        color = Colors.blue;
      case 'sensor_alert':
        final t = threatType?.toUpperCase() ?? '';
        if (t == 'FIRE' || t == 'SMOKE') {
          icon = Icons.local_fire_department;
          color = Colors.deepOrange;
        } else if (t == 'WATER_LEAK' || t == 'WATER') {
          icon = Icons.water_drop;
          color = Colors.blue;
        } else {
          icon = Icons.warning_amber;
          color = Colors.orange;
        }
      case 'sensor_offline':
        icon = Icons.wifi_off;
        color = Colors.grey;
      case 'service_request_new':
        icon = Icons.assignment_outlined;
        color = Colors.blue;
      case 'service_request_taken':
        icon = Icons.engineering_outlined;
        color = Colors.orange;
      case 'service_request_assigned':
        icon = Icons.assignment_ind_outlined;
        color = Colors.deepPurple;
      case 'service_request_done':
        icon = Icons.task_alt;
        color = Colors.green;
      case 'service_request_rejected':
        icon = Icons.cancel_outlined;
        color = Colors.red;
      case 'news_post':
        icon = Icons.campaign_outlined;
        color = Colors.teal;
      default:
        icon = Icons.notifications;
        color = Colors.blue;
    }
    return CircleAvatar(
      radius: 20,
      backgroundColor: color.withOpacity(0.15),
      child: Icon(icon, color: color, size: 20),
    );
  }
}
