import '../../../../shared/models/player_enums.dart';

/// Perfil deportivo de un jugador (tabla public.player_profiles).
class PlayerProfile {
  const PlayerProfile({
    required this.userId,
    this.position,
    this.dominantFoot,
    this.experienceLevel,
    this.bio,
  });

  factory PlayerProfile.fromMap(Map<String, dynamic> map) {
    return PlayerProfile(
      userId: map['user_id'] as String,
      position: map['position'] != null
          ? PlayerPosition.fromDb(map['position'] as String)
          : null,
      dominantFoot: map['dominant_foot'] != null
          ? DominantFoot.fromDb(map['dominant_foot'] as String)
          : null,
      experienceLevel: map['experience_level'] != null
          ? ExperienceLevel.fromDb(map['experience_level'] as String)
          : null,
      bio: map['bio'] as String?,
    );
  }

  final String userId;
  final PlayerPosition? position;
  final DominantFoot? dominantFoot;
  final ExperienceLevel? experienceLevel;
  final String? bio;

  PlayerProfile copyWith({
    PlayerPosition? position,
    DominantFoot? dominantFoot,
    ExperienceLevel? experienceLevel,
    String? bio,
  }) {
    return PlayerProfile(
      userId: userId,
      position: position ?? this.position,
      dominantFoot: dominantFoot ?? this.dominantFoot,
      experienceLevel: experienceLevel ?? this.experienceLevel,
      bio: bio ?? this.bio,
    );
  }
}
