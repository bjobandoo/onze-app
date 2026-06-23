import 'package:flutter/material.dart';

import '../../core/theme/onze_motion.dart';

/// Aplica una escala sutil al presionar, como feedback táctil moderno.
///
/// Escucha los eventos de puntero crudos con [Listener], así no roba los
/// gestos del hijo: el botón o card envuelto sigue manejando su propio tap.
class OnzePressable extends StatefulWidget {
  const OnzePressable({
    super.key,
    required this.child,
    this.enabled = true,
    this.pressedScale = 0.97,
  });

  final Widget child;
  final bool enabled;
  final double pressedScale;

  @override
  State<OnzePressable> createState() => _OnzePressableState();
}

class _OnzePressableState extends State<OnzePressable> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (!widget.enabled || _pressed == value) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (_) => _setPressed(true),
      onPointerUp: (_) => _setPressed(false),
      onPointerCancel: (_) => _setPressed(false),
      child: AnimatedScale(
        scale: _pressed ? widget.pressedScale : 1,
        duration: OnzeMotion.fast,
        curve: OnzeMotion.enter,
        child: widget.child,
      ),
    );
  }
}
