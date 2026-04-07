import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../features/auth/presentation/providers/auth_providers.dart';
import '../../data/profile_repository_impl.dart';
import '../../domain/models/player_profile.dart';
import '../../domain/models/player_stats.dart';
import '../../domain/profile_repository.dart';

/// Proveedor del repositorio de perfil.
final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  return ProfileRepositoryImpl();
});

/// Perfil deportivo del usuario autenticado.
///
/// Se invalida automáticamente cuando cambia la sesión o se llama
/// a [ref.invalidate(myProfileProvider)] tras guardar cambios.
final myProfileProvider = FutureProvider<PlayerProfile?>((ref) async {
  final user = await ref.watch(currentUserProvider.future);
  if (user == null) return null;
  return ref.read(profileRepositoryProvider).getPlayerProfile(user.id);
});

/// Estadísticas globales del usuario autenticado.
final myStatsProvider = FutureProvider<PlayerStats>((ref) async {
  final user = await ref.watch(currentUserProvider.future);
  if (user == null) return const PlayerStats();
  return ref.read(profileRepositoryProvider).getPlayerStats(user.id);
});
