// Pantalla de gestión de desafíos y reservas para capitanes y dueños.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:google_fonts/google_fonts.dart';

import '../../../../core/routing/app_router.dart';
import '../../../../core/theme/onze_colors.dart';
import '../../../../core/theme/onze_motion.dart';
import '../../../../features/auth/presentation/providers/auth_providers.dart';
import '../../../../shared/widgets/onze_avatar.dart';
import '../../../../shared/widgets/onze_select_chip.dart';
import '../../domain/models/match.dart';
import '../../domain/models/match_request.dart';
import '../providers/matches_providers.dart';
import 'report_result_screen.dart';
import 'send_challenge_screen.dart';

class MatchRequestsScreen extends ConsumerStatefulWidget {
  const MatchRequestsScreen({super.key});

  @override
  ConsumerState<MatchRequestsScreen> createState() =>
      _MatchRequestsScreenState();
}

class _MatchRequestsScreenState extends ConsumerState<MatchRequestsScreen> {
  int _index = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.invalidate(myMatchesProvider);
      ref.invalidate(pendingMyReportProvider);
    });
  }

  @override
  Widget build(BuildContext context) {
    final isOwner =
        ref.watch(currentUserProvider).valueOrNull?.isOwner ?? false;
    final pendingCount =
        ref.watch(pendingMyReportProvider).valueOrNull?.length ?? 0;

    final tabs = <Widget>[
      _ReceivedTab(),
      _SentTab(),
      _MatchesTab(),
      if (isOwner) _OwnerTab(),
    ];
    final index = _index < tabs.length ? _index : 0;

    return Scaffold(
      appBar: AppBar(title: const Text('Desafíos')),
      body: Column(
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
            child: Row(
              children: [
                OnzeSelectChip(
                  label: 'Recibidos',
                  isSelected: index == 0,
                  onTap: () => setState(() => _index = 0),
                ),
                const SizedBox(width: 8),
                OnzeSelectChip(
                  label: 'Enviados',
                  isSelected: index == 1,
                  onTap: () => setState(() => _index = 1),
                ),
                const SizedBox(width: 8),
                OnzeSelectChip(
                  label: 'Partidos',
                  isSelected: index == 2,
                  badgeCount: pendingCount,
                  onTap: () => setState(() => _index = 2),
                ),
                if (isOwner) ...[
                  const SizedBox(width: 8),
                  OnzeSelectChip(
                    label: 'Mi cancha',
                    isSelected: index == 3,
                    onTap: () => setState(() => _index = 3),
                  ),
                ],
              ],
            ),
          ),
          Expanded(
            child: AnimatedSwitcher(
              duration: OnzeMotion.medium,
              switchInCurve: OnzeMotion.enter,
              switchOutCurve: OnzeMotion.exit,
              child: tabs[index],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateSheet(context),
        icon: const Icon(Icons.sports_soccer),
        label: const Text('Reservar'),
        backgroundColor: OnzeColors.accent,
        foregroundColor: OnzeColors.onAccent,
      ),
    );
  }

  void _showCreateSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: OnzeColors.surface,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.sports_soccer, color: OnzeColors.accent),
              title: const Text('Desafiar a otro equipo'),
              subtitle: const Text('Partido oficial: cuenta para ELO y ranking'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                context.push(AppRoutes.sendChallenge);
              },
            ),
            ListTile(
              leading: const Icon(Icons.groups_outlined, color: OnzeColors.accent),
              title: const Text('Reserva amistosa'),
              subtitle:
                  const Text('Partido interno de tu equipo, sin estadísticas'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                context.push(
                  AppRoutes.sendChallenge,
                  extra: const SendChallengeArgs(isFriendly: true),
                );
              },
            ),
          ],
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
// Tab: Partidos (resultados)
// ---------------------------------------------------------------------------

class _MatchesTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final matchesAsync = ref.watch(myMatchesProvider);
    final captainTeamIds = ref
        .watch(myCaptainTeamIdsProvider)
        .valueOrNull
        ?.toSet() ??
        const <String>{};

    return matchesAsync.when(
      loading: () => const Center(
          child: CircularProgressIndicator(color: OnzeColors.accent)),
      error: (e, _) => _ErrorView(message: e.toString()),
      data: (matches) {
        if (matches.isEmpty) {
          return const _EmptyView(
              message: 'Tus partidos confirmados aparecerán aquí.');
        }
        return RefreshIndicator(
          color: OnzeColors.accent,
          onRefresh: () async {
            ref.invalidate(myMatchesProvider);
            await ref.read(myMatchesProvider.future);
          },
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
            itemCount: matches.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, index) => _MatchCard(
              match: matches[index],
              captainTeamIds: captainTeamIds,
            ),
          ),
        );
      },
    );
  }
}

class _MatchCard extends StatelessWidget {
  const _MatchCard({required this.match, required this.captainTeamIds});

  final Match match;
  final Set<String> captainTeamIds;

