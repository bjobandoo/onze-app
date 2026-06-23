// Pantalla de registro como dueño de cancha.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/routing/app_router.dart';
import '../../../../core/theme/onze_colors.dart';
import '../../../../features/auth/presentation/providers/auth_providers.dart';
import '../../../../shared/widgets/onze_button.dart';
import '../providers/fields_providers.dart';

/// Pantalla donde el usuario se registra como dueño de cancha(s).
///
/// Solicita nombre del negocio y número de cédula/RUC para verificación manual
/// por el admin. El perfil queda con [verified = false] hasta ser aprobado.
class BecomeOwnerScreen extends ConsumerStatefulWidget {
  const BecomeOwnerScreen({super.key});

  @override
  ConsumerState<BecomeOwnerScreen> createState() => _BecomeOwnerScreenState();
}

class _BecomeOwnerScreenState extends ConsumerState<BecomeOwnerScreen> {
  final _formKey = GlobalKey<FormState>();
  final _businessNameController = TextEditingController();
  final _idDocumentController = TextEditingController();

  @override
  void dispose() {
    _businessNameController.dispose();
    _idDocumentController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    await ref.read(becomeOwnerProvider.notifier).register(
          businessName: _businessNameController.text,
          idDocument: _idDocumentController.text,
        );

    if (!mounted) return;
    final state = ref.read(becomeOwnerProvider);

    if (state.success) {
      // Refrescar usuario para actualizar roles
      ref
        ..invalidate(currentUserProvider)
        ..invalidate(myOwnerProfileProvider);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            '¡Registrado! Verificaremos tus datos pronto.',
          ),
          backgroundColor: OnzeColors.accent,
        ),
      );
      context.go(AppRoutes.ownerFields);
    } else if (state.hasError) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(state.errorMessage!),
          backgroundColor: OnzeColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = ref.watch(becomeOwnerProvider).isLoading;

    return Scaffold(
      appBar: AppBar(title: const Text('Registrarse como dueño')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 8),
              _InfoBanner(),
              const SizedBox(height: 32),
              Text(
                'Datos del negocio',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _businessNameController,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Nombre del negocio',
                  hintText: 'Ej: Canchas Los Pinos',
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return 'El nombre del negocio es obligatorio';
                  }
                  if (v.trim().length < 3) return 'Mínimo 3 caracteres';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _idDocumentController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Cédula o RUC',
                  hintText: 'Ej: 1001234567 o 1001234567001',
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return 'La cédula o RUC es obligatorio';
                  }
                  final digits = v.trim().replaceAll(RegExp(r'\D'), '');
                  if (digits.length != 10 && digits.length != 13) {
                    return 'Ingresa una cédula (10 dígitos) o RUC (13 dígitos)';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 32),
              OnzeButton(
                label: 'Enviar solicitud',
                onPressed: isLoading ? null : _submit,
                isLoading: isLoading,
                icon: Icons.send_outlined,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: OnzeColors.accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: OnzeColors.accent.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.info_outline,
                  color: OnzeColors.accent, size: 18),
              const SizedBox(width: 8),
              Text(
                '¿Cómo funciona?',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: OnzeColors.accent,
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Registra tus datos para empezar a subir tus canchas. '
            'El equipo de Onze verificará tu información antes de publicar '
            'las canchas en la app. Este proceso tarda 1–2 días hábiles.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: OnzeColors.textSecondary,
                ),
          ),
        ],
      ),
    );
  }
}
