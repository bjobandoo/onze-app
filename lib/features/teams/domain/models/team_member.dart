// Modelo de dominio de un miembro de equipo.

import 'team_enums.dart';

/// Representa la relación entre un usuario y un equipo.
class TeamMember {
  const TeamMember({
    required this.teamId,
    required this.userId,
    required this.role,
    required this.joinedAt,
    required this.userFullName,
    this.userAvatarUrl,
  });

  final String teamId;
  final String userId;
  final TeamMemberRole role;
  final DateTime joinedAt;
  final String userFullName;
  final String? userAvatarUrl;

  bool get isCaptain => role == TeamMemberRole.captain;

  factory TeamMember.fromMap(Map<String, dynamic> map) {
    final userData = map['users'] as Map<String, dynamic>?;
    return TeamMember(
      teamId: map['team_id'] as String,
      userId: map['user_id'] as String,
      role: TeamMemberRole.fromDb(map['role'] as String),
      joinedAt: DateTime.parse(map['joined_at'] as String),
      userFullName: userData?['full_name'] as String? ?? '',
      userAvatarUrl: userData?['avatar_url'] as String?,
    );
  }
}
