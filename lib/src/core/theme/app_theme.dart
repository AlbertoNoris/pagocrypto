import 'package:flutter/material.dart';

class AppTheme {
  // Updated color scheme
  static const Color backgroundColor = Color(
    0xFF2a7afb,
  ); // Bright blue background
  static const Color surfaceColor = Color(0xFF153D80); // Dark blue boxes/cards
  static const Color primaryColor = Color(0xFF153D80); // Dark blue for buttons
  static const Color secondaryColor = Color(0xFF153D80); // Dark blue
  static const Color textColor = Colors.white; // White text
  static const Color accentColor = Color(
    0xFF4A90E2,
  ); // Lighter blue for accents

  // Aptos font family with fallbacks
  static const String fontFamily = 'Aptos';

  static final ThemeData
  lightTheme = ThemeData.light(useMaterial3: true).copyWith(
    colorScheme: ColorScheme.fromSeed(
      seedColor: primaryColor,
      secondary: secondaryColor,
      brightness: Brightness.dark,
      surface: surfaceColor,
      onSurface: textColor,
    ),
    scaffoldBackgroundColor: backgroundColor,
    textTheme: const TextTheme(
      displayLarge: TextStyle(fontFamily: fontFamily, color: textColor),
      displayMedium: TextStyle(fontFamily: fontFamily, color: textColor),
      displaySmall: TextStyle(fontFamily: fontFamily, color: textColor),
      headlineLarge: TextStyle(fontFamily: fontFamily, color: textColor),
      headlineMedium: TextStyle(fontFamily: fontFamily, color: textColor),
      headlineSmall: TextStyle(fontFamily: fontFamily, color: textColor),
      titleLarge: TextStyle(fontFamily: fontFamily, color: textColor),
      titleMedium: TextStyle(fontFamily: fontFamily, color: textColor),
      titleSmall: TextStyle(fontFamily: fontFamily, color: textColor),
      bodyLarge: TextStyle(fontFamily: fontFamily, color: textColor),
      bodyMedium: TextStyle(fontFamily: fontFamily, color: textColor),
      bodySmall: TextStyle(fontFamily: fontFamily, color: textColor),
      labelLarge: TextStyle(fontFamily: fontFamily, color: textColor),
      labelMedium: TextStyle(fontFamily: fontFamily, color: textColor),
      labelSmall: TextStyle(fontFamily: fontFamily, color: textColor),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: backgroundColor,
      elevation: 0,
      titleTextStyle: TextStyle(
        fontFamily: fontFamily,
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: textColor,
      ),
      iconTheme: IconThemeData(color: textColor),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: surfaceColor,
      foregroundColor: textColor,
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(color: textColor),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: surfaceColor,
        foregroundColor: textColor,
        textStyle: const TextStyle(
          fontFamily: fontFamily,
          //fontWeight: FontWeight.w600,
        ),
        padding: const EdgeInsets.symmetric(vertical: 20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: surfaceColor,
      labelStyle: const TextStyle(
        fontFamily: fontFamily,
        color: textColor,
        fontWeight: FontWeight.w500,
      ),
      hintStyle: TextStyle(
        fontFamily: fontFamily,
        color: textColor.withValues(alpha: 0.6),
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: textColor.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: textColor.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: accentColor, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    ),
    cardTheme: CardThemeData(
      color: surfaceColor,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: surfaceColor,
      contentTextStyle: const TextStyle(
        fontFamily: fontFamily,
        color: textColor,
        fontWeight: FontWeight.w500,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
  );
}
