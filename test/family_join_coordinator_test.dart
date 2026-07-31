import 'package:family_score/models/family_join_request.dart';
import 'package:family_score/services/family_join_coordinator.dart';
import 'package:family_score/services/family_join_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const parentPending = PendingFamilyJoin(
    familyId: 'family-1',
    familyCode: 'ABCD12',
    requestId: 'request-1',
    requestedRole: FamilyJoinRole.parent,
  );

  const childPending = PendingFamilyJoin(
    familyId: 'family-1',
    familyCode: 'ABCD12',
    requestId: 'request-2',
    requestedRole: FamilyJoinRole.child,
  );

  group('FamilyJoinCoordinator.applyStatus', () {
    test('ne fait rien lorsque la demande est encore en attente', () async {
      var activationCount = 0;
      var clearCount = 0;

      await FamilyJoinCoordinator.applyStatus(
        pending: parentPending,
        status: const FamilyJoinStatusResult(
          familyId: 'family-1',
          status: FamilyJoinStatus.pending,
        ),
        activateApprovedFamily: ({
          required familyId,
          required familyCode,
          required role,
          childId,
        }) async {
          activationCount++;
        },
        clearPendingRequest: () async {
          clearCount++;
        },
      );

      expect(activationCount, 0);
      expect(clearCount, 0);
    });

    test('conserve la demande locale lorsqu’elle est rejetée', () async {
      var activationCount = 0;
      var clearCount = 0;

      await FamilyJoinCoordinator.applyStatus(
        pending: parentPending,
        status: const FamilyJoinStatusResult(
          familyId: 'family-1',
          status: FamilyJoinStatus.rejected,
        ),
        activateApprovedFamily: ({
          required familyId,
          required familyCode,
          required role,
          childId,
        }) async {
          activationCount++;
        },
        clearPendingRequest: () async {
          clearCount++;
        },
      );

      expect(activationCount, 0);
      expect(clearCount, 0);
    });

    test('active un parent puis supprime la demande locale', () async {
      final operations = <String>[];
      String? activatedFamilyId;
      String? activatedCode;
      String? activatedRole;
      String? activatedChildId;

      await FamilyJoinCoordinator.applyStatus(
        pending: parentPending,
        status: const FamilyJoinStatusResult(
          familyId: 'family-1',
          status: FamilyJoinStatus.approved,
          role: FamilyJoinRole.parent,
        ),
        activateApprovedFamily: ({
          required familyId,
          required familyCode,
          required role,
          childId,
        }) async {
          operations.add('activate');
          activatedFamilyId = familyId;
          activatedCode = familyCode;
          activatedRole = role;
          activatedChildId = childId;
        },
        clearPendingRequest: () async {
          operations.add('clear');
        },
      );

      expect(operations, ['activate', 'clear']);
      expect(activatedFamilyId, 'family-1');
      expect(activatedCode, 'ABCD12');
      expect(activatedRole, 'parent');
      expect(activatedChildId, isNull);
    });

    test('transmet le profil enfant autorisé', () async {
      String? activatedRole;
      String? activatedChildId;
      var clearCount = 0;

      await FamilyJoinCoordinator.applyStatus(
        pending: childPending,
        status: const FamilyJoinStatusResult(
          familyId: 'family-1',
          status: FamilyJoinStatus.approved,
          role: FamilyJoinRole.child,
          childId: 'child-123',
        ),
        activateApprovedFamily: ({
          required familyId,
          required familyCode,
          required role,
          childId,
        }) async {
          activatedRole = role;
          activatedChildId = childId;
        },
        clearPendingRequest: () async {
          clearCount++;
        },
      );

      expect(activatedRole, 'child');
      expect(activatedChildId, 'child-123');
      expect(clearCount, 1);
    });

    test('refuse une réponse concernant une autre famille', () async {
      var activationCount = 0;
      var clearCount = 0;

      await expectLater(
        FamilyJoinCoordinator.applyStatus(
          pending: parentPending,
          status: const FamilyJoinStatusResult(
            familyId: 'family-2',
            status: FamilyJoinStatus.approved,
            role: FamilyJoinRole.parent,
          ),
          activateApprovedFamily: ({
            required familyId,
            required familyCode,
            required role,
            childId,
          }) async {
            activationCount++;
          },
          clearPendingRequest: () async {
            clearCount++;
          },
        ),
        throwsA(
          isA<FamilyJoinException>().having(
            (error) => error.code,
            'code',
            'invalid-response',
          ),
        ),
      );

      expect(activationCount, 0);
      expect(clearCount, 0);
    });

    test('refuse un rôle différent de celui demandé', () async {
      var activationCount = 0;
      var clearCount = 0;

      await expectLater(
        FamilyJoinCoordinator.applyStatus(
          pending: parentPending,
          status: const FamilyJoinStatusResult(
            familyId: 'family-1',
            status: FamilyJoinStatus.approved,
            role: FamilyJoinRole.child,
            childId: 'child-123',
          ),
          activateApprovedFamily: ({
            required familyId,
            required familyCode,
            required role,
            childId,
          }) async {
            activationCount++;
          },
          clearPendingRequest: () async {
            clearCount++;
          },
        ),
        throwsA(
          isA<FamilyJoinException>().having(
            (error) => error.code,
            'code',
            'invalid-response',
          ),
        ),
      );

      expect(activationCount, 0);
      expect(clearCount, 0);
    });

    test('ne supprime pas la demande si l’activation échoue', () async {
      var clearCount = 0;

      await expectLater(
        FamilyJoinCoordinator.applyStatus(
          pending: parentPending,
          status: const FamilyJoinStatusResult(
            familyId: 'family-1',
            status: FamilyJoinStatus.approved,
            role: FamilyJoinRole.parent,
          ),
          activateApprovedFamily: ({
            required familyId,
            required familyCode,
            required role,
            childId,
          }) async {
            throw StateError('activation impossible');
          },
          clearPendingRequest: () async {
            clearCount++;
          },
        ),
        throwsStateError,
      );

      expect(clearCount, 0);
    });
  });
}
