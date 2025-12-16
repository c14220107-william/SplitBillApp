import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:splitbillapp/features/notifications/models/notification.dart' as app_notification;
import 'package:splitbillapp/features/notifications/providers/notification_providers.dart';

class NotificationsPage extends ConsumerWidget {
  const NotificationsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notificationsAsync = ref.watch(notificationsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.invalidate(notificationsProvider);
              ref.invalidate(unreadNotificationsCountProvider);
            },
            tooltip: 'Refresh',
          ),
          TextButton(
            onPressed: () async {
              final service = ref.read(notificationServiceProvider);
              await service.markAllAsRead();
              ref.invalidate(notificationsProvider);
              ref.invalidate(unreadNotificationsCountProvider);
            },
            child: const Text('Mark all read'),
          ),
        ],
      ),
      body: notificationsAsync.when(
        data: (notifications) {
          if (notifications.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.notifications_none, size: 80, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    'No notifications yet',
                    style: TextStyle(color: Colors.grey[600], fontSize: 16),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(notificationsProvider);
              ref.invalidate(unreadNotificationsCountProvider);
            },
            child: ListView.builder(
              itemCount: notifications.length,
              itemBuilder: (context, index) {
                final notification = notifications[index];
                return _NotificationCard(notification: notification);
              },
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 60, color: Colors.red),
              const SizedBox(height: 16),
              Text('Error: $error'),
            ],
          ),
        ),
      ),
    );
  }
}

class _NotificationCard extends ConsumerWidget {
  final app_notification.Notification notification;

  const _NotificationCard({required this.notification});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    IconData icon;
    Color iconColor;

    switch (notification.type) {
      case 'bill_finalized':
        icon = Icons.check_circle;
        iconColor = Colors.blue;
        break;
      case 'payment_received':
        icon = Icons.payments;
        iconColor = Colors.green;
        break;
      default:
        icon = Icons.info;
        iconColor = Colors.grey;
    }

    return Dismissible(
      key: Key(notification.id),
      direction: DismissDirection.endToStart,
      background: Container(
        color: Colors.red,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      onDismissed: (_) async {
        final service = ref.read(notificationServiceProvider);
        await service.deleteNotification(notification.id);
        ref.invalidate(notificationsProvider);
        ref.invalidate(unreadNotificationsCountProvider);
      },
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        color: notification.isRead ? null : Colors.blue.shade50,
        child: ListTile(
          leading: CircleAvatar(
            backgroundColor: iconColor.withOpacity(0.2),
            child: Icon(icon, color: iconColor, size: 24),
          ),
          title: Text(
            notification.title,
            style: TextStyle(
              fontWeight: notification.isRead ? FontWeight.normal : FontWeight.bold,
            ),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 4),
              Text(notification.message),
              const SizedBox(height: 4),
              Text(
                _formatTime(notification.createdAt),
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
            ],
          ),
          trailing: notification.relatedId != null
              ? const Icon(Icons.chevron_right)
              : null,
          onTap: () async {
            // Mark as read
            if (!notification.isRead) {
              final service = ref.read(notificationServiceProvider);
              await service.markAsRead(notification.id);
              ref.invalidate(notificationsProvider);
              ref.invalidate(unreadNotificationsCountProvider);
            }

            // Navigate to related content
            if (notification.relatedId != null && context.mounted) {
              if (notification.type == 'bill_finalized') {
                context.push('/bill/${notification.relatedId}');
              }
            }
          },
        ),
      ),
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final difference = now.difference(time);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${time.day}/${time.month}/${time.year}';
    }
  }
}
