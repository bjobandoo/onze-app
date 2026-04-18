// Modelo de dominio de un partido oficial confirmado.

import 'package:flutter/material.dart';

// ---------------------------------------------------------------------------
// Enums
// ---------------------------------------------------------------------------

enum MatchStatus {
  scheduled,
  awaitingReport,
  disputed,
  resolved,
  cancelled;

  static MatchStatus fromDb(String value) => switch (value) {
        'scheduled'       => MatchStatus.scheduled,
        'awaiting_report' => MatchStatus.awaitingReport,
        'disputed'        => MatchStatus.disputed,
        'resolved'        => MatchStatus.resolved,
        _                 => MatchStatus.cancelled,
      };

  String get dbValue => switch (this) {
        MatchStatus.scheduled       => 'scheduled',
        MatchStatus.awaitingReport  => 'awaiting_report',
        MatchStatus.disputed        => 'disputed',
        MatchStatus.resolved        => 'resolved',
        MatchStatus.cancelled       => 'cancelled',
      };

  String get label => switch (this) {
        MatchStatus.scheduled       => 'Programado',
        MatchStatus.awaitingReport  => 'Pendiente de reporte',
        MatchStatus.disputed        => 'En disputa',
        MatchStatus.resolved        => 'Resuelto',
        MatchStatus.cancelled       => 'Cancelado',
      };
}

enum MatchReport {
  win,
  loss,
  draw;

  static MatchReport? fromDb(String? value) => switch (value) {
        'win'  => MatchReport.win,
        'loss' => MatchReport.loss,
        'draw' => MatchReport.draw,
        _      => null,
      };

  String get dbValue => name; // 'win' | 'loss' | 'draw'

  String get label => switch (this) {
        MatchReport.win  => 'Ganamos',
        MatchReport.loss => 'Perdimos',
        MatchReport.draw => 'Empatamos',
      };
}

enum OwnerResolution {
  teamAWin,
  teamBWin,
  draw;

  static OwnerResolution? fromDb(String? value) => switch (value) {
        'team_a_win' => OwnerResolution.teamAWin,
        'team_b_win' => OwnerResolution.teamBWin,
        'draw'       => OwnerResolution.draw,
        _            => null,
      };

  String get dbValue => switch (this) {
        OwnerResolution.teamAWin => 'team_a_win',
        OwnerResolution.teamBWin => 'team_b_win',
        OwnerResolution.draw     => 'draw',
      };
}

enum MatchFinalResult {
  teamAWin,
  teamBWin,
  draw;

  static MatchFinalResult? fromDb(String? value) => switch (value) {
        'team_a_win' => MatchFinalResult.teamAWin,
        'team_b_win' => MatchFinalResult.teamBWin,
        'draw'       => MatchFinalResult.draw,
        _            => null,
      };

  String get label => switch (this) {
        MatchFinalResult.teamAWin => 'Victoria equipo A',
        MatchFinalResult.teamBWin => 'Victoria equipo B',
        MatchFinalResult.draw     => 'Empate',
      };
}

// ---------------------------------------------------------------------------
// Modelo
// ---------------------------------------------------------------------------

/// Partido oficial confirmado por el dueño de la cancha.
class Match {
  const Match({
    required this.id,
    required this.matchRequestId,
    required this.teamAId,
    required this.teamBId,
    required this.fieldId,
    required this.matchDate,
    required this.startTime,
    required this.endTime,
    required this.status,
    this.teamAReport,
    this.teamBReport,
    this.ownerResolution,
    this.finalResult,
    this.teamAEloChange = 0,
    this.teamBEloChange = 0,
    this.reportedAt,
    this.resolvedAt,
    // Desnormalizados para display
    this.teamAName = '',
    this.teamBName = '',
    this.teamAShieldUrl,
    this.teamBShieldUrl,
    this.fieldName = '',
    this.fieldAddress = '',
  });

  final String id;
  final String matchRequestId;
  final String teamAId;
  final String teamBId;
  final String fieldId;
  final DateTime matchDate;
  final TimeOfDay startTime;
  final TimeOfDay endTime;
  final MatchStatus status;
  final MatchReport? teamAReport;
  final MatchReport? teamBReport;
  final OwnerResolution? ownerResolution;
  final MatchFinalResult? finalResult;
  final int teamAEloChange;
  final int teamBEloChange;
  final DateTime? reportedAt;
  final DateTime? resolvedAt;

  // Desnormalizados
  final String teamAName;
  final String teamBName;
  final String? teamAShieldUrl;
  final String? teamBShieldUrl;
  final String fieldName;
  final String fieldAddress;

