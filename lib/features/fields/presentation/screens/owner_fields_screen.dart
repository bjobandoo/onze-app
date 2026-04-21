// Pantalla principal del dueño: lista de sus canchas registradas.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/routing/app_router.dart';
import '../../../../core/theme/onze_colors.dart';
import '../../../../shared/widgets/onze_button.dart';
import '../../domain/models/field.dart';
import '../providers/fields_providers.dart';
import '../widgets/field_status_card.dart';

/// Pantalla que muestra las canchas del dueño autenticado.
///
/// Si el usuario no tiene perfil de dueño, redirige a [BecomeOwnerScreen].
class OwnerFieldsScreen extends ConsumerWidget {
  const OwnerFieldsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ownerProfileAsync = ref.watch(myOwnerProfileProvider);
    final fieldsAsync = ref.watch(myFieldsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mis canchas'),
        actions: [
          ownerProfileAsync.whenOrNull(
                data: (profile) => profile != null
                    ? IconButton(
                        icon: const Icon(Icons.bar_chart_outlined),
                        tooltip: 'Estadísticas',
                        onPressed: () => context.push(
                          AppRoutes.ownerDashboard,
                          extra: profile.userId,
                        ),
                      )
                    : null,
              ) ??
              const SizedBox.shrink(),
          ownerProfileAsync.whenOrNull(
                data: (profile) => profile != null
                    ? IconButton(
                        icon: const Icon(Icons.add),
                        tooltip: 'Registrar cancha',
                        onPressed: () =>
                            context.push(AppRoutes.registerField),
                      )
                    : null,
              ) ??
              const SizedBox.shrink(),
        ],
      ),
      body: ownerProfileAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: OnzeColors.accent)),
        error: (e, _) => _ErrorView(message: e.toString()),
        data: (profile) {
          // Sin perfil de dueño → invitar a registrarse
          if (profile == null) {
            return _NoBecomeOwnerView(
              onRegisterTap: () => context.push(AppRoutes.becomeOwner),
            );
          }

          // Tiene perfil pero aún no verificado → banner informativo
          return Column(
            children: [
              if (!profile.verified) _PendingVerificationBanner(),
              Expanded(child: _FieldsList(fieldsAsync: fieldsAsync)),
            ],
          );
        },
      ),
      floatingActionButton: ownerProfileAsync.whenOrNull(
        data: (profile) => profile != null
            ? FloatingActionButton.extended(
                onPressed: () => context.push(AppRoutes.registerField),
                icon: const Icon(Icons.add_location_alt_outlined),
                label: const Text('Nueva cancha'),
                backgroundColor: OnzeColors.accent,
              )
            : null,
      ),
    );
  }
}

class _PendingVerificationBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: OnzeColors.warning.withValues(alpha: 0.15),
      child: Row(
        children: [
          const Icon(Icons.hourglass_top_outlined,
              color: OnzeColors.warning, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Tu perfil de dueño está en revisión. Puedes registrar canchas '
              'mientras esperas la verificación.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: OnzeColors.warning,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FieldsList extends StatelessWidget {
  const _FieldsList({required this.fieldsAsync});
  final AsyncValue<List<Field>> fieldsAsync;

  @override
  Widget build(BuildContext context) {
    return fieldsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator(color: OnzeColors.accent)),
      error: (e, _) => _ErrorView(message: e.toString()),
      data: (fields) {
        if (fields.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.sports_soccer,
                      size: 64, color: OnzeColors.textSecondary),
                  const SizedBox(height: 16),
                  Text(
                    'Aún no has registrado canchas',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: OnzeColors.textSecondary,
                        ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(24),
          itemCount: fields.length,
          separatorBuilder: (_, _) => const SizedBox(height: 16),
          itemBuilder: (context, index) {
            final field = fields[index];
            return FieldStatusCard(
              field: field,
              onTap: () => context.push(
                AppRoutes.fieldSchedules(field.id),
                extra: field,
              ),
            );
          },
        );
      },
    );
  }
}

class _NoBecomeOwnerView extends StatelessWidget {
  const _NoBecomeOwnerView({required this.onRegisterTap});
  final VoidCallback onRegisterTap;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.store_outlined,
                size: 64, color: OnzeColors.textSecondary),
            const SizedBox(height: 16),
            Text(
              '¿Tienes canchas sintéticas?',
              style: Theme.of(context).textTheme.headlineMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Regístrate como dueño para publicar tus canchas y recibir reservas a través de Onze.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: OnzeColors.textSecondary,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            OnzeButton(
              label: 'Registrarme como dueño',
              onPressed: onRegisterTap,
              icon: Icons.store_outlined,
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          message,
          style: Theme.of(context)
              .textTheme
              .bodyMedium
              ?.copyWith(color: OnzeColors.error),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
