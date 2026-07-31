import 'package:flutter_test/flutter_test.dart';
import 'package:family_score/models/family_join_request.dart';

void main() {
  group('FamilyJoinRequestResult', () {
    test('parses a pending request response', () {
      final result = FamilyJoinRequestResult.fromMap({
        'familyId': 'family-1',
        'requestId': 'uid-1',
        'status': 'pending',
        'alreadyPending': false,
      });

      expect(result.familyId, 'family-1');
      expect(result.requestId, 'uid-1');
      expect(result.status, FamilyJoinStatus.pending);
      expect(result.alreadyPending, isFalse);
    });

    test('rejects a malformed request response', () {
      expect(
        () => FamilyJoinRequestResult.fromMap({
          'familyId': 'family-1',
          'requestId': 'uid-1',
          'status': 'approved',
          'alreadyPending': false,
        }),
        throwsFormatException,
      );
    });
  });

  group('FamilyJoinStatusResult', () {
    test('accepts a pending response without member data', () {
      final result = FamilyJoinStatusResult.fromMap({
        'familyId': 'family-1',
        'status': 'pending',
        'role': null,
        'childId': null,
      });

      expect(result.isPending, isTrue);
      expect(result.role, isNull);
      expect(result.childId, isNull);
    });

    test('accepts an approved parent without childId', () {
      final result = FamilyJoinStatusResult.fromMap({
        'familyId': 'family-1',
        'status': 'approved',
        'role': 'parent',
        'childId': null,
      });

      expect(result.isApproved, isTrue);
      expect(result.role, FamilyJoinRole.parent);
      expect(result.childId, isNull);
    });

    test('accepts an approved child with childId', () {
      final result = FamilyJoinStatusResult.fromMap({
        'familyId': 'family-1',
        'status': 'approved',
        'role': 'child',
        'childId': 'child-123',
      });

      expect(result.isApproved, isTrue);
      expect(result.role, FamilyJoinRole.child);
      expect(result.childId, 'child-123');
    });

    test('rejects approved status without an active role', () {
      expect(
        () => FamilyJoinStatusResult.fromMap({
          'familyId': 'family-1',
          'status': 'approved',
          'role': null,
          'childId': null,
        }),
        throwsFormatException,
      );
    });

    test('rejects an approved child without childId', () {
      expect(
        () => FamilyJoinStatusResult.fromMap({
          'familyId': 'family-1',
          'status': 'approved',
          'role': 'child',
          'childId': null,
        }),
        throwsFormatException,
      );
    });

    test('rejects member data on a rejected request', () {
      expect(
        () => FamilyJoinStatusResult.fromMap({
          'familyId': 'family-1',
          'status': 'rejected',
          'role': 'parent',
          'childId': null,
        }),
        throwsFormatException,
      );
    });
  });

  group('PendingFamilyJoin', () {
    test('round-trips through JSON data', () {
      const pending = PendingFamilyJoin(
        familyId: 'family-1',
        familyCode: 'ABCD12',
        requestId: 'uid-1',
        requestedRole: FamilyJoinRole.child,
      );

      final restored = PendingFamilyJoin.fromJson(pending.toJson());

      expect(restored.familyId, pending.familyId);
      expect(restored.familyCode, pending.familyCode);
      expect(restored.requestId, pending.requestId);
      expect(restored.requestedRole, FamilyJoinRole.child);
    });

    test('rejects an unknown role', () {
      expect(
        () => PendingFamilyJoin.fromJson({
          'familyId': 'family-1',
          'familyCode': 'ABCD12',
          'requestId': 'uid-1',
          'requestedRole': 'owner',
        }),
        throwsFormatException,
      );
    });
  });
}
