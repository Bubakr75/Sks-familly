import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final source =
      File('lib/screens/pending_requests_screen.dart').readAsStringSync();
  final providerSource =
      File('lib/providers/family_provider.dart').readAsStringSync();

  test('chaque demande de la cloche propose une suppression', () {
    expect(source, contains("'delete_request_\${r.id}'"));
    expect(source, contains('Supprimer cette notification ?'));
    expect(source, contains('_confirmDeleteRequest('));
  });

  test('la suppression refuse proprement la demande et rembourse les achats',
      () {
    expect(source, contains('await provider.rejectRequest('));
    expect(source, contains("final isPurchase = request.type == 'boutique'"));
    expect(source, contains('les points de l’achat seront remboursés'));
  });

  test('le statut de l’achat suit la décision prise dans la cloche', () {
    expect(
      providerSource,
      contains("await _setPurchaseRequestStatus(r, 'approved')"),
    );
    expect(
      providerSource,
      contains("await _setPurchaseRequestStatus(r, 'rejected')"),
    );
  });

  test('les achats anciens encore en attente réapparaissent dans la cloche',
      () {
    expect(providerSource, contains('_restoreMissingPurchaseRequests()'));
    expect(
      providerSource,
      contains("purchase['status'] != 'pending'"),
    );
    expect(providerSource, contains("type: 'boutique'"));
  });

  test('un achat hors connexion conserve le même identifiant que sa demande',
      () {
    expect(providerSource, contains('requestId: purchaseId'));
    expect(providerSource, contains("'purchaseId': purchaseId"));
    expect(providerSource, contains('id: requestId ?? _uuid.v4()'));
  });

  test('la restauration accepte les coûts numériques Firestore', () {
    expect(providerSource, contains('rawCost is num ? rawCost.toInt() : 0'));
  });

  test('un achat déjà traité ne peut pas être remboursé une seconde fois', () {
    expect(
      providerSource,
      contains("if (purchase['status'] != 'pending') return false"),
    );
    expect(providerSource, contains('if (shouldRefund && child != null)'));
  });
}
