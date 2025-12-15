import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

/// Search History Service
/// Manages recent search queries
class SearchHistoryService {
  static const String _keySearchHistory = 'search_history';
  static const int _maxHistoryItems = 10;

  final SharedPreferences _prefs;

  SearchHistoryService(this._prefs);

  /// Initialize service
  static Future<SearchHistoryService> init() async {
    final prefs = await SharedPreferences.getInstance();
    return SearchHistoryService(prefs);
  }

  /// Get search history
  List<String> getHistory() {
    final historyJson = _prefs.getString(_keySearchHistory);
    if (historyJson == null) return [];

    try {
      final List<dynamic> decoded = json.decode(historyJson);
      return decoded.cast<String>();
    } catch (_) {
      return [];
    }
  }

  /// Add search query to history
  Future<void> addToHistory(String query) async {
    if (query.trim().isEmpty) return;

    final history = getHistory();

    // Remove if already exists
    history.remove(query);

    // Add to beginning
    history.insert(0, query);

    // Keep only max items
    if (history.length > _maxHistoryItems) {
      history.removeRange(_maxHistoryItems, history.length);
    }

    // Save
    await _prefs.setString(_keySearchHistory, json.encode(history));
  }

  /// Remove specific item from history
  Future<void> removeFromHistory(String query) async {
    final history = getHistory();
    history.remove(query);
    await _prefs.setString(_keySearchHistory, json.encode(history));
  }

  /// Clear all history
  Future<void> clearHistory() async {
    await _prefs.remove(_keySearchHistory);
  }
}
