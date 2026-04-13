// Implementación del repositorio de partidos usando Supabase.

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../../../core/errors/onze_exception.dart';
import '../../../core/utils/logger.dart';
import '../../../shared/services/supabase_service.dart';
import '../../fields/domain/models/field_schedule.dart';
import '../../teams/domain/models/team.dart';
import '../domain/matches_repository.dart';
import '../domain/models/match_request.dart';

/// Selector de columnas para match_requests con equipos y campo desnormalizados.
const _matchRequestSelect = '''
  *,
  challenger_team:teams!challenger_team_id(id, name),
  challenged_team:teams!challenged_team_id(id, name),
  field:fields!field_id(id, name, address)
''';

class MatchesRepositoryImpl implements MatchesRepository {
  @override
  Future<MatchRequest> sendChallenge({
    required String challengerTeamId,
    required String challengedTeamId,
    required String fieldId,
    required DateTime date,
    required TimeOfDay startTime,
    required TimeOfDay endTime,
    required double price,
  }) async {
    try {
      final row = await supabase
          .from('match_requests')
          .insert({
            'challenger_team_id': challengerTeamId,
            'challenged_team_id': challengedTeamId,
            'field_id': fieldId,
            'requested_date': _fmtDate(date),
            'requested_start_time': _fmtTime(startTime),
            'requested_end_time': _fmtTime(endTime),
            'price': price,
            'status': 'pending_opponent',
          })
          .select(_matchRequestSelect)
          .single();

      log.i('Desafío enviado: ${row['id']}');
      return MatchRequest.fromMap(row);
    } on sb.PostgrestException catch (e) {
      log.e('Error al enviar desafío', error: e);
      throw DatabaseException('No se pudo enviar el desafío.', code: e.code);
    }
  }

  @override
  Future<List<MatchRequest>> getChallengesAsChallenger(
      List<String> teamIds) async {
    if (teamIds.isEmpty) return [];
    try {
      final rows = await supabase
          .from('match_requests')
          .select(_matchRequestSelect)
          .inFilter('challenger_team_id', teamIds)
          .order('created_at', ascending: false);

      return rows.map(MatchRequest.fromMap).toList();
    } on sb.PostgrestException catch (e) {
      log.e('Error al obtener desafíos enviados', error: e);
      throw DatabaseException('No se pudieron cargar los desafíos.', code: e.code);
    }
  }

  @override
  Future<List<MatchRequest>> getChallengesAsChallenged(
      List<String> teamIds) async {
    if (teamIds.isEmpty) return [];
    try {
      final rows = await supabase
          .from('match_requests')
          .select(_matchRequestSelect)
          .inFilter('challenged_team_id', teamIds)
          .order('created_at', ascending: false);

      return rows.map(MatchRequest.fromMap).toList();
    } on sb.PostgrestException catch (e) {
      log.e('Error al obtener desafíos recibidos', error: e);
      throw DatabaseException('No se pudieron cargar los desafíos.', code: e.code);
    }
  }

  @override
  Future<List<MatchRequest>> getPendingOwnerRequests(String ownerId) async {
    try {
      final rows = await supabase
          .from('match_requests')
          .select(_matchRequestSelect)
          .eq('status', 'pending_owner')
          .order('created_at', ascending: false);

      // Filtrar por canchas del dueño se hace vía RLS
      return rows.map(MatchRequest.fromMap).toList();
    } on sb.PostgrestException catch (e) {
      log.e('Error al obtener solicitudes pendientes del dueño', error: e);
      throw DatabaseException('No se pudieron cargar las solicitudes.', code: e.code);
    }
  }

