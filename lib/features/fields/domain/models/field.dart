// Modelo de dominio de una cancha sintética.

import 'field_enums.dart';

/// Representa una cancha sintética registrada en Onze.
class Field {
  const Field({
    required this.id,
    required this.ownerId,
    required this.name,
    required this.address,
    required this.latitude,
    required this.longitude,
    required this.fieldType,
    required this.createdAt,
    this.description,
    this.photos = const [],
    this.isActive = true,
    this.verified = false,
    this.averageRating = 0.0,
  });

  final String id;
  final String ownerId;
  final String name;
  final String address;
  final double latitude;
  final double longitude;
  final FieldType fieldType;
  final DateTime createdAt;
  final String? description;
  final List<String> photos;
  final bool isActive;
  final bool verified;
  final double averageRating;

  String? get firstPhotoUrl => photos.isNotEmpty ? photos.first : null;

  factory Field.fromMap(Map<String, dynamic> map) => Field(
        id: map['id'] as String,
        ownerId: map['owner_id'] as String,
        name: map['name'] as String,
        address: map['address'] as String,
        latitude: (map['latitude'] as num).toDouble(),
        longitude: (map['longitude'] as num).toDouble(),
        fieldType: FieldType.fromDb(map['field_type'] as String),
        createdAt: DateTime.parse(map['created_at'] as String),
        description: map['description'] as String?,
        photos: (map['photos'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            const [],
        isActive: map['is_active'] as bool? ?? true,
        verified: map['verified'] as bool? ?? false,
        averageRating: (map['average_rating'] as num?)?.toDouble() ?? 0.0,
      );

  Field copyWith({
    String? name,
    String? description,
    String? address,
    double? latitude,
    double? longitude,
    FieldType? fieldType,
    List<String>? photos,
    bool? isActive,
  }) =>
      Field(
        id: id,
        ownerId: ownerId,
        name: name ?? this.name,
        address: address ?? this.address,
        latitude: latitude ?? this.latitude,
        longitude: longitude ?? this.longitude,
        fieldType: fieldType ?? this.fieldType,
        createdAt: createdAt,
        description: description ?? this.description,
        photos: photos ?? this.photos,
        isActive: isActive ?? this.isActive,
        verified: verified,
        averageRating: averageRating,
      );
}
