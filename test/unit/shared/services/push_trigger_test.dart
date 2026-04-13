import 'package:flutter_test/flutter_test.dart';

import 'package:onze_app/shared/services/push_trigger.dart';

void main() {
  // ---------------------------------------------------------------------------
  // PushEvent — constantes
  // ---------------------------------------------------------------------------

  group('PushEvent', () {
    test('tiene el valor correcto para challenge_received', () {
      expect(PushEvent.challengeReceived, 'challenge_received');
    });

    test('tiene el valor correcto para challenge_accepted', () {
      expect(PushEvent.challengeAccepted, 'challenge_accepted');
    });

    test('tiene el valor correcto para challenge_rejected', () {
      expect(PushEvent.challengeRejected, 'challenge_rejected');
    });

    test('tiene el valor correcto para match_confirmed', () {
      expect(PushEvent.matchConfirmed, 'match_confirmed');
    });

    test('tiene el valor correcto para match_rejected_owner', () {
      expect(PushEvent.matchRejectedOwner, 'match_rejected_owner');
    });

    test('tiene el valor correcto para team_invitation', () {
      expect(PushEvent.teamInvitation, 'team_invitation');
    });

    test('todos los eventos son únicos', () {
      final all = [
        PushEvent.challengeReceived,
        PushEvent.challengeAccepted,
        PushEvent.challengeRejected,
        PushEvent.matchConfirmed,
        PushEvent.matchRejectedOwner,
        PushEvent.teamInvitation,
      ];
      expect(all.toSet().length, all.length);
    });
  });
}
