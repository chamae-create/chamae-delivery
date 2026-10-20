import 'package:flutter/material.dart';

class AppTheme {
  static const Color primaryYellow = Color(0xFFFFCC00);
  static const Color darkBg = Color(0xFF141414);
  static const Color lightBg = Color(0xFFFAF7F0);
  static const Color textDark = Color(0xFF191816);

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: lightBg,
      fontFamily: 'Roboto',
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryYellow,
        primary: primaryYellow,
        secondary: darkBg,
        onPrimary: darkBg,
        surface: Colors.white,
      ),
      visualDensity: VisualDensity.standard,
      cardTheme: CardThemeData(
        color: AppColors.surfaceWhite,
        surfaceTintColor: Colors.transparent,
        shadowColor: const Color(0x189A7600),
        elevation: 1,
        margin: const EdgeInsets.symmetric(vertical: AppSpace.xs),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
            side: const BorderSide(color: AppColors.borderLight)),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: Colors.white,
        selectedColor: AppColors.lightGold,
        labelStyle:
            const TextStyle(color: textDark, fontWeight: FontWeight.w600),
        side: const BorderSide(color: AppColors.borderLight),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.sm)),
      ),
      textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
              foregroundColor: textDark, minimumSize: const Size(48, 48))),
      outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
              foregroundColor: textDark,
              minimumSize: const Size(48, 48),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md)))),
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
        contentPadding: const EdgeInsets.all(AppSpace.md),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.md)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: AppColors.borderLight),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryYellow,
          foregroundColor: darkBg,
          minimumSize: const Size(48, 48),
          elevation: 1,
          textStyle: const TextStyle(
              fontFamily: 'Roboto', fontSize: 15, fontWeight: FontWeight.w700),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.md)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: darkBg,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md)),
      ),
      dividerTheme:
          const DividerThemeData(color: AppColors.borderLight, thickness: 1),
      appBarTheme: const AppBarTheme(
        backgroundColor: lightBg,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        elevation: 1,
        iconTheme: IconThemeData(color: Colors.black87),
        titleTextStyle: TextStyle(
          fontFamily: 'Roboto',
          color: textDark,
          fontWeight: FontWeight.w900,
          fontSize: 22,
        ),
      ),
    );
  }
}

abstract final class AppSpace {
  static const double xs = 4, sm = 8, md = 16, lg = 24, xl = 32;
}

abstract final class AppRadius {
  static const double sm = 12, md = 20, lg = 28;
}

class AppColors {
  static const Color error = Color(0xFFB3261E);
  static const Color mutedSurface = Color(0xFFF0EFEB);
  static const Color primaryGold = AppTheme.primaryYellow;
  static const Color deepBlack = AppTheme.darkBg;

  static const Color accentGreen = Color(0xFF2E7D32);
  static const Color surfaceWhite = Colors.white;
  static const Color borderLight = Color(0xFFECE2CF);
  static const Color textMain = AppTheme.textDark;
  static const Color textSecondary = Color(0xFF69655E);
  static const Color backgroundLight = AppTheme.lightBg;
  static const Color lightGold = Color(0xFFFFF4C2);
  static const Color darkGold = Color(0xFF886000);
}
