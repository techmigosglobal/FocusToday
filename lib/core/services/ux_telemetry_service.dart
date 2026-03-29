import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../../shared/models/user.dart';
import 'firestore_service.dart';

/// Lightweight product telemetry for UX iteration and dashboarding.
///
/// Schema (telemetry_events collection):
/// - event_name: string
/// - event_group: string (discovery|header|engagement|navigation|system)
/// - screen: string
/// - user_id: string
/// - role: string
/// - session_id: string
/// - metadata: `Map<String, dynamic>`
/// - created_at: server timestamp
class UxTelemetryService {
  UxTelemetryService._();

  static final UxTelemetryService instance = UxTelemetryService._();

  final Uuid _uuid = const Uuid();
  String? _sessionId;

  String _ensureSessionId() => _sessionId ??= _uuid.v4();

  Future<void> trackAnonymous({
    required String eventName,
    required String eventGroup,
    required String screen,
    String userId = 'anonymous',
    String role = 'anonymous',
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final cleanMetadata = <String, dynamic>{
        for (final entry in (metadata ?? const <String, dynamic>{}).entries)
          if (entry.value != null) entry.key: entry.value,
      };

      await FirestoreService.telemetryEvents.add({
        'event_name': eventName,
        'event_group': eventGroup,
        'screen': screen,
        'user_id': userId,
        'role': role,
        'session_id': _ensureSessionId(),
        'metadata': cleanMetadata,
        'created_at': FieldValue.serverTimestamp(),
        'client_created_at': DateTime.now().toUtc().toIso8601String(),
      });
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[UxTelemetry] trackAnonymous failed for $eventName: $e');
      }
    }
  }

  Future<void> track({
    required String eventName,
    required String eventGroup,
    required String screen,
    required User user,
    Map<String, dynamic>? metadata,
  }) async {
    if (user.id.isEmpty) return;

    try {
      final cleanMetadata = <String, dynamic>{
        for (final entry in (metadata ?? const <String, dynamic>{}).entries)
          if (entry.value != null) entry.key: entry.value,
      };

      await FirestoreService.telemetryEvents.add({
        'event_name': eventName,
        'event_group': eventGroup,
        'screen': screen,
        'user_id': user.id,
        'role': user.role.toStr(),
        'session_id': _ensureSessionId(),
        'metadata': cleanMetadata,
        'created_at': FieldValue.serverTimestamp(),
        'client_created_at': DateTime.now().toUtc().toIso8601String(),
      });
    } catch (e) {
      // Non-blocking by design.
      if (kDebugMode) {
        debugPrint('[UxTelemetry] track failed for $eventName: $e');
      }
    }
  }

  Future<void> trackHeaderAction({
    required User user,
    required String screen,
    required String action,
    Map<String, dynamic>? metadata,
  }) {
    return track(
      eventName: 'header_action',
      eventGroup: 'header',
      screen: screen,
      user: user,
      metadata: {'action': action, ...?metadata},
    );
  }

  Future<void> trackDiscoveryTap({
    required User user,
    required String screen,
    required String railLabel,
    required bool selected,
  }) {
    return track(
      eventName: 'discovery_rail_tap',
      eventGroup: 'discovery',
      screen: screen,
      user: user,
      metadata: {'rail_label': railLabel, 'selected': selected},
    );
  }

  Future<void> trackEngagement({
    required User user,
    required String screen,
    required String action,
    required String postId,
    Map<String, dynamic>? metadata,
  }) {
    return track(
      eventName: 'engagement_action',
      eventGroup: 'engagement',
      screen: screen,
      user: user,
      metadata: {'action': action, 'post_id': postId, ...?metadata},
    );
  }

  Future<void> trackNavigation({
    required User user,
    required String screen,
    required String destination,
    Map<String, dynamic>? metadata,
  }) {
    return track(
      eventName: 'navigation_action',
      eventGroup: 'navigation',
      screen: screen,
      user: user,
      metadata: {'destination': destination, ...?metadata},
    );
  }
}
