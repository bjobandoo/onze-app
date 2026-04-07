import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/providers/auth_providers.dart';
import '../../features/auth/presentation/screens/create_profile_screen.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/otp_screen.dart';
import '../../features/home/presentation/screens/home_screen.dart';
import '../../shared/services/supabase_service.dart';
import '../utils/go_router_refresh_stream.dart';

/// Rutas nombradas de la aplicación.
abstract final class AppRoutes {
  static const String login = '/login';
  static const String otp = '/otp';
  static const String createProfile = '/create-profile';
  static const String home = '/home';
}

/// Construye el router con auth guard a partir del [ProviderContainer].
///
/// Necesita acceso al container de Riverpod para leer [authStateChangesProvider]
/// sin depender de un BuildContext.
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
          path == AppRoutes.createProfile;

      // Sin sesión → siempre al login
      if (!isLoggedIn && !isAuthRoute) return AppRoutes.login;

      // Con sesión activa → no dejar volver al login
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
        path: AppRoutes.home,
        name: 'home',
        builder: (context, state) => const HomeScreen(),
      ),
    ],
  );
}
