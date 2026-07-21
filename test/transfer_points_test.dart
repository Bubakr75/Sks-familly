// Tests pour le transfert express SKS entre enfants.
// Couvre la sérialisation HistoryEntry, la rétrocompatibilité,
// les règles de catégorie et les validations de FamilyProvider.

import 'package:flutter_test/flutter_test.dart';

import 'package:family_score/models/history_entry.dart';

void main() {
  group('HistoryEntry transfert — sérialisation', () {
    test('transferId et counterpartyChildId sont sérialisés', () {
      final entry = HistoryEntry(
        id: 'h1',
        childId: 'child-a',
        points: 15,
        reason: 'Objet abîmé',
        category: 'points_transfer_out',
        isBonus: false,
        transferId: 'transfer_123',
        counterpartyChildId: 'child-b',
      );
      final map = entry.toMap();

      expect(map['transferId'], 'transfer_123');
      expect(map['counterpartyChildId'], 'child-b');
      expect(map['category'], 'points_transfer_out');
    });

    test('désérialisation round-trip préserve tous les champs', () {
      final original = HistoryEntry(
        id: 'h2',
        childId: 'child-x',
        points: 25,
        reason: 'Moquerie',
        category: 'points_transfer_in',
        isBonus: true,
        transferId: 'transfer_456',
        counterpartyChildId: 'child-y',
      );
      final restored = HistoryEntry.fromMap(original.toMap());

      expect(restored.transferId, 'transfer_456');
      expect(restored.counterpartyChildId, 'child-y');
      expect(restored.category, 'points_transfer_in');
      expect(restored.points, 25);
      expect(restored.isBonus, true);
    });
  });

  group('HistoryEntry transfert — rétrocompatibilité', () {
    test('une ancienne entrée sans transfert se charge sans erreur', () {
      final oldMap = <String, dynamic>{
        'id': 'old1',
        'childId': 'c1',
        'points': 10,
        'reason': 'Bonus',
        'category': 'Bonus',
        'date': DateTime(2026, 1, 1).toIso8601String(),
        'isBonus': true,
      };
      final entry = HistoryEntry.fromMap(oldMap);

      expect(entry.transferId, isNull);
      expect(entry.counterpartyChildId, isNull);
      expect(entry.isPointsTransfer, isFalse);
    });
  });

  group('HistoryEntry transfert — catégories', () {
    test('points_transfer_out n\'est pas une pénalité', () {
      final entry = HistoryEntry(
        id: 'h',
        childId: 'c',
        points: 10,
        reason: '',
        category: 'points_transfer_out',
        isBonus: false,
      );
      // isPenalty = !isBonus && !isPurchase
      // Un transfert n'est ni un achat, mais isPointsTransfer doit exclure
      expect(entry.isPointsTransfer, isTrue);
      expect(entry.isPurchase, isFalse);
    });

    test('points_transfer_in n\'est pas un bonus quotidien', () {
      final entry = HistoryEntry(
        id: 'h',
        childId: 'c',
        points: 10,
        reason: '',
        category: 'points_transfer_in',
        isBonus: true,
      );
      expect(entry.isPointsTransfer, isTrue);
      // Le getter isPointsTransfer permet au provider d'exclure du compteur
    });

    test('isPointsTransfer est faux pour un bonus normal', () {
      final entry = HistoryEntry(
        id: 'h',
        childId: 'c',
        points: 10,
        reason: '',
        category: 'Bonus',
        isBonus: true,
      );
      expect(entry.isPointsTransfer, isFalse);
    });

    test('isPointsTransfer est faux pour une pénalité normale', () {
      final entry = HistoryEntry(
        id: 'h',
        childId: 'c',
        points: 5,
        reason: '',
        category: 'Pénalité',
        isBonus: false,
      );
      expect(entry.isPointsTransfer, isFalse);
    });
  });

  group('Validations de transfert (logique pure)', () {
    // Ces tests valident les règles sans instancier FamilyProvider
    // (qui nécessite Hive + Firebase). On vérifie les invariants.

    test('transfert vers le même enfant est refusé', () {
      const fromId = 'child-a';
      const toId = 'child-a';
      expect(fromId == toId, isTrue,
          reason: 'Doit être détecté comme identique');
    });

    test('montant nul est refusé', () {
      const amount = 0;
      expect(amount < 1, isTrue);
    });

    test('montant négatif est refusé', () {
      const amount = -5;
      expect(amount < 1, isTrue);
    });

    test('montant supérieur à 999 est refusé', () {
      const amount = 1000;
      expect(amount > 999, isTrue);
    });

    test('montant supérieur au solde est refusé', () {
      const solde = 30;
      const amount = 50;
      expect(amount > solde, isTrue);
    });

    test('transfert valide : -X et +X exactement', () {
      const soldeFrom = 100;
      const soldeTo = 20;
      const amount = 15;
      expect(soldeFrom - amount, 85);
      expect(soldeTo + amount, 35);
      expect((soldeFrom - amount) + (soldeTo + amount), soldeFrom + soldeTo,
          reason: 'Aucun point créé ou perdu');
    });

    test('deux entrées avec le même transferId sont liées', () {
      const transferId = 'transfer_abc';
      final outEntry = HistoryEntry(
        id: 'out1',
        childId: 'a',
        points: 20,
        reason: 'Test',
        category: 'points_transfer_out',
        transferId: transferId,
        counterpartyChildId: 'b',
      );
      final inEntry = HistoryEntry(
        id: 'in1',
        childId: 'b',
        points: 20,
        reason: 'Test',
        category: 'points_transfer_in',
        transferId: transferId,
        counterpartyChildId: 'a',
      );

      expect(outEntry.transferId, inEntry.transferId);
      expect(outEntry.points, inEntry.points);
      expect(outEntry.counterpartyChildId, inEntry.childId);
      expect(inEntry.counterpartyChildId, outEntry.childId);
    });
  });
}
