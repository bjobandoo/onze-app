import 'package:flutter/material.dart';

import '../../core/theme/onze_colors.dart';
import '../../core/theme/onze_motion.dart';
import '../../core/theme/onze_theme.dart';
import 'onze_pressable.dart';

/// Chip seleccionable del design system de Onze.
///
/// Usado en selección de posición, pie hábil, nivel de experiencia,
/// y como filtro de pestañas (ranking, desafíos). Al seleccionarse
/// se encierra en una píldora verde con texto oscuro.
class OnzeSelectChip extends StatelessWidget {
  const OnzeSelectChip({
    super.key,
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.badgeCount,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  /// Contador opcional (ej. partidos pendientes). Se muestra como
  /// burbuja roja junto al label cuando es mayor que cero.
  final int? badgeCount;

  @override
  Widget build(BuildContext context) {
    return OnzePressable(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: OnzeMotion.medium,
          curve: OnzeMotion.emphasized,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? OnzeColors.accent : OnzeColors.surface,
            borderRadius: BorderRadius.circular(OnzeTheme.radiusPill),
            border: Border.all(
              color: isSelected ? OnzeColors.accent : OnzeColors.border,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedDefaultTextStyle(
                duration: OnzeMotion.medium,
                curve: OnzeMotion.emphasized,
                style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                      color: isSelected
                          ? OnzeColors.onAccent
                          : OnzeColors.textSecondary,
                      fontWeight:
                          isSelected ? FontWeight.w600 : FontWeight.w400,
                    ),
                child: Text(label),
              ),
              if ((badgeCount ?? 0) > 0) ...[
                const SizedBox(width: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: const BoxDecoration(
                    color: OnzeColors.error,
                    borderRadius:
                        BorderRadius.all(Radius.circular(OnzeTheme.radiusPill)),
                  ),
                  child: Text(
                    '$badgeCount',
                    style: const TextStyle(
                      fontSize: 10,
                      color: OnzeColors.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
