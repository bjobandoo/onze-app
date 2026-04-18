// Pantalla de edición de equipo (capitán).
// Permite cambiar el escudo y la descripción. El nombre no es editable.

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/errors/onze_exception.dart';
import '../../../../core/theme/onze_colors.dart';
import '../../domain/models/team.dart';
import '../providers/teams_providers.dart';
import '../widgets/team_shield_picker.dart';

/// Argumentos para la pantalla de edición de equipo.
class EditTeamArgs {
  const EditTeamArgs({required this.team});
  final Team team;
}

/// Pantalla para editar escudo y descripción del equipo.
class EditTeamScreen extends ConsumerStatefulWidget {
  const EditTeamScreen({super.key, required this.args});

  final EditTeamArgs args;

  @override
  ConsumerState<EditTeamScreen> createState() => _EditTeamScreenState();
}

class _EditTeamScreenState extends ConsumerState<EditTeamScreen> {
  late final TextEditingController _descController;
  Uint8List? _newShieldBytes; // bytes elegidos localmente (aún no subidos)
  bool _removeShield = false;  // usuario eligió quitar el escudo actual
  bool _isLoading = false;
  String? _globalError;

  static const int _descMaxLength = 200;

  Team get _team => widget.args.team;

  @override
  void initState() {
    super.initState();
    _descController =
        TextEditingController(text: _team.description ?? '');
  }

  @override
  void dispose() {
    _descController.dispose();
    super.dispose();
  }

  bool get _hasChanges {
    final descChanged =
        _descController.text.trim() != (_team.description ?? '');
    return descChanged || _newShieldBytes != null || _removeShield;
  }

  // ---------------------------------------------------------------------------
  // Guardar
  // ---------------------------------------------------------------------------

  Future<void> _save() async {
    setState(() {
      _isLoading = true;
      _globalError = null;
    });

    try {
      final repo = ref.read(teamsRepositoryProvider);

      // 1. Subir nuevo escudo si se eligió uno
      if (_newShieldBytes != null) {
        await repo.uploadTeamShield(
          teamId: _team.id,
          bytes: _newShieldBytes!,
        );
      }

      // 2. Actualizar descripción si cambió
      final newDesc = _descController.text.trim();
      if (newDesc != (_team.description ?? '')) {
        await repo.updateTeam(teamId: _team.id, description: newDesc);
      }

      // Invalidar providers para que se recarguen con los nuevos datos
      ref
        ..invalidate(teamDetailProvider(_team.id))
        ..invalidate(myTeamsProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Equipo actualizado correctamente.'),
            backgroundColor: OnzeColors.accent,
          ),
        );
        context.pop();
      }
    } on OnzeException catch (e) {
      setState(() => _globalError = e.message);
    } catch (e) {
      setState(() => _globalError = 'Error inesperado. Intenta nuevamente.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Editar equipo'),
        actions: [
          TextButton(
            onPressed: (_isLoading || !_hasChanges) ? null : _save,
            child: _isLoading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: OnzeColors.highlight,
                    ),
                  )
                : const Text(
                    'Guardar',
                    style: TextStyle(
                      color: OnzeColors.highlight,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Escudo
            Center(
              child: Column(
                children: [
                  TeamShieldPicker(
                    imageUrl: _removeShield ? null : _team.shieldUrl,
                    localBytes: _newShieldBytes,
                    radius: 52,
                    onImagePicked: (bytes) => setState(() {
                      _newShieldBytes = bytes;
                      _removeShield = false;
                    }),
                    onRemove: (_team.shieldUrl != null || _newShieldBytes != null)
                        ? () => setState(() {
                              _newShieldBytes = null;
                              _removeShield = true;
                            })
                        : null,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Toca para cambiar el escudo',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: OnzeColors.textSecondary,
                        ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),

            // Nombre (solo lectura)
            Text(
              'Nombre del equipo',
              style: Theme.of(context).textTheme.labelSmall,
            ),
            const SizedBox(height: 8),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
              decoration: BoxDecoration(
                color: OnzeColors.surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: OnzeColors.border),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _team.name,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: OnzeColors.textSecondary,
                          ),
                    ),
                  ),
                  const Icon(Icons.lock_outline,
                      size: 16, color: OnzeColors.textSecondary),
                ],
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'El nombre del equipo no se puede modificar.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: OnzeColors.textSecondary,
                  ),
            ),
            const SizedBox(height: 24),

            // Descripción
            Text(
              'Descripción',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _descController,
              maxLines: 4,
              maxLength: _descMaxLength,
              decoration: const InputDecoration(
                hintText: 'Cuéntanos sobre tu equipo...',
                alignLabelWithHint: true,
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                '${_descController.text.length}/$_descMaxLength',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: _descController.text.length > _descMaxLength
                          ? OnzeColors.error
                          : OnzeColors.textSecondary,
                    ),
              ),
            ),

            if (_globalError != null) ...[
              const SizedBox(height: 20),
              _ErrorBanner(message: _globalError!),
            ],
          ],
        ),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: OnzeColors.error.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: OnzeColors.error.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: OnzeColors.error, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: OnzeColors.error),
            ),
          ),
        ],
      ),
    );
  }
}
