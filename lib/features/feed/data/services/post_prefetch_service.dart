import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../../../core/services/media_cache_service.dart';
import '../../../../core/services/media_thumbnail_service.dart';
import '../../../../shared/models/post.dart';

/// Prefetches upcoming post media in parallel so next cards open faster.
class PostPrefetchService {
  PostPrefetchService._();

  static final Set<String> _prefetchedUrls = <String>{};
  static final Map<String, String> _textPreviewCache = <String, String>{};
  static final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 6),
      receiveTimeout: const Duration(seconds: 8),
      sendTimeout: const Duration(seconds: 8),
    ),
  );

  static Future<void> prefetchUpcoming({
    required BuildContext context,
    required List<Post> posts,
    required int currentIndex,
    int aheadCount = 4,
  }) async {
    if (posts.isEmpty) return;
    final start = currentIndex + 1;
    if (start >= posts.length) return;
    final end = (start + aheadCount - 1).clamp(0, posts.length - 1);
    final targets = <Post>[for (int i = start; i <= end; i++) posts[i]];

    await Future.wait(
      targets.map((post) => _prefetchSingle(context, post)),
      eagerError: false,
    );
  }

  static Future<void> _prefetchSingle(BuildContext context, Post post) async {
    final url = post.mediaUrl;
    if (url == null || url.isEmpty || _prefetchedUrls.contains(url)) return;
    final uri = Uri.tryParse(url);
    final host = uri?.host.toLowerCase();
    if (host == 'localhost' || host == '127.0.0.1' || host == '0.0.0.0') {
      return;
    }

    _prefetchedUrls.add(url);
    try {
      switch (post.contentType) {
        case ContentType.image:
          // Probe first so missing/deleted URLs (404) don't trigger noisy
          // uncaught image exceptions during precache.
          final probe = await _dio.get<List<int>>(
            url,
            options: Options(
              responseType: ResponseType.bytes,
              headers: const {'Range': 'bytes=0-1023'},
              validateStatus: (status) => status != null && status < 500,
            ),
          );
          if ((probe.statusCode ?? 500) >= 400) {
            _prefetchedUrls.remove(url);
            return;
          }
          if (!context.mounted) {
            _prefetchedUrls.remove(url);
            return;
          }
          await _precacheImageSafely(context, url);
          return;
        case ContentType.video:
          MediaThumbnailService.warmInBackground(
            mediaUrl: url,
            type: MediaThumbnailType.video,
          );
          // Prefer lightweight disk cache warmup for small/medium files.
          final cached = await MediaCacheService.cacheFile(
            url,
            maxBytes:
                25 * 1024 * 1024, // Avoid aggressive prefetch on huge media
          );
          if (cached != null) return;

          // Fallback: warm connection/cache with a small byte-range fetch.
          await _dio.get<List<int>>(
            url,
            options: Options(
              responseType: ResponseType.bytes,
              headers: const {'Range': 'bytes=0-262143'},
              validateStatus: (status) => status != null && status < 500,
            ),
          );
          return;
        case ContentType.pdf:
          MediaThumbnailService.warmInBackground(
            mediaUrl: url,
            type: MediaThumbnailType.pdf,
          );
          // Prefer lightweight disk cache warmup for small/medium files.
          final cachedPdf = await MediaCacheService.cacheFile(
            url,
            maxBytes:
                25 * 1024 * 1024, // Avoid aggressive prefetch on huge media
          );
          if (cachedPdf != null) return;

          // Fallback: warm connection/cache with a small byte-range fetch.
          await _dio.get<List<int>>(
            url,
            options: Options(
              responseType: ResponseType.bytes,
              headers: const {'Range': 'bytes=0-262143'},
              validateStatus: (status) => status != null && status < 500,
            ),
          );
          return;
        case ContentType.article:
        case ContentType.story:
        case ContentType.poetry:
        case ContentType.none:
          final sourceText = post.articleContent ?? post.caption;
          final preview = await compute(_buildTextPreview, sourceText);
          _textPreviewCache[post.id] = preview;
          return;
      }
    } catch (_) {
      // Remove failed URL so a future attempt can retry.
      _prefetchedUrls.remove(url);
    }
  }

  static void clear() {
    _prefetchedUrls.clear();
    _textPreviewCache.clear();
  }

  static Future<void> prefetchMedia(String url) async {
    if (url.isEmpty || _prefetchedUrls.contains(url)) return;
    _prefetchedUrls.add(url);
    try {
      MediaThumbnailService.warmInBackground(
        mediaUrl: url,
        type: MediaThumbnailType.video,
      );
      final cached = await MediaCacheService.cacheFile(
        url,
        maxBytes: 25 * 1024 * 1024,
      );
      if (cached != null) return;

      await _dio.get<List<int>>(
        url,
        options: Options(
          responseType: ResponseType.bytes,
          headers: const {'Range': 'bytes=0-262143'},
          validateStatus: (status) => status != null && status < 500,
        ),
      );
    } catch (_) {
      _prefetchedUrls.remove(url);
    }
  }

  static Future<void> _precacheImageSafely(
    BuildContext context,
    String url,
  ) async {
    final provider = CachedNetworkImageProvider(url);
    final stream = provider.resolve(createLocalImageConfiguration(context));
    final completer = Completer<void>();
    late final ImageStreamListener listener;
    listener = ImageStreamListener(
      (_, _) {
        if (!completer.isCompleted) completer.complete();
        stream.removeListener(listener);
      },
      onError: (_, _) {
        _prefetchedUrls.remove(url);
        if (!completer.isCompleted) completer.complete();
        stream.removeListener(listener);
      },
    );
    stream.addListener(listener);

    try {
      await completer.future.timeout(const Duration(seconds: 5));
    } catch (_) {
      _prefetchedUrls.remove(url);
      stream.removeListener(listener);
    }
  }
}

String _buildTextPreview(String source) {
  final normalized = source.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (normalized.length <= 280) return normalized;
  return '${normalized.substring(0, 280)}...';
}
