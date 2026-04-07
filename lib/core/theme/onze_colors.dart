import 'package:flutter/material.dart';

/// Paleta de colores oficial de Onze.
///
/// Usar siempre estas constantes. Nunca hardcodear valores hex en widgets.
abstract final class OnzeColors {
  /// Fondo principal (modo oscuro).
  static const Color background = Color(0xFF000000);

  /// Superficies secundarias: cards, inputs, drawers.
  static const Color surface = Color(0xFF3A3A3C);

  /// Color primario de marca (verde oscuro).
  static const Color primary = Color(0xFF004101);

  /// Acento principal: botones primarios, íconos activos.
  static const Color accent = Color(0xFF008001);

  /// Acento brillante: estados activos, badges, CTAs.
  static const Color highlight = Color(0xFF00BF00);

  /// Texto principal.
  static const Color textPrimary = Color(0xFFFFFFFF);

  /// Texto secundario (60% opacidad sobre fondo).
  static const Color textSecondary = Color(0x99EBEBF5);

  /// Error.
  static const Color error = Color(0xFFFF3B30);

  /// Advertencia / tarjeta amarilla.
  static const Color warning = Color(0xFFFFCC00);

  /// Borde sutil para cards.
  static const Color border = Color(0xFF3A3A3C);
}
