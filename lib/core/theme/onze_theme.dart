import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'onze_colors.dart';
import 'onze_motion.dart';

/// Tema oscuro oficial de Onze — estilo "Stadium Night".
///
/// Display en Barlow Condensed, cuerpo en Barlow, superficies suaves
/// con radios generosos y acciones en forma de píldora.
abstract final class OnzeTheme {
  // Radios estándar del design system.
  static const double radiusCard = 22;
  static const double radiusRow = 18;
  static const double radiusInput = 16;
  static const double radiusDialog = 24;
  static const double radiusSheet = 28;

  /// Botones y chips son píldoras completas (StadiumBorder).
  static const double radiusPill = 999;

  static ThemeData get dark {
    final base = ThemeData.dark(useMaterial3: true);

    return base.copyWith(
      scaffoldBackgroundColor: OnzeColors.background,
      splashFactory: InkRipple.splashFactory,
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: <TargetPlatform, PageTransitionsBuilder>{
          TargetPlatform.android: OnzePageTransitionsBuilder(),
          TargetPlatform.iOS: OnzePageTransitionsBuilder(),
          TargetPlatform.windows: OnzePageTransitionsBuilder(),
          TargetPlatform.macOS: OnzePageTransitionsBuilder(),
          TargetPlatform.linux: OnzePageTransitionsBuilder(),
        },
      ),
      colorScheme: const ColorScheme.dark(
        surface: OnzeColors.surface,
        primary: OnzeColors.accent,
        secondary: OnzeColors.highlight,
        error: OnzeColors.error,
        onPrimary: OnzeColors.onAccent,
        onSurface: OnzeColors.textPrimary,
        onSecondary: OnzeColors.onAccent,
        onError: OnzeColors.textPrimary,
        outline: OnzeColors.border,
      ),
      textTheme: _buildTextTheme(base.textTheme),
      cardTheme: const CardThemeData(
        color: OnzeColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(radiusCard)),
          side: BorderSide(color: OnzeColors.border, width: 1),
        ),
        elevation: 0,
        margin: EdgeInsets.zero,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: OnzeColors.surfaceHigh,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusInput),
          borderSide: const BorderSide(color: OnzeColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusInput),
          borderSide: const BorderSide(color: OnzeColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusInput),
          borderSide: const BorderSide(color: OnzeColors.accent, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusInput),
          borderSide: const BorderSide(color: OnzeColors.error),
        ),
        labelStyle: const TextStyle(color: OnzeColors.textSecondary),
        hintStyle: const TextStyle(color: OnzeColors.textSecondary),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: OnzeColors.accent,
          foregroundColor: OnzeColors.onAccent,
          disabledBackgroundColor: OnzeColors.surfaceHigh,
          shape: const StadiumBorder(),
          minimumSize: const Size(double.infinity, 54),
          padding: const EdgeInsets.symmetric(horizontal: 24),
          textStyle: GoogleFonts.barlowCondensed(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: OnzeColors.accent,
          side: const BorderSide(color: Color(0x663BDC1E)),
          minimumSize: const Size(double.infinity, 54),
          shape: const StadiumBorder(),
          textStyle: GoogleFonts.barlowCondensed(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: OnzeColors.accent,
          shape: const StadiumBorder(),
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: OnzeColors.background,
        foregroundColor: OnzeColors.textPrimary,
        elevation: 0,
        centerTitle: false,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: GoogleFonts.barlowCondensed(
          fontSize: 22,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.8,
          color: OnzeColors.textPrimary,
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: OnzeColors.border,
        thickness: 1,
      ),
      chipTheme: const ChipThemeData(
        backgroundColor: OnzeColors.surface,
        labelStyle: TextStyle(color: OnzeColors.textPrimary),
        shape: StadiumBorder(),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: OnzeColors.surfaceHigh,
        contentTextStyle: GoogleFonts.barlow(
          fontSize: 14,
          color: OnzeColors.textPrimary,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusInput),
          side: const BorderSide(color: OnzeColors.border),
        ),
      ),
      dialogTheme: const DialogThemeData(
        backgroundColor: OnzeColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(radiusDialog)),
          side: BorderSide(color: OnzeColors.border),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: OnzeColors.surface,
        dragHandleColor: OnzeColors.border,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(radiusSheet)),
        ),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: OnzeColors.highlight,
      ),
      tabBarTheme: TabBarThemeData(
        indicatorColor: OnzeColors.highlight,
        labelColor: OnzeColors.textPrimary,
        unselectedLabelColor: OnzeColors.textSecondary,
        dividerColor: Colors.transparent,
        labelStyle: GoogleFonts.barlowCondensed(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.0,
        ),
        unselectedLabelStyle: GoogleFonts.barlowCondensed(
          fontSize: 15,
          fontWeight: FontWeight.w500,
          letterSpacing: 1.0,
        ),
      ),
    );
  }

  static TextTheme _buildTextTheme(TextTheme base) {
    return base.copyWith(
      // Hero — wordmark y títulos de pantalla principales
      displayLarge: GoogleFonts.barlowCondensed(
        fontSize: 30,
        fontWeight: FontWeight.w700,
        color: OnzeColors.textPrimary,
        letterSpacing: 0.5,
      ),
      // Headings
      headlineLarge: GoogleFonts.barlowCondensed(
        fontSize: 24,
        fontWeight: FontWeight.w700,
        color: OnzeColors.textPrimary,
        letterSpacing: 0.5,
      ),
      headlineMedium: GoogleFonts.barlowCondensed(
        fontSize: 19,
        fontWeight: FontWeight.w600,
        color: OnzeColors.textPrimary,
        letterSpacing: 0.6,
      ),
      // Body
      bodyLarge: GoogleFonts.barlow(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        color: OnzeColors.textPrimary,
      ),
      bodyMedium: GoogleFonts.barlow(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: OnzeColors.textPrimary,
      ),
      // Caption — metadatos, timestamps
      bodySmall: GoogleFonts.barlow(
        fontSize: 13,
        fontWeight: FontWeight.w400,
        color: OnzeColors.textSecondary,
      ),
      // Button
      labelLarge: GoogleFonts.barlowCondensed(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.8,
        color: OnzeColors.textPrimary,
      ),
      // Etiquetas ALL CAPS de sección (ESTADÍSTICAS, QUÉ QUIERES HACER, etc.)
      labelSmall: GoogleFonts.barlowCondensed(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        letterSpacing: 2.2,
        color: OnzeColors.accent,
      ),
    );
  }
}
