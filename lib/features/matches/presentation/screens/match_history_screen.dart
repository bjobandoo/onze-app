// Pantalla de historial de partidos del usuario (todos sus equipos).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/onze_colors.dart';
import '../../../../shared/widgets/onze_avatar.dart';
import '../../domain/models/match.dart';
import '../providers/matches_providers.dart';

/// Lista los partidos finalizados de todos los equipos del usuario.
/// Distingue partidos oficiales (con resultado) de amistosos (badge, sin marcador).
class MatchHistoryScreen extends ConsumerWidget {
  const MatchHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(matchHistoryProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Historial de partidos')),
      body: historyAsync.when(
        loading: () => const Center(
            child: CircularProgressIndicator(color: OnzeColors.accent)),
        error: (e, _) => _ErrorView(message: e.toString()),
        data: (matches) {
          if (matches.isEmpty) {
            return const _EmptyView(
                message: 'Aún no tienes partidos en tu historial.');
          }
          return RefreshIndicator(
            color: OnzeColors.accent,
            onRefresh: () async {
              ref.invalidate(matchHistoryProvider);
              await ref.read(matchHistoryProvider.future);
            },
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
              itemCount: matches.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, index) =>
                  _HistoryCard(match: matches[index]),
            ),
          );
        },
      ),
    );
  }
}

class _HistoryCard extends StatelessWidget {
  const _HistoryCard({required this.match});

  final Match match;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: OnzeColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: OnzeColors.border),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: match.isFriendly
                ? _buildFriendlyHeader(context)
                : _buildVersusHeader(context),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: OnzeColors.border)),
            ),
            child: Row(
              children: [
                const Icon(Icons.calendar_today_outlined,
                    size: 13, color: OnzeColors.textSecondary),
                const SizedBox(width: 4),
                Text(match.dateLabel,
                    style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(width: 12),
                const Icon(Icons.access_time_outlined,
                    size: 13, color: OnzeColors.textSecondary),
                const SizedBox(width: 4),
                Text(match.timeRange,
                    style: Theme.of(context).textTheme.bodySmall),
                const Spacer(),
                if (!match.isFriendly && match.finalResult != null)
                  _FinalResultChip(result: match.finalResult!)
                else if (match.status == MatchStatus.cancelled)
                  Text('Cancelado',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: OnzeColors.textSecondary,
                          )),
              ],
            ),
          ),
          if (match.fieldName.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  match.fieldName,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: OnzeColors.textSecondary,
                      ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildVersusHeader(BuildContext context) {
    return Row(
      children: [
        _MiniTeam(name: match.teamAName, shieldUrl: match.teamAShieldUrl),
        Expanded(
          child: Text(
            'VS',
            textAlign: TextAlign.center,
            style: GoogleFonts.barlowCondensed(
              fontSize: 13,
              fontWeight: FontWeight.w900,
              color: OnzeColors.textSecondary,
            ),
          ),
        ),
        _MiniTeam(name: match.teamBName, shieldUrl: match.teamBShieldUrl),
      ],
    );
  }

  Widget _buildFriendlyHeader(BuildContext context) {
    return Row(
      children: [
        _MiniTeam(name: match.teamAName, shieldUrl: match.teamAShieldUrl),
        const Expanded(child: Center(child: _FriendlyChip())),
        const SizedBox(width: 80),
      ],
    );
  }
}

class _MiniTeam extends StatelessWidget {
  const _MiniTeam({required this.name, this.shieldUrl});
  final String name;
  final String? shieldUrl;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 80,
      child: Column(
        children: [
          OnzeAvatar(imageUrl: shieldUrl, name: name, radius: 22),
          const SizedBox(height: 4),
          Text(
            name,
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(fontWeight: FontWeight.w600),
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
            maxLines: 2,
          ),
        ],
      ),
    );
  }
}

class _FriendlyChip extends StatelessWidget {
  const _FriendlyChip();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: OnzeColors.highlight.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: OnzeColors.highlight.withValues(alpha: 0.4)),
      ),
      child: const Text(
        'Amistoso',
        style: TextStyle(
            fontSize: 10,
            color: OnzeColors.highlight,
            fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _FinalResultChip extends StatelessWidget {
  const _FinalResultChip({required this.result});
  final MatchFinalResult result;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: OnzeColors.accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Text(
        result.label,
        style: const TextStyle(
            fontSize: 10,
            color: OnzeColors.accent,
            fontWeight: FontWeight.w600),
      ),
    );
  }
}

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
