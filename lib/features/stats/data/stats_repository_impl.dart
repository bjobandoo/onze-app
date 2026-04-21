// Implementación del repositorio de estadísticas usando Supabase.

import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../../../core/errors/onze_exception.dart';
import '../../../core/utils/logger.dart';
import '../../../shared/services/supabase_service.dart';
import '../domain/models/ranking_entry.dart';
import '../domain/models/ranking_snapshot.dart';
import '../domain/models/team_medal.dart';
import '../domain/stats_repository.dart';

class StatsRepositoryImpl implements StatsRepository {
  @override
  Future<List<RankingEntry>> getGlobalRanking({int limit = 50}) async {
    try {
      final rows = await supabase
          .from('teams')
          .select(
            'id, name, shield_url, elo_rating, wins, losses, draws, matches_played',
          )
          .order('elo_rating', ascending: false)
          .limit(limit);

      return List<Map<String, dynamic>>.from(rows as List)
          .asMap()
          .entries
          .map((e) => RankingEntry.fromTeamMap(e.value, e.key + 1))
          .toList();
    } on sb.PostgrestException catch (e) {
      log.e('Error al obtener ranking global', error: e);
      throw DatabaseException(
          'No se pudo cargar el ranking.', code: e.code);
    }
  }

  static const _snapshotSelect =
      '*, team:teams!team_id(id, name, shield_url)';

  @override
  Future<List<RankingSnapshot>> getTeamPeriodHistory(String teamId) async {
    try {
      final rows = await supabase
          .from('ranking_snapshots')
          .select(_snapshotSelect)
          .eq('team_id', teamId)
          .order('period_start', ascending: false)
          .limit(20);

      return (rows as List)
          .map((r) => RankingSnapshot.fromMap(r as Map<String, dynamic>))
          .toList();
    } on sb.PostgrestException catch (e) {
      log.e('Error al obtener historial de periodos', error: e);
      throw DatabaseException(
          'No se pudo cargar el historial.', code: e.code);
    }
  }

  @override
  Future<List<TeamMedal>> getTeamMedals(String teamId) async {
    try {
      final rows = await supabase
          .from('team_achievements')
          .select(
            'unlocked_at, achievement:achievements!achievement_id(id, code, name)',
          )
          .eq('team_id', teamId)
          .order('unlocked_at');

      return (rows as List)
          .map((r) => r as Map<String, dynamic>)
          .where((r) {
            final code =
                (r['achievement'] as Map<String, dynamic>?)?['code'] as String? ??
                    '';
            return code.startsWith('elo_');
          })
          .map(TeamMedal.fromMap)
          .toList();
    } on sb.PostgrestException catch (e) {
      log.e('Error al obtener medallas del equipo', error: e);
      throw DatabaseException('No se pudieron cargar las medallas.', code: e.code);
    }
  }

  @override
  Future<List<RankingSnapshot>> getLatestPeriodRanking(
    RankingPeriodType periodType,
  ) async {
    try {
      final latest = await supabase
          .from('ranking_snapshots')
          .select('period_start')
          .eq('period_type', periodType.dbValue)
          .order('period_start', ascending: false)
          .limit(1)
          .maybeSingle();

      if (latest == null) return [];

      final periodStart = latest['period_start'] as String;

      final rows = await supabase
          .from('ranking_snapshots')
          .select(_snapshotSelect)
          .eq('period_type', periodType.dbValue)
          .eq('period_start', periodStart)
          .order('rank_position');

      return (rows as List)
          .map((r) => RankingSnapshot.fromMap(r as Map<String, dynamic>))
          .toList();
    } on sb.PostgrestException catch (e) {
      log.e('Error al obtener ranking del periodo', error: e);
      throw DatabaseException(
          'No se pudo cargar el ranking del periodo.', code: e.code);
    }
  }
}
