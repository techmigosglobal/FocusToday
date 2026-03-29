import 'dart:async';

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';
import 'package:video_thumbnail/video_thumbnail.dart';

import 'media_cache_service.dart';

enum MediaThumbnailType { video, pdf }

/// Generates and caches static thumbnails for heavy media in feed cards.
class MediaThumbnailService {
  MediaThumbnailService._();

  static Directory? _thumbnailDir;
  static final Map<String, Future<File?>> _inFlight = {};

  /// Whether the platform can raster PDFs.
  /// null = not yet checked; true/false = cached result.
  /// Reset to null if a transient failure occurs so we retry on the next call.
  static bool? _canRasterPdf;

  static Future<File?> getThumbnail({
    required String mediaUrl,
    required MediaThumbnailType type,
  }) {
    final trimmed = mediaUrl.trim();
    if (trimmed.isEmpty) return Future.value(null);

    final key = '${type.name}:$trimmed';
    final existing = _inFlight[key];
    if (existing != null) return existing;

    final future = _generateThumbnail(mediaUrl: trimmed, type: type)
        .whenComplete(() {
          _inFlight.remove(key);
        });

    _inFlight[key] = future;
    return future;
  }

  static void warmInBackground({
    required String mediaUrl,
    required MediaThumbnailType type,
  }) {
    unawaited(
      getThumbnail(
        mediaUrl: mediaUrl,
        type: type,
      ).catchError((Object _) => null),
    );
  }

  static Future<File?> _generateThumbnail({
    required String mediaUrl,
    required MediaThumbnailType type,
  }) async {
    final target = await _resolveTargetFile(mediaUrl, type);
    if (await target.exists() && await target.length() > 0) {
      return target;
    }

    switch (type) {
      case MediaThumbnailType.video:
        return _createVideoThumbnail(mediaUrl: mediaUrl, target: target);
      case MediaThumbnailType.pdf:
        return _createPdfThumbnail(mediaUrl: mediaUrl, target: target);
    }
  }

  static Future<File?> _createVideoThumbnail({
    required String mediaUrl,
    required File target,
  }) async {
    try {
      final local =
          await MediaCacheService.getCachedFile(mediaUrl) ??
          await MediaCacheService.cacheFile(
            mediaUrl,
            maxBytes: 35 * 1024 * 1024,
          );

      final source = local?.path ?? mediaUrl;
      final generatedPath = await VideoThumbnail.thumbnailFile(
        video: source,
        thumbnailPath: target.parent.path,
        imageFormat: ImageFormat.JPEG,
        maxWidth: 720,
        quality: 75,
      );

      if (generatedPath == null || generatedPath.isEmpty) return null;
      final generated = File(generatedPath);
      if (!await generated.exists() || await generated.length() <= 0) {
        return null;
      }

      if (generated.path != target.path) {
        if (await target.exists()) {
          await target.delete();
        }
        await generated.copy(target.path);
      }
      return target;
    } catch (e) {
      debugPrint('[Thumbnail] Video thumb failed: $e');
      return null;
    }
  }

  static Future<File?> _createPdfThumbnail({
    required String mediaUrl,
    required File target,
  }) async {
    if (kIsWeb) return null;
    try {
      // Check raster capability. If the cached result is false, bail early.
      // We do NOT permanently cache false here — reset it so we retry on next
      // session start if it was a transient platform failure.
      if (_canRasterPdf == false) return null;

      final local = await MediaCacheService.cacheFile(
        mediaUrl,
        maxBytes: 40 * 1024 * 1024,
      );
      if (local == null || !await local.exists()) {
        debugPrint('[Thumbnail] PDF cache failed for $mediaUrl');
        return null;
      }

      final bytes = await local.readAsBytes();
      if (bytes.isEmpty) {
        debugPrint('[Thumbnail] PDF bytes empty for $mediaUrl');
        return null;
      }

      // Query raster support only once per session.
      if (_canRasterPdf == null) {
        final info = await Printing.info();
        _canRasterPdf = info.canRaster;
      }

      if (_canRasterPdf != true) {
        debugPrint('[Thumbnail] Platform cannot raster PDFs');
        return null;
      }

      // Raster page 0. Guard against PDFs with 0 pages or corrupt data.
      PdfRaster? rasterPage;
      try {
        rasterPage = await Printing.raster(
          bytes,
          pages: const [0],
          dpi: 110,
        ).first;
      } catch (rasterErr) {
        debugPrint('[Thumbnail] PDF raster page 0 failed: $rasterErr');
        return null;
      }

      final pngBytes = await rasterPage.toPng();
      if (pngBytes.isEmpty) {
        debugPrint('[Thumbnail] PDF toPng() returned empty bytes');
        return null;
      }

      await target.writeAsBytes(pngBytes, flush: true);
      return target;
    } catch (e) {
      debugPrint('[Thumbnail] PDF thumb failed: $e');
      // Reset the capability flag in case the failure was transient (e.g.
      // platform not yet ready) so the next call will re-query.
      _canRasterPdf = null;
      return null;
    }
  }

  static Future<File> _resolveTargetFile(
    String mediaUrl,
    MediaThumbnailType type,
  ) async {
    final dir = await _thumbnailDirectory();
    // Use the full-URL hash so every unique PDF URL gets its own file.
    // hashCode alone is not guaranteed unique across process restarts, so we
    // combine it with the last 45 chars of the URL for extra safety (catches tokens).
    final urlHash = mediaUrl.hashCode.toRadixString(16).replaceAll('-', 'n');
    final suffix = mediaUrl.length > 45
        ? mediaUrl.substring(mediaUrl.length - 45)
        : mediaUrl;
    final safeSuffix = suffix.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
    final key = '${type.name}_${urlHash}_$safeSuffix';
    final ext = type == MediaThumbnailType.pdf ? 'png' : 'jpg';
    return File('${dir.path}/$key.$ext');
  }


  static Future<Directory> _thumbnailDirectory() async {
    final existing = _thumbnailDir;
    if (existing != null) return existing;

    final temp = await getTemporaryDirectory();
    final dir = Directory('${temp.path}/thumb_cache');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    _thumbnailDir = dir;
    return dir;
  }
}
