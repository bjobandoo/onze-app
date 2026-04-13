// Pantalla de gestión de desafíos y reservas para capitanes y dueños.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/routing/app_router.dart';
import '../../../../core/theme/onze_colors.dart';
import '../../../../features/auth/presentation/providers/auth_providers.dart';
import '../../domain/models/match_request.dart';
import '../providers/matches_providers.dart';

class MatchRequestsScreen extends ConsumerWidget {
  const MatchRequestsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isOwner =
        ref.watch(currentUserProvider).valueOrNull?.isOwner ?? false;

    return DefaultTabController(
      length: isOwner ? 3 : 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Desafíos'),
          bottom: TabBar(
            indicatorColor: OnzeColors.highlight,
            labelColor: OnzeColors.textPrimary,
            unselectedLabelColor: OnzeColors.textSecondary,
            tabs: [
              const Tab(text: 'Recibidos'),
              const Tab(text: 'Enviados'),
              if (isOwner) const Tab(text: 'Mi cancha'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _ReceivedTab(),
            _SentTab(),
            if (isOwner) _OwnerTab(),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => context.push(AppRoutes.sendChallenge),
          icon: const Icon(Icons.sports_soccer),
          label: const Text('Desafiar'),
          backgroundColor: OnzeColors.accent,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Tab: Recibidos
// ---------------------------------------------------------------------------

class _ReceivedTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(challengesReceivedProvider);
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator(color: OnzeColors.accent)),
      error: (e, _) => _ErrorView(message: e.toString()),
      data: (requests) {
        final pending =
            requests.where((r) => r.status == MatchRequestStatus.pendingOpponent).toList();
        if (pending.isEmpty) return const _EmptyView(message: 'No tienes desafíos pendientes de respuesta.');
        return _RequestList(requests: pending, role: _Role.challenged);
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Tab: Enviados
// ---------------------------------------------------------------------------

class _SentTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(challengesSentProvider);
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator(color: OnzeColors.accent)),
      error: (e, _) => _ErrorView(message: e.toString()),
      data: (requests) {
        if (requests.isEmpty) return const _EmptyView(message: 'No has enviado desafíos todavía.');
        return _RequestList(requests: requests, role: _Role.challenger);
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Tab: Dueño
// ---------------------------------------------------------------------------

class _OwnerTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(pendingOwnerRequestsProvider);
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator(color: OnzeColors.accent)),
      error: (e, _) => _ErrorView(message: e.toString()),
      data: (requests) {
        if (requests.isEmpty) {
          return const _EmptyView(message: 'No hay reservas pendientes de confirmación.');
        }
        return _RequestList(requests: requests, role: _Role.owner);
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Lista de solicitudes
// ---------------------------------------------------------------------------

enum _Role { challenger, challenged, owner }

class _RequestList extends StatelessWidget {
  const _RequestList({required this.requests, required this.role});

  final List<MatchRequest> requests;
  final _Role role;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: requests.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, i) =>
          _MatchRequestCard(request: requests[i], role: role),
    );
  }
}

// ---------------------------------------------------------------------------
// Tarjeta de solicitud
// ---------------------------------------------------------------------------

class _MatchRequestCard extends ConsumerWidget {
  const _MatchRequestCard({required this.request, required this.role});

  final MatchRequest request;
  final _Role role;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final actionState = ref.watch(challengeActionProvider);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: OnzeColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: OnzeColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${request.challengerTeamName ?? '…'} vs ${request.challengedTeamName ?? '…'}',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ),
              _StatusChip(
                status: request.isExpired
                    ? MatchRequestStatus.expired
                    : request.status,
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            request.fieldName ?? '',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: OnzeColors.textSecondary,
                ),
          ),
          const SizedBox(height: 2),
          Text(
            '${_fmtDate(request.requestedDate)}  ·  ${request.timeRange}',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: OnzeColors.textSecondary,
                ),
          ),
          const SizedBox(height: 2),
          Text(
            '\$${request.price.toStringAsFixed(2)}',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: OnzeColors.highlight,
                  fontWeight: FontWeight.w600,
                ),
          ),
          if (_showActions) ...[
            const SizedBox(height: 12),
            _buildActions(context, ref, actionState),
          ],
        ],
      ),
    );
  }

  bool get _showActions {
    if (request.isExpired) return false;
    return switch (role) {
      _Role.challenged =>
        request.status == MatchRequestStatus.pendingOpponent,
      _Role.challenger =>
        request.status == MatchRequestStatus.pendingOpponent,
      _Role.owner =>
        request.status == MatchRequestStatus.pendingOwner,
    };
  }

  Widget _buildActions(
    BuildContext context,
    WidgetRef ref,
    ChallengeActionState state,
  ) {
    if (state.isLoading) {
      return const Center(
        child: SizedBox(
          height: 24,
          width: 24,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    void invalidateAll() {
      ref.invalidate(challengesSentProvider);
      ref.invalidate(challengesReceivedProvider);
      ref.invalidate(pendingOwnerRequestsProvider);
    }

    switch (role) {
      case _Role.challenged:
        return Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () async {
                  final ok = await ref
                      .read(challengeActionProvider.notifier)
                      .reject(request.id);
                  if (ok) invalidateAll();
                },
                style: OutlinedButton.styleFrom(
                    foregroundColor: OnzeColors.error),
                child: const Text('Rechazar'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: FilledButton(
                onPressed: () async {
                  final ok = await ref
                      .read(challengeActionProvider.notifier)
                      .accept(request.id);
                  if (ok) invalidateAll();
                },
                style: FilledButton.styleFrom(
                    backgroundColor: OnzeColors.accent),
                child: const Text('Aceptar'),
              ),
            ),
          ],
        );

      case _Role.challenger:
        return Align(
          alignment: Alignment.centerRight,
          child: OutlinedButton(
            onPressed: () async {
              final ok = await ref
                  .read(challengeActionProvider.notifier)
                  .cancel(request.id);
              if (ok) invalidateAll();
            },
            style: OutlinedButton.styleFrom(
                foregroundColor: OnzeColors.error),
            child: const Text('Cancelar'),
          ),
        );

      case _Role.owner:
        return Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () async {
                  final ok = await ref
                      .read(challengeActionProvider.notifier)
                      .rejectByOwner(request.id);
                  if (ok) invalidateAll();
                },
                style: OutlinedButton.styleFrom(
                    foregroundColor: OnzeColors.error),
                child: const Text('Rechazar'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: FilledButton(
                onPressed: () async {
                  final ok = await ref
                      .read(challengeActionProvider.notifier)
                      .confirmByOwner(request.id);
                  if (ok) invalidateAll();
                },
                style: FilledButton.styleFrom(
                    backgroundColor: OnzeColors.accent),
                child: const Text('Confirmar'),
              ),
            ),
          ],
        );
    }
  }

  static String _fmtDate(DateTime d) {
    const months = [
      '', 'ene', 'feb', 'mar', 'abr', 'may', 'jun',
      'jul', 'ago', 'sep', 'oct', 'nov', 'dic'
    ];
    return '${d.day} ${months[d.month]} ${d.year}';
  }
}

// ---------------------------------------------------------------------------
// Chip de estado
// ---------------------------------------------------------------------------

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});
  final MatchRequestStatus status;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      MatchRequestStatus.pendingOpponent => OnzeColors.warning,
      MatchRequestStatus.pendingOwner => OnzeColors.warning,
      MatchRequestStatus.confirmed => OnzeColors.highlight,
      _ => OnzeColors.textSecondary,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Text(
        status.label,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
              fontSize: 11,
            ),
      ),
    );
  }
}

class _EmptyView extends StatelessWidget {
  const _EmptyView({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Text(
          message,
          style: Theme.of(context)
              .textTheme
              .bodyMedium
              ?.copyWith(color: OnzeColors.textSecondary),
          textAlign: TextAlign.center,
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
