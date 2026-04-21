// Pantalla de ranking global de equipos.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/routing/app_router.dart';
import '../../../../core/theme/onze_colors.dart';
import '../../../../features/teams/domain/models/team.dart';
import '../../../../shared/widgets/onze_avatar.dart';
import '../../domain/models/ranking_entry.dart';
import '../../domain/models/ranking_snapshot.dart';
import '../providers/stats_providers.dart';
import '../../../../features/onboarding/presentation/providers/onboarding_providers.dart';
import '../../../../features/onboarding/presentation/widgets/onze_tip_banner.dart';

class RankingScreen extends ConsumerStatefulWidget {
  const RankingScreen({super.key});

  @override
  ConsumerState<RankingScreen> createState() => _RankingScreenState();
}

class _RankingScreenState extends ConsumerState<RankingScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this);
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
        title: const Text('Ranking'),
        bottom: TabBar(
          controller: _tab,
          indicatorColor: OnzeColors.highlight,
          labelColor: OnzeColors.textPrimary,
          unselectedLabelColor: OnzeColors.textSecondary,
          tabs: const [
            Tab(text: 'Global'),
            Tab(text: 'Quincenal'),
            Tab(text: 'Mensual'),
          ],
        ),
      ),
      body: Column(
        children: [
          if (!ref.watch(onboardingProvider.notifier).isDismissed(kObElo))
            OnzeTipBanner(
              icon: Icons.leaderboard_outlined,
              title: 'Sistema ELO',
              body: 'El ELO mide la fortaleza de cada equipo. Ganar suma puntos y '
                  'perder los resta. Vencer a un rival con mayor ELO que tú da '
                  'más puntos que ganarle a uno más débil.',
              onDismiss: () =>
                  ref.read(onboardingProvider.notifier).dismiss(kObElo),
            ),
          Expanded(
            child: TabBarView(
              controller: _tab,
              children: [
                _GlobalTab(),
                _PeriodTab(provider: biweeklyRankingProvider),
                _PeriodTab(provider: monthlyRankingProvider),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Tab: Ranking global (ELO actual)
// ---------------------------------------------------------------------------

class _GlobalTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(globalRankingProvider);

    return async.when(
      loading: () =>
          const Center(child: CircularProgressIndicator(color: OnzeColors.accent)),
      error: (e, _) => _ErrorView(message: e.toString()),
      data: (entries) {
        if (entries.isEmpty) {
          return const _EmptyView(
              message: 'Aún no hay equipos en el ranking.');
        }
        return RefreshIndicator(
          color: OnzeColors.accent,
          onRefresh: () async => ref.invalidate(globalRankingProvider),
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
            itemCount: entries.length,
            itemBuilder: (context, i) => _GlobalRankCard(
              entry: entries[i],
              onTap: () => context.push(
                AppRoutes.teamDetail(entries[i].teamId),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _GlobalRankCard extends StatelessWidget {
  const _GlobalRankCard({required this.entry, required this.onTap});

  final RankingEntry entry;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isTop3 = entry.position <= 3;
    final tierColor = entry.eloTier.color;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: OnzeColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isTop3
                ? tierColor.withValues(alpha: 0.5)
                : OnzeColors.border,
            width: isTop3 ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            // Posición
            SizedBox(
              width: 36,
              child: Text(
                '#${entry.position}',
                style: GoogleFonts.inter(
                  fontSize: isTop3 ? 18 : 14,
                  fontWeight: FontWeight.w900,
                  color: isTop3 ? tierColor : OnzeColors.textSecondary,
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Avatar
            OnzeAvatar(
                imageUrl: entry.shieldUrl,
                name: entry.teamName,
                radius: 22),
            const SizedBox(width: 12),
            // Nombre + tier
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.teamName,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Row(
                    children: [
                      Text(
                        entry.eloTier.emoji,
                        style: const TextStyle(fontSize: 12),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        entry.eloTier.label,
                        style: TextStyle(
                            fontSize: 11,
                            color: tierColor,
                            fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // ELO + W/D/L
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${entry.eloRating}',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: tierColor,
                  ),
                ),
                Text(
                  '${entry.wins}V ${entry.draws}E ${entry.losses}D',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: OnzeColors.textSecondary,
                      ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Tab: Ranking por periodo (quincenal / mensual)
// ---------------------------------------------------------------------------

class _PeriodTab extends ConsumerWidget {
  const _PeriodTab({required this.provider});

  final FutureProvider<List<RankingSnapshot>> provider;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(provider);

    return async.when(
      loading: () =>
          const Center(child: CircularProgressIndicator(color: OnzeColors.accent)),
      error: (e, _) => _ErrorView(message: e.toString()),
      data: (snapshots) {
        if (snapshots.isEmpty) {
          return const _EmptyView(
              message:
                  'Todavía no hay snapshots de este periodo.\nSe generan al cerrar cada periodo.');
        }

        final period = snapshots.first;
        return RefreshIndicator(
          color: OnzeColors.accent,
          onRefresh: () async => ref.invalidate(provider),
          child: Column(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                    horizontal: 20, vertical: 12),
                color: OnzeColors.surface,
                child: Text(
                  period.periodLabel,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: OnzeColors.textSecondary,
                      ),
                ),
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
                  itemCount: snapshots.length,
                  itemBuilder: (context, i) =>
                      _PeriodRankCard(snapshot: snapshots[i]),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _PeriodRankCard extends StatelessWidget {
  const _PeriodRankCard({required this.snapshot});
  final RankingSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final tier = EloTier.fromRating(snapshot.eloAtPeriod);
    final isTop3 = snapshot.rankPosition <= 3;
    final teamName = snapshot.teamName.isNotEmpty
        ? snapshot.teamName
        : 'Equipo ${snapshot.teamId.substring(0, 6)}';

    return GestureDetector(
      onTap: () => context.push(AppRoutes.teamDetail(snapshot.teamId)),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: OnzeColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isTop3
                ? tier.color.withValues(alpha: 0.4)
                : OnzeColors.border,
          ),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 36,
              child: Text(
                '#${snapshot.rankPosition}',
                style: GoogleFonts.inter(
                  fontSize: isTop3 ? 18 : 14,
                  fontWeight: FontWeight.w900,
                  color: isTop3 ? tier.color : OnzeColors.textSecondary,
                ),
              ),
            ),
            const SizedBox(width: 10),
            OnzeAvatar(
              imageUrl: snapshot.teamShieldUrl,
              name: teamName,
              radius: 18,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    teamName,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Row(
                    children: [
                      Text(tier.emoji,
                          style: const TextStyle(fontSize: 11)),
                      const SizedBox(width: 3),
                      Text(tier.label,
                          style: TextStyle(
                              fontSize: 11,
                              color: tier.color,
                              fontWeight: FontWeight.w600)),
                    ],
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${snapshot.eloAtPeriod} ELO',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: tier.color,
                  ),
                ),
                Text(
                  '${snapshot.winsInPeriod}V / ${snapshot.matchesInPeriod}P',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: OnzeColors.textSecondary,
                      ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
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
          style: Theme.of(context)
              .textTheme
              .bodyMedium
              ?.copyWith(color: OnzeColors.textSecondary),
          textAlign: TextAlign.center,
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
