// Pantalla de búsqueda de usuarios para invitar a un equipo.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/onze_colors.dart';
import '../../../../features/auth/presentation/providers/auth_providers.dart';
import '../../../../shared/widgets/onze_avatar.dart';
import '../providers/teams_providers.dart';

/// Pantalla de búsqueda de usuarios para que el capitán invite miembros.
///
/// Recibe [teamId] para enviar la invitación directamente desde aquí.
/// Recibe [memberIds] con los IDs de los miembros actuales para marcarlos.
class UserSearchScreen extends ConsumerStatefulWidget {
  const UserSearchScreen({
    super.key,
    required this.teamId,
    required this.memberIds,
  });

  final String teamId;

  /// IDs de usuarios que ya son miembros del equipo.
  final Set<String> memberIds;

  @override
  ConsumerState<UserSearchScreen> createState() => _UserSearchScreenState();
}

class _UserSearchScreenState extends ConsumerState<UserSearchScreen> {
  late final TextEditingController _controller;
  late final UserSearchArgs _args;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    final currentUserId =
        ref.read(currentUserProvider).valueOrNull?.id ?? '';
    _args = (teamId: widget.teamId, currentUserId: currentUserId);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final searchState = ref.watch(userSearchProvider(_args));

    return Scaffold(
      appBar: AppBar(
        title: _SearchField(
          controller: _controller,
          onChanged: (q) =>
              ref.read(userSearchProvider(_args).notifier).setQuery(q),
        ),
      ),
      body: _buildBody(context, ref, searchState),
    );
  }

  Widget _buildBody(
      BuildContext context, WidgetRef ref, UserSearchState state) {
    if (state.isEmpty) {
      return const _HintView(
        message: 'Busca por @usuario o número de teléfono.',
      );
    }

    if (state.isLoading) {
      return const Center(child: CircularProgressIndicator(color: OnzeColors.accent));
    }

    if (state.hasError) {
      return _HintView(message: state.errorMessage!, isError: true);
    }

    if (state.results.isEmpty) {
      return const _HintView(
          message: 'No se encontraron jugadores con ese usuario o teléfono.');
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: state.results.length,
      separatorBuilder: (_, _) =>
          const Divider(height: 1, indent: 72, color: OnzeColors.border),
      itemBuilder: (context, index) {
        final user = state.results[index];
        final isMember = widget.memberIds.contains(user.id);
        final isInvited = state.invitedIds.contains(user.id);

        return _UserResultTile(
          avatarUrl: user.avatarUrl,
          fullName: user.fullName,
          username: user.username,
          phone: user.phone,
          isMember: isMember,
          isInvited: isInvited,
          onInvite: isMember || isInvited
              ? null
              : () => ref
                  .read(userSearchProvider(_args).notifier)
                  .invite(user.id),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Widgets internos
// ---------------------------------------------------------------------------

class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.controller,
    required this.onChanged,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      autofocus: true,
      onChanged: onChanged,
      style: Theme.of(context).textTheme.bodyLarge,
      decoration: InputDecoration(
        hintText: '@usuario o teléfono…',
        hintStyle: Theme.of(context)
            .textTheme
            .bodyLarge
            ?.copyWith(color: OnzeColors.textSecondary),
        border: InputBorder.none,
        suffixIcon: controller.text.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.clear, color: OnzeColors.textSecondary),
                onPressed: () {
                  controller.clear();
                  onChanged('');
                },
              )
            : null,
      ),
    );
  }
}

class _UserResultTile extends StatelessWidget {
  const _UserResultTile({
    required this.avatarUrl,
    required this.fullName,
    required this.username,
    required this.phone,
    required this.isMember,
    required this.isInvited,
    required this.onInvite,
  });

  final String? avatarUrl;
  final String fullName;
  final String? username;
  final String phone;
  final bool isMember;
  final bool isInvited;
  final VoidCallback? onInvite;

  String get _subtitle {
    if (username != null && username!.isNotEmpty) return '@$username';
    if (phone.startsWith('+593')) return '0${phone.substring(4)}';
    return phone;
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: OnzeAvatar(imageUrl: avatarUrl, name: fullName, radius: 22),
      title: Text(
        fullName,
        style: Theme.of(context)
            .textTheme
            .bodyMedium
            ?.copyWith(fontWeight: FontWeight.w500),
      ),
      subtitle: Text(
        _subtitle,
        style: Theme.of(context)
            .textTheme
            .bodySmall
            ?.copyWith(color: OnzeColors.textSecondary),
      ),
      trailing: _buildTrailing(context),
    );
  }

  Widget _buildTrailing(BuildContext context) {
    if (isMember) {
      return const _StatusChip(
        label: 'Miembro',
        color: OnzeColors.textSecondary,
      );
    }
    if (isInvited) {
      return const _StatusChip(
        label: 'Enviada ✓',
        color: OnzeColors.highlight,
      );
    }
    return TextButton(
      onPressed: onInvite,
      child: const Text('Invitar'),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}

class _HintView extends StatelessWidget {
  const _HintView({required this.message, this.isError = false});
  final String message;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Text(
          message,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: isError ? OnzeColors.error : OnzeColors.textSecondary,
              ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
