import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/routing/app_router.dart';
import '../../../../core/theme/onze_colors.dart';
import '../../../../features/auth/presentation/providers/auth_providers.dart';
import '../../../../shared/models/app_user.dart';
import '../../../../shared/widgets/onze_avatar.dart';
import '../../../../shared/widgets/onze_button.dart';
import '../../../../shared/widgets/onze_card.dart';
import '../../domain/models/player_profile.dart';
import '../providers/profile_providers.dart';
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
        title: const Text('Mi perfil'),
        actions: [
          userAsync.whenOrNull(
                data: (user) => user != null
                    ? IconButton(
                        icon: const Icon(Icons.edit_outlined),
                        tooltip: 'Editar perfil',
                        onPressed: () {
                          final profile = profileAsync.valueOrNull;
                          context.push(
                            AppRoutes.editProfile,
                            extra: EditProfileArgs(
                              user: user,
                              profile: profile,
                            ),
                          );
                        },
                      )
                    : null,
              ) ??
              const SizedBox.shrink(),
        ],
      ),
      body: userAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _ErrorView(message: e.toString()),
        data: (user) {
          if (user == null) return const SizedBox.shrink();
          return _ProfileContent(
            user: user,
            profileAsync: profileAsync,
            statsAsync: statsAsync,
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Contenido del perfil
// ---------------------------------------------------------------------------

class _ProfileContent extends ConsumerWidget {
  const _ProfileContent({
    required this.user,
    required this.profileAsync,
    required this.statsAsync,
  });

  final AppUser user;
  final AsyncValue<PlayerProfile?> profileAsync;
  final AsyncValue<dynamic> statsAsync;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 32),
          _buildAvatarSection(context, user),
          const SizedBox(height: 32),
          _buildStatsSection(context),
          const SizedBox(height: 32),
          _buildSportsSection(context),
          const SizedBox(height: 32),
          _buildBioSection(context),
          const SizedBox(height: 32),
          _buildAccountSection(context, ref),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildAvatarSection(BuildContext context, AppUser user) {
    return Center(
      child: Column(
        children: [
          OnzeAvatar(
            imageUrl: user.avatarUrl,
            name: user.fullName,
            radius: 48,
          ),
          const SizedBox(height: 16),
          Text(
            user.fullName,
            style: Theme.of(context).textTheme.displayLarge?.copyWith(
                  fontSize: 22,
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            user.phone.replaceFirst('+593', '0'),
            style: Theme.of(context).textTheme.bodySmall,
          ),
          if (user.isSuspended) ...[
            const SizedBox(height: 8),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: OnzeColors.error.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Text(
                'Cuenta suspendida',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: OnzeColors.error,
                    ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatsSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle(context, 'Estadísticas'),
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
            _sectionTitle(context, 'Datos deportivos'),
            const SizedBox(height: 12),
            OnzeCard(
              child: Column(
                children: [
                  if (profile.position != null)
                    _InfoRow(
                      icon: Icons.sports_soccer,
                      label: 'Posición',
                      value: profile.position!.label,
                    ),
                  if (profile.dominantFoot != null) ...[
                    const Divider(height: 1),
                    _InfoRow(
                      icon: Icons.sports,
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
                _sectionTitle(context, 'Sobre mí'),
                const SizedBox(height: 12),
                OnzeCard(
                  child: Text(
                    bio,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                ),
              ],
            );
          },
        ) ??
        const SizedBox.shrink();
  }

  Widget _buildAccountSection(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle(context, 'Cuenta'),
        const SizedBox(height: 12),
        OnzeButton(
          label: 'Cerrar sesión',
          onPressed: () async {
            await ref.read(authRepositoryProvider).signOut();
          },
          icon: Icons.logout,
        ),
      ],
    );
  }

  Widget _sectionTitle(BuildContext context, String title) {
    return Text(
      title,
      style: Theme.of(context).textTheme.headlineMedium,
    );
  }
}

// ---------------------------------------------------------------------------
// Widgets auxiliares
// ---------------------------------------------------------------------------

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
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Icon(icon, size: 18, color: OnzeColors.textSecondary),
          const SizedBox(width: 12),
          Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: OnzeColors.textSecondary,
                ),
          ),
          const Spacer(),
          Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
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

