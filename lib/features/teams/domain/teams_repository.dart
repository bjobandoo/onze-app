// Contrato del repositorio de equipos.

import 'dart:typed_data';

import '../../../shared/models/app_user.dart';
import 'models/team.dart';
import 'models/team_join_request.dart';
import 'models/team_member.dart';

/// Contrato de acceso a datos para el feature de equipos.
abstract class TeamsRepository {
  /// Devuelve los equipos de los que [userId] es miembro (activo).
  Future<List<Team>> getMyTeams(String userId);

  /// Devuelve el equipo con [teamId], o null si no existe.
  Future<Team?> getTeamById(String teamId);

  /// Devuelve los miembros activos de un equipo.
  Future<List<TeamMember>> getTeamMembers(String teamId);

  /// Cuenta cuántos equipos tiene [userId] como capitán.
  /// Usado para validar el límite de 2 equipos por capitán.
  Future<int> getCaptainTeamsCount(String userId);

  /// Crea un equipo nuevo y agrega al [captainId] como capitán.
  /// Lanza [PermissionException] si el capitán ya tiene 2 equipos.
  Future<Team> createTeam({
    required String captainId,
    required String name,
  });

  /// Sube el escudo del equipo a Storage y actualiza [shield_url].
  Future<String> uploadTeamShield({
    required String teamId,
    required Uint8List bytes,
  });

  /// Invita a [invitedUserId] a unirse al equipo (capitán → jugador).
  Future<void> inviteMember({
    required String teamId,
    required String invitedUserId,
  });

  /// El usuario [userId] solicita unirse al equipo (jugador → equipo).
  Future<void> requestToJoin({
    required String teamId,
    required String userId,
  });

  /// Acepta una solicitud/invitación pendiente e incorpora al miembro.
  Future<void> acceptJoinRequest(String requestId);

  /// Rechaza una solicitud/invitación pendiente.
  Future<void> rejectJoinRequest(String requestId);

  /// Devuelve las invitaciones pendientes recibidas por [userId].
  Future<List<TeamJoinRequest>> getMyPendingInvitations(String userId);

  /// Devuelve las solicitudes de ingreso pendientes para un equipo.
  Future<List<TeamJoinRequest>> getPendingRequestsForTeam(String teamId);

  /// El capitán expulsa a [userId] del equipo.
  Future<void> removeMember({
    required String teamId,
    required String userId,
  });

  /// El propio [userId] abandona el equipo.
  Future<void> leaveTeam({
    required String teamId,
    required String userId,
  });

  /// Busca usuarios por nombre o teléfono.
  ///
  /// [query] debe tener al menos 2 caracteres.
  /// [excludeUserId] excluye al usuario actual de los resultados.
  Future<List<AppUser>> searchUsers(
    String query, {
    required String excludeUserId,
  });
}
