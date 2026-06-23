import 'package:flutter/material.dart';

import '../../core/theme/onze_colors.dart';
import '../../core/theme/onze_motion.dart';
import '../../core/theme/onze_theme.dart';
import 'onze_pressable.dart';

/// Destino del dock flotante de navegación.
class OnzeDockItem {
  const OnzeDockItem({required this.icon, required this.label});

  final IconData icon;
  final String label;
}

/// Dock flotante de navegación principal — estilo "Stadium Night".
///
/// Píldora centrada que flota sobre el contenido. La pestaña activa
/// se expande en un pill verde mostrando su etiqueta; las inactivas
/// muestran solo el ícono.
class OnzeDock extends StatelessWidget {
  const OnzeDock({
    super.key,
    required this.items,
    required this.currentIndex,
    required this.onSelect,
  });

  final List<OnzeDockItem> items;
  final int currentIndex;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        // heightFactor: 1 evita que el Center se expanda a toda la altura
        // disponible del bottomNavigationBar: el dock mide solo su contenido.
        child: Center(
          heightFactor: 1,
          child: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: const Color(0xEB1B221A),
              borderRadius: BorderRadius.circular(OnzeTheme.radiusPill),
              border: Border.all(color: OnzeColors.border),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x73000000),
                  blurRadius: 32,
                  offset: Offset(0, 12),
                ),
              ],
            ),
            // FittedBox: si las pestañas no caben en pantallas angostas,
            // el dock se escala hacia abajo en lugar de desbordarse.
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (int i = 0; i < items.length; i++)
                    _DockTab(
                      item: items[i],
                      isActive: i == currentIndex,
                      onTap: () => onSelect(i),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DockTab extends StatelessWidget {
  const _DockTab({
    required this.item,
    required this.isActive,
    required this.onTap,
  });

  final OnzeDockItem item;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return OnzePressable(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedContainer(
          duration: OnzeMotion.medium,
          curve: OnzeMotion.emphasized,
          height: 44,
          padding: EdgeInsets.symmetric(horizontal: isActive ? 15 : 11),
          decoration: BoxDecoration(
            color: isActive ? OnzeColors.accent : Colors.transparent,
            borderRadius: BorderRadius.circular(OnzeTheme.radiusPill),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                item.icon,
                size: 21,
                color:
                    isActive ? OnzeColors.onAccent : OnzeColors.textSecondary,
              ),
              AnimatedSize(
                duration: OnzeMotion.medium,
                curve: OnzeMotion.emphasized,
                child: isActive
                    ? Padding(
                        padding: const EdgeInsets.only(left: 7),
                        child: Text(
                          item.label.toUpperCase(),
                          style: Theme.of(context)
                              .textTheme
                              .labelLarge
                              ?.copyWith(
                                fontSize: 15,
                                color: OnzeColors.onAccent,
                              ),
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
