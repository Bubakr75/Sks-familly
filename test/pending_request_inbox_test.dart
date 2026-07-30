import 'package:family_score/models/pending_request.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  PendingRequest request({
    String status = 'sent',
    List<String>? readBy,
  }) {
    return PendingRequest.fromMap({
      'id': 'request-1',
      'type': 'bonus',
      'childId': 'child-1',
      'requestedBy': 'Adam',
      'text': 'Demande persistante',
      'amount': 5,
      'status': status,
      'createdAt': '2026-07-30T12:00:00.000Z',
      'readBy': readBy ?? <String>[],
    });
  }

  test('la demande Firestore reste visible après la réception du push', () {
    final persisted = request(status: 'sent');
    expect(persisted.isPending, isTrue);

    final reopenedOnAnotherDevice = PendingRequest.fromMap(persisted.toMap());
    expect(reopenedOnAnotherDevice.isPending, isTrue);
    expect(reopenedOnAnotherDevice.id, 'request-1');
  });

  test('le compteur non lu dépend de readBy et de l’UID authentifié', () {
    expect(request().isUnreadFor('uid-maman'), isTrue);
    expect(request(readBy: ['uid-maman']).isUnreadFor('uid-maman'), isFalse);
    expect(request(readBy: ['uid-papa']).isUnreadFor('uid-maman'), isTrue);
  });

  test('le traitement retire la demande de la boîte active', () {
    expect(request(status: 'received').isPending, isTrue);
    expect(request(status: 'accepted').isPending, isFalse);
    expect(request(status: 'refused').isPending, isFalse);
    expect(request(status: 'expired').isPending, isFalse);
  });
}
