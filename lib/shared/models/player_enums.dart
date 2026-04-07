// Enumerados de dominio del jugador.
// Compartidos entre auth (creación de perfil) y profile (edición).

enum PlayerPosition {
  portero,
  defensa,
  mediocampista,
  delantero;

  String get label => switch (this) {
        PlayerPosition.portero => 'Portero',
        PlayerPosition.defensa => 'Defensa',
        PlayerPosition.mediocampista => 'Mediocampista',
        PlayerPosition.delantero => 'Delantero',
      };

  String get dbValue => name;

  static PlayerPosition fromDb(String value) =>
      PlayerPosition.values.firstWhere((e) => e.name == value);
}

enum DominantFoot {
  izquierdo,
  derecho,
  ambidiestro;

  String get label => switch (this) {
        DominantFoot.izquierdo => 'Izquierdo',
        DominantFoot.derecho => 'Derecho',
        DominantFoot.ambidiestro => 'Ambidiestro',
      };

  String get dbValue => name;

  static DominantFoot fromDb(String value) =>
      DominantFoot.values.firstWhere((e) => e.name == value);
}

enum ExperienceLevel {
  principiante,
  intermedio,
  avanzado;

  String get label => switch (this) {
        ExperienceLevel.principiante => 'Principiante',
        ExperienceLevel.intermedio => 'Intermedio',
        ExperienceLevel.avanzado => 'Avanzado',
      };

  String get dbValue => name;

  static ExperienceLevel fromDb(String value) =>
      ExperienceLevel.values.firstWhere((e) => e.name == value);
}
