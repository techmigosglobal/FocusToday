import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../shared/models/user.dart';

/// Mock Notification Model
class AppNotification {
  final String id;
  final String title;
  final String body;
  final NotificationType type;
  final DateTime timestamp;
  final bool isRead;
  final String? actionData;

  AppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    required this.timestamp,
    this.isRead = false,
    this.actionData,
  });
}

enum NotificationType {
  postApproved,
  postRejected,
  newContent,
  like,
  comment,
  follower,
  system,
}

/// Notifications Screen
/// Shows mock notifications for demo purposes
class NotificationsScreen extends StatefulWidget {
  final User currentUser;

  const NotificationsScreen({super.key, required this.currentUser});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  List<AppNotification> _notifications = [];

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  void _loadNotifications() {
    // Generate mock notifications based on user role
    _notifications = _generateMockNotifications();
  }

  List<AppNotification> _generateMockNotifications() {
    final now = DateTime.now();
    final notifications = <AppNotification>[];

    if (widget.currentUser.role == UserRole.admin ||
        widget.currentUser.role == UserRole.reporter) {
      notifications.addAll([
        AppNotification(
          id: '1',
          title: 'Post Approved',
          body: 'Your post "Breaking: New Technology Update" has been approved',
          type: NotificationType.postApproved,
          timestamp: now.subtract(const Duration(minutes: 5)),
        ),
        AppNotification(
          id: '2',
          title: '3 New Posts Pending',
          body: 'There are 3 new posts waiting for moderation',
          type: NotificationType.system,
          timestamp: now.subtract(const Duration(hours: 1)),
          isRead: true,
        ),
      ]);
    }

    notifications.addAll([
      AppNotification(
        id: '3',
        title: 'New Content Available',
        body: '5 new articles in Technology category',
        type: NotificationType.newContent,
        timestamp: now.subtract(const Duration(hours: 2)),
      ),
      AppNotification(
        id: '4',
        title: '10 Likes on Your Post',
        body: 'Your post received 10 new likes',
        type: NotificationType.like,
        timestamp: now.subtract(const Duration(hours: 5)),
        isRead: true,
      ),
      AppNotification(
        id: '5',
        title: 'System Update',
        body: 'New features available! Pull down to refresh and discover.',
        type: NotificationType.system,
        timestamp: now.subtract(const Duration(days: 1)),
        isRead: true,
      ),
    ]);

    return notifications;
  }

  @override
  Widget build(BuildContext context) {
    final unreadCount = _notifications.where((n) => !n.isRead).length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          if (unreadCount > 0)
            TextButton(
              onPressed: () {
                HapticFeedback.selectionClick();
                setState(() {
                  for (var notification in _notifications) {
                    notification;
                  }
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('All notifications marked as read'),
                    duration: Duration(seconds: 1),
                  ),
                );
              },
              child: const Text('Mark all read'),
            ),
        ],
      ),
      body: _notifications.isEmpty
          ? _buildEmptyState()
          : ListView.builder(
              itemCount: _notifications.length,
              itemBuilder: (context, index) {
                return _buildNotificationTile(_notifications[index]);
              },
            ),
    );
  }

  Widget _buildNotificationTile(AppNotification notification) {
    return Dismissible(
      key: Key(notification.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: Colors.red,
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      onDismissed: (direction) {
        HapticFeedback.mediumImpact();
        setState(() {
          _notifications.remove(notification);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Notification deleted'),
            duration: Duration(seconds: 1),
          ),
        );
      },
      child: ListTile(
        leading: _buildNotificationIcon(notification.type),
        title: Text(
          notification.title,
          style: TextStyle(
            fontWeight: notification.isRead
                ? FontWeight.normal
                : FontWeight.bold,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(notification.body),
            const SizedBox(height: 4),
            Text(
              _getTimeAgo(notification.timestamp),
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
          ],
        ),
        trailing: !notification.isRead
            ? Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
              )
            : null,
        onTap: () {
          HapticFeedback.lightImpact();
          // Handle notification tap
        },
      ),
    );
  }

  Widget _buildNotificationIcon(NotificationType type) {
    IconData icon;
    Color color;

    switch (type) {
      case NotificationType.postApproved:
        icon = Icons.check_circle;
        color = Colors.green;
        break;
      case NotificationType.postRejected:
        icon = Icons.cancel;
        color = Colors.red;
        break;
      case NotificationType.newContent:
        icon = Icons.fiber_new;
        color = Colors.blue;
        break;
      case NotificationType.like:
        icon = Icons.favorite;
        color = Colors.red;
        break;
      case NotificationType.comment:
        icon = Icons.comment;
        color = AppColors.secondary;
        break;
      case NotificationType.follower:
        icon = Icons.person_add;
        color = AppColors.primary;
        break;
      case NotificationType.system:
        icon = Icons.info;
        color = Colors.orange;
        break;
    }

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: color, size: 24),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.notifications_none,
            size: 64,
            color: AppColors.textSecondary.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 16),
          Text(
            'No notifications',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  String _getTimeAgo(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${difference.inDays ~/ 7}w ago';
    }
  }
}
