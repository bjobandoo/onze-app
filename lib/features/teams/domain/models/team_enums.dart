// Enumerados de dominio del feature de equipos.

enum TeamMemberRole {
  captain,
  member;

  String get label => switch (this) {
        TeamMemberRole.captain => 'Capitán',
        TeamMemberRole.member => 'Miembro',
      };

  String get dbValue => name;

  static TeamMemberRole fromDb(String value) =>
      TeamMemberRole.values.firstWhere((e) => e.name == value);
}

enum JoinRequestType {
  invitation,
  request;

  String get dbValue => name;

  static JoinRequestType fromDb(String value) =>
      JoinRequestType.values.firstWhere((e) => e.name == value);
}

enum JoinRequestStatus {
  pending,
  accepted,
  rejected;

  String get dbValue => name;

  static JoinRequestStatus fromDb(String value) =>
      JoinRequestStatus.values.firstWhere((e) => e.name == value);
}
