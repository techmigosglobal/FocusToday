import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Theme Service
/// Manages dark mode state with persistence
class ThemeService extends ChangeNotifier {
  static const String _keyDarkMode = 'dark_mode_enabled';
  final SharedPreferences _prefs;
  bool _isDarkMode = false;

  ThemeService(this._prefs) {
    _loadTheme();
  }

  /// Initialize service
  static Future<ThemeService> init() async {
    final prefs = await SharedPreferences.getInstance();
    return ThemeService(prefs);
  }

  /// Get current dark mode state
  bool get isDarkMode => _isDarkMode;

  /// Load saved theme preference
  void _loadTheme() {
    _isDarkMode = _prefs.getBool(_keyDarkMode) ?? false;
  }

  /// Toggle dark mode
  Future<void> toggleDarkMode() async {
    _isDarkMode = !_isDarkMode;
    notifyListeners();
    await _prefs.setBool(_keyDarkMode, _isDarkMode);
  }

  /// Set dark mode
  Future<void> setDarkMode(bool value) async {
    if (_isDarkMode != value) {
      _isDarkMode = value;
      notifyListeners();
      await _prefs.setBool(_keyDarkMode, value);
    }
  }
}
