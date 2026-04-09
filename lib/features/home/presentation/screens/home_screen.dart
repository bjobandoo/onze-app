import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/routing/app_router.dart';
import '../../../../core/theme/onze_colors.dart';
import '../../../../features/auth/presentation/providers/auth_providers.dart';

/// Pantalla de inicio — shell de navegación principal.
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
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
                children: [
                  const _SectionLabel('QUÉ QUIERES HACER'),
                  const SizedBox(height: 16),
                  _HomeCard(
                    icon: Icons.map_outlined,
                    title: 'Buscar canchas',
                    subtitle: 'Explora las canchas disponibles en Ibarra',
                    onTap: () => context.push(AppRoutes.fieldsMap),
                  ),
                  const SizedBox(height: 10),
                  _HomeCard(
                    icon: Icons.sports_soccer_outlined,
                    title: 'Desafíos',
                    subtitle: 'Envía y gestiona desafíos de partido',
                    onTap: () => context.push(AppRoutes.matchRequests),
                  ),
                  const SizedBox(height: 10),
                  _HomeCard(
                    icon: Icons.group_outlined,
                    title: 'Mis equipos',
                    subtitle: 'Crea y gestiona tus equipos de fútbol',
                    onTap: () => context.push(AppRoutes.teams),
                  ),
                  const SizedBox(height: 10),
                  _HomeCard(
                    icon: Icons.stadium_outlined,
                    title: isOwner ? 'Mis canchas' : 'Registrar cancha',
                    subtitle: isOwner
                        ? 'Administra tus canchas y horarios'
                        : '¿Tienes canchas? Publícalas en Onze',
                    onTap: () => context.push(AppRoutes.ownerFields),
                  ),
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
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 16, 20),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: OnzeColors.border, width: 1),
        ),
      ),
      child: Row(
        children: [
          Expanded(child: _buildGreeting(context)),
          IconButton(
            icon: const Icon(Icons.person_outline,
                color: OnzeColors.textPrimary, size: 26),
            tooltip: 'Mi perfil',
            onPressed: () => context.push(AppRoutes.profile),
          ),
        ],
      ),
    );
  }

  Widget _buildGreeting(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'ONZE',
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            letterSpacing: 3.0,
            color: OnzeColors.highlight,
          ),
        ),
        const SizedBox(height: 2),
        if (userName.isNotEmpty)
          Text(
            'HOLA, ${userName.toUpperCase().split(' ').first}',
            style: GoogleFonts.inter(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.5,
              color: OnzeColors.textPrimary,
            ),
          )
        else
          Text(
            'BIENVENIDO',
            style: GoogleFonts.inter(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.5,
              color: OnzeColors.textPrimary,
            ),
          ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Section label
// ---------------------------------------------------------------------------

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(context).textTheme.labelSmall,
    );
  }
}

// ---------------------------------------------------------------------------
// Card
// ---------------------------------------------------------------------------

class _HomeCard extends StatelessWidget {
  const _HomeCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: OnzeColors.surfaceHigh,
          borderRadius: BorderRadius.circular(12),
        ),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Barra verde izquierda
              Container(
                width: 4,
                decoration: const BoxDecoration(
                  color: OnzeColors.highlight,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(12),
                    bottomLeft: Radius.circular(12),
                  ),
                ),
              ),
              // Contenido
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 18,
                  ),
                  child: Row(
                    children: [
                      Icon(icon, color: OnzeColors.highlight, size: 26),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title.toUpperCase(),
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.0,
                                color: OnzeColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              subtitle,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(
                        Icons.arrow_forward,
                        color: OnzeColors.textSecondary,
                        size: 18,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