  factory Match.fromMap(Map<String, dynamic> map) {
    final teamA = map['team_a'] as Map<String, dynamic>? ?? {};
    final teamB = map['team_b'] as Map<String, dynamic>? ?? {};
    final field = map['field'] as Map<String, dynamic>? ?? {};

    final startParts =
        (map['start_time'] as String).split(':');
    final endParts =
        (map['end_time'] as String).split(':');

    return Match(
      id: map['id'] as String,
      matchRequestId: map['match_request_id'] as String,
      teamAId: map['team_a_id'] as String,
      teamBId: map['team_b_id'] as String,
      fieldId: map['field_id'] as String,
      matchDate: DateTime.parse(map['match_date'] as String),
      startTime: TimeOfDay(
        hour: int.parse(startParts[0]),
        minute: int.parse(startParts[1]),
      ),
      endTime: TimeOfDay(
        hour: int.parse(endParts[0]),
        minute: int.parse(endParts[1]),
      ),
      status: MatchStatus.fromDb(map['status'] as String),
      teamAReport: MatchReport.fromDb(map['team_a_report'] as String?),
      teamBReport: MatchReport.fromDb(map['team_b_report'] as String?),
      ownerResolution:
          OwnerResolution.fromDb(map['owner_resolution'] as String?),
      finalResult:
          MatchFinalResult.fromDb(map['final_result'] as String?),
      teamAEloChange: map['team_a_elo_change'] as int? ?? 0,
      teamBEloChange: map['team_b_elo_change'] as int? ?? 0,
      reportedAt: map['reported_at'] != null
          ? DateTime.parse(map['reported_at'] as String)
          : null,
      resolvedAt: map['resolved_at'] != null
          ? DateTime.parse(map['resolved_at'] as String)
          : null,
      teamAName: teamA['name'] as String? ?? '',
      teamBName: teamB['name'] as String? ?? '',
      teamAShieldUrl: teamA['shield_url'] as String?,
      teamBShieldUrl: teamB['shield_url'] as String?,
      fieldName: field['name'] as String? ?? '',
      fieldAddress: field['address'] as String? ?? '',
    );
  }

  /// Formato de horario "14:00 – 16:00".
  String get timeRange {
    String fmt(TimeOfDay t) =>
        '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
    return '${fmt(startTime)} – ${fmt(endTime)}';
  }

  /// Fecha formateada "lun 14 abr".
  String get dateLabel {
    const months = [
      '', 'ene', 'feb', 'mar', 'abr', 'may', 'jun',
      'jul', 'ago', 'sep', 'oct', 'nov', 'dic',
    ];
    const days = ['', 'lun', 'mar', 'mié', 'jue', 'vie', 'sáb', 'dom'];
    return '${days[matchDate.weekday]} ${matchDate.day} ${months[matchDate.month]}';
  }

  // ---------------------------------------------------------------------------
  // Ventana de 24h para reporte
  // ---------------------------------------------------------------------------

  /// Fin del partido como DateTime.
  DateTime get matchEndDateTime => DateTime(
        matchDate.year,
        matchDate.month,
        matchDate.day,
        endTime.hour,
        endTime.minute,
      );

  /// Límite para reportar: fin del partido + 24 horas.
  DateTime get reportDeadline =>
      matchEndDateTime.add(const Duration(hours: 24));

  /// True si el plazo de reporte ya venció y el partido sigue en awaiting_report.
  bool get isReportWindowExpired =>
      status == MatchStatus.awaitingReport &&
      DateTime.now().isAfter(reportDeadline);

  /// Tiempo restante hasta el deadline (puede ser negativo si ya venció).
  Duration get timeUntilDeadline =>
      reportDeadline.difference(DateTime.now());

  /// Etiqueta legible del deadline, ej. "hasta el lun 14 abr a las 22:00".
  String get deadlineLabel {
    const months = [
      '', 'ene', 'feb', 'mar', 'abr', 'may', 'jun',
      'jul', 'ago', 'sep', 'oct', 'nov', 'dic',
    ];
    final d = reportDeadline;
    final hh = d.hour.toString().padLeft(2, '0');
    final mm = d.minute.toString().padLeft(2, '0');
    return 'Hasta el ${d.day} ${months[d.month]} a las $hh:$mm';
  }

  /// Etiqueta de countdown "X h Y min" o "Plazo vencido".
  String get countdownLabel {
    final remaining = timeUntilDeadline;
    if (remaining.isNegative) return 'Plazo vencido';
    final hours = remaining.inHours;
    final minutes = remaining.inMinutes.remainder(60);
    if (hours > 0) return '$hours h ${minutes.toString().padLeft(2, '0')} min';
    return '$minutes min';
  }
}
