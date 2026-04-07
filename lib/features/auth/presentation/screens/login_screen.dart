import 'package:flutter/material.dart';

/// Pantalla de login — implementación completa en la Tarea 3 del plan.
class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Text(
          'Onze — Login',
          style: Theme.of(context).textTheme.displayLarge,
        ),
      ),
    );
  }
}
