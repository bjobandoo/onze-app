import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/errors/onze_exception.dart';
import '../../../../core/theme/onze_colors.dart';
import '../../../../features/auth/data/auth_repository_impl.dart';
import '../../../../features/auth/presentation/providers/auth_providers.dart';
import '../../../../shared/models/app_user.dart';
import '../../../../shared/models/player_enums.dart';
import '../../../../shared/widgets/onze_button.dart';
import '../../../../shared/widgets/onze_select_chip.dart';
import '../../../../shared/widgets/onze_text_field.dart';
import '../../domain/models/player_profile.dart';
import '../providers/profile_providers.dart';

/// Datos necesarios para pre-poblar el formulario.
/// Se reciben desde [ProfileScreen] vía GoRouter extra.
class EditProfileArgs {
  const EditProfileArgs({required this.user, this.profile});
  final AppUser user;
  final PlayerProfile? profile;
}

/// Pantalla de edición del perfil del jugador.
class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key, required this.args});

  final EditProfileArgs args;

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  late final TextEditingController _nameController;
  late final TextEditingController _usernameController;
  late final TextEditingController _bioController;
  late PlayerPosition _position;
  late DominantFoot _dominantFoot;
  late ExperienceLevel _experience;

  bool _isLoading = false;
  String? _nameError;
  String? _usernameError;
  String? _globalError;

  // Límite de bio
  static const int _bioMaxLength = 300;

  @override
  void initState() {
    super.initState();
    final user = widget.args.user;
    final profile = widget.args.profile;

    _nameController = TextEditingController(text: user.fullName);
    _usernameController = TextEditingController(text: user.username ?? '');
    _bioController = TextEditingController(text: profile?.bio ?? '');
    _position = profile?.position ?? PlayerPosition.mediocampista;
    _dominantFoot = profile?.dominantFoot ?? DominantFoot.derecho;
    _experience = profile?.experienceLevel ?? ExperienceLevel.intermedio;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _usernameController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Validación
  // ---------------------------------------------------------------------------

  String? _validateName(String value) {
    if (value.trim().isEmpty) return 'Ingresa tu nombre';
    if (value.trim().length < 3) {
      return 'El nombre debe tener al menos 3 caracteres';
    }
    if (value.trim().length > 80) {
      return 'El nombre no puede superar 80 caracteres';
    }
    return null;
  }

  bool get _hasChanges {
    final user = widget.args.user;
    final profile = widget.args.profile;
    return _nameController.text.trim() != user.fullName ||
        _usernameController.text.trim().toLowerCase() != (user.username ?? '') ||
        _bioController.text.trim() != (profile?.bio ?? '') ||
        _position != (profile?.position ?? PlayerPosition.mediocampista) ||
        _dominantFoot != (profile?.dominantFoot ?? DominantFoot.derecho) ||
        _experience != (profile?.experienceLevel ?? ExperienceLevel.intermedio);
  }

  // ---------------------------------------------------------------------------
  // Guardar
  // ---------------------------------------------------------------------------

  Future<void> _save() async {
    final nameError = _validateName(_nameController.text);
    final newUsername = _usernameController.text.trim().toLowerCase();
    String? usernameErr;

    if (newUsername.isNotEmpty &&
        !RegExp(r'^[a-z0-9_]{3,20}$').hasMatch(newUsername)) {
      usernameErr = 'Solo letras minúsculas, números y _ (3–20 caracteres)';
    }

    if (nameError != null || usernameErr != null) {
      setState(() {
        _nameError = nameError;
        _usernameError = usernameErr;
      });
      return;
    }

    setState(() {
      _nameError = null;
      _usernameError = null;
      _globalError = null;
      _isLoading = true;
    });

    try {
      // Comprobar disponibilidad solo si el username cambió
      final currentUsername = widget.args.user.username ?? '';
      if (newUsername.isNotEmpty && newUsername != currentUsername) {
        final available =
            await AuthRepositoryImpl().isUsernameAvailable(newUsername);
        if (!available) {
          setState(() {
            _usernameError =
                'Ese nombre de usuario ya está en uso. Elige otro.';
            _isLoading = false;
          });
          return;
        }
      }

      final userId = widget.args.user.id;
      await ref.read(profileRepositoryProvider).updateProfile(
            userId: userId,
            fullName: _nameController.text.trim(),
            username: newUsername.isNotEmpty ? newUsername : null,
            bio: _bioController.text.trim(),
            position: _position,
            dominantFoot: _dominantFoot,
            experienceLevel: _experience,
          );

      // Invalida los providers para que se recarguen con los nuevos datos
      ref.invalidate(currentUserProvider);
      ref.invalidate(myProfileProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Perfil actualizado correctamente'),
            backgroundColor: OnzeColors.accent,
          ),
        );
        context.pop();
      }
    } on OnzeException catch (e) {
      setState(() => _globalError = e.message);
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
        title: const Text('Editar perfil'),
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _save,
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
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 24),
            _buildNameField(),
            const SizedBox(height: 16),
            _buildUsernameField(),
            const SizedBox(height: 32),
            _buildBioField(),
            const SizedBox(height: 32),
            _buildSectionTitle('Posición en el campo'),
            const SizedBox(height: 12),
            _buildPositionSelector(),
            const SizedBox(height: 32),
            _buildSectionTitle('Pie hábil'),
            const SizedBox(height: 12),
            _buildFootSelector(),
            const SizedBox(height: 32),
            _buildSectionTitle('Nivel de experiencia'),
            const SizedBox(height: 12),
            _buildExperienceSelector(),
            if (_globalError != null) ...[
              const SizedBox(height: 24),
              _buildErrorBanner(_globalError!),
            ],
            const SizedBox(height: 40),
            OnzeButton(
              label: 'Guardar cambios',
              onPressed: (_isLoading || !_hasChanges) ? null : _save,
              isLoading: _isLoading,
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Secciones del formulario
  // ---------------------------------------------------------------------------

  Widget _buildNameField() {
    return OnzeTextField(
      label: 'Nombre completo',
      controller: _nameController,
      hint: 'Ej: Carlos Pérez',
      errorText: _nameError,
      keyboardType: TextInputType.name,
      textInputAction: TextInputAction.next,
      onChanged: (_) {
        if (_nameError != null) setState(() => _nameError = null);
        setState(() {}); // actualiza _hasChanges
      },
    );
  }

  Widget _buildUsernameField() {
    return OnzeTextField(
      label: 'Nombre de usuario',
      controller: _usernameController,
      hint: 'Ej: carlos_10',
      errorText: _usernameError,
      keyboardType: TextInputType.text,
      textInputAction: TextInputAction.next,
      onChanged: (v) {
        final lower = v.toLowerCase();
        if (v != lower) {
          _usernameController.value = TextEditingValue(
            text: lower,
            selection: TextSelection.collapsed(offset: lower.length),
          );
        }
        if (_usernameError != null) setState(() => _usernameError = null);
        setState(() {}); // actualiza _hasChanges
      },
    );
  }

  Widget _buildBioField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        OnzeTextField(
          label: 'Sobre mí',
          controller: _bioController,
          hint: 'Cuéntanos algo de ti como jugador...',
          maxLines: 4,
          textInputAction: TextInputAction.newline,
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 4),
        Align(
          alignment: Alignment.centerRight,
          child: Text(
            '${_bioController.text.length}/$_bioMaxLength',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: _bioController.text.length > _bioMaxLength
                      ? OnzeColors.error
                      : OnzeColors.textSecondary,
                ),
          ),
        ),
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
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
        return OnzeSelectChip(
          label: pos.label,
          isSelected: _position == pos,
          onTap: () => setState(() => _position = pos),
        );
      }).toList(),
    );
  }

  Widget _buildFootSelector() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: DominantFoot.values.map((foot) {
        return OnzeSelectChip(
          label: foot.label,
          isSelected: _dominantFoot == foot,
          onTap: () => setState(() => _dominantFoot = foot),
        );
      }).toList(),
    );
  }

  Widget _buildExperienceSelector() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: ExperienceLevel.values.map((level) {
        return OnzeSelectChip(
          label: level.label,
          isSelected: _experience == level,
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
        borderRadius: BorderRadius.circular(12),
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
