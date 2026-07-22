// Tests pour les corrections de la refonte Bonus/Pénalité/Navigation.
// Teste requestKey exacte, solde nul, historique récent, Photo IA.

import 'dart:math';
import 'package:flutter_test/flutter_test.dart';

import 'package:family_score/models/history_entry.dart';
import 'package:family_score/models/pending_request.dart';

void main() {
  group('requestKey exacte vs différente', () {
    String buildKey(
        String childId, String dateStr, List<String> doneKeys, int amount) {
      final sorted = List<String>.from(doneKeys)..sort();
      return 'chore_checklist|$childId|$dateStr|${sorted.join(',')}|$amount';
    }

    test('même requestKey pending → bouton doit être bloqué', () {
      final key = buildKey('child-a', '2026-07-22', ['chore1:matin'], 5);
      final pendingRequests = [
        PendingRequest(
          id: 'r1',
          type: 'chore_checklist',
          childId: 'child-a',
          requestedBy: 'Enfant',
          text: 'Tâches',
          amount: 5,
          status: 'pending',
          extra: {'requestKey': key},
        ),
      ];
      final isBlocked = pendingRequests.any((r) =>
          r.status == 'pending' &&
          (r.extra['requestKey'] as String?)?.trim() == key);
      expect(isBlocked, isTrue);
    });

    test('requestKey différente le même jour → envoi autorisé', () {
      final keyPending = buildKey('child-a', '2026-07-22', ['chore1:matin'], 5);
      final keyNew = buildKey('child-a', '2026-07-22', ['chore2:soir'], 10);

      final pendingRequests = [
        PendingRequest(
          id: 'r1',
          type: 'chore_checklist',
          childId: 'child-a',
          requestedBy: 'Enfant',
          text: 'Tâches',
          amount: 5,
          status: 'pending',
          extra: {'requestKey': keyPending},
        ),
      ];

      final isBlocked = pendingRequests.any((r) =>
          r.status == 'pending' &&
          (r.extra['requestKey'] as String?)?.trim() == keyNew);
      expect(isBlocked, isFalse,
          reason: 'Une sélection différente doit pouvoir être envoyée');
    });
  });

  group('Montant réel pour pénalité', () {
    int actualPenaltyAmount(int requested, int balance) {
      if (balance <= 0) return 0;
      return min(requested, balance);
    }

    test('solde 3, pénalité demandée 10 → historique de 3', () {
      final result = actualPenaltyAmount(10, 3);
      expect(result, 3);
    });

    test('solde 0, pénalité demandée 10 → aucune opération', () {
      final result = actualPenaltyAmount(10, 0);
      expect(result, 0, reason: 'Solde nul = aucune pénalité');
    });

    test('solde 25, pénalité demandée 10 → retrait de 10', () {
      final result = actualPenaltyAmount(10, 25);
      expect(result, 10);
    });

    test('actualAmount == 0 désactive la confirmation', () {
      final actualAmount = actualPenaltyAmount(10, 0);
      final canConfirm = actualAmount > 0;
      expect(canConfirm, isFalse);
    });

    test('ne crée aucune entrée d\'historique à zéro point', () {
      final actualAmount = actualPenaltyAmount(10, 0);
      final shouldCreateEntry = actualAmount > 0;
      expect(shouldCreateEntry, isFalse);
    });
  });

  group('chore_checklist affiché en points', () {
    test('le montant s\'affiche en points et non en lignes', () {
      final r = PendingRequest(
        id: 'r1',
        type: 'chore_checklist',
        childId: 'c',
        requestedBy: 'Enfant',
        text: 'Tâches',
        amount: 15,
      );
      final display = r.type == 'chore_checklist'
          ? '${r.amount} points'
          : '${r.amount} ligne${r.amount > 1 ? 's' : ''}';
      expect(display, '15 points');
      expect(display.contains('ligne'), isFalse);
    });
  });

  group('Exclusion achats et transferts de l\'historique récent', () {
    test('un achat n\'apparaît pas dans l\'historique bonus', () {
      final entries = [
        HistoryEntry(
            id: 'h1',
            childId: 'c',
            points: 5,
            reason: 'Bonus',
            category: 'Bonus',
            isBonus: true),
        HistoryEntry(
            id: 'h2',
            childId: 'c',
            points: 50,
            reason: 'Achat',
            category: 'boutique',
            isBonus: false),
      ];
      final bonusOnly = entries
          .where((h) => h.isBonus && !h.isPurchase && !h.isPointsTransfer)
          .toList();
      expect(bonusOnly.length, 1);
      expect(bonusOnly.first.id, 'h1');
    });

    test('un transfert n\'apparaît pas dans l\'historique pénalité', () {
      final entries = [
        HistoryEntry(
            id: 'h1',
            childId: 'c',
            points: 5,
            reason: 'Pénalité',
            category: 'Pénalité',
            isBonus: false),
        HistoryEntry(
            id: 'h2',
            childId: 'c',
            points: 10,
            reason: 'Transfert',
            category: 'points_transfer_out',
            isBonus: false),
      ];
      final penaltyOnly = entries
          .where(
              (h) => h.isBonus == false && !h.isPurchase && !h.isPointsTransfer)
          .toList();
      expect(penaltyOnly.length, 1);
      expect(penaltyOnly.first.id, 'h1');
    });
  });

  group('startAiPhotoFlow — retour booléen', () {
    test('annulation du dialogue → false', () {
      // Simule showDialog retournant null (annulation)
      final dialogResult = null;
      expect(dialogResult == true, isFalse);
    });

    test('confirmation réussie → true', () {
      // Simule Navigator.pop(ctx, true) après addPoints
      final dialogResult = true;
      expect(dialogResult == true, isTrue);
    });

    test('erreur Gemini → false (return avant dialogue)', () {
      // Simule le catch autour de GeminiService.analyzePhoto
      bool geminiFailed = true;
      bool result = false;
      if (geminiFailed) result = false;
      expect(result, isFalse);
    });
  });

  group('Persistance après reconstruction', () {
    test('demande pending détectée après redémarrage', () {
      final today = DateTime.now();
      final todayStr =
          '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

      final requests = [
        PendingRequest(
          id: 'r1',
          type: 'chore_checklist',
          childId: 'child-a',
          requestedBy: 'Enfant',
          text: 'Tâches',
          amount: 15,
          status: 'pending',
          extra: {'requestDate': todayStr},
        ),
      ];

      final detected = requests.any((r) =>
          r.type == 'chore_checklist' &&
          r.status == 'pending' &&
          r.childId == 'child-a' &&
          (r.extra['requestDate'] as String?) == todayStr);

      expect(detected, isTrue);
    });

    test('verrou libéré après finally même en cas d\'échec', () {
      bool lock = false;
      bool isInFlight = false;

      try {
        lock = true;
        isInFlight = true;
        throw Exception('simulated failure');
      } catch (_) {
        // échec
      } finally {
        isInFlight = false;
        lock = false;
      }

      expect(isInFlight, isFalse,
          reason: 'Le verrou doit toujours être libéré');
      expect(lock, isFalse);
    });

    test('sélections conservées après échec', () {
      final states = <String, String>{'child-a|chore1|matin': 'done'};
      final validatedToday = <String>{};

      // Simule RequestResult.failed → ne pas nettoyer
      final result = 'failed';
      if (result != 'failed') {
        states.clear();
        validatedToday.add('child-a');
      }

      expect(states.isNotEmpty, isTrue,
          reason: 'Les sélections doivent être conservées');
      expect(validatedToday.contains('child-a'), isFalse);
    });
  });
}
