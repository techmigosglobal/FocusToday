import 'package:flutter/services.dart';

/// Centralized haptic & feedback service for consistent UX across the app.
/// Use instead of calling HapticFeedback directly in widgets.
class FeedbackService {
  FeedbackService._();

  /// Light tap — button presses, toggles, minor selections
  static void lightTap() => HapticFeedback.lightImpact();

  /// Medium tap — confirmations, major selections
  static void mediumTap() => HapticFeedback.mediumImpact();

  /// Heavy tap — important/destructive actions
  static void heavyTap() => HapticFeedback.heavyImpact();

  /// Selection changed — tabs, pickers, segmented controls
  static void selection() => HapticFeedback.selectionClick();

  /// Success — post approved, profile saved, action completed
  static void success() => HapticFeedback.mediumImpact();

  /// Warning — before destructive actions, important alerts
  static void warning() => HapticFeedback.heavyImpact();

  /// Error — double-pulse vibration for error feedback
  static Future<void> error() async {
    HapticFeedback.heavyImpact();
    await Future.delayed(const Duration(milliseconds: 100));
    HapticFeedback.heavyImpact();
  }

  /// Like/Bookmark toggle — satisfying light feedback
  static void toggle() => HapticFeedback.lightImpact();

  /// Pull-to-refresh trigger
  static void refresh() => HapticFeedback.mediumImpact();
}
