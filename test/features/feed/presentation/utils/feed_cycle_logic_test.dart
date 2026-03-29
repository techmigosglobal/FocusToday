import 'package:flutter_test/flutter_test.dart';
import 'package:focus_today/features/feed/presentation/utils/feed_cycle_logic.dart';

void main() {
  group('canEnableFeedCycle', () {
    test('enabled only on primary feed when exhausted and multiple items', () {
      expect(
        canEnableFeedCycle(
          isPrimaryFeed: true,
          visibleCount: 5,
          hasMoreFeedPages: false,
        ),
        isTrue,
      );
      expect(
        canEnableFeedCycle(
          isPrimaryFeed: false,
          visibleCount: 5,
          hasMoreFeedPages: false,
        ),
        isFalse,
      );
      expect(
        canEnableFeedCycle(
          isPrimaryFeed: true,
          visibleCount: 1,
          hasMoreFeedPages: false,
        ),
        isFalse,
      );
      expect(
        canEnableFeedCycle(
          isPrimaryFeed: true,
          visibleCount: 5,
          hasMoreFeedPages: true,
        ),
        isFalse,
      );
    });
  });

  group('resolveCyclicTargetIndex', () {
    test('wraps forward from last to first', () {
      expect(
        resolveCyclicTargetIndex(
          currentIndex: 4,
          visibleCount: 5,
          direction: FeedSwipeDirection.forward,
          cycleEnabled: true,
        ),
        0,
      );
    });

    test('wraps backward from first to last', () {
      expect(
        resolveCyclicTargetIndex(
          currentIndex: 0,
          visibleCount: 5,
          direction: FeedSwipeDirection.backward,
          cycleEnabled: true,
        ),
        4,
      );
    });

    test('does not wrap when cycle disabled or non-boundary index', () {
      expect(
        resolveCyclicTargetIndex(
          currentIndex: 4,
          visibleCount: 5,
          direction: FeedSwipeDirection.forward,
          cycleEnabled: false,
        ),
        isNull,
      );
      expect(
        resolveCyclicTargetIndex(
          currentIndex: 2,
          visibleCount: 5,
          direction: FeedSwipeDirection.forward,
          cycleEnabled: true,
        ),
        isNull,
      );
      expect(
        resolveCyclicTargetIndex(
          currentIndex: 2,
          visibleCount: 5,
          direction: FeedSwipeDirection.backward,
          cycleEnabled: true,
        ),
        isNull,
      );
    });
  });
}
