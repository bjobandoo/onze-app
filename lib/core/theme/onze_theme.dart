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
        color: OnzeColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
          side: BorderSide(color: OnzeColors.border, width: 1),
        ),
        elevation: 0,
        margin: EdgeInsets.zero,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: OnzeColors.surface,
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
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          textStyle: GoogleFonts.inter(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: OnzeColors.background,
        foregroundColor: OnzeColors.textPrimary,
        elevation: 0,
        centerTitle: false,
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
      // Display — títulos grandes de pantalla
      displayLarge: GoogleFonts.inter(
        fontSize: 28,
        fontWeight: FontWeight.w700,
        color: OnzeColors.textPrimary,
      ),
      // Heading — títulos de sección
      headlineMedium: GoogleFonts.inter(
        fontSize: 20,
        fontWeight: FontWeight.w600,
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
        fontSize: 15,
        fontWeight: FontWeight.w600,
        color: OnzeColors.textPrimary,
      ),
    );
  }
}