  bool get _myReportPending {
    if (match.status != MatchStatus.awaitingReport) return false;
    if (captainTeamIds.contains(match.teamAId)) return match.teamAReport == null;
    if (captainTeamIds.contains(match.teamBId)) return match.teamBReport == null;
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: OnzeColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: _myReportPending
              ? OnzeColors.error.withValues(alpha: 0.5)
              : OnzeColors.border,
          width: _myReportPending ? 1.5 : 1,
        ),
      ),
      child: Column(
        children: [
          // Header con equipos
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: match.isFriendly
                ? Row(
                    children: [
                      _MiniTeam(
                          name: match.teamAName,
                          shieldUrl: match.teamAShieldUrl),
                      Expanded(
                        child: Column(
                          children: [
                            const _FriendlyChip(),
                            const SizedBox(height: 4),
                            _MatchStatusChip(status: match.status),
                          ],
                        ),
                      ),
                      const SizedBox(width: 80),
                    ],
                  )
                : Row(
                    children: [
                      _MiniTeam(
                          name: match.teamAName,
                          shieldUrl: match.teamAShieldUrl),
                      Expanded(
                        child: Column(
                          children: [
                            Text(
                              'VS',
                              style: GoogleFonts.barlowCondensed(
                                fontSize: 13,
                                fontWeight: FontWeight.w900,
                                color: OnzeColors.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            _MatchStatusChip(status: match.status),
                          ],
                        ),
                      ),
                      _MiniTeam(
                          name: match.teamBName,
                          shieldUrl: match.teamBShieldUrl),
                    ],
                  ),
          ),
          // Info partido
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: OnzeColors.border)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.calendar_today_outlined,
                        size: 13, color: OnzeColors.textSecondary),
                    const SizedBox(width: 4),
                    Text(match.dateLabel,
                        style: Theme.of(context).textTheme.bodySmall),
                    const SizedBox(width: 12),
                    const Icon(Icons.access_time_outlined,
                        size: 13, color: OnzeColors.textSecondary),
                    const SizedBox(width: 4),
                    Text(match.timeRange,
                        style: Theme.of(context).textTheme.bodySmall),
                    const Spacer(),
                    if (_myReportPending && !match.isReportWindowExpired)
                      TextButton(
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => ReportResultScreen(match: match),
                          ),
                        ),
                        style: TextButton.styleFrom(
                          foregroundColor: OnzeColors.error,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 4),
                        ),
                        child: const Text('Reportar',
                            style: TextStyle(fontWeight: FontWeight.w700)),
                      ),
                    if (match.status == MatchStatus.resolved &&
                        match.finalResult != null)
                      _FinalResultChip(result: match.finalResult!),
                  ],
                ),
                // Deadline row — solo visible cuando hay reporte pendiente
                if (_myReportPending) ...[
                  const SizedBox(height: 6),
                  _DeadlineRow(match: match),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DeadlineRow extends StatelessWidget {
  const _DeadlineRow({required this.match});
  final Match match;

  @override
  Widget build(BuildContext context) {
    final expired = match.isReportWindowExpired;
    final color = expired ? OnzeColors.textSecondary : OnzeColors.warning;
    final icon = expired ? Icons.timer_off_outlined : Icons.timer_outlined;

    return Row(
      children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 4),
        Text(
          expired
              ? 'Plazo vencido — pendiente de procesamiento'
              : '${match.deadlineLabel} (${match.countdownLabel})',
          style: TextStyle(fontSize: 11, color: color),
        ),
      ],
    );
  }
}

class _MiniTeam extends StatelessWidget {
  const _MiniTeam({required this.name, this.shieldUrl});
  final String name;
  final String? shieldUrl;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 80,
      child: Column(
        children: [
          OnzeAvatar(imageUrl: shieldUrl, name: name, radius: 22),
          const SizedBox(height: 4),
          Text(
            name,
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(fontWeight: FontWeight.w600),
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
            maxLines: 2,
          ),
        ],
      ),
    );
  }
}

class _MatchStatusChip extends StatelessWidget {
  const _MatchStatusChip({required this.status});
  final MatchStatus status;

