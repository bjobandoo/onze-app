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
      throw DatabaseException(
        'No se pudo cargar el perfil.',
        code: e.code,
      );
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
      // Las estadísticas no son críticas; retornar vacías antes de fallar.
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
      // 1. Actualizar public.users si cambió el nombre
      if (fullName != null) {
        await supabase
            .from('users')
            .update({'full_name': fullName.trim()})
            .eq('id', userId);
      }

      // 2. Construir el mapa de campos a actualizar en player_profiles
      final profileUpdates = <String, dynamic>{
        'user_id': userId,
      };
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
}
