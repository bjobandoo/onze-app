// Pantalla vitrina de logros coleccionables.
// Muestra todos los logros del catálogo (ganados en color, bloqueados en gris).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/onze_colors.dart';
import '../../../../features/teams/domain/models/team.dart';
import '../../../../features/teams/presentation/providers/teams_providers.dart';
import '../../domain/models/achievement.dart';
import '../providers/achievements_providers.dart';
import '../../../../features/onboarding/presentation/providers/onboarding_providers.dart';
import '../../../../features/onboarding/presentation/widgets/onze_tip_banner.dart';

/// Pantalla de vitrina de logros.
///
/// Si se pasa [teamId] se abre directamente en la pestaña del equipo.
class AchievementsScreen extends ConsumerStatefulWidget {
  const AchievementsScreen({super.key, this.teamId});

  final String? teamId;

  @override
  ConsumerState<AchievementsScreen> createState() => _AchievementsScreenState();
}

class _AchievementsScreenState extends ConsumerState<AchievementsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.teamId != null ? 1 : 0,
    );
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Logros'),
        bottom: TabBar(
          controller: _tab,
          indicatorColor: OnzeColors.highlight,
          labelColor: OnzeColors.textPrimary,
          unselectedLabelColor: OnzeColors.textSecondary,
          tabs: const [
            Tab(text: 'Personales'),
            Tab(text: 'Equipo'),
          ],
        ),
      ),
      body: Column(
        children: [
          if (!ref.watch(onboardingProvider
              .select((s) => s.contains(kObAchievements))))
            OnzeTipBanner(
              icon: Icons.emoji_events_outlined,
              title: 'Logros y medallas',
              body: 'Los logros se desbloquean automáticamente al cumplir hitos: '
                  'primera victoria, rachas de triunfos, partidos jugados y más. '
                  'Las medallas ELO suben de categoría con tu rating.',
              onDismiss: () => ref
                  .read(onboardingProvider.notifier)
                  .dismiss(kObAchievements),
            ),
          Expanded(
            child: TabBarView(
              controller: _tab,
              children: [
                _PersonalTab(),
                _TeamTab(initialTeamId: widget.teamId),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Tab: logros personales
// ---------------------------------------------------------------------------

class _PersonalTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catalogAsync = ref.watch(userAchievementsCatalogProvider);
    final earnedAsync  = ref.watch(myEarnedAchievementsProvider);

    return catalogAsync.when(
      loading: () => const Center(
          child: CircularProgressIndicator(color: OnzeColors.accent)),
      error: (e, _) => _ErrorView(message: e.toString()),
      data: (catalog) {
        final earnedCodes = earnedAsync.valueOrNull
                ?.map((e) => e.achievement.code)
                .toSet() ??
            const <String>{};
        final earnedMap = {
          for (final e in earnedAsync.valueOrNull ?? <EarnedAchievement>[])
            e.achievement.code: e,
        };

        return _AchievementsGrid(
          catalog:   catalog,
          earnedMap: earnedMap,
          earnedCodes: earnedCodes,
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Tab: logros de equipo
// ---------------------------------------------------------------------------

class _TeamTab extends ConsumerStatefulWidget {
  const _TeamTab({this.initialTeamId});
  final String? initialTeamId;

  @override
  ConsumerState<_TeamTab> createState() => _TeamTabState();
}

class _TeamTabState extends ConsumerState<_TeamTab> {
  String? _selectedTeamId;

  @override
  void initState() {
    super.initState();
    _selectedTeamId = widget.initialTeamId;
  }

  @override
  Widget build(BuildContext context) {
    final teamsAsync   = ref.watch(myTeamsProvider);
    final catalogAsync = ref.watch(teamAchievementsCatalogProvider);

    return teamsAsync.when(
      loading: () => const Center(
          child: CircularProgressIndicator(color: OnzeColors.accent)),
      error: (e, _) => _ErrorView(message: e.toString()),
      data: (teams) {
        if (teams.isEmpty) {
          return const _EmptyView(
            message: 'Únete a un equipo para ver sus logros.',
          );
        }

        // Auto-select first team if none is selected yet
        final effectiveId = _selectedTeamId ?? teams.first.id;

        return Column(
          children: [
            if (teams.length > 1)
              _TeamPicker(
                teams:    teams,
                selected: effectiveId,
                onChanged: (id) => setState(() => _selectedTeamId = id),
              ),
            Expanded(
              child: catalogAsync.when(
                loading: () => const Center(
                    child: CircularProgressIndicator(color: OnzeColors.accent)),
                error: (e, _) => _ErrorView(message: e.toString()),
                data: (catalog) => _TeamAchievementsBody(
                  catalog:  catalog,
                  teamId:   effectiveId,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _TeamAchievementsBody extends ConsumerWidget {
  const _TeamAchievementsBody({
    required this.catalog,
    required this.teamId,
  });

  final List<Achievement> catalog;
  final String teamId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final earnedAsync = ref.watch(teamEarnedAchievementsProvider(teamId));

    return earnedAsync.when(
      loading: () =>
          const Center(child: CircularProgressIndicator(color: OnzeColors.accent)),
      error: (e, _) => _ErrorView(message: e.toString()),
      data: (earned) {
        final earnedCodes = earned.map((e) => e.achievement.code).toSet();
        final earnedMap   = {
          for (final e in earned) e.achievement.code: e,
        };
        return _AchievementsGrid(
          catalog:    catalog,
          earnedMap:  earnedMap,
          earnedCodes: earnedCodes,
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Selector de equipo (cuando el usuario pertenece a varios)
// ---------------------------------------------------------------------------

class _TeamPicker extends StatelessWidget {
  const _TeamPicker({
    required this.teams,
    required this.selected,
    required this.onChanged,
  });

  final List<Team> teams;
  final String selected;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: OnzeColors.surfaceHigh,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: selected,
          isExpanded: true,
          dropdownColor: OnzeColors.surfaceHigh,
          icon: const Icon(Icons.expand_more, color: OnzeColors.textSecondary),
          style: Theme.of(context)
              .textTheme
              .bodyMedium
              ?.copyWith(color: OnzeColors.textPrimary),
          items: teams
              .map((t) => DropdownMenuItem(
                    value: t.id,
                    child: Text(t.name, overflow: TextOverflow.ellipsis),
                  ))
              .toList(),
          onChanged: (id) {
            if (id != null) onChanged(id);
          },
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Grid de logros (earned + locked)
// ---------------------------------------------------------------------------

class _AchievementsGrid extends StatelessWidget {
  const _AchievementsGrid({
    required this.catalog,
    required this.earnedMap,
    required this.earnedCodes,
  });

  final List<Achievement> catalog;
  final Map<String, EarnedAchievement> earnedMap;
  final Set<String> earnedCodes;

  @override
  Widget build(BuildContext context) {
    if (catalog.isEmpty) {
      return const _EmptyView(message: 'No hay logros disponibles aún.');
    }

    // Separar: obtenidos primero, luego bloqueados
    final earned  = catalog.where((a) => earnedCodes.contains(a.code)).toList();
    final locked  = catalog.where((a) => !earnedCodes.contains(a.code)).toList();
    final ordered = [...earned, ...locked];

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 40),
      children: [
        if (earned.isNotEmpty) ...[
          _GroupLabel(
            '${earned.length} de ${catalog.length} logros obtenidos',
            color: OnzeColors.highlight,
          ),
          const SizedBox(height: 12),
        ],
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 0.85,
          ),
          itemCount: ordered.length,
          itemBuilder: (context, i) {
            final a = ordered[i];
            final isEarned = earnedCodes.contains(a.code);
            return _AchievementCard(
              achievement: a,
              isEarned:    isEarned,
              unlockedAt:  earnedMap[a.code]?.unlockedAt,
            );
          },
        ),
      ],
    );
  }
}

class _GroupLabel extends StatelessWidget {
  const _GroupLabel(this.text, {this.color});
  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: GoogleFonts.inter(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.2,
        color: color ?? OnzeColors.textSecondary,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Tarjeta individual de logro
// ---------------------------------------------------------------------------

class _AchievementCard extends StatelessWidget {
  const _AchievementCard({
    required this.achievement,
    required this.isEarned,
    this.unlockedAt,
  });

  final Achievement achievement;
  final bool isEarned;
  final DateTime? unlockedAt;

  @override
  Widget build(BuildContext context) {
    final color = isEarned ? achievement.accentColor : OnzeColors.textSecondary;

    return Tooltip(
      message: isEarned
          ? '${achievement.name}\nObtenido el ${_fmtDate(unlockedAt!)}'
          : '${achievement.name}\n${achievement.description}',
      child: Container(
        decoration: BoxDecoration(
          color: isEarned
              ? achievement.accentColor.withValues(alpha: 0.08)
              : OnzeColors.surfaceHigh,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isEarned
                ? achievement.accentColor.withValues(alpha: 0.45)
                : OnzeColors.border,
            width: isEarned ? 1.5 : 1,
          ),
        ),
        padding: const EdgeInsets.fromLTRB(8, 14, 8, 10),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Emoji del logro
            Stack(
              alignment: Alignment.center,
              children: [
                Text(
                  achievement.emoji,
                  style: TextStyle(
                    fontSize: 30,
                    color: isEarned ? null : const Color(0x40FFFFFF),
                  ),
                ),
                if (!isEarned)
                  const Positioned(
                    right: 0,
                    bottom: 0,
                    child: Text('🔒', style: TextStyle(fontSize: 12)),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            // Nombre
            Text(
              achievement.name,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: color,
                height: 1.2,
              ),
            ),
            if (isEarned && unlockedAt != null) ...[
              const SizedBox(height: 3),
              Text(
                _fmtDate(unlockedAt!),
                style: TextStyle(
                  fontSize: 9,
                  color: OnzeColors.textSecondary,
                ),
              ),
            ],
            if (!isEarned) ...[
              const SizedBox(height: 3),
              Text(
                achievement.description,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 9,
                  color: OnzeColors.textSecondary,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  static String _fmtDate(DateTime dt) {
    const months = [
      '', 'ene', 'feb', 'mar', 'abr', 'may', 'jun',
      'jul', 'ago', 'sep', 'oct', 'nov', 'dic',
    ];
    return '${dt.day} ${months[dt.month]}';
  }
}

// ---------------------------------------------------------------------------
// Auxiliares
// ---------------------------------------------------------------------------

class _EmptyView extends StatelessWidget {
  const _EmptyView({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: Theme.of(context)
              .textTheme
              .bodyMedium
              ?.copyWith(color: OnzeColors.textSecondary),
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
          textAlign: TextAlign.center,
          style: Theme.of(context)
              .textTheme
              .bodyMedium
              ?.copyWith(color: OnzeColors.error),
        ),
      ),
    );
  }
}
