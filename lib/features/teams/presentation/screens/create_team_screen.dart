// Pantalla de creación de equipo.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/onze_colors.dart';
import '../../../../shared/widgets/onze_button.dart';
import '../providers/teams_providers.dart';

/// Pantalla para crear un equipo nuevo con nombre obligatorio.
class CreateTeamScreen extends ConsumerStatefulWidget {
  const CreateTeamScreen({super.key});

  @override
  ConsumerState<CreateTeamScreen> createState() => _CreateTeamScreenState();
}

class _CreateTeamScreenState extends ConsumerState<CreateTeamScreen> {
  final _nameController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    await ref
        .read(createTeamProvider.notifier)
        .createTeam(_nameController.text.trim());

    if (!mounted) return;

    final state = ref.read(createTeamProvider);
    if (state.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Equipo creado exitosamente.'),
          backgroundColor: OnzeColors.accent,
        ),
      );
      ref.invalidate(myTeamsProvider);
      context.pop();
    } else if (state.hasError) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(state.errorMessage!),
          backgroundColor: OnzeColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // watch mantiene el provider vivo durante el async y actualiza el botón
    final createState = ref.watch(createTeamProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Crear equipo')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 16),
              Text(
                'Nombre del equipo',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _nameController,
                textCapitalization: TextCapitalization.words,
                maxLength: 40,
                decoration: const InputDecoration(
                  hintText: 'Ej: Los Cóndores FC',
                  counterText: '',
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'El nombre es obligatorio';
                  }
                  if (value.trim().length < 3) {
                    return 'Mínimo 3 caracteres';
                  }
                  return null;
                },
                onFieldSubmitted: (_) => _submit(),
              ),
              const SizedBox(height: 8),
              Text(
                'Podrás agregar el escudo del equipo después de crearlo.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: OnzeColors.textSecondary,
                    ),
              ),
              const Spacer(),
              OnzeButton(
                label: 'Crear equipo',
                onPressed: createState.isLoading ? null : _submit,
                isLoading: createState.isLoading,
                icon: Icons.add,
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
