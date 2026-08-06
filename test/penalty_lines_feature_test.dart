import 'package:family_score/models/punishment_lines.dart';
import 'package:family_score/services/point_action_submission_service.dart';
import 'package:flutter_test/flutter_test.dart';

PunishmentLines linkedLines({
  required String id,
  String childId = 'child-1',
  PenaltyLinesStatus status = PenaltyLinesStatus.pending,
}) {
  return PunishmentLines(
    id: id,
    childId: childId,
    text: 'Je respecte les règles.',
    totalLines: 20,
    penaltyHistoryId: id,
    status: status,
  );
}

void main() {
  group('Création d’une pénalité avec lignes', () {
    test('sans lignes reste une pénalité normale', () {
      const draft = PointActionDraft(
        actionId: 'a1',
        childId: 'child-1',
        amount: 5,
        reason: 'Test',
        category: 'Pénalité',
        isBonus: false,
        hasPhoto: false,
      );
      expect(draft.hasPenaltyLines, isFalse);
    });

    test('avec lignes expose le nombre et la consigne', () {
      const draft = PointActionDraft(
        actionId: 'a2',
        childId: 'child-1',
        amount: 5,
        reason: 'Test',
        category: 'Pénalité',
        isBonus: false,
        hasPhoto: false,
        penaltyLinesCount: 25,
        penaltyLinesInstruction: 'Je parle calmement.',
      );
      expect(draft.hasPenaltyLines, isTrue);
      expect(draft.penaltyLinesCount, 25);
    });

    test('refuse zéro et les nombres négatifs', () {
      expect(PenaltyLinesAccess.isValidCount(0), isFalse);
      expect(PenaltyLinesAccess.isValidCount(-1), isFalse);
      expect(PenaltyLinesAccess.isValidCount(1), isTrue);
    });
  });

  group('Compatibilité et données invalides', () {
    test('une ancienne pénalité sans nouveau champ ne bloque pas', () {
      final legacy = PunishmentLines.fromMap({
        'id': 'legacy',
        'childId': 'child-1',
        'text': 'Ancienne punition',
        'totalLines': 10,
        'completedLines': 0,
      });
      expect(legacy.isLinkedToPenalty, isFalse);
      expect(legacy.blocksScreenAccess, isFalse);
    });

    test('les données Firebase invalides restent sûres et non bloquantes', () {
      final invalid = PunishmentLines.fromMap({
        'id': 42,
        'childId': null,
        'penaltyHistoryId': 'history-1',
        'penaltyLinesCount': -50,
        'penaltyLinesStatus': 'inconnu',
        'photoUrls': [1, null],
      });
      expect(invalid.totalLines, 0);
      expect(invalid.blocksScreenAccess, isFalse);
      expect(invalid.photoUrls, isEmpty);
    });
  });

  group('Blocage centralisé', () {
    test('bloque avec une obligation en attente', () {
      expect(
        PenaltyLinesAccess.shouldBlockScreenAccess(
          isParentMode: false,
          punishments: [linkedLines(id: 'p1')],
          childId: 'child-1',
        ),
        isTrue,
      );
    });

    test('reste bloqué si une autre obligation est encore en attente', () {
      final items = [
        linkedLines(id: 'p1', status: PenaltyLinesStatus.completed),
        linkedLines(id: 'p2'),
      ];
      expect(
          PenaltyLinesAccess.pendingForChild(items, 'child-1'), hasLength(1));
    });

    test('se débloque après validation de la dernière obligation', () {
      final items = [
        linkedLines(id: 'p1', status: PenaltyLinesStatus.completed),
        linkedLines(id: 'p2', status: PenaltyLinesStatus.completed),
      ];
      expect(PenaltyLinesAccess.pendingForChild(items, 'child-1'), isEmpty);
    });

    test('un parent n’est jamais bloqué', () {
      expect(
        PenaltyLinesAccess.shouldBlockScreenAccess(
          isParentMode: true,
          punishments: [linkedLines(id: 'p1')],
          childId: 'child-1',
        ),
        isFalse,
      );
    });

    test('un changement synchronisé recalcule immédiatement l’état', () {
      var synced = [linkedLines(id: 'p1')];
      expect(PenaltyLinesAccess.pendingForChild(synced, 'child-1'), isNotEmpty);
      synced = [
        linkedLines(id: 'p1', status: PenaltyLinesStatus.completed),
      ];
      expect(PenaltyLinesAccess.pendingForChild(synced, 'child-1'), isEmpty);
    });
  });
}
