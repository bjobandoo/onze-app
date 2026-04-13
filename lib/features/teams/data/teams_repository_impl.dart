// Implementación del repositorio de equipos usando Supabase.

import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../../../core/errors/onze_exception.dart';
import '../../../core/utils/logger.dart';
import '../../../shared/models/app_user.dart';
import '../../../shared/services/supabase_service.dart';
import '../domain/models/team.dart';
import '../domain/models/team_join_request.dart';
import '../domain/models/team_member.dart';
import '../domain/teams_repository.dart';

/// Implementación de [TeamsRepository] usando Supabase.
class TeamsRepositoryImpl implements TeamsRepository {
  static const _shieldBucket = 'team-shields';

  @override
  Future<List<Team>> getMyTeams(String userId) async {
    try {
      final rows = await supabase
          .from('team_members')
          .select('teams(*)')
          .eq('user_id', userId);

      return rows
          .map((r) => Team.fromMap(r['teams'] as Map<String, dynamic>))
          .toList();
    } on sb.PostgrestException catch (e) {
      log.e('Error al obtener equipos del usuario', error: e);
      throw DatabaseException('No se pudieron cargar los equipos.', code: e.code);
    }
  }

  @override
  Future<Team?> getTeamById(String teamId) async {
    try {
      final data = await supabase
          .from('teams')
          .select()
          .eq('id', teamId)
          .maybeSingle();

      if (data == null) return null;
      return Team.fromMap(data);
    } on sb.PostgrestException catch (e) {
      log.e('Error al obtener equipo $teamId', error: e);
      throw DatabaseException('No se pudo cargar el equipo.', code: e.code);
    }
  }

  @override
  Future<List<TeamMember>> getTeamMembers(String teamId) async {
    try {
      final rows = await supabase
          .from('team_members')
          .select('*, users(full_name, avatar_url)')
          .eq('team_id', teamId)
          .order('joined_at');

      return rows.map(TeamMember.fromMap).toList();
    } on sb.PostgrestException catch (e) {
      log.e('Error al obtener miembros del equipo $teamId', error: e);
      throw DatabaseException('No se pudieron cargar los miembros.', code: e.code);
    }
  }

  @override
  Future<int> getCaptainTeamsCount(String userId) async {
    try {
      final rows = await supabase
          .from('team_members')
          .select('team_id')
          .eq('user_id', userId)
          .eq('role', 'captain');

      return rows.length;
    } on sb.PostgrestException catch (e) {
      log.e('Error al contar equipos del capitán', error: e);
      throw DatabaseException('No se pudo verificar el límite de equipos.', code: e.code);
    }
  }

  @override
  Future<Team> createTeam({
    required String captainId,
    required String name,
  }) async {
    // Validación en cliente antes de tocar la BD
    final count = await getCaptainTeamsCount(captainId);
    if (count >= 2) {
      throw const PermissionException(
        'Ya eres capitán de 2 equipos. No puedes crear más.',
      );
    }

    try {
      final teamRow = await supabase
          .from('teams')
          .insert({
            'name': name.trim(),
            'captain_id': captainId,
            'created_by': captainId,
          })
          .select()
          .single();

      final team = Team.fromMap(teamRow);

      await supabase.from('team_members').insert({
        'team_id': team.id,
        'user_id': captainId,
        'role': 'captain',
      });

      log.i('Equipo creado: ${team.id} — $name');
      return team;
    } on sb.PostgrestException catch (e) {
      log.e('Error al crear equipo', error: e);
      throw DatabaseException('No se pudo crear el equipo.', code: e.code);
    }
  }

  @override
  Future<String> uploadTeamShield({
    required String teamId,
    required Uint8List bytes,
  }) async {
    final filePath = '$teamId.jpg';
    try {
      await supabase.storage.from(_shieldBucket).uploadBinary(
            filePath,
            bytes,
            fileOptions: const sb.FileOptions(
              upsert: true,
              contentType: 'image/jpeg',
            ),
          );

      final publicUrl =
          supabase.storage.from(_shieldBucket).getPublicUrl(filePath);
      final urlWithBust =
          '$publicUrl?t=${DateTime.now().millisecondsSinceEpoch}';

      await supabase
          .from('teams')
          .update({'shield_url': urlWithBust})
          .eq('id', teamId);

      log.i('Escudo subido para equipo $teamId');
      return urlWithBust;
    } on sb.StorageException catch (e) {
      log.e('Error al subir escudo', error: e);
      throw DatabaseException('No se pudo subir el escudo.', code: e.statusCode);
    } on sb.PostgrestException catch (e) {
      log.e('Error al guardar URL del escudo', error: e);
      throw DatabaseException('Escudo subido pero no se pudo guardar.', code: e.code);
    }
  }

  @override
  Future<void> inviteMember({
    required String teamId,
    required String invitedUserId,
  }) async {
    try {
      await supabase.from('team_join_requests').insert({
        'team_id': teamId,
        'user_id': invitedUserId,
        'type': 'invitation',
        'status': 'pending',
      });
      log.i('Invitación enviada a $invitedUserId para equipo $teamId');
    } on sb.PostgrestException catch (e) {
      log.e('Error al invitar miembro', error: e);
      throw DatabaseException('No se pudo enviar la invitación.', code: e.code);
    }
  }

