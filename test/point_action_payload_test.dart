import 'package:flutter_test/flutter_test.dart';
import 'package:family_score/services/firestore_service.dart';

void main() {
  test('le client ne transmet aucun champ d’auteur', () {
    final payload = FirestoreService.buildPointActionPayload(
      familyId: 'family-a',
      actionId: 'action-a',
      childId: 'child-a',
      amount: 5,
      reason: ' Rangement ',
      category: ' Pénalité ',
      isBonus: false,
    );

    expect(payload['reason'], 'Rangement');
    expect(payload['category'], 'Pénalité');
    expect(payload.containsKey('actorUid'), isFalse);
    expect(payload.containsKey('actorDisplayName'), isFalse);
    expect(payload.containsKey('actorRole'), isFalse);
    expect(payload.containsKey('createdAt'), isFalse);
  });
}
