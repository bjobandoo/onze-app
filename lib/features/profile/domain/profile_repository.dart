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
  /// Solo los campos no-null se actualizan. Para limpiar un campo opcional
  /// (ej. borrar la bio) se puede pasar `bio: ''`.
  Future<void> updateProfile({
    required String userId,
    String? fullName,
    String? bio,
    PlayerPosition? position,
    DominantFoot? dominantFoot,
    ExperienceLevel? experienceLevel,
  });
}
