import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/routing/app_router.dart';
import 'core/theme/onze_theme.dart';

/// Raíz de la aplicación.
///
/// Configura el router (go_router), el tema oscuro de Onze y el
/// [ProviderScope] ya está definido en [main.dart].
class OnzeApp extends ConsumerWidget {
  const OnzeApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'Onze',
      debugShowCheckedModeBanner: false,
      theme: OnzeTheme.dark,
      routerConfig: appRouter,
    );
  }
}
