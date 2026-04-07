import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/routing/app_router.dart';
import '../../../../core/theme/onze_colors.dart';
import '../../../../shared/widgets/onze_button.dart';
import '../providers/auth_providers.dart';
import '../widgets/phone_input_field.dart';
import '../../domain/models/phone_auth_state.dart';

/// Pantalla de login: ingreso del número de WhatsApp.
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

    // Navegar a OTP cuando el código fue enviado
    ref.listen(phoneAuthProvider, (_, next) {
      if (next is PhoneAuthOtpSent) {
        context.push(AppRoutes.otp, extra: next.phone);
      }
    });

    final isLoading = authState is PhoneAuthSendingOtp;
    final errorMessage =
        authState is PhoneAuthError ? authState.message : null;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 64),
              _buildHeader(context),
              const SizedBox(height: 48),
              _buildForm(isLoading),
              if (errorMessage != null) ...[
                const SizedBox(height: 16),
                _buildErrorBanner(errorMessage),
              ],
              const SizedBox(height: 24),
              OnzeButton(
                label: 'Enviar código por WhatsApp',
                onPressed: isLoading ? null : _submit,
                isLoading: isLoading,
              ),
              const Spacer(),
              _buildFooter(context),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'ONZE',
          style: Theme.of(context).textTheme.displayLarge?.copyWith(
                color: OnzeColors.highlight,
                letterSpacing: 4,
              ),
        ),
        const SizedBox(height: 8),
        Text(
          'Ingresa tu número de WhatsApp\npara recibir tu código de acceso.',
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: OnzeColors.textSecondary,
              ),
        ),
      ],
    );
  }

  Widget _buildForm(bool isLoading) {
    return PhoneInputField(
      controller: _phoneController,
      errorText: _fieldError,
      autofocus: true,
      onSubmitted: isLoading ? null : _submit,
    );
  }

  Widget _buildErrorBanner(String message) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: OnzeColors.error.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: OnzeColors.error.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: OnzeColors.error, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
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
      'Al continuar aceptas los términos de servicio de Onze.\nSolo para jugadores en Ibarra, Ecuador.',
      textAlign: TextAlign.center,
      style: Theme.of(context).textTheme.bodySmall,
    );
  }
}
