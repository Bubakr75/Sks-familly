import 'package:flutter_test/flutter_test.dart';

import 'package:family_score/models/sks_wallet.dart';
import 'package:family_score/screens/wallet_screen.dart';
import 'package:family_score/services/firestore_service.dart';

void main() {
  group('Modèles de cagnotte SKS', () {
    test('le solde reste séparé des points de comportement', () {
      final wallet = SksWallet.fromMap({
        'childId': 'child-1',
        'balance': 42,
        'createdAt': '2026-07-28T10:00:00.000Z',
        'updatedAt': '2026-07-28T11:00:00.000Z',
      });

      expect(wallet.childId, 'child-1');
      expect(wallet.balance, 42);
    });

    test('une opération conserve le motif, le delta et la date', () {
      final operation = SksWalletOperation.fromMap({
        'id': 'operation-1',
        'childId': 'child-1',
        'type': 'debit',
        'amount': 5,
        'delta': -5,
        'reason': 'Achat',
        'actorUid': 'parent-1',
        'balanceAfter': 37,
        'createdAt': '2026-07-28T11:00:00.000Z',
      });

      expect(operation.reason, 'Achat');
      expect(operation.delta, -5);
      expect(operation.balanceAfter, 37);
      expect(operation.createdAt.year, 2026);
    });

    test('parse une réponse idempotente de la Cloud Function', () {
      final result = SksWalletAdjustmentResult.fromData({
        'operationId': 'operation-1',
        'balance': 42,
        'idempotent': true,
      });

      expect(result.operationId, 'operation-1');
      expect(result.balance, 42);
      expect(result.idempotent, isTrue);
    });
  });

  group('Droits d’interface de la cagnotte', () {
    test('le propriétaire et le parent déverrouillé peuvent gérer', () {
      expect(
        canManageSksWallet(memberRole: 'owner', isParentMode: true),
        isTrue,
      );
      expect(
        canManageSksWallet(memberRole: 'parent', isParentMode: true),
        isTrue,
      );
    });

    test('un enfant reste en consultation seule', () {
      expect(
        canManageSksWallet(memberRole: 'child', isParentMode: true),
        isFalse,
      );
      expect(
        canManageSksWallet(memberRole: 'parent', isParentMode: false),
        isFalse,
      );
    });
  });

  group('Appel sécurisé de la cagnotte', () {
    test('utilise la région et les paramètres attendus par adjustWallet', () {
      expect(FirestoreService.walletFunctionsRegion, 'us-central1');
      expect(
        FirestoreService.buildWalletAdjustmentPayload(
          familyId: 'family-1',
          childId: 'child-1',
          operationId: 'operation-1',
          type: 'credit',
          amount: 25,
          reason: '  Argent de poche  ',
        ),
        {
          'familyId': 'family-1',
          'childId': 'child-1',
          'operationId': 'operation-1',
          'type': 'credit',
          'amount': 25,
          'reason': 'Argent de poche',
        },
      );
    });

    test('traduit les erreurs techniques en messages français', () {
      expect(
        walletErrorMessage(code: 'not_found'),
        contains('fonction sécurisée'),
      );
      expect(
        walletErrorMessage(code: 'permission-denied'),
        contains('autorisation'),
      );
      expect(
        walletErrorMessage(code: 'internal'),
        'Impossible de modifier la cagnotte pour le moment.',
      );
      expect(
        walletErrorMessage(
          code: 'not-found',
          serverMessage: 'Famille introuvable.',
        ),
        'Famille introuvable.',
      );
    });
  });
}
