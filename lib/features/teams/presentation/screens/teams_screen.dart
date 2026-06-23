// Pantalla principal del feature de equipos.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/routing/app_router.dart';
import '../../../../core/theme/onze_colors.dart';
import '../../../../features/auth/presentation/providers/auth_providers.dart';
import '../../../../shared/widgets/onze_button.dart';
import '../providers/teams_providers.dart';
import '../widgets/team_card.dart';

/// Pantalla de mis equipos con acceso a crear equipo e invitaciones.
class TeamsScreen extends ConsumerStatefulWidget {
  const TeamsScreen({super.key});

  @override
  ConsumerState<TeamsScreen> createState() => _TeamsScreenState();
}

class _TeamsScreenState extends ConsumerState<TeamsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.invalidate(myTeamsProvider);
    });
  }

  @override
  Widget build(BuildContext context) {
    final teamsAsync = ref.watch(myTeamsProvider);
    final userAsync = ref.watch(currentUserProvider);
    final invitationsAsync = ref.watch(myPendingInvitationsProvider);
    final pendingCount =
        invitationsAsync.valueOrNull?.length ?? 0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mis equipos'),
        actions: [
          Stack(
            alignment: Alignment.topRight,
            children: [
              IconButton(
                icon: const Icon(Icons.mail_outline),
                tooltip: 'Invitaciones',
                onPressed: () => context.push(AppRoutes.teamInvitations),
              ),
              if (pendingCount > 0)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: OnzeColors.highlight,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
      body: teamsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: OnzeColors.accent)),
        error: (e, _) => _ErrorView(message: e.toString()),
        data: (teams) {
          if (teams.isEmpty) {
            return _EmptyTeamsView(
              onCreateTap: () => context.push(AppRoutes.createTeam),
            );
          }

          final currentUserId =
              userAsync.valueOrNull?.id ?? '';

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 120),
            itemCount: teams.length + 1,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              if (index == teams.length) {
                return _CreateTeamButton(
                  onTap: () => context.push(AppRoutes.createTeam),
                );
              }
              final team = teams[index];
              return TeamCard(
                team: team,
                isCaptain: team.captainId == currentUserId,
                onTap: () =>
                    context.push(AppRoutes.teamDetail(team.id)),
              );
            },
          );
        },
      ),
    );
  }
}

class _EmptyTeamsView extends StatelessWidget {
  const _EmptyTeamsView({required this.onCreateTap});
  final VoidCallback onCreateTap;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.group_outlined,
              size: 64,
              color: OnzeColors.textSecondary,
            ),
            const SizedBox(height: 16),
            Text(
              'Aún no perteneces a ningún equipo',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: OnzeColors.textSecondary,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            OnzeButton(
              label: 'Crear equipo',
              onPressed: onCreateTap,
              icon: Icons.add,
            ),
          ],
        ),
      ),
    );
  }
}

class _CreateTeamButton extends StatelessWidget {
  const _CreateTeamButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: OnzeColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
              color: OnzeColors.accent.withValues(alpha: 0.4)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.add, color: OnzeColors.accent),
            const SizedBox(width: 8),
            Text(
              'Crear nuevo equipo',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: OnzeColors.accent,
                    fontWeight: FontWeight.w600,
                  ),
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
