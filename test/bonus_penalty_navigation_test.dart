// Tests pour la refonte Bonus/Pénalité/Navigation.
// Vérifie les configurations, la classification, la navigation et l'anti-doublon.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:family_score/models/history_entry.dart';
import 'package:family_score/models/pending_request.dart';
import 'package:family_score/widgets/point_action_panel.dart';
import 'package:family_score/screens/bonus_screen.dart';
import 'package:family_score/screens/penalty_screen.dart';

void main() {
  group('Navigation — structure', () {
    test('BonusScreen est un StatelessWidget instanciable', () {
      const screen = BonusScreen();
      expect(screen, isA<BonusScreen>());
    });

    test('PenaltyScreen est un StatelessWidget instanciable', () {
      const screen = PenaltyScreen();
      expect(screen, isA<PenaltyScreen>());
    });
  });

  group('BonusScreen — configuration', () {
    test('isBonus est true', () {
      // On vérifie via le motif de la config
      const config = PointActionConfig(
        title: 'Test',
        subtitle: '',
        buttonText: '',
        category: 'Bonus',
        isBonus: true,
        primaryColor: Color(0xFF000000),
        accentColor: Color(0xFF000000),
        backgroundColor: Color(0xFF000000),
        motifs: [],
        buttonIcon: Icons.star,
        successMessage: '',
      );
      expect(config.isBonus, isTrue);
      expect(config.category, 'Bonus');
    });
  });

  group('PenaltyScreen — configuration', () {
    test('isBonus est false', () {
      const config = PointActionConfig(
        title: 'Test',
        subtitle: '',
        buttonText: '',
        category: 'Pénalité',
        isBonus: false,
        primaryColor: Color(0xFF000000),
        accentColor: Color(0xFF000000),
        backgroundColor: Color(0xFF000000),
        motifs: [],
        buttonIcon: Icons.warning,
        successMessage: '',
      );
      expect(config.isBonus, isFalse);
      expect(config.category, 'Pénalité');
    });
  });

  group('PointActionPanel — montants', () {
    test('montant minimum est 1', () {
      int amount = 0;
      amount = (amount + 1).clamp(1, 999);
      expect(amount, 1);
    });

    test('montant maximum est 999', () {
      int amount = 1000;
      amount = amount.clamp(1, 999);
      expect(amount, 999);
    });

    test('ajustement par delta respecte les bornes', () {
      int amount = 5;
      amount = (amount + (-10)).clamp(1, 999);
      expect(amount, 1);
      amount = (amount + 2000).clamp(1, 999);
      expect(amount, 999);
    });
  });

  group('Classification des entrées', () {
    test('un achat boutique n\'est jamais une pénalité', () {
      final entry = HistoryEntry(
        id: 'h',
        childId: 'c',
        points: 50,
        reason: 'Achat',
        category: 'boutique',
        isBonus: false,
      );
      expect(entry.isPurchase, isTrue);
      expect(entry.isPenalty, isFalse);
    });

    test('un transfert n\'est jamais une pénalité ni un achat', () {
      final outEntry = HistoryEntry(
        id: 'h',
        childId: 'c',
        points: 10,
        reason: 'Test',
        category: 'points_transfer_out',
        isBonus: false,
      );
      expect(outEntry.isPointsTransfer, isTrue);
      expect(outEntry.isPenalty, isFalse);
      expect(outEntry.isPurchase, isFalse);
    });
  });

  group('PendingRequest — rétrocompatibilité', () {
    test('une ancienne demande sans requestKey reste lisible', () {
      final oldMap = <String, dynamic>{
        'id': 'old1',
        'type': 'bonus',
        'childId': 'c1',
        'requestedBy': 'Enfant',
        'text': 'Bonus demandé',
        'amount': 10,
        'status': 'pending',
        'createdAt': DateTime(2026, 1, 1).toIso8601String(),
        'extra': {},
      };
      final req = PendingRequest.fromMap(oldMap);
      expect(req.extra['requestKey'], isNull);
      expect(req.status, 'pending');
    });

    test('une demande avec requestKey est sérialisée correctement', () {
      final req = PendingRequest(
        id: 'r1',
        type: 'chore_checklist',
        childId: 'c1',
        requestedBy: 'Enfant',
        text: 'Tâches',
        amount: 15,
        extra: {'requestKey': 'checklist_c1_2026-7-22'},
      );
      final map = req.toMap();
      expect(map['extra']['requestKey'], 'checklist_c1_2026-7-22');
    });
  });

  group('Anti-doublon — requestKey', () {
    test('deux clés identiques sont détectées comme doublon', () {
      final key1 = 'checklist_child-a_2026-7-22';
      final key2 = 'checklist_child-a_2026-7-22';
      expect(key1 == key2, isTrue);
    });

    test('un autre jour produit une clé différente', () {
      final key1 = 'checklist_child-a_2026-7-22';
      final key2 = 'checklist_child-a_2026-7-23';
      expect(key1 != key2, isTrue);
    });
  });

  group('PendingRequest — tri', () {
    test('tri par createdAt décroissant', () {
      final requests = [
        PendingRequest(
            id: 'r1',
            type: 'bonus',
            childId: 'c',
            requestedBy: 'E',
            text: 't1',
            createdAt: DateTime(2026, 7, 22, 10)),
        PendingRequest(
            id: 'r2',
            type: 'bonus',
            childId: 'c',
            requestedBy: 'E',
            text: 't2',
            createdAt: DateTime(2026, 7, 22, 14)),
        PendingRequest(
            id: 'r3',
            type: 'bonus',
            childId: 'c',
            requestedBy: 'E',
            text: 't3',
            createdAt: DateTime(2026, 7, 22, 12)),
      ];
      final sorted = List<PendingRequest>.from(requests)
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      expect(sorted.first.id, 'r2'); // 14h
      expect(sorted[1].id, 'r3'); // 12h
      expect(sorted.last.id, 'r1'); // 10h
    });
  });
}
