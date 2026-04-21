// Contrato del repositorio de logros coleccionables.

import 'models/achievement.dart';

abstract class AchievementsRepository {
  /// Catálogo completo de logros, filtrado opcionalmente por tipo de objetivo.
  Future<List<Achievement>> getCatalog({AchievementTargetType? targetType});

  /// Logros obtenidos por un usuario concreto.
  Future<List<EarnedAchievement>> getUserAchievements(String userId);

  /// Logros obtenidos por un equipo concreto.
  Future<List<EarnedAchievement>> getTeamAchievements(String teamId);
}
