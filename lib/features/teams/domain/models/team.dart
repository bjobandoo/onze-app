// Modelo de dominio de un equipo.

/// Representa un equipo de fútbol dentro de la aplicación.
class Team {
  const Team({
    required this.id,
    required this.name,
    required this.captainId,
    required this.createdAt,
    this.shieldUrl,
    this.isActive = true,
  });

  final String id;
  final String name;
  final String captainId;
  final DateTime createdAt;
  final String? shieldUrl;
  final bool isActive;

  factory Team.fromMap(Map<String, dynamic> map) => Team(
        id: map['id'] as String,
        name: map['name'] as String,
        captainId: map['captain_id'] as String,
        createdAt: DateTime.parse(map['created_at'] as String),
        shieldUrl: map['shield_url'] as String?,
        isActive: map['is_active'] as bool? ?? true,
      );

  Team copyWith({
    String? name,
    String? shieldUrl,
    bool? isActive,
  }) =>
      Team(
        id: id,
        name: name ?? this.name,
        captainId: captainId,
        createdAt: createdAt,
        shieldUrl: shieldUrl ?? this.shieldUrl,
        isActive: isActive ?? this.isActive,
      );
}
