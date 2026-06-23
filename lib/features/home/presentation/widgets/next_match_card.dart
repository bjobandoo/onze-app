// Card "Próximo partido" del Home — estilo Stadium Night.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/routing/app_router.dart';
import '../../../../core/theme/onze_colors.dart';
import '../../../../core/theme/onze_theme.dart';
import '../../../../features/matches/domain/models/match.dart';
import '../../../../features/matches/presentation/providers/matches_providers.dart';
import '../../../../shared/widgets/onze_avatar.dart';
import '../../../../shared/widgets/onze_pressable.dart';

/// Muestra el próximo partido programado del usuario (capitán) o,
/// si no hay ninguno, una invitación a enviar un desafío.
class NextMatchCard extends ConsumerWidget {
  const NextMatchCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(upcomingMatchProvider);
    final match = async.valueOrNull;

    final Widget body = match != null
        ? _MatchBody(match: match)
        : const _EmptyBody();

    return OnzePressable(
      child: GestureDetector(
        onTap: () => context.go(AppRoutes.matchRequests),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: OnzeColors.surface,
            borderRadius: BorderRadius.circular(OnzeTheme.radiusCard),
            border: Border.all(color: OnzeColors.border),
          ),
          child: body,
        ),
      ),
    );
  }
}

class _MatchBody extends StatelessWidget {
  const _MatchBody({required this.match});

  final Match match;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('PRÓXIMO PARTIDO',
            style: Theme.of(context).textTheme.labelSmall),
        const SizedBox(height: 14),
        Row(
          children: [
            _TeamColumn(name: match.teamAName, shieldUrl: match.teamAShieldUrl),
            Expanded(
              child: Column(
                children: [
                  Text(
                    match.timeRange.split(' ').first,
                    style: GoogleFonts.barlowCondensed(
                      fontSize: 32,
                      fontWeight: FontWeight.w700,
                      height: 1,
                      color: OnzeColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    match.dateLabel.toUpperCase(),
                    style: GoogleFonts.barlowCondensed(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.6,
                      color: OnzeColors.highlight,
                    ),
                  ),
                ],
              ),
            ),
            match.isFriendly
                ? const _TeamColumn(name: 'Amistoso', shieldUrl: null)
                : _TeamColumn(
                    name: match.teamBName, shieldUrl: match.teamBShieldUrl),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.place_outlined,
                color: OnzeColors.textSecondary, size: 15),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                match.fieldName,
                style: Theme.of(context).textTheme.bodySmall,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _TeamColumn extends StatelessWidget {
  const _TeamColumn({required this.name, this.shieldUrl});

  final String name;
  final String? shieldUrl;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 92,
      child: Column(
        children: [
          OnzeAvatar(imageUrl: shieldUrl, name: name, radius: 26),
          const SizedBox(height: 7),
          Text(
            name,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: OnzeColors.textPrimary,
                  fontWeight: FontWeight.w600,
                  fontSize: 12.5,
                ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _EmptyBody extends StatelessWidget {
  const _EmptyBody();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('PRÓXIMO PARTIDO',
            style: Theme.of(context).textTheme.labelSmall),
        const SizedBox(height: 10),
        Text(
          'No tienes partidos programados.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: OnzeColors.textSecondary,
              ),
        ),
        const SizedBox(height: 14),
        Align(
          alignment: Alignment.centerLeft,
          child: GestureDetector(
            onTap: () => context.push(AppRoutes.sendChallenge),
            child: Container(
              height: 40,
              padding: const EdgeInsets.symmetric(horizontal: 18),
              decoration: BoxDecoration(
                color: OnzeColors.highlight,
                borderRadius: BorderRadius.circular(OnzeTheme.radiusPill),
              ),
              alignment: Alignment.center,
              child: Text(
                'ENVIAR DESAFÍO',
                style: GoogleFonts.barlowCondensed(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                  color: OnzeColors.onAccent,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
