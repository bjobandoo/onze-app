// Enumerados de dominio del feature de canchas.

/// Tipo de cancha según cantidad de jugadores por lado.
enum FieldType {
  v5x5,
  v6x6,
  v7x7,
  v8x8;

  String get label => switch (this) {
        FieldType.v5x5 => '5 vs 5',
        FieldType.v6x6 => '6 vs 6',
        FieldType.v7x7 => '7 vs 7',
        FieldType.v8x8 => '8 vs 8',
      };

  /// Valor almacenado en la BD ('5v5', '6v6', …).
  String get dbValue => switch (this) {
        FieldType.v5x5 => '5v5',
        FieldType.v6x6 => '6v6',
        FieldType.v7x7 => '7v7',
        FieldType.v8x8 => '8v8',
      };

  static FieldType fromDb(String value) =>
      FieldType.values.firstWhere((e) => e.dbValue == value);
}
