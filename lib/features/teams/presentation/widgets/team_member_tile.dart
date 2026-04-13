// Widget de fila para mostrar un miembro del equipo.

import 'package:flutter/material.dart';

import '../../../../core/theme/onze_colors.dart';
import '../../../../shared/widgets/onze_avatar.dart';
import '../../domain/models/team_member.dart';

/// Fila de lista que muestra info de un [TeamMember].
class TeamMemberTile extends StatelessWidget {
  const TeamMemberTile({
    super.key,
    required this.member,
    this.onRemove,
  });

  final TeamMember member;

  /// Si no es null, muestra el botón de expulsar (solo capitán).
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: OnzeAvatar(
        imageUrl: member.userAvatarUrl,
        name: member.userFullName,
        radius: 20,
      ),
      title: Text(
        member.userFullName,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w500,
            ),
      ),
      subtitle: Text(
        member.role.label,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: member.isCaptain
                  ? OnzeColors.highlight
                  : OnzeColors.textSecondary,
            ),
      ),
      trailing: onRemove != null && !member.isCaptain
          ? IconButton(
              icon: const Icon(Icons.remove_circle_outline,
                  color: OnzeColors.error),
              tooltip: 'Expulsar',
              onPressed: onRemove,
            )
          : null,
    );
  }
}
