// Implementación del repositorio de canchas usando Supabase.

import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../../../core/errors/onze_exception.dart';
import '../../../core/utils/logger.dart';
import '../../../shared/services/supabase_service.dart';
import 'package:flutter/material.dart';

import '../domain/fields_repository.dart';
import '../domain/models/field.dart';
import '../domain/models/field_enums.dart';
import '../domain/models/field_schedule.dart';
import '../domain/models/owner_profile.dart';

/// Implementación de [FieldsRepository] usando Supabase.
class FieldsRepositoryImpl implements FieldsRepository {
  static const _photoBucket = 'field-photos';

  @override
  Future<OwnerProfile?> getOwnerProfile(String userId) async {
    try {
      final data = await supabase
          .from('owner_profiles')
          .select()
          .eq('user_id', userId)
          .maybeSingle();

      if (data == null) return null;
      return OwnerProfile.fromMap(data);
    } on sb.PostgrestException catch (e) {
      log.e('Error al obtener perfil de dueño', error: e);
      throw DatabaseException(
        'No se pudo cargar el perfil de dueño.',
        code: e.code,
      );
    }
  }

  @override
  Future<OwnerProfile> createOwnerProfile({
    required String userId,
    required String businessName,
    required String idDocument,
  }) async {
    try {
      // Insertar perfil de dueño
      final row = await supabase
          .from('owner_profiles')
          .insert({
            'user_id': userId,
            'business_name': businessName.trim(),
            'id_document': idDocument.trim(),
          })
          .select()
          .single();

      // Agregar rol 'owner' al arreglo de roles del usuario
      await supabase.rpc('append_role', params: {
        'uid': userId,
        'new_role': 'owner',
      });

      log.i('Perfil de dueño creado para userId: $userId');
      return OwnerProfile.fromMap(row);
    } on sb.PostgrestException catch (e) {
      log.e('Error al crear perfil de dueño', error: e);
      throw DatabaseException(
        'No se pudo registrar como dueño. Intenta nuevamente.',
        code: e.code,
      );
    }
  }

  @override
  Future<List<Field>> getMyFields(String ownerId) async {
    try {
      final rows = await supabase
          .from('fields')
          .select()
          .eq('owner_id', ownerId)
          .order('created_at', ascending: false);

      return rows.map(Field.fromMap).toList();
    } on sb.PostgrestException catch (e) {
      log.e('Error al obtener canchas del dueño $ownerId', error: e);
      throw DatabaseException(
        'No se pudieron cargar las canchas.',
        code: e.code,
      );
    }
  }

  @override
  Future<Field> registerField({
    required String ownerId,
    required String name,
    String? description,
    required String address,
    required double latitude,
    required double longitude,
    required FieldType fieldType,
  }) async {
    try {
      final row = await supabase
          .from('fields')
          .insert({
            'owner_id': ownerId,
            'name': name.trim(),
            'description': description?.trim(),
            'address': address.trim(),
            'latitude': latitude,
            'longitude': longitude,
            'field_type': fieldType.dbValue,
          })
          .select()
          .single();

      final field = Field.fromMap(row);
      log.i('Cancha registrada: ${field.id} — ${field.name}');
      return field;
    } on sb.PostgrestException catch (e) {
      log.e('Error al registrar cancha', error: e);
      throw DatabaseException(
        'No se pudo registrar la cancha.',
        code: e.code,
      );
    }
  }

  @override
  Future<Field> updateField({
    required String fieldId,
    required String name,
    String? description,
    required String address,
    required double latitude,
    required double longitude,
    required FieldType fieldType,
  }) async {
    try {
      final row = await supabase
          .from('fields')
          .update({
            'name': name.trim(),
            'description': description?.trim(),
            'address': address.trim(),
            'latitude': latitude,
            'longitude': longitude,
            'field_type': fieldType.dbValue,
          })
          .eq('id', fieldId)
          .select()
          .single();

      final field = Field.fromMap(row);
      log.i('Cancha actualizada: $fieldId — ${field.name}');
      return field;
    } on sb.PostgrestException catch (e) {
      log.e('Error al actualizar cancha $fieldId', error: e);
      throw DatabaseException(
        'No se pudo actualizar la cancha.',
        code: e.code,
      );
    }
  }

