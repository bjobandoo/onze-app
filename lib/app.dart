import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/routing/app_router.dart';
import 'core/theme/onze_theme.dart';

/// Raíz de la aplicación.
///
/// Recibe el [ProviderContainer] para construir el router con auth guard.
class OnzeApp extends ConsumerWidget {
  const OnzeApp({super.key, required this.container});

  final ProviderContainer container;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'Onze',
      debugShowCheckedModeBanner: false,
      theme: OnzeTheme.dark,
      routerConfig: buildAppRouter(container),
    );
  }
}
