enum FeedSwipeDirection { forward, backward }

bool canEnableFeedCycle({
  required bool isPrimaryFeed,
  required int visibleCount,
  required bool hasMoreFeedPages,
}) {
  return isPrimaryFeed && visibleCount > 1 && !hasMoreFeedPages;
}

int? resolveCyclicTargetIndex({
  required int currentIndex,
  required int visibleCount,
  required FeedSwipeDirection direction,
  required bool cycleEnabled,
}) {
  if (!cycleEnabled || visibleCount < 2) return null;
  if (direction == FeedSwipeDirection.forward &&
      currentIndex == visibleCount - 1) {
    return 0;
  }
  if (direction == FeedSwipeDirection.backward && currentIndex == 0) {
    return visibleCount - 1;
  }
  return null;
}
