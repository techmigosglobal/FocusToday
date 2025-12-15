import 'package:flutter/material.dart';

/// EagleTV Color Palette
/// Design System: Empathy Canvas – Calming & Professional
class AppColors {
  // Private constructor to prevent instantiation
  AppColors._();

  // ==================== Primary Brand Colors ====================
  
  /// Primary Brand Color - Trust, stability, professional depth
  /// Usage: App bar, primary buttons, active states, key icons, links
  static const Color primary = Color(0xFF1C375C);

  /// Secondary Brand Color - Calm, empathy, balance
  /// Usage: Highlights, success states, selected cards, progress indicators
  static const Color secondary = Color(0xFFA4C3B2);

  /// Accent Color - CTA emphasis
  /// Usage: CTA emphasis, warnings, important actions, notification dots
  /// Rule: Use sparingly (≤10% of visible UI)
  static const Color accent = Color(0xFFE07A5F);

  // ==================== Light Mode Colors ====================
  
  /// Background color for light mode
  /// Usage: App background, screens, scaffold
  static const Color backgroundLight = Color(0xFFE9EBF0);

  /// Surface color for cards and elevated elements
  /// Usage: Cards, modals, sheets, dialogs
  static const Color surface = Color(0xFFFFFFFF);

  /// Alias for background (light mode)
  static const Color background = backgroundLight;

  /// Primary text color for light mode
  /// Usage: Main text, headings
  static const Color textPrimary = Color(0xFF333333);

  /// Secondary text color for light mode
  /// Usage: Subtitles, captions, less emphasized text
  static const Color textSecondary = Color(0xFF757575);

  /// Divider and border color
  /// Usage: Subtle separations only
  static const Color divider = Color(0xFFE0E0E0);

  // ==================== Dark Mode Colors ====================
  
  /// Background color for dark mode
  static const Color backgroundDark = Color(0xFF1F1F1F);

  /// Surface color for dark mode
  static const Color surfaceDark = Color(0xFF2A2A2A);

  /// Primary text color for dark mode
  static const Color textPrimaryDark = Color(0xFFFFFFFF);

  /// Secondary text color for dark mode
  static const Color textSecondaryDark = Color(0xFFBDBDBD);

  // ==================== Feedback States ====================
  
  /// Success state color (same as secondary)
  static const Color success = secondary;

  /// Warning/Attention color (same as accent)
  static const Color warning = accent;

  /// Error state color (muted red, lower saturation)
  static const Color error = Color(0xFFD67A5F);

  // ==================== Special Purpose Colors ====================
  
  /// Offline indicator pill color
  static const Color offlineIndicator = secondary;

  /// Like button color
  static const Color likeColor = accent;

  /// Bookmark button color
  static const Color bookmarkColor = primary;

  /// Toast/Snackbar background
  static const Color toastBackground = Color(0xFF333333);

  /// Toast/Snackbar text
  static const Color toastText = Color(0xFFFFFFFF);

  // ==================== Gradient Stops (If needed in future) ====================
  // Note: Current design system avoids gradients, but keeping for extensibility
  
  /// Primary gradient colors (currently unused)
  static const List<Color> primaryGradient = [primary, Color(0xFF2A4A7C)];
}
