import 'package:flutter_test/flutter_test.dart';
import 'package:focus_today/core/utils/pagination_controller.dart';

void main() {
  group('PaginationController', () {
    test('initial state is correct', () {
      final controller = PaginationController<int>();
      expect(controller.items, isEmpty);
      expect(controller.hasMore, isTrue);
      expect(controller.isLoading, isFalse);
      expect(controller.isEmpty, isTrue);
      expect(controller.itemCount, 0);
    });

    test('loadNext loads first page', () async {
      final controller = PaginationController<int>();
      int stateChanges = 0;

      await controller.loadNext(
        fetcher: (page, limit) async =>
            List.generate(20, (i) => i + (page - 1) * 20),
        onStateChanged: () => stateChanges++,
      );

      expect(controller.items.length, 20);
      expect(controller.hasMore, isTrue);
      expect(controller.isLoading, isFalse);
      expect(stateChanges, 2); // loading start + loading end
    });

    test('loadNext stops when fewer items than pageSize', () async {
      final controller = PaginationController<int>();

      await controller.loadNext(
        fetcher: (page, limit) async => [1, 2, 3], // Less than 20
      );

      expect(controller.items.length, 3);
      expect(controller.hasMore, isFalse);
    });

    test('loadNext ignores if already loading', () async {
      final controller = PaginationController<int>();
      int fetchCalls = 0;

      // Start two loads simultaneously
      final f1 = controller.loadNext(
        fetcher: (page, limit) async {
          fetchCalls++;
          await Future.delayed(const Duration(milliseconds: 50));
          return [1, 2, 3];
        },
      );
      final f2 = controller.loadNext(
        fetcher: (page, limit) async {
          fetchCalls++;
          return [4, 5, 6];
        },
      );

      await Future.wait([f1, f2]);
      expect(fetchCalls, 1); // Second call was ignored
    });

    test('loadNext does nothing when no more items', () async {
      final controller = PaginationController<int>();

      // Load less than pageSize to mark hasMore = false
      await controller.loadNext(fetcher: (page, limit) async => [1]);

      expect(controller.hasMore, isFalse);

      int fetchCalls = 0;
      await controller.loadNext(
        fetcher: (page, limit) async {
          fetchCalls++;
          return [];
        },
      );

      expect(fetchCalls, 0); // No fetch because hasMore is false
    });

    test('refresh resets and reloads', () async {
      final controller = PaginationController<int>();

      await controller.loadNext(fetcher: (page, limit) async => [1, 2, 3]);
      expect(controller.items.length, 3);

      await controller.refresh(fetcher: (page, limit) async => [10, 20]);
      expect(controller.items.length, 2);
      expect(controller.items.first, 10);
    });

    test('prepend adds item to beginning', () async {
      final controller = PaginationController<int>();

      await controller.loadNext(fetcher: (page, limit) async => [2, 3]);

      controller.prepend(1);
      expect(controller.items, [1, 2, 3]);
    });

    test('removeWhere removes matching items', () async {
      final controller = PaginationController<int>();

      await controller.loadNext(
        fetcher: (page, limit) async => [1, 2, 3, 4, 5],
      );

      controller.removeWhere((item) => item.isEven);
      expect(controller.items, [1, 3, 5]);
    });

    test('handles fetch errors gracefully', () async {
      final controller = PaginationController<int>();

      await controller.loadNext(
        fetcher: (page, limit) async => throw Exception('Network error'),
      );

      expect(controller.items, isEmpty);
      expect(controller.isLoading, isFalse);
      // hasMore remains true so user can retry
      expect(controller.hasMore, isTrue);
    });

    test('pagination loads sequential pages', () async {
      final controller = PaginationController<int>();

      // Page 1
      await controller.loadNext(
        fetcher: (page, limit) async {
          expect(page, 1);
          return List.generate(20, (i) => i);
        },
      );

      // Page 2
      await controller.loadNext(
        fetcher: (page, limit) async {
          expect(page, 2);
          return List.generate(20, (i) => 20 + i);
        },
      );

      expect(controller.items.length, 40);
      expect(controller.items.first, 0);
      expect(controller.items.last, 39);
    });

    test('dispose clears items', () async {
      final controller = PaginationController<int>();

      await controller.loadNext(fetcher: (page, limit) async => [1, 2, 3]);

      controller.dispose();
      expect(controller.items, isEmpty);
    });
  });
}
