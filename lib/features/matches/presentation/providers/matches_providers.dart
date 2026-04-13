// Providers de Riverpod para el feature de partidos y reservas.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/onze_exception.dart';
import '../../../../core/utils/logger.dart';
import '../../../../features/auth/presentation/providers/auth_providers.dart';
import '../../../../features/fields/domain/models/field_schedule.dart';
import '../../../../features/teams/domain/models/team.dart';
import '../../../../features/teams/presentation/providers/teams_providers.dart';
import '../../../../shared/services/push_trigger.dart';
import '../../data/matches_repository_impl.dart';
import '../../domain/matches_repository.dart';
import '../../domain/models/match_request.dart';

final matchesRepositoryProvider = Provider<MatchesRepository>(
  (ref) => MatchesRepositoryImpl(),
);

// ---------------------------------------------------------------------------
// Equipos donde el usuario es capitán
// ---------------------------------------------------------------------------

/// Equipos donde el usuario autenticado es capitán.
final myCaptainTeamsProvider = FutureProvider<List<Team>>((ref) async {
  final user = await ref.watch(currentUserProvider.future);
  if (user == null) return [];
  final teams = await ref.watch(myTeamsProvider.future);
  return teams.where((t) => t.captainId == user.id).toList();
});

// ---------------------------------------------------------------------------
// Listas de solicitudes
// ---------------------------------------------------------------------------

/// IDs de los equipos donde soy capitán (para queries de match_requests).
final _myCaptainTeamIdsProvider = FutureProvider<List<String>>((ref) async {
  final teams = await ref.watch(myCaptainTeamsProvider.future);
  return teams.map((t) => t.id).toList();
});

/// Desafíos enviados (como challenger).
final challengesSentProvider =
    FutureProvider<List<MatchRequest>>((ref) async {
  final ids = await ref.watch(_myCaptainTeamIdsProvider.future);
  if (ids.isEmpty) return [];
  return ref.read(matchesRepositoryProvider).getChallengesAsChallenger(ids);
});

/// Desafíos recibidos (como challenged) en estado pending_opponent.
final challengesReceivedProvider =
    FutureProvider<List<MatchRequest>>((ref) async {
  final ids = await ref.watch(_myCaptainTeamIdsProvider.future);
  if (ids.isEmpty) return [];
  return ref.read(matchesRepositoryProvider).getChallengesAsChallenged(ids);
});

/// Solicitudes pendientes para el dueño de cancha.
final pendingOwnerRequestsProvider =
    FutureProvider<List<MatchRequest>>((ref) async {
  final user = await ref.watch(currentUserProvider.future);
  if (user == null) return [];
  return ref.read(matchesRepositoryProvider).getPendingOwnerRequests(user.id);
});

// ---------------------------------------------------------------------------
// Horarios disponibles por fecha
// ---------------------------------------------------------------------------

typedef SlotsQueryArgs = ({String fieldId, DateTime date});

/// Horarios disponibles (no reservados) de un campo para una fecha dada.
final availableSlotsProvider =
    FutureProvider.autoDispose.family<List<FieldSchedule>, SlotsQueryArgs>(
        (ref, args) async {
  return ref.read(matchesRepositoryProvider).getAvailableSlotsForDate(
        fieldId: args.fieldId,
        date: args.date,
      );
});

// ---------------------------------------------------------------------------
// Búsqueda de equipos rivales
// ---------------------------------------------------------------------------

class TeamSearchState {
  const TeamSearchState({
    this.query = '',
    this.results = const [],
    this.isLoading = false,
    this.errorMessage,
  });

  final String query;
  final List<Team> results;
  final bool isLoading;
  final String? errorMessage;

  bool get hasError => errorMessage != null;

  TeamSearchState copyWith({
    String? query,
    List<Team>? results,
    bool? isLoading,
    String? errorMessage,
  }) =>
      TeamSearchState(
        query: query ?? this.query,
        results: results ?? this.results,
        isLoading: isLoading ?? this.isLoading,
        errorMessage: errorMessage,
      );
}

class TeamSearchNotifier extends StateNotifier<TeamSearchState> {
  TeamSearchNotifier(this._repo, this._excludeTeamId)
      : super(const TeamSearchState());

  final MatchesRepository _repo;
  final String _excludeTeamId;
  Timer? _debounce;

  void setQuery(String query) {
    _debounce?.cancel();
    if (query.trim().length < 2) {
      state = TeamSearchState(query: query);
      return;
    }
    state = state.copyWith(query: query, isLoading: true, errorMessage: null);
    _debounce = Timer(const Duration(milliseconds: 350), () => _search(query));
  }

