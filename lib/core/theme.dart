import 'package:flutter/material.dart';

class AppTheme {
  static const Color primaryYellow = Color(0xFFFFCC00);
  static const Color darkBg = Color(0xFF141414);
  static const Color lightBg = Color(0xFFF4F6F9);
  static const Color textDark = Color(0xFF1E2124);

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: lightBg,
      fontFamily: 'Roboto',
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryYellow,
        primary: primaryYellow,
        secondary: darkBg,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.black87),
        titleTextStyle: TextStyle(
          color: textDark,
          fontWeight: FontWeight.w900,
          fontSize: 18,
        ),
      ),
    );
  }
}
class AppColors {
  static const Color primaryGold = AppTheme.primaryYellow;
  static const Color deepBlack = AppTheme.darkBg;

  static const Color accentGreen = Color(0xFF2E7D32);
  static const Color surfaceWhite = Colors.white;
  static const Color borderLight = Color(0xFFD9DDE3);
  static const Color textMain = AppTheme.textDark;
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color backgroundLight = AppTheme.lightBg;
  static const Color lightGold = Color(0xFFFFF4C2);
  static const Color darkGold = Color(0xFF9A7600);
}