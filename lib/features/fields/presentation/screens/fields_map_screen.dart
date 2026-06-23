// Pantalla de mapa de canchas verificadas en Ibarra.

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/theme/onze_colors.dart';
import '../../domain/models/field.dart';
import '../providers/fields_providers.dart';
import '../widgets/field_detail_sheet.dart';

/// Centro de Ibarra, Ecuador.
const _ibarraCenter = LatLng(0.3516, -78.1221);

/// Pantalla principal del mapa: muestra las canchas verificadas sobre un mapa
/// de OpenStreetMap. Al tocar un marcador se despliega un panel inferior con
/// la información de la cancha y sus horarios disponibles.
class FieldsMapScreen extends ConsumerStatefulWidget {
  const FieldsMapScreen({super.key});

  @override
  ConsumerState<FieldsMapScreen> createState() => _FieldsMapScreenState();
}

class _FieldsMapScreenState extends ConsumerState<FieldsMapScreen> {
  final _mapController = MapController();

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  void _onMarkerTap(Field field) {
    _mapController.move(
      LatLng(field.latitude, field.longitude),
      16.0,
    );
    showFieldDetailSheet(context, field);
  }

  @override
  Widget build(BuildContext context) {
    final fieldsAsync = ref.watch(verifiedFieldsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Canchas disponibles'),
        actions: [
          IconButton(
            icon: const Icon(Icons.my_location_outlined),
            tooltip: 'Centrar en Ibarra',
            onPressed: () =>
                _mapController.move(_ibarraCenter, 13.0),
          ),
        ],
      ),
      body: fieldsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: OnzeColors.accent)),
        error: (e, _) => _ErrorView(message: e.toString()),
        data: (fields) => Stack(
          children: [
            FlutterMap(
              mapController: _mapController,
              options: const MapOptions(
                initialCenter: _ibarraCenter,
                initialZoom: 13.0,
                minZoom: 10.0,
                maxZoom: 18.0,
              ),
              children: [
                TileLayer(
                  urlTemplate:
                      'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.onze.app',
                ),
                MarkerLayer(
                  markers: [
                    for (final field in fields)
                      Marker(
                        point: LatLng(field.latitude, field.longitude),
                        width: 52,
                        height: 52,
                        child: GestureDetector(
                          onTap: () => _onMarkerTap(field),
                          child: const _FieldMarkerIcon(),
                        ),
                      ),
                  ],
                ),
              ],
            ),
            if (fields.isEmpty)
              const Positioned.fill(child: _EmptyOverlay()),
            Positioned(
              bottom: 16,
              right: 16,
              child: _FieldCountBadge(count: fields.length),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Icono del marcador
// ---------------------------------------------------------------------------

class _FieldMarkerIcon extends StatelessWidget {
  const _FieldMarkerIcon();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: OnzeColors.primary,
        shape: BoxShape.circle,
        border: Border.all(color: OnzeColors.highlight, width: 2),
        boxShadow: const [
          BoxShadow(
            color: Colors.black54,
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: const Center(
        child: Text(
          '⚽',
          style: TextStyle(fontSize: 20),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Badge de cantidad
// ---------------------------------------------------------------------------

class _FieldCountBadge extends StatelessWidget {
  const _FieldCountBadge({required this.count});
  final int count;

  @override
  Widget build(BuildContext context) {
    if (count == 0) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: OnzeColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: OnzeColors.border),
      ),
      child: Text(
        '$count ${count == 1 ? 'cancha' : 'canchas'}',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: OnzeColors.textSecondary,
            ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Overlay cuando no hay canchas
// ---------------------------------------------------------------------------

class _EmptyOverlay extends StatelessWidget {
  const _EmptyOverlay();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Center(
        child: Container(
          margin: const EdgeInsets.all(32),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: OnzeColors.surface.withValues(alpha: 0.92),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Text(
            'Aún no hay canchas verificadas en Ibarra.\nVuelve pronto.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: OnzeColors.textSecondary,
                ),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          message,
          style: Theme.of(context)
              .textTheme
              .bodyMedium
              ?.copyWith(color: OnzeColors.error),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
