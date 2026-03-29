import 'package:flutter/foundation.dart';
import 'package:google_mlkit_translation/google_mlkit_translation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// ML Kit on-device translation helper with memory + persistent cache.
class OnDeviceTranslationService {
  OnDeviceTranslationService._();

  static const Set<String> _supportedCodes = {'en', 'te', 'hi'};
  static const int _maxMemoryEntries = 800;
  static const String _cachePrefix = 'mlkit_tx_';

  static final Map<String, String> _memoryCache = {};
  static final Map<String, Future<String>> _inFlight = {};
  static final Map<String, OnDeviceTranslator> _translators = {};
  static final OnDeviceTranslatorModelManager _modelManager =
      OnDeviceTranslatorModelManager();

  static Future<String> translate({
    required String text,
    required String targetLanguageCode,
    String? sourceLanguageCode,
  }) async {
    final normalizedText = text.trim();
    if (normalizedText.isEmpty) return text;

    final target = _normalizeCode(targetLanguageCode);
    if (!_supportedCodes.contains(target)) return text;

    final source = _normalizeCode(sourceLanguageCode ?? detectLanguageCode(text));
    if (!_supportedCodes.contains(source) || source == target) return text;

    if (kIsWeb) {
      // ML Kit translation plugin is mobile-only.
      return text;
    }

    final cacheKey = _cacheKey(source: source, target: target, text: normalizedText);
    final mem = _memoryCache[cacheKey];
    if (mem != null) return mem;

    final persisted = await _getPersisted(cacheKey);
    if (persisted != null) {
      _putMemory(cacheKey, persisted);
      return persisted;
    }

    final running = _inFlight[cacheKey];
    if (running != null) return running;

    final future = _translateInternal(
      source: source,
      target: target,
      text: normalizedText,
    );
    _inFlight[cacheKey] = future;
    try {
      final translated = await future;
      _putMemory(cacheKey, translated);
      await _persist(cacheKey, translated);
      return translated;
    } finally {
      _inFlight.remove(cacheKey);
    }
  }

  static String detectLanguageCode(String text) {
    if (_teluguRegex.hasMatch(text)) return 'te';
    if (_hindiRegex.hasMatch(text)) return 'hi';
    return 'en';
  }

  static Future<bool> isModelDownloaded(String languageCode) async {
    final code = _normalizeCode(languageCode);
    final lang = _toTranslateLanguage(code);
    if (lang == null) return false;
    return _modelManager.isModelDownloaded(lang.bcpCode);
  }

  static Future<bool> downloadModel(String languageCode) async {
    final code = _normalizeCode(languageCode);
    final lang = _toTranslateLanguage(code);
    if (lang == null) return false;
    return _modelManager.downloadModel(lang.bcpCode);
  }

  static Future<bool> deleteModel(String languageCode) async {
    final code = _normalizeCode(languageCode);
    final lang = _toTranslateLanguage(code);
    if (lang == null) return false;
    return _modelManager.deleteModel(lang.bcpCode);
  }

  static Future<void> clearCache() async {
    _memoryCache.clear();
    _inFlight.clear();
    for (final translator in _translators.values) {
      translator.close();
    }
    _translators.clear();
  }

  static final RegExp _teluguRegex = RegExp(r'[\u0C00-\u0C7F]');
  static final RegExp _hindiRegex = RegExp(r'[\u0900-\u097F]');

  static Future<String> _translateInternal({
    required String source,
    required String target,
    required String text,
  }) async {
    final sourceLang = _toTranslateLanguage(source);
    final targetLang = _toTranslateLanguage(target);
    if (sourceLang == null || targetLang == null) return text;

    try {
      final translatorKey = '${sourceLang.bcpCode}->${targetLang.bcpCode}';
      final translator =
          _translators[translatorKey] ??
          OnDeviceTranslator(
            sourceLanguage: sourceLang,
            targetLanguage: targetLang,
          );
      _translators[translatorKey] = translator;

      final sourceReady = await _modelManager.isModelDownloaded(sourceLang.bcpCode);
      if (!sourceReady) {
        await _modelManager.downloadModel(sourceLang.bcpCode);
      }
      final targetReady = await _modelManager.isModelDownloaded(targetLang.bcpCode);
      if (!targetReady) {
        await _modelManager.downloadModel(targetLang.bcpCode);
      }

      final translated = await translator.translateText(text);
      final normalized = translated.trim();
      return normalized.isEmpty ? text : normalized;
    } catch (e) {
      debugPrint('[OnDeviceTranslationService] Translation failed: $e');
      return text;
    }
  }

  static TranslateLanguage? _toTranslateLanguage(String languageCode) {
    switch (languageCode) {
      case 'en':
        return TranslateLanguage.english;
      case 'te':
        return TranslateLanguage.telugu;
      case 'hi':
        return TranslateLanguage.hindi;
      default:
        return null;
    }
  }

  static String _normalizeCode(String code) {
    return code.trim().toLowerCase();
  }

  static String _cacheKey({
    required String source,
    required String target,
    required String text,
  }) {
    return '$source->$target:${text.hashCode}';
  }

  static void _putMemory(String key, String value) {
    _memoryCache[key] = value;
    while (_memoryCache.length > _maxMemoryEntries) {
      _memoryCache.remove(_memoryCache.keys.first);
    }
  }

  static Future<String?> _getPersisted(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final value = prefs.getString('$_cachePrefix$key');
      if (value == null || value.trim().isEmpty) return null;
      return value;
    } catch (_) {
      return null;
    }
  }

  static Future<void> _persist(String key, String value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('$_cachePrefix$key', value);
    } catch (_) {
      // Best-effort persistent cache.
    }
  }
}
