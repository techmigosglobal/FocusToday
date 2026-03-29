import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Language Service
/// Manages app language and provides translations
enum AppLanguage {
  english,
  telugu,
  hindi;

  static AppLanguage fromCode(String code) {
    switch (code) {
      case 'te':
        return AppLanguage.telugu;
      case 'hi':
        return AppLanguage.hindi;
      default:
        return AppLanguage.english;
    }
  }
}

extension AppLanguageExtension on AppLanguage {
  String get code {
    switch (this) {
      case AppLanguage.english:
        return 'en';
      case AppLanguage.telugu:
        return 'te';
      case AppLanguage.hindi:
        return 'hi';
    }
  }

  String get displayName {
    switch (this) {
      case AppLanguage.english:
        return 'EN';
      case AppLanguage.telugu:
        return 'తెలుగు';
      case AppLanguage.hindi:
        return 'हिंदी';
    }
  }
}

class LanguageService extends ChangeNotifier {
  static const String _keyLanguage = 'app_language';
  static LanguageService? _instance;
  static Future<LanguageService>? _inFlightInit;
  final SharedPreferences _prefs;
  AppLanguage _currentLanguage = AppLanguage.english;

  LanguageService(this._prefs) {
    _loadLanguage();
  }

  /// Initialize service
  static Future<LanguageService> init() async {
    final cached = _instance;
    if (cached != null) return cached;

    final existingInit = _inFlightInit;
    if (existingInit != null) return existingInit;

    _inFlightInit = SharedPreferences.getInstance().then((prefs) {
      final service = LanguageService(prefs);
      _instance = service;
      _inFlightInit = null;
      return service;
    });
    return _inFlightInit!;
  }

  /// Get current language
  AppLanguage get currentLanguage => _currentLanguage;

  /// Load saved language
  void _loadLanguage() {
    final code = _prefs.getString(_keyLanguage) ?? 'en';
    _currentLanguage = AppLanguage.fromCode(code);
  }

  /// Set language
  Future<void> setLanguage(AppLanguage language) async {
    _currentLanguage = language;
    notifyListeners();
    // Persist async
    await _prefs.setString(_keyLanguage, language.code);
  }

  /// Cycle to next language
  Future<void> cycleLanguage() async {
    final next = AppLanguage
        .values[(_currentLanguage.index + 1) % AppLanguage.values.length];
    await setLanguage(next);
  }
}
