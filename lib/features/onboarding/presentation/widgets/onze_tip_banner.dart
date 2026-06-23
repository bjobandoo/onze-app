// Banner contextual descartable para coachmarks in-app.

import 'package:flutter/material.dart';

import '../../../../core/theme/onze_colors.dart';
import '../../../../core/theme/onze_motion.dart';
import '../../../../core/theme/onze_theme.dart';

/// Banner informativo descartable que explica una característica de la app.
///
/// Se muestra en la primera visita a una pantalla y se descarta con
/// el botón "Entendido". Al descartarse colapsa su altura con animación,
/// de modo que el contenido inferior sube a ocupar el espacio liberado.
/// Una vez descartado, no vuelve a aparecer.
class OnzeTipBanner extends StatefulWidget {
  const OnzeTipBanner({
    required this.icon,
    required this.title,
    required this.body,
    required this.onDismiss,
    super.key,
  });

  final IconData icon;
  final String title;
  final String body;
  final VoidCallback onDismiss;

  @override
  State<OnzeTipBanner> createState() => _OnzeTipBannerState();
}

class _OnzeTipBannerState extends State<OnzeTipBanner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;
  late final Animation<double> _size;
  bool _dismissing = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: OnzeMotion.slow);
    final curved = CurvedAnimation(
      parent: _ctrl,
      curve: OnzeMotion.enter,
      reverseCurve: OnzeMotion.exit,
    );
    _fade = curved;
    _slide = Tween<Offset>(
      begin: const Offset(0, -0.15),
      end: Offset.zero,
    ).animate(curved);
    _size = CurvedAnimation(parent: _ctrl, curve: OnzeMotion.emphasized);
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _dismiss() async {
    if (_dismissing) return;
    _dismissing = true;
    await _ctrl.reverse();
    if (mounted) widget.onDismiss();
  }

  @override
  Widget build(BuildContext context) {
    return SizeTransition(
      sizeFactor: _size,
      axisAlignment: -1,
      child: FadeTransition(
        opacity: _fade,
        child: SlideTransition(
          position: _slide,
          child: Container(
            margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: OnzeColors.primary,
              borderRadius: BorderRadius.circular(OnzeTheme.radiusCard),
              border:
                  Border.all(color: OnzeColors.highlight.withValues(alpha: 0.4)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Icon(widget.icon, color: OnzeColors.highlight, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        widget.title,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: OnzeColors.highlight,
                            ),
                      ),
                    ),
                    GestureDetector(
                      onTap: _dismiss,
                      child: const Icon(
                        Icons.close,
                        color: OnzeColors.textSecondary,
                        size: 16,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  widget.body,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: OnzeColors.textPrimary.withValues(alpha: 0.85),
                      ),
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: GestureDetector(
                    onTap: _dismiss,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 6),
                      decoration: BoxDecoration(
                        color: OnzeColors.highlight,
                        borderRadius:
                            BorderRadius.circular(OnzeTheme.radiusPill),
                      ),
                      child: Text(
                        'Entendido',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: OnzeColors.onAccent,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
