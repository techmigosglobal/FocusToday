import 'dart:convert';
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'firestore_service.dart';
import '../../shared/models/user.dart';
import 'notification_preferences_service.dart';

const String _prefDeviceId = 'device_unique_id';
const String _keyFcmToken = 'fcm_token';
const String _channelId = 'focus_today_high_importance';
const String _channelName = 'Focus Today Notifications';
const String _channelDesc =
    'Important alerts, post updates, and news from Focus Today.';

/// Multi-device token management for FCM notifications
///
/// Stores tokens in:
/// - `users/{uid}/devices/{deviceId}` (primary)
/// - `users/{uid}.fcm_token` (legacy fallback)
class NotificationService {
  static final NotificationService instance = NotificationService._internal();
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  final _uuid = const Uuid();
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();
  Map<String, dynamic>? _pendingNavigationData;
  AppForegroundSurface _activeSurface = AppForegroundSurface.other;
  final StreamController<InAppNotificationEvent> _eventsController =
      StreamController<InAppNotificationEvent>.broadcast();
  NotificationPreferencesService? _notificationPreferences;
  bool _isInitialized = false;
  Future<void>? _initializationFuture;

  NotificationService._internal();

  Stream<InAppNotificationEvent> get events => _eventsController.stream;

  void setForegroundSurface(AppForegroundSurface surface) {
    _activeSurface = surface;
  }

  /// Initialize notification service
  static Future<void> initialize() async {
    await instance._ensureInitialized();
  }

  Future<void> _ensureInitialized() {
    if (_isInitialized) return Future.value();
    _initializationFuture ??= _initInternal();
    return _initializationFuture!;
  }

  Future<void> _initInternal() async {
    if (_isInitialized) return;
    _notificationPreferences = await NotificationPreferencesService.init();

    // Request permission only when needed to avoid repeated prompts/noisy logs.
    var settings = await _messaging.getNotificationSettings();
    if (settings.authorizationStatus == AuthorizationStatus.notDetermined) {
      settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );
    }

