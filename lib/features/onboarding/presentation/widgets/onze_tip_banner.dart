// Banner contextual descartable para coachmarks in-app.

import 'package:flutter/material.dart';

import '../../../../core/theme/onze_colors.dart';

/// Banner informativo descartable que explica una característica de la app.
///
/// Se muestra en la primera visita a una pantalla y se descarta con
/// el botón "Entendido". Una vez descartado, no vuelve a aparecer.
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

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slide = Tween<Offset>(
      begin: const Offset(0, -0.15),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _dismiss() {
    _ctrl.reverse().then((_) => widget.onDismiss());
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(
        position: _slide,
        child: Container(
          margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: OnzeColors.primary,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: OnzeColors.highlight.withValues(alpha: 0.4)),
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
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    decoration: BoxDecoration(
                      color: OnzeColors.highlight,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'Entendido',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: OnzeColors.background,
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
    );
  }
}
