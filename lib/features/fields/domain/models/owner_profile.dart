// Modelo de dominio del perfil de dueño de cancha.

/// Datos del dueño de canchas sintéticas registrado en Onze.
class OwnerProfile {
  const OwnerProfile({
    required this.userId,
    required this.businessName,
    required this.idDocument,
    required this.verified,
    this.verifiedAt,
  });

  final String userId;
  final String businessName;
  final String idDocument;
  final bool verified;
  final DateTime? verifiedAt;

  factory OwnerProfile.fromMap(Map<String, dynamic> map) => OwnerProfile(
        userId: map['user_id'] as String,
        businessName: map['business_name'] as String,
        idDocument: map['id_document'] as String,
        verified: map['verified'] as bool? ?? false,
        verifiedAt: map['verified_at'] != null
            ? DateTime.parse(map['verified_at'] as String)
            : null,
      );
}
