import 'package:flutter/material.dart';
import 'package:google_mlkit_translation/google_mlkit_translation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

/// Translation Service
/// Handles on-device text translation with caching
class TranslationService {
  static const String _cacheKey = 'translation_cache';

  final SharedPreferences _prefs;
  final Map<String, OnDeviceTranslator> _translators = {};
  Map<String, String> _cache = {};

  TranslationService(this._prefs) {
    _loadCache();
  }

  /// Initialize service
  static Future<TranslationService> init() async {
    final prefs = await SharedPreferences.getInstance();
    return TranslationService(prefs);
  }

  /// Load cached translations
  void _loadCache() {
    final cacheJson = _prefs.getString(_cacheKey);
    if (cacheJson != null) {
      _cache = Map<String, String>.from(jsonDecode(cacheJson));
    }
  }

  /// Save cache
  Future<void> _saveCache() async {
    await _prefs.setString(_cacheKey, jsonEncode(_cache));
  }

  /// Get cache key for translation
  String _getCacheKey(
    String text,
    String sourceLanguage,
    String targetLanguage,
  ) {
    return '${sourceLanguage}_${targetLanguage}_${text.hashCode}';
  }

  /// Get or create translator
  OnDeviceTranslator _getTranslator(
    TranslateLanguage source,
    TranslateLanguage target,
  ) {
    final key = '${source.bcpCode}_${target.bcpCode}';

    if (!_translators.containsKey(key)) {
      _translators[key] = OnDeviceTranslator(
        sourceLanguage: source,
        targetLanguage: target,
      );
    }

    return _translators[key]!;
  }

  /// Translate text
  /// Returns cached translation if available
  Future<String> translate({
    required String text,
    required String sourceLanguageCode,
    required String targetLanguageCode,
  }) async {
    // Check cache first
    final cacheKey = _getCacheKey(text, sourceLanguageCode, targetLanguageCode);
    if (_cache.containsKey(cacheKey)) {
      return _cache[cacheKey]!;
    }

    try {
      final source = _getTranslateLanguage(sourceLanguageCode);
      final target = _getTranslateLanguage(targetLanguageCode);

      final translator = _getTranslator(source, target);
      final translated = await translator.translateText(text);

      // Cache result
      _cache[cacheKey] = translated;
      await _saveCache();

      return translated;
    } catch (e) {
      debugPrint('Translation error: $e');
      return text; // Return original on error
    }
  }

  /// Map language code to TranslateLanguage
  TranslateLanguage _getTranslateLanguage(String code) {
    switch (code) {
      case 'te':
        return TranslateLanguage.telugu;
      case 'hi':
        return TranslateLanguage.hindi;
      case 'en':
      default:
        return TranslateLanguage.english;
    }
  }

  /// Detect source language (simple heuristic based on Unicode)
  String detectLanguage(String text) {
    if (text.isEmpty) return 'en';

    // Check for Telugu Unicode range (0C00-0C7F)
    final teluguPattern = RegExp(r'[\u0C00-\u0C7F]');
    if (teluguPattern.hasMatch(text)) return 'te';

    // Check for Hindi/Devanagari Unicode range (0900-097F)
    final hindiPattern = RegExp(r'[\u0900-\u097F]');
    if (hindiPattern.hasMatch(text)) return 'hi';

    return 'en';
  }

  /// Clean up translators
  void dispose() {
    for (final translator in _translators.values) {
      translator.close();
    }
    _translators.clear();
  }
}

/// Translate Button Widget
/// Shows inline translate button with loading state
class TranslateButton extends StatefulWidget {
  final String text;
  final String currentLanguageCode;
  final Function(String translatedText, bool isTranslated) onTranslate;

  const TranslateButton({
    super.key,
    required this.text,
    required this.currentLanguageCode,
    required this.onTranslate,
  });

  @override
  State<TranslateButton> createState() => _TranslateButtonState();
}

class _TranslateButtonState extends State<TranslateButton> {
  bool _isLoading = false;
  bool _isTranslated = false;
  TranslationService? _translationService;

  @override
  void initState() {
    super.initState();
    _initService();
  }

  Future<void> _initService() async {
    _translationService = await TranslationService.init();
  }

  Future<void> _toggleTranslation() async {
    if (_isTranslated) {
      // Toggle back to original
      setState(() => _isTranslated = false);
      widget.onTranslate(widget.text, false);
      return;
    }

    if (_translationService == null) return;

    setState(() => _isLoading = true);

    try {
      // Detect source language
      final sourceLanguage = _translationService!.detectLanguage(widget.text);

      // If already in target language, no need to translate
      if (sourceLanguage == widget.currentLanguageCode) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Content is already in selected language'),
            ),
          );
        }
        setState(() => _isLoading = false);
        return;
      }

      // Translate to current app language
      final translated = await _translationService!.translate(
        text: widget.text,
        sourceLanguageCode: sourceLanguage,
        targetLanguageCode: widget.currentLanguageCode,
      );

      setState(() {
        _isTranslated = true;
        _isLoading = false;
      });

      widget.onTranslate(translated, true);
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Translation failed: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: _isLoading ? null : _toggleTranslation,
      icon: _isLoading
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Icon(_isTranslated ? Icons.translate : Icons.g_translate, size: 16),
      label: Text(
        _isTranslated ? 'Show Original' : 'Translate',
        style: const TextStyle(fontSize: 12),
      ),
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        visualDensity: VisualDensity.compact,
      ),
    );
  }
}
