import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Two-tier cache service: in-memory (fast) + disk (persistent).
/// Use for API response caching to reduce network calls and improve UX.
/// Memory cache is capped at [_maxMemoryEntries] with LRU eviction.
class CacheService {
  CacheService._();

  /// Maximum number of entries in the in-memory cache.
  static const int _maxMemoryEntries = 200;

  /// Insertion-ordered map; newest entries are at the end.
  static final Map<String, _CacheEntry> _memory = {};
  static SharedPreferences? _prefs;

  /// Initialize disk cache. Call once at app startup.
  static Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  /// Get cached data. Returns null if expired or missing.
  static dynamic get(
    String key, {
    Duration maxAge = const Duration(minutes: 5),
  }) {
    // Check memory first (fastest)
    final memEntry = _memory[key];
    if (memEntry != null && !memEntry.isExpired(maxAge)) {
      // Move to end (most-recently-used) for LRU ordering.
      _memory.remove(key);
      _memory[key] = memEntry;
      return memEntry.data;
    }
    // Remove expired entry if present.
    if (memEntry != null) _memory.remove(key);

    // Fallback to disk cache
    if (_prefs == null) return null;
    final diskJson = _prefs!.getString('cache_$key');
    final diskTs = _prefs!.getInt('cache_ts_$key');
    if (diskJson != null && diskTs != null) {
      final age = DateTime.now().millisecondsSinceEpoch - diskTs;
      if (age < maxAge.inMilliseconds) {
        try {
          final data = jsonDecode(diskJson);
          // Promote to memory cache
          _memory[key] = _CacheEntry(
            data,
            DateTime.fromMillisecondsSinceEpoch(diskTs),
          );
          return data;
        } catch (e) {
          debugPrint('[CacheService] Failed to decode disk cache for $key: $e');
        }
      }
    }
    return null;
  }

  /// Store data in both memory and disk cache.
  static Future<void> set(String key, dynamic data) async {
    final now = DateTime.now();

    // If key already exists, remove so re-insert goes to end (LRU).
    _memory.remove(key);
    _memory[key] = _CacheEntry(data, now);

    // Evict oldest entries if over capacity.
    while (_memory.length > _maxMemoryEntries) {
      _memory.remove(_memory.keys.first);
    }

    if (_prefs != null) {
      try {
        await _prefs!.setString('cache_$key', jsonEncode(data));
        await _prefs!.setInt('cache_ts_$key', now.millisecondsSinceEpoch);
      } catch (e) {
        debugPrint('[CacheService] Failed to write disk cache for $key: $e');
      }
    }
  }

  /// Invalidate a specific cache entry.
  static Future<void> invalidate(String key) async {
    _memory.remove(key);
    await _prefs?.remove('cache_$key');
    await _prefs?.remove('cache_ts_$key');
  }

  /// Invalidate all keys matching a prefix.
  static Future<void> invalidatePrefix(String prefix) async {
    _memory.removeWhere((k, _) => k.startsWith(prefix));
    if (_prefs != null) {
      final keys = _prefs!
          .getKeys()
          .where((k) => k.startsWith('cache_$prefix'))
          .toList();
      for (final k in keys) {
        await _prefs!.remove(k);
      }
      // Also remove timestamps
      final tsKeys = _prefs!
          .getKeys()
          .where((k) => k.startsWith('cache_ts_$prefix'))
          .toList();
      for (final k in tsKeys) {
        await _prefs!.remove(k);
      }
    }
  }

  /// Clear all cached data.
  static Future<void> clearAll() async {
    _memory.clear();
    if (_prefs != null) {
      final keys = _prefs!
          .getKeys()
          .where((k) => k.startsWith('cache_'))
          .toList();
      for (final k in keys) {
        await _prefs!.remove(k);
      }
    }
  }

  /// Get cache statistics (for debugging)
  static Map<String, int> get stats => {
    'memoryEntries': _memory.length,
    'diskEntries':
        _prefs
            ?.getKeys()
            .where((k) => k.startsWith('cache_') && !k.startsWith('cache_ts_'))
            .length ??
        0,
  };
}

class _CacheEntry {
  final dynamic data;
  final DateTime createdAt;

  _CacheEntry(this.data, this.createdAt);

  bool isExpired(Duration maxAge) =>
      DateTime.now().difference(createdAt) > maxAge;
}
