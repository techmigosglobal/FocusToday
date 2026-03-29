import 'package:flutter/material.dart';

/// Focus Today Spacing and Dimension Constants
/// Base unit: 8dp — Mobile-first responsive design system
class AppDimensions {
  // Private constructor
  AppDimensions._();

  // ==================== Spacing (Base unit: 8dp) ====================

  static const double spacingXXS = 2.0;
  static const double spacingXS = 4.0;
  static const double spacingS = 8.0;
  static const double spacingM = 16.0;
  static const double spacingL = 24.0;
  static const double spacingXL = 32.0;
  static const double spacingXXL = 48.0;

  // ==================== Screen Padding ====================

  static const double screenPaddingHorizontal = 16.0;
  static const double screenPaddingVertical = 16.0;
  static const double cardPadding = 14.0;
  static const double sectionSpacing = 20.0;

  /// Standard edge insets for screen content
  static const EdgeInsets screenPadding = EdgeInsets.symmetric(
    horizontal: screenPaddingHorizontal,
    vertical: screenPaddingVertical,
  );

  /// Horizontal-only screen padding (common for lists/scrolls)
  static const EdgeInsets screenPaddingH = EdgeInsets.symmetric(
    horizontal: screenPaddingHorizontal,
  );

  // ==================== Border Radius ====================

  /// Small components (tags, badges)
  static const double borderRadiusXS = 6.0;

  /// Card border radius
  static const double borderRadiusCard = 12.0;

  /// Input field border radius
  static const double borderRadiusInput = 12.0;

  /// Primary/CTA button border radius
  static const double borderRadiusButton = 24.0;

  /// Chips/Tags border radius
  static const double borderRadiusChip = 16.0;

  /// Bottom sheets and modals (top corners only)
  static const double borderRadiusBottomSheet = 24.0;

  /// Large containers (onboarding cards, hero areas)
  static const double borderRadiusLarge = 20.0;

  // ==================== Elevation ====================

  /// Card elevation (soft shadow)
  static const double elevationCard = 2.0;

  /// Floating action button elevation
  static const double elevationFAB = 4.0;

  /// Modal/Dialog elevation
  static const double elevationModal = 8.0;

  // ==================== Icon Sizes ====================

  static const double iconXSmall = 16.0;
  static const double iconSmall = 20.0;
  static const double iconMedium = 24.0;
  static const double iconLarge = 32.0;
  static const double iconXLarge = 40.0;

  // ==================== Touch Targets ====================

  /// Minimum touch target size (accessibility - WCAG 2.5.5)
  static const double minTouchTarget = 48.0;

  /// Comfortable touch target for primary actions
  static const double comfortableTouchTarget = 56.0;

  // ==================== Avatar Sizes ====================

  static const double avatarSmall = 32.0;
  static const double avatarMedium = 48.0;
  static const double avatarLarge = 80.0;
  static const double avatarXLarge = 120.0;

  // ==================== Feed Card ====================

  /// Feed card height (85-90% of screen)
  static const double feedCardHeightFactor = 0.87;

  /// Action bar height
  static const double actionBarHeight = 56.0;

  // ==================== Bottom Navigation ====================

  static const double bottomNavHeight = 64.0;

  /// Bottom navigation icon size
  static const double bottomNavIconSize = 24.0;

  // ==================== App Bar ====================

  static const double appBarHeight = 56.0;

  // ==================== Bottom Sheet ====================

  /// Bottom sheet drag handle
  static const double dragHandleWidth = 40.0;
  static const double dragHandleHeight = 4.0;

  // ==================== Responsive Helpers ====================

  /// Whether the current screen width qualifies as tablet (>= 600dp)
  static bool isTablet(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= 600;

  /// Whether the screen is very small (< 360dp)
  static bool isSmallScreen(BuildContext context) =>
      MediaQuery.sizeOf(context).width < 360;

  /// Max content width for centered layouts on wide screens
  static double maxContentWidth(BuildContext context) =>
      isTablet(context) ? 480.0 : double.infinity;

  /// Responsive grid cross-axis count based on screen width
  static int responsiveGridCount(
    BuildContext context, {
    double itemWidth = 130,
  }) {
    final width = MediaQuery.sizeOf(context).width;
    return (width / itemWidth).floor().clamp(3, 6);
  }

  /// Responsive logo size (constrained for tablets)
  static double responsiveLogoSize(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    return (width * 0.3).clamp(80.0, 160.0);
  }

  /// Responsive horizontal padding
  static double responsivePadding(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    if (width >= 600) return 24.0;
    if (width < 360) return 12.0;
    return 16.0;
  }
}
