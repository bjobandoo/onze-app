// Panel inferior con el detalle de una cancha: foto, horarios y reseñas.
// Usado desde el mapa de canchas y desde "Canchas cerca" en el Home.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/routing/app_router.dart';
import '../../../../core/theme/onze_colors.dart';
import '../../../../core/theme/onze_theme.dart';
import '../../../../features/matches/presentation/screens/send_challenge_screen.dart';
import '../../../../shared/widgets/onze_button.dart';
import '../../../../shared/widgets/onze_pressable.dart';
import '../../domain/models/field.dart';
import '../../domain/models/field_schedule.dart';
import '../providers/fields_providers.dart';
import 'field_reviews_section.dart';

/// Abre el detalle de [field] como bottom sheet arrastrable.
Future<void> showFieldDetailSheet(BuildContext context, Field field) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: OnzeColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius:
          BorderRadius.vertical(top: Radius.circular(OnzeTheme.radiusSheet)),
    ),
    builder: (_) => FieldDetailSheet(field: field),
  );
}

/// Contenido del detalle de cancha: foto, dirección, horarios y reseñas.
class FieldDetailSheet extends ConsumerWidget {
  const FieldDetailSheet({required this.field, super.key});

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
                OnzeButton(
                  label: 'Desafiar en esta cancha',
                  icon: Icons.sports_soccer,
                  onPressed: () => _goToChallenge(context),
                ),
                const SizedBox(height: 20),
                _buildSchedulesSection(context, schedulesAsync),
                const SizedBox(height: 20),
                const Divider(color: OnzeColors.border, height: 1),
                const SizedBox(height: 16),
                FieldReviewsSection(field: field),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Cierra el sheet y abre el formulario de desafío con esta cancha
  /// preseleccionada. Se captura el router antes del pop porque el
  /// context del sheet queda desmontado al cerrarse.
  void _goToChallenge(BuildContext context) {
    final router = GoRouter.of(context);
    Navigator.of(context).pop();
    router.push(
      AppRoutes.sendChallenge,
      extra: SendChallengeArgs(fieldId: field.id),
    );
  }

  /// Igual que [_goToChallenge], pero con fecha y horario precargados:
  /// la fecha es la próxima ocurrencia del día del [schedule].
  void _goToChallengeWithSlot(BuildContext context, FieldSchedule schedule) {
    final router = GoRouter.of(context);
    Navigator.of(context).pop();
    router.push(
      AppRoutes.sendChallenge,
      extra: SendChallengeArgs(
        fieldId: field.id,
        date: _nextDateForDay(schedule.dayOfWeek),
        scheduleId: schedule.id,
      ),
    );
  }

  /// Próxima fecha (desde mañana) cuyo día de semana coincide con
  /// [dayOfWeek] (convención 0=domingo … 6=sábado).
  DateTime _nextDateForDay(int dayOfWeek) {
    var d = DateTime.now().add(const Duration(days: 1));
    while (d.weekday % 7 != dayOfWeek) {
      d = d.add(const Duration(days: 1));
    }
    return DateTime(d.year, d.month, d.day);
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
    return SizedBox(
      height: 160,
      width: double.infinity,
      child: url != null
          ? Image.network(
              url,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => _PhotoPlaceholder(),
            )
          : _PhotoPlaceholder(),
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
            borderRadius: BorderRadius.circular(OnzeTheme.radiusPill),
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
          'HORARIOS DISPONIBLES',
          style: Theme.of(context).textTheme.labelSmall,
        ),
        const SizedBox(height: 4),
        Text(
          'Toca un horario para desafiar en ese bloque.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontSize: 12,
                color: OnzeColors.textDim,
              ),
        ),
        const SizedBox(height: 12),
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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final day in kDayOrder)
                  if (byDay.containsKey(day))
                    _DaySlotsGroup(
                      dayName: kDayNames[day],
                      schedules: byDay[day]!,
                      onSlotTap: (s) => _goToChallengeWithSlot(context, s),
                    ),
              ],
            );
          },
        ),
      ],
    );
  }
}

/// Grupo de horarios de un día: encabezado con el nombre del día y
/// debajo sus bloques como tarjetas tappables.
class _DaySlotsGroup extends StatelessWidget {
  const _DaySlotsGroup({
    required this.dayName,
    required this.schedules,
    required this.onSlotTap,
  });

  final String dayName;
  final List<FieldSchedule> schedules;
  final ValueChanged<FieldSchedule> onSlotTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            dayName,
            style: GoogleFonts.barlowCondensed(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.8,
              color: OnzeColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final s in schedules)
                _SlotTile(schedule: s, onTap: () => onSlotTap(s)),
            ],
          ),
        ],
      ),
    );
  }
}

/// Tarjeta de un bloque horario: hora arriba, precio abajo en verde.
class _SlotTile extends StatelessWidget {
  const _SlotTile({required this.schedule, required this.onTap});

  final FieldSchedule schedule;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return OnzePressable(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            color: OnzeColors.surfaceHigh,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: OnzeColors.border),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.schedule,
                      size: 13, color: OnzeColors.highlight),
                  const SizedBox(width: 5),
                  Text(
                    schedule.timeRange,
                    style: GoogleFonts.barlow(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: OnzeColors.textPrimary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 3),
              Text(
                '\$${schedule.price.toStringAsFixed(0)}',
                style: GoogleFonts.barlowCondensed(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                  color: OnzeColors.highlight,
                ),
              ),
            ],
          ),
        ),
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
