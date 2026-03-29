import 'package:flutter_test/flutter_test.dart';
import 'package:focus_today/core/utils/debouncer.dart';

void main() {
  group('Debouncer', () {
    test('executes action after delay', () async {
      final debouncer = Debouncer(delay: const Duration(milliseconds: 100));
      int count = 0;

      debouncer.run(() => count++);
      expect(count, 0); // Not yet executed
      expect(debouncer.isPending, isTrue);

      await Future.delayed(const Duration(milliseconds: 150));
      expect(count, 1); // Now executed
      expect(debouncer.isPending, isFalse);

      debouncer.dispose();
    });

    test('cancels previous action on rapid calls', () async {
      final debouncer = Debouncer(delay: const Duration(milliseconds: 100));
      int count = 0;

      debouncer.run(() => count++); // Will be cancelled
      debouncer.run(() => count++); // Will be cancelled
      debouncer.run(() => count++); // This one runs

      await Future.delayed(const Duration(milliseconds: 150));
      expect(count, 1); // Only the last one executed

      debouncer.dispose();
    });

    test('cancel stops pending action', () async {
      final debouncer = Debouncer(delay: const Duration(milliseconds: 100));
      int count = 0;

      debouncer.run(() => count++);
      debouncer.cancel();

      await Future.delayed(const Duration(milliseconds: 150));
      expect(count, 0); // Cancelled before execution
      expect(debouncer.isPending, isFalse);

      debouncer.dispose();
    });

    test('dispose cancels pending action', () async {
      final debouncer = Debouncer(delay: const Duration(milliseconds: 100));
      int count = 0;

      debouncer.run(() => count++);
      debouncer.dispose();

      await Future.delayed(const Duration(milliseconds: 150));
      expect(count, 0); // Disposed before execution
    });

    test('can run again after previous action completes', () async {
      final debouncer = Debouncer(delay: const Duration(milliseconds: 50));
      int count = 0;

      debouncer.run(() => count++);
      await Future.delayed(const Duration(milliseconds: 100));
      expect(count, 1);

      debouncer.run(() => count++);
      await Future.delayed(const Duration(milliseconds: 100));
      expect(count, 2);

      debouncer.dispose();
    });

    test('isPending reflects timer state', () {
      final debouncer = Debouncer(delay: const Duration(milliseconds: 100));

      expect(debouncer.isPending, isFalse);
      debouncer.run(() {});
      expect(debouncer.isPending, isTrue);
      debouncer.cancel();
      expect(debouncer.isPending, isFalse);

      debouncer.dispose();
    });
  });
}
