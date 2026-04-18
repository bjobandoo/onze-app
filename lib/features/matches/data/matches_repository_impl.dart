// Implementación del repositorio de partidos usando Supabase.

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../../../core/errors/onze_exception.dart';
import '../../../core/utils/logger.dart';
import '../../../shared/services/supabase_service.dart';
import '../../fields/domain/models/field_schedule.dart';
import '../../teams/domain/models/team.dart';
import '../domain/matches_repository.dart';
import '../domain/models/match.dart';
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

  // ---------------------------------------------------------------------------
  // Matches (partidos oficiales)
  // ---------------------------------------------------------------------------

  static const _matchSelect = '''
    *,
    team_a:teams!team_a_id(id, name, shield_url),
    team_b:teams!team_b_id(id, name, shield_url),
    field:fields!field_id(id, name, address)
  ''';

  @override
  Future<void> markMatchesAwaitingReport() async {
    try {
      await supabase.rpc('mark_matches_awaiting_report');
    } catch (e) {
      log.w('mark_matches_awaiting_report falló (no crítico): $e');
    }
  }

  @override
  Future<List<Match>> getMyMatches(List<String> teamIds) async {
    if (teamIds.isEmpty) return [];
    try {
      final idList = teamIds.join(',');
      final rows = await supabase
          .from('matches')
          .select(_matchSelect)
          .or('team_a_id.in.($idList),team_b_id.in.($idList)')
          .order('match_date', ascending: false)
          .order('start_time', ascending: false);

      return rows.map(Match.fromMap).toList();
    } on sb.PostgrestException catch (e) {
      log.e('Error al obtener partidos', error: e);
      throw DatabaseException('No se pudieron cargar los partidos.', code: e.code);
    }
  }

  @override
  Future<List<Match>> getDisputedMatchesForOwner(String ownerId) async {
    try {
      // Obtener IDs de canchas del dueño
      final fieldRows = await supabase
          .from('fields')
          .select('id')
          .eq('owner_id', ownerId);
      final fieldIds = (fieldRows as List<dynamic>)
          .map((r) => (r as Map<String, dynamic>)['id'] as String)
          .toList();
      if (fieldIds.isEmpty) return [];

      final idList = fieldIds.join(',');
      final rows = await supabase
          .from('matches')
          .select(_matchSelect)
          .eq('status', 'disputed')
          .filter('field_id', 'in', '($idList)')
          .order('match_date', ascending: false);

      return rows.map(Match.fromMap).toList();
    } on sb.PostgrestException catch (e) {
      log.e('Error al obtener partidos en disputa', error: e);
      throw DatabaseException('No se pudieron cargar los partidos.', code: e.code);
    }
  }

  @override
  Future<String> reportMatchResult({
    required String matchId,
    required MatchReport report,
  }) async {
    try {
      final result = await supabase.rpc(
        'report_match_result',
        params: {'p_match_id': matchId, 'p_report': report.dbValue},
      );
      log.i('Resultado reportado: match=$matchId report=${report.dbValue} → $result');
      return result as String;
    } on sb.PostgrestException catch (e) {
      log.e('Error al reportar resultado', error: e);
      throw DatabaseException(
        e.message.contains('Ya reportaste')
            ? 'Ya reportaste el resultado de este partido.'
            : 'No se pudo reportar el resultado.',
        code: e.code,
      );
    }
  }

  @override
  Future<void> resolveMatchDispute({
    required String matchId,
    required OwnerResolution resolution,
  }) async {
    try {
      await supabase.rpc(
        'resolve_match_dispute',
        params: {
          'p_match_id': matchId,
          'p_resolution': resolution.dbValue,
        },
      );
      log.i('Disputa resuelta: match=$matchId resolution=${resolution.dbValue}');
    } on sb.PostgrestException catch (e) {
      log.e('Error al resolver disputa', error: e);
      throw DatabaseException('No se pudo resolver la disputa.', code: e.code);
    }
  }

  static String _fmtDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  static String _fmtTime(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}:00';
}
