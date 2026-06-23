import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/onze_colors.dart';
import '../../domain/models/player_stats.dart';

/// Fila de estadísticas — celdas bold estilo Nike.
class ProfileStatsRow extends StatelessWidget {
  const ProfileStatsRow({super.key, required this.stats});

  final PlayerStats stats;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _StatCell(
          value: stats.matchesPlayed.toString(),
          label: 'Partidos',
        ),
        const SizedBox(width: 8),
        _StatCell(
          value: stats.wins.toString(),
          label: 'Victorias',
          valueColor: OnzeColors.highlight,
        ),
        const SizedBox(width: 8),
        _StatCell(
          value: stats.draws.toString(),
          label: 'Empates',
        ),
        const SizedBox(width: 8),
        _StatCell(
          value: stats.losses.toString(),
          label: 'Derrotas',
          valueColor: OnzeColors.error,
        ),
        const SizedBox(width: 8),
        _StatCell(
          value: _formatRate(stats.winRate),
          label: '% Win',
          valueColor: OnzeColors.highlight,
        ),
      ],
    );
  }

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
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: OnzeColors.surfaceHigh,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: GoogleFonts.barlowCondensed(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: valueColor ?? OnzeColors.textPrimary,
                height: 1.0,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label.toUpperCase(),
              style: GoogleFonts.barlowCondensed(
                fontSize: 9,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.0,
                color: OnzeColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
