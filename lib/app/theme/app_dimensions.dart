/// EagleTV Spacing and Dimension Constants
/// Base unit: 8dp
class AppDimensions {
  // Private constructor
  AppDimensions._();

  // ==================== Spacing (Base unit: 8dp) ====================
  
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

  // ==================== Border Radius ====================
  
  /// Card border radius
  static const double borderRadiusCard = 8.0;
  
  /// Input field border radius
  static const double borderRadiusInput = 10.0;
  
  /// Primary/CTA button border radius
  static const double borderRadiusButton = 20.0;
  
  /// Chips/Tags border radius
  static const double borderRadiusChip = 16.0;
  
  /// Bottom sheets and modals (top corners only)
  static const double borderRadiusBottomSheet = 24.0;

  // ==================== Elevation ====================
  
  /// Card elevation (soft shadow)
  static const double elevationCard = 3.0;
  
  /// Floating action button elevation
  static const double elevationFAB = 6.0;
  
  /// Modal/Dialog elevation
  static const double elevationModal = 8.0;

  // ==================== Icon Sizes ====================
  
  static const double iconSmall = 20.0;
  static const double iconMedium = 24.0;
  static const double iconLarge = 32.0;

  // ==================== Touch Targets ====================
  
  /// Minimum touch target size (accessibility)
  static const double minTouchTarget = 48.0;

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
  
  static const double bottomNavHeight = 60.0;

  // ==================== App Bar ====================
  
  static const double appBarHeight = 56.0;
}
