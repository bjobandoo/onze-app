// Pantalla de creación de equipo.

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/onze_colors.dart';
import '../../../../shared/widgets/onze_button.dart';
import '../providers/teams_providers.dart';
import '../widgets/team_shield_picker.dart';

/// Pantalla para crear un equipo nuevo.
class CreateTeamScreen extends ConsumerStatefulWidget {
  const CreateTeamScreen({super.key});

  @override
  ConsumerState<CreateTeamScreen> createState() => _CreateTeamScreenState();
}

class _CreateTeamScreenState extends ConsumerState<CreateTeamScreen> {
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  Uint8List? _shieldBytes;

  static const int _descMaxLength = 200;

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    await ref.read(createTeamProvider.notifier).createTeam(
          _nameController.text.trim(),
          description: _descriptionController.text.trim(),
          shieldBytes: _shieldBytes,
        );

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
    final createState = ref.watch(createTeamProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Crear equipo')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Selector de escudo centrado
              Center(
                child: Column(
                  children: [
                    TeamShieldPicker(
                      localBytes: _shieldBytes,
                      radius: 52,
                      onImagePicked: (bytes) =>
                          setState(() => _shieldBytes = bytes),
                      onRemove: _shieldBytes != null
                          ? () => setState(() => _shieldBytes = null)
                          : null,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Escudo del equipo (opcional)',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: OnzeColors.textSecondary,
                          ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),

              // Nombre
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
              const SizedBox(height: 24),

              // Descripción
              Text(
                'Descripción (opcional)',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _descriptionController,
                maxLines: 3,
                maxLength: _descMaxLength,
                decoration: const InputDecoration(
                  hintText: 'Cuéntanos sobre tu equipo...',
                  alignLabelWithHint: true,
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  '${_descriptionController.text.length}/$_descMaxLength',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: _descriptionController.text.length >
                                _descMaxLength
                            ? OnzeColors.error
                            : OnzeColors.textSecondary,
                      ),
                ),
              ),
              const SizedBox(height: 32),

              OnzeButton(
                label: 'Crear equipo',
                onPressed: createState.isLoading ? null : _submit,
                isLoading: createState.isLoading,
                icon: Icons.add,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
