// Modelo de dominio de una tarjeta amarilla.

enum YellowCardTarget {
  user,
  team;

  static YellowCardTarget fromDb(String v) =>
      v == 'team' ? YellowCardTarget.team : YellowCardTarget.user;
}

enum YellowCardReason {
  falseReport,
  lateCancellation,
  noReport,
  other;

  static YellowCardReason fromDb(String v) => switch (v) {
        'false_report'      => YellowCardReason.falseReport,
        'late_cancellation' => YellowCardReason.lateCancellation,
        'no_report'         => YellowCardReason.noReport,
        _                   => YellowCardReason.other,
      };

  String get dbValue => switch (this) {
        YellowCardReason.falseReport      => 'false_report',
        YellowCardReason.lateCancellation => 'late_cancellation',
        YellowCardReason.noReport         => 'no_report',
        YellowCardReason.other            => 'other',
      };

  String get label => switch (this) {
        YellowCardReason.falseReport      => 'Reporte falso',
        YellowCardReason.lateCancellation => 'Cancelación tardía',
        YellowCardReason.noReport         => 'No reportó resultado',
        YellowCardReason.other            => 'Otra razón',
      };
}

enum AppealStatus {
  pending,
  approved,
  rejected;

  static AppealStatus? fromDb(String? v) => switch (v) {
        'approved' => AppealStatus.approved,
        'rejected' => AppealStatus.rejected,
        'pending'  => AppealStatus.pending,
        _          => null,
      };

  String get label => switch (this) {
        AppealStatus.pending  => 'En revisión',
        AppealStatus.approved => 'Aprobada',
        AppealStatus.rejected => 'Rechazada',
      };
}

/// Tarjeta amarilla emitida a un usuario o equipo.
class YellowCard {
  const YellowCard({
    required this.id,
    required this.targetType,
    required this.targetId,
    required this.reason,
    required this.issuedAt,
    this.matchId,
    this.appealed = false,
    this.appealStatus,
  });

  final String id;
  final YellowCardTarget targetType;
  final String targetId;
  final YellowCardReason reason;
  final DateTime issuedAt;
  final String? matchId;
  final bool appealed;
  final AppealStatus? appealStatus;

  /// La tarjeta puede ser apelada si aún no se apeló.
  bool get canAppeal => !appealed;

  factory YellowCard.fromMap(Map<String, dynamic> map) => YellowCard(
        id: map['id'] as String,
        targetType:
            YellowCardTarget.fromDb(map['target_type'] as String),
        targetId: map['target_id'] as String,
        reason: YellowCardReason.fromDb(map['reason'] as String),
        issuedAt: DateTime.parse(map['issued_at'] as String),
        matchId: map['match_id'] as String?,
        appealed: map['appealed'] as bool? ?? false,
        appealStatus:
            AppealStatus.fromDb(map['appeal_resolution'] as String?),
      );
}
