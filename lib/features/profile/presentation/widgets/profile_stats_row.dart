import 'package:flutter/material.dart';

import '../../../../core/theme/onze_colors.dart';
import '../../domain/models/player_stats.dart';

/// Fila de estadísticas de partidos: PJ / V / E / D y % victorias.
class ProfileStatsRow extends StatelessWidget {
  const ProfileStatsRow({super.key, required this.stats});

  final PlayerStats stats;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: OnzeColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: OnzeColors.border),
      ),
      child: Row(
        children: [
          _StatCell(
            value: stats.matchesPlayed.toString(),
            label: 'Partidos',
          ),
          _divider(),
          _StatCell(
            value: stats.wins.toString(),
            label: 'Victorias',
            valueColor: OnzeColors.highlight,
          ),
          _divider(),
          _StatCell(
            value: stats.draws.toString(),
            label: 'Empates',
          ),
          _divider(),
          _StatCell(
            value: stats.losses.toString(),
            label: 'Derrotas',
            valueColor: OnzeColors.error,
          ),
          _divider(),
          _StatCell(
            value: _formatRate(stats.winRate),
            label: '% Victorias',
            valueColor: OnzeColors.highlight,
          ),
        ],
      ),
    );
  }

  Widget _divider() => Container(
        width: 1,
        height: 36,
        color: OnzeColors.border,
      );

  String _formatRate(double rate) => '${(rate * 100).round()}%';
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
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: valueColor ?? OnzeColors.textPrimary,
                  fontSize: 18,
                ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
