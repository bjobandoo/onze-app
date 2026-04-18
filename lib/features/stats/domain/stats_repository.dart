// Contrato del repositorio de estadísticas y ranking.

import 'models/ranking_entry.dart';
import 'models/ranking_snapshot.dart';

abstract class StatsRepository {
  /// Ranking global de equipos ordenados por ELO descendente.
  Future<List<RankingEntry>> getGlobalRanking({int limit = 50});

  /// Historial de snapshots de ranking para un equipo específico.
  Future<List<RankingSnapshot>> getTeamPeriodHistory(String teamId);

  /// Snapshots del periodo actual (el más reciente de cada tipo).
  Future<List<RankingSnapshot>> getLatestPeriodRanking(
    RankingPeriodType periodType,
  );
}
