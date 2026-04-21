// Pantalla de detalle de un equipo.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/errors/onze_exception.dart';
import '../../../../core/routing/app_router.dart';
import '../../../../core/theme/onze_colors.dart';
import '../../../../core/utils/logger.dart';
import '../../../../features/auth/presentation/providers/auth_providers.dart';
import '../../../../shared/widgets/onze_avatar.dart';
import '../../../../shared/widgets/onze_button.dart';
import '../../../../shared/widgets/onze_card.dart';
import '../../../../features/sanctions/presentation/screens/sanctions_screen.dart';
import '../../../../features/stats/presentation/widgets/team_stats_section.dart';
import '../../domain/models/team.dart';
import '../../domain/models/team_member.dart';
import '../providers/teams_providers.dart';
import 'edit_team_screen.dart';
import '../widgets/join_request_tile.dart';
import '../widgets/team_member_tile.dart';

/// Pantalla de detalle de un equipo con miembros y solicitudes.
class TeamDetailScreen extends ConsumerStatefulWidget {
  const TeamDetailScreen({super.key, required this.teamId});

  final String teamId;

  @override
  ConsumerState<TeamDetailScreen> createState() => _TeamDetailScreenState();
}

class _TeamDetailScreenState extends ConsumerState<TeamDetailScreen> {
  @override
  void initState() {
    super.initState();
    // Invalida al entrar para que siempre se carguen datos frescos.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.invalidate(teamDetailProvider(widget.teamId));
      ref.invalidate(teamMembersProvider(widget.teamId));
    });
  }

  Future<void> _refresh() async {
    ref.invalidate(teamDetailProvider(widget.teamId));
    ref.invalidate(teamMembersProvider(widget.teamId));
    // Esperar a que ambos providers completen.
    await Future.wait([
      ref.read(teamDetailProvider(widget.teamId).future),
      ref.read(teamMembersProvider(widget.teamId).future),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final teamId = widget.teamId;
    final teamAsync = ref.watch(teamDetailProvider(teamId));
    final membersAsync = ref.watch(teamMembersProvider(teamId));
    final currentUserId =
        ref.watch(currentUserProvider).valueOrNull?.id ?? '';

    return Scaffold(
      appBar: AppBar(
        title: teamAsync.whenOrNull(data: (t) => Text(t?.name ?? '')) ??
            const Text('Equipo'),
        actions: [
          teamAsync.whenOrNull(
            data: (team) {
              if (team == null || team.captainId != currentUserId) return null;
              return IconButton(
                icon: const Icon(Icons.edit_outlined),
                tooltip: 'Editar equipo',
                onPressed: () => context.push(
                  AppRoutes.editTeam(team.id),
                  extra: EditTeamArgs(team: team),
                ),
              );
            },
          ) ?? const SizedBox.shrink(),
        ],
      ),
      body: teamAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: OnzeColors.accent)),
        error: (e, _) => _ErrorView(message: e.toString()),
        data: (team) {
          if (team == null) {
            return const _ErrorView(message: 'Equipo no encontrado.');
          }

          final isCaptain = team.captainId == currentUserId;

          return RefreshIndicator(
            color: OnzeColors.accent,
            onRefresh: _refresh,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 32),
                _buildHeader(context, team),
                const SizedBox(height: 24),
                // Sanciones del equipo (si hay tarjetas o suspensión)
                if (team.isActivelySuspended || team.yellowCardsCount > 0) ...[
                  const SizedBox(height: 16),
                  SuspensionStatusCard(
                    isSuspended: team.isSuspended,
                    suspensionUntil: team.suspensionUntil,
                    yellowCardsCount: team.yellowCardsCount,
                    label: 'Estado del equipo',
                  ),
                ],
                const SizedBox(height: 24),
                // Estadísticas del equipo
                const _SectionLabel('ESTADÍSTICAS'),
                const SizedBox(height: 12),
                TeamStatsSection(team: team),
                const SizedBox(height: 12),
                _AchievementsButton(teamId: team.id),
                const SizedBox(height: 32),
                _buildMembersSection(
                  context,
                  ref,
                  membersAsync,
                  currentUserId,
                  isCaptain,
                ),
                if (isCaptain) ...[
                  const SizedBox(height: 32),
                  _buildRequestsSection(context, ref),
                ],
                const SizedBox(height: 32),
                if (!isCaptain)
                  _buildLeaveButton(context, ref, currentUserId),
                const SizedBox(height: 40),
              ],
            ),
          ),
        );
        },
      ),
    );
  }

  Widget _buildHeader(BuildContext context, Team team) {
    return Center(
      child: Column(
        children: [
          OnzeAvatar(imageUrl: team.shieldUrl, name: team.name, radius: 48),
          const SizedBox(height: 12),
          Text(
            team.name,
            style: Theme.of(context).textTheme.displayLarge?.copyWith(
                  fontSize: 22,
                ),
            textAlign: TextAlign.center,
          ),
          if (team.description != null && team.description!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              team.description!,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: OnzeColors.textSecondary,
                  ),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMembersSection(
    BuildContext context,
    WidgetRef ref,
    AsyncValue<List<TeamMember>> membersAsync,
    String currentUserId,
    bool isCaptain,
  ) {
    final memberIds = membersAsync.valueOrNull
            ?.map((m) => m.userId)
            .toSet() ??
        const <String>{};

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Miembros',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const Spacer(),
            if (isCaptain)
              IconButton(
                icon: const Icon(Icons.person_add_outlined,
                    color: OnzeColors.accent),
                tooltip: 'Invitar jugador',
                onPressed: () => context.push(
                  AppRoutes.teamInvite(widget.teamId),
                  extra: memberIds,
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        membersAsync.when(
          loading: () => const LinearProgressIndicator(color: OnzeColors.accent, backgroundColor: OnzeColors.surface),
          error: (e, _) => const SizedBox.shrink(),
          data: (members) => OnzeCard(
            child: Column(
              children: members
                  .map(
                    (m) => TeamMemberTile(
                      member: m,
                      onRemove: isCaptain && m.userId != currentUserId
                          ? () => _removeMember(context, ref, m.userId)
                          : null,
                    ),
                  )
                  .toList(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRequestsSection(BuildContext context, WidgetRef ref) {
    final requestsAsync = ref.watch(pendingRequestsForTeamProvider(widget.teamId));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Solicitudes pendientes',
            style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 12),
        requestsAsync.when(
          loading: () => const LinearProgressIndicator(color: OnzeColors.accent, backgroundColor: OnzeColors.surface),
          error: (e, _) => const SizedBox.shrink(),
          data: (requests) {
            if (requests.isEmpty) {
              return Text(
                'Sin solicitudes pendientes.',
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: OnzeColors.textSecondary),
              );
            }
            return OnzeCard(
              child: Column(
                children: requests
                    .map(
                      (r) => JoinRequestTile(
                        request: r,
                        onAccept: () =>
                            _respondRequest(context, ref, r.id, accept: true),
                        onReject: () =>
                            _respondRequest(context, ref, r.id, accept: false),
                      ),
                    )
                    .toList(),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildLeaveButton(
      BuildContext context, WidgetRef ref, String userId) {
    return OnzeButton(
      label: 'Abandonar equipo',
      onPressed: () => _leaveTeam(context, ref, userId),
      icon: Icons.exit_to_app,
    );
  }

  Future<void> _removeMember(
      BuildContext context, WidgetRef ref, String userId) async {
    try {
      await ref
          .read(teamsRepositoryProvider)
          .removeMember(teamId: widget.teamId, userId: userId);
      ref.invalidate(teamMembersProvider(widget.teamId));
    } on OnzeException catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(e.message), backgroundColor: OnzeColors.error),
      );
    } catch (e, st) {
      log.e('Error al expulsar miembro', error: e, stackTrace: st);
    }
  }

  Future<void> _respondRequest(
    BuildContext context,
    WidgetRef ref,
    String requestId, {
    required bool accept,
  }) async {
    try {
      final repo = ref.read(teamsRepositoryProvider);
      if (accept) {
        await repo.acceptJoinRequest(requestId);
      } else {
        await repo.rejectJoinRequest(requestId);
      }
      ref
        ..invalidate(pendingRequestsForTeamProvider(widget.teamId))
        ..invalidate(teamMembersProvider(widget.teamId));
    } on OnzeException catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(e.message), backgroundColor: OnzeColors.error),
      );
    } catch (e, st) {
      log.e('Error al responder solicitud', error: e, stackTrace: st);
    }
  }

  Future<void> _leaveTeam(
      BuildContext context, WidgetRef ref, String userId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: OnzeColors.surface,
        title: const Text('Abandonar equipo'),
        content:
            const Text('¿Estás seguro de que quieres abandonar este equipo?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text(
              'Abandonar',
              style: TextStyle(color: OnzeColors.error),
            ),
          ),
        ],
      ),
    );

    if (confirm != true || !context.mounted) return;

    try {
      await ref
          .read(teamsRepositoryProvider)
          .leaveTeam(teamId: widget.teamId, userId: userId);
      ref.invalidate(myTeamsProvider);
      if (context.mounted) context.pop();
    } on OnzeException catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(e.message), backgroundColor: OnzeColors.error),
      );
    } catch (e, st) {
      log.e('Error al abandonar equipo', error: e, stackTrace: st);
    }
  }
}

class _AchievementsButton extends StatelessWidget {
  const _AchievementsButton({required this.teamId});
  final String teamId;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push(
        AppRoutes.achievementsTeam(teamId),
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: OnzeColors.surfaceHigh,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: OnzeColors.border),
        ),
        child: Row(
          children: [
            const Icon(Icons.emoji_events_outlined,
                color: OnzeColors.highlight, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Ver vitrina de logros',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
            const Icon(Icons.arrow_forward_ios,
                size: 14, color: OnzeColors.textSecondary),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(text, style: Theme.of(context).textTheme.labelSmall);
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
