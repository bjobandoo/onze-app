// Widget de fila para solicitudes/invitaciones de equipo.

import 'package:flutter/material.dart';

import '../../../../core/theme/onze_colors.dart';
import '../../../../shared/widgets/onze_avatar.dart';
import '../../domain/models/team_join_request.dart';

/// Fila que muestra una [TeamJoinRequest] con botones de aceptar/rechazar.
class JoinRequestTile extends StatelessWidget {
  const JoinRequestTile({
    super.key,
    required this.request,
    required this.onAccept,
    required this.onReject,
  });

  final TeamJoinRequest request;
  final VoidCallback onAccept;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    final name = request.userFullName ?? request.teamName ?? 'Desconocido';
    final avatarUrl = request.userAvatarUrl;

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: OnzeAvatar(
        imageUrl: avatarUrl,
        name: name,
        radius: 20,
      ),
      title: Text(
        name,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w500,
            ),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.check_circle_outline,
                color: OnzeColors.highlight),
            tooltip: 'Aceptar',
            onPressed: onAccept,
          ),
          IconButton(
            icon: const Icon(Icons.cancel_outlined, color: OnzeColors.error),
            tooltip: 'Rechazar',
            onPressed: onReject,
          ),
        ],
      ),
    );
  }
}
