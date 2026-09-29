import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Dark palette
  static const Color darkScaffoldBg = Color(0xFF13131A);
  static const Color darkCardColor = Color(0xFF1E1E2A);
  static const Color darkCardBorder = Color(0xFF2D2D3E);

  // Light palette
  static const Color lightScaffoldBg = Color(0xFFF6F8FB);
  static const Color lightCardColor = Color(0xFFFFFFFF);
  static const Color lightCardBorder = Color(0xFFE2E8F0);

  // Default aliases (for backward compatibility)
  static const Color scaffoldBackgroundColor = darkScaffoldBg;
  static const Color cardColor = darkCardColor;

  // Accents
  static const Color primaryTeal = Color(0xFF0E7C7B);
  static const Color primaryTealLight = Color(0xFF149D9B);
  static const Color secondaryAmber = Color(0xFFD98E04);
  static const Color dangerousRed = Color(0xFFD32F2F);
  static const Color infoBlue = Color(0xFF2563EB);
  static const Color successGreen = Color(0xFF10B981);

  // Design System Standard Radiuses
  static const double borderRadius = 16.0;

  // Adaptive background gradient
  static Decoration get backgroundGradient => const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment.topRight,
          radius: 1.5,
          colors: [
            Color(0xFF1E1E2A),
            Color(0xFF13131A),
          ],
          stops: [0.0, 1.0],
        ),
      );

  static Decoration adaptiveBackgroundGradient(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (isDark) {
      return const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment.topRight,
          radius: 1.5,
          colors: [
            Color(0xFF1E1E2A),
            Color(0xFF13131A),
          ],
          stops: [0.0, 1.0],
        ),
      );
    }
    return const BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color(0xFFF1F5F9),
          Color(0xFFF8FAFC),
        ],
      ),
    );
  }

  // Dynamic Theme-Aware Helpers
  static Color getCardColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark ? darkCardColor : lightCardColor;
  }

  static Color getCardBorderColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark ? darkCardBorder : lightCardBorder;
  }

  static Color getScaffoldColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark ? darkScaffoldBg : lightScaffoldBg;
  }

  static Color getTextColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark ? Colors.white : const Color(0xFF0F172A);
  }

  static Color getSubtextColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark ? Colors.white70 : const Color(0xFF64748B);
  }

  // Soft Shadows
  static List<BoxShadow> get softShadows => [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.12),
          blurRadius: 20,
          offset: const Offset(0, 10),
        ),
      ];

  // Dark Theme
  static ThemeData get darkTheme {
    final base = ThemeData.dark();
    return base.copyWith(
      scaffoldBackgroundColor: darkScaffoldBg,
      primaryColor: primaryTeal,
      colorScheme: const ColorScheme.dark(
        primary: primaryTeal,
        secondary: secondaryAmber,
        error: dangerousRed,
        surface: darkCardColor,
        surfaceContainerHighest: Color(0xFF282838),
        onSurface: Colors.white,
      ),
      textTheme: GoogleFonts.soraTextTheme(base.textTheme).apply(
        bodyColor: Colors.white,
        displayColor: Colors.white,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: Colors.white),
        titleTextStyle: TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
      cardTheme: CardThemeData(
        color: darkCardColor,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(borderRadius),
          side: const BorderSide(color: darkCardBorder, width: 1),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: darkCardColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: darkCardBorder, width: 1),
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: darkCardColor,
        selectedItemColor: primaryTeal,
        unselectedItemColor: Colors.white60,
      ),
    );
  }

  // Light Theme
  static ThemeData get lightTheme {
    final base = ThemeData.light();
    return base.copyWith(
      scaffoldBackgroundColor: lightScaffoldBg,
      primaryColor: primaryTeal,
      colorScheme: const ColorScheme.light(
        primary: primaryTeal,
        secondary: secondaryAmber,
        error: dangerousRed,
        surface: lightCardColor,
        surfaceContainerHighest: Color(0xFFEDF2F7),
        onSurface: Color(0xFF0F172A),
      ),
      textTheme: GoogleFonts.soraTextTheme(base.textTheme).apply(
        bodyColor: const Color(0xFF0F172A),
        displayColor: const Color(0xFF0F172A),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: Color(0xFF0F172A)),
        titleTextStyle: TextStyle(
          color: Color(0xFF0F172A),
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
      cardTheme: CardThemeData(
        color: lightCardColor,
        elevation: 2,
        shadowColor: Colors.black.withValues(alpha: 0.05),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(borderRadius),
          side: const BorderSide(color: lightCardBorder, width: 1),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: lightCardColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: lightCardBorder, width: 1),
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: lightCardColor,
        selectedItemColor: primaryTeal,
        unselectedItemColor: Color(0xFF64748B),
      ),
    );
  }
}
