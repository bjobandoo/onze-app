// Modelo de solicitud de partido (desafío) y sus estados.

import 'package:flutter/material.dart';

/// Estados del ciclo de vida de un desafío.
enum MatchRequestStatus {
  pendingOpponent,
  pendingOwner,
  confirmed,
  rejected,
  expired,
  cancelled;

  static MatchRequestStatus fromDb(String v) => switch (v) {
        'pending_opponent' => pendingOpponent,
        'pending_owner' => pendingOwner,
        'confirmed' => confirmed,
        'rejected' => rejected,
        'expired' => expired,
        'cancelled' => cancelled,
        _ => throw ArgumentError('Unknown match request status: $v'),
      };

  String get dbValue => switch (this) {
        pendingOpponent => 'pending_opponent',
        pendingOwner => 'pending_owner',
        confirmed => 'confirmed',
        rejected => 'rejected',
        expired => 'expired',
        cancelled => 'cancelled',
      };

  String get label => switch (this) {
        pendingOpponent => 'Esperando rival',
        pendingOwner => 'Esperando dueño',
        confirmed => 'Confirmado',
        rejected => 'Rechazado',
        expired => 'Expirado',
        cancelled => 'Cancelado',
      };
}

/// Solicitud de partido entre dos equipos.
///
/// Ciclo de vida: pending_opponent → pending_owner → confirmed
///                                 ↘ rejected / cancelled / expired
class MatchRequest {
  const MatchRequest({
    required this.id,
    required this.challengerTeamId,
    required this.challengedTeamId,
    required this.fieldId,
    required this.requestedDate,
    required this.requestedStartTime,
    required this.requestedEndTime,
    required this.price,
    required this.status,
    required this.createdAt,
    this.isFriendly = false,
    this.blockedUntil,
    this.challengerTeamName,
    this.challengedTeamName,
    this.fieldName,
    this.fieldAddress,
  });

  final String id;
  final String challengerTeamId;

  /// Equipo rival. `null` en reservas amistosas (un solo equipo).
  final String? challengedTeamId;
  final String fieldId;
  final DateTime requestedDate;
  final TimeOfDay requestedStartTime;
  final TimeOfDay requestedEndTime;
  final double price;
  final MatchRequestStatus status;

  /// True si es una reserva amistosa (sin equipo rival, sin ELO/estadísticas).
  final bool isFriendly;
  final DateTime? blockedUntil;
  final DateTime createdAt;

  // Datos desnormalizados para display
  final String? challengerTeamName;
  final String? challengedTeamName;
  final String? fieldName;
  final String? fieldAddress;

  /// Verdadero si el bloqueo de 45 minutos ha expirado.
  bool get isExpired {
    if (status != MatchRequestStatus.pendingOwner) return false;
    final until = blockedUntil;
    if (until == null) return false;
    return DateTime.now().isAfter(until);
  }

  String get timeRange =>
      '${_fmt(requestedStartTime)} – ${_fmt(requestedEndTime)}';

  static String _fmt(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  factory MatchRequest.fromMap(Map<String, dynamic> map) {
    final challenger = map['challenger_team'] as Map<String, dynamic>?;
    final challenged = map['challenged_team'] as Map<String, dynamic>?;
    final field = map['field'] as Map<String, dynamic>?;

    return MatchRequest(
      id: map['id'] as String,
      challengerTeamId: map['challenger_team_id'] as String,
      challengedTeamId: map['challenged_team_id'] as String?,
      fieldId: map['field_id'] as String,
      requestedDate: DateTime.parse(map['requested_date'] as String),
      requestedStartTime:
          _parseTime(map['requested_start_time'] as String),
      requestedEndTime: _parseTime(map['requested_end_time'] as String),
      price: (map['price'] as num).toDouble(),
      status:
          MatchRequestStatus.fromDb(map['status'] as String),
      isFriendly: map['is_friendly'] as bool? ?? false,
      blockedUntil: map['blocked_until'] != null
          ? DateTime.parse(map['blocked_until'] as String)
          : null,
      createdAt: DateTime.parse(map['created_at'] as String),
      challengerTeamName: challenger?['name'] as String?,
      challengedTeamName: challenged?['name'] as String?,
      fieldName: field?['name'] as String?,
      fieldAddress: field?['address'] as String?,
    );
  }

  static TimeOfDay _parseTime(String s) {
    final parts = s.split(':');
    return TimeOfDay(
        hour: int.parse(parts[0]), minute: int.parse(parts[1]));
  }
}
