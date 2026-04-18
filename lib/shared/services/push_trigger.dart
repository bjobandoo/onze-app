// Helper para disparar notificaciones push via Edge Function.
//
// Fire-and-forget: los errores se loggean pero no bloquean el flujo principal.
// La Edge Function `send-notification` resuelve los destinatarios en el servidor.

import '../../core/utils/logger.dart';
import 'supabase_service.dart';

/// Eventos reconocidos por la Edge Function `send-notification`.
abstract final class PushEvent {
  static const String challengeReceived = 'challenge_received';
  static const String challengeAccepted = 'challenge_accepted';
  static const String challengeRejected = 'challenge_rejected';
  static const String matchConfirmed = 'match_confirmed';
  static const String matchRejectedOwner = 'match_rejected_owner';
  static const String teamInvitation = 'team_invitation';

  /// Capitán reportó y los reportes no coinciden → dueño debe resolver.
  static const String matchDisputed = 'match_disputed';

  /// Dueño resolvió la disputa → notificar a ambos capitanes.
  static const String matchDisputeResolved = 'match_dispute_resolved';
}

/// Invoca la Edge Function `send-notification` de forma asíncrona sin bloquear.
///
/// [event] — tipo de evento (ver [PushEvent]).
/// [entityId] — ID de la entidad principal (match_request_id o team_id).
/// [extra] — datos adicionales opcionales (ej. targetUserId para invitaciones).
Future<void> triggerPushNotification(
  String event,
  String entityId, {
  Map<String, String>? extra,
}) async {
  try {
    await supabase.functions.invoke(
      'send-notification',
      body: {
        'event': event,
        'entityId': entityId,
        'extra': ?extra,
      },
    );
    log.d('Push enviado: event=$event entityId=$entityId');
  } catch (e) {
    // Best-effort: las notificaciones no deben bloquear acciones del usuario
    log.w('Push trigger fallido (event=$event): $e');
  }
}
