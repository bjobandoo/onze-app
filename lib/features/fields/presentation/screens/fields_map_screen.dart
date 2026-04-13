// Pantalla de mapa de canchas verificadas en Ibarra.

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/theme/onze_colors.dart';
import '../../domain/models/field.dart';
import '../../domain/models/field_schedule.dart';
import '../providers/fields_providers.dart';

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
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: OnzeColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => _FieldBottomSheet(field: field),
    );
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
            borderRadius: BorderRadius.circular(12),
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

// ---------------------------------------------------------------------------
// Panel inferior de la cancha
// ---------------------------------------------------------------------------

class _FieldBottomSheet extends ConsumerWidget {
  const _FieldBottomSheet({required this.field});
  final Field field;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final schedulesAsync = ref.watch(fieldSchedulesProvider(field.id));

    return DraggableScrollableSheet(
      initialChildSize: 0.45,
      minChildSize: 0.3,
      maxChildSize: 0.85,
      expand: false,
      builder: (_, controller) => ListView(
        controller: controller,
        padding: EdgeInsets.zero,
        children: [
          _buildHandle(),
          _buildPhoto(),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(context),
                const SizedBox(height: 4),
                Text(
                  field.address,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: OnzeColors.textSecondary,
                      ),
                ),
                const SizedBox(height: 16),
                _buildSchedulesSection(context, schedulesAsync),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHandle() {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 10),
        width: 36,
        height: 4,
        decoration: BoxDecoration(
          color: OnzeColors.border,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }

  Widget _buildPhoto() {
    final url = field.firstPhotoUrl;
    return ClipRRect(
      borderRadius: BorderRadius.zero,
      child: SizedBox(
        height: 160,
        width: double.infinity,
        child: url != null
            ? Image.network(
                url,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => _PhotoPlaceholder(),
              )
            : _PhotoPlaceholder(),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            field.name,
            style: Theme.of(context)
                .textTheme
                .bodyLarge
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: OnzeColors.primary,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Text(
            field.fieldType.label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: OnzeColors.highlight,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ),
      ],
    );
  }

  Widget _buildSchedulesSection(
    BuildContext context,
    AsyncValue<List<FieldSchedule>> schedulesAsync,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Horarios disponibles',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
        const SizedBox(height: 8),
        schedulesAsync.when(
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Center(
                child: CircularProgressIndicator(strokeWidth: 2)),
          ),
          error: (_, _) => Text(
            'No se pudieron cargar los horarios.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: OnzeColors.error,
                ),
          ),
          data: (schedules) {
            final active =
                schedules.where((s) => s.isActive).toList();
            if (active.isEmpty) {
              return Text(
                'Esta cancha no tiene horarios configurados aún.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: OnzeColors.textSecondary,
                    ),
              );
            }

            // Agrupar por día y ordenar por hora de inicio
            final Map<int, List<FieldSchedule>> byDay = {};
            for (final s in active) {
              byDay.putIfAbsent(s.dayOfWeek, () => []).add(s);
            }
            for (final day in byDay.keys) {
              byDay[day]!.sort((a, b) {
                final aMin = a.startTime.hour * 60 + a.startTime.minute;
                final bMin = b.startTime.hour * 60 + b.startTime.minute;
                return aMin.compareTo(bMin);
              });
            }

            return Column(
              children: [
                for (final day in kDayOrder)
                  if (byDay.containsKey(day)) ...[
                    _DayScheduleRow(
                      dayName: kDayNames[day],
                      schedules: byDay[day]!,
                    ),
                  ],
              ],
            );
          },
        ),
      ],
    );
  }
}

class _DayScheduleRow extends StatelessWidget {
  const _DayScheduleRow({
    required this.dayName,
    required this.schedules,
  });

  final String dayName;
  final List<FieldSchedule> schedules;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(
              dayName,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: OnzeColors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
            ),
          ),
          Expanded(
            child: Wrap(
              spacing: 6,
              runSpacing: 4,
              children: schedules
                  .map(
                    (s) => Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: OnzeColors.primary,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: RichText(
                        text: TextSpan(
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(fontSize: 11),
                          children: [
                            TextSpan(
                              text: s.timeRange,
                              style: const TextStyle(
                                  color: OnzeColors.highlight),
                            ),
                            TextSpan(
                              text: '  \$${s.price.toStringAsFixed(0)}',
                              style: const TextStyle(
                                color: OnzeColors.warning,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class _PhotoPlaceholder extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      color: OnzeColors.surface,
      child: const Center(
        child: Icon(
          Icons.sports_soccer,
          size: 48,
          color: OnzeColors.textSecondary,
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
