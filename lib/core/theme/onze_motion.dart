import 'package:flutter/material.dart';

/// Tokens de movimiento del design system de Onze.
///
/// Centraliza duraciones y curvas para que todas las animaciones
/// de la app se sientan consistentes y fluidas.
abstract final class OnzeMotion {
  /// Micro-interacciones: press de botones, cambios de icono.
  static const Duration fast = Duration(milliseconds: 140);

  /// Transiciones de componentes: chips, switches de contenido.
  static const Duration medium = Duration(milliseconds: 240);

  /// Entradas/salidas de elementos grandes: banners, páginas.
  static const Duration slow = Duration(milliseconds: 340);

  /// Curva para elementos que entran en pantalla.
  static const Curve enter = Curves.easeOutCubic;

  /// Curva para elementos que salen de pantalla.
  static const Curve exit = Curves.easeInCubic;

  /// Curva para cambios de tamaño/posición dentro de la pantalla.
  static const Curve emphasized = Curves.easeInOutCubic;
}

/// Transición de página de Onze: fade con deslizamiento sutil hacia arriba.
///
/// Se aplica globalmente vía [PageTransitionsTheme] en el tema, por lo que
/// go_router la usa automáticamente en cada navegación.
class OnzePageTransitionsBuilder extends PageTransitionsBuilder {
  const OnzePageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final CurvedAnimation curved = CurvedAnimation(
      parent: animation,
      curve: OnzeMotion.enter,
      reverseCurve: OnzeMotion.exit,
    );
    return FadeTransition(
      opacity: curved,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.04),
          end: Offset.zero,
        ).animate(curved),
        child: child,
      ),
    );
  }
}
