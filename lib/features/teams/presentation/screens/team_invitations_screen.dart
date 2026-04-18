// Pantalla de invitaciones pendientes recibidas por el usuario.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/onze_exception.dart';
import '../../../../core/theme/onze_colors.dart';
import '../../../../core/utils/logger.dart';
import '../providers/teams_providers.dart';
import '../widgets/join_request_tile.dart';

/// Pantalla con las invitaciones pendientes que el usuario ha recibido.
class TeamInvitationsScreen extends ConsumerStatefulWidget {
  const TeamInvitationsScreen({super.key});

  @override
  ConsumerState<TeamInvitationsScreen> createState() =>
      _TeamInvitationsScreenState();
}

class _TeamInvitationsScreenState extends ConsumerState<TeamInvitationsScreen> {
  @override
  void initState() {
    super.initState();
    // Siempre refrescar al abrir la pantalla para mostrar invitaciones recientes.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.invalidate(myPendingInvitationsProvider);
    });
  }

  @override
  Widget build(BuildContext context) {
    final invitationsAsync = ref.watch(myPendingInvitationsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Invitaciones')),
      body: invitationsAsync.when(
        loading: () =>
            const Center(child: CircularProgressIndicator(color: OnzeColors.accent)),
        error: (e, _) => Center(
          child: Text(
            e.toString(),
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: OnzeColors.error),
          ),
        ),
        data: (invitations) {
          if (invitations.isEmpty) {
            return RefreshIndicator(
              color: OnzeColors.accent,
              onRefresh: () async =>
                  ref.invalidate(myPendingInvitationsProvider),
              child: ListView(
                children: [
                  SizedBox(
                    height: MediaQuery.of(context).size.height * 0.5,
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.mail_outline,
                              size: 64, color: OnzeColors.textSecondary),
                          const SizedBox(height: 16),
                          Text(
                            'Sin invitaciones pendientes',
                            style:
                                Theme.of(context).textTheme.bodyLarge?.copyWith(
                                      color: OnzeColors.textSecondary,
                                    ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            color: OnzeColors.accent,
            onRefresh: () async => ref.invalidate(myPendingInvitationsProvider),
            child: ListView.separated(
              padding: const EdgeInsets.all(24),
              itemCount: invitations.length,
              separatorBuilder: (_, _) =>
                  const Divider(height: 1, color: OnzeColors.border),
              itemBuilder: (context, index) {
                final invitation = invitations[index];
                return JoinRequestTile(
                  request: invitation,
                  onAccept: () =>
                      _respond(context, invitation.id, accept: true),
                  onReject: () =>
                      _respond(context, invitation.id, accept: false),
                );
              },
            ),
          );
        },
      ),
    );
  }

  Future<void> _respond(
    BuildContext context,
    String requestId, {
    required bool accept,
  }) async {
    try {
      final repo = ref.read(teamsRepositoryProvider);
      if (accept) {
        await repo.acceptJoinRequest(requestId);
        ref.invalidate(myTeamsProvider);
      } else {
        await repo.rejectJoinRequest(requestId);
      }
      ref.invalidate(myPendingInvitationsProvider);

      if (!context.mounted) return;
      final msg = accept ? 'Te uniste al equipo.' : 'Invitación rechazada.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg),
          backgroundColor:
              accept ? OnzeColors.accent : OnzeColors.textSecondary,
        ),
      );
    } on OnzeException catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(e.message), backgroundColor: OnzeColors.error),
      );
    } catch (e, st) {
      log.e('Error al responder invitación', error: e, stackTrace: st);
    }
  }
}
