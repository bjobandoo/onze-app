// Widget de tarjeta de equipo para listados.

import 'package:flutter/material.dart';

import '../../../../core/theme/onze_colors.dart';
import '../../../../shared/widgets/onze_avatar.dart';
import '../../domain/models/team.dart';

/// Tarjeta compacta que muestra info básica de un [Team].
class TeamCard extends StatelessWidget {
  const TeamCard({
    super.key,
    required this.team,
    required this.onTap,
    this.isCaptain = false,
  });

  final Team team;
  final VoidCallback onTap;
  final bool isCaptain;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: OnzeColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: OnzeColors.border),
        ),
        child: Row(
          children: [
            OnzeAvatar(
              imageUrl: team.shieldUrl,
              name: team.name,
              radius: 24,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    team.name,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  if (isCaptain)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: OnzeColors.accent.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Text(
                        'Capitán',
                        style:
                            Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: OnzeColors.accent,
                                  fontWeight: FontWeight.w600,
                                ),
                      ),
                    ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right,
              color: OnzeColors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }
}
