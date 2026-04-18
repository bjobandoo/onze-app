// Sección de estadísticas de un equipo (ELO + W/D/L + historial de periodos).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/onze_colors.dart';
import '../../../../features/teams/domain/models/team.dart';
import '../../domain/models/ranking_snapshot.dart';
import '../providers/stats_providers.dart';

/// Muestra el badge ELO, stats globales y historial de periodos de un equipo.
class TeamStatsSection extends ConsumerWidget {
  const TeamStatsSection({super.key, required this.team});

  final Team team;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final periodAsync = ref.watch(teamPeriodHistoryProvider(team.id));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ELO badge prominente
        _EloBadge(team: team),
        const SizedBox(height: 16),
        // Fila de stats globales
        _GlobalStatsRow(team: team),
        // Historial de periodos
        const SizedBox(height: 20),
        Text(
          'HISTORIAL POR PERIODO',
          style: Theme.of(context).textTheme.labelSmall,
        ),
        const SizedBox(height: 8),
        periodAsync.when(
          loading: () => const LinearProgressIndicator(
              color: OnzeColors.accent,
              backgroundColor: OnzeColors.surface),
          error: (e, _) => const SizedBox.shrink(),
          data: (snapshots) => snapshots.isEmpty
              ? Text(
                  'Sin historial de periodos todavía.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: OnzeColors.textSecondary,
                      ),
                )
              : _PeriodHistory(snapshots: snapshots.cast<RankingSnapshot>()),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Badge ELO
// ---------------------------------------------------------------------------

class _EloBadge extends StatelessWidget {
  const _EloBadge({required this.team});
  final Team team;

  @override
  Widget build(BuildContext context) {
    final tier = team.eloTier;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: tier.color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: tier.color.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Text(tier.emoji, style: const TextStyle(fontSize: 32)),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tier.label.toUpperCase(),
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 2,
                    color: tier.color,
                  ),
                ),
                Text(
                  '${team.eloRating} puntos ELO',
                  style: GoogleFonts.inter(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: OnzeColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          // Win rate circular
          _WinRateCircle(winRate: team.winRate),
        ],
      ),
    );
  }
}

class _WinRateCircle extends StatelessWidget {
  const _WinRateCircle({required this.winRate});
  final double winRate;

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        SizedBox(
          width: 56,
          height: 56,
          child: CircularProgressIndicator(
            value: winRate,
            strokeWidth: 5,
            backgroundColor: OnzeColors.border,
            color: OnzeColors.accent,
          ),
        ),
        Text(
          '${(winRate * 100).round()}%',
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: OnzeColors.textPrimary,
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Fila de stats globales
// ---------------------------------------------------------------------------

class _GlobalStatsRow extends StatelessWidget {
  const _GlobalStatsRow({required this.team});
  final Team team;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _StatCell(
            value: team.matchesPlayed.toString(),
            label: 'Partidos',
          ),
        ),
        _divider(),
        Expanded(
          child: _StatCell(
            value: team.wins.toString(),
            label: 'Victorias',
            valueColor: OnzeColors.accent,
          ),
        ),
        _divider(),
        Expanded(
          child: _StatCell(
            value: team.draws.toString(),
            label: 'Empates',
          ),
        ),
        _divider(),
        Expanded(
          child: _StatCell(
            value: team.losses.toString(),
            label: 'Derrotas',
            valueColor: OnzeColors.error,
          ),
        ),
      ],
    );
  }

  Widget _divider() => Container(
        width: 1,
        height: 40,
        color: OnzeColors.border,
      );
}

class _StatCell extends StatelessWidget {
  const _StatCell({
    required this.value,
    required this.label,
    this.valueColor,
  });
  final String value;
  final String label;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: GoogleFonts.inter(
            fontSize: 22,
            fontWeight: FontWeight.w900,
            color: valueColor ?? OnzeColors.textPrimary,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: OnzeColors.textSecondary,
              ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Historial de periodos
// ---------------------------------------------------------------------------

class _PeriodHistory extends StatelessWidget {
  const _PeriodHistory({required this.snapshots});
  final List<RankingSnapshot> snapshots;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: snapshots
          .take(6)
          .map((s) => _PeriodRow(snapshot: s))
          .toList(),
    );
  }
}

class _PeriodRow extends StatelessWidget {
  const _PeriodRow({required this.snapshot});
  final RankingSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final tier = EloTier.fromRating(snapshot.eloAtPeriod);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: OnzeColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: OnzeColors.border),
      ),
      child: Row(
        children: [
          Text(
            '#${snapshot.rankPosition}',
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: snapshot.rankPosition <= 3
                  ? tier.color
                  : OnzeColors.textSecondary,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              snapshot.periodLabel,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          Text(
            '${snapshot.eloAtPeriod} ELO',
            style: TextStyle(
              fontSize: 12,
              color: tier.color,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '${snapshot.winsInPeriod}V/${snapshot.matchesInPeriod}P',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: OnzeColors.textSecondary,
                ),
          ),
        ],
      ),
    );
  }
}
