import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/home/presentation/screens/home_screen.dart';

/// Rutas nombradas de la aplicación.
abstract final class AppRoutes {
  static const String login = '/login';
  static const String home = '/home';
}

/// Configuración de go_router.
///
/// La lógica de redirección (auth guard) se agrega aquí cuando
/// se implemente el provider de sesión.
final GoRouter appRouter = GoRouter(
  initialLocation: AppRoutes.login,
  routes: [
    GoRoute(
      path: AppRoutes.login,
      name: 'login',
      builder: (context, state) => const LoginScreen(),
    ),
    GoRoute(
      path: AppRoutes.home,
      name: 'home',
      builder: (context, state) => const HomeScreen(),
    ),
  ],
);
