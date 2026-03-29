import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../../../../core/services/cache_service.dart';
import '../../../../core/services/firestore_service.dart';

class AppNotification {
  final String id;
  final String userId;
  final String title;
  final String body;
  final String type;
  final bool isRead;
  final String? actionData;
  final DateTime createdAt;

  AppNotification({
    required this.id,
    required this.userId,
    required this.title,
    required this.body,
    required this.type,
    this.isRead = false,
    this.actionData,
    required this.createdAt,
  });

  factory AppNotification.fromMap(Map<String, dynamic> map) {
    return AppNotification(
      id: (map['id'] ?? '').toString(),
      userId: (map['user_id'] ?? '').toString(),
      title: (map['title'] ?? '').toString(),
      body: (map['body'] ?? '').toString(),
      type: (map['type'] ?? 'system').toString(),
      isRead: map['is_read'] == true || map['is_read'] == 1,
      actionData: map['action_data']?.toString(),
      createdAt: FirestoreService.toDateTime(map['created_at']),
    );
  }
}

class NotificationRepository {
  static Future<int>? _unreadCountInFlight;
  static String? _unreadCountInFlightUserId;

  Future<List<AppNotification>> getNotifications(String userId) async {
    final cacheKey = 'notifications_list_$userId';
    final cached = CacheService.get(
      cacheKey,
      maxAge: const Duration(seconds: 15),
    );
    if (cached is List) {
      return cached
          .whereType<Map>()
          .map((row) => AppNotification.fromMap(Map<String, dynamic>.from(row)))
          .toList(growable: true);
    }

    try {
      final snapshot = await FirestoreService.notifications
          .where('user_id', isEqualTo: userId)
          .orderBy('created_at', descending: true)
          .limit(50)
          .get();

      final notifications = snapshot.docs
          .map((doc) => AppNotification.fromMap({'id': doc.id, ...doc.data()}))
          .toList(growable: true);
      await CacheService.set(
        cacheKey,
        notifications
            .map(
              (notification) => {
                'id': notification.id,
                'user_id': notification.userId,
                'title': notification.title,
                'body': notification.body,
                'type': notification.type,
                'is_read': notification.isRead,
                'action_data': notification.actionData,
                'created_at': notification.createdAt.toIso8601String(),
              },
            )
            .toList(growable: false),
      );
      return notifications;
    } catch (e) {
      debugPrint('[NotificationRepo] getNotifications error: $e');
      return [];
    }
  }

  Future<int> getUnreadCount(String userId, {bool forceRefresh = false}) async {
    final cacheKey = 'notifications_unread_count_$userId';

    if (!forceRefresh) {
      final cached = CacheService.get(
        cacheKey,
        maxAge: const Duration(seconds: 10),
      );
      if (cached is int) return cached;
      if (cached is num) return cached.toInt();
    }

    if (_unreadCountInFlight != null && _unreadCountInFlightUserId == userId) {
      return _unreadCountInFlight!;
    }

    final future = _fetchUnreadCount(cacheKey, userId);
    _unreadCountInFlight = future;
    _unreadCountInFlightUserId = userId;

    try {
      return await future;
    } catch (e) {
      debugPrint('[NotificationRepo] getUnreadCount error: $e');
      return 0;
    } finally {
      if (identical(_unreadCountInFlight, future)) {
        _unreadCountInFlight = null;
        _unreadCountInFlightUserId = null;
      }
    }
  }

  Future<void> markAsRead(String notificationId) async {
    try {
      await FirestoreService.notifications.doc(notificationId).set({
        'is_read': true,
        'read_at': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      await CacheService.invalidatePrefix('notifications_list_');
      await CacheService.invalidatePrefix('notifications_unread_count_');
    } catch (e) {
      debugPrint('[NotificationRepo] markAsRead error: $e');
    }
  }

  Future<void> markAllAsRead(String userId) async {
    try {
      final docs = await FirestoreService.notifications
          .where('user_id', isEqualTo: userId)
          .where('is_read', isEqualTo: false)
          .limit(500)
          .get();

      final batch = FirestoreService.db.batch();
      for (final doc in docs.docs) {
        batch.set(doc.reference, {
          'is_read': true,
          'read_at': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
      await batch.commit();
      await CacheService.invalidate('notifications_list_$userId');
      await CacheService.invalidate('notifications_unread_count_$userId');
    } catch (e) {
      debugPrint('[NotificationRepo] markAllAsRead error: $e');
    }
  }

  Future<void> deleteNotification(String notificationId) async {
    try {
      await FirestoreService.notifications.doc(notificationId).delete();
      await CacheService.invalidatePrefix('notifications_list_');
      await CacheService.invalidatePrefix('notifications_unread_count_');
    } catch (e) {
      debugPrint('[NotificationRepo] deleteNotification error: $e');
    }
  }

  Future<int> _fetchUnreadCount(String cacheKey, String userId) async {
    final snap = await FirestoreService.notifications
        .where('user_id', isEqualTo: userId)
        .where('is_read', isEqualTo: false)
        .count()
        .get();
    final count = snap.count ?? 0;
    await CacheService.set(cacheKey, count);
    return count;
  }
}
