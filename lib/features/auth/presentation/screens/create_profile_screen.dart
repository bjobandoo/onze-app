import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/errors/onze_exception.dart';
import '../../../../core/routing/app_router.dart';
import '../../../../core/theme/onze_colors.dart';
import '../../../../shared/models/player_enums.dart';
import '../../../../shared/widgets/onze_button.dart';
import '../../../../shared/widgets/onze_select_chip.dart';
import '../../../../shared/widgets/onze_text_field.dart';
import '../providers/auth_providers.dart';

/// Pantalla de creación de perfil del jugador recién registrado.
class CreateProfileScreen extends ConsumerStatefulWidget {
  const CreateProfileScreen({super.key});

  @override
  ConsumerState<CreateProfileScreen> createState() =>
      _CreateProfileScreenState();
}

class _CreateProfileScreenState extends ConsumerState<CreateProfileScreen> {
  final _nameController = TextEditingController();
  PlayerPosition _position = PlayerPosition.mediocampista;
  DominantFoot _dominantFoot = DominantFoot.derecho;
  ExperienceLevel _experience = ExperienceLevel.intermedio;

  bool _isLoading = false;
  String? _nameError;
  String? _globalError;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _nameError = 'Ingresa tu nombre');
      return;
    }
    if (name.length < 3) {
      setState(() => _nameError = 'El nombre debe tener al menos 3 caracteres');
      return;
    }
    setState(() {
      _nameError = null;
      _globalError = null;
      _isLoading = true;
    });

    try {
      await ref.read(authRepositoryProvider).createPlayerProfile(
            fullName: name,
            position: _position,
            dominantFoot: _dominantFoot,
            experienceLevel: _experience,
          );
      if (mounted) context.go(AppRoutes.home);
    } on OnzeException catch (e) {
      setState(() => _globalError = e.message);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 48),
              _buildHeader(context),
              const SizedBox(height: 40),
              OnzeTextField(
                label: 'Tu nombre completo',
                controller: _nameController,
                hint: 'Ej: Carlos Pérez',
                errorText: _nameError,
                keyboardType: TextInputType.name,
                textInputAction: TextInputAction.next,
                onChanged: (_) {
                  if (_nameError != null) setState(() => _nameError = null);
                },
              ),
              const SizedBox(height: 32),
              _buildSectionTitle(context, 'Posición en el campo'),
              const SizedBox(height: 12),
              _buildPositionSelector(),
              const SizedBox(height: 32),
              _buildSectionTitle(context, 'Pie hábil'),
              const SizedBox(height: 12),
              _buildFootSelector(),
              const SizedBox(height: 32),
              _buildSectionTitle(context, 'Nivel de experiencia'),
              const SizedBox(height: 12),
              _buildExperienceSelector(),
              if (_globalError != null) ...[
                const SizedBox(height: 24),
                _buildErrorBanner(_globalError!),
              ],
              const SizedBox(height: 40),
              OnzeButton(
                label: 'Crear perfil',
                onPressed: _isLoading ? null : _submit,
                isLoading: _isLoading,
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Cuéntanos sobre ti',
          style: Theme.of(context).textTheme.displayLarge,
        ),
        const SizedBox(height: 8),
        Text(
          'Esta información ayuda a otros jugadores\na conocerte mejor.',
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: OnzeColors.textSecondary,
              ),
        ),
      ],
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    return Text(
      title,
      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
    );
  }

  Widget _buildPositionSelector() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: PlayerPosition.values.map((pos) {
        final isSelected = _position == pos;
        return OnzeSelectChip(
          label: pos.label,
          isSelected: isSelected,
          onTap: () => setState(() => _position = pos),
        );
      }).toList(),
    );
  }

  Widget _buildFootSelector() {
    return Wrap(
      spacing: 8,
      children: DominantFoot.values.map((foot) {
        final isSelected = _dominantFoot == foot;
        return OnzeSelectChip(
          label: foot.label,
          isSelected: isSelected,
          onTap: () => setState(() => _dominantFoot = foot),
        );
      }).toList(),
    );
  }

  Widget _buildExperienceSelector() {
    return Wrap(
      spacing: 8,
      children: ExperienceLevel.values.map((level) {
        final isSelected = _experience == level;
        return OnzeSelectChip(
          label: level.label,
          isSelected: isSelected,
          onTap: () => setState(() => _experience = level),
        );
      }).toList(),
    );
  }

  Widget _buildErrorBanner(String message) {
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

