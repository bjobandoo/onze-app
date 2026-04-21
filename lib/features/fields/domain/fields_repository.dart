// Contrato del repositorio de canchas y perfil de dueño.

import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'models/field.dart';
import 'models/field_enums.dart';
import 'models/field_review.dart';
import 'models/field_schedule.dart';
import 'models/owner_profile.dart';
import 'models/owner_stats.dart';

/// Contrato de acceso a datos para canchas y perfil de dueño.
abstract class FieldsRepository {
  /// Devuelve el perfil de dueño de [userId], o null si no existe.
  Future<OwnerProfile?> getOwnerProfile(String userId);

  /// Registra al usuario como dueño de cancha.
  ///
  /// Inserta en [owner_profiles] y agrega el rol 'owner' al usuario.
  Future<OwnerProfile> createOwnerProfile({
    required String userId,
    required String businessName,
    required String idDocument,
  });

  /// Devuelve las canchas registradas por el [ownerId].
  Future<List<Field>> getMyFields(String ownerId);

  /// Registra una nueva cancha. Queda con [verified = false] hasta
  /// que el admin la apruebe manualmente desde Supabase.
  Future<Field> registerField({
    required String ownerId,
    required String name,
    String? description,
    required String address,
    required double latitude,
    required double longitude,
    required FieldType fieldType,
  });

  /// Sube una foto de cancha a Storage y devuelve su URL pública.
  Future<String> uploadFieldPhoto({
    required String fieldId,
    required int photoIndex,
    required Uint8List bytes,
  });

  /// Actualiza los datos básicos de una cancha existente.
  Future<Field> updateField({
    required String fieldId,
    required String name,
    String? description,
    required String address,
    required double latitude,
    required double longitude,
    required FieldType fieldType,
  });

  /// Actualiza el arreglo de fotos de una cancha.
  Future<void> updateFieldPhotos({
    required String fieldId,
    required List<String> photoUrls,
  });

  // ---------------------------------------------------------------------------
  // Horarios
  // ---------------------------------------------------------------------------

  /// Retorna las canchas verificadas y activas (vista pública para jugadores).
  Future<List<Field>> getVerifiedFields();

  /// Retorna todos los bloques horarios de una cancha.
  Future<List<FieldSchedule>> getFieldSchedules(String fieldId);

  /// Crea o actualiza un bloque horario.
  /// Si [id] es null crea uno nuevo; si se provee actualiza el existente.
  Future<FieldSchedule> upsertSchedule({
    String? id,
    required String fieldId,
    required int dayOfWeek,
    required TimeOfDay startTime,
    required TimeOfDay endTime,
    required double price,
    bool isActive = true,
  });

  /// Elimina un bloque horario por su [id].
  Future<void> deleteSchedule(String id);

  /// Activa o desactiva un bloque horario.
  Future<void> setScheduleActive(String id, {required bool isActive});

  // ---------------------------------------------------------------------------
  // Reseñas
  // ---------------------------------------------------------------------------

  /// Devuelve todas las reseñas de una cancha, ordenadas por fecha descendente.
  Future<List<FieldReview>> getFieldReviews(String fieldId);

  /// Devuelve la reseña del [userId] para la cancha [fieldId], o null.
  Future<FieldReview?> getMyReview({
    required String fieldId,
    required String userId,
  });

  /// Crea o actualiza la reseña del usuario autenticado para la cancha.
  Future<void> upsertReview({
    required String fieldId,
    required String userId,
    required int rating,
    String? comment,
  });

  /// Elimina la reseña del usuario autenticado para la cancha.
  Future<void> deleteReview({
    required String fieldId,
    required String userId,
  });

  // ---------------------------------------------------------------------------
  // Panel del dueño
  // ---------------------------------------------------------------------------

  /// Estadísticas globales + desglose por cancha para el panel del dueño.
  Future<OwnerStats> getOwnerStats(String ownerId);
}
