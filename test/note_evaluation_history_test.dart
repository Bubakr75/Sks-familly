import 'package:flutter_test/flutter_test.dart';
import 'package:family_score/models/note_model.dart';

void main() {
  group('Historique structuré des évaluations', () {
    test('conserve toutes les notes pendant la sérialisation', () {
      final note = NoteModel(
        id: 'evaluation-1',
        childId: 'child-1',
        text: 'Bulletin hebdomadaire',
        isEvaluation: true,
        aiScore: 16,
        parentScore: 18,
        overallScore: 17,
        categoryScores: const {
          'Respect': 18,
          'Coopération': 15,
          'Autonomie': 17,
          'Gestion des émotions': 14,
        },
      );

      final restored = NoteModel.fromMap(note.toMap());

      expect(restored.isEvaluation, isTrue);
      expect(restored.aiScore, 16);
      expect(restored.parentScore, 18);
      expect(restored.overallScore, 17);
      expect(restored.categoryScores['Respect'], 18);
      expect(restored.categoryScores['Coopération'], 15);
      expect(restored.categoryScores['Autonomie'], 17);
      expect(restored.categoryScores['Gestion des émotions'], 14);
    });

    test('reconnaît les anciens bulletins enregistrés en texte', () {
      final note = NoteModel.fromMap({
        'id': 'legacy',
        'childId': 'child-1',
        'text': 'Bulletin: IA=14/20 Parent=18/20 Moy=16/20 | '
            'Respect=17/20 | Coopération=15/20 | Autonomie=13/20 | '
            'Gestion des émotions=19/20 | Très bonne semaine',
        'createdAt': '2026-07-17T20:00:00.000',
      });

      expect(note.isEvaluation, isTrue);
      expect(note.aiScore, 14);
      expect(note.parentScore, 18);
      expect(note.overallScore, 16);
      expect(note.categoryScores['Respect'], 17);
      expect(note.categoryScores['Coopération'], 15);
      expect(note.categoryScores['Autonomie'], 13);
      expect(note.categoryScores['Gestion des émotions'], 19);
    });

    test('accepte un ancien bulletin avec IA indisponible', () {
      final note = NoteModel.fromMap({
        'id': 'legacy-no-ai',
        'childId': 'child-1',
        'text': 'Bulletin: IA=indisponible Parent=12/20 Moy=12/20 | '
            'Respect=10/20',
      });

      expect(note.isEvaluation, isTrue);
      expect(note.aiScore, isNull);
      expect(note.parentScore, 12);
      expect(note.overallScore, 12);
      expect(note.categoryScores['Respect'], 10);
    });

    test('une note manuelle ne devient pas une évaluation', () {
      final note = NoteModel.fromMap({
        'id': 'manual',
        'childId': 'child-1',
        'text': 'Penser au rendez-vous de mercredi',
      });

      expect(note.isEvaluation, isFalse);
      expect(note.overallScore, isNull);
      expect(note.categoryScores, isEmpty);
    });

    test('limite les valeurs incorrectes entre zéro et vingt', () {
      final note = NoteModel.fromMap({
        'id': 'invalid-values',
        'childId': 'child-1',
        'text': 'Évaluation',
        'isEvaluation': true,
        'overallScore': 99,
        'categoryScores': {
          'Respect': -10,
          'Autonomie': 50,
        },
      });

      expect(note.overallScore, 20);
      expect(note.categoryScores['Respect'], 0);
      expect(note.categoryScores['Autonomie'], 20);
    });
  });
}
