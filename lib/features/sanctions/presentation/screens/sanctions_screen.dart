// Pantalla de sanciones del usuario: tarjetas y suspensión activa.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/onze_colors.dart';
import '../../../../features/auth/presentation/providers/auth_providers.dart';
import '../../domain/models/yellow_card.dart';
import '../providers/sanctions_providers.dart';
import '../../../../features/onboarding/presentation/providers/onboarding_providers.dart';
import '../../../../features/onboarding/presentation/widgets/onze_tip_banner.dart';

class SanctionsScreen extends ConsumerWidget {
  const SanctionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(currentUserProvider);
    final cardsAsync = ref.watch(myYellowCardsProvider);

    final tipDismissed = ref.watch(onboardingProvider
        .select((s) => s.contains(kObSanctions)));

    return Scaffold(
      appBar: AppBar(title: const Text('Mis sanciones')),
      body: Column(
        children: [
          if (!tipDismissed)
            OnzeTipBanner(
              icon: Icons.warning_amber_rounded,
              title: 'Tarjetas y sanciones',
              body: 'Acumular 3 tarjetas amarillas genera una tarjeta roja '
                  'y suspensión temporal. Las tarjetas las emite el sistema '
                  'cuando se reporta conducta antideportiva.',
              onDismiss: () => ref
                  .read(onboardingProvider.notifier)
                  .dismiss(kObSanctions),
            ),
          Expanded(
            child: userAsync.when(
        loading: () => const Center(
            child: CircularProgressIndicator(color: OnzeColors.accent)),
        error: (e, _) => _ErrorView(message: e.toString()),
        data: (user) {
          if (user == null) return const SizedBox.shrink();
          return RefreshIndicator(
            color: OnzeColors.accent,
            onRefresh: () async {
              ref.invalidate(myYellowCardsProvider);
              ref.invalidate(currentUserProvider);
            },
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
              children: [
                // Estado de suspensión personal
                _SuspensionCard(
                  isSuspended: user.isSuspended,
                  suspensionUntil: user.suspensionUntil,
                  yellowCardsCount: user.yellowCardsCount,
                  label: 'Mi cuenta',
                ),
                const SizedBox(height: 24),
                // Tarjetas recibidas
                Text('TARJETAS RECIBIDAS',
                    style: Theme.of(context).textTheme.labelSmall),
                const SizedBox(height: 12),
                cardsAsync.when(
                  loading: () => const Center(
                      child: CircularProgressIndicator(
                          color: OnzeColors.accent, strokeWidth: 2)),
                  error: (e, _) => _ErrorView(message: e.toString()),
                  data: (cards) => cards.isEmpty
                      ? _EmptyCards()
                      : Column(
                          children: cards
                              .map((c) => Padding(
                                    padding: const EdgeInsets.only(bottom: 8),
                                    child: _YellowCardTile(
                                      card: c,
                                      onAppeal: c.canAppeal
                                          ? () => _showAppealDialog(
                                              context, ref, c)
                                          : null,
                                    ),
                                  ))
                              .toList(),
                        ),
                ),
              ],
            ),
          );
        },
      ),
          ),
        ],
      ),
    );
  }

  Future<void> _showAppealDialog(
      BuildContext context, WidgetRef ref, YellowCard card) async {
    final controller = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (ctx) => _AppealDialog(
        card: card,
        controller: controller,
        onSubmit: () async {
          await ref.read(appealProvider(card.id).notifier).submit(
                cardId: card.id,
                reason: controller.text,
              );
          final state = ref.read(appealProvider(card.id));
          if (!ctx.mounted) return;
          if (state.submitted) {
            Navigator.of(ctx).pop();
            ref.invalidate(myYellowCardsProvider);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Apelación enviada. Revisaremos tu caso.'),
                backgroundColor: OnzeColors.accent,
              ),
            );
          }
        },
      ),
    );
    controller.dispose();
  }
}

// ---------------------------------------------------------------------------
// Sección de suspensión del equipo (reutilizable desde TeamDetailScreen)
// ---------------------------------------------------------------------------

/// Card que muestra el estado de suspensión de un usuario o equipo.
class SuspensionStatusCard extends StatelessWidget {
  const SuspensionStatusCard({
    super.key,
    required this.isSuspended,
    required this.suspensionUntil,
    required this.yellowCardsCount,
    required this.label,
  });

  final bool isSuspended;
  final DateTime? suspensionUntil;
  final int yellowCardsCount;
  final String label;

  @override
  Widget build(BuildContext context) {
    return _SuspensionCard(
      isSuspended: isSuspended,
      suspensionUntil: suspensionUntil,
      yellowCardsCount: yellowCardsCount,
      label: label,
    );
  }
}

// ---------------------------------------------------------------------------
// Widgets internos
// ---------------------------------------------------------------------------

class _SuspensionCard extends StatelessWidget {
  const _SuspensionCard({
    required this.isSuspended,
    required this.suspensionUntil,
    required this.yellowCardsCount,
    required this.label,
  });

  final bool isSuspended;
  final DateTime? suspensionUntil;
  final int yellowCardsCount;
  final String label;

  bool get _activelySuspended {
    if (!isSuspended) return false;
    if (suspensionUntil == null) return true;
    return DateTime.now().isBefore(suspensionUntil!);
  }

