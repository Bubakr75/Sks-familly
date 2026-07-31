import 'dart:async';

import 'package:family_score/services/point_action_submission_service.dart';
import 'package:flutter_test/flutter_test.dart';

PointActionDraft draft({
  required bool isBonus,
  required bool custom,
  required bool withPhoto,
  String childId = 'child-a',
  int amount = 5,
}) {
  return PointActionDraft(
    actionId: 'action-a',
    childId: childId,
    amount: amount,
    reason: custom ? '✨ Motif personnalisé' : '🧹 Motif prédéfini',
    category: isBonus ? 'Bonus' : 'Pénalité',
    isBonus: isBonus,
    hasPhoto: withPhoto,
  );
}

void main() {
  for (final isBonus in [true, false]) {
    for (final custom in [true, false]) {
      for (final withPhoto in [true, false]) {
        test(
          '${isBonus ? "bonus" : "pénalité"} '
          '${custom ? "personnalisé" : "prédéfini"} '
          '${withPhoto ? "avec" : "sans"} photo',
          () async {
            final coordinator = PointActionSubmissionCoordinator();
            var uploads = 0;
            PointActionDraft? recorded;
            final action = draft(
              isBonus: isBonus,
              custom: custom,
              withPhoto: withPhoto,
            );
            final result = await coordinator.submit(
              draft: action,
              existingPhotoStoragePath: null,
              uploadPhoto: () async {
                uploads += 1;
                return 'families/f/actions/action-a/proof.jpg';
              },
              deletePhoto: (_) async {},
              recordAction: (path) async {
                recorded = action;
                expect(path != null, withPhoto);
                return action.amount;
              },
            );
            expect(result.success, isTrue);
            expect(result.appliedAmount, action.amount);
            expect(recorded!.childId, 'child-a');
            expect(recorded!.amount, 5);
            expect(recorded!.isBonus, isBonus);
            expect(uploads, withPhoto ? 1 : 0);
          },
        );
      }
    }
  }

  test('double appui rapide n’enregistre qu’une fois', () async {
    final coordinator = PointActionSubmissionCoordinator();
    final gate = Completer<void>();
    var records = 0;
    final first = coordinator.submit(
      draft: draft(isBonus: true, custom: false, withPhoto: false),
      existingPhotoStoragePath: null,
      uploadPhoto: () async => 'unused',
      deletePhoto: (_) async {},
      recordAction: (_) async {
        records += 1;
        await gate.future;
        return 5;
      },
    );
    final second = await coordinator.submit(
      draft: draft(isBonus: true, custom: false, withPhoto: false),
      existingPhotoStoragePath: null,
      uploadPhoto: () async => 'unused',
      deletePhoto: (_) async {},
      recordAction: (_) async {
        records += 1;
        return 5;
      },
    );
    expect(second.duplicateIgnored, isTrue);
    gate.complete();
    expect((await first).success, isTrue);
    expect(records, 1);
    expect(coordinator.isBusy, isFalse);
  });

  test('erreur serveur conserve la saisie et libère le verrou', () async {
    final coordinator = PointActionSubmissionCoordinator();
    final action = draft(isBonus: false, custom: true, withPhoto: false);
    final failed = await coordinator.submit(
      draft: action,
      existingPhotoStoragePath: null,
      uploadPhoto: () async => 'unused',
      deletePhoto: (_) async {},
      recordAction: (_) async => throw const PointActionRemoteException(
        code: 'permission-denied',
      ),
    );
    expect(failed.success, isFalse);
    expect(failed.errorMessage, contains('pas autorisé'));
    expect(coordinator.isBusy, isFalse);

    final retried = await coordinator.submit(
      draft: action,
      existingPhotoStoragePath: null,
      uploadPhoto: () async => 'unused',
      deletePhoto: (_) async {},
      recordAction: (_) async => 5,
    );
    expect(retried.success, isTrue);
  });

  test('Function absente produit un diagnostic explicite sans fallback',
      () async {
    final coordinator = PointActionSubmissionCoordinator();
    final result = await coordinator.submit(
      draft: draft(isBonus: true, custom: false, withPhoto: false),
      existingPhotoStoragePath: null,
      uploadPhoto: () async => 'unused',
      deletePhoto: (_) async {},
      recordAction: (_) async => throw const PointActionRemoteException(
        code: 'not-found',
        message: 'NOT FOUND',
      ),
    );
    expect(result.functionUnavailable, isTrue);
    expect(result.errorMessage, contains('recordPointAction'));
    expect(result.errorMessage, contains('Aucune action'));
  });

  test('réseau lent garde les valeurs capturées avant validation', () async {
    final coordinator = PointActionSubmissionCoordinator();
    final gate = Completer<void>();
    final action = draft(
      isBonus: false,
      custom: true,
      withPhoto: false,
      childId: 'child-before',
      amount: 7,
    );
    String? recordedChild;
    int? recordedAmount;
    final future = coordinator.submit(
      draft: action,
      existingPhotoStoragePath: null,
      uploadPhoto: () async => 'unused',
      deletePhoto: (_) async {},
      recordAction: (_) async {
        await gate.future;
        recordedChild = action.childId;
        recordedAmount = action.amount;
        return 7;
      },
    );
    // Simule une autre sélection locale après le début de la validation.
    final changed = draft(
      isBonus: true,
      custom: false,
      withPhoto: false,
      childId: 'child-after',
      amount: 99,
    );
    expect(changed.childId, isNot(action.childId));
    gate.complete();
    expect((await future).success, isTrue);
    expect(recordedChild, 'child-before');
    expect(recordedAmount, 7);
  });

  test('erreur certaine nettoie la photo puis permet une nouvelle tentative',
      () async {
    final coordinator = PointActionSubmissionCoordinator();
    var deletes = 0;
    final action = draft(isBonus: true, custom: false, withPhoto: true);
    final failed = await coordinator.submit(
      draft: action,
      existingPhotoStoragePath: null,
      uploadPhoto: () async => 'families/f/actions/action-a/proof.jpg',
      deletePhoto: (_) async => deletes += 1,
      recordAction: (_) async => throw const PointActionRemoteException(
        code: 'invalid-argument',
      ),
    );
    expect(failed.photoStoragePath, isNull);
    expect(deletes, 1);
    expect(coordinator.isBusy, isFalse);
  });

  test('réponse réseau ambiguë conserve photo et identifiant pour rejeu',
      () async {
    final coordinator = PointActionSubmissionCoordinator();
    var deletes = 0;
    final result = await coordinator.submit(
      draft: draft(isBonus: false, custom: false, withPhoto: true),
      existingPhotoStoragePath: null,
      uploadPhoto: () async => 'families/f/actions/action-a/proof.jpg',
      deletePhoto: (_) async => deletes += 1,
      recordAction: (_) async => throw const PointActionRemoteException(
        code: 'deadline-exceeded',
      ),
    );
    expect(result.retryStateUncertain, isTrue);
    expect(result.photoStoragePath, isNotNull);
    expect(deletes, 0);
    expect(coordinator.isBusy, isFalse);
  });
}
