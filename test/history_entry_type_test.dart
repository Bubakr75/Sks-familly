import 'package:flutter_test/flutter_test.dart';
import 'package:family_score/models/history_entry.dart';

void main() {
  group('Types des opérations de points', () {
    test('un bonus est uniquement un bonus', () {
      final entry = HistoryEntry(
        id: 'bonus-1',
        childId: 'child-1',
        points: 10,
        reason: 'Bonne action',
        category: 'Bonus',
        isBonus: true,
      );

      expect(entry.isBonus, isTrue);
      expect(entry.isPenalty, isFalse);
      expect(entry.isPurchase, isFalse);
    });

    test('une pénalité est reconnue comme pénalité', () {
      final entry = HistoryEntry(
        id: 'penalty-1',
        childId: 'child-1',
        points: 5,
        reason: 'Mauvais comportement',
        category: 'Pénalité',
        isBonus: false,
      );

      expect(entry.isBonus, isFalse);
      expect(entry.isPenalty, isTrue);
      expect(entry.isPurchase, isFalse);
    });

    test('un achat boutique n’est jamais une pénalité', () {
      final entry = HistoryEntry(
        id: 'purchase-1',
        childId: 'child-1',
        points: 30,
        reason: 'Achat boutique',
        category: 'boutique',
        isBonus: false,
      );

      expect(entry.isBonus, isFalse);
      expect(entry.isPurchase, isTrue);
      expect(entry.isPenalty, isFalse);
    });

    test('un ancien achat désérialisé reste reconnu', () {
      final entry = HistoryEntry.fromMap({
        'id': 'legacy-purchase',
        'childId': 'child-1',
        'points': 20,
        'reason': 'Achat boutique',
        'category': 'boutique',
        'isBonus': false,
        'date': DateTime(2026, 1, 1).toIso8601String(),
      });

      expect(entry.isPurchase, isTrue);
      expect(entry.isPenalty, isFalse);
    });
  });
}
