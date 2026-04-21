// Implementación del repositorio de logros usando Supabase.

import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../../../core/errors/onze_exception.dart';
import '../../../core/utils/logger.dart';
import '../../../shared/services/supabase_service.dart';
import '../domain/achievements_repository.dart';
import '../domain/models/achievement.dart';

class AchievementsRepositoryImpl implements AchievementsRepository {
  static const _achievementSelect =
      'achievement:achievements!achievement_id(id, code, name, description, target_type)';

  @override
  Future<List<Achievement>> getCatalog({
    AchievementTargetType? targetType,
  }) async {
    try {
      var query = supabase.from('achievements').select(
            'id, code, name, description, target_type',
          );

      if (targetType != null) {
        query = query.eq('target_type', targetType.name);
      }

      final rows = await query.order('target_type').order('name');

      return (rows as List)
          .map((r) => Achievement.fromMap(r as Map<String, dynamic>))
          .toList();
    } on sb.PostgrestException catch (e) {
      log.e('Error al obtener catálogo de logros', error: e);
      throw DatabaseException('No se pudo cargar el catálogo.', code: e.code);
    }
  }

  @override
  Future<List<EarnedAchievement>> getUserAchievements(String userId) async {
    try {
      final rows = await supabase
          .from('user_achievements')
          .select('unlocked_at, $_achievementSelect')
          .eq('user_id', userId)
          .order('unlocked_at');

      return (rows as List)
          .map((r) => EarnedAchievement.fromMap(r as Map<String, dynamic>))
          .toList();
    } on sb.PostgrestException catch (e) {
      log.e('Error al obtener logros del usuario', error: e);
      throw DatabaseException('No se pudieron cargar los logros.', code: e.code);
    }
  }

  @override
  Future<List<EarnedAchievement>> getTeamAchievements(String teamId) async {
    try {
      final rows = await supabase
          .from('team_achievements')
          .select('unlocked_at, $_achievementSelect')
          .eq('team_id', teamId)
          .order('unlocked_at');

      return (rows as List)
          .map((r) => EarnedAchievement.fromMap(r as Map<String, dynamic>))
          .toList();
    } on sb.PostgrestException catch (e) {
      log.e('Error al obtener logros del equipo', error: e);
      throw DatabaseException('No se pudieron cargar los logros.', code: e.code);
    }
  }
}
