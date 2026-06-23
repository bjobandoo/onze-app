// Podio de barras del ranking — top 3, estilo Stadium Night.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/onze_colors.dart';
import '../../../../shared/widgets/onze_avatar.dart';
import '../../../../shared/widgets/onze_pressable.dart';

/// Datos mínimos de un equipo para el podio.
class PodiumTeam {
  const PodiumTeam({
    required this.teamId,
    required this.name,
    required this.elo,
    required this.position,
    this.shieldUrl,
  });

  final String teamId;
  final String name;
  final int elo;
  final int position;
  final String? shieldUrl;
}

/// Gráfico de podio con los 3 primeros equipos del ranking:
/// barras de altura decreciente con el 1.º al centro, resaltado en verde.
class PodiumChart extends StatelessWidget {
  const PodiumChart({
    required this.teams,
    this.onTeamTap,
    super.key,
  });

  /// Equipos ordenados por posición (1.º, 2.º, 3.º).
  final List<PodiumTeam> teams;
  final ValueChanged<String>? onTeamTap;

  @override
  Widget build(BuildContext context) {
    if (teams.length < 3) return const SizedBox.shrink();

    // Orden visual: 2.º — 1.º — 3.º, con el campeón al centro.
    final ordered = [teams[1], teams[0], teams[2]];
    const heights = [74.0, 100.0, 58.0];

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (int i = 0; i < 3; i++) ...[
          if (i > 0) const SizedBox(width: 10),
          Expanded(
            child: _PodiumColumn(
              team: ordered[i],
              barHeight: heights[i],
              isFirst: i == 1,
              onTap: onTeamTap,
            ),
          ),
        ],
      ],
    );
  }
}

class _PodiumColumn extends StatelessWidget {
  const _PodiumColumn({
    required this.team,
    required this.barHeight,
    required this.isFirst,
    this.onTap,
  });

  final PodiumTeam team;
  final double barHeight;
  final bool isFirst;
  final ValueChanged<String>? onTap;

  @override
  Widget build(BuildContext context) {
    return OnzePressable(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap == null ? null : () => onTap!(team.teamId),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              decoration: isFirst
                  ? BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: OnzeColors.highlight, width: 2),
                    )
                  : null,
              padding: isFirst ? const EdgeInsets.all(2) : EdgeInsets.zero,
              child: OnzeAvatar(
                imageUrl: team.shieldUrl,
                name: team.name,
                radius: isFirst ? 27 : 22,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              team.name,
              style: GoogleFonts.barlow(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                height: 1.2,
                color: OnzeColors.textPrimary,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              height: barHeight,
              decoration: BoxDecoration(
                color: isFirst ? OnzeColors.greenGlow : OnzeColors.surface,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(14),
                  bottom: Radius.circular(6),
                ),
                border: Border.all(
                  color: isFirst
                      ? OnzeColors.highlight.withValues(alpha: 0.3)
                      : OnzeColors.border,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '${team.elo}',
                    style: GoogleFonts.barlowCondensed(
                      fontSize: isFirst ? 26 : 20,
                      fontWeight: FontWeight.w700,
                      height: 1.1,
                      color: isFirst
                          ? OnzeColors.highlight
                          : OnzeColors.textPrimary,
                    ),
                  ),
                  Text(
                    'ELO · ${team.position}º',
                    style: GoogleFonts.barlowCondensed(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 1.5,
                      color: OnzeColors.textDim,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
