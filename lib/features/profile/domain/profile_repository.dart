import 'dart:typed_data';

import '../../../shared/models/player_enums.dart';
import 'models/player_profile.dart';
import 'models/player_stats.dart';

/// Contrato del repositorio de perfil de jugador.
abstract class ProfileRepository {
  /// Obtiene el perfil deportivo del jugador con [userId].
  /// Retorna null si aún no tiene perfil creado.
  Future<PlayerProfile?> getPlayerProfile(String userId);

  /// Obtiene las estadísticas globales del jugador con [userId].
  Future<PlayerStats> getPlayerStats(String userId);

  /// Actualiza el perfil del jugador autenticado.
  ///
  /// Solo los campos no-null se actualizan. Para limpiar la bio
  /// se puede pasar `bio: ''`.
  Future<void> updateProfile({
    required String userId,
    String? fullName,
    String? username,
    String? bio,
    PlayerPosition? position,
    DominantFoot? dominantFoot,
    ExperienceLevel? experienceLevel,
  });

  /// Sube [bytes] JPEG al bucket `avatars` de Supabase Storage y actualiza
  /// `avatar_url` en `public.users`. Retorna la URL pública del avatar.
  ///
  /// El bucket `avatars` debe existir en Supabase Storage con acceso público.
  /// Crea el bucket en: Storage → New bucket → nombre: `avatars` → Public.
  Future<String> uploadAvatar(String userId, Uint8List bytes);

  /// Elimina el avatar del bucket y borra `avatar_url` en `public.users`.
  Future<void> removeAvatar(String userId);
}
