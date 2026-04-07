import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../../core/theme/onze_colors.dart';

/// Campo de teléfono con prefijo Ecuador (+593).
///
/// El usuario ingresa solo los 9 dígitos sin el cero inicial.
/// El número completo en E.164 se obtiene con [fullPhone].
class PhoneInputField extends StatefulWidget {
  const PhoneInputField({
    super.key,
    required this.controller,
    this.onSubmitted,
    this.errorText,
    this.autofocus = false,
  });

  final TextEditingController controller;
  final VoidCallback? onSubmitted;
  final String? errorText;
  final bool autofocus;

  @override
  State<PhoneInputField> createState() => _PhoneInputFieldState();

  /// Convierte el texto del controller al formato E.164 con prefijo Ecuador.
  /// Ejemplo: "987654321" → "+593987654321"
  static String toE164(String rawInput) {
    final digits = rawInput.replaceAll(RegExp(r'\D'), '');
    return '+593$digits';
  }

  /// Valida que el número tenga exactamente 9 dígitos y empiece por 9.
  static String? validate(String rawInput) {
    final digits = rawInput.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) return 'Ingresa tu número de teléfono';
    if (digits.length != 9) return 'El número debe tener 9 dígitos';
    if (!digits.startsWith('9')) return 'El número debe empezar por 9';
    return null;
  }
}

class _PhoneInputFieldState extends State<PhoneInputField> {
  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: widget.controller,
      autofocus: widget.autofocus,
      keyboardType: TextInputType.phone,
      textInputAction: TextInputAction.done,
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(9),
      ],
      onSubmitted: (_) => widget.onSubmitted?.call(),
      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            fontSize: 20,
            letterSpacing: 2,
          ),
      decoration: InputDecoration(
        labelText: 'Número de WhatsApp',
        hintText: '987 654 321',
        errorText: widget.errorText,
        prefixIcon: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('🇪🇨', style: TextStyle(fontSize: 20)),
              const SizedBox(width: 8),
              Text(
                '+593',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: OnzeColors.textSecondary,
                    ),
              ),
              const SizedBox(width: 4),
              Container(
                width: 1,
                height: 24,
                color: OnzeColors.border,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
