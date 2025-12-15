import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// EagleTV Typography System
/// Font Family: Plus Jakarta Sans
/// Line height: 1.4-1.6x font size
class AppTextStyles {
  // Private constructor
  AppTextStyles._();

  // ==================== Font Weights ====================
  
  static const FontWeight regular = FontWeight.w400;      // Body, captions
  static const FontWeight medium = FontWeight.w500;       // Body emphasis
  static const FontWeight semiBold = FontWeight.w600;     // Subheadings
  static const FontWeight bold = FontWeight.w700;         // Headings
  static const FontWeight extraBold = FontWeight.w800;    // H1-H3

  // ==================== Font Sizes ====================
  
  static const double h1Size = 30.0;         // Line height: 1.4x = 42
  static const double h2Size = 24.0;         // Line height: 1.5x = 36
  static const double h3Size = 20.0;         // Line height: 1.5x = 30
  static const double h4Size = 18.0;         // Line height: 1.5x = 27
  static const double bodySize = 16.0;       // Line height: 1.5x = 24
  static const double body2Size = 14.0;      // Line height: 1.5x = 21
  static const double captionSize = 12.0;    // Line height: 1.4x = 16.8

  // ==================== Line Heights ====================
  
  static const double lineHeightHeading = 1.4;
  static const double lineHeightBody = 1.5;
  static const double lineHeightCompact = 1.3;

  // ==================== Text Styles ====================
  
  /// Display Large - H1 (32sp, ExtraBold)
  static TextStyle displayLarge(Color color) => GoogleFonts.plusJakartaSans(
        fontSize: 32.0,
        fontWeight: extraBold,
        color: color,
        height: lineHeightHeading,
      );

  /// Display Medium - H2 (28sp, ExtraBold)
  static TextStyle displayMedium(Color color) => GoogleFonts.plusJakartaSans(
        fontSize: 28.0,
        fontWeight: extraBold,
        color: color,
        height: lineHeightHeading,
      );

  /// Display Small - H3 (24sp, Bold)
  static TextStyle displaySmall(Color color) => GoogleFonts.plusJakartaSans(
        fontSize: h2Size,
        fontWeight: bold,
        color: color,
        height: lineHeightBody,
      );

  /// Headline Medium - H4 (20sp, SemiBold)
  static TextStyle headlineMedium(Color color) => GoogleFonts.plusJakartaSans(
        fontSize: h3Size,
        fontWeight: semiBold,
        color: color,
        height: lineHeightBody,
      );

  /// Title Large - H5 (18sp, SemiBold)
  static TextStyle titleLarge(Color color) => GoogleFonts.plusJakartaSans(
        fontSize: h4Size,
        fontWeight: semiBold,
        color: color,
        height: lineHeightBody,
      );

  /// Body Large - Body text (16sp, Regular)
  static TextStyle bodyLarge(Color color) => GoogleFonts.plusJakartaSans(
        fontSize: bodySize,
        fontWeight: regular,
        color: color,
        height: lineHeightBody,
      );

  /// Body Medium - Secondary body (14sp, Regular)
  static TextStyle bodyMedium(Color color) => GoogleFonts.plusJakartaSans(
        fontSize: body2Size,
        fontWeight: regular,
        color: color,
        height: lineHeightBody,
      );

  /// Label Large - Buttons (16sp, SemiBold)
  static TextStyle labelLarge(Color color) => GoogleFonts.plusJakartaSans(
        fontSize: bodySize,
        fontWeight: semiBold,
        color: color,
      );

  /// Body Small - Captions (12sp, Regular)
  static TextStyle bodySmall(Color color) => GoogleFonts.plusJakartaSans(
        fontSize: captionSize,
        fontWeight: regular,
        color: color,
        height: lineHeightHeading,
      );

  // ==================== Specialized Styles ====================
  
  /// Card headline style (Bold, 20sp)
  static TextStyle cardHeadline(Color color) => GoogleFonts.plusJakartaSans(
        fontSize: h3Size,
        fontWeight: bold,
        color: color,
        height: lineHeightCompact,
      );

  /// Category label style (Small caps, 12sp, Medium)
  static TextStyle categoryLabel(Color color) => GoogleFonts.plusJakartaSans(
        fontSize: captionSize,
        fontWeight: medium,
        color: color,
        letterSpacing: 0.5,
      );

  /// Button text style (SemiBold, 16sp)
  static TextStyle buttonText(Color color) => GoogleFonts.plusJakartaSans(
        fontSize: bodySize,
        fontWeight: semiBold,
        color: color,
        letterSpacing: 0.2,
      );

  /// App bar title style (SemiBold, 20sp)
  static TextStyle appBarTitle(Color color) => GoogleFonts.plusJakartaSans(
        fontSize: h3Size,
        fontWeight: semiBold,
        color: color,
      );
}
