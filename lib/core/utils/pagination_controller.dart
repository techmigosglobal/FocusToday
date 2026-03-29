import 'package:flutter/material.dart';

/// Generic pagination controller for infinite scroll lists.
///
/// Usage:
/// ```dart
/// final paginator = PaginationController<Post>();
/// await paginator.loadNext(fetcher: (page, limit) => repo.getPosts(page, limit));
/// ```
class PaginationController<T> {
  static const int defaultPageSize = 20;

  final List<T> _items = [];
  int _currentPage = 1;
  bool _hasMore = true;
  bool _isLoading = false;

  /// All loaded items
  List<T> get items => List.unmodifiable(_items);

  /// Whether there are more pages to load
  bool get hasMore => _hasMore;

  /// Whether a page is currently being fetched
  bool get isLoading => _isLoading;

  /// Whether there are no items and loading is complete
  bool get isEmpty => _items.isEmpty && !_isLoading;

  /// Total items loaded so far
  int get itemCount => _items.length;

  /// Load next page of items
  Future<void> loadNext({
    required Future<List<T>> Function(int page, int limit) fetcher,
    int pageSize = defaultPageSize,
    VoidCallback? onStateChanged,
  }) async {
    if (_isLoading || !_hasMore) return;

    _isLoading = true;
    onStateChanged?.call();

    try {
      final newItems = await fetcher(_currentPage, pageSize);
      _items.addAll(newItems);
      _hasMore = newItems.length >= pageSize;
      _currentPage++;
    } catch (e) {
      debugPrint('[Pagination] Error loading page $_currentPage: $e');
    } finally {
      _isLoading = false;
      onStateChanged?.call();
    }
  }

  /// Reset and reload from page 1
  Future<void> refresh({
    required Future<List<T>> Function(int page, int limit) fetcher,
    int pageSize = defaultPageSize,
    VoidCallback? onStateChanged,
  }) async {
    _items.clear();
    _currentPage = 1;
    _hasMore = true;
    _isLoading = false;
    await loadNext(
      fetcher: fetcher,
      pageSize: pageSize,
      onStateChanged: onStateChanged,
    );
  }

  /// Add a single item to the beginning (e.g., after creating a new post)
  void prepend(T item) {
    _items.insert(0, item);
  }

  /// Remove an item by predicate
  void removeWhere(bool Function(T) test) {
    _items.removeWhere(test);
  }

  /// Clean up resources
  void dispose() {
    _items.clear();
  }
}
