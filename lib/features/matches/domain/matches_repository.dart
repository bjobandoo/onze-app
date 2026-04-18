// Interfaz del repositorio de partidos y reservas.

import 'package:flutter/material.dart';

import '../../fields/domain/models/field_schedule.dart';
import '../../teams/domain/models/team.dart';
import 'models/match.dart';
import 'models/match_request.dart';

/// Contrato de acceso a datos para el sistema de reservas.
abstract class MatchesRepository {
  /// Envía un desafío desde [challengerTeamId] al [challengedTeamId].
  Future<MatchRequest> sendChallenge({
    required String challengerTeamId,
    required String challengedTeamId,
    required String fieldId,
    required DateTime date,
    required TimeOfDay startTime,
    required TimeOfDay endTime,
    required double price,
  });

  /// Retorna solicitudes donde el usuario es el equipo desafiador.
  Future<List<MatchRequest>> getChallengesAsChallenger(
      List<String> teamIds);

  /// Retorna solicitudes donde el usuario es el equipo desafiado.
  Future<List<MatchRequest>> getChallengesAsChallenged(
      List<String> teamIds);

  /// Retorna solicitudes en estado [pending_owner] para los campos del dueño.
  Future<List<MatchRequest>> getPendingOwnerRequests(String ownerId);

  /// El capitán del equipo desafiado acepta el desafío.
  /// Pasa a [pending_owner] y bloquea el horario 45 minutos.
  Future<void> acceptChallenge(String matchRequestId);

  /// El capitán del equipo desafiado rechaza el desafío.
  Future<void> rejectChallenge(String matchRequestId);

  /// El capitán desafiador cancela el desafío propio.
  Future<void> cancelChallenge(String matchRequestId);

  /// El dueño confirma la reserva (crea el partido oficial).
  Future<void> confirmMatch(String matchRequestId);

  /// El dueño rechaza la reserva.
  Future<void> rejectMatchByOwner(String matchRequestId);

  /// Retorna los horarios disponibles (no reservados) de [fieldId] para [date].
  Future<List<FieldSchedule>> getAvailableSlotsForDate({
    required String fieldId,
    required DateTime date,
  });

  /// Busca equipos por nombre para seleccionar el equipo rival.
  Future<List<Team>> searchTeams(String query,
      {required String excludeTeamId});

  // ---------------------------------------------------------------------------
  // Partidos (matches)
  // ---------------------------------------------------------------------------

  /// Marca como [awaiting_report] los partidos cuya hora ya pasó.
  /// Llamar al abrir la pantalla de partidos.
  Future<void> markMatchesAwaitingReport();

  /// Retorna todos los partidos de los equipos [teamIds] (todos los estados).
  Future<List<Match>> getMyMatches(List<String> teamIds);

  /// Retorna los partidos del dueño [ownerId] en estado [disputed].
  Future<List<Match>> getDisputedMatchesForOwner(String ownerId);

  /// El capitán reporta el resultado de su equipo.
  /// [report] es 'win' | 'loss' | 'draw' desde la perspectiva del capitán.
  /// Retorna el nuevo estado del partido.
  Future<String> reportMatchResult({
    required String matchId,
    required MatchReport report,
  });

  /// El dueño de la cancha resuelve una disputa.
  Future<void> resolveMatchDispute({
    required String matchId,
    required OwnerResolution resolution,
  });
}