  @override
  Future<String> uploadFieldPhoto({
    required String fieldId,
    required int photoIndex,
    required Uint8List bytes,
  }) async {
    final filePath = '$fieldId/$photoIndex.jpg';
    try {
      await supabase.storage.from(_photoBucket).uploadBinary(
            filePath,
            bytes,
            fileOptions: const sb.FileOptions(
              upsert: true,
              contentType: 'image/jpeg',
            ),
          );

      final publicUrl =
          supabase.storage.from(_photoBucket).getPublicUrl(filePath);
      final urlWithBust =
          '$publicUrl?t=${DateTime.now().millisecondsSinceEpoch}';

      log.d('Foto $photoIndex subida para cancha $fieldId');
      return urlWithBust;
    } on sb.StorageException catch (e) {
      log.e('Error al subir foto de cancha', error: e);
      throw DatabaseException(
        'No se pudo subir la foto.',
        code: e.statusCode,
      );
    }
  }

  @override
  Future<void> updateFieldPhotos({
    required String fieldId,
    required List<String> photoUrls,
  }) async {
    try {
      await supabase
          .from('fields')
          .update({'photos': photoUrls})
          .eq('id', fieldId);

      log.i('Fotos actualizadas para cancha $fieldId: ${photoUrls.length}');
    } on sb.PostgrestException catch (e) {
      log.e('Error al actualizar fotos de cancha', error: e);
      throw DatabaseException(
        'No se pudo guardar las fotos.',
        code: e.code,
      );
    }
  }

  @override
  Future<List<Field>> getVerifiedFields() async {
    try {
      final rows = await supabase
          .from('fields')
          .select()
          .eq('verified', true)
          .eq('is_active', true)
          .order('name');

      return rows.map(Field.fromMap).toList();
    } on sb.PostgrestException catch (e) {
      log.e('Error al obtener canchas verificadas', error: e);
      throw DatabaseException(
        'No se pudieron cargar las canchas.',
        code: e.code,
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Horarios
  // ---------------------------------------------------------------------------

  @override
  Future<List<FieldSchedule>> getFieldSchedules(String fieldId) async {
    try {
      final rows = await supabase
          .from('field_schedules')
          .select()
          .eq('field_id', fieldId)
          .order('day_of_week')
          .order('start_time');

      return rows.map(FieldSchedule.fromMap).toList();
    } on sb.PostgrestException catch (e) {
      log.e('Error al obtener horarios de cancha $fieldId', error: e);
      throw DatabaseException(
        'No se pudieron cargar los horarios.',
        code: e.code,
      );
    }
  }

  @override
  Future<FieldSchedule> upsertSchedule({
    String? id,
    required String fieldId,
    required int dayOfWeek,
    required TimeOfDay startTime,
    required TimeOfDay endTime,
    required double price,
    bool isActive = true,
  }) async {
    try {
      final payload = <String, dynamic>{
        'field_id': fieldId,
        'day_of_week': dayOfWeek,
        'start_time': _formatTime(startTime),
        'end_time': _formatTime(endTime),
        'price': price,
        'is_active': isActive,
      };
      if (id != null) payload['id'] = id;

      final row = await supabase
          .from('field_schedules')
          .upsert(payload)
          .select()
          .single();

      log.i('Horario guardado para cancha $fieldId (day $dayOfWeek)');
      return FieldSchedule.fromMap(row);
    } on sb.PostgrestException catch (e) {
      log.e('Error al guardar horario', error: e);
      throw DatabaseException(
        'No se pudo guardar el horario.',
        code: e.code,
      );
    }
  }

  @override
  Future<void> deleteSchedule(String id) async {
    try {
      await supabase.from('field_schedules').delete().eq('id', id);
      log.i('Horario $id eliminado');
    } on sb.PostgrestException catch (e) {
      log.e('Error al eliminar horario $id', error: e);
      throw DatabaseException(
        'No se pudo eliminar el horario.',
        code: e.code,
      );
    }
  }

  @override
  Future<void> setScheduleActive(String id, {required bool isActive}) async {
    try {
      await supabase
          .from('field_schedules')
          .update({'is_active': isActive})
          .eq('id', id);
      log.d('Horario $id isActive=$isActive');
    } on sb.PostgrestException catch (e) {
      log.e('Error al actualizar estado del horario $id', error: e);
      throw DatabaseException(
        'No se pudo actualizar el horario.',
        code: e.code,
      );
    }
  }

  static String _formatTime(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}:00';
}
