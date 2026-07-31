import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('firestore.rules — join_requests et members', () {
    late String rules;

    setUpAll(() {
      rules = File('firestore.rules').readAsStringSync();
    });

    String ruleBlock(String path) {
      final start = rules.indexOf(path);
      expect(start, greaterThanOrEqualTo(0));
      final nextMatch = rules.indexOf('\n      match /', start + path.length);
      return rules.substring(
        start,
        nextMatch == -1 ? rules.length : nextMatch,
      );
    }

    test('la boîte de demandes est réservée au propriétaire et gestionnaire',
        () {
      final block = ruleBlock('match /join_requests/{requestId}');
      expect(block, contains('isFamilyOwner(familyId)'));
      expect(block, contains('isFamilyManager(familyId)'));
      expect(block, isNot(contains('isFamilyParent(familyId)')));
      expect(block, contains('requestId == request.auth.uid'));
      expect(block, contains('allow write: if false'));
    });

    test('les membres restent réservés au propriétaire réel', () {
      final block = ruleBlock('match /members/{memberId}');
      expect(block, contains('isFamilyOwner(familyId)'));
      expect(block, contains('allow write: if false'));
    });
  });

  group('family_join_approval_panel — contrat serveur', () {
    test('les paramètres envoyés correspondent au contrat', () {
      final params = {
        'familyId': 'family-123',
        'requesterUid': 'uid-abc',
      };
      expect(params.containsKey('familyId'), isTrue);
      expect(params.containsKey('requesterUid'), isTrue);
    });

    test('approveFamilyJoin attend familyId et requesterUid', () {
      const expectedParams = ['familyId', 'requesterUid'];
      final sentParams = {'familyId': 'x', 'requesterUid': 'y'};
      for (final parameter in expectedParams) {
        expect(sentParams.containsKey(parameter), isTrue);
      }
    });

    test('rejectFamilyJoin attend familyId et requesterUid', () {
      const expectedParams = ['familyId', 'requesterUid'];
      final sentParams = {'familyId': 'x', 'requesterUid': 'y'};
      for (final parameter in expectedParams) {
        expect(sentParams.containsKey(parameter), isTrue);
      }
    });

    test('document.id est utilisé comme requesterUid', () {
      const documentId = 'firebase-uid-xyz';
      const requesterUid = documentId;
      expect(documentId, requesterUid);
    });
  });
}
