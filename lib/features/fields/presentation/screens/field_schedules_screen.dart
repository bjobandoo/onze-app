// Pantalla de gestión de horarios y precios de una cancha.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/routing/app_router.dart';
import '../../../../core/theme/onze_colors.dart';
import '../../domain/models/field.dart';
import '../../domain/models/field_schedule.dart';
import '../providers/fields_providers.dart';

/// Pantalla que lista y permite gestionar los bloques horarios de [fieldId].
class FieldSchedulesScreen extends ConsumerWidget {
  const FieldSchedulesScreen({
    super.key,
    required this.fieldId,
    this.field,
  });

  final String fieldId;

  /// Cancha completa (opcional). Si está presente habilita el botón de editar.
  final Field? field;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final schedulesAsync = ref.watch(fieldSchedulesProvider(fieldId));
    final notifierState = ref.watch(manageSchedulesProvider(fieldId));
    final title = field?.name ?? 'Horarios';

    return Scaffold(
      appBar: AppBar(
        title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          if (field != null)
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              tooltip: 'Editar cancha',
              onPressed: () => context.push(
                AppRoutes.editField(fieldId),
                extra: field,
              ),
            ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(2),
          child: notifierState.isLoading
              ? const LinearProgressIndicator(
                  minHeight: 2,
                  color: OnzeColors.accent,
                  backgroundColor: OnzeColors.surface,
                )
              : const SizedBox.shrink(),
        ),
      ),
      body: schedulesAsync.when(
        loading: () => const Center(
            child: CircularProgressIndicator(color: OnzeColors.accent)),
        error: (e, _) => _ErrorView(message: e.toString()),
        data: (schedules) => _ScheduleBody(
          fieldId: fieldId,
          schedules: schedules,
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => schedulesAsync.whenData(
          (schedules) => _openScheduleForm(
            context,
            ref,
            fieldId: fieldId,
            existingSchedules: schedules,
          ),
        ),
        icon: const Icon(Icons.add),
        label: const Text('Nuevo bloque'),
        backgroundColor: OnzeColors.accent,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Body — lista organizada por día
// ---------------------------------------------------------------------------

class _ScheduleBody extends StatelessWidget {
  const _ScheduleBody({required this.fieldId, required this.schedules});

  final String fieldId;
  final List<FieldSchedule> schedules;

  @override
  Widget build(BuildContext context) {
    if (schedules.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: _EmptyState(),
        ),
      );
    }

    // Agrupar por día en el orden L–D
    final Map<int, List<FieldSchedule>> byDay = {};
    for (final s in schedules) {
      byDay.putIfAbsent(s.dayOfWeek, () => []).add(s);
    }

    // Ordenar cada día por hora de inicio
    for (final day in byDay.keys) {
      byDay[day]!.sort((a, b) {
        final aMin = a.startTime.hour * 60 + a.startTime.minute;
        final bMin = b.startTime.hour * 60 + b.startTime.minute;
        return aMin.compareTo(bMin);
      });
    }

    final presentDays = kDayOrder.where(byDay.containsKey).toList();

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 100),
      itemCount: presentDays.length,
      itemBuilder: (context, index) {
        final day = presentDays[index];
        return _DaySection(
          fieldId: fieldId,
          dayOfWeek: day,
          schedules: byDay[day]!,
          allSchedules: schedules,
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Sección por día
// ---------------------------------------------------------------------------

class _DaySection extends StatelessWidget {
  const _DaySection({
    required this.fieldId,
    required this.dayOfWeek,
    required this.schedules,
    required this.allSchedules,
  });

  final String fieldId;
  final int dayOfWeek;
  final List<FieldSchedule> schedules;
  final List<FieldSchedule> allSchedules;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8, top: 16),
          child: Text(
            kDayNames[dayOfWeek],
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: OnzeColors.highlight,
                ),
          ),
        ),
        ...schedules.map(
          (s) => _ScheduleCard(
            fieldId: fieldId,
            schedule: s,
            allSchedules: allSchedules,
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Tarjeta de bloque horario
// ---------------------------------------------------------------------------

class _ScheduleCard extends ConsumerWidget {
  const _ScheduleCard({
    required this.fieldId,
    required this.schedule,
    required this.allSchedules,
  });

  final String fieldId;
  final FieldSchedule schedule;
  final List<FieldSchedule> allSchedules;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: OnzeColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: schedule.isActive
              ? OnzeColors.border
              : OnzeColors.border.withValues(alpha: 0.4),
        ),
      ),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        title: Text(
          schedule.timeRange,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.w500,
                color: schedule.isActive ? null : OnzeColors.textSecondary,
              ),
        ),
        subtitle: Text(
          '\$${schedule.price.toStringAsFixed(2)}',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: schedule.isActive
                    ? OnzeColors.warning
                    : OnzeColors.textSecondary,
              ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Switch(
              value: schedule.isActive,
              activeThumbColor: OnzeColors.accent,
              onChanged: (val) => ref
                  .read(manageSchedulesProvider(fieldId).notifier)
                  .toggleActive(schedule.id, isActive: val)
                  .then(
                      (_) => ref.invalidate(fieldSchedulesProvider(fieldId))),
            ),
            IconButton(
              icon: const Icon(Icons.edit_outlined,
                  color: OnzeColors.textSecondary, size: 20),
              onPressed: () => _openScheduleForm(
                context,
                ref,
                fieldId: fieldId,
                existing: schedule,
                existingSchedules: allSchedules,
              ),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline,
                  color: OnzeColors.error, size: 20),
              onPressed: () => _confirmDelete(context, ref),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: OnzeColors.surface,
        title: const Text('Eliminar bloque'),
        content: Text('¿Eliminar el bloque ${schedule.timeRange}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text(
              'Eliminar',
              style: TextStyle(color: OnzeColors.error),
            ),
          ),
        ],
      ),
    );
    if (ok == true && context.mounted) {
      final success = await ref
          .read(manageSchedulesProvider(fieldId).notifier)
          .delete(schedule.id);
      if (success) {
        ref.invalidate(fieldSchedulesProvider(fieldId));
      }
    }
  }
}

