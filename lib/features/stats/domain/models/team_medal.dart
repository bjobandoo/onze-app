// Medalla ELO otorgada a un equipo al alcanzar un rango determinado.

import '../../../teams/domain/models/team.dart';

/// Medalla de rango ELO obtenida por un equipo (coleccionable, nunca se pierde).
class TeamMedal {
  const TeamMedal({
    required this.achievementId,
    required this.code,
    required this.name,
    required this.unlockedAt,
  });

  final String achievementId;

  /// Código del logro, p.ej. 'elo_bronce', 'elo_plata', …
  final String code;

  final String name;
  final DateTime unlockedAt;

  /// Tier ELO correspondiente a esta medalla.
  EloTier get tier => _tierFromCode(code);

  static EloTier _tierFromCode(String code) => switch (code) {
        'elo_plata'    => EloTier.plata,
        'elo_oro'      => EloTier.oro,
        'elo_platino'  => EloTier.platino,
        'elo_diamante' => EloTier.diamante,
        _              => EloTier.bronce,
      };

  factory TeamMedal.fromMap(Map<String, dynamic> map) {
    final achievement = map['achievement'] as Map<String, dynamic>;
    return TeamMedal(
      achievementId: achievement['id'] as String,
      code:          achievement['code'] as String,
      name:          achievement['name'] as String,
      unlockedAt:    DateTime.parse(map['unlocked_at'] as String),
    );
  }
}
