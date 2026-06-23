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
import '../../domain/models/match.dart';
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
final myCaptainTeamIdsProvider = FutureProvider<List<String>>((ref) async {
  final teams = await ref.watch(myCaptainTeamsProvider.future);
  return teams.map((t) => t.id).toList();
});

/// IDs de todos los equipos donde el usuario es miembro (capitán o jugador).
/// Usado por el historial de partidos del perfil.
final myMemberTeamIdsProvider = FutureProvider<List<String>>((ref) async {
  final teams = await ref.watch(myTeamsProvider.future);
  return teams.map((t) => t.id).toList();
});

/// Desafíos enviados (como challenger).
final challengesSentProvider =
    FutureProvider<List<MatchRequest>>((ref) async {
  final ids = await ref.watch(myCaptainTeamIdsProvider.future);
  if (ids.isEmpty) return [];
  return ref.read(matchesRepositoryProvider).getChallengesAsChallenger(ids);
});

/// Desafíos recibidos (como challenged) en estado pending_opponent.
final challengesReceivedProvider =
    FutureProvider<List<MatchRequest>>((ref) async {
  final ids = await ref.watch(myCaptainTeamIdsProvider.future);
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

// ---------------------------------------------------------------------------
// Creación de reserva amistosa
// ---------------------------------------------------------------------------

/// Notifier de creación de reservas amistosas. Reutiliza [SendChallengeState].
class CreateFriendlyNotifier extends StateNotifier<SendChallengeState> {
  CreateFriendlyNotifier(this._repo) : super(const SendChallengeState());

  final MatchesRepository _repo;

  Future<bool> create({
    required String teamId,
    required String fieldId,
    required DateTime date,
    required TimeOfDay startTime,
    required TimeOfDay endTime,
    required double price,
  }) async {
    state = const SendChallengeState(isLoading: true);
    try {
      final request = await _repo.createFriendlyBooking(
        teamId: teamId,
        fieldId: fieldId,
        date: date,
        startTime: startTime,
        endTime: endTime,
        price: price,
      );
      state = SendChallengeState(sentRequest: request);
      return true;
    } on OnzeException catch (e) {
      state = SendChallengeState(errorMessage: e.message);
      return false;
    } catch (e, st) {
      log.e('Error inesperado al crear amistoso', error: e, stackTrace: st);
      state = const SendChallengeState(
          errorMessage: 'Error inesperado. Intenta nuevamente.');
      return false;
    }
  }
}

final createFriendlyProvider = StateNotifierProvider.autoDispose<
    CreateFriendlyNotifier, SendChallengeState>(
  (ref) => CreateFriendlyNotifier(ref.read(matchesRepositoryProvider)),
);

// ---------------------------------------------------------------------------
// Partidos oficiales (matches)
// ---------------------------------------------------------------------------

/// Todos los partidos de los equipos donde el usuario es capitán.
final myMatchesProvider = FutureProvider<List<Match>>((ref) async {
  final teamIds = await ref.watch(myCaptainTeamIdsProvider.future);
  if (teamIds.isEmpty) return [];
  final repo = ref.read(matchesRepositoryProvider);
  await repo.markMatchesAwaitingReport();
  return repo.getMyMatches(teamIds);
});

/// Historial de partidos finalizados de todos los equipos del usuario
/// (miembro o capitán). Incluye oficiales resueltos/cancelados y amistosos
/// completados. Ordenado del más reciente al más antiguo.
final matchHistoryProvider = FutureProvider<List<Match>>((ref) async {
  final teamIds = await ref.watch(myMemberTeamIdsProvider.future);
  if (teamIds.isEmpty) return [];
  final repo = ref.read(matchesRepositoryProvider);
  await repo.markMatchesAwaitingReport();
  final matches = await repo.getMyMatches(teamIds);
  return matches
      .where((m) =>
          m.status == MatchStatus.resolved ||
          m.status == MatchStatus.cancelled)
      .toList();
});

/// Próximo partido programado de los equipos donde el usuario es capitán,
/// o null si no hay ninguno. Usado por la card "Próximo partido" del Home.
final upcomingMatchProvider = FutureProvider<Match?>((ref) async {
  final matches = await ref.watch(myMatchesProvider.future);
  final now = DateTime.now();
  final upcoming = matches
      .where((m) =>
          m.status == MatchStatus.scheduled && m.matchEndDateTime.isAfter(now))
      .toList()
    ..sort((a, b) => a.matchEndDateTime.compareTo(b.matchEndDateTime));
  return upcoming.isEmpty ? null : upcoming.first;
});

/// Partidos donde el usuario (capitán) aún no ha reportado su resultado.
final pendingMyReportProvider = FutureProvider<List<Match>>((ref) async {
  final teamIds = await ref.watch(myCaptainTeamIdsProvider.future);
  if (teamIds.isEmpty) return [];
  final matches = await ref.watch(myMatchesProvider.future);
  final teamIdSet = teamIds.toSet();

  return matches.where((m) {
    if (m.status != MatchStatus.awaitingReport) return false;
    if (teamIdSet.contains(m.teamAId)) return m.teamAReport == null;
    if (teamIdSet.contains(m.teamBId)) return m.teamBReport == null;
    return false;
  }).toList();
});

/// Partidos en disputa en las canchas del dueño.
final disputedMatchesForOwnerProvider =
    FutureProvider<List<Match>>((ref) async {
  final user = await ref.watch(currentUserProvider.future);
  if (user == null || !user.isOwner) return [];
  return ref
      .read(matchesRepositoryProvider)
      .getDisputedMatchesForOwner(user.id);
});

// ---------------------------------------------------------------------------
// Reporte de resultado
// ---------------------------------------------------------------------------

class ReportMatchState {
  const ReportMatchState({
    this.isLoading = false,
    this.errorMessage,
    this.resultStatus,
  });
  final bool isLoading;
  final String? errorMessage;

  /// Nuevo estado del partido tras reportar: 'awaiting_report'|'resolved'|'disputed'
  final String? resultStatus;

  bool get hasError => errorMessage != null;
  bool get isDone => resultStatus != null;

  ReportMatchState copyWith({
    bool? isLoading,
    String? errorMessage,
    String? resultStatus,
  }) =>
      ReportMatchState(
        isLoading: isLoading ?? this.isLoading,
        errorMessage: errorMessage,
        resultStatus: resultStatus ?? this.resultStatus,
      );
}

class ReportMatchNotifier extends StateNotifier<ReportMatchState> {
  ReportMatchNotifier(this._repo) : super(const ReportMatchState());

  final MatchesRepository _repo;

  Future<void> report({
    required String matchId,
    required MatchReport report,
  }) async {
    state = state.copyWith(isLoading: true);
    try {
      final newStatus = await _repo.reportMatchResult(
        matchId: matchId,
        report: report,
      );
      state = ReportMatchState(resultStatus: newStatus);
      // Notificar al dueño si hay disputa
      if (newStatus == 'disputed') {
        unawaited(
            triggerPushNotification(PushEvent.matchDisputed, matchId));
      }
    } on OnzeException catch (e) {
      state = ReportMatchState(errorMessage: e.message);
    } catch (e, st) {
      log.e('Error inesperado al reportar resultado', error: e, stackTrace: st);
      state = const ReportMatchState(
        errorMessage: 'Error inesperado. Intenta nuevamente.',
      );
    }
  }
}

final reportMatchProvider = StateNotifierProvider.autoDispose
    .family<ReportMatchNotifier, ReportMatchState, String>(
  (ref, matchId) => ReportMatchNotifier(ref.read(matchesRepositoryProvider)),
);

// ---------------------------------------------------------------------------
// Resolución de disputas (dueño)
// ---------------------------------------------------------------------------

class ResolveDisputeState {
  const ResolveDisputeState({
    this.isLoading = false,
    this.errorMessage,
    this.resolved = false,
  });
  final bool isLoading;
  final String? errorMessage;
  final bool resolved;

  bool get hasError => errorMessage != null;
}

class ResolveDisputeNotifier extends StateNotifier<ResolveDisputeState> {
  ResolveDisputeNotifier(this._repo) : super(const ResolveDisputeState());

  final MatchesRepository _repo;

  Future<void> resolve({
    required String matchId,
    required OwnerResolution resolution,
  }) async {
    state = const ResolveDisputeState(isLoading: true);
    try {
      await _repo.resolveMatchDispute(
        matchId: matchId,
        resolution: resolution,
      );
      state = const ResolveDisputeState(resolved: true);
      // Notificar a ambos capitanes
      unawaited(
          triggerPushNotification(PushEvent.matchDisputeResolved, matchId));
    } on OnzeException catch (e) {
      state = ResolveDisputeState(errorMessage: e.message);
    } catch (e, st) {
      log.e('Error inesperado al resolver disputa', error: e, stackTrace: st);
      state = const ResolveDisputeState(
        errorMessage: 'Error inesperado. Intenta nuevamente.',
      );
    }
  }
}

final resolveDisputeProvider = StateNotifierProvider.autoDispose
    .family<ResolveDisputeNotifier, ResolveDisputeState, String>(
  (ref, matchId) =>
      ResolveDisputeNotifier(ref.read(matchesRepositoryProvider)),
);
