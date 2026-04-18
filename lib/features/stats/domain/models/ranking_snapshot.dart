// Snapshot del ranking de un equipo en un periodo quincenal o mensual.

/// Tipo de periodo de ranking.
enum RankingPeriodType {
  biweekly,
  monthly;

  static RankingPeriodType fromDb(String v) =>
      v == 'monthly' ? RankingPeriodType.monthly : RankingPeriodType.biweekly;

  String get dbValue => name;

  String get label => this == RankingPeriodType.biweekly ? 'Quincenal' : 'Mensual';
}

/// Posición y stats de un equipo al cierre de un periodo de ranking.
class RankingSnapshot {
  const RankingSnapshot({
    required this.id,
    required this.periodType,
    required this.periodStart,
    required this.periodEnd,
    required this.teamId,
    required this.eloAtPeriod,
    required this.winsInPeriod,
    required this.matchesInPeriod,
    required this.rankPosition,
    this.teamName = '',
    this.teamShieldUrl,
  });

  final String id;
  final RankingPeriodType periodType;
  final DateTime periodStart;
  final DateTime periodEnd;
  final String teamId;
  final int eloAtPeriod;
  final int winsInPeriod;
  final int matchesInPeriod;
  final int rankPosition;

  // Desnormalizados desde teams (poblados al leer)
  final String teamName;
  final String? teamShieldUrl;

  String get periodLabel {
    const months = [
      '', 'ene', 'feb', 'mar', 'abr', 'may', 'jun',
      'jul', 'ago', 'sep', 'oct', 'nov', 'dic',
    ];
    final s = periodStart;
    final e = periodEnd;
    return '${s.day} ${months[s.month]} – ${e.day} ${months[e.month]} ${e.year}';
  }

  factory RankingSnapshot.fromMap(Map<String, dynamic> map) {
    final team = map['team'] as Map<String, dynamic>?;
    return RankingSnapshot(
      id: map['id'] as String,
      periodType: RankingPeriodType.fromDb(map['period_type'] as String),
      periodStart: DateTime.parse(map['period_start'] as String),
      periodEnd: DateTime.parse(map['period_end'] as String),
      teamId: map['team_id'] as String,
      eloAtPeriod: map['elo_at_period'] as int,
      winsInPeriod: map['wins_in_period'] as int? ?? 0,
      matchesInPeriod: map['matches_in_period'] as int? ?? 0,
      rankPosition: map['rank_position'] as int,
      teamName: team?['name'] as String? ?? '',
      teamShieldUrl: team?['shield_url'] as String?,
    );
  }
}
