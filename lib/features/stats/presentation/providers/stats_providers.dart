// Providers de Riverpod para el feature de estadísticas y ranking.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/stats_repository_impl.dart';
import '../../domain/models/ranking_entry.dart';
import '../../domain/models/ranking_snapshot.dart';
import '../../domain/models/team_medal.dart';
import '../../domain/stats_repository.dart';

final statsRepositoryProvider = Provider<StatsRepository>(
  (ref) => StatsRepositoryImpl(),
);

/// Ranking global de equipos ordenado por ELO.
final globalRankingProvider =
    FutureProvider<List<RankingEntry>>((ref) async {
  return ref.read(statsRepositoryProvider).getGlobalRanking();
});

/// Historial de snapshots de ranking de un equipo por periodo.
final teamPeriodHistoryProvider =
    FutureProvider.autoDispose.family<List<RankingSnapshot>, String>(
  (ref, teamId) =>
      ref.read(statsRepositoryProvider).getTeamPeriodHistory(teamId),
);

/// Medallas ELO obtenidas por un equipo.
final teamMedalsProvider =
    FutureProvider.autoDispose.family<List<TeamMedal>, String>(
  (ref, teamId) => ref.read(statsRepositoryProvider).getTeamMedals(teamId),
);

/// Ranking del último periodo quincenal.
final biweeklyRankingProvider =
    FutureProvider<List<RankingSnapshot>>((ref) async {
  return ref
      .read(statsRepositoryProvider)
      .getLatestPeriodRanking(RankingPeriodType.biweekly);
});

/// Ranking del último periodo mensual.
final monthlyRankingProvider =
    FutureProvider<List<RankingSnapshot>>((ref) async {
  return ref
      .read(statsRepositoryProvider)
      .getLatestPeriodRanking(RankingPeriodType.monthly);
});