  Color get _color => switch (status) {
        MatchStatus.scheduled      => OnzeColors.textSecondary,
        MatchStatus.awaitingReport => OnzeColors.error,
        MatchStatus.disputed       => OnzeColors.warning,
        MatchStatus.resolved       => OnzeColors.accent,
        MatchStatus.cancelled      => OnzeColors.textSecondary,
      };

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: _color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _color.withValues(alpha: 0.4)),
      ),
      child: Text(
        status.label,
        style: TextStyle(
            fontSize: 10, color: _color, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _FinalResultChip extends StatelessWidget {
  const _FinalResultChip({required this.result});
  final MatchFinalResult result;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: OnzeColors.accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Text(
        result.label,
        style: const TextStyle(
            fontSize: 10,
            color: OnzeColors.accent,
            fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _FriendlyChip extends StatelessWidget {
  const _FriendlyChip();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: OnzeColors.highlight.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: OnzeColors.highlight.withValues(alpha: 0.4)),
      ),
      child: const Text(
        'Amistoso',
        style: TextStyle(
            fontSize: 10,
            color: OnzeColors.highlight,
            fontWeight: FontWeight.w600),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Tab: Dueño
// ---------------------------------------------------------------------------

class _OwnerTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pendingAsync = ref.watch(pendingOwnerRequestsProvider);
    final disputedAsync = ref.watch(disputedMatchesForOwnerProvider);

    return RefreshIndicator(
      color: OnzeColors.accent,
      onRefresh: () async {
        ref.invalidate(pendingOwnerRequestsProvider);
        ref.invalidate(disputedMatchesForOwnerProvider);
      },
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        children: [
          // Reservas pendientes de confirmación
          Text('Reservas pendientes',
              style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 12),
          pendingAsync.when(
            loading: () => const Center(
                child: CircularProgressIndicator(color: OnzeColors.accent)),
            error: (e, _) => _ErrorView(message: e.toString()),
            data: (requests) => requests.isEmpty
                ? Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Text('Sin reservas pendientes.',
                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.copyWith(color: OnzeColors.textSecondary)),
                  )
                : Column(
                    children: requests
                        .map((r) => Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: _MatchRequestCard(
                                  request: r, role: _Role.owner),
                            ))
                        .toList(),
                  ),
          ),
          const SizedBox(height: 8),
          // Disputas
          Text('Disputas',
              style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 12),
          disputedAsync.when(
            loading: () => const Center(
                child: CircularProgressIndicator(color: OnzeColors.accent)),
            error: (e, _) => _ErrorView(message: e.toString()),
            data: (matches) => matches.isEmpty
                ? Text('Sin disputas pendientes.',
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(color: OnzeColors.textSecondary))
                : Column(
                    children: matches
                        .map((m) => Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: _DisputeCard(match: m),
                            ))
                        .toList(),
                  ),
          ),
        ],
      ),
    );
  }
}

class _DisputeCard extends ConsumerWidget {
  const _DisputeCard({required this.match});
  final Match match;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(resolveDisputeProvider(match.id));

    ref.listen(resolveDisputeProvider(match.id), (_, next) {
      if (next.resolved) {
        ref.invalidate(disputedMatchesForOwnerProvider);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Disputa resuelta correctamente.'),
              backgroundColor: OnzeColors.accent),
        );
      }
    });

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: OnzeColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
            color: OnzeColors.warning.withValues(alpha: 0.5), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.warning_amber_outlined,
                  color: OnzeColors.warning, size: 16),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  '${match.teamAName} vs ${match.teamBName}',
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${match.dateLabel} · ${match.fieldName}',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: OnzeColors.textSecondary),
          ),
          const SizedBox(height: 8),
          Text(
            'Reportes: ${match.teamAName} → ${match.teamAReport?.label ?? "—"}  |  '
            '${match.teamBName} → ${match.teamBReport?.label ?? "—"}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          if (state.hasError) ...[
            const SizedBox(height: 8),
            Text(state.errorMessage!,
                style: const TextStyle(
                    color: OnzeColors.error, fontSize: 12)),
          ],
          const SizedBox(height: 12),
          if (state.isLoading)
            const Center(
                child: CircularProgressIndicator(
                    color: OnzeColors.accent, strokeWidth: 2))
          else
            Row(
              children: [
                Expanded(
                  child: _ResolveBtn(
                    label: match.teamAName,
                    onTap: () => ref
                        .read(resolveDisputeProvider(match.id).notifier)
                        .resolve(
                            matchId: match.id,
                            resolution: OwnerResolution.teamAWin),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _ResolveBtn(
                    label: 'Empate',
                    onTap: () => ref
                        .read(resolveDisputeProvider(match.id).notifier)
                        .resolve(
                            matchId: match.id,
                            resolution: OwnerResolution.draw),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _ResolveBtn(
                    label: match.teamBName,
                    onTap: () => ref
                        .read(resolveDisputeProvider(match.id).notifier)
                        .resolve(
                            matchId: match.id,
                            resolution: OwnerResolution.teamBWin),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _ResolveBtn extends StatelessWidget {
  const _ResolveBtn({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: OnzeColors.accent.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: OnzeColors.accent.withValues(alpha: 0.4)),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
              fontSize: 11,
              color: OnzeColors.accent,
              fontWeight: FontWeight.w700),
        ),
      ),
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
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: OnzeColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  request.isFriendly
                      ? '${request.challengerTeamName ?? '…'} · Amistoso'
                      : '${request.challengerTeamName ?? '…'} vs ${request.challengedTeamName ?? '…'}',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ),
              if (request.isFriendly) ...[
                const _FriendlyChip(),
                const SizedBox(width: 6),
              ],
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
