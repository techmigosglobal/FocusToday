import 'dart:async';
import 'package:flutter/foundation.dart';

/// Reusable debouncer for search, scroll events, text input, etc.
/// Ensures an action is only executed after a specified delay since the last call.
class Debouncer {
  final Duration delay;
  Timer? _timer;

  Debouncer({this.delay = const Duration(milliseconds: 300)});

  /// Run [action] after [delay], cancelling any previous pending call.
  void run(VoidCallback action) {
    _timer?.cancel();
    _timer = Timer(delay, action);
  }

  /// Cancel any pending action without executing it.
  void cancel() {
    _timer?.cancel();
  }

  /// Whether a timer is currently pending.
  bool get isPending => _timer?.isActive ?? false;

  /// Clean up resources. Always call in widget's dispose().
  void dispose() {
    _timer?.cancel();
    _timer = null;
  }
}
