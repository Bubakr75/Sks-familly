import 'package:family_score/services/gemini_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late List<Map<String, dynamic>> questions;

  setUp(() {
    questions = GeminiService.generateQuizQuestions(
      theme: 'Comportement',
      age: 10,
    );
  });

  group('Catégories du questionnaire', () {
    test('les quatre catégories sont présentes', () {
      expect(
        GeminiService.scoreCategories,
        [
          'Respect',
          'Coopération',
          'Autonomie',
          'Gestion des émotions',
        ],
      );
    });

    test('chaque question possède une catégorie valide', () {
      for (final question in questions) {
        expect(question.containsKey('category'), isTrue);

        expect(
          GeminiService.scoreCategories,
          contains(question['category']),
        );
      }
    });

    test('les dix questions sont réparties entre les catégories', () {
      final counts = <String, int>{};

      for (final question in questions) {
        final category = question['category'] as String;
        counts[category] = (counts[category] ?? 0) + 1;
      }

      expect(counts['Respect'], 2);
      expect(counts['Coopération'], 3);
      expect(counts['Autonomie'], 2);
      expect(counts['Gestion des émotions'], 3);
    });
  });

  group('GeminiService.calculateCategoryScores', () {
    test('toutes les meilleures réponses donnent 20 partout', () {
      final answers = List<int>.filled(questions.length, 0);

      final scores = GeminiService.calculateCategoryScores(
        questions,
        answers,
      );

      expect(scores['Respect'], 20);
      expect(scores['Coopération'], 20);
      expect(scores['Autonomie'], 20);
      expect(scores['Gestion des émotions'], 20);
    });

    test('toutes les moins bonnes réponses donnent zéro partout', () {
      final answers = List<int>.filled(questions.length, 3);

      final scores = GeminiService.calculateCategoryScores(
        questions,
        answers,
      );

      expect(scores['Respect'], 0);
      expect(scores['Coopération'], 0);
      expect(scores['Autonomie'], 0);
      expect(scores['Gestion des émotions'], 0);
    });

    test('calcule chaque catégorie indépendamment', () {
      final answers = <int>[
        0,
        3,
        0,
        3,
        0,
        3,
        0,
        3,
        0,
        3,
      ];

      final scores = GeminiService.calculateCategoryScores(
        questions,
        answers,
      );

      expect(scores['Respect'], 10);
      expect(scores['Coopération'], 7);
      expect(scores['Autonomie'], 10);
      expect(scores['Gestion des émotions'], 13);
    });

    test('conserve toujours une note entre zéro et vingt', () {
      final scores = GeminiService.calculateCategoryScores(
        questions,
        List<int>.filled(questions.length, 99),
      );

      for (final score in scores.values) {
        expect(score, inInclusiveRange(0, 20));
      }
    });

    test('les réponses manquantes comptent pour zéro', () {
      final scores = GeminiService.calculateCategoryScores(
        questions,
        const [],
      );

      expect(scores.values, everyElement(0));
    });
  });
}
