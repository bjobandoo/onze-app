// Entrada del ranking global de equipos.

import '../../../teams/domain/models/team.dart';

/// Representa la posición de un equipo en el ranking global.
class RankingEntry {
  const RankingEntry({
    required this.position,
    required this.teamId,
    required this.teamName,
    required this.eloRating,
    required this.wins,
    required this.losses,
    required this.draws,
    required this.matchesPlayed,
    this.shieldUrl,
  });

  final int position;
  final String teamId;
  final String teamName;
  final String? shieldUrl;
  final int eloRating;
  final int wins;
  final int losses;
  final int draws;
  final int matchesPlayed;

  EloTier get eloTier => EloTier.fromRating(eloRating);

  double get winRate =>
      matchesPlayed > 0 ? wins / matchesPlayed : 0.0;

  factory RankingEntry.fromTeamMap(Map<String, dynamic> map, int position) =>
      RankingEntry(
        position: position,
        teamId: map['id'] as String,
        teamName: map['name'] as String,
        shieldUrl: map['shield_url'] as String?,
        eloRating: map['elo_rating'] as int? ?? 1000,
        wins: map['wins'] as int? ?? 0,
        losses: map['losses'] as int? ?? 0,
        draws: map['draws'] as int? ?? 0,
        matchesPlayed: map['matches_played'] as int? ?? 0,
      );
}
