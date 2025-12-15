import 'package:flutter/material.dart';

/// Responsive Helper - Provides utilities for responsive and adaptive layouts
/// Handles different screen sizes and orientations
class ResponsiveHelper {
  final BuildContext context;

  ResponsiveHelper(this.context);

  /// Screen breakpoints
  static const double mobileBreakpoint = 600;
  static const double tabletBreakpoint = 900;
  static const double desktopBreakpoint = 1200;

  /// Get screen width
  double get screenWidth => MediaQuery.of(context).size.width;

  /// Get screen height
  double get screenHeight => MediaQuery.of(context).size.height;

  /// Check if device is mobile
  bool get isMobile => screenWidth < mobileBreakpoint;

  /// Check if device is tablet
  bool get isTablet =>
      screenWidth >= mobileBreakpoint && screenWidth < desktopBreakpoint;

  /// Check if device is desktop
  bool get isDesktop => screenWidth >= desktopBreakpoint;

  /// Check if device is small mobile (< 360px width)
  bool get isSmallMobile => screenWidth < 360;

  /// Check if orientation is portrait
  bool get isPortrait =>
      MediaQuery.of(context).orientation == Orientation.portrait;

  /// Check if orientation is landscape
  bool get isLandscape =>
      MediaQuery.of(context).orientation == Orientation.landscape;

  /// Get responsive value based on screen size
  /// Example: responsive(mobile: 12, tablet: 16, desktop: 20)
  T responsive<T>({
    required T mobile,
    T? tablet,
    T? desktop,
  }) {
    if (isDesktop && desktop != null) {
      return desktop;
    } else if (isTablet && tablet != null) {
      return tablet;
    } else {
      return mobile;
    }
  }

  /// Get responsive font size
  /// Base size is for mobile (360px width)
  double fontSize(double baseSize) {
    if (isSmallMobile) {
      return baseSize * 0.9;
    } else if (isTablet) {
      return baseSize * 1.2;
    } else if (isDesktop) {
      return baseSize * 1.4;
    }
    return baseSize;
  }

  /// Get responsive width percentage
  /// value: 0.0 to 1.0 (percentage of screen width)
  double widthPercent(double value) {
    return screenWidth * value;
  }

  /// Get responsive height percentage
  /// value: 0.0 to 1.0 (percentage of screen height)
  double heightPercent(double value) {
    return screenHeight * value;
  }

  /// Get responsive spacing
  double spacing(double baseSpacing) {
    if (isSmallMobile) {
      return baseSpacing * 0.8;
    } else if (isTablet) {
      return baseSpacing * 1.3;
    } else if (isDesktop) {
      return baseSpacing * 1.5;
    }
    return baseSpacing;
  }

  /// Get responsive padding
  EdgeInsets padding({
    double? all,
    double? horizontal,
    double? vertical,
    double? left,
    double? top,
    double? right,
    double? bottom,
  }) {
    if (all != null) {
      final value = spacing(all);
      return EdgeInsets.all(value);
    }

    return EdgeInsets.only(
      left: spacing(left ?? horizontal ?? 0),
      top: spacing(top ?? vertical ?? 0),
      right: spacing(right ?? horizontal ?? 0),
      bottom: spacing(bottom ?? vertical ?? 0),
    );
  }

  /// Get responsive icon size
  double iconSize(double baseSize) {
    if (isSmallMobile) {
      return baseSize * 0.9;
    } else if (isTablet) {
      return baseSize * 1.3;
    } else if (isDesktop) {
      return baseSize * 1.5;
    }
    return baseSize;
  }

  /// Get number of grid columns based on screen size
  int gridColumns({
    int mobile = 2,
    int tablet = 3,
    int desktop = 4,
  }) {
    if (isDesktop) {
      return desktop;
    } else if (isTablet) {
      return tablet;
    } else {
      return mobile;
    }
  }

  /// Get grid cross axis count for posts/bookmarks
  int get postsGridColumns {
    if (isSmallMobile) return 2;
    if (isTablet) return 4;
    if (isDesktop) return 6;
    return 3; // Default mobile
  }

  /// Get responsive border radius
  double borderRadius(double baseRadius) {
    if (isTablet) {
      return baseRadius * 1.2;
    } else if (isDesktop) {
      return baseRadius * 1.4;
    }
    return baseRadius;
  }

  /// Get minimum tap target size (for accessibility)
  double get minTapTarget => 48.0;

  /// Get responsive card height
  double cardHeight(double baseHeight) {
    if (isSmallMobile) {
      return baseHeight * 0.9;
    } else if (isTablet) {
      return baseHeight * 1.2;
    }
    return baseHeight;
  }

  /// Get responsive aspect ratio
  double get contentCardAspectRatio {
    if (isPortrait) {
      return isSmallMobile ? 0.55 : 0.6; // 60/40 split
    } else {
      return 1.2; // Wider in landscape
    }
  }

  /// Get safe area padding
  EdgeInsets get safeAreaPadding => MediaQuery.of(context).padding;

  /// Get bottom navigation height
  double get bottomNavHeight {
    return spacing(isTablet ? 70 : 60);
  }

  /// Get app bar height
  double get appBarHeight {
    return spacing(isTablet ? 64 : 56);
  }
}

/// Extension on BuildContext for easy access to ResponsiveHelper
extension ResponsiveExtension on BuildContext {
  ResponsiveHelper get responsive => ResponsiveHelper(this);
}
