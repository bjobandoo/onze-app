// Card compacta del equipo del usuario en el ranking — Home Stadium Night.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/routing/app_router.dart';
import '../../../../core/theme/onze_colors.dart';
import '../../../../core/theme/onze_theme.dart';
import '../../../../features/stats/presentation/providers/stats_providers.dart';
import '../../../../features/teams/presentation/providers/teams_providers.dart';
import '../../../../shared/widgets/onze_avatar.dart';
import '../../../../shared/widgets/onze_pressable.dart';

/// Mini-ranking del primer equipo del usuario: posición y ELO actuales.
/// Si el usuario no tiene equipos, invita a crear uno.
class TeamRankCard extends ConsumerWidget {
  const TeamRankCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final teams = ref.watch(myTeamsProvider).valueOrNull ?? [];

    if (teams.isEmpty) return const _CreateTeamCard();

    final team = teams.first;
    final entries = ref.watch(globalRankingProvider).valueOrNull ?? [];
    final entry =
        entries.where((e) => e.teamId == team.id).toList().firstOrNull;

    return OnzePressable(
      child: GestureDetector(
        onTap: () => context.go(AppRoutes.ranking),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          decoration: BoxDecoration(
            color: OnzeColors.surface,
            borderRadius: BorderRadius.circular(OnzeTheme.radiusCard),
            border: Border.all(color: OnzeColors.border),
          ),
          child: Row(
            children: [
              OnzeAvatar(
                  imageUrl: entry?.shieldUrl ?? team.shieldUrl,
                  name: team.name,
                  radius: 19),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      team.name,
                      style: GoogleFonts.barlow(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: OnzeColors.textPrimary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 1),
                    Text(
                      entry != null
                          ? '#${entry.position} en el ranking'
                          : 'Sin partidos oficiales aún',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            fontSize: 12,
                          ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${entry?.eloRating ?? team.eloRating}',
                    style: GoogleFonts.barlowCondensed(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      height: 1.1,
                      color: OnzeColors.textPrimary,
                    ),
                  ),
                  Text(
                    'ELO',
                    style: GoogleFonts.barlowCondensed(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.6,
                      color: OnzeColors.textDim,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right,
                  color: OnzeColors.textDim, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}

class _CreateTeamCard extends StatelessWidget {
  const _CreateTeamCard();

  @override
  Widget build(BuildContext context) {
    return OnzePressable(
      child: GestureDetector(
        onTap: () => context.push(AppRoutes.createTeam),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: OnzeColors.surface,
            borderRadius: BorderRadius.circular(OnzeTheme.radiusCard),
            border: Border.all(color: OnzeColors.border),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: OnzeColors.greenGlow,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: const Icon(Icons.group_add_outlined,
                    color: OnzeColors.highlight, size: 21),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Crea tu equipo',
                      style: GoogleFonts.barlowCondensed(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                        color: OnzeColors.textPrimary,
                      ),
                    ),
                    Text(
                      'Y empieza a competir en el ranking',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right,
                  color: OnzeColors.textDim, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}
