import 'package:flutter/material.dart';

import '../../core/theme/onze_colors.dart';
import '../../core/theme/onze_motion.dart';
import 'onze_pressable.dart';

/// Botón primario del design system de Onze.
///
/// Alto de 56px, texto en uppercase con letter spacing.
/// Se encoge sutilmente al presionar y transiciona con fade
/// entre el label y el estado de carga.
class OnzeButton extends StatelessWidget {
  const OnzeButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
    this.isFullWidth = true,
    this.icon,
    this.variant = OnzeButtonVariant.filled,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final bool isFullWidth;
  final IconData? icon;
  final OnzeButtonVariant variant;

  @override
  Widget build(BuildContext context) {
    final Widget button = switch (variant) {
      OnzeButtonVariant.filled => ElevatedButton(
          onPressed: isLoading ? null : onPressed,
          child: _buildChild(),
        ),
      OnzeButtonVariant.outline => OutlinedButton(
          onPressed: isLoading ? null : onPressed,
          child: _buildChild(),
        ),
    };
    final Widget sized = isFullWidth
        ? SizedBox(width: double.infinity, child: button)
        : button;
    return OnzePressable(
      enabled: onPressed != null && !isLoading,
      child: sized,
    );
  }

  Widget _buildChild() {
    return AnimatedSwitcher(
      duration: OnzeMotion.medium,
      switchInCurve: OnzeMotion.enter,
      switchOutCurve: OnzeMotion.exit,
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.85, end: 1).animate(animation),
          child: child,
        ),
      ),
      child: isLoading
          ? SizedBox(
              key: const ValueKey<String>('loading'),
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: variant == OnzeButtonVariant.filled
                    ? OnzeColors.onAccent
                    : OnzeColors.accent,
              ),
            )
          : Row(
              key: const ValueKey<String>('label'),
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 18),
                  const SizedBox(width: 8),
                ],
                Text(label.toUpperCase()),
              ],
            ),
    );
  }
}

enum OnzeButtonVariant { filled, outline }

/// Botón de texto (sin fondo) del design system.
class OnzeTextButton extends StatelessWidget {
  const OnzeTextButton({
    super.key,
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onPressed,
      child: Text(label),
    );
  }
}
