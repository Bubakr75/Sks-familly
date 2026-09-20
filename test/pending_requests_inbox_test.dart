import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final source =
      File('lib/screens/pending_requests_screen.dart').readAsStringSync();
  final provider =
      File('lib/providers/family_provider.dart').readAsStringSync();

  test('the inbox can hide a notification without deleting business data', () {
    expect(source, contains("'delete_request_\${r.id}'"));
    expect(source, contains('_confirmDeleteRequest('));
    expect(source, contains('dismissRequestNotification(request.id)'));
  });

  test('a purchase settles only through the server', () {
    expect(provider, contains("_settlePurchaseRequest(r, 'purchase_approve')"));
    expect(
        provider,
        contains(
            "_settlePurchaseRequest(r, 'purchase_reject', reason: reason)"));
    expect(provider, contains('operationId:'));
    expect(provider, contains("request.extra['purchaseId']?.toString()"));
    expect(provider, contains('_markRequestDeleted(request.id)'));
    expect(provider, isNot(contains('_setPurchaseRequestStatus')));
    expect(provider, contains('finally {'));
    expect(provider, contains('_purchaseActionsInFlight.remove(request.id)'));
    expect(source, contains('fp.isPurchaseActionInFlight(r.id)'));
    expect(source, contains('onPressed: processing'));
    expect(source, contains('? null'));
  });

  test(
      'pending legacy purchases are restored without duplicate linked requests',
      () {
    expect(provider, contains('_restoreMissingPurchaseRequests()'));
    expect(provider, contains("purchase['status'] != 'pending'"));
    expect(provider,
        contains("request.extra['purchaseId']?.toString() == purchaseId"));
    expect(provider,
        contains("'screenTimeMinutes': purchase['screenTimeMinutes'] ?? 0"));
  });

  test('purchase retries reuse an operation id and server confirmed points',
      () {
    expect(provider, contains('!_firestore.isConnected) return false'));
    expect(provider, contains('_purchaseOperationsInFlight.putIfAbsent'));
    expect(provider, contains("operation: 'purchase_reward'"));
    expect(provider, contains("final serverPoints = result['points']"));
  });
}
