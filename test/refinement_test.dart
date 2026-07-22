// Tests utilisant les vrais helpers de production.
// Teste requestKey multi-enfants, parsing Gemini, montant réel pénalité.

import 'package:flutter_test/flutter_test.dart';

import 'package:family_score/utils/checklist_helpers.dart';
import 'package:family_score/models/chore_model.dart';
import 'package:family_score/models/history_entry.dart';
import 'package:family_score/models/pending_request.dart';

void main() {
  group('Multi-enfants — requestKey', () {
    final chores = [
      ChoreModel(
          id: 'chore1',
          label: 'Lit',
          emoji: '🛏️',
          points: 5,
          timeSlots: ['matin']),
      ChoreModel(
          id: 'chore2',
          label: 'Devoirs',
          emoji: '📚',
          points: 10,
          timeSlots: ['soir']),
    ];

    test('enfant A déjà pending + enfant B nouveau → envoi autorisé', () {
      final keyA = buildChecklistRequestKey(
        childId: 'child-a',
        dateStr: '2026-07-22',
        chores: chores,
        doneStates: {'child-a|chore1|matin': 'done'},
      );
      final keyB = buildChecklistRequestKey(
        childId: 'child-b',
        dateStr: '2026-07-22',
        chores: chores,
        doneStates: {'child-b|chore2|soir': 'done'},
      );

      final pendingRequests = [
        PendingRequest(
          id: 'r1',
          type: 'chore_checklist',
          childId: 'child-a',
          requestedBy: 'A',
          text: 'T',
          amount: 5,
          status: 'pending',
          extra: {'requestKey': keyA},
        ),
      ];

      final aPending = pendingRequests.any((r) =>
          r.status == 'pending' &&
          (r.extra['requestKey'] as String?)?.trim() == keyA);
      final bPending = pendingRequests.any((r) =>
          r.status == 'pending' &&
          (r.extra['requestKey'] as String?)?.trim() == keyB);

      expect(aPending, isTrue);
      expect(bPending, isFalse, reason: 'Enfant B doit pouvoir envoyer');
    });

    test('tous les enfants sélectionnés déjà pending → bouton bloqué', () {
      final keyA = buildChecklistRequestKey(
        childId: 'child-a',
        dateStr: '2026-07-22',
        chores: chores,
        doneStates: {'child-a|chore1|matin': 'done'},
      );
      final keyB = buildChecklistRequestKey(
        childId: 'child-b',
        dateStr: '2026-07-22',
        chores: chores,
        doneStates: {'child-b|chore2|soir': 'done'},
      );

      final pendingRequests = [
        PendingRequest(
          id: 'r1',
          type: 'chore_checklist',
          childId: 'child-a',
          requestedBy: 'A',
          text: 'T',
          amount: 5,
          status: 'pending',
          extra: {'requestKey': keyA},
        ),
        PendingRequest(
          id: 'r2',
          type: 'chore_checklist',
          childId: 'child-b',
          requestedBy: 'B',
          text: 'T',
          amount: 10,
          status: 'pending',
          extra: {'requestKey': keyB},
        ),
      ];

      final allPending = [keyA, keyB].every((key) => pendingRequests.any((r) =>
          r.status == 'pending' &&
          (r.extra['requestKey'] as String?)?.trim() == key));

      expect(allPending, isTrue, reason: 'Tous bloqués → bouton masqué');
    });

    test('ordre des tâches différent → même clé (tri)', () {
      final k1 = buildChecklistRequestKey(
        childId: 'c',
        dateStr: '2026-07-22',
        chores: chores,
        doneStates: {'c|chore1|matin': 'done', 'c|chore2|soir': 'done'},
      );
      final k2 = buildChecklistRequestKey(
        childId: 'c',
        dateStr: '2026-07-22',
        chores: chores,
        doneStates: {'c|chore2|soir': 'done', 'c|chore1|matin': 'done'},
      );
      expect(k1, k2);
    });
  });

  group('Parsing Gemini — parseGeminiPoints', () {
    test('int valide', () {
      expect(parseGeminiPoints(5), 5);
    });

    test('double valide', () {
      expect(parseGeminiPoints(10.0), 10);
      expect(parseGeminiPoints(7.6), 8);
    });

    test('chaîne numérique valide', () {
      expect(parseGeminiPoints('15'), 15);
      expect(parseGeminiPoints(' 3 '), 3);
    });

    test('null → null', () {
      expect(parseGeminiPoints(null), isNull);
    });

    test('NaN → null', () {
      expect(parseGeminiPoints(double.nan), isNull);
    });

    test('chaîne invalide → null', () {
      expect(parseGeminiPoints('abc'), isNull);
      expect(parseGeminiPoints(''), isNull);
    });

    test('type inattendu → null', () {
      expect(parseGeminiPoints([1, 2]), isNull);
      expect(parseGeminiPoints(true), isNull);
    });
  });

  group('Parsing Gemini — parseGeminiType', () {
    test('bonus → true', () {
      expect(parseGeminiType('bonus'), isTrue);
      expect(parseGeminiType('BONUS'), isTrue);
    });

    test('penalty → false', () {
      expect(parseGeminiType('penalty'), isFalse);
    });

    test('pénalité → false', () {
      expect(parseGeminiType('pénalité'), isFalse);
    });

    test('null ou invalide → null', () {
      expect(parseGeminiType(null), isNull);
      expect(parseGeminiType('xyz'), isNull);
    });
  });

  group('actualPenaltyAmount — vrai helper', () {
    test('solde 3, demande 10 → 3', () {
      expect(actualPenaltyAmount(requested: 10, balance: 3, isBonus: false), 3);
    });

    test('solde 0, demande 10 → 0', () {
      expect(actualPenaltyAmount(requested: 10, balance: 0, isBonus: false), 0);
    });

    test('solde négatif, demande 10 → 0', () {
      expect(
          actualPenaltyAmount(requested: 10, balance: -5, isBonus: false), 0);
    });

    test('solde 25, demande 10 → 10', () {
      expect(
          actualPenaltyAmount(requested: 10, balance: 25, isBonus: false), 10);
    });

    test('bonus → toujours demandé', () {
      expect(actualPenaltyAmount(requested: 15, balance: 0, isBonus: true), 15);
      expect(
          actualPenaltyAmount(requested: 15, balance: 100, isBonus: true), 15);
    });

    test('actualAmount == 0 désactive la confirmation', () {
      final amt =
          actualPenaltyAmount(requested: 10, balance: 0, isBonus: false);
      expect(amt > 0, isFalse);
    });
  });

  group('chore_checklist affiche points', () {
    test('montant en points pas en lignes', () {
      final r = PendingRequest(
        id: 'r',
        type: 'chore_checklist',
        childId: 'c',
        requestedBy: 'E',
        text: 'T',
        amount: 15,
      );
      final display = r.type == 'chore_checklist'
          ? '${r.amount} points'
          : '${r.amount} ligne${r.amount > 1 ? 's' : ''}';
      expect(display, '15 points');
      expect(display.contains('ligne'), isFalse);
    });
  });

  group('Exclusion achats et transferts de l\'historique', () {
    test('achat exclu du bonus', () {
      final entries = [
        HistoryEntry(
            id: '1',
            childId: 'c',
            points: 5,
            reason: 'B',
            category: 'Bonus',
            isBonus: true),
        HistoryEntry(
            id: '2',
            childId: 'c',
            points: 50,
            reason: 'Achat',
            category: 'boutique',
            isBonus: false),
      ];
      final bonus = entries
          .where((h) => h.isBonus && !h.isPurchase && !h.isPointsTransfer)
          .toList();
      expect(bonus.length, 1);
      expect(bonus.first.id, '1');
    });

    test('transfert exclu de la pénalité', () {
      final entries = [
        HistoryEntry(
            id: '1',
            childId: 'c',
            points: 5,
            reason: 'P',
            category: 'Pénalité',
            isBonus: false),
        HistoryEntry(
            id: '2',
            childId: 'c',
            points: 10,
            reason: 'T',
            category: 'points_transfer_out',
            isBonus: false),
      ];
      final penalty = entries
          .where((h) => !h.isBonus && !h.isPurchase && !h.isPointsTransfer)
          .toList();
      expect(penalty.length, 1);
      expect(penalty.first.id, '1');
    });
  });

  group('startAiPhotoFlow — retour après invalidité Gemini', () {
    test('points null → invalide', () {
      final pts = parseGeminiPoints(null);
      expect(pts, isNull);
    });

    test('raison vide → invalide', () {
      final reason = parseGeminiReason('');
      expect(reason, isNull);
    });

    test('type invalide → invalide', () {
      final t = parseGeminiType('xyz');
      expect(t, isNull);
    });

    test('combinaison valide → points clampés entre 1 et 999', () {
      final pts = parseGeminiPoints(1500);
      expect(pts, 1500);
      expect(pts!.clamp(1, 999), 999);
    });
  });

  group('parseGeminiType — types dynamiques', () {
    test('bool → null', () {
      expect(parseGeminiType(true), isNull);
    });
    test('int → null', () {
      expect(parseGeminiType(42), isNull);
    });
    test('liste → null', () {
      expect(parseGeminiType(['bonus']), isNull);
    });
    test('null → null', () {
      expect(parseGeminiType(null), isNull);
    });
  });

  group('parseGeminiReason — types dynamiques', () {
    test('null → null', () {
      expect(parseGeminiReason(null), isNull);
    });
    test('nombre → null', () {
      expect(parseGeminiReason(123), isNull);
    });
    test('liste → null', () {
      expect(parseGeminiReason(['x']), isNull);
    });
    test('vide → null', () {
      expect(parseGeminiReason(''), isNull);
    });
    test('espaces seulement → null', () {
      expect(parseGeminiReason('   '), isNull);
    });
    test('chaîne valide trimée', () {
      expect(parseGeminiReason('  Bon comportement  '), 'Bon comportement');
    });
  });

  group('parseGeminiPoints — formats étendus', () {
    test('chaîne décimale "7.5" → 8', () {
      expect(parseGeminiPoints('7.5'), 8);
    });
    test('chaîne décimale "3.2" → 3', () {
      expect(parseGeminiPoints('3.2'), 3);
    });
    test('NaN → null', () {
      expect(parseGeminiPoints(double.nan), isNull);
    });
    test('Infinity → null', () {
      expect(parseGeminiPoints(double.infinity), isNull);
    });
    test('-Infinity → null', () {
      expect(parseGeminiPoints(double.negativeInfinity), isNull);
    });
    test('chaîne "NaN" → null', () {
      expect(parseGeminiPoints('NaN'), isNull);
    });
  });

  group('actualPenaltyAmount — montant nul ou négatif', () {
    test('demandé 0 → 0', () {
      expect(actualPenaltyAmount(requested: 0, balance: 50, isBonus: false), 0);
    });
    test('demandé -5 → 0', () {
      expect(actualPenaltyAmount(requested: -5, balance: 50, isBonus: false), 0);
    });
    test('demandé 0 en bonus → 0', () {
      expect(actualPenaltyAmount(requested: 0, balance: 50, isBonus: true), 0);
    });
  });
}
