import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  static const Color primaryYellow = Color(0xFFFFC400);
  static const Color goldBright = Color(0xFFFFE047);
  static const Color goldMid = Color(0xFFF5A623);
  static const Color goldDeep = Color(0xFFD9820B);
  static const Color obsidianDark = Color(0xFF111111);
  static const Color obsidianCard = Color(0xFF1C1915);
  static const Color darkBg = Color(0xFF141414);
  static const Color lightBg = Color(0xFFFAF9F6);
  static const Color metallicGold = Color(0xFFC9A24D);
  static const Color textDark = Color(0xFF141311);

  static bool get _isTestEnvironment =>
      WidgetsBinding.instance.runtimeType.toString().contains('Test');

  static TextStyle displayFont(TextStyle base) {
    if (_isTestEnvironment) return base;
    GoogleFonts.config.allowRuntimeFetching = true;
    return GoogleFonts.outfit(textStyle: base);
  }

  static ThemeData get lightTheme {
    final isTest = _isTestEnvironment;
    if (isTest) {
      GoogleFonts.config.allowRuntimeFetching = false;
    }
    final baseTheme = ThemeData.light(useMaterial3: true);
    final bodyTextTheme = isTest
        ? baseTheme.textTheme.apply(
            bodyColor: textDark,
            displayColor: textDark,
          )
        : GoogleFonts.interTextTheme(baseTheme.textTheme).apply(
            bodyColor: textDark,
            displayColor: textDark,
          );
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: lightBg,
      textTheme: bodyTextTheme.copyWith(
        headlineLarge: displayFont(
          const TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: textDark),
        ),
        headlineMedium: displayFont(
          const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: textDark),
        ),
        titleLarge: displayFont(
          const TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: textDark),
        ),
      ),
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryYellow,
        primary: primaryYellow,
        secondary: obsidianDark,
        onPrimary: obsidianDark,
        surface: Colors.white,
      ),
      visualDensity: VisualDensity.standard,
      cardTheme: CardThemeData(
        color: AppColors.surfaceWhite,
        surfaceTintColor: Colors.transparent,
        shadowColor: const Color(0x16916A16),
        elevation: 1,
        margin: const EdgeInsets.symmetric(vertical: AppSpace.xs),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          side: const BorderSide(color: AppColors.borderLight, width: 1),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: Colors.white,
        selectedColor: AppColors.lightGold,
        labelStyle: const TextStyle(
          fontSize: 12,
          color: textDark,
          fontWeight: FontWeight.w600,
        ),
        side: const BorderSide(color: AppColors.borderLight),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: textDark,
          minimumSize: const Size(48, 48),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: textDark,
          minimumSize: const Size(48, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        floatingLabelStyle: WidgetStateTextStyle.resolveWith((states) {
          if (states.contains(WidgetState.error)) {
            return const TextStyle(color: AppColors.error);
          }
          if (states.contains(WidgetState.disabled)) {
            return const TextStyle(color: AppColors.textSecondary);
          }
          return const TextStyle(color: textDark);
        }),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: AppColors.borderLight, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: AppTheme.goldDeep, width: 1.5),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryYellow,
          foregroundColor: darkBg,
          minimumSize: const Size(48, 48),
          elevation: 1,
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: darkBg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.borderLight,
        thickness: 1,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: lightBg,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        elevation: 1,
        iconTheme: const IconThemeData(color: Colors.black87),
        titleTextStyle: displayFont(
          const TextStyle(
            color: textDark,
            fontWeight: FontWeight.w900,
            fontSize: 20,
          ),
        ),
      ),
    );
  }
}

abstract final class AppSpace {
  static const double xs = 4, sm = 8, md = 16, lg = 24, xl = 32;
}

abstract final class AppRadius {
  static const double sm = 10, md = 14, lg = 20;
}

class AppColors {
  static const Color error = Color(0xFFB3261E);
  static const Color mutedSurface = Color(0xFFF3EFE4);
  static const Color primaryGold = AppTheme.primaryYellow;
  static const Color deepBlack = AppTheme.darkBg;

  static const Color accentGreen = Color(0xFF2E7D32);
  static const Color surfaceWhite = Color(0xFFFAF9F6);
  static const Color borderLight = Color(0xFFC9A24D);
  static const Color textMain = AppTheme.textDark;
  static const Color textSecondary = Color(0xFF666057);
  static const Color backgroundLight = AppTheme.lightBg;
  static const Color lightGold = Color(0xFFFFF4C2);
  static const Color darkGold = Color(0xFF9E6300);
}