  @override
  Widget build(BuildContext context) {
    final color = _activelySuspended ? OnzeColors.error : OnzeColors.surface;
    final borderColor =
        _activelySuspended ? OnzeColors.error.withValues(alpha: 0.5) : OnzeColors.border;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: _activelySuspended ? 0.08 : 1.0),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                _activelySuspended
                    ? Icons.block_outlined
                    : Icons.check_circle_outline,
                color: _activelySuspended
                    ? OnzeColors.error
                    : OnzeColors.accent,
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const Spacer(),
              if (_activelySuspended)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: OnzeColors.error.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'SUSPENDIDO',
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1,
                      color: OnzeColors.error,
                    ),
                  ),
                ),
            ],
          ),
          if (_activelySuspended) ...[
            const SizedBox(height: 8),
            Text(
              suspensionUntil == null
                  ? 'Suspensión permanente.'
                  : 'Suspendido hasta: ${_formatDate(suspensionUntil!)}',
              style: TextStyle(
                  fontSize: 12, color: OnzeColors.error),
            ),
          ],
          const SizedBox(height: 12),
          // Indicadores de tarjetas amarillas
          Row(
            children: [
              Text(
                'Tarjetas amarillas: ',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              ...List.generate(3, (i) {
                final filled = i < yellowCardsCount;
                return Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: Icon(
                    filled
                        ? Icons.square_rounded
                        : Icons.square_outlined,
                    color: filled
                        ? OnzeColors.warning
                        : OnzeColors.border,
                    size: 20,
                  ),
                );
              }),
              const SizedBox(width: 4),
              Text(
                '$yellowCardsCount/3',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: yellowCardsCount >= 2
                          ? OnzeColors.warning
                          : OnzeColors.textSecondary,
                      fontWeight: yellowCardsCount >= 2
                          ? FontWeight.w700
                          : FontWeight.normal,
                    ),
              ),
            ],
          ),
          if (yellowCardsCount == 2)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                '⚠️ Una tarjeta más resultará en suspensión.',
                style: TextStyle(
                    fontSize: 11, color: OnzeColors.warning),
              ),
            ),
        ],
      ),
    );
  }

  String _formatDate(DateTime d) {
    const months = [
      '', 'ene', 'feb', 'mar', 'abr', 'may', 'jun',
      'jul', 'ago', 'sep', 'oct', 'nov', 'dic',
    ];
    return '${d.day} ${months[d.month]} ${d.year}';
  }
}

class _YellowCardTile extends StatelessWidget {
  const _YellowCardTile({required this.card, this.onAppeal});

  final YellowCard card;
  final VoidCallback? onAppeal;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: OnzeColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: OnzeColors.warning.withValues(alpha: 0.4),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.square_rounded,
              color: OnzeColors.warning, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  card.reason.label,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                Text(
                  _formatDate(card.issuedAt),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: OnzeColors.textSecondary,
                      ),
                ),
                if (card.appealed && card.appealStatus != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      'Apelación: ${card.appealStatus!.label}',
                      style: TextStyle(
                        fontSize: 11,
                        color: card.appealStatus == AppealStatus.approved
                            ? OnzeColors.accent
                            : card.appealStatus == AppealStatus.rejected
                                ? OnzeColors.error
                                : OnzeColors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (onAppeal != null)
            TextButton(
              onPressed: onAppeal,
              style: TextButton.styleFrom(
                  foregroundColor: OnzeColors.highlight),
              child: const Text('Apelar',
                  style: TextStyle(fontWeight: FontWeight.w700)),
            ),
        ],
      ),
    );
  }

  String _formatDate(DateTime d) {
    const months = [
      '', 'ene', 'feb', 'mar', 'abr', 'may', 'jun',
      'jul', 'ago', 'sep', 'oct', 'nov', 'dic',
    ];
    return '${d.day} ${months[d.month]} ${d.year}';
  }
}

class _AppealDialog extends ConsumerWidget {
  const _AppealDialog({
    required this.card,
    required this.controller,
    required this.onSubmit,
  });

  final YellowCard card;
  final TextEditingController controller;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(appealProvider(card.id));

    return AlertDialog(
      backgroundColor: OnzeColors.surface,
      title: const Text('Apelar tarjeta'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Motivo de la tarjeta: ${card.reason.label}',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: OnzeColors.textSecondary),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: controller,
            maxLines: 4,
            maxLength: 500,
            decoration: const InputDecoration(
              hintText: 'Explica por qué esta tarjeta es incorrecta…',
              alignLabelWithHint: true,
            ),
          ),
          if (state.hasError) ...[
            const SizedBox(height: 8),
            Text(state.errorMessage!,
                style: const TextStyle(
                    color: OnzeColors.error, fontSize: 12)),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        TextButton(
          onPressed: state.isLoading ? null : onSubmit,
          child: state.isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: OnzeColors.highlight))
              : const Text('Enviar apelación',
                  style: TextStyle(color: OnzeColors.highlight)),
        ),
      ],
    );
  }
}

class _EmptyCards extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: OnzeColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: OnzeColors.border),
      ),
      child: Row(
        children: [
          const Icon(Icons.check_circle_outline,
              color: OnzeColors.accent, size: 28),
          const SizedBox(width: 12),
          Text(
            'Sin tarjetas. ¡Sigue así!',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
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
        child: Text(message,
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: OnzeColors.error),
            textAlign: TextAlign.center),
      ),
    );
  }
}
