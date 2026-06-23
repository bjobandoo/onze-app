// Pantalla de registro de una nueva cancha.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/theme/onze_colors.dart';
import '../../../../shared/widgets/onze_button.dart';
import '../../domain/models/field_enums.dart';
import '../providers/fields_providers.dart';
import 'location_picker_screen.dart';

/// Pantalla con formulario completo para registrar una cancha nueva.
/// La cancha queda con [verified = false] esperando aprobación del admin.
class RegisterFieldScreen extends ConsumerStatefulWidget {
  const RegisterFieldScreen({super.key});

  @override
  ConsumerState<RegisterFieldScreen> createState() =>
      _RegisterFieldScreenState();
}

class _RegisterFieldScreenState extends ConsumerState<RegisterFieldScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _addressController = TextEditingController();

  FieldType _fieldType = FieldType.v5x5;
  LatLng? _location;
  final List<XFile> _photos = [];
  final _picker = ImagePicker();

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
    if (_photos.length >= 5) return;
    final file = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1200,
      maxHeight: 900,
      imageQuality: 80,
    );
    if (file != null) setState(() => _photos.add(file));
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

    // Leer bytes de todas las fotos antes de pasar al notifier
    final photoBytes = <List<int>>[];
    for (final file in _photos) {
      photoBytes.add(await file.readAsBytes());
    }

    await ref.read(registerFieldProvider.notifier).register(
          name: _nameController.text,
          description: _descriptionController.text.trim().isEmpty
              ? null
              : _descriptionController.text,
          address: _addressController.text,
          latitude: _location!.latitude,
          longitude: _location!.longitude,
          fieldType: _fieldType,
          photoBytes: photoBytes,
        );

    if (!mounted) return;
    final state = ref.read(registerFieldProvider);

    if (state.success) {
      ref.invalidate(myFieldsProvider);
      final extra = state.photoUploadErrors > 0
          ? ' (${state.photoUploadErrors} foto(s) no se pudieron subir)'
          : '';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              '¡Cancha registrada! Está pendiente de verificación.$extra'),
          backgroundColor: OnzeColors.accent,
        ),
      );
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
    final isLoading = ref.watch(registerFieldProvider).isLoading;

    return Scaffold(
      appBar: AppBar(title: const Text('Registrar cancha')),
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
                label: 'Registrar cancha',
                onPressed: isLoading ? null : _submit,
                isLoading: isLoading,
                icon: Icons.add_location_alt_outlined,
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
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
            if (v == null || v.trim().isEmpty) {
              return 'La dirección es obligatoria';
            }
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
                color: isSelected
                    ? OnzeColors.accent
                    : OnzeColors.border,
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
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: OnzeColors.accent.withValues(alpha: 0.4)),
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
          label: Text(
            _location == null ? 'Seleccionar en mapa' : 'Cambiar ubicación',
          ),
          style: OutlinedButton.styleFrom(
            foregroundColor: OnzeColors.accent,
            side: const BorderSide(color: OnzeColors.accent),
          ),
        ),
      ],
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
              '(${_photos.length}/5)',
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
              ..._photos.asMap().entries.map(
                    (entry) => _PhotoThumbnail(
                      file: entry.value,
                      onRemove: () =>
                          setState(() => _photos.removeAt(entry.key)),
                    ),
                  ),
              if (_photos.length < 5) _AddPhotoButton(onTap: _pickPhoto),
            ],
          ),
        ),
      ],
    );
  }
}

class _PhotoThumbnail extends StatelessWidget {
  const _PhotoThumbnail({required this.file, required this.onRemove});
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
            borderRadius: BorderRadius.circular(12),
            color: OnzeColors.surface,
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
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: OnzeColors.accent.withValues(alpha: 0.4),
              style: BorderStyle.solid),
        ),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_photo_alternate_outlined,
                color: OnzeColors.accent, size: 28),
            SizedBox(height: 4),
            Text(
              'Agregar',
              style: TextStyle(
                color: OnzeColors.accent,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