  @override
  Future<void> requestToJoin({
    required String teamId,
    required String userId,
  }) async {
    try {
      await supabase.from('team_join_requests').insert({
        'team_id': teamId,
        'user_id': userId,
        'type': 'request',
        'status': 'pending',
      });
      log.i('Solicitud de ingreso enviada por $userId al equipo $teamId');
    } on sb.PostgrestException catch (e) {
      log.e('Error al solicitar ingreso', error: e);
      throw DatabaseException('No se pudo enviar la solicitud.', code: e.code);
    }
  }

  @override
  Future<void> acceptJoinRequest(String requestId) async {
    try {
      // Obtener datos de la solicitud
      final row = await supabase
          .from('team_join_requests')
          .select()
          .eq('id', requestId)
          .single();

      final teamId = row['team_id'] as String;
      final userId = row['user_id'] as String;

      // Marcar como aceptada
      await supabase
          .from('team_join_requests')
          .update({'status': 'accepted'})
          .eq('id', requestId);

      // Agregar como miembro
      await supabase.from('team_members').insert({
        'team_id': teamId,
        'user_id': userId,
        'role': 'member',
      });

      log.i('Solicitud $requestId aceptada — usuario $userId en equipo $teamId');
    } on sb.PostgrestException catch (e) {
      log.e('Error al aceptar solicitud $requestId', error: e);
      throw DatabaseException('No se pudo aceptar la solicitud.', code: e.code);
    }
  }

  @override
  Future<void> rejectJoinRequest(String requestId) async {
    try {
      await supabase
          .from('team_join_requests')
          .update({'status': 'rejected'})
          .eq('id', requestId);

      log.i('Solicitud $requestId rechazada');
    } on sb.PostgrestException catch (e) {
      log.e('Error al rechazar solicitud $requestId', error: e);
      throw DatabaseException('No se pudo rechazar la solicitud.', code: e.code);
    }
  }

  @override
  Future<List<TeamJoinRequest>> getMyPendingInvitations(String userId) async {
    try {
      final rows = await supabase
          .from('team_join_requests')
          .select('*, teams(name)')
          .eq('user_id', userId)
          .eq('type', 'invitation')
          .eq('status', 'pending')
          .order('created_at', ascending: false);

      return rows.map(TeamJoinRequest.fromMap).toList();
    } on sb.PostgrestException catch (e) {
      log.e('Error al obtener invitaciones pendientes de $userId', error: e);
      throw DatabaseException('No se pudieron cargar las invitaciones.', code: e.code);
    }
  }

  @override
  Future<List<TeamJoinRequest>> getPendingRequestsForTeam(
      String teamId) async {
    try {
      final rows = await supabase
          .from('team_join_requests')
          .select('*, users(full_name, avatar_url)')
          .eq('team_id', teamId)
          .eq('type', 'request')
          .eq('status', 'pending')
          .order('created_at', ascending: false);

      return rows.map(TeamJoinRequest.fromMap).toList();
    } on sb.PostgrestException catch (e) {
      log.e('Error al obtener solicitudes del equipo $teamId', error: e);
      throw DatabaseException('No se pudieron cargar las solicitudes.', code: e.code);
    }
  }

  @override
  Future<void> removeMember({
    required String teamId,
    required String userId,
  }) async {
    try {
      await supabase
          .from('team_members')
          .delete()
          .eq('team_id', teamId)
          .eq('user_id', userId)
          .neq('role', 'captain'); // No permitir borrar al capitán

      log.i('Miembro $userId expulsado del equipo $teamId');
    } on sb.PostgrestException catch (e) {
      log.e('Error al expulsar miembro', error: e);
      throw DatabaseException('No se pudo expulsar al miembro.', code: e.code);
    }
  }

  @override
  Future<void> leaveTeam({
    required String teamId,
    required String userId,
  }) async {
    try {
      await supabase
          .from('team_members')
          .delete()
          .eq('team_id', teamId)
          .eq('user_id', userId)
          .neq('role', 'captain'); // El capitán no puede abandonar sin disolver

      log.i('Usuario $userId abandonó el equipo $teamId');
    } on sb.PostgrestException catch (e) {
      log.e('Error al abandonar equipo', error: e);
      throw DatabaseException('No se pudo abandonar el equipo.', code: e.code);
    }
  }

  @override
  Future<List<AppUser>> searchUsers(
    String query, {
    required String excludeUserId,
  }) async {
    if (query.trim().length < 2) return [];

    final term = query.trim();
    try {
      final rows = await supabase
          .from('users')
          .select('id, full_name, phone, avatar_url, is_suspended, roles')
          .or('full_name.ilike.%$term%,phone.ilike.%$term%')
          .neq('id', excludeUserId)
          .limit(20);

      return rows.map(AppUser.fromMap).toList();
    } on sb.PostgrestException catch (e) {
      log.e('Error al buscar usuarios', error: e);
      throw DatabaseException('No se pudo realizar la búsqueda.', code: e.code);
    }
  }
}
