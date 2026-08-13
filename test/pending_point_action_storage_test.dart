import 'dart:convert';

import 'package:family_score/services/firestore_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('une entrée JSON corrompue préserve les opérations valides', () {
    final raw = jsonEncode([
      {
        'familyId': 'family-a',
        'operationId': 'operation-a',
        'fingerprint': 'immutable',
        'type': 'bonus',
        'createdAt': '2026-01-01T00:00:00.000Z',
      },
      '{json invalide',
      {
        'familyId': 'family-b',
        'operationId': 'operation-b',
        'fingerprint': 'immutable-b',
        'type': 'penalty',
        'createdAt': '2026-01-02T00:00:00.000Z',
      },
    ]);

    final decoded = FirestoreService.decodePendingPointActions(raw);
    expect(
        decoded.where((entry) => entry['operationId'] != null), hasLength(2));
    expect(
        decoded.where((entry) => entry['status'] == 'corrupted'), hasLength(1));
  });

  test('une liste totalement corrompue reste signalée localement', () {
    final decoded = FirestoreService.decodePendingPointActions('{cassé');
    expect(decoded, hasLength(1));
    expect(decoded.single['status'], 'corrupted');
  });

  test('une attente de plus de 30 jours est archivée sans être supprimée', () {
    final entries = <Map<String, dynamic>>[
      {
        'familyId': 'family-inactive',
        'operationId': 'old-operation',
        'fingerprint': 'immutable',
        'type': 'penalty',
        'createdAt': '2026-01-01T00:00:00.000Z',
        'status': 'reconciling',
      }
    ];
    final changed = FirestoreService.archiveOldPendingPointActions(
      entries,
      now: DateTime.utc(2026, 2, 15),
    );
    expect(changed, isTrue);
    expect(entries, hasLength(1));
    expect(entries.single['familyId'], 'family-inactive');
    expect(entries.single['status'], 'verificationRequired');
  });
}
