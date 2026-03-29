import 'package:flutter/material.dart';

/// Focus Today Color Palette
/// Design System: Empathy Canvas – Calming & Professional
class AppColors {
  // Private constructor to prevent instantiation
  AppColors._();

  // ==================== Primary Brand Colors ====================

  /// Primary Brand Color - Trust, stability, professional depth
  /// Usage: App bar, primary buttons, active states, key icons, links
  static const Color primary = Color(0xFF1C375C);
  static const Color primaryDark = Color(0xFF132B4A);

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

  /// Background color for dark mode — deep navy-charcoal for depth
  static const Color backgroundDark = Color(0xFF0F1419);

  /// Surface color for dark mode — slightly elevated with blue undertone
  static const Color surfaceDark = Color(0xFF1A2332);

  /// Elevated surface for cards in dark mode
  static const Color surfaceDarkElevated = Color(0xFF243447);

  /// Primary text color for dark mode — warm white for readability
  static const Color textPrimaryDark = Color(0xFFF0F4F8);

  /// Secondary text color for dark mode — muted blue-gray
  static const Color textSecondaryDark = Color(0xFF8899A6);
  static const Color textMutedDark = Color(0xFF7E8FA1);

  // ==================== Premium Semantic Tokens ====================

  /// Strong trust marker and verification accents.
  static const Color trustBlue = Color(0xFF2F6FED);

  /// Surface layers for premium cards/sheets in light mode.
  static const Color surfaceTier1 = Color(0xFFFFFFFF);
  static const Color surfaceTier2 = Color(0xFFF4F7FB);
  static const Color surfaceTier3 = Color(0xFFE9EEF6);

  /// Surface layers for premium cards/sheets in dark mode.
  static const Color surfaceTier1Dark = Color(0xFF162131);
  static const Color surfaceTier2Dark = Color(0xFF1E2D41);
  static const Color surfaceTier3Dark = Color(0xFF25384F);

  static const Color likeStrong = Color(0xFFDC2F45);
  static const Color bookmarkGold = Color(0xFFE3A621);

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

  /// Primary gradient colors
  static const List<Color> primaryGradient = [primary, Color(0xFF2A4A7C)];

  /// Dark mode gradient for cards/surfaces
  static const List<Color> darkSurfaceGradient = [
    surfaceDark,
    Color(0xFF1E2D3F),
  ];

  // ==================== Context-Aware Helpers ====================
  // Use these instead of the static constants to support Dark mode.

  /// Adaptive background color
  static Color backgroundOf(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
      ? backgroundDark
      : backgroundLight;

  /// Adaptive surface color
  static Color surfaceOf(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? surfaceDark : surface;

  /// Adaptive primary text color
  static Color textPrimaryOf(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
      ? textPrimaryDark
      : textPrimary;

  /// Adaptive secondary text color
  static Color textSecondaryOf(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
      ? textSecondaryDark
      : textSecondary;

  static Color textMutedOf(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
      ? textMutedDark
      : const Color(0xFF6A7380);

  /// Adaptive divider color
  static Color dividerOf(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
      ? textSecondaryDark.withValues(alpha: 0.2)
      : divider;

  static Color surfaceTier1Of(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
      ? surfaceTier1Dark
      : surfaceTier1;

  static Color surfaceTier2Of(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
      ? surfaceTier2Dark
      : surfaceTier2;

  static Color surfaceTier3Of(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
      ? surfaceTier3Dark
      : surfaceTier3;

  static Color primaryOf(BuildContext context) =>
      Theme.of(context).colorScheme.primary;

  static Color onPrimaryOf(BuildContext context) =>
      Theme.of(context).colorScheme.onPrimary;

  static Color successOf(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
      ? const Color(0xFF7FD7B5)
      : const Color(0xFF2E7D62);

  static Color warningOf(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
      ? const Color(0xFFFFB470)
      : const Color(0xFFE07A5F);

  static Color infoOf(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
      ? const Color(0xFF8AB4FF)
      : const Color(0xFF2F6FED);

  static Color errorOf(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
      ? const Color(0xFFFF8A80)
      : const Color(0xFFD67A5F);

  static Color destructiveBgOf(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
      ? const Color(0xFF5D2525)
      : const Color(0xFFFFECE8);

  static Color destructiveFgOf(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
      ? const Color(0xFFFFB3AE)
      : const Color(0xFFC62828);

  static Color iconStrongOf(BuildContext context) => textPrimaryOf(context);

  static Color iconMutedOf(BuildContext context) =>
      textSecondaryOf(context).withValues(alpha: 0.88);

  static Color overlayStrongOf(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
      ? Colors.black.withValues(alpha: 0.70)
      : Colors.black.withValues(alpha: 0.55);

  static Color overlaySoftOf(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
      ? Colors.black.withValues(alpha: 0.42)
      : Colors.black.withValues(alpha: 0.26);
}
