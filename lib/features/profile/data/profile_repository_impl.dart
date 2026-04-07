import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../../../core/errors/onze_exception.dart';
import '../../../core/utils/logger.dart';
import '../../../shared/models/player_enums.dart';
import '../../../shared/services/supabase_service.dart';
import '../domain/models/player_profile.dart';
import '../domain/models/player_stats.dart';
import '../domain/profile_repository.dart';

/// Implementación de [ProfileRepository] usando Supabase.
class ProfileRepositoryImpl implements ProfileRepository {
  static const _avatarBucket = 'avatars';

  @override
  Future<PlayerProfile?> getPlayerProfile(String userId) async {
    try {
      final data = await supabase
          .from('player_profiles')
          .select()
          .eq('user_id', userId)
          .maybeSingle();

      if (data == null) return null;
      return PlayerProfile.fromMap(data);
    } on sb.PostgrestException catch (e) {
      log.e('Error al obtener perfil del jugador', error: e);
      throw DatabaseException('No se pudo cargar el perfil.', code: e.code);
    }
  }

  @override
  Future<PlayerStats> getPlayerStats(String userId) async {
    try {
      final data = await supabase
          .from('individual_stats')
          .select()
          .eq('user_id', userId)
          .maybeSingle();

      if (data == null) return const PlayerStats();
      return PlayerStats.fromMap(data);
    } on sb.PostgrestException catch (e) {
      log.e('Error al obtener estadísticas', error: e);
      return const PlayerStats();
    }
  }

  @override
  Future<void> updateProfile({
    required String userId,
    String? fullName,
    String? bio,
    PlayerPosition? position,
    DominantFoot? dominantFoot,
    ExperienceLevel? experienceLevel,
  }) async {
    try {
      if (fullName != null) {
        await supabase
            .from('users')
            .update({'full_name': fullName.trim()})
            .eq('id', userId);
      }

      final profileUpdates = <String, dynamic>{'user_id': userId};
      if (bio != null) profileUpdates['bio'] = bio.trim();
      if (position != null) profileUpdates['position'] = position.dbValue;
      if (dominantFoot != null) {
        profileUpdates['dominant_foot'] = dominantFoot.dbValue;
      }
      if (experienceLevel != null) {
        profileUpdates['experience_level'] = experienceLevel.dbValue;
      }

      if (profileUpdates.length > 1) {
        await supabase.from('player_profiles').upsert(profileUpdates);
      }

      log.i('Perfil actualizado para userId: $userId');
    } on sb.PostgrestException catch (e) {
      log.e('Error al actualizar perfil', error: e);
      throw DatabaseException(
        'No se pudo guardar los cambios. Intenta nuevamente.',
        code: e.code,
      );
    } catch (e, st) {
      log.e('Error inesperado al actualizar perfil', error: e, stackTrace: st);
      throw const NetworkException('Error de conexión. Intenta nuevamente.');
    }
  }

  @override
  Future<String> uploadAvatar(String userId, Uint8List bytes) async {
    // Siempre se guarda como JPEG. image_picker con imageQuality < 100
    // devuelve bytes JPEG en Android e iOS.
    final filePath = '$userId.jpg';

    try {
      log.d('Subiendo avatar para userId: $userId (${bytes.lengthInBytes} bytes)');

      await supabase.storage.from(_avatarBucket).uploadBinary(
            filePath,
            bytes,
            fileOptions: const sb.FileOptions(
              upsert: true,
              contentType: 'image/jpeg',
            ),
          );

      final publicUrl =
          supabase.storage.from(_avatarBucket).getPublicUrl(filePath);

      // Agregar cache-buster para que la imagen recargue en el cliente
      final urlWithBust =
          '$publicUrl?t=${DateTime.now().millisecondsSinceEpoch}';

      await supabase
          .from('users')
          .update({'avatar_url': urlWithBust})
          .eq('id', userId);

      log.i('Avatar subido correctamente: $publicUrl');
      return urlWithBust;
    } on sb.StorageException catch (e) {
      log.e('Error al subir avatar', error: e);
      throw DatabaseException(
        'No se pudo subir la foto. Intenta nuevamente.',
        code: e.statusCode,
      );
    } on sb.PostgrestException catch (e) {
      log.e('Error al actualizar avatar_url', error: e);
      throw DatabaseException(
        'Foto subida pero no se pudo guardar. Intenta nuevamente.',
        code: e.code,
      );
    } catch (e, st) {
      log.e('Error inesperado al subir avatar', error: e, stackTrace: st);
      throw const NetworkException('Error de conexión. Intenta nuevamente.');
    }
  }

  @override
  Future<void> removeAvatar(String userId) async {
    final filePath = '$userId.jpg';

    try {
      log.d('Eliminando avatar para userId: $userId');

      await supabase.storage.from(_avatarBucket).remove([filePath]);
      await supabase
          .from('users')
          .update({'avatar_url': null})
          .eq('id', userId);

      log.i('Avatar eliminado para $userId');
    } on sb.StorageException catch (e) {
      log.e('Error al eliminar avatar del storage', error: e);
      // Si el archivo no existe en Storage, igual limpiamos la BD
      if (e.statusCode != '404') {
        throw DatabaseException(
          'No se pudo eliminar la foto. Intenta nuevamente.',
          code: e.statusCode,
        );
      }
      await supabase
          .from('users')
          .update({'avatar_url': null})
          .eq('id', userId);
    } on sb.PostgrestException catch (e) {
      log.e('Error al limpiar avatar_url', error: e);
      throw DatabaseException(
        'No se pudo completar la operación. Intenta nuevamente.',
        code: e.code,
      );
    }
  }
}
