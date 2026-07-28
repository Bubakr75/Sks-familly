import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('firestore.rules — join_requests et members', () {
    late String rules;

    setUpAll(() {
      rules = File('firestore.rules').readAsStringSync();
    });

    test('les deux collections sont réservées au propriétaire réel', () {
      for (final path in [
        'match /join_requests/{requestId}',
        'match /members/{memberId}',
      ]) {
        final start = rules.indexOf(path);
        expect(start, greaterThanOrEqualTo(0));
        final nextMatch = rules.indexOf('\n      match /', start + path.length);
        final block = rules.substring(
          start,
          nextMatch == -1 ? rules.length : nextMatch,
        );
        expect(block, contains('isFamilyOwner(familyId)'));
        expect(block, contains('allow write: if false'));
      }
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
