// Pantalla de edición de una cancha existente.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/theme/onze_colors.dart';
import '../../../../shared/widgets/onze_button.dart';
import '../../domain/models/field.dart';
import '../../domain/models/field_enums.dart';
import '../providers/fields_providers.dart';
import 'location_picker_screen.dart';

/// Pantalla de edición de nombre, descripción, dirección, tipo, ubicación
/// y fotos de una cancha ya registrada.
class EditFieldScreen extends ConsumerStatefulWidget {
  const EditFieldScreen({super.key, required this.field});

  final Field field;

  @override
  ConsumerState<EditFieldScreen> createState() => _EditFieldScreenState();
}

class _EditFieldScreenState extends ConsumerState<EditFieldScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _addressController = TextEditingController();
  final _picker = ImagePicker();

  late FieldType _fieldType;
  LatLng? _location;

  /// URLs de fotos existentes que el usuario NO ha eliminado.
  late List<String> _keptPhotos;

  /// Fotos nuevas seleccionadas desde galería.
  final List<XFile> _newPhotos = [];

  int get _totalPhotos => _keptPhotos.length + _newPhotos.length;

  @override
  void initState() {
    super.initState();
    final f = widget.field;
    _nameController.text = f.name;
    _descriptionController.text = f.description ?? '';
    _addressController.text = f.address;
    _fieldType = f.fieldType;
    _location = LatLng(f.latitude, f.longitude);
    _keptPhotos = List.of(f.photos);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _openLocationPicker() async {
    final result = await Navigator.of(context).push<LatLng>(
      MaterialPageRoute(
        builder: (_) => LocationPickerScreen(initialLocation: _location),
      ),
    );
    if (result != null) setState(() => _location = result);
  }

  Future<void> _pickPhoto() async {
    if (_totalPhotos >= 5) return;
    final file = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1200,
      maxHeight: 900,
      imageQuality: 80,
    );
    if (file != null) setState(() => _newPhotos.add(file));
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_location == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Selecciona la ubicación de la cancha en el mapa.'),
          backgroundColor: OnzeColors.error,
        ),
      );
      return;
    }

    // Leer bytes de fotos nuevas antes de pasar al notifier
    final newPhotoBytes = <List<int>>[];
    for (final file in _newPhotos) {
      newPhotoBytes.add(await file.readAsBytes());
    }

    await ref.read(editFieldProvider.notifier).update(
          fieldId: widget.field.id,
          name: _nameController.text,
          description: _descriptionController.text.trim().isEmpty
              ? null
              : _descriptionController.text,
          address: _addressController.text,
          latitude: _location!.latitude,
          longitude: _location!.longitude,
          fieldType: _fieldType,
          keptPhotoUrls: _keptPhotos,
          newPhotoBytes: newPhotoBytes,
        );

    if (!mounted) return;
    final state = ref.read(editFieldProvider);

    if (state.success) {
      ref.invalidate(myFieldsProvider);
      ref.invalidate(verifiedFieldsProvider);
      final extra = state.photoUploadErrors > 0
          ? ' (${state.photoUploadErrors} foto(s) no se pudieron subir)'
          : '';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Cancha actualizada correctamente.$extra'),
          backgroundColor: OnzeColors.accent,
        ),
      );
      Navigator.of(context).pop(state.field);
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
    final isLoading = ref.watch(editFieldProvider).isLoading;

    return Scaffold(
      appBar: AppBar(title: const Text('Editar cancha')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 8),
              _buildPhotosSection(),
              const SizedBox(height: 24),
              _buildBasicInfoSection(context),
              const SizedBox(height: 24),
              _buildFieldTypeSection(context),
              const SizedBox(height: 24),
              _buildLocationSection(context),
              const SizedBox(height: 32),
              OnzeButton(
                label: 'Guardar cambios',
                onPressed: isLoading ? null : _submit,
                isLoading: isLoading,
                icon: Icons.save_outlined,
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPhotosSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text('Fotos'),
            const SizedBox(width: 8),
            Text(
              '($_totalPhotos/5)',
              style: const TextStyle(color: OnzeColors.textSecondary),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 100,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              // Fotos existentes conservadas
              ..._keptPhotos.asMap().entries.map(
                    (entry) => _ExistingPhotoThumbnail(
                      url: entry.value,
                      onRemove: () =>
                          setState(() => _keptPhotos.removeAt(entry.key)),
                    ),
                  ),
              // Fotos nuevas seleccionadas
              ..._newPhotos.asMap().entries.map(
                    (entry) => _NewPhotoThumbnail(
                      file: entry.value,
                      onRemove: () =>
                          setState(() => _newPhotos.removeAt(entry.key)),
                    ),
                  ),
              if (_totalPhotos < 5) _AddPhotoButton(onTap: _pickPhoto),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBasicInfoSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Información básica',
            style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 16),
        TextFormField(
          controller: _nameController,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            labelText: 'Nombre de la cancha',
            hintText: 'Ej: Cancha Los Pinos N°1',
          ),
          validator: (v) {
            if (v == null || v.trim().isEmpty) return 'El nombre es obligatorio';
            if (v.trim().length < 3) return 'Mínimo 3 caracteres';
            return null;
          },
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _descriptionController,
          maxLines: 3,
          maxLength: 300,
          decoration: const InputDecoration(
            labelText: 'Descripción (opcional)',
            hintText: 'Ej: Cancha de césped sintético con iluminación LED…',
            alignLabelWithHint: true,
          ),
        ),
        TextFormField(
          controller: _addressController,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            labelText: 'Dirección',
            hintText: 'Ej: Av. Teodoro Gómez de la Torre y Juan de Velasco',
          ),
          validator: (v) {
            if (v == null || v.trim().isEmpty) return 'La dirección es obligatoria';
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildFieldTypeSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Tipo de cancha',
            style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          children: FieldType.values.map((type) {
            final isSelected = type == _fieldType;
            return ChoiceChip(
              label: Text(type.label),
              selected: isSelected,
              onSelected: (_) => setState(() => _fieldType = type),
              selectedColor: OnzeColors.accent.withValues(alpha: 0.25),
              labelStyle: TextStyle(
                color: isSelected
                    ? OnzeColors.highlight
                    : OnzeColors.textSecondary,
                fontWeight:
                    isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
              side: BorderSide(
                color: isSelected ? OnzeColors.accent : OnzeColors.border,
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildLocationSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Ubicación en mapa',
            style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 12),
        if (_location != null) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: OnzeColors.surface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                  color: OnzeColors.accent.withValues(alpha: 0.4)),
            ),
            child: Row(
              children: [
                const Icon(Icons.location_on,
                    color: OnzeColors.highlight, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Lat: ${_location!.latitude.toStringAsFixed(5)}'
                    '  Lng: ${_location!.longitude.toStringAsFixed(5)}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: OnzeColors.textSecondary,
                        ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
        ],
        OutlinedButton.icon(
          onPressed: _openLocationPicker,
          icon: const Icon(Icons.map_outlined),
          label: const Text('Cambiar ubicación'),
          style: OutlinedButton.styleFrom(
            foregroundColor: OnzeColors.accent,
            side: const BorderSide(color: OnzeColors.accent),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Thumbnails
// ---------------------------------------------------------------------------

class _ExistingPhotoThumbnail extends StatelessWidget {
  const _ExistingPhotoThumbnail({required this.url, required this.onRemove});

  final String url;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          width: 100,
          height: 100,
          margin: const EdgeInsets.only(right: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            color: OnzeColors.surface,
          ),
          clipBehavior: Clip.antiAlias,
          child: Image.network(
            url,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => const Center(
              child: Icon(Icons.broken_image_outlined,
                  color: OnzeColors.textSecondary, size: 28),
            ),
          ),
        ),
        Positioned(
          top: 4,
          right: 12,
          child: GestureDetector(
            onTap: onRemove,
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: const BoxDecoration(
                color: OnzeColors.error,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.close, size: 14, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }
}

class _NewPhotoThumbnail extends StatelessWidget {
  const _NewPhotoThumbnail({required this.file, required this.onRemove});

  final XFile file;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          width: 100,
          height: 100,
          margin: const EdgeInsets.only(right: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            color: OnzeColors.surface,
            border: Border.all(
                color: OnzeColors.accent.withValues(alpha: 0.5), width: 1.5),
          ),
          clipBehavior: Clip.antiAlias,
          child: Image.file(
            File(Uri.parse(file.path).toFilePath()),
            fit: BoxFit.cover,
          ),
        ),
        Positioned(
          top: 4,
          right: 12,
          child: GestureDetector(
            onTap: onRemove,
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: const BoxDecoration(
                color: OnzeColors.error,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.close, size: 14, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }
}

class _AddPhotoButton extends StatelessWidget {
  const _AddPhotoButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 100,
        height: 100,
        decoration: BoxDecoration(
          color: OnzeColors.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: OnzeColors.accent.withValues(alpha: 0.4),
          ),
        ),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_photo_alternate_outlined,
                color: OnzeColors.accent, size: 28),
            SizedBox(height: 4),
            Text(
              'Agregar',
              style: TextStyle(color: OnzeColors.accent, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}
