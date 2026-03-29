import 'package:flutter/foundation.dart';
import 'package:video_player/video_player.dart';

/// Shared controller cache for feed videos.
/// Keeps only a small controller window (current + next) in memory.
class FeedVideoControllerService {
  FeedVideoControllerService._();

  static final FeedVideoControllerService instance =
      FeedVideoControllerService._();

  static const int _maxActiveControllers = 2;

  final Map<String, VideoPlayerController> _controllers = {};
  final Map<String, Future<VideoPlayerController?>> _inFlight = {};
  final List<String> _lru = [];

  static String buildKey({required String postId, required String mediaUrl}) {
    return '${postId.trim()}|${mediaUrl.trim()}';
  }

  VideoPlayerController? getController(String key) {
    final controller = _controllers[key];
    if (controller != null) _touch(key);
    return controller;
  }

  Future<VideoPlayerController?> acquire({
    required String key,
    required Uri uri,
  }) async {
    final cached = _controllers[key];
    if (cached != null) {
      _touch(key);
      return cached;
    }

    final inFlight = _inFlight[key];
    if (inFlight != null) return inFlight;

    final future = _createController(key, uri);
    _inFlight[key] = future;

    try {
      return await future;
    } finally {
      _inFlight.remove(key);
    }
  }

  Future<void> trimTo(Set<String> keepKeys) async {
    final removeKeys = _controllers.keys
        .where((key) => !keepKeys.contains(key))
        .toList();

    for (final key in removeKeys) {
      await _disposeKey(key);
    }

    await _trimOverflow(preferredKeys: keepKeys);
  }

  Future<void> disposeAll() async {
    final keys = _controllers.keys.toList();
    for (final key in keys) {
      await _disposeKey(key);
    }
    _inFlight.clear();
    _lru.clear();
  }

  Future<VideoPlayerController?> _createController(String key, Uri uri) async {
    final controller = VideoPlayerController.networkUrl(uri);

    try {
      await controller.initialize();
      await controller.setLooping(true);
      _controllers[key] = controller;
      _touch(key);
      await _trimOverflow(preferredKeys: {key});
      return controller;
    } catch (error) {
      debugPrint('[FeedVideoControllerService] Failed to init video: $error');
      await controller.dispose();
      return null;
    }
  }

  Future<void> _trimOverflow({required Set<String> preferredKeys}) async {
    while (_controllers.length > _maxActiveControllers && _lru.isNotEmpty) {
      String? evictKey;
      for (final key in _lru) {
        if (!preferredKeys.contains(key)) {
          evictKey = key;
          break;
        }
      }
      evictKey ??= _lru.first;
      await _disposeKey(evictKey);
    }
  }

  Future<void> _disposeKey(String key) async {
    final controller = _controllers.remove(key);
    _lru.remove(key);
    if (controller != null) {
      await controller.dispose();
    }
  }

  void _touch(String key) {
    _lru.remove(key);
    _lru.add(key);
  }
}
