import 'package:flutter/material.dart';

/// Paleta de colores oficial de Onze — estilo "Stadium Night".
///
/// Verde césped sobre carbón verdoso, superficies suaves.
/// Usar siempre estas constantes. Nunca hardcodear valores hex en widgets.
abstract final class OnzeColors {
  /// Fondo principal: negro puro.
  static const Color background = Color(0xFF000000);

  /// Superficies secundarias: cards, sheets, drawers.
  static const Color surface = Color(0xFF151B14);

  /// Superficie elevada (sobre surface): inputs, cards destacadas.
  static const Color surfaceHigh = Color(0xFF1B221A);

  /// Color primario de marca: verde césped profundo, para fondos
  /// teñidos (banners, fills del mapa, filas resaltadas).
  static const Color primary = Color(0xFF1A3615);

  /// Acento principal: verde césped. Botones, íconos activos, links.
  static const Color accent = Color(0xFF3BDC1E);

  /// Acento brillante: estados activos, badges, CTAs.
  /// En Stadium Night es el mismo verde césped que [accent].
  static const Color highlight = Color(0xFF3BDC1E);

  /// Texto / íconos sobre superficies verdes ([accent], [highlight]).
  static const Color onAccent = Color(0xFF0A0F09);

  /// Texto principal: blanco con tinte verdoso.
  static const Color textPrimary = Color(0xFFEDF3EC);

  /// Texto secundario (55% de opacidad sobre fondo).
  static const Color textSecondary = Color(0x8CEDF3EC);

  /// Texto terciario / apagado (32% de opacidad sobre fondo).
  static const Color textDim = Color(0x52EDF3EC);

  /// Error.
  static const Color error = Color(0xFFFF3B30);

  /// Advertencia / tarjeta amarilla.
  static const Color warning = Color(0xFFFFCC00);

  /// Borde sutil para cards e inputs (blanco al 7 %).
  static const Color border = Color(0x12FFFFFF);

  /// Verde césped al 14 % — tinte para fondos activos, glows y overlays.
  static const Color greenGlow = Color(0x243BDC1E);
}
