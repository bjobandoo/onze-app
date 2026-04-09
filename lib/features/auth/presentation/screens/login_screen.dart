import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/routing/app_router.dart';
import '../../../../core/theme/onze_colors.dart';
import '../../../../shared/widgets/onze_button.dart';
import '../../domain/models/phone_auth_state.dart';
import '../providers/auth_providers.dart';
import '../widgets/phone_input_field.dart';

/// Pantalla de login — estilo editorial Nike.
///
/// Fondo con radial gradient verde oscuro → negro.
/// Wordmark gigante en la zona superior.
/// Formulario limpio anclado al fondo.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _phoneController = TextEditingController();
  String? _fieldError;

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final error = PhoneInputField.validate(_phoneController.text);
    if (error != null) {
      setState(() => _fieldError = error);
      return;
    }
    setState(() => _fieldError = null);
    final phone = PhoneInputField.toE164(_phoneController.text);
    await ref.read(phoneAuthProvider.notifier).sendOtp(phone);
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(phoneAuthProvider);

    ref.listen(phoneAuthProvider, (_, next) {
      if (next is PhoneAuthOtpSent) {
        context.push(AppRoutes.otp, extra: next.phone);
      }
    });

    final isLoading = authState is PhoneAuthSendingOtp;
    final errorMessage =
        authState is PhoneAuthError ? authState.message : null;

    return Scaffold(
      body: Stack(
        children: [
          _buildBackground(),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 56),
                  _buildWordmark(),
                  const Spacer(),
                  _buildFormSection(isLoading, errorMessage),
                  const SizedBox(height: 24),
                  OnzeButton(
                    label: 'Continuar',
                    onPressed: isLoading ? null : _submit,
                    isLoading: isLoading,
                  ),
                  const SizedBox(height: 20),
                  _buildFooter(context),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBackground() {
    return Container(
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment(-0.8, -0.9),
          radius: 1.3,
          colors: [Color(0xFF002800), Colors.black],
          stops: [0.0, 0.65],
        ),
      ),
    );
  }

  Widget _buildWordmark() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'ONZE',
          style: GoogleFonts.inter(
            fontSize: 72,
            fontWeight: FontWeight.w900,
            color: OnzeColors.textPrimary,
            letterSpacing: -3,
            height: 1.0,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          width: 40,
          height: 3,
          color: OnzeColors.highlight,
        ),
        const SizedBox(height: 14),
        Text(
          'IBARRA · ECUADOR',
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 3.0,
            color: OnzeColors.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildFormSection(bool isLoading, String? errorMessage) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Ingresa tu número de WhatsApp',
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: OnzeColors.textSecondary,
              ),
        ),
        const SizedBox(height: 12),
        PhoneInputField(
          controller: _phoneController,
          errorText: _fieldError,
          autofocus: true,
          onSubmitted: isLoading ? null : _submit,
        ),
        if (errorMessage != null) ...[
          const SizedBox(height: 12),
          _buildErrorBanner(errorMessage),
        ],
      ],
    );
  }

  Widget _buildErrorBanner(String message) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: OnzeColors.error.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: OnzeColors.error.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: OnzeColors.error, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: OnzeColors.error,
                  ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter(BuildContext context) {
    return Text(
      'Al continuar aceptas los términos de servicio de Onze.',
      textAlign: TextAlign.center,
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
            letterSpacing: 0,
          ),
    );
  }
}
