import 'package:flutter/foundation.dart';
import 'on_device_translation_service.dart';

/// On-device translation helper backed by Google ML Kit.
class PostTranslationService {
  PostTranslationService._();

  static final Map<String, String> _cache = {};
  static final Map<String, Future<String>> _inFlight = {};
  static final Set<String> _modelWarmupsInFlight = <String>{};
  static const Set<String> _supportedCodes = {'en', 'te', 'hi'};

  static Future<String> translate({
    required String text,
    required String targetLanguageCode,
    String? sourceLanguageCode,
    bool allowModelDownload = true,
  }) async {
    final normalizedText = text.trim();
    if (normalizedText.isEmpty) return text;

    final target = _normalizeCode(targetLanguageCode);
    if (!_supportedCodes.contains(target)) return text;

    var source = _normalizeCode(
      sourceLanguageCode ?? detectLanguageCode(normalizedText),
    );
    if (!_supportedCodes.contains(source)) source = 'en';
    if (source == target) return text;

    final cacheKey = '$source->$target:${normalizedText.hashCode}';
    final cached = _cache[cacheKey];
    if (cached != null) return cached;

    final inFlight = _inFlight[cacheKey];
    if (inFlight != null) return inFlight;

    final future = _translateInternal(
      source: source,
      target: target,
      text: normalizedText,
    );
    _inFlight[cacheKey] = future;

    try {
      final translated = await future;
      _cache[cacheKey] = translated;
      return translated;
    } finally {
      _inFlight.remove(cacheKey);
    }
  }

  static String detectLanguageCode(String text) {
    return OnDeviceTranslationService.detectLanguageCode(text);
  }

  /// Decide whether a server-provided translation should be used as-is.
  /// If candidate text is effectively identical to source (common when
  /// translated fields are not actually translated), caller should fallback
  /// to dynamic translation.
  static bool shouldUseServerTranslation({
    required String sourceText,
    required String? candidateText,
    required String targetLanguageCode,
  }) {
    final candidate = candidateText?.trim() ?? '';
    if (candidate.isEmpty) return false;

    final normalizedTarget = _normalizeCode(targetLanguageCode);
    if (normalizedTarget == 'en') return true;

    final source = sourceText.trim();
    if (source.isEmpty) return true;

    final sameText =
        _normalizedForCompare(source) == _normalizedForCompare(candidate);
    if (!sameText) return true;

    // If source is already in target language, same text is expected.
    final sourceCode = detectLanguageCode(source);
    return sourceCode == normalizedTarget;
  }

  static Future<String> _translateInternal({
    required String source,
    required String target,
    required String text,
  }) async {
    final translated = await OnDeviceTranslationService.translate(
      text: text,
      sourceLanguageCode: source,
      targetLanguageCode: target,
    );
    final normalized = translated.trim();
    if (normalized.isEmpty) {
      debugPrint('[PostTranslationService] Empty translation fallback.');
      return text;
    }
    return normalized;
  }

  static String _normalizeCode(String code) {
    return code.trim().toLowerCase();
  }

  static String _normalizedForCompare(String text) {
    return text.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
  }

  static Future<void> clearCache() async {
    _cache.clear();
    _inFlight.clear();
    await OnDeviceTranslationService.clearCache();
  }

  /// Best-effort model warmup to reduce first-translation latency.
  /// Safe to call repeatedly; concurrent warmups are de-duplicated.
  static Future<void> warmUpForLanguage(String targetLanguageCode) async {
    final target = _normalizeCode(targetLanguageCode);
    if (!_supportedCodes.contains(target) || target == 'en') return;
    if (_modelWarmupsInFlight.contains(target)) return;

    _modelWarmupsInFlight.add(target);
    try {
      await OnDeviceTranslationService.downloadModel('en');
      await OnDeviceTranslationService.downloadModel(target);
    } catch (_) {
      // Best effort only.
    } finally {
      _modelWarmupsInFlight.remove(target);
    }
  }
}
