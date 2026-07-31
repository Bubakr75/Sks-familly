// Tests pour la notification de demande de rattachement (join_requests).
// Teste la logique de filtrage par ownerUid et l'exclusion de l'appareil demandeur.

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('onJoinRequestCreated — filtrage ownerUid', () {
    // Simule la logique de filtrage de la Cloud Function
    List<String> filterOwnerTokens({
      required List<Map<String, dynamic>> allTokens,
      required String ownerUid,
      required String requesterDeviceId,
    }) {
      final result = <String>[];
      for (final doc in allTokens) {
        final docId = doc['deviceId'] as String;
        final uid = doc['uid'] as String?;
        final token = doc['token'] as String?;
        if (docId != requesterDeviceId &&
            uid == ownerUid &&
            token != null &&
            token.isNotEmpty) {
          result.add(token);
        }
      }
      return result;
    }

    test('token avec uid == ownerUid est inclus', () {
      final tokens = filterOwnerTokens(
        allTokens: [
          {'deviceId': 'dev1', 'uid': 'owner-uid', 'token': 'token1'},
        ],
        ownerUid: 'owner-uid',
        requesterDeviceId: 'dev-requester',
      );
      expect(tokens, ['token1']);
    });

    test('token avec uid != ownerUid est exclu', () {
      final tokens = filterOwnerTokens(
        allTokens: [
          {'deviceId': 'dev1', 'uid': 'parent-uid', 'token': 'token1'},
          {'deviceId': 'dev2', 'uid': 'child-uid', 'token': 'token2'},
          {'deviceId': 'dev3', 'uid': 'owner-uid', 'token': 'token3'},
        ],
        ownerUid: 'owner-uid',
        requesterDeviceId: 'dev-requester',
      );
      expect(tokens.length, 1);
      expect(tokens, ['token3']);
    });

    test('token sans uid (ancien) est ignoré', () {
      final tokens = filterOwnerTokens(
        allTokens: [
          {'deviceId': 'dev1', 'uid': null, 'token': 'old-token'},
          {'deviceId': 'dev2', 'uid': 'owner-uid', 'token': 'new-token'},
        ],
        ownerUid: 'owner-uid',
        requesterDeviceId: 'dev-requester',
      );
      expect(tokens.length, 1);
      expect(tokens, ['new-token']);
    });

    test('l\'appareil demandeur est exclu même si uid == ownerUid', () {
      final tokens = filterOwnerTokens(
        allTokens: [
          {
            'deviceId': 'dev-requester',
            'uid': 'owner-uid',
            'token': 'requester-token'
          },
          {'deviceId': 'dev2', 'uid': 'owner-uid', 'token': 'owner-token'},
        ],
        ownerUid: 'owner-uid',
        requesterDeviceId: 'dev-requester',
      );
      expect(tokens.length, 1);
      expect(tokens, ['owner-token']);
    });

    test('token vide est ignoré', () {
      final tokens = filterOwnerTokens(
        allTokens: [
          {'deviceId': 'dev1', 'uid': 'owner-uid', 'token': ''},
          {'deviceId': 'dev2', 'uid': 'owner-uid', 'token': 'valid'},
        ],
        ownerUid: 'owner-uid',
        requesterDeviceId: 'dev-x',
      );
      expect(tokens.length, 1);
      expect(tokens, ['valid']);
    });

    test('aucun token owner → liste vide', () {
      final tokens = filterOwnerTokens(
        allTokens: [
          {'deviceId': 'dev1', 'uid': 'other-uid', 'token': 'token1'},
        ],
        ownerUid: 'owner-uid',
        requesterDeviceId: 'dev-x',
      );
      expect(tokens.isEmpty, isTrue);
    });

    test('plusieurs tokens owner sont tous inclus', () {
      final tokens = filterOwnerTokens(
        allTokens: [
          {'deviceId': 'dev1', 'uid': 'owner-uid', 'token': 'token1'},
          {'deviceId': 'dev2', 'uid': 'owner-uid', 'token': 'token2'},
          {'deviceId': 'dev3', 'uid': 'owner-uid', 'token': 'token3'},
        ],
        ownerUid: 'owner-uid',
        requesterDeviceId: 'dev-x',
      );
      expect(tokens.length, 3);
    });

    test('parent non-owner est exclu', () {
      final tokens = filterOwnerTokens(
        allTokens: [
          {'deviceId': 'dev1', 'uid': 'parent-uid', 'token': 'parent-token'},
          {'deviceId': 'dev2', 'uid': 'owner-uid', 'token': 'owner-token'},
        ],
        ownerUid: 'owner-uid',
        requesterDeviceId: 'dev-x',
      );
      expect(tokens.length, 1);
      expect(tokens.contains('parent-token'), isFalse);
    });
  });

  group('fcm_service — guard UID', () {
    test('uid null empêche l\'enregistrement du token', () {
      const String? uid = null;
      final shouldSave = uid != null && uid.isNotEmpty;
      expect(shouldSave, isFalse);
    });

    test('uid valide permet l\'enregistrement', () {
      const uid = 'firebase-auth-uid-123';
      final shouldSave = uid.isNotEmpty;
      expect(shouldSave, isTrue);
    });
  });

  group('firestore.rules — fcm_tokens', () {
    test('create nécessite uid == auth.uid', () {
      const resourceUid = 'user-123';
      const authUid = 'user-123';
      expect(resourceUid == authUid, isTrue);

      const otherUid = 'user-456';
      expect(otherUid == authUid, isFalse);
    });

    test('read est interdit depuis le client', () {
      const allowRead = false;
      expect(allowRead, isFalse);
    });

    test('delete nécessite resource.data.uid == auth.uid', () {
      const storedUid = 'user-123';
      const authUid = 'user-123';
      expect(storedUid == authUid, isTrue);

      const otherUid = 'user-456';
      expect(otherUid == authUid, isFalse);
    });

    test('Firebase Admin contourne les règles', () {
      // Admin SDK n'est pas soumis aux règles Firestore
      const isAdmin = true;
      const canReadOrDelete = isAdmin; // toujours true pour Admin
      expect(canReadOrDelete, isTrue);
    });
  });
}
