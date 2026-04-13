// Pantalla de selección de ubicación en mapa para registro de cancha.

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/theme/onze_colors.dart';
import '../../../../shared/widgets/onze_button.dart';

/// Coordenadas del centro de Ibarra, Ecuador.
const _ibarraCenter = LatLng(0.3516, -78.1221);

/// Pantalla de mapa a pantalla completa para que el dueño seleccione
/// la ubicación exacta de su cancha tocando el mapa.
///
/// Retorna un [LatLng] al hacer pop, o null si el usuario cancela.
class LocationPickerScreen extends StatefulWidget {
  const LocationPickerScreen({super.key, this.initialLocation});

  /// Ubicación inicial si ya había una seleccionada previamente.
  final LatLng? initialLocation;

  @override
  State<LocationPickerScreen> createState() => _LocationPickerScreenState();
}

class _LocationPickerScreenState extends State<LocationPickerScreen> {
  late LatLng? _selected;

  @override
  void initState() {
    super.initState();
    _selected = widget.initialLocation;
  }

  void _onTap(TapPosition _, LatLng point) {
    setState(() => _selected = point);
  }

  void _confirm() {
    if (_selected == null) return;
    Navigator.of(context).pop(_selected);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ubicación de la cancha'),
        actions: [
          if (_selected != null)
            TextButton(
              onPressed: _confirm,
              child: const Text(
                'Confirmar',
                style: TextStyle(color: OnzeColors.highlight),
              ),
            ),
        ],
      ),
      body: Stack(
        children: [
          FlutterMap(
            options: MapOptions(
              initialCenter: widget.initialLocation ?? _ibarraCenter,
              initialZoom: 15.0,
              onTap: _onTap,
            ),
            children: [
              TileLayer(
                urlTemplate:
                    'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.onze.app',
              ),
              if (_selected != null)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: _selected!,
                      child: const Icon(
                        Icons.location_pin,
                        color: OnzeColors.highlight,
                        size: 48,
                      ),
                    ),
                  ],
                ),
            ],
          ),
          // Instrucción flotante en la parte inferior
          Positioned(
            bottom: 16,
            left: 16,
            right: 16,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_selected != null)
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: OnzeColors.surface,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: OnzeColors.border),
                    ),
                    child: Text(
                      'Lat: ${_selected!.latitude.toStringAsFixed(6)}'
                      '  Lng: ${_selected!.longitude.toStringAsFixed(6)}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: OnzeColors.textSecondary,
                          ),
                    ),
                  ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: OnzeColors.surface.withValues(alpha: 0.92),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Toca el mapa para marcar la ubicación de tu cancha',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: OnzeColors.textSecondary,
                        ),
                    textAlign: TextAlign.center,
                  ),
                ),
                if (_selected != null) ...[
                  const SizedBox(height: 12),
                  OnzeButton(
                    label: 'Confirmar ubicación',
                    onPressed: _confirm,
                    icon: Icons.check,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
