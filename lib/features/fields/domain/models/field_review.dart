// Modelo de dominio para una reseña de cancha.

/// Reseña y calificación (1–5 estrellas) que un jugador deja sobre una cancha.
class FieldReview {
  const FieldReview({
    required this.id,
    required this.fieldId,
    required this.userId,
    required this.rating,
    required this.createdAt,
    this.comment,
    this.updatedAt,
    this.userName,
    this.userAvatarUrl,
  });

  final String id;
  final String fieldId;
  final String userId;

  /// Calificación de 1 a 5 estrellas.
  final int rating;
  final String? comment;
  final DateTime createdAt;
  final DateTime? updatedAt;

  // Desnormalizados desde public.users (poblados al leer con join)
  final String? userName;
  final String? userAvatarUrl;

  factory FieldReview.fromMap(Map<String, dynamic> map) {
    final user = map['user'] as Map<String, dynamic>?;
    return FieldReview(
      id:             map['id'] as String,
      fieldId:        map['field_id'] as String,
      userId:         map['user_id'] as String,
      rating:         map['rating'] as int,
      comment:        map['comment'] as String?,
      createdAt:      DateTime.parse(map['created_at'] as String),
      updatedAt:      map['updated_at'] != null
          ? DateTime.parse(map['updated_at'] as String)
          : null,
      userName:       user?['full_name'] as String?,
      userAvatarUrl:  user?['avatar_url'] as String?,
    );
  }
}
