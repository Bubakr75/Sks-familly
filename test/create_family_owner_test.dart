import 'package:flutter_test/flutter_test.dart';
import 'package:family_score/services/firestore_service.dart';

void main() {
  group('createFamily owner data', () {
    test('builds the new family document', () {
      final createdAt = Object();

      final data = FirestoreService.buildNewFamilyData(
        code: 'ABCD12',
        ownerUid: 'owner-uid',
        createdAt: createdAt,
      );

      expect(data, {
        'code': 'ABCD12',
        'createdAt': same(createdAt),
        'memberCount': 1,
        'ownerUid': 'owner-uid',
        'schemaVersion': 2,
        'migrationStatus': 'native',
      });
    });

    test('builds the owner member document', () {
      final createdAt = Object();
      final approvedAt = Object();

      final data = FirestoreService.buildOwnerMemberData(
        ownerUid: 'owner-uid',
        createdAt: createdAt,
        approvedAt: approvedAt,
      );

      expect(data, {
        'uid': 'owner-uid',
        'role': 'owner',
        'childId': isNull,
        'active': true,
        'createdAt': same(createdAt),
        'approvedBy': 'owner-uid',
        'approvedAt': same(approvedAt),
      });
    });
  });
}
