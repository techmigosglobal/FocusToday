import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:focus_today/core/services/cache_service.dart';

void main() {
  group('CacheService', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await CacheService.init();
      await CacheService.clearAll();
    });

    test('set and get returns cached data', () async {
      await CacheService.set('test_key', {'name': 'test', 'value': 42});
      final result = CacheService.get('test_key');
      expect(result, isNotNull);
      expect(result['name'], 'test');
      expect(result['value'], 42);
    });

    test('get returns null for non-existent key', () {
      final result = CacheService.get('non_existent_key');
      expect(result, isNull);
    });

    test('get returns null for expired data', () async {
      await CacheService.set('expired_key', 'data');

      // With zero duration, data is immediately expired
      await Future.delayed(const Duration(milliseconds: 10));
      final result = CacheService.get('expired_key', maxAge: Duration.zero);
      expect(result, isNull);
    });

    test('get returns data within maxAge', () async {
      await CacheService.set('valid_key', 'data');
      final result = CacheService.get(
        'valid_key',
        maxAge: const Duration(minutes: 5),
      );
      expect(result, 'data');
    });

    test('invalidate removes specific key', () async {
      await CacheService.set('to_remove', 'value');
      await CacheService.set('to_keep', 'keep');

      await CacheService.invalidate('to_remove');

      expect(CacheService.get('to_remove'), isNull);
      expect(CacheService.get('to_keep'), 'keep');
    });

    test('invalidatePrefix removes matching keys', () async {
      await CacheService.set('feed_user1', 'data1');
      await CacheService.set('feed_user2', 'data2');
      await CacheService.set('profile_user1', 'profile');

      await CacheService.invalidatePrefix('feed_');

      expect(CacheService.get('feed_user1'), isNull);
      expect(CacheService.get('feed_user2'), isNull);
      expect(CacheService.get('profile_user1'), 'profile');
    });

    test('clearAll removes everything', () async {
      await CacheService.set('key1', 'val1');
      await CacheService.set('key2', 'val2');
      await CacheService.set('key3', 'val3');

      await CacheService.clearAll();

      expect(CacheService.get('key1'), isNull);
      expect(CacheService.get('key2'), isNull);
      expect(CacheService.get('key3'), isNull);
    });

    test('caches complex nested data', () async {
      final complexData = {
        'users': [
          {'id': '1', 'name': 'User 1'},
          {'id': '2', 'name': 'User 2'},
        ],
        'total': 2,
        'page': 1,
      };

      await CacheService.set('complex', complexData);
      final result = CacheService.get('complex');

      expect(result['users'], isList);
      expect(result['users'].length, 2);
      expect(result['total'], 2);
    });

    test('overwriting key updates data', () async {
      await CacheService.set('key', 'original');
      await CacheService.set('key', 'updated');

      final result = CacheService.get('key');
      expect(result, 'updated');
    });

    test('stats returns entry counts', () async {
      await CacheService.set('a', 1);
      await CacheService.set('b', 2);

      final stats = CacheService.stats;
      expect(stats['memoryEntries'], 2);
      expect(stats['diskEntries'], 2);
    });
  });
}
