import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/screens/create_profile_screen.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/otp_screen.dart';
import '../../features/home/presentation/screens/home_screen.dart';
import '../../features/profile/presentation/screens/edit_profile_screen.dart';
import '../../features/profile/presentation/screens/profile_screen.dart';
import '../../features/fields/domain/models/field.dart';
import '../../features/fields/presentation/screens/become_owner_screen.dart';
import '../../features/fields/presentation/screens/edit_field_screen.dart';
import '../../features/fields/presentation/screens/field_schedules_screen.dart';
import '../../features/fields/presentation/screens/fields_map_screen.dart';
import '../../features/fields/presentation/screens/owner_dashboard_screen.dart';
import '../../features/onboarding/presentation/screens/onboarding_screen.dart';
import '../../features/fields/presentation/screens/owner_fields_screen.dart';
import '../../features/fields/presentation/screens/register_field_screen.dart';
import '../../features/rewards/presentation/screens/achievements_screen.dart';
import '../../features/sanctions/presentation/screens/sanctions_screen.dart';
import '../../features/stats/presentation/screens/ranking_screen.dart';
import '../../features/teams/presentation/screens/create_team_screen.dart';
import '../../features/teams/presentation/screens/edit_team_screen.dart';
import '../../features/teams/presentation/screens/team_detail_screen.dart';
import '../../features/teams/presentation/screens/team_invitations_screen.dart';
import '../../features/teams/presentation/screens/teams_screen.dart';
import '../../features/teams/presentation/screens/user_search_screen.dart';
import '../../features/matches/presentation/screens/match_requests_screen.dart';
import '../../features/matches/presentation/screens/send_challenge_screen.dart';
import '../../shared/services/supabase_service.dart';
import '../utils/go_router_refresh_stream.dart';

/// Rutas nombradas de la aplicación.
abstract final class AppRoutes {
  static const String login = '/login';
  static const String otp = '/otp';
  static const String createProfile = '/create-profile';
  static const String onboarding = '/onboarding';
  static const String home = '/home';
  static const String profile = '/profile';
  static const String editProfile = '/profile/edit';
  static const String teams = '/teams';
  static const String createTeam = '/teams/create';
  static const String teamInvitations = '/teams/invitations';

  /// Ruta dinámica de detalle de equipo.
  static String teamDetail(String teamId) => '/teams/$teamId';

  /// Ruta de edición de un equipo.
  static String editTeam(String teamId) => '/teams/$teamId/edit';

  /// Ruta de búsqueda de usuarios para invitar a un equipo.
  static String teamInvite(String teamId) => '/teams/$teamId/invite';

  // Desafíos / reservas
  static const String matchRequests = '/matches';
  static const String sendChallenge = '/matches/challenge';

  // Ranking
  static const String ranking = '/ranking';
  static const String sanctions = '/sanctions';

  // Logros
  static const String achievements = '/achievements';
  static String achievementsTeam(String teamId) => '/achievements?team=$teamId';

  // Canchas
  static const String fieldsMap = '/fields-map';

  // Dueño
  static const String ownerFields = '/owner';
  static const String becomeOwner = '/owner/become';
  static const String registerField = '/owner/fields/register';
  static const String ownerDashboard = '/owner/dashboard';

  /// Ruta de gestión de horarios de una cancha.
  static String fieldSchedules(String fieldId) => '/owner/fields/$fieldId/schedules';

  /// Ruta de edición de datos de una cancha.
  static String editField(String fieldId) => '/owner/fields/$fieldId/edit';
}

