import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/errors/onze_exception.dart';
import '../../../../core/theme/onze_colors.dart';
import '../../../../shared/widgets/onze_avatar.dart';
import '../providers/profile_providers.dart';

/// Límite de tamaño de imagen: 5 MB.
const _maxImageBytes = 5 * 1024 * 1024;

/// Avatar interactivo que permite al usuario cambiar o eliminar su foto.
///
/// Muestra [OnzeAvatar] con un ícono de cámara superpuesto. Al tocar abre
/// un bottom sheet con opciones: galería, cámara, o eliminar foto.
/// Tras cada operación llama a [onAvatarChanged] para que el padre recargue datos.
class ProfileAvatarPicker extends ConsumerStatefulWidget {
  const ProfileAvatarPicker({
    super.key,
    required this.userId,
    this.imageUrl,
    this.name,
    this.radius = 48,
    this.onAvatarChanged,
  });

  final String userId;
  final String? imageUrl;
  final String? name;
  final double radius;

  /// Se invoca después de subir o eliminar el avatar con éxito.
  final VoidCallback? onAvatarChanged;

  @override
  ConsumerState<ProfileAvatarPicker> createState() =>
      _ProfileAvatarPickerState();
}

class _ProfileAvatarPickerState extends ConsumerState<ProfileAvatarPicker> {
  bool _isLoading = false;
  final _picker = ImagePicker();

  // ---------------------------------------------------------------------------
  // Acciones
  // ---------------------------------------------------------------------------

  Future<void> _pickImage(ImageSource source) async {
    // Cerrar el bottom sheet antes de abrir el selector nativo
    if (mounted) Navigator.of(context).pop();

    final XFile? file = await _picker.pickImage(
      source: source,
      maxWidth: 800,
      maxHeight: 800,
      imageQuality: 85,
    );
    if (file == null) return; // usuario canceló

    final Uint8List bytes = await file.readAsBytes();

    if (bytes.lengthInBytes > _maxImageBytes) {
      _showError('La imagen no puede superar 5 MB.');
      return;
    }

    await _upload(bytes);
  }

  Future<void> _upload(Uint8List bytes) async {
    setState(() => _isLoading = true);
    try {
      await ref.read(profileRepositoryProvider).uploadAvatar(
            widget.userId,
            bytes,
          );
      widget.onAvatarChanged?.call();
    } on OnzeException catch (e) {
      _showError(e.message);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _removeAvatar() async {
    if (mounted) Navigator.of(context).pop();
    setState(() => _isLoading = true);
    try {
      await ref.read(profileRepositoryProvider).removeAvatar(widget.userId);
      widget.onAvatarChanged?.call();
    } on OnzeException catch (e) {
      _showError(e.message);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: OnzeColors.error,
      ),
    );
  }

  void _showOptions() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: OnzeColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => _AvatarOptionsSheet(
        hasPhoto:
            widget.imageUrl != null && widget.imageUrl!.isNotEmpty,
        onGallery: () => _pickImage(ImageSource.gallery),
        onCamera: () => _pickImage(ImageSource.camera),
        onRemove: _removeAvatar,
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _isLoading ? null : _showOptions,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          _buildAvatar(),
          Positioned(
            bottom: 0,
            right: 0,
            child: _buildCameraButton(),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatar() {
    if (_isLoading) {
      return CircleAvatar(
        radius: widget.radius,
        backgroundColor: OnzeColors.surface,
        child: SizedBox(
          width: widget.radius,
          height: widget.radius,
          child: const CircularProgressIndicator(
            strokeWidth: 2,
            color: OnzeColors.highlight,
          ),
        ),
      );
    }

    return OnzeAvatar(
      imageUrl: widget.imageUrl,
      name: widget.name,
      radius: widget.radius,
    );
  }

  Widget _buildCameraButton() {
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: _isLoading ? OnzeColors.surface : OnzeColors.accent,
        shape: BoxShape.circle,
        border: Border.all(color: OnzeColors.background, width: 2),
      ),
      child: Icon(
        Icons.camera_alt,
        size: 14,
        color: _isLoading ? OnzeColors.textSecondary : OnzeColors.textPrimary,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Bottom sheet de opciones
// ---------------------------------------------------------------------------

class _AvatarOptionsSheet extends StatelessWidget {
  const _AvatarOptionsSheet({
    required this.hasPhoto,
    required this.onGallery,
    required this.onCamera,
    required this.onRemove,
  });

  final bool hasPhoto;
  final VoidCallback onGallery;
  final VoidCallback onCamera;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle visual
          Container(
            width: 36,
            height: 4,
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            decoration: BoxDecoration(
              color: OnzeColors.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              'Foto de perfil',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontSize: 16,
                  ),
            ),
          ),
          ListTile(
            leading: const Icon(
              Icons.photo_library_outlined,
              color: OnzeColors.textPrimary,
            ),
            title: const Text('Elegir de la galería'),
            onTap: onGallery,
          ),
          ListTile(
            leading: const Icon(
              Icons.camera_alt_outlined,
              color: OnzeColors.textPrimary,
            ),
            title: const Text('Tomar una foto'),
            onTap: onCamera,
          ),
          if (hasPhoto) ...[
            const Divider(height: 1, indent: 16, endIndent: 16),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: OnzeColors.error),
              title: const Text(
                'Eliminar foto',
                style: TextStyle(color: OnzeColors.error),
              ),
              onTap: onRemove,
            ),
          ],
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
