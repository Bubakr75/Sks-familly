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

  group('GeminiService.calculateScore', () {
    test('toutes les meilleures réponses donnent 20', () {
      final answers = List<int>.filled(questions.length, 0);

      expect(
        GeminiService.calculateScore(questions, answers),
        20,
      );
    });

    test('toutes les réponses index 1 donnent 13', () {
      final answers = List<int>.filled(questions.length, 1);

      expect(
        GeminiService.calculateScore(questions, answers),
        13,
      );
    });

    test('toutes les réponses index 2 donnent 7', () {
      final answers = List<int>.filled(questions.length, 2);

      expect(
        GeminiService.calculateScore(questions, answers),
        7,
      );
    });

    test('toutes les moins bonnes réponses donnent 0', () {
      final answers = List<int>.filled(questions.length, 3);

      expect(
        GeminiService.calculateScore(questions, answers),
        0,
      );
    });

    test('une moitié parfaite et une moitié mauvaise donnent 10', () {
      final answers = <int>[
        0,
        0,
        0,
        0,
        0,
        3,
        3,
        3,
        3,
        3,
      ];

      expect(
        GeminiService.calculateScore(questions, answers),
        10,
      );
    });

    test('accepte les réponses sous forme de texte', () {
      final answers = questions
          .map((question) => (question['answers'] as List).first)
          .toList();

      expect(
        GeminiService.calculateScore(questions, answers),
        20,
      );
    });

    test('les réponses inconnues rapportent zéro', () {
      final answers = List<String>.filled(
        questions.length,
        'Réponse inconnue',
      );

      expect(
        GeminiService.calculateScore(questions, answers),
        0,
      );
    });

    test('les index invalides rapportent zéro', () {
      final answers = List<int>.filled(questions.length, 99);

      expect(
        GeminiService.calculateScore(questions, answers),
        0,
      );
    });

    test('les réponses manquantes comptent pour zéro', () {
      final answers = List<int>.filled(5, 0);

      expect(
        GeminiService.calculateScore(questions, answers),
        10,
      );
    });

    test('une liste de questions vide donne zéro', () {
      expect(
        GeminiService.calculateScore(const [], const []),
        0,
      );
    });

    test('respecte un correctIndex placé en dernière position', () {
      final customQuestions = <Map<String, dynamic>>[
        {
          'question': 'Test inversé',
          'answers': ['Mauvais', 'Moyen', 'Bien', 'Excellent'],
          'correctIndex': 3,
        },
      ];

      expect(
        GeminiService.calculateScore(customQuestions, [3]),
        20,
      );

      expect(
        GeminiService.calculateScore(customQuestions, [0]),
        0,
      );
    });

    test('respecte la pondération des questions', () {
      final weightedQuestions = <Map<String, dynamic>>[
        {
          'question': 'Question importante',
          'answers': ['Excellent', 'Bien', 'Moyen', 'Mauvais'],
          'correctIndex': 0,
          'weight': 3.0,
        },
        {
          'question': 'Question normale',
          'answers': ['Excellent', 'Bien', 'Moyen', 'Mauvais'],
          'correctIndex': 0,
          'weight': 1.0,
        },
      ];

      expect(
        GeminiService.calculateScore(weightedQuestions, [0, 3]),
        15,
      );
    });
  });
}