    if (settings.authorizationStatus == AuthorizationStatus.denied) {
      debugPrint('WARNING: User declined notification permission');
    } else if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      debugPrint('INFO: User granted notification permission');
    } else if (settings.authorizationStatus ==
        AuthorizationStatus.provisional) {
      debugPrint('INFO: User granted provisional notification permission');
    }

    // Get initial token
    final token = await _messaging.getToken();
    if (token != null) {
      await _saveFcmToken(token);
      debugPrint('INFO: FCM token obtained: ${token.substring(0, 20)}...');
    }

    // Listen for token refresh
    _messaging.onTokenRefresh.listen(_onTokenRefresh);

    // ----------------------------------------------------------------
    // flutter_local_notifications — needed to surface FCM messages
    // when the app is in the FOREGROUND (FCM suppresses the system
    // notification tray in foreground; we must show it ourselves).
    // ----------------------------------------------------------------
    await _localNotifications.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('ic_stat_focus_today'),
        iOS: DarwinInitializationSettings(),
      ),
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        // Payload is the FCM data map serialised as a JSON string.
        final payload = response.payload;
        if (payload != null && payload.isNotEmpty) {
          try {
            final decoded = jsonDecode(payload);
            if (decoded is Map) {
              _pendingNavigationData = Map<String, dynamic>.from(decoded);
            }
          } catch (_) {}
        }
      },
    );

    // Create the Android notification channel once.
    await _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(
          const AndroidNotificationChannel(
            _channelId,
            _channelName,
            description: _channelDesc,
            importance: Importance.high,
          ),
        );

    // Foreground message handler — shows a local notification so the
    // user is aware of incoming events while the app is open.
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      final event = InAppNotificationEvent.fromRemoteMessage(message);
      if (event != null && !_eventsController.isClosed) {
        _eventsController.add(event);
      }

      final notification = message.notification;
      final type = event?.type ?? message.data['type']?.toString() ?? '';
      final shouldSuppressForegroundBanner =
          _activeSurface == AppForegroundSurface.feed &&
          (type == 'post_published_digest' || type == 'post_published');
      final shouldHonorPreferences = _shouldDisplayForegroundNotification();

      if (notification != null) {
        if (shouldSuppressForegroundBanner) {
          debugPrint(
            '[NotificationService] Suppressed foreground banner for $type while user is reading feed',
          );
          return;
        }
        if (!shouldHonorPreferences) {
          debugPrint(
            '[NotificationService] Suppressed foreground banner by user notification preferences',
          );
          return;
        }
        // Serialise data so it can be recovered when user taps the notification.
        final payloadJson = message.data.isNotEmpty
            ? jsonEncode(message.data)
            : null;

        try {
          _localNotifications.show(
            notification.hashCode,
            notification.title,
            notification.body,
            const NotificationDetails(
              android: AndroidNotificationDetails(
                _channelId,
                _channelName,
                channelDescription: _channelDesc,
                importance: Importance.high,
                priority: Priority.high,
                icon: 'ic_notification_focus_today',
                // Must reference a drawable resource; using app launcher from
                // mipmap here causes runtime "invalid_large_icon" on some devices.
                largeIcon: DrawableResourceAndroidBitmap(
                  'ic_notification_focus_today',
                ),
              ),
              iOS: DarwinNotificationDetails(
                presentAlert: true,
                presentBadge: true,
                presentSound: true,
              ),
            ),
            payload: payloadJson,
          );
        } catch (e) {
          debugPrint(
            '[NotificationService] Local foreground notification failed: $e',
          );
        }
      }

      debugPrint(
        '[NotificationService] Foreground message received: ${notification?.title}',
      );
    });

    // Background tap: app was in background and user tapped notification.
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint(
        '[NotificationService] Notification tap (background): ${message.notification?.title}',
      );
      if (message.data.isNotEmpty) {
        _pendingNavigationData = Map<String, dynamic>.from(message.data);
      }
    });

    // Terminated tap: app was fully closed, opened via notification.
    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null && initialMessage.data.isNotEmpty) {
      debugPrint(
        '[NotificationService] Notification tap (terminated): ${initialMessage.notification?.title}',
      );
      _pendingNavigationData = Map<String, dynamic>.from(initialMessage.data);
    }
    _isInitialized = true;
  }

  bool _shouldDisplayForegroundNotification() {
    final prefs = _notificationPreferences;
    if (prefs == null) return true;
    if (!prefs.pushEnabled) return false;
    if (prefs.isInQuietHours(DateTime.now())) return false;
    return true;
  }

  /// Get or create unique device ID
  Future<String> _getOrCreateDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    String? deviceId = prefs.getString(_prefDeviceId);

    if (deviceId == null || deviceId.isEmpty) {
      // Generate new device ID using uuid
      deviceId = _uuid.v4();
      await prefs.setString(_prefDeviceId, deviceId);
      debugPrint('INFO: Generated new device ID: $deviceId');
    }

    return deviceId;
  }

  /// Handle token refresh
  Future<void> _onTokenRefresh(String newToken) async {
    debugPrint('INFO: FCM token refreshed: ${newToken.substring(0, 20)}...');
    await _saveFcmToken(newToken);

    // Re-sync to server if user is authenticated.
    // Read the canonical 'user_id' key (written by AuthRepository) with
    // a fallback to the legacy 'current_user_id' key stored by this service.
    final prefs = await SharedPreferences.getInstance();
    final userId =
        prefs.getString('user_id') ?? prefs.getString('current_user_id');
    if (userId != null) {
      await syncFcmTokenToServer(userId);
    }
  }

  /// Save FCM token to local storage
  Future<void> _saveFcmToken(String token) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyFcmToken, token);
      debugPrint('INFO: FCM token saved locally');
    } catch (e) {
      debugPrint('ERROR: Failed to save FCM token: $e');
    }
  }

  /// Get stored FCM token
  Future<String?> getStoredFcmToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyFcmToken);
  }

  /// Sync FCM token to backend server with multi-device support
  Future<void> syncFcmTokenToServer(String userId) async {
    try {
      var token = await getStoredFcmToken();
      token ??= await _messaging.getToken();
      if (token == null || token.trim().isEmpty) {
        debugPrint(
          'WARNING: No FCM token available yet; skipping sync for user $userId',
        );
        return;
      }
      await _saveFcmToken(token);

      final deviceId = await _getOrCreateDeviceId();
      final now = Timestamp.now();

      // Write to devices subcollection (multi-device support)
      await FirestoreService.users
          .doc(userId)
          .collection('devices')
          .doc(deviceId)
          .set({
            'fcm_token': token,
            'device_id': deviceId,
            'platform': defaultTargetPlatform.name,
            'created_at': now,
            'last_active_at': now,
            'updated_at': now,
            'active': true,
          }, SetOptions(merge: true));

      // Also update legacy field for backward compatibility
      await FirestoreService.users.doc(userId).set({
        'fcm_token': token,
        'updated_at': now,
      }, SetOptions(merge: true));

      debugPrint(
        'INFO: FCM token synced to server for user $userId (device: $deviceId)',
      );
    } catch (e) {
      debugPrint('ERROR: Failed to sync FCM token to server: $e');
    }
  }

  /// Full setup after login/session restore
  Future<void> onUserAuthenticated(String userId, UserRole role) async {
    await _ensureInitialized();

    // Store user ID for future token refreshes (match AuthRepository key)
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_id', userId);

    // Sync token to server
    await syncFcmTokenToServer(userId);

    // Subscribe to role-based topics
    await subscribeToRoleTopics(role);
  }

  /// Subscribe to role-based FCM topics
  Future<void> subscribeToRoleTopics(UserRole role) async {
    // Unsubscribe from all role topics first
    for (final r in [
      'role_admin',
      'role_super_admin',
      'role_reporter',
      'role_public_user',
      'new_content',
      'breaking_news',
    ]) {
      try {
        await _messaging.unsubscribeFromTopic(r);
      } catch (_) {}
    }

    // Subscribe to the user's role topic
    final roleTopic = 'role_${role.toApiString()}';
    await subscribeToTopic(roleTopic);

    // All users should get new_content notifications
    await subscribeToTopic('new_content');
    await subscribeToTopic('breaking_news');

    debugPrint(
      'INFO: Subscribed to FCM topics: $roleTopic, new_content, breaking_news',
    );
  }

  /// Subscribe to topic
  Future<void> subscribeToTopic(String topic) async {
    try {
      await _messaging.subscribeToTopic(topic);
      debugPrint('INFO: Subscribed to topic: $topic');
    } catch (e) {
      debugPrint('ERROR: Failed to subscribe to topic: $e');
    }
  }

  /// Unsubscribe from topic
  Future<void> unsubscribeFromTopic(String topic) async {
    try {
      await _messaging.unsubscribeFromTopic(topic);
      debugPrint('INFO: Unsubscribed from topic: $topic');
    } catch (e) {
      debugPrint('ERROR: Failed to unsubscribe from topic: $e');
    }
  }

  /// Delete FCM token (on logout) and cleanup
  Future<void> deleteToken({String? userId}) async {
    try {
      if (userId != null) {
        // Delete device from devices subcollection
        final deviceId = await _getOrCreateDeviceId();
        await FirestoreService.users
            .doc(userId)
            .collection('devices')
            .doc(deviceId)
            .delete();

        // Clear legacy token
        await FirestoreService.users.doc(userId).set({
          'fcm_token': '',
          'updated_at': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        debugPrint('INFO: Deleted device token for user $userId');
      }

      // Unsubscribe from all topics
      for (final topic in [
        'role_admin',
        'role_super_admin',
        'role_reporter',
        'role_public_user',
        'new_content',
        'breaking_news',
      ]) {
        try {
          await _messaging.unsubscribeFromTopic(topic);
        } catch (_) {}
      }

      // Delete FCM token
      await _messaging.deleteToken();
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keyFcmToken);

      debugPrint('INFO: FCM token deleted and topics unsubscribed');
    } catch (e) {
      debugPrint('ERROR: Failed to delete FCM token: $e');
    }
  }

  Map<String, dynamic>? consumePendingNavigation() {
    final data = _pendingNavigationData;
    _pendingNavigationData = null;
    return data;
  }

  Future<NotificationPreferencesService> getPreferences() async {
    return await NotificationPreferencesService.init();
  }

  Future<AuthorizationStatus> getAuthorizationStatus() async {
    final settings = await _messaging.getNotificationSettings();
    return settings.authorizationStatus;
  }

  Future<bool> requestSystemNotificationPermission() async {
    await _ensureInitialized();
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );
    return settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional;
  }

  Future<void> setQuietHoursStart(TimeOfDayLite value) async {
    final prefs = await NotificationPreferencesService.init();
    await prefs.setQuietStart(value);
  }

  Future<void> setQuietHoursEnd(TimeOfDayLite value) async {
    final prefs = await NotificationPreferencesService.init();
    await prefs.setQuietEnd(value);
  }

  Future<void> setPushEnabled(bool value) async {
    final prefs = await NotificationPreferencesService.init();
    await prefs.setPushEnabled(value);
  }

  Future<void> setGroupingEnabled(bool value) async {
    final prefs = await NotificationPreferencesService.init();
    await prefs.setGroupingEnabled(value);
  }

  Future<void> setQuietHoursEnabled(bool value) async {
    final prefs = await NotificationPreferencesService.init();
    await prefs.setQuietHoursEnabled(value);
  }
}

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('Handling a background message: ${message.messageId}');
}

enum AppForegroundSurface { feed, other }

class InAppNotificationEvent {
  final String type;
  final String? postId;
  final int? count;
  final DateTime receivedAt;

  const InAppNotificationEvent({
    required this.type,
    this.postId,
    this.count,
    required this.receivedAt,
  });

  factory InAppNotificationEvent.fromMap(Map<String, dynamic> map) {
    final rawCount = map['count'];
    return InAppNotificationEvent(
      type: (map['type'] ?? '').toString(),
      postId: map['post_id']?.toString(),
      count: rawCount is int
          ? rawCount
          : int.tryParse(rawCount?.toString() ?? ''),
      receivedAt: DateTime.now(),
    );
  }

  static InAppNotificationEvent? fromRemoteMessage(RemoteMessage message) {
    if (message.data.isEmpty) return null;
    return InAppNotificationEvent.fromMap(
      Map<String, dynamic>.from(message.data),
    );
  }
}
