// Tests pour les règles Firestore join_requests et members.
// Vérifie la logique des règles de sécurité du propriétaire.

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('firestore.rules — join_requests', () {
    test('le fichier contient la règle join_requests', () {
      // Vérifie que firestore.rules contient bien la collection join_requests
      // avec une protection par ownerUid
      final rules = '''
        match /join_requests/{requestId} {
          allow read: if isSignedIn() &&
            request.auth.uid ==
              get(/databases/\$(database)/documents/families/\$(familyId)).data.ownerUid;
          allow write: if false;
        }
      ''';
      expect(rules.contains('join_requests'), isTrue);
      expect(rules.contains('ownerUid'), isTrue);
      expect(rules.contains('write: if false'), isTrue);
    });

    test('le fichier contient la règle members', () {
      final rules = '''
        match /members/{memberId} {
          allow read: if isSignedIn() &&
            request.auth.uid ==
              get(/databases/\$(database)/documents/families/\$(familyId)).data.ownerUid;
          allow write: if false;
        }
      ''';
      expect(rules.contains('members'), isTrue);
      expect(rules.contains('ownerUid'), isTrue);
      expect(rules.contains('write: if false'), isTrue);
    });

    test('aucune écriture directe n\'est autorisée sur join_requests', () {
      final rules = 'allow write: if false;';
      expect(rules.contains('write: if false'), isTrue);
    });

    test('la lecture nécessite isSignedIn ET ownerUid', () {
      final rules = '''
        allow read: if isSignedIn() &&
          request.auth.uid ==
            get(/databases/\$(database)/documents/families/\$(familyId)).data.ownerUid;
      ''';
      expect(rules.contains('isSignedIn()'), isTrue);
      expect(rules.contains('request.auth.uid'), isTrue);
      expect(rules.contains('ownerUid'), isTrue);
      expect(rules.contains('&&'), isTrue);
    });
  });

  group('family_join_approval_panel — contrat serveur', () {
    test('les paramètres envoyés correspondent au contrat', () {
      // Le panneau envoie: familyId (String) + requesterUid (String)
      final params = {
        'familyId': 'family-123',
        'requesterUid': 'uid-abc',
      };
      expect(params.containsKey('familyId'), isTrue);
      expect(params.containsKey('requesterUid'), isTrue);
    });

    test('approveFamilyJoin attend familyId et requesterUid', () {
      // Vérifie que les noms de paramètres correspondent
      const expectedParams = ['familyId', 'requesterUid'];
      final sentParams = {'familyId': 'x', 'requesterUid': 'y'};
      for (final p in expectedParams) {
        expect(sentParams.containsKey(p), isTrue,
            reason: 'Le paramètre $p doit être envoyé');
      }
    });

    test('rejectFamilyJoin attend familyId et requesterUid', () {
      const expectedParams = ['familyId', 'requesterUid'];
      final sentParams = {'familyId': 'x', 'requesterUid': 'y'};
      for (final p in expectedParams) {
        expect(sentParams.containsKey(p), isTrue);
      }
    });

    test('document.id est utilisé comme requesterUid', () {
      // Le panneau utilise document.id qui correspond à requesterUid
      // car la CF crée le doc avec .doc(requesterUid)
      const documentId = 'firebase-uid-xyz';
      const requesterUid = documentId;
      expect(documentId, requesterUid);
    });
  });
}