  Future<void> _search(String query) async {
    try {
      final results = await _repo.searchTeams(query,
          excludeTeamId: _excludeTeamId);
      if (mounted) state = state.copyWith(results: results, isLoading: false);
    } on OnzeException catch (e) {
      if (mounted) {
        state = state.copyWith(isLoading: false, errorMessage: e.message);
      }
    } catch (e, st) {
      log.e('Error buscando equipos', error: e, stackTrace: st);
      if (mounted) {
        state = state.copyWith(
            isLoading: false,
            errorMessage: 'Error inesperado.');
      }
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }
}

/// Args: equipo que se excluye de la búsqueda (el propio del desafiador).
final teamSearchProvider = StateNotifierProvider.autoDispose
    .family<TeamSearchNotifier, TeamSearchState, String>(
  (ref, excludeTeamId) =>
      TeamSearchNotifier(ref.read(matchesRepositoryProvider), excludeTeamId),
);

// ---------------------------------------------------------------------------
// Acciones sobre solicitudes
// ---------------------------------------------------------------------------

class ChallengeActionState {
  const ChallengeActionState({
    this.isLoading = false,
    this.errorMessage,
    this.successMessage,
  });

  final bool isLoading;
  final String? errorMessage;
  final String? successMessage;

  bool get hasError => errorMessage != null;
  bool get success => successMessage != null;
}

class ChallengeActionNotifier
    extends StateNotifier<ChallengeActionState> {
  ChallengeActionNotifier(this._repo) : super(const ChallengeActionState());

  final MatchesRepository _repo;

  Future<bool> accept(String matchRequestId) => _run(
        () async {
          await _repo.acceptChallenge(matchRequestId);
          unawaited(triggerPushNotification(
              PushEvent.challengeAccepted, matchRequestId));
        },
        'Desafío aceptado.',
      );

  Future<bool> reject(String matchRequestId) => _run(
        () async {
          await _repo.rejectChallenge(matchRequestId);
          unawaited(triggerPushNotification(
              PushEvent.challengeRejected, matchRequestId));
        },
        'Desafío rechazado.',
      );

  Future<bool> cancel(String matchRequestId) =>
      _run(() => _repo.cancelChallenge(matchRequestId), 'Desafío cancelado.');

  Future<bool> confirmByOwner(String matchRequestId) => _run(
        () async {
          await _repo.confirmMatch(matchRequestId);
          unawaited(triggerPushNotification(
              PushEvent.matchConfirmed, matchRequestId));
        },
        'Reserva confirmada.',
      );

  Future<bool> rejectByOwner(String matchRequestId) => _run(
        () async {
          await _repo.rejectMatchByOwner(matchRequestId);
          unawaited(triggerPushNotification(
              PushEvent.matchRejectedOwner, matchRequestId));
        },
        'Reserva rechazada.',
      );

  Future<bool> _run(Future<void> Function() action, String success) async {
    state = const ChallengeActionState(isLoading: true);
    try {
      await action();
      state = ChallengeActionState(successMessage: success);
      return true;
    } on OnzeException catch (e) {
      state = ChallengeActionState(errorMessage: e.message);
      return false;
    } catch (e, st) {
      log.e('Error en acción de desafío', error: e, stackTrace: st);
      state = const ChallengeActionState(
          errorMessage: 'Error inesperado. Intenta nuevamente.');
      return false;
    }
  }
}

final challengeActionProvider = StateNotifierProvider.autoDispose<
    ChallengeActionNotifier, ChallengeActionState>(
  (ref) => ChallengeActionNotifier(ref.read(matchesRepositoryProvider)),
);

// ---------------------------------------------------------------------------
// Envío de desafío
// ---------------------------------------------------------------------------

class SendChallengeState {
  const SendChallengeState({
    this.isLoading = false,
    this.errorMessage,
    this.sentRequest,
  });

  final bool isLoading;
  final String? errorMessage;
  final MatchRequest? sentRequest;

  bool get hasError => errorMessage != null;
  bool get success => sentRequest != null;
}

class SendChallengeNotifier
    extends StateNotifier<SendChallengeState> {
  SendChallengeNotifier(this._repo) : super(const SendChallengeState());

  final MatchesRepository _repo;

  Future<bool> send({
    required String challengerTeamId,
    required String challengedTeamId,
    required String fieldId,
    required DateTime date,
    required TimeOfDay startTime,
    required TimeOfDay endTime,
    required double price,
  }) async {
    state = const SendChallengeState(isLoading: true);
    try {
      final request = await _repo.sendChallenge(
        challengerTeamId: challengerTeamId,
        challengedTeamId: challengedTeamId,
        fieldId: fieldId,
        date: date,
        startTime: startTime,
        endTime: endTime,
        price: price,
      );
      state = SendChallengeState(sentRequest: request);
      unawaited(triggerPushNotification(
          PushEvent.challengeReceived, request.id));
      return true;
    } on OnzeException catch (e) {
      state = SendChallengeState(errorMessage: e.message);
      return false;
    } catch (e, st) {
      log.e('Error inesperado al enviar desafío', error: e, stackTrace: st);
      state = const SendChallengeState(
          errorMessage: 'Error inesperado. Intenta nuevamente.');
      return false;
    }
  }
}

final sendChallengeProvider =
    StateNotifierProvider.autoDispose<SendChallengeNotifier, SendChallengeState>(
  (ref) => SendChallengeNotifier(ref.read(matchesRepositoryProvider)),
);
