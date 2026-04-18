// Pantalla para enviar un desafío a otro equipo.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/onze_colors.dart';
import '../../../../features/auth/presentation/providers/auth_providers.dart';
import '../../../../features/fields/domain/models/field.dart';
import '../../../../features/fields/domain/models/field_schedule.dart';
import '../../../../features/fields/presentation/providers/fields_providers.dart';
import '../../../../features/teams/domain/models/team.dart';
import '../providers/matches_providers.dart';

class SendChallengeScreen extends ConsumerStatefulWidget {
  const SendChallengeScreen({super.key});

  @override
  ConsumerState<SendChallengeScreen> createState() =>
      _SendChallengeScreenState();
}

class _SendChallengeScreenState extends ConsumerState<SendChallengeScreen> {
  Team? _myTeam;
  String? _fieldId;
  DateTime? _date;
  FieldSchedule? _slot;
  Team? _opponent;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.invalidate(verifiedFieldsProvider);
      ref.invalidate(myCaptainTeamsProvider);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Enviar desafío')),
      body: _buildGuardedBody(context, ref),
    );
  }

  String _fmtDate(DateTime d) {
    const m = ['','ene','feb','mar','abr','may','jun','jul','ago','sep','oct','nov','dic'];
    return '${d.day} ${m[d.month]} ${d.year}';
  }

  Widget _buildGuardedBody(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider).valueOrNull;
    if (user != null && user.isSuspended) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.block_outlined,
                  size: 64, color: OnzeColors.error),
              const SizedBox(height: 16),
              Text('Cuenta suspendida',
                  style: Theme.of(context).textTheme.displayLarge?.copyWith(fontSize: 20)),
              const SizedBox(height: 8),
              Text(
                user.suspensionUntil != null
                    ? 'No puedes enviar desafíos hasta el ${_fmtDate(user.suspensionUntil!)}'
                    : 'Tu cuenta está suspendida permanentemente.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: OnzeColors.textSecondary),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    final captainTeamsAsync = ref.watch(myCaptainTeamsProvider);
    final fieldsAsync = ref.watch(verifiedFieldsProvider);
    final sendState = ref.watch(sendChallengeProvider);

    return captainTeamsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: OnzeColors.accent)),
        error: (e, _) => _errorText(context, e.toString()),
        data: (captainTeams) {
          if (captainTeams.isEmpty) {
            return _errorText(
                context, 'Necesitas ser capitán de un equipo para desafiar.');
          }
          // Auto-seleccionar si solo hay un equipo
          if (_myTeam == null && captainTeams.length == 1) {
            WidgetsBinding.instance.addPostFrameCallback(
                (_) => setState(() => _myTeam = captainTeams.first));
          }
          return _buildForm(context, captainTeams, fieldsAsync, sendState);
        },
      );
  }

  Widget _buildForm(
    BuildContext context,
    List<Team> captainTeams,
    AsyncValue<List<Field>> fieldsAsync,
    SendChallengeState sendState,
  ) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
      children: [
        _sectionLabel(context, 'Mi equipo'),
        _TeamSelector(
          teams: captainTeams,
          selected: _myTeam,
          onSelected: (t) => setState(() {
            _myTeam = t;
            _slot = null; // reset slot si cambia el equipo
          }),
        ),
        const SizedBox(height: 20),
        _sectionLabel(context, 'Cancha'),
        fieldsAsync.when(
          loading: () =>
              const Center(child: CircularProgressIndicator(strokeWidth: 2, color: OnzeColors.accent)),
          error: (e, _) => _errorText(context, e.toString()),
          data: (fields) => _FieldDropdown(
            fields: fields,
            selectedId: _fieldId,
            onSelected: (id) => setState(() {
              _fieldId = id;
              _slot = null;
            }),
          ),
        ),
        const SizedBox(height: 20),
        _sectionLabel(context, 'Fecha'),
        _DatePickerTile(
          selected: _date,
          onSelected: (d) => setState(() {
            _date = d;
            _slot = null;
          }),
        ),
        if (_fieldId != null && _date != null) ...[
          const SizedBox(height: 20),
          _sectionLabel(context, 'Horario disponible'),
          _SlotSelector(
            fieldId: _fieldId!,
            date: _date!,
            selected: _slot,
            onSelected: (s) => setState(() => _slot = s),
          ),
        ],
        const SizedBox(height: 20),
        _sectionLabel(context, 'Equipo rival'),
        _OpponentSearch(
          excludeTeamId: _myTeam?.id ?? '',
          selected: _opponent,
          onSelected: (t) => setState(() => _opponent = t),
        ),
        const SizedBox(height: 28),
        if (sendState.hasError)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              sendState.errorMessage!,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: OnzeColors.error),
              textAlign: TextAlign.center,
            ),
          ),
        FilledButton(
          onPressed: sendState.isLoading ? null : _canSend ? _send : null,
          style: FilledButton.styleFrom(
            backgroundColor: OnzeColors.accent,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          child: sendState.isLoading
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white),
                )
              : const Text('Enviar desafío'),
        ),
      ],
    );
  }

  bool get _canSend =>
      _myTeam != null &&
      _fieldId != null &&
      _date != null &&
      _slot != null &&
      _opponent != null;

  Future<void> _send() async {
    final ok = await ref.read(sendChallengeProvider.notifier).send(
          challengerTeamId: _myTeam!.id,
          challengedTeamId: _opponent!.id,
          fieldId: _fieldId!,
          date: _date!,
          startTime: _slot!.startTime,
          endTime: _slot!.endTime,
          price: _slot!.price,
        );
    if (ok && mounted) {
      ref.invalidate(challengesSentProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('¡Desafío enviado! Esperando respuesta del rival.'),
          backgroundColor: OnzeColors.accent,
        ),
      );
      context.pop();
    }
  }

  Widget _sectionLabel(BuildContext context, String label) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(
          label.toUpperCase(),
          style: Theme.of(context).textTheme.labelSmall,
        ),
      );

  Widget _errorText(BuildContext context, String msg) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            msg,
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: OnzeColors.error),
            textAlign: TextAlign.center,
          ),
        ),
      );
}