/// Construye el router con auth guard a partir del [ProviderContainer].
GoRouter buildAppRouter(ProviderContainer container) {
  return GoRouter(
    initialLocation: AppRoutes.login,
    refreshListenable: GoRouterRefreshStream(
      supabase.auth.onAuthStateChange,
    ),
    redirect: (context, state) {
      final session = supabase.auth.currentSession;
      final isLoggedIn = session != null;
      final path = state.matchedLocation;

      final isAuthRoute = path == AppRoutes.login ||
          path == AppRoutes.otp ||
          path == AppRoutes.createProfile ||
          path == AppRoutes.onboarding;

      if (!isLoggedIn && !isAuthRoute) return AppRoutes.login;
      if (isLoggedIn && path == AppRoutes.login) return AppRoutes.home;

      return null;
    },
    routes: [
      GoRoute(
        path: AppRoutes.login,
        name: 'login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: AppRoutes.otp,
        name: 'otp',
        builder: (context, state) {
          final phone = state.extra as String? ?? '';
          return OtpScreen(phone: phone);
        },
      ),
      GoRoute(
        path: AppRoutes.createProfile,
        name: 'create-profile',
        builder: (context, state) => const CreateProfileScreen(),
      ),
      GoRoute(
        path: AppRoutes.onboarding,
        name: 'onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(
        path: AppRoutes.home,
        name: 'home',
        builder: (context, state) => const HomeScreen(),
      ),
      GoRoute(
        path: AppRoutes.profile,
        name: 'profile',
        builder: (context, state) => const ProfileScreen(),
      ),
      GoRoute(
        path: AppRoutes.editProfile,
        name: 'edit-profile',
        builder: (context, state) {
          final args = state.extra! as EditProfileArgs;
          return EditProfileScreen(args: args);
        },
      ),
      GoRoute(
        path: AppRoutes.teams,
        name: 'teams',
        builder: (context, state) => const TeamsScreen(),
      ),
      GoRoute(
        path: AppRoutes.createTeam,
        name: 'create-team',
        builder: (context, state) => const CreateTeamScreen(),
      ),
      GoRoute(
        path: AppRoutes.teamInvitations,
        name: 'team-invitations',
        builder: (context, state) => const TeamInvitationsScreen(),
      ),
      GoRoute(
        path: AppRoutes.matchRequests,
        name: 'match-requests',
        builder: (context, state) => const MatchRequestsScreen(),
      ),
      GoRoute(
        path: AppRoutes.sendChallenge,
        name: 'send-challenge',
        builder: (context, state) => const SendChallengeScreen(),
      ),
      GoRoute(
        path: AppRoutes.ranking,
        name: 'ranking',
        builder: (context, state) => const RankingScreen(),
      ),
      GoRoute(
        path: AppRoutes.sanctions,
        name: 'sanctions',
        builder: (context, state) => const SanctionsScreen(),
      ),
      GoRoute(
        path: AppRoutes.achievements,
        name: 'achievements',
        builder: (context, state) {
          final teamId = state.uri.queryParameters['team'];
          return AchievementsScreen(teamId: teamId);
        },
      ),
      GoRoute(
        path: AppRoutes.fieldsMap,
        name: 'fields-map',
        builder: (context, state) => const FieldsMapScreen(),
      ),
      GoRoute(
        path: AppRoutes.ownerFields,
        name: 'owner-fields',
        builder: (context, state) => const OwnerFieldsScreen(),
      ),
      GoRoute(
        path: AppRoutes.becomeOwner,
        name: 'become-owner',
        builder: (context, state) => const BecomeOwnerScreen(),
      ),
      GoRoute(
        path: AppRoutes.registerField,
        name: 'register-field',
        builder: (context, state) => const RegisterFieldScreen(),
      ),
      GoRoute(
        path: AppRoutes.ownerDashboard,
        name: 'owner-dashboard',
        builder: (context, state) {
          final ownerId = state.extra as String? ?? '';
          return OwnerDashboardScreen(ownerId: ownerId);
        },
      ),
      GoRoute(
        path: '/owner/fields/:id/schedules',
        name: 'field-schedules',
        builder: (context, state) {
          final fieldId = state.pathParameters['id']!;
          final field = state.extra as Field?;
          return FieldSchedulesScreen(
            fieldId: fieldId,
            field: field,
          );
        },
      ),
      GoRoute(
        path: '/owner/fields/:id/edit',
        name: 'edit-field',
        builder: (context, state) {
          final field = state.extra! as Field;
          return EditFieldScreen(field: field);
        },
      ),
      GoRoute(
        path: '/teams/:id',
        name: 'team-detail',
        builder: (context, state) {
          final teamId = state.pathParameters['id']!;
          return TeamDetailScreen(teamId: teamId);
        },
        routes: [
          GoRoute(
            path: 'edit',
            name: 'edit-team',
            builder: (context, state) {
              final args = state.extra! as EditTeamArgs;
              return EditTeamScreen(args: args);
            },
          ),
          GoRoute(
            path: 'invite',
            name: 'team-invite',
            builder: (context, state) {
              final teamId = state.pathParameters['id']!;
              final memberIds =
                  state.extra as Set<String>? ?? const {};
              return UserSearchScreen(
                teamId: teamId,
                memberIds: memberIds,
              );
            },
          ),
        ],
      ),
    ],
  );
}
