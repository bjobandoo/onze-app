/// Estadísticas globales acumuladas de un jugador (tabla public.individual_stats).
class PlayerStats {
  const PlayerStats({
    this.wins = 0,
    this.losses = 0,
    this.draws = 0,
    this.matchesPlayed = 0,
  });

  factory PlayerStats.fromMap(Map<String, dynamic> map) {
    return PlayerStats(
      wins: map['wins'] as int? ?? 0,
      losses: map['losses'] as int? ?? 0,
      draws: map['draws'] as int? ?? 0,
      matchesPlayed: map['matches_played'] as int? ?? 0,
    );
  }

  final int wins;
  final int losses;
  final int draws;
  final int matchesPlayed;

  /// Porcentaje de victorias (0.0 – 1.0).
  double get winRate => matchesPlayed > 0 ? wins / matchesPlayed : 0.0;
}
