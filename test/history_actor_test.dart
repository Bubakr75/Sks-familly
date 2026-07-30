import 'package:flutter_test/flutter_test.dart';
import 'package:family_score/models/history_entry.dart';

void main() {
  test('affiche l’auteur attribué par le serveur', () {
    final entry = HistoryEntry.fromMap({
      'id': 'action-1',
      'childId': 'child-1',
      'points': 5,
      'reason': 'Rangement',
      'category': 'Pénalité',
      'isBonus': false,
      'createdAt': '2026-07-30T12:00:00.000Z',
      'actorUid': 'uid-maman',
      'actorDisplayName': 'Maman',
      'actorRole': 'parent',
    });

    expect(entry.actorUid, 'uid-maman');
    expect(entry.displayActorName, 'Maman');
    expect(entry.actionDescription, 'Pénalité de 5 points ajoutée par Maman');
  });

  test('conserve la compatibilité avec une ancienne action', () {
    final entry = HistoryEntry.fromMap({
      'id': 'legacy',
      'childId': 'child-1',
      'points': 2,
      'reason': 'Ancienne action',
      'date': '2025-01-01T08:00:00.000Z',
      'actionBy': 'Papa',
    });

    expect(entry.actorUid, isNull);
    expect(entry.displayActorName, 'Papa');
  });
}
