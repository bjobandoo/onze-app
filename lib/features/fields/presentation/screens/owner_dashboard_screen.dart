// Panel de estadísticas para el dueño de canchas.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/onze_colors.dart';
import '../../domain/models/owner_stats.dart';
import '../providers/fields_providers.dart';

/// Pantalla de estadísticas de reservas, ocupación e ingresos del dueño.
class OwnerDashboardScreen extends ConsumerStatefulWidget {
  const OwnerDashboardScreen({required this.ownerId, super.key});

  final String ownerId;

  @override
  ConsumerState<OwnerDashboardScreen> createState() =>
      _OwnerDashboardScreenState();
}

class _OwnerDashboardScreenState extends ConsumerState<OwnerDashboardScreen> {
  StatPeriod _period = StatPeriod.week;

  @override
  Widget build(BuildContext context) {
    final statsAsync = ref.watch(ownerStatsProvider(widget.ownerId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Panel de estadísticas'),
        actions: [
          _PeriodSelector(
            value: _period,
            onChanged: (p) => setState(() => _period = p),
          ),
        ],
      ),
      body: statsAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: OnzeColors.accent),
        ),
        error: (e, _) => _ErrorView(message: e.toString()),
        data: (stats) => _DashboardBody(stats: stats, period: _period),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Selector de periodo
// ---------------------------------------------------------------------------

class _PeriodSelector extends StatelessWidget {
  const _PeriodSelector({required this.value, required this.onChanged});

  final StatPeriod value;
  final ValueChanged<StatPeriod> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<StatPeriod>(
          value: value,
          dropdownColor: OnzeColors.surface,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: OnzeColors.highlight,
                fontWeight: FontWeight.w600,
              ),
          items: StatPeriod.values
              .map(
                (p) => DropdownMenuItem(
                  value: p,
                  child: Text(p.label),
                ),
              )
              .toList(),
          onChanged: (p) {
            if (p != null) onChanged(p);
          },
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Cuerpo principal
// ---------------------------------------------------------------------------

class _DashboardBody extends StatelessWidget {
  const _DashboardBody({required this.stats, required this.period});

  final OwnerStats stats;
  final StatPeriod period;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const _SectionTitle(text: 'Resumen global'),
        const SizedBox(height: 12),
        _GlobalKpiGrid(stats: stats, period: period),
        const SizedBox(height: 24),
        if (stats.fields.isNotEmpty) ...[
          const _SectionTitle(text: 'Por cancha'),
          const SizedBox(height: 12),
          for (final field in stats.fields) ...[
            _FieldStatsCard(fieldStats: field, period: period),
            const SizedBox(height: 12),
          ],
        ],
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Grid de KPIs globales
// ---------------------------------------------------------------------------

class _GlobalKpiGrid extends StatelessWidget {
  const _GlobalKpiGrid({required this.stats, required this.period});

  final OwnerStats stats;
  final StatPeriod period;

  @override
  Widget build(BuildContext context) {
    final matches = stats.matchesForPeriod(period);
    final revenue = stats.revenueForPeriod(period);
    final completion = stats.completionRate;

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.4,
      children: [
        _KpiCard(
          icon: Icons.calendar_today_outlined,
          label: 'Reservas',
          value: '$matches',
          color: OnzeColors.accent,
        ),
        _KpiCard(
          icon: Icons.attach_money_outlined,
          label: 'Ingresos est.',
          value: '\$${revenue.toStringAsFixed(0)}',
          color: OnzeColors.highlight,
        ),
        _KpiCard(
          icon: Icons.sports_soccer_outlined,
          label: 'Partidos compl.',
          value: '${(completion * 100).toStringAsFixed(0)}%',
          color: OnzeColors.warning,
        ),
        _KpiCard(
          icon: Icons.star_outline,
          label: 'Rating promedio',
          value: stats.avgRating > 0
              ? stats.avgRating.toStringAsFixed(1)
              : '—',
          color: OnzeColors.warning,
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Card de KPI individual
// ---------------------------------------------------------------------------

class _KpiCard extends StatelessWidget {
  const _KpiCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: OnzeColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: OnzeColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Icon(icon, color: color, size: 22),
          const Spacer(),
          Text(
            value,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: OnzeColors.textSecondary,
                ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Card de estadísticas por cancha
// ---------------------------------------------------------------------------

class _FieldStatsCard extends StatelessWidget {
  const _FieldStatsCard({
    required this.fieldStats,
    required this.period,
  });

  final OwnerFieldStats fieldStats;
  final StatPeriod period;

  @override
  Widget build(BuildContext context) {
    final matches = fieldStats.matchesForPeriod(period);
    final revenue = fieldStats.revenueForPeriod(period);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: OnzeColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: OnzeColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  fieldStats.fieldName,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ),
              if (fieldStats.averageRating > 0) ...[
                const Icon(Icons.star, color: OnzeColors.warning, size: 14),
                const SizedBox(width: 2),
                Text(
                  fieldStats.averageRating.toStringAsFixed(1),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: OnzeColors.warning,
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(width: 4),
                Text(
                  '(${fieldStats.reviewsCount})',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: OnzeColors.textSecondary,
                      ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          const Divider(color: OnzeColors.border, height: 1),
          const SizedBox(height: 12),
          Row(
            children: [
              _FieldStat(
                label: 'Reservas',
                value: '$matches',
                icon: Icons.calendar_today_outlined,
              ),
              const SizedBox(width: 24),
              _FieldStat(
                label: 'Ingresos est.',
                value: '\$${revenue.toStringAsFixed(0)}',
                icon: Icons.attach_money_outlined,
                valueColor: OnzeColors.highlight,
              ),
              const SizedBox(width: 24),
              _FieldStat(
                label: 'Completados',
                value: '${(fieldStats.completionRate * 100).toStringAsFixed(0)}%',
                icon: Icons.check_circle_outline,
                valueColor: OnzeColors.accent,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FieldStat extends StatelessWidget {
  const _FieldStat({
    required this.label,
    required this.value,
    required this.icon,
    this.valueColor,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 13, color: OnzeColors.textSecondary),
            const SizedBox(width: 4),
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: OnzeColors.textSecondary,
                    fontSize: 11,
                  ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: valueColor ?? Colors.white,
              ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: OnzeColors.textSecondary,
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
