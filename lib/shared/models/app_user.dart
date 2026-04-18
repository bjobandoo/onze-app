/// Modelo de usuario de dominio de Onze.
/// Representa la fila de public.users enriquecida con su perfil.
class AppUser {
  const AppUser({
    required this.id,
    required this.phone,
    required this.fullName,
    required this.roles,
    required this.isSuspended,
    this.username,
    this.avatarUrl,
    this.suspensionUntil,
    this.yellowCardsCount = 0,
  });

  factory AppUser.fromMap(Map<String, dynamic> map) {
    return AppUser(
      id: map['id'] as String,
      phone: map['phone'] as String? ?? '',
      fullName: map['full_name'] as String? ?? '',
      username: map['username'] as String?,
      avatarUrl: map['avatar_url'] as String?,
      isSuspended: map['is_suspended'] as bool? ?? false,
      suspensionUntil: map['suspension_until'] != null
          ? DateTime.parse(map['suspension_until'] as String)
          : null,
      yellowCardsCount: map['yellow_cards_count'] as int? ?? 0,
      roles: (map['roles'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const ['player'],
    );
  }

  final String id;
  final String phone;
  final String fullName;

  /// Alias único del jugador (ej: "carlos_10"). Null si aún no lo eligió.
  final String? username;
  final String? avatarUrl;
  final bool isSuspended;
  final DateTime? suspensionUntil;
  final int yellowCardsCount;
  final List<String> roles;

  /// El usuario completó la creación de perfil si tiene nombre.
  bool get hasProfile => fullName.isNotEmpty;

  bool get isOwner => roles.contains('owner');
  bool get isAdmin => roles.contains('admin');

  AppUser copyWith({
    String? fullName,
    String? username,
    String? avatarUrl,
    bool? isSuspended,
  }) {
    return AppUser(
      id: id,
      phone: phone,
      fullName: fullName ?? this.fullName,
      username: username ?? this.username,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      roles: roles,
      isSuspended: isSuspended ?? this.isSuspended,
      suspensionUntil: suspensionUntil,
      yellowCardsCount: yellowCardsCount,
    );
  }
}
