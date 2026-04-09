import 'package:flutter/material.dart';

import '../../core/theme/onze_colors.dart';

/// Botón primario del design system de Onze.
///
/// Alto de 56px, texto en uppercase con letter spacing.
/// Admite estado de carga y variante outline.
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
    if (variant == OnzeButtonVariant.outline) {
      return _buildOutline(context);
    }
    return _buildFilled(context);
  }

  Widget _buildFilled(BuildContext context) {
    final button = ElevatedButton(
      onPressed: isLoading ? null : onPressed,
      child: _buildChild(),
    );
    return isFullWidth
        ? SizedBox(width: double.infinity, child: button)
        : button;
  }

  Widget _buildOutline(BuildContext context) {
    final button = OutlinedButton(
      onPressed: isLoading ? null : onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: OnzeColors.highlight,
        side: const BorderSide(color: OnzeColors.highlight),
        minimumSize: const Size(double.infinity, 56),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        textStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.5,
        ),
      ),
      child: _buildChild(),
    );
    return isFullWidth
        ? SizedBox(width: double.infinity, child: button)
        : button;
  }

  Widget _buildChild() {
    if (isLoading) {
      return const SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
      );
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 18),
          const SizedBox(width: 8),
        ],
        Text(label.toUpperCase()),
      ],
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
