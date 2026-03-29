import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Handles incoming deep links from Android App Links, custom scheme, etc.
/// Share URLs follow the pattern:  https://crii-focus-today.web.app/p/{postId}
/// Custom scheme:                  eagletv://post/{postId}
class DeepLinkService {
  DeepLinkService._();
  static final DeepLinkService instance = DeepLinkService._();

  static const _channel = MethodChannel('app.channel.shared.data');

  final _controller = StreamController<String>.broadcast();

  /// Stream of post IDs arriving from deep links.
  Stream<String> get onPostDeepLink => _controller.stream;

  /// The post ID from the initial deep link that launched the app (if any).
  String? _initialPostId;
  String? get initialPostId => _initialPostId;

  bool _initialized = false;

  /// Call once at app startup to capture the initial link and listen for
  /// subsequent links while the app is running.
  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    // Capture the initial URI that launched the app
    try {
      final initialUri = await _getInitialUri();
      if (initialUri != null) {
        final postId = _extractPostId(initialUri);
        if (postId != null) {
          _initialPostId = postId;
          _controller.add(postId);
        }
      }
    } catch (e) {
      debugPrint('[DeepLinkService] initial URI error: $e');
    }

    // Listen for links while app is running
    // Flutter's PlatformDispatcher provides a callback for URIs opened while
    // the app is already alive.
    try {
      SystemChannels.lifecycle.setMessageHandler((msg) async {
        // On resume, re-check — some platforms deliver links through resume
        if (msg == AppLifecycleState.resumed.toString()) {
          final uri = await _getInitialUri();
          if (uri != null) {
            final postId = _extractPostId(uri);
            if (postId != null && postId != _initialPostId) {
              _initialPostId = postId;
              _controller.add(postId);
            }
          }
        }
        return null;
      });
    } catch (_) {}
  }

  /// Extract postId from a URI like:
  ///   https://crii-focus-today.web.app/p/abc123
  ///   eagletv://post/abc123
  static String? _extractPostId(Uri uri) {
    final segments = uri.pathSegments;

    // https://crii-focus-today.web.app/p/{postId}
    if (segments.length >= 2 && segments[0] == 'p') {
      return segments[1];
    }

    // eagletv://post/{postId}
    if (uri.scheme == 'eagletv' && uri.host == 'post' && segments.isNotEmpty) {
      return segments[0];
    }

    // Fallback: single segment = postId
    if (segments.length == 1 && segments[0].isNotEmpty) {
      return segments[0];
    }

    return null;
  }

  Future<Uri?> _getInitialUri() async {
    try {
      final link = await _channel.invokeMethod<String>('getInitialLink');
      if (link != null && link.isNotEmpty) {
        return Uri.tryParse(link);
      }
    } catch (_) {
      // Channel not available or no initial link
    }

    // Fallback: use PlatformDispatcher if available
    try {
      // ignore: deprecated_member_use
      final uri = WidgetsBinding.instance.platformDispatcher.defaultRouteName;
      if (uri.isNotEmpty && uri != '/') {
        return Uri.tryParse(uri);
      }
    } catch (_) {}

    return null;
  }

  void dispose() {
    _controller.close();
  }
}
