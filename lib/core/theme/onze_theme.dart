import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'onze_colors.dart';

/// Tema oscuro oficial de Onze.
abstract final class OnzeTheme {
  static ThemeData get dark {
    final base = ThemeData.dark(useMaterial3: true);

    return base.copyWith(
      scaffoldBackgroundColor: OnzeColors.background,
      colorScheme: const ColorScheme.dark(
        surface: OnzeColors.surface,
        primary: OnzeColors.accent,
        secondary: OnzeColors.highlight,
        error: OnzeColors.error,
        onPrimary: OnzeColors.textPrimary,
        onSurface: OnzeColors.textPrimary,
        onSecondary: OnzeColors.background,
        onError: OnzeColors.textPrimary,
        outline: OnzeColors.border,
      ),
      textTheme: _buildTextTheme(base.textTheme),
      cardTheme: const CardThemeData(
        color: OnzeColors.surfaceHigh,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
          side: BorderSide(color: OnzeColors.border, width: 1),
        ),
        elevation: 0,
        margin: EdgeInsets.zero,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: OnzeColors.surfaceHigh,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: OnzeColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: OnzeColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: OnzeColors.accent, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: OnzeColors.error),
        ),
        labelStyle: const TextStyle(color: OnzeColors.textSecondary),
        hintStyle: const TextStyle(color: OnzeColors.textSecondary),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: OnzeColors.accent,
          foregroundColor: OnzeColors.textPrimary,
          disabledBackgroundColor: OnzeColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          minimumSize: const Size(double.infinity, 56),
          padding: const EdgeInsets.symmetric(horizontal: 24),
          textStyle: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.5,
          ),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: OnzeColors.background,
        foregroundColor: OnzeColors.textPrimary,
        elevation: 0,
        centerTitle: false,
        surfaceTintColor: Colors.transparent,
      ),
      dividerTheme: const DividerThemeData(
        color: OnzeColors.border,
        thickness: 1,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: OnzeColors.surface,
        labelStyle: const TextStyle(color: OnzeColors.textPrimary),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
      ),
    );
  }

  static TextTheme _buildTextTheme(TextTheme base) {
    return base.copyWith(
      // Hero — wordmark y títulos de pantalla principales
      displayLarge: GoogleFonts.inter(
        fontSize: 28,
        fontWeight: FontWeight.w700,
        color: OnzeColors.textPrimary,
        letterSpacing: -0.5,
      ),
      // Headings
      headlineLarge: GoogleFonts.inter(
        fontSize: 22,
        fontWeight: FontWeight.w700,
        color: OnzeColors.textPrimary,
        letterSpacing: -0.3,
      ),
      headlineMedium: GoogleFonts.inter(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: OnzeColors.textPrimary,
      ),
      // Body
      bodyLarge: GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        color: OnzeColors.textPrimary,
      ),
      bodyMedium: GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: OnzeColors.textPrimary,
      ),
      // Caption — metadatos, timestamps
      bodySmall: GoogleFonts.inter(
        fontSize: 13,
        fontWeight: FontWeight.w400,
        color: OnzeColors.textSecondary,
      ),
      // Button
      labelLarge: GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.5,
        color: OnzeColors.textPrimary,
      ),
      // Etiquetas ALL CAPS de sección (ESTADÍSTICAS, QUÉ QUIERES HACER, etc.)
      labelSmall: GoogleFonts.inter(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 2.0,
        color: OnzeColors.textSecondary,
      ),
    );
  }
}
