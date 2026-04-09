import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/routing/app_router.dart';
import '../../../../core/theme/onze_colors.dart';
import '../../../../features/auth/presentation/providers/auth_providers.dart';
import '../../../../shared/models/app_user.dart';
import '../../../../shared/widgets/onze_button.dart';
import '../../domain/models/player_profile.dart';
import '../providers/profile_providers.dart';
import '../widgets/profile_avatar_picker.dart';
import '../widgets/profile_stats_row.dart';
import 'edit_profile_screen.dart';

/// Pantalla de perfil del jugador autenticado.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(currentUserProvider);
    final profileAsync = ref.watch(myProfileProvider);
    final statsAsync = ref.watch(myStatsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('MI PERFIL'),
        actions: [
          userAsync.whenOrNull(
                data: (user) => user != null
                    ? IconButton(
                        icon: const Icon(Icons.edit_outlined),
                        tooltip: 'Editar perfil',
                        onPressed: () => context.push(
                          AppRoutes.editProfile,
                          extra: EditProfileArgs(
                            user: user,
                            profile: profileAsync.valueOrNull,
                          ),
                        ),
                      )
                    : null,
              ) ??
              const SizedBox.shrink(),
        ],
      ),
      body: userAsync.when(
        loading: () =>
            const Center(child: CircularProgressIndicator()),
        error: (e, _) => _ErrorView(message: e.toString()),
        data: (user) {
          if (user == null) return const SizedBox.shrink();
          return _ProfileContent(
            user: user,
            profileAsync: profileAsync,
            statsAsync: statsAsync,
            ref: ref,
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Contenido del perfil
// ---------------------------------------------------------------------------

class _ProfileContent extends StatelessWidget {
  const _ProfileContent({
    required this.user,
    required this.profileAsync,
    required this.statsAsync,
    required this.ref,
  });

  final AppUser user;
  final AsyncValue<PlayerProfile?> profileAsync;
  final AsyncValue<dynamic> statsAsync;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildGradientHeader(context),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 28),
                _buildStatsSection(context),
                const SizedBox(height: 28),
                _buildSportsSection(context),
                const SizedBox(height: 28),
                _buildBioSection(context),
                const SizedBox(height: 28),
                _buildAccountSection(context),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGradientHeader(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 28),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF092009), Color(0xFF000000)],
          stops: [0.0, 0.85],
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _buildAvatar(),
          const SizedBox(width: 20),
          Expanded(child: _buildUserInfo(context)),
        ],
      ),
    );
  }

  Widget _buildAvatar() {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: OnzeColors.highlight, width: 2),
      ),
      child: ProfileAvatarPicker(
        userId: user.id,
        imageUrl: user.avatarUrl,
        name: user.fullName,
        radius: 44,
        onAvatarChanged: () => ref.invalidate(currentUserProvider),
      ),
    );
  }

  Widget _buildUserInfo(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          user.fullName.toUpperCase(),
          style: GoogleFonts.inter(
            fontSize: 20,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.5,
            color: OnzeColors.textPrimary,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 4),
        Text(
          user.phone.replaceFirst('+593', '0'),
          style: Theme.of(context).textTheme.bodySmall,
        ),
        if (user.isSuspended) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: BoxDecoration(
              color: OnzeColors.error.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: OnzeColors.error.withValues(alpha: 0.4),
              ),
            ),
            child: Text(
              'SUSPENDIDO',
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.5,
                color: OnzeColors.error,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildStatsSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionLabel('ESTADÍSTICAS'),
        const SizedBox(height: 12),
        statsAsync.when(
          loading: () => const LinearProgressIndicator(),
          error: (e, _) => const SizedBox.shrink(),
          data: (stats) => ProfileStatsRow(stats: stats),
        ),
      ],
    );
  }

  Widget _buildSportsSection(BuildContext context) {
    return profileAsync.when(
      loading: () => const LinearProgressIndicator(),
      error: (e, _) => const SizedBox.shrink(),
      data: (profile) {
        if (profile == null) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _SectionLabel('DATOS DEPORTIVOS'),
            const SizedBox(height: 12),
            _DataCard(
              children: [
                if (profile.position != null)
                  _InfoRow(
                    icon: Icons.sports_soccer_outlined,
                    label: 'Posición',
                    value: profile.position!.label,
                  ),
                if (profile.dominantFoot != null) ...[
                  const Divider(height: 1),
                  _InfoRow(
                    icon: Icons.sports_outlined,
                    label: 'Pie hábil',
                    value: profile.dominantFoot!.label,
                  ),
                ],
                if (profile.experienceLevel != null) ...[
                  const Divider(height: 1),
                  _InfoRow(
                    icon: Icons.bar_chart,
                    label: 'Experiencia',
                    value: profile.experienceLevel!.label,
                  ),
                ],
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _buildBioSection(BuildContext context) {
    return profileAsync.whenOrNull(
          data: (profile) {
            final bio = profile?.bio;
            if (bio == null || bio.isEmpty) return null;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _SectionLabel('SOBRE MÍ'),
                const SizedBox(height: 12),
                _DataCard(
                  children: [
                    Text(
                      bio,
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  ],
                ),
              ],
            );
          },
        ) ??
        const SizedBox.shrink();
  }

  Widget _buildAccountSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionLabel('CUENTA'),
        const SizedBox(height: 12),
        OnzeButton(
          label: 'Cerrar sesión',
          icon: Icons.logout,
          variant: OnzeButtonVariant.outline,
          onPressed: () async {
            await ref.read(authRepositoryProvider).signOut();
          },
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Widgets auxiliares
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

class _DataCard extends StatelessWidget {
  const _DataCard({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: OnzeColors.surfaceHigh,
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: children,
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        children: [
          Icon(icon, size: 16, color: OnzeColors.textSecondary),
          const SizedBox(width: 12),
          Text(
            label,
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: OnzeColors.textSecondary),
          ),
          const Spacer(),
          Text(
            value,
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
        ],
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
