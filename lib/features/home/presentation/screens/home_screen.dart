import 'package:flutter/material.dart';

/// Pantalla de inicio — shell de navegación principal.
/// Implementación completa en fases posteriores del plan.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Onze')),
      body: const Center(child: Text('Home')),
    );
  }
}