// ---------------------------------------------------------------------------
// Sub-widgets del formulario
// ---------------------------------------------------------------------------

class _TeamSelector extends StatelessWidget {
  const _TeamSelector(
      {required this.teams, required this.selected, required this.onSelected});

  final List<Team> teams;
  final Team? selected;
  final ValueChanged<Team> onSelected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      children: teams.map((t) {
        final isSelected = t.id == selected?.id;
        return ChoiceChip(
          label: Text(t.name),
          selected: isSelected,
          selectedColor: OnzeColors.accent,
          backgroundColor: OnzeColors.surface,
          labelStyle: TextStyle(
            color: isSelected ? Colors.white : OnzeColors.textSecondary,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          ),
          onSelected: (_) => onSelected(t),
        );
      }).toList(),
    );
  }
}

class _FieldDropdown extends StatelessWidget {
  const _FieldDropdown(
      {required this.fields,
      required this.selectedId,
      required this.onSelected});

  final List<Field> fields;
  final String? selectedId;
  final void Function(String id) onSelected;

  @override
  Widget build(BuildContext context) {
    if (fields.isEmpty) {
      return Text(
        'No hay canchas verificadas disponibles.',
        style: Theme.of(context)
            .textTheme
            .bodySmall
            ?.copyWith(color: OnzeColors.textSecondary),
      );
    }
    return DropdownButtonFormField<String>(
      initialValue: selectedId,
      isExpanded: true,
      itemHeight: 56,
      decoration: InputDecoration(
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        filled: true,
        fillColor: OnzeColors.surface,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      ),
      hint: const Text('Selecciona una cancha'),
      dropdownColor: OnzeColors.surface,
      items: [
        for (final f in fields)
          DropdownMenuItem<String>(
            value: f.id,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(f.name, overflow: TextOverflow.ellipsis),
                Text(
                  f.address,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11,
                    color: OnzeColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
      ],
      onChanged: (id) {
        if (id == null) return;
        onSelected(id);
      },
    );
  }
}

class _DatePickerTile extends StatelessWidget {
  const _DatePickerTile({required this.selected, required this.onSelected});

  final DateTime? selected;
  final ValueChanged<DateTime> onSelected;

  @override
  Widget build(BuildContext context) {
    final label = selected == null
        ? 'Seleccionar fecha'
        : '${selected!.day}/${selected!.month}/${selected!.year}';

    return InkWell(
      onTap: () async {
        final now = DateTime.now();
        final picked = await showDatePicker(
          context: context,
          initialDate: now.add(const Duration(days: 1)),
          firstDate: now,
          lastDate: now.add(const Duration(days: 60)),
          locale: const Locale('es', 'EC'),
        );
        if (picked != null) onSelected(picked);
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(
          border: Border.all(color: OnzeColors.border),
          borderRadius: BorderRadius.circular(8),
          color: OnzeColors.surface,
        ),
        child: Row(
          children: [
            const Icon(Icons.calendar_today_outlined,
                color: OnzeColors.textSecondary, size: 18),
            const SizedBox(width: 10),
            Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: selected == null
                        ? OnzeColors.textSecondary
                        : null,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SlotSelector extends ConsumerWidget {
  const _SlotSelector({
    required this.fieldId,
    required this.date,
    required this.selected,
    required this.onSelected,
  });

  final String fieldId;
  final DateTime date;
  final FieldSchedule? selected;
  final ValueChanged<FieldSchedule> onSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final args = (fieldId: fieldId, date: date);
    final slotsAsync = ref.watch(availableSlotsProvider(args));

    return slotsAsync.when(
      loading: () =>
          const Center(child: CircularProgressIndicator(strokeWidth: 2)),
      error: (e, _) => Text(
        e.toString(),
        style: Theme.of(context)
            .textTheme
            .bodySmall
            ?.copyWith(color: OnzeColors.error),
      ),
      data: (slots) {
        if (slots.isEmpty) {
          return Text(
            'No hay horarios disponibles para esta fecha.',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: OnzeColors.textSecondary),
          );
        }
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: slots.map((s) {
            final isSelected = s.id == selected?.id;
            return ChoiceChip(
              label: Text(
                  '${s.timeRange}  \$${s.price.toStringAsFixed(0)}'),
              selected: isSelected,
              selectedColor: OnzeColors.accent,
              backgroundColor: OnzeColors.surface,
              labelStyle: TextStyle(
                color: isSelected ? Colors.white : OnzeColors.textSecondary,
                fontWeight:
                    isSelected ? FontWeight.w600 : FontWeight.normal,
                fontSize: 12,
              ),
              onSelected: (_) => onSelected(s),
            );
          }).toList(),
        );
      },
    );
  }
}

class _OpponentSearch extends ConsumerStatefulWidget {
  const _OpponentSearch({
    required this.excludeTeamId,
    required this.selected,
    required this.onSelected,
  });

  final String excludeTeamId;
  final Team? selected;
  final ValueChanged<Team> onSelected;

  @override
  ConsumerState<_OpponentSearch> createState() => _OpponentSearchState();
}

class _OpponentSearchState extends ConsumerState<_OpponentSearch> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final searchState = ref.watch(teamSearchProvider(widget.excludeTeamId));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.selected != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _SelectedTeamChip(
              team: widget.selected!,
              onRemove: () {
                setState(() => _controller.clear());
                ref
                    .read(teamSearchProvider(widget.excludeTeamId).notifier)
                    .setQuery('');
              },
            ),
          ),
        TextField(
          controller: _controller,
          onChanged: (q) => ref
              .read(teamSearchProvider(widget.excludeTeamId).notifier)
              .setQuery(q),
          decoration: InputDecoration(
            hintText: 'Buscar equipo rival…',
            prefixIcon: const Icon(Icons.search, color: OnzeColors.textSecondary),
            border:
                OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            filled: true,
            fillColor: OnzeColors.surface,
          ),
        ),
        if (searchState.isLoading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Center(
                child: CircularProgressIndicator(strokeWidth: 2, color: OnzeColors.accent)),
          )
        else if (searchState.results.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 4),
            decoration: BoxDecoration(
              color: OnzeColors.surface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: OnzeColors.border),
            ),
            child: Column(
              children: searchState.results
                  .map((t) => ListTile(
                        dense: true,
                        title: Text(t.name),
                        onTap: () {
                          widget.onSelected(t);
                          _controller.text = t.name;
                          ref
                              .read(teamSearchProvider(widget.excludeTeamId)
                                  .notifier)
                              .setQuery('');
                        },
                      ))
                  .toList(),
            ),
          ),
      ],
    );
  }
}

class _SelectedTeamChip extends StatelessWidget {
  const _SelectedTeamChip({required this.team, required this.onRemove});

  final Team team;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: OnzeColors.primary,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            team.name,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: OnzeColors.highlight,
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: onRemove,
            child: const Icon(Icons.close,
                size: 14, color: OnzeColors.textSecondary),
          ),
        ],
      ),
    );
  }
}
