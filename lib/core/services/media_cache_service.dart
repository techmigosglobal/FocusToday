import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// Lightweight disk cache for large media (video/pdf) to speed up repeat opens.
class MediaCacheService {
  MediaCacheService._();

  static final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 8),
      receiveTimeout: const Duration(minutes: 5),
      sendTimeout: const Duration(seconds: 30),
      followRedirects: true,
      maxRedirects: 5,
    ),
  );

  static Directory? _cacheDir;
  static final Map<String, Future<File?>> _inFlight = {};

  static Future<File?> getCachedFile(String url) async {
    try {
      final file = await _resolveFile(url);
      if (!await file.exists()) return null;
      if (await file.length() <= 0) return null;
      return file;
    } catch (_) {
      return null;
    }
  }

  /// Ensure file is cached locally.
  /// If [maxBytes] is set and server reports a larger size, cache is skipped.
  static Future<File?> cacheFile(
    String url, {
    ProgressCallback? onProgress,
    int? maxBytes,
  }) {
    final trimmed = url.trim();
    if (trimmed.isEmpty) return Future.value(null);
    final existing = _inFlight[trimmed];
    if (existing != null) return existing;

    final future =
        _cacheFileInternal(
          trimmed,
          onProgress: onProgress,
          maxBytes: maxBytes,
        ).whenComplete(() {
          _inFlight.remove(trimmed);
        });

    _inFlight[trimmed] = future;
    return future;
  }

  static void warmInBackground(String? url, {int? maxBytes}) {
    final value = url?.trim();
    if (value == null || value.isEmpty) return;
    unawaited(
      cacheFile(value, maxBytes: maxBytes).catchError((Object _) => null),
    );
  }

  static Future<File?> _cacheFileInternal(
    String url, {
    ProgressCallback? onProgress,
    int? maxBytes,
  }) async {
    final parsed = Uri.tryParse(url);
    if (parsed == null ||
        !(parsed.isScheme('http') || parsed.isScheme('https'))) {
      return null;
    }

    final cached = await getCachedFile(url);
    if (cached != null) return cached;

    if (maxBytes != null) {
      final tooLarge = await _isLargerThan(url, maxBytes);
      if (tooLarge) {
        debugPrint('[MediaCache] Skip large file: $url');
        return null;
      }
    }

    final file = await _resolveFile(url);
    final tempFile = File('${file.path}.part');

    try {
      if (await tempFile.exists()) {
        await tempFile.delete();
      }

      await _dio.download(
        url,
        tempFile.path,
        deleteOnError: true,
        onReceiveProgress: onProgress,
      );

      if (!await tempFile.exists() || await tempFile.length() <= 0) {
        return null;
      }

      if (await file.exists()) {
        await file.delete();
      }
      await tempFile.rename(file.path);
      return file;
    } catch (e) {
      if (await tempFile.exists()) {
        try {
          await tempFile.delete();
        } catch (_) {}
      }
      debugPrint('[MediaCache] cacheFile failed: $e');
      return null;
    }
  }

  static Future<bool> _isLargerThan(String url, int maxBytes) async {
    try {
      final response = await _dio.head(url);
      final header = response.headers.value(HttpHeaders.contentLengthHeader);
      final bytes = int.tryParse(header ?? '');
      if (bytes == null || bytes <= 0) return false;
      return bytes > maxBytes;
    } catch (_) {
      return false;
    }
  }

  static Future<File> _resolveFile(String url) async {
    final dir = await _cacheDirectory();
    final fileName = _buildFileName(url);
    return File('${dir.path}/$fileName');
  }

  static Future<Directory> _cacheDirectory() async {
    final existing = _cacheDir;
    if (existing != null) return existing;
    final tempDir = await getTemporaryDirectory();
    final dir = Directory('${tempDir.path}/media_cache');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    _cacheDir = dir;
    return dir;
  }

  static String _buildFileName(String url) {
    // Generate a reasonably unique string without external crypto packages.
    // The previous implementation base64-encoded the URL and grabbed the first 48 chars.
    // For Firebase Storage URLs, the first ~64 chars are identical, which meant ALL
    // files from the same bucket resolved to the EXACT SAME cached file!
    final hashCodeStr = url.hashCode.toRadixString(16).replaceAll('-', 'n');
    
    // Grab the last 45 characters of the URL (contains the unique token/UUID)
    final urlEnd = url.length > 45 ? url.substring(url.length - 45) : url;
    final encodedEnd = base64Url.encode(utf8.encode(urlEnd)).replaceAll('=', '');
    
    final safeBase = '${hashCodeStr}_$encodedEnd';

    final uri = Uri.tryParse(url);
    final path = uri?.path ?? '';
    final extMatch = RegExp(r'\.([a-zA-Z0-9]{1,6})$').firstMatch(path);
    final ext = extMatch != null
        ? '.${extMatch.group(1)!.toLowerCase()}'
        : '.bin';
    return '$safeBase$ext';
  }
}
