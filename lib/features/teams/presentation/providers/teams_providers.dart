// Providers de Riverpod para el feature de equipos.

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/onze_exception.dart';
import '../../../../core/utils/logger.dart';
import '../../../../features/auth/presentation/providers/auth_providers.dart';
import '../../../../shared/models/app_user.dart';
import '../../../../shared/services/push_trigger.dart';
import '../../data/teams_repository_impl.dart';
import '../../domain/models/team.dart';
import '../../domain/models/team_join_request.dart';
import '../../domain/models/team_member.dart';
import '../../domain/teams_repository.dart';

final teamsRepositoryProvider = Provider<TeamsRepository>(
  (ref) => TeamsRepositoryImpl(),
);

/// Equipos del usuario autenticado.
final myTeamsProvider = FutureProvider<List<Team>>((ref) async {
  final userAsync = await ref.watch(currentUserProvider.future);
  if (userAsync == null) return [];
  return ref.read(teamsRepositoryProvider).getMyTeams(userAsync.id);
});

/// Detalle de un equipo específico por ID.
final teamDetailProvider =
    FutureProvider.family<Team?, String>((ref, teamId) async {
  return ref.read(teamsRepositoryProvider).getTeamById(teamId);
});

/// Miembros de un equipo específico.
final teamMembersProvider =
    FutureProvider.family<List<TeamMember>, String>((ref, teamId) async {
  return ref.read(teamsRepositoryProvider).getTeamMembers(teamId);
});

/// Invitaciones pendientes del usuario autenticado.
final myPendingInvitationsProvider =
    FutureProvider<List<TeamJoinRequest>>((ref) async {
  final user = await ref.watch(currentUserProvider.future);
  if (user == null) return [];
  return ref
      .read(teamsRepositoryProvider)
      .getMyPendingInvitations(user.id);
});

/// Solicitudes de ingreso pendientes para un equipo (vista capitán).
final pendingRequestsForTeamProvider =
    FutureProvider.family<List<TeamJoinRequest>, String>((ref, teamId) async {
  return ref
      .read(teamsRepositoryProvider)
      .getPendingRequestsForTeam(teamId);
});

// ---------------------------------------------------------------------------
// CreateTeamNotifier
// ---------------------------------------------------------------------------

/// Estado del proceso de creación de equipo.
class CreateTeamState {
  const CreateTeamState({
    this.isLoading = false,
    this.errorMessage,
    this.createdTeam,
  });

  final bool isLoading;
  final String? errorMessage;
  final Team? createdTeam;

  bool get hasError => errorMessage != null;
  bool get success => createdTeam != null;

  CreateTeamState copyWith({
    bool? isLoading,
    String? errorMessage,
    Team? createdTeam,
  }) =>
      CreateTeamState(
        isLoading: isLoading ?? this.isLoading,
        errorMessage: errorMessage,
        createdTeam: createdTeam ?? this.createdTeam,
      );
}

/// Notifier que maneja la creación de un equipo nuevo.
class CreateTeamNotifier extends StateNotifier<CreateTeamState> {
  CreateTeamNotifier(this._repo, this._captainId)
      : super(const CreateTeamState());

  final TeamsRepository _repo;
  final String _captainId;

  Future<void> createTeam(String name) async {
    state = state.copyWith(isLoading: true);
    try {
      final team = await _repo.createTeam(
        captainId: _captainId,
        name: name,
      );
      state = CreateTeamState(createdTeam: team);
      log.i('Equipo creado exitosamente: ${team.id}');
    } on OnzeException catch (e) {
      state = CreateTeamState(errorMessage: e.message);
    } catch (e, st) {
      log.e('Error inesperado al crear equipo', error: e, stackTrace: st);
      state = const CreateTeamState(
        errorMessage: 'Error inesperado. Intenta nuevamente.',
      );
    }
  }
}

