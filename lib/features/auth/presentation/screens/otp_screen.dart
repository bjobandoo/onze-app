import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/routing/app_router.dart';
import '../../../../core/theme/onze_colors.dart';
import '../../../../shared/widgets/onze_button.dart';
import '../../domain/models/phone_auth_state.dart';
import '../providers/auth_providers.dart';

/// Pantalla de verificación del código OTP.
///
/// Recibe el [phone] en E.164 como [GoRouterState.extra].
class OtpScreen extends ConsumerStatefulWidget {
  const OtpScreen({super.key, required this.phone});

  final String phone;

  @override
  ConsumerState<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends ConsumerState<OtpScreen> {
  final _otpController = TextEditingController();
  String? _fieldError;

  // Contador de reenvío: 60 segundos
  static const _resendCooldown = 60;
  int _secondsRemaining = _resendCooldown;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startResendTimer();
  }

  @override
  void dispose() {
    _otpController.dispose();
    _timer?.cancel();
    super.dispose();
  }

  void _startResendTimer() {
    _timer?.cancel();
    setState(() => _secondsRemaining = _resendCooldown);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsRemaining <= 1) {
        timer.cancel();
        setState(() => _secondsRemaining = 0);
      } else {
        setState(() => _secondsRemaining--);
      }
    });
  }

  Future<void> _verify() async {
    final code = _otpController.text.trim();
    if (code.length != 6) {
      setState(() => _fieldError = 'El código tiene 6 dígitos');
      return;
    }
    setState(() => _fieldError = null);

    await ref.read(phoneAuthProvider.notifier).verifyOtp(
          phone: widget.phone,
          code: code,
        );
  }

  Future<void> _resend() async {
    _otpController.clear();
    setState(() => _fieldError = null);
    await ref.read(phoneAuthProvider.notifier).sendOtp(widget.phone);
    _startResendTimer();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(phoneAuthProvider);

    ref.listen(phoneAuthProvider, (_, next) {
      if (next is PhoneAuthSuccess) {
        if (next.isNewUser) {
          context.go(AppRoutes.createProfile);
        } else {
          context.go(AppRoutes.home);
        }
      }
    });

    final isLoading = authState is PhoneAuthVerifying;
    final errorMessage =
        authState is PhoneAuthError ? authState.message : null;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            ref.read(phoneAuthProvider.notifier).reset();
            context.pop();
          },
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 32),
              _buildHeader(context),
              const SizedBox(height: 40),
              _buildOtpField(),
              if (errorMessage != null) ...[
                const SizedBox(height: 16),
                _buildErrorBanner(errorMessage),
              ],
              const SizedBox(height: 32),
              OnzeButton(
                label: 'Verificar código',
                onPressed: isLoading ? null : _verify,
                isLoading: isLoading,
              ),
              const SizedBox(height: 24),
              _buildResendButton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final displayPhone = widget.phone.replaceFirst('+593', '0');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Revisa tu WhatsApp',
          style: Theme.of(context).textTheme.displayLarge,
        ),
        const SizedBox(height: 8),
        Text.rich(
          TextSpan(
            text: 'Enviamos un código de 6 dígitos a ',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: OnzeColors.textSecondary,
                ),
            children: [
              TextSpan(
                text: displayPhone,
                style: const TextStyle(
                  color: OnzeColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildOtpField() {
    return TextField(
      controller: _otpController,
      autofocus: true,
      keyboardType: TextInputType.number,
      textAlign: TextAlign.center,
      textInputAction: TextInputAction.done,
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(6),
      ],
      onSubmitted: (_) => _verify(),
      onChanged: (value) {
        if (_fieldError != null) setState(() => _fieldError = null);
        // Auto-verificar al completar 6 dígitos
        if (value.length == 6) _verify();
      },
      style: Theme.of(context).textTheme.displayLarge?.copyWith(
            letterSpacing: 16,
            color: OnzeColors.highlight,
          ),
      decoration: InputDecoration(
        hintText: '------',
        hintStyle: Theme.of(context).textTheme.displayLarge?.copyWith(
              letterSpacing: 12,
              color: OnzeColors.textSecondary,
            ),
        errorText: _fieldError,
      ),
    );
  }

  Widget _buildErrorBanner(String message) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: OnzeColors.error.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: OnzeColors.error.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: OnzeColors.error, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: OnzeColors.error),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResendButton() {
    if (_secondsRemaining > 0) {
      return Center(
        child: Text(
          'Reenviar en ${_secondsRemaining}s',
          style: Theme.of(context)
              .textTheme
              .bodyMedium
              ?.copyWith(color: OnzeColors.textSecondary),
        ),
      );
    }

    return Center(
      child: TextButton(
        onPressed: _resend,
        child: const Text('Reenviar código'),
      ),
    );
  }
}
