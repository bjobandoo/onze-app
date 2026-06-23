import 'package:flutter/material.dart';

import '../../core/theme/onze_theme.dart';
import 'onze_pressable.dart';

/// Card estándar del design system de Onze.
///
/// Fondo grafito, borde sutil, radio redondeado. Cuando es tappable
/// se encoge sutilmente al presionar.
class OnzeCard extends StatelessWidget {
  const OnzeCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final Widget card = Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(OnzeTheme.radiusCard),
        child: Padding(
          padding: padding,
          child: child,
        ),
      ),
    );
    if (onTap == null) return card;
    return OnzePressable(child: card);
  }
}
