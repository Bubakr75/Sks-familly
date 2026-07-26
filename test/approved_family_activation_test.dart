import 'package:flutter_test/flutter_test.dart';
import 'package:family_score/services/firestore_service.dart';

void main() {
  group('approved family activation data', () {
    test('normalizes an approved parent membership', () {
      final data = FirestoreService.buildApprovedLocalMembershipData(
        familyId: ' family-1 ',
        familyCode: ' abcd12 ',
        role: 'parent',
      );

      expect(data, {
        'family_id': 'family-1',
        'family_code': 'ABCD12',
        'family_member_role': 'parent',
        'family_member_child_id': null,
      });
    });

    test('keeps the authorized child profile', () {
      final data = FirestoreService.buildApprovedLocalMembershipData(
        familyId: 'family-1',
        familyCode: 'ABCD12',
        role: 'child',
        childId: 'child-123',
      );

      expect(data['family_member_role'], 'child');
      expect(data['family_member_child_id'], 'child-123');
    });

    test('rejects a child membership without childId', () {
      expect(
        () => FirestoreService.buildApprovedLocalMembershipData(
          familyId: 'family-1',
          familyCode: 'ABCD12',
          role: 'child',
        ),
        throwsArgumentError,
      );
    });

    test('rejects a parent membership with childId', () {
      expect(
        () => FirestoreService.buildApprovedLocalMembershipData(
          familyId: 'family-1',
          familyCode: 'ABCD12',
          role: 'parent',
          childId: 'child-123',
        ),
        throwsArgumentError,
      );
    });

    test('rejects owner as a join approval role', () {
      expect(
        () => FirestoreService.buildApprovedLocalMembershipData(
          familyId: 'family-1',
          familyCode: 'ABCD12',
          role: 'owner',
        ),
        throwsArgumentError,
      );
    });

    test('rejects unsafe family and child identifiers', () {
      expect(
        () => FirestoreService.buildApprovedLocalMembershipData(
          familyId: 'family/bad',
          familyCode: 'ABCD12',
          role: 'parent',
        ),
        throwsArgumentError,
      );

      expect(
        () => FirestoreService.buildApprovedLocalMembershipData(
          familyId: 'family-1',
          familyCode: 'ABCD12',
          role: 'child',
          childId: 'child/bad',
        ),
        throwsArgumentError,
      );
    });
  });
}
