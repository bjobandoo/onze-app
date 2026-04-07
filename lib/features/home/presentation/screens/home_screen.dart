import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/routing/app_router.dart';

/// Pantalla de inicio — shell de navegación principal.
/// Navegación completa (BottomNavigationBar) se implementa en Fase 2.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ONZE'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_outline),
            tooltip: 'Mi perfil',
            onPressed: () => context.push(AppRoutes.profile),
          ),
        ],
      ),
      body: const Center(
        child: Text('Inicio — próximamente'),
      ),
    );
  }
}
