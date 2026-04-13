import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/routing/app_router.dart';
import 'core/theme/onze_theme.dart';
import 'features/auth/presentation/providers/auth_providers.dart';
import 'shared/services/notification_service.dart';

/// Raíz de la aplicación.
///
/// Recibe el [ProviderContainer] para construir el router con auth guard.
class OnzeApp extends ConsumerWidget {
  const OnzeApp({super.key, required this.container});

  final ProviderContainer container;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Guarda el token FCM en DB cuando el usuario se autentica.
    ref.listen(currentUserProvider, (_, next) {
      final userId = next.valueOrNull?.id;
      if (userId != null) {
        NotificationService.instance.saveTokenToDb(userId);
      }
    });

    return MaterialApp.router(
      title: 'Onze',
      debugShowCheckedModeBanner: false,
      theme: OnzeTheme.dark,
      routerConfig: buildAppRouter(container),
    );
  }
}
