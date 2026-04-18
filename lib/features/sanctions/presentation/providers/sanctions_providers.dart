// Providers de Riverpod para el feature de sanciones.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/onze_exception.dart';
import '../../../../core/utils/logger.dart';
import '../../data/sanctions_repository_impl.dart';
import '../../domain/models/yellow_card.dart';
import '../../domain/sanctions_repository.dart';

final sanctionsRepositoryProvider = Provider<SanctionsRepository>(
  (ref) => SanctionsRepositoryImpl(),
);

/// Tarjetas amarillas del usuario autenticado.
final myYellowCardsProvider =
    FutureProvider<List<YellowCard>>((ref) async {
  return ref.read(sanctionsRepositoryProvider).getMyYellowCards();
});

/// Tarjetas amarillas de un equipo específico.
final teamYellowCardsProvider =
    FutureProvider.autoDispose.family<List<YellowCard>, String>(
  (ref, teamId) =>
      ref.read(sanctionsRepositoryProvider).getTeamYellowCards(teamId),
);

// ---------------------------------------------------------------------------
// Appeal notifier
// ---------------------------------------------------------------------------

class AppealState {
  const AppealState({
    this.isLoading = false,
    this.errorMessage,
    this.submitted = false,
  });
  final bool isLoading;
  final String? errorMessage;
  final bool submitted;

  bool get hasError => errorMessage != null;
}

class AppealNotifier extends StateNotifier<AppealState> {
  AppealNotifier(this._repo) : super(const AppealState());

  final SanctionsRepository _repo;

  Future<void> submit({
    required String cardId,
    required String reason,
  }) async {
    if (reason.trim().length < 10) {
      state = const AppealState(
          errorMessage: 'La justificación debe tener al menos 10 caracteres.');
      return;
    }
    state = const AppealState(isLoading: true);
    try {
      await _repo.submitAppeal(cardId: cardId, reason: reason);
      state = const AppealState(submitted: true);
    } on OnzeException catch (e) {
      state = AppealState(errorMessage: e.message);
    } catch (e, st) {
      log.e('Error inesperado al apelar', error: e, stackTrace: st);
      state = const AppealState(
          errorMessage: 'Error inesperado. Intenta nuevamente.');
    }
  }
}

final appealProvider = StateNotifierProvider.autoDispose
    .family<AppealNotifier, AppealState, String>(
  (ref, cardId) =>
      AppealNotifier(ref.read(sanctionsRepositoryProvider)),
);
