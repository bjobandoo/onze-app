// Widget selector de escudo de equipo.
//
// Modo local (CreateTeamScreen): muestra preview de bytes elegidos, llama
// [onImagePicked] con los bytes — el padre decide cuándo subir.
//
// Modo remoto (EditTeamScreen): muestra [imageUrl] existente y además acepta
// bytes locales como preview antes de guardar.

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/theme/onze_colors.dart';
import '../../../../shared/widgets/onze_avatar.dart';

/// Límite de tamaño: 5 MB.
const _maxImageBytes = 5 * 1024 * 1024;

/// Selector de escudo de equipo con preview local.
///
/// Muestra el escudo actual ([imageUrl]) o los bytes elegidos localmente
/// ([localBytes]). Al tocar abre un bottom sheet para elegir fuente.
/// Llama [onImagePicked] con los bytes tras la selección, o [onRemove] si
/// el usuario elige quitar la foto.
class TeamShieldPicker extends StatefulWidget {
  const TeamShieldPicker({
    super.key,
    this.imageUrl,
    this.localBytes,
    this.radius = 52,
    required this.onImagePicked,
    this.onRemove,
  });

  final String? imageUrl;
  final Uint8List? localBytes;
  final double radius;

  /// Llamado con los bytes de la imagen elegida.
  final ValueChanged<Uint8List> onImagePicked;

  /// Llamado cuando el usuario elige "Eliminar foto". Puede ser null si no
  /// se quiere ofrecer esa opción.
  final VoidCallback? onRemove;

  @override
  State<TeamShieldPicker> createState() => _TeamShieldPickerState();
}

class _TeamShieldPickerState extends State<TeamShieldPicker> {
  final _picker = ImagePicker();

  Future<void> _pickImage(ImageSource source) async {
    if (mounted) Navigator.of(context).pop();

    final XFile? file = await _picker.pickImage(
      source: source,
      maxWidth: 800,
      maxHeight: 800,
      imageQuality: 85,
    );
    if (file == null) return;

    final bytes = await file.readAsBytes();
    if (bytes.lengthInBytes > _maxImageBytes) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('La imagen no puede superar 5 MB.'),
          backgroundColor: OnzeColors.error,
        ),
      );
      return;
    }
    widget.onImagePicked(bytes);
  }

  void _showOptions() {
    final hasPhoto = widget.localBytes != null ||
        (widget.imageUrl != null && widget.imageUrl!.isNotEmpty);

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: OnzeColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => _ShieldOptionsSheet(
        hasPhoto: hasPhoto,
        onGallery: () => _pickImage(ImageSource.gallery),
        onCamera: () => _pickImage(ImageSource.camera),
        onRemove: widget.onRemove != null
            ? () {
                Navigator.of(context).pop();
                widget.onRemove!();
              }
            : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _showOptions,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          _buildShield(),
          Positioned(
            bottom: 0,
            right: 0,
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: OnzeColors.accent,
                shape: BoxShape.circle,
                border: Border.all(color: OnzeColors.background, width: 2),
              ),
              child: const Icon(Icons.camera_alt, size: 16,
                  color: OnzeColors.textPrimary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShield() {
    if (widget.localBytes != null) {
      return CircleAvatar(
        radius: widget.radius,
        backgroundImage: MemoryImage(widget.localBytes!),
        backgroundColor: OnzeColors.surface,
      );
    }
    return OnzeAvatar(
      imageUrl: widget.imageUrl,
      name: '?',
      radius: widget.radius,
    );
  }
}

// ---------------------------------------------------------------------------
// Bottom sheet
// ---------------------------------------------------------------------------

class _ShieldOptionsSheet extends StatelessWidget {
  const _ShieldOptionsSheet({
    required this.hasPhoto,
    required this.onGallery,
    required this.onCamera,
    this.onRemove,
  });

  final bool hasPhoto;
  final VoidCallback onGallery;
  final VoidCallback onCamera;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
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
              'Escudo del equipo',
              style: Theme.of(context)
                  .textTheme
                  .headlineMedium
                  ?.copyWith(fontSize: 16),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.photo_library_outlined,
                color: OnzeColors.textPrimary),
            title: const Text('Elegir de la galería'),
            onTap: onGallery,
          ),
          ListTile(
            leading: const Icon(Icons.camera_alt_outlined,
                color: OnzeColors.textPrimary),
            title: const Text('Tomar una foto'),
            onTap: onCamera,
          ),
          if (hasPhoto && onRemove != null) ...[
            const Divider(height: 1, indent: 16, endIndent: 16),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: OnzeColors.error),
              title: const Text('Quitar escudo',
                  style: TextStyle(color: OnzeColors.error)),
              onTap: onRemove,
            ),
          ],
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
