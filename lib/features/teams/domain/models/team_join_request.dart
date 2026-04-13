// Modelo de dominio de una solicitud/invitación para unirse a un equipo.

import 'team_enums.dart';

/// Representa una invitación (capitán→jugador) o solicitud (jugador→equipo).
class TeamJoinRequest {
  const TeamJoinRequest({
    required this.id,
    required this.teamId,
    required this.userId,
    required this.type,
    required this.status,
    required this.createdAt,
    this.teamName,
    this.userFullName,
    this.userAvatarUrl,
  });

  final String id;
  final String teamId;
  final String userId;
  final JoinRequestType type;
  final JoinRequestStatus status;
  final DateTime createdAt;

  // Datos desnormalizados para mostrar en listas sin joins adicionales
  final String? teamName;
  final String? userFullName;
  final String? userAvatarUrl;

  factory TeamJoinRequest.fromMap(Map<String, dynamic> map) {
    final teamData = map['teams'] as Map<String, dynamic>?;
    final userData = map['users'] as Map<String, dynamic>?;
    return TeamJoinRequest(
      id: map['id'] as String,
      teamId: map['team_id'] as String,
      userId: map['user_id'] as String,
      type: JoinRequestType.fromDb(map['type'] as String),
      status: JoinRequestStatus.fromDb(map['status'] as String),
      createdAt: DateTime.parse(map['created_at'] as String),
      teamName: teamData?['name'] as String?,
      userFullName: userData?['full_name'] as String?,
      userAvatarUrl: userData?['avatar_url'] as String?,
    );
  }
}