  @override
  Future<void> acceptChallenge(String matchRequestId) async {
    final blockedUntil =
        DateTime.now().toUtc().add(const Duration(minutes: 45));
    try {
      await supabase.from('match_requests').update({
        'status': 'pending_owner',
        'blocked_until': blockedUntil.toIso8601String(),
        'opponent_responded_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', matchRequestId);

      log.i('Desafío $matchRequestId aceptado (bloqueo hasta $blockedUntil)');
    } on sb.PostgrestException catch (e) {
      log.e('Error al aceptar desafío', error: e);
      throw DatabaseException('No se pudo aceptar el desafío.', code: e.code);
    }
  }

  @override
  Future<void> rejectChallenge(String matchRequestId) async {
    try {
      await supabase.from('match_requests').update({
        'status': 'rejected',
        'opponent_responded_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', matchRequestId);

      log.i('Desafío $matchRequestId rechazado por capitán');
    } on sb.PostgrestException catch (e) {
      log.e('Error al rechazar desafío', error: e);
      throw DatabaseException('No se pudo rechazar el desafío.', code: e.code);
    }
  }

  @override
  Future<void> cancelChallenge(String matchRequestId) async {
    try {
      await supabase.from('match_requests').update({
        'status': 'cancelled',
        'challenger_responded_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', matchRequestId);

      log.i('Desafío $matchRequestId cancelado por desafiador');
    } on sb.PostgrestException catch (e) {
      log.e('Error al cancelar desafío', error: e);
      throw DatabaseException('No se pudo cancelar el desafío.', code: e.code);
    }
  }

  @override
  Future<void> confirmMatch(String matchRequestId) async {
    try {
      await supabase.rpc('confirm_match',
          params: {'p_match_request_id': matchRequestId});
      log.i('Reserva confirmada: $matchRequestId');
    } on sb.PostgrestException catch (e) {
      log.e('Error al confirmar reserva', error: e);
      final msg = e.message.contains('expirado')
          ? 'El bloqueo expiró. El horario ya no está reservado.'
          : 'No se pudo confirmar la reserva.';
      throw DatabaseException(msg, code: e.code);
    }
  }

  @override
  Future<void> rejectMatchByOwner(String matchRequestId) async {
    try {
      await supabase.from('match_requests').update({
        'status': 'rejected',
        'owner_responded_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', matchRequestId);

      log.i('Reserva $matchRequestId rechazada por dueño');
    } on sb.PostgrestException catch (e) {
      log.e('Error al rechazar reserva', error: e);
      throw DatabaseException('No se pudo rechazar la reserva.', code: e.code);
    }
  }

  @override
  Future<List<FieldSchedule>> getAvailableSlotsForDate({
    required String fieldId,
    required DateTime date,
  }) async {
    try {
      // 0=domingo, 1=lunes … 6=sábado. Dart: 1=Mon…7=Sun → %7 da 0 para domingo ✓
      final dayOfWeek = date.weekday % 7;
      final dateStr = _fmtDate(date);

      // Horarios configurados para ese día
      final scheduleRows = await supabase
          .from('field_schedules')
          .select()
          .eq('field_id', fieldId)
          .eq('day_of_week', dayOfWeek)
          .eq('is_active', true);

      final schedules =
          scheduleRows.map(FieldSchedule.fromMap).toList();

      if (schedules.isEmpty) return [];

      // Slots ya reservados para esa fecha (activos o confirmados)
      final bookedRows = await supabase
          .from('match_requests')
          .select('requested_start_time, requested_end_time')
          .eq('field_id', fieldId)
          .eq('requested_date', dateStr)
          .inFilter('status', ['pending_opponent', 'pending_owner', 'confirmed']);

      final booked = bookedRows.map((r) {
        final parts0 = (r['requested_start_time'] as String).split(':');
        final parts1 = (r['requested_end_time'] as String).split(':');
        return (
          startMin: int.parse(parts0[0]) * 60 + int.parse(parts0[1]),
          endMin: int.parse(parts1[0]) * 60 + int.parse(parts1[1]),
        );
      }).toList();

      // Filtrar: un horario está disponible si no se superpone con ningún booked
      return schedules.where((s) {
        final sStart = s.startTime.hour * 60 + s.startTime.minute;
        final sEnd = s.endTime.hour * 60 + s.endTime.minute;
        return !booked.any(
            (b) => b.startMin < sEnd && b.endMin > sStart);
      }).toList();
    } on sb.PostgrestException catch (e) {
      log.e('Error al obtener horarios disponibles', error: e);
      throw DatabaseException(
          'No se pudieron cargar los horarios.', code: e.code);
    }
  }

  @override
  Future<List<Team>> searchTeams(String query,
      {required String excludeTeamId}) async {
    if (query.trim().length < 2) return [];
    try {
      final rows = await supabase
          .from('teams')
          .select('id, name, captain_id, created_at, shield_url, is_active')
          .ilike('name', '%${query.trim()}%')
          .neq('id', excludeTeamId)
          .limit(20);

      return rows.map(Team.fromMap).toList();
    } on sb.PostgrestException catch (e) {
      log.e('Error al buscar equipos', error: e);
      throw DatabaseException('No se pudieron buscar equipos.', code: e.code);
    }
  }

  static String _fmtDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  static String _fmtTime(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}:00';
}
