import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/routing/app_router.dart';
import '../../../../core/theme/onze_colors.dart';
import '../../../../core/theme/onze_theme.dart';
import '../../../../features/auth/presentation/providers/auth_providers.dart';
import '../../../../features/matches/presentation/providers/matches_providers.dart';
import '../../../../shared/widgets/onze_pressable.dart';
import '../widgets/nearby_fields_section.dart';
import '../widgets/next_match_card.dart';
import '../widgets/team_rank_card.dart';

/// Pantalla de inicio — resumen de la actividad del jugador.
///
/// La navegación principal vive en el dock flotante ([OnzeShell]);
/// el Home muestra próximo partido, canchas cercanas y mini-ranking.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(currentUserProvider);
    final isOwner = userAsync.valueOrNull?.isOwner ?? false;
    final userName = userAsync.valueOrNull?.fullName ?? '';

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _HomeHeader(userName: userName),
            _PendingReportBanner(),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
                children: [
                  const NextMatchCard(),
                  const SizedBox(height: 20),
                  const NearbyFieldsSection(),
                  const SizedBox(height: 20),
                  const TeamRankCard(),
                  const SizedBox(height: 12),
                  _OwnerCard(isOwner: isOwner),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Header
// ---------------------------------------------------------------------------

class _HomeHeader extends StatelessWidget {
  const _HomeHeader({required this.userName});

  final String userName;

  @override
  Widget build(BuildContext context) {
    final String greeting = userName.isNotEmpty
        ? 'Hola, ${userName.split(' ').first}'
        : 'Bienvenido';

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 16, 14),
      child: Row(
        children: [
          Image.asset(
            'assets/images/onze_mark.png',
            height: 38,
            errorBuilder: (_, _, _) => const SizedBox.shrink(),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'ONZE',
                  style: GoogleFonts.barlowCondensed(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 3.0,
                    color: OnzeColors.highlight,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  greeting,
                  style: GoogleFonts.barlowCondensed(
                    fontSize: 30,
                    fontWeight: FontWeight.w600,
                    height: 1.05,
                    color: OnzeColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          OnzePressable(
            child: GestureDetector(
              onTap: () => context.go(AppRoutes.profile),
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(OnzeTheme.radiusPill),
                  border: Border.all(color: OnzeColors.border),
                ),
                child: const Icon(Icons.person_outline,
                    color: OnzeColors.textSecondary, size: 21),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Banner de bloqueo — partidos pendientes de reporte
// ---------------------------------------------------------------------------

/// Banner prominente que aparece cuando el capitán tiene partidos sin reportar.
/// No se puede descartar — el usuario debe ir a reportar.
class _PendingReportBanner extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pendingAsync = ref.watch(pendingMyReportProvider);
    final count = pendingAsync.valueOrNull?.length ?? 0;
    if (count == 0) return const SizedBox.shrink();

    return GestureDetector(
      onTap: () => context.go(AppRoutes.matchRequests),
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.fromLTRB(20, 0, 20, 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: OnzeColors.error.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(OnzeTheme.radiusRow),
          border: Border.all(
              color: OnzeColors.error.withValues(alpha: 0.5)),
        ),
        child: Row(
          children: [
            const Icon(Icons.warning_amber_rounded,
                color: OnzeColors.error, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    count == 1
                        ? '1 partido pendiente de reportar'
                        : '$count partidos pendientes de reportar',
                    style: GoogleFonts.barlow(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: OnzeColors.error,
                    ),
                  ),
                  Text(
                    'Tienes 24h para reportar el resultado.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: OnzeColors.error.withValues(alpha: 0.8),
                        ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios,
                color: OnzeColors.error, size: 14),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Card de gestión de canchas (dueño)
// ---------------------------------------------------------------------------

class _OwnerCard extends StatelessWidget {
  const _OwnerCard({required this.isOwner});

  final bool isOwner;

  @override
  Widget build(BuildContext context) {
    return OnzePressable(
      child: GestureDetector(
        onTap: () => context.push(AppRoutes.ownerFields),
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          decoration: BoxDecoration(
            color: OnzeColors.surface,
            borderRadius: BorderRadius.circular(OnzeTheme.radiusCard),
            border: Border.all(color: OnzeColors.border),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: OnzeColors.greenGlow,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: const Icon(Icons.stadium_outlined,
                    color: OnzeColors.highlight, size: 21),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isOwner ? 'Mis canchas' : 'Registrar cancha',
                      style: GoogleFonts.barlowCondensed(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                        color: OnzeColors.textPrimary,
                      ),
                    ),
                    Text(
                      isOwner
                          ? 'Administra tus canchas y horarios'
                          : '¿Tienes canchas? Publícalas en Onze',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right,
                  color: OnzeColors.textDim, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}