final createTeamProvider = StateNotifierProvider.autoDispose<CreateTeamNotifier,
    CreateTeamState>((ref) {
  final captainId =
      ref.watch(currentUserProvider).valueOrNull?.id ?? '';
  return CreateTeamNotifier(
    ref.read(teamsRepositoryProvider),
    captainId,
  );
});

// ---------------------------------------------------------------------------
// UserSearchNotifier
// ---------------------------------------------------------------------------

/// Estado de la búsqueda de usuarios para invitar al equipo.
class UserSearchState {
  const UserSearchState({
    this.query = '',
    this.results = const [],
    this.isLoading = false,
    this.errorMessage,
    this.invitedIds = const {},
  });

  final String query;
  final List<AppUser> results;
  final bool isLoading;
  final String? errorMessage;

  /// IDs de usuarios a los que ya se envió invitación en esta sesión.
  final Set<String> invitedIds;

  bool get hasError => errorMessage != null;
  bool get isEmpty => query.isEmpty;

  UserSearchState copyWith({
    String? query,
    List<AppUser>? results,
    bool? isLoading,
    String? errorMessage,
    Set<String>? invitedIds,
  }) =>
      UserSearchState(
        query: query ?? this.query,
        results: results ?? this.results,
        isLoading: isLoading ?? this.isLoading,
        errorMessage: errorMessage,
        invitedIds: invitedIds ?? this.invitedIds,
      );
}

/// Notifier que maneja la búsqueda de usuarios y el envío de invitaciones.
class UserSearchNotifier extends StateNotifier<UserSearchState> {
  UserSearchNotifier(this._repo, this._currentUserId, this._teamId)
      : super(const UserSearchState());

  final TeamsRepository _repo;
  final String _currentUserId;
  final String _teamId;
  Timer? _debounce;

  /// Actualiza la query y dispara la búsqueda con debounce de 350ms.
  void setQuery(String query) {
    _debounce?.cancel();
    if (query.trim().length < 2) {
      state = UserSearchState(
        query: query,
        invitedIds: state.invitedIds,
      );
      return;
    }

    state = state.copyWith(query: query, isLoading: true, errorMessage: null);
    _debounce = Timer(const Duration(milliseconds: 350), () => _search(query));
  }

  Future<void> _search(String query) async {
    try {
      final results = await _repo.searchUsers(
        query,
        excludeUserId: _currentUserId,
      );
      if (!mounted) return;
      state = state.copyWith(results: results, isLoading: false);
    } on OnzeException catch (e) {
      if (!mounted) return;
      state = state.copyWith(isLoading: false, errorMessage: e.message);
    } catch (e, st) {
      log.e('Error inesperado en búsqueda de usuarios', error: e, stackTrace: st);
      if (!mounted) return;
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Error inesperado. Intenta nuevamente.',
      );
    }
  }

  /// Envía la invitación al [userId] y lo marca como invitado en el estado.
  Future<void> invite(String userId) async {
    try {
      await _repo.inviteMember(teamId: _teamId, invitedUserId: userId);
      if (!mounted) return;
      state = state.copyWith(
        invitedIds: {...state.invitedIds, userId},
      );
      log.i('Invitación enviada a $userId');
      unawaited(triggerPushNotification(
        PushEvent.teamInvitation,
        _teamId,
        extra: {'targetUserId': userId},
      ));
    } on OnzeException catch (e) {
      if (!mounted) return;
      state = state.copyWith(errorMessage: e.message);
    } catch (e, st) {
      log.e('Error al enviar invitación', error: e, stackTrace: st);
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }
}

/// Parámetro compuesto para el provider de búsqueda (teamId + currentUserId).
typedef UserSearchArgs = ({String teamId, String currentUserId});

final userSearchProvider = StateNotifierProvider.autoDispose
    .family<UserSearchNotifier, UserSearchState, UserSearchArgs>(
  (ref, args) => UserSearchNotifier(
    ref.read(teamsRepositoryProvider),
    args.currentUserId,
    args.teamId,
  ),
);