// ---------------------------------------------------------------------------
// Bottom sheet — formulario de bloque
// ---------------------------------------------------------------------------

Future<void> _openScheduleForm(
  BuildContext context,
  WidgetRef ref, {
  required String fieldId,
  required List<FieldSchedule> existingSchedules,
  FieldSchedule? existing,
}) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: OnzeColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (ctx) => _ScheduleFormSheet(
      fieldId: fieldId,
      existing: existing,
      existingSchedules: existingSchedules,
      onSaved: () => ref.invalidate(fieldSchedulesProvider(fieldId)),
    ),
  );
}

class _ScheduleFormSheet extends ConsumerStatefulWidget {
  const _ScheduleFormSheet({
    required this.fieldId,
    this.existing,
    required this.existingSchedules,
    required this.onSaved,
  });

  final String fieldId;
  final FieldSchedule? existing;

  /// Horarios ya existentes de la cancha, para detectar conflictos.
  final List<FieldSchedule> existingSchedules;
  final VoidCallback onSaved;

  @override
  ConsumerState<_ScheduleFormSheet> createState() => _ScheduleFormSheetState();
}

class _ScheduleFormSheetState extends ConsumerState<_ScheduleFormSheet> {
  final _priceController = TextEditingController();
  late Set<int> _selectedDays;
  late TimeOfDay _startTime;
  late TimeOfDay _endTime;
  String? _timeError;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _selectedDays = {e?.dayOfWeek ?? 1};
    _startTime = e?.startTime ?? const TimeOfDay(hour: 8, minute: 0);
    _endTime = e?.endTime ?? const TimeOfDay(hour: 10, minute: 0);
    _priceController.text = e != null ? e.price.toStringAsFixed(2) : '';
  }

  @override
  void dispose() {
    _priceController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Lógica de conflictos
  // ---------------------------------------------------------------------------

  /// Devuelve true si el rango actual colisiona con algún horario del [day].
  bool _hasConflict(int day) {
    final startMin = _startTime.hour * 60 + _startTime.minute;
    final endMin = _endTime.hour * 60 + _endTime.minute;
    return widget.existingSchedules.any((s) {
      if (s.dayOfWeek != day) return false;
      // Al editar, excluimos el propio bloque
      if (widget.existing?.id == s.id) return false;
      final sStart = s.startTime.hour * 60 + s.startTime.minute;
      final sEnd = s.endTime.hour * 60 + s.endTime.minute;
      return startMin < sEnd && endMin > sStart;
    });
  }

  List<int> get _daysWithConflict =>
      _selectedDays.where(_hasConflict).toList();

  List<int> get _daysWithoutConflict =>
      _selectedDays.where((d) => !_hasConflict(d)).toList();

  // ---------------------------------------------------------------------------
  // Validación
  // ---------------------------------------------------------------------------

  bool _validate() {
    final startMinutes = _startTime.hour * 60 + _startTime.minute;
    final endMinutes = _endTime.hour * 60 + _endTime.minute;
    if (endMinutes <= startMinutes) {
      setState(() =>
          _timeError = 'La hora de fin debe ser posterior al inicio.');
      return false;
    }
    setState(() => _timeError = null);
    return true;
  }

  // ---------------------------------------------------------------------------
  // Guardar
  // ---------------------------------------------------------------------------

  Future<void> _save() async {
    if (!_validate()) return;
    final price = double.tryParse(_priceController.text.trim()) ?? 0;
    if (price < 0) return;

    if (_isEdit) {
      // Modo edición — siempre día único
      if (_hasConflict(_selectedDays.first)) {
        setState(() =>
            _timeError = 'Este horario se superpone con uno ya existente.');
        return;
      }
      final success =
          await ref.read(manageSchedulesProvider(widget.fieldId).notifier).upsert(
                id: widget.existing!.id,
                dayOfWeek: _selectedDays.first,
                startTime: _startTime,
                endTime: _endTime,
                price: price,
              );
      if (success && mounted) {
        widget.onSaved();
        Navigator.of(context).pop();
      }
    } else {
      // Modo creación — puede ser multi-día
      final toCreate = _daysWithoutConflict;
      if (toCreate.isEmpty) {
        setState(() => _timeError =
            'Todos los días seleccionados tienen conflictos de horario.');
        return;
      }
      final created =
          await ref.read(manageSchedulesProvider(widget.fieldId).notifier).bulkUpsert(
                dayOfWeeks: toCreate.toSet(),
                startTime: _startTime,
                endTime: _endTime,
                price: price,
              );
      if (mounted) {
        widget.onSaved();
        Navigator.of(context).pop();
        final skipped = _daysWithConflict.length;
        if (skipped > 0) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '$created bloque(s) creado(s). '
                '$skipped día(s) omitido(s) por conflicto.',
              ),
              backgroundColor: OnzeColors.warning.withValues(alpha: 0.9),
            ),
          );
        }
      }
    }
  }

  Future<void> _pickTime({required bool isStart}) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: isStart ? _startTime : _endTime,
      builder: (ctx, child) => MediaQuery(
        data: MediaQuery.of(ctx).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _startTime = picked;
        } else {
          _endTime = picked;
        }
        _timeError = null;
      });
    }
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final notifierState = ref.watch(manageSchedulesProvider(widget.fieldId));
    final conflictDays = _daysWithConflict;
    final readyCount = _daysWithoutConflict.length;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        24,
        24,
        24,
        MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            _isEdit ? 'Editar bloque horario' : 'Nuevo bloque horario',
            style: Theme.of(context)
                .textTheme
                .bodyLarge
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 20),

          // ── Día(s) de la semana ──────────────────────────────────────────
          Row(
            children: [
              Text(
                _isEdit ? 'Día de la semana' : 'Días de la semana',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: OnzeColors.textSecondary,
                    ),
              ),
              if (!_isEdit) ...[
                const Spacer(),
                TextButton(
                  onPressed: () => setState(() {
                    if (_selectedDays.length == kDayOrder.length) {
                      _selectedDays = {_selectedDays.first};
                    } else {
                      _selectedDays = Set.of(kDayOrder);
                    }
                  }),
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(
                    _selectedDays.length == kDayOrder.length
                        ? 'Quitar todos'
                        : 'Todos',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: OnzeColors.accent,
                        ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: kDayOrder.map((day) {
              final selected = _selectedDays.contains(day);
              final conflict = selected && _hasConflict(day);
              return _DayChip(
                label: kDayNames[day].substring(0, 3),
                selected: selected,
                hasConflict: conflict,
                multiSelect: !_isEdit,
                onTap: () {
                  setState(() {
                    if (_isEdit) {
                      _selectedDays = {day};
                    } else {
                      if (selected && _selectedDays.length == 1) return;
                      if (selected) {
                        _selectedDays.remove(day);
                      } else {
                        _selectedDays.add(day);
                      }
                    }
                  });
                },
              );
            }).toList(),
          ),

          // Aviso de conflictos
          if (!_isEdit && conflictDays.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.warning_amber_outlined,
                    color: OnzeColors.warning, size: 14),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    '${conflictDays.map((d) => kDayNames[d].substring(0, 3)).join(', ')} '
                    'ya tienen un horario en este rango y serán omitidos.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: OnzeColors.warning,
                        ),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 20),

          // ── Horario ───────────────────────────────────────────────────────
          Row(
            children: [
              Expanded(
                child: _TimeTile(
                  label: 'Inicio',
                  time: _startTime,
                  onTap: () => _pickTime(isStart: true),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _TimeTile(
                  label: 'Fin',
                  time: _endTime,
                  onTap: () => _pickTime(isStart: false),
                ),
              ),
            ],
          ),
          if (_timeError != null) ...[
            const SizedBox(height: 6),
            Text(
              _timeError!,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: OnzeColors.error),
            ),
          ],
          const SizedBox(height: 20),

          // ── Precio ────────────────────────────────────────────────────────
          TextField(
            controller: _priceController,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
            ],
            decoration: InputDecoration(
              labelText: 'Precio por bloque (USD)',
              prefixText: '\$',
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12)),
              filled: true,
              fillColor: OnzeColors.background,
            ),
          ),
          const SizedBox(height: 24),

          if (notifierState.hasError)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                notifierState.errorMessage!,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: OnzeColors.error),
                textAlign: TextAlign.center,
              ),
            ),

          FilledButton(
            onPressed: notifierState.isLoading ? null : _save,
            style: FilledButton.styleFrom(
              backgroundColor: OnzeColors.accent,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: notifierState.isLoading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : Text(
                    _isEdit
                        ? 'Guardar cambios'
                        : readyCount > 1
                            ? 'Crear $readyCount bloques'
                            : 'Agregar bloque',
                  ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _DayChip — chip de día con soporte multi-selección y estado de conflicto
// ---------------------------------------------------------------------------

class _DayChip extends StatelessWidget {
  const _DayChip({
    required this.label,
    required this.selected,
    required this.hasConflict,
    required this.multiSelect,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final bool hasConflict;
  final bool multiSelect;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color bg;
    final Color labelColor;
    final Color borderColor;

    if (hasConflict) {
      bg = OnzeColors.warning.withValues(alpha: 0.15);
      labelColor = OnzeColors.warning;
      borderColor = OnzeColors.warning.withValues(alpha: 0.6);
    } else if (selected) {
      bg = OnzeColors.accent.withValues(alpha: 0.25);
      labelColor = OnzeColors.highlight;
      borderColor = OnzeColors.accent;
    } else {
      bg = OnzeColors.surface;
      labelColor = OnzeColors.textSecondary;
      borderColor = OnzeColors.border;
    }

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor),
        ),
        child: Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: labelColor,
                fontWeight:
                    selected ? FontWeight.w600 : FontWeight.normal,
              ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Widgets de apoyo
// ---------------------------------------------------------------------------

class _TimeTile extends StatelessWidget {
  const _TimeTile({
    required this.label,
    required this.time,
    required this.onTap,
  });

  final String label;
  final TimeOfDay time;
  final VoidCallback onTap;

  String _fmt(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(
          border: Border.all(color: OnzeColors.border),
          borderRadius: BorderRadius.circular(12),
          color: OnzeColors.background,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: OnzeColors.textSecondary,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              _fmt(time),
              style: Theme.of(context)
                  .textTheme
                  .bodyLarge
                  ?.copyWith(fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.schedule_outlined,
            size: 64, color: OnzeColors.textSecondary),
        const SizedBox(height: 16),
        Text(
          'Sin horarios configurados',
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: OnzeColors.textSecondary,
              ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          'Agrega bloques horarios para que los equipos puedan reservar esta cancha.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: OnzeColors.textSecondary,
              ),
          textAlign: TextAlign.center,
        ),
      ],
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
