import 'package:flutter_test/flutter_test.dart';

import 'package:family_score/services/family_management_service.dart';
import 'package:family_score/services/firestore_service.dart';

void main() {
  group('LegacyFamilyMigrationResult', () {
    test('valide une réponse serveur correcte', () {
      final result = LegacyFamilyMigrationResult.fromData({
        'familyId': 'family-document-id',
        'code': 'NEW123',
        'alreadyMigrated': false,
      });

      expect(result.familyId, 'family-document-id');
      expect(result.code, 'NEW123');
      expect(result.alreadyMigrated, isFalse);
    });

    test('refuse une réponse sans indicateur booléen', () {
      expect(
        () => LegacyFamilyMigrationResult.fromData({
          'familyId': 'family-document-id',
          'code': 'NEW123',
        }),
        throwsFormatException,
      );
    });
  });

  group('activation locale du propriétaire', () {
    test('accepte le rôle owner sans profil enfant', () {
      final data = FirestoreService.buildApprovedLocalMembershipData(
        familyId: 'family-document-id',
        familyCode: 'NEW123',
        role: 'owner',
        allowOwner: true,
      );

      expect(data['family_id'], 'family-document-id');
      expect(data['family_code'], 'NEW123');
      expect(data['family_member_role'], 'owner');
      expect(data['family_member_child_id'], isNull);
    });
  });
}
