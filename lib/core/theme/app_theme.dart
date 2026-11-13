import 'package:material_ui/material_ui.dart';
import 'package:google_fonts/google_fonts.dart';

/// Tokens oficiales del Design System Cold2Hot (alineados con cold2hot-web-app).
/// Estética editorial limpia, colores sólidos de alto contraste y jerarquía táctil.
class AppColors {
  static const Color cold = Color(0xFF38BDF8);
  static const Color coldStrong = Color(0xFF0284C7);
  static const Color coldSoft = Color(0xFFE0F2FE);

  static const Color hot = Color(0xFFFD5701);
  static const Color hotStrong = Color(0xFFE04A00);
  static const Color hotSoft = Color(0xFFFFEFE6);

  static const Color ok = Color(0xFF10B981);
  static const Color okStrong = Color(0xFF047857);
  static const Color okSoft = Color(0xFFECFDF5);

  static const Color warn = Color(0xFFF59E0B);
  static const Color warnStrong = Color(0xFFB45309);
  static const Color warnSoft = Color(0xFFFFFBEB);

  static const Color danger = Color(0xFFEF4444);
  static const Color dangerStrong = Color(0xFFB91C1C);
  static const Color dangerSoft = Color(0xFFFEF2F2);

  static const Color ink = Color(0xFF0E1726);
  static const Color ink2 = Color(0xFF243044);
  static const Color muted = Color(0xFF64748B);
  static const Color line = Color(0xFFE8ECF2);

  static const Color bg = Color(0xFFFFFFFF);
  static const Color bgAlt = Color(0xFFF5F7FA);
  static const Color navy = Color(0xFF0E1726);
}

class AppTheme {
  static ThemeData get lightTheme {
    // TextTheme construido explícitamente con GoogleFonts.poppins para evitar
    // colisión de tipos con material_ui en Flutter 3.50.0 / google_fonts 9.x.
    final textTheme = TextTheme(
      displaySmall: GoogleFonts.poppins(
        fontSize: 32,
        fontWeight: FontWeight.w700,
        color: AppColors.ink,
        letterSpacing: -0.6,
      ),
      headlineMedium: GoogleFonts.poppins(
        fontSize: 24,
        fontWeight: FontWeight.w700,
        color: AppColors.ink,
        letterSpacing: -0.4,
      ),
      titleLarge: GoogleFonts.poppins(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: AppColors.ink,
      ),
      titleMedium: GoogleFonts.poppins(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: AppColors.ink,
      ),
      bodyLarge: GoogleFonts.poppins(
        fontSize: 15,
        fontWeight: FontWeight.w400,
        color: AppColors.ink,
      ),
      bodyMedium: GoogleFonts.poppins(
        fontSize: 13.5,
        fontWeight: FontWeight.w500,
        color: AppColors.ink2,
      ),
      bodySmall: GoogleFonts.poppins(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: AppColors.muted,
      ),
      labelLarge: GoogleFonts.poppins(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: AppColors.ink,
      ),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: AppColors.bgAlt,
      colorScheme: const ColorScheme.light(
        primary: AppColors.ink,
        onPrimary: Colors.white,
        secondary: AppColors.hot,
        onSecondary: Colors.white,
        error: AppColors.danger,
        onError: Colors.white,
        surface: AppColors.bg,
        onSurface: AppColors.ink,
      ),
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.bg,
        foregroundColor: AppColors.ink,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        titleTextStyle: GoogleFonts.poppins(
          fontSize: 19,
          fontWeight: FontWeight.w700,
          color: AppColors.ink,
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.bg,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: AppColors.line, width: 1),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.bg,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.line),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.ink, width: 1.6),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.danger, width: 1.4),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.ink,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(54),
          shape: const StadiumBorder(),
          textStyle: GoogleFonts.poppins(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.ink,
          minimumSize: const Size.fromHeight(50),
          side: const BorderSide(color: AppColors.line, width: 1.5),
          shape: const StadiumBorder(),
          textStyle: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.bg,
        surfaceTintColor: Colors.transparent,
        indicatorColor: AppColors.hotSoft,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return GoogleFonts.poppins(
            fontSize: 12,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected ? AppColors.ink : AppColors.muted,
          );
        }),
      ),
    );
  }

  static TextStyle mono({
    double fontSize = 15,
    FontWeight fontWeight = FontWeight.w600,
    Color color = AppColors.ink,
  }) {
    return GoogleFonts.jetBrainsMono(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
  }

  static TextStyle displayNum({
    double fontSize = 40,
    FontWeight fontWeight = FontWeight.w700,
    Color color = AppColors.ink,
  }) {
    return GoogleFonts.poppins(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      height: 1.0,
      letterSpacing: -1.0,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
  }
}
