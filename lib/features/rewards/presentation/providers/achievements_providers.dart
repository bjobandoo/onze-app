// Providers de Riverpod para logros coleccionables.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../features/auth/presentation/providers/auth_providers.dart';
import '../../data/achievements_repository_impl.dart';
import '../../domain/achievements_repository.dart';
import '../../domain/models/achievement.dart';

final achievementsRepositoryProvider = Provider<AchievementsRepository>(
  (_) => AchievementsRepositoryImpl(),
);

/// Catálogo completo de logros de usuario.
final userAchievementsCatalogProvider =
    FutureProvider.autoDispose<List<Achievement>>((ref) {
  return ref
      .read(achievementsRepositoryProvider)
      .getCatalog(targetType: AchievementTargetType.user);
});

/// Catálogo completo de logros de equipo.
final teamAchievementsCatalogProvider =
    FutureProvider.autoDispose<List<Achievement>>((ref) {
  return ref
      .read(achievementsRepositoryProvider)
      .getCatalog(targetType: AchievementTargetType.team);
});

/// Logros obtenidos por el usuario autenticado.
final myEarnedAchievementsProvider =
    FutureProvider.autoDispose<List<EarnedAchievement>>((ref) async {
  final userId = ref.watch(currentUserProvider).valueOrNull?.id;
  if (userId == null) return [];
  return ref
      .read(achievementsRepositoryProvider)
      .getUserAchievements(userId);
});

/// Logros obtenidos por un equipo específico.
final teamEarnedAchievementsProvider =
    FutureProvider.autoDispose.family<List<EarnedAchievement>, String>(
  (ref, teamId) =>
      ref.read(achievementsRepositoryProvider).getTeamAchievements(teamId),
);
