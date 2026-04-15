// lib/services/gemini_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;

class GeminiService {
  static const String _apiKey = 'AIzaSyBzyWQB3qLYtVakVzInkd5Z86882kayssU'; // ← remplace par ta vraie clé
  static const String _baseUrl =
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent';

  // ══════════════════════════════════════════════════════════════
  // APPRÉCIATION JOURNALIÈRE
  // ══════════════════════════════════════════════════════════════
  static Future<String> generateAppreciation({
    required String childName,
    required String context,
    required Map<String, String> answers,
  }) async {
    final answersText =
        answers.entries.map((e) => '- ${e.key} : ${e.value}').join('\n');

    final prompt = '''
Tu es un assistant bienveillant qui aide des parents à évaluer le comportement de leurs enfants.
Contexte de la journée : $context
Prénom de l'enfant : $childName
Réponses du parent au questionnaire :
$answersText
En fonction de ces réponses :
1. Donne une note sur 20
2. Écris une appréciation courte et bienveillante de 2-3 phrases maximum
3. Donne un conseil rapide au parent
Réponds UNIQUEMENT au format JSON suivant, sans markdown :
{ "note": 15, "appreciation": "...", "conseil": "..." }
''';

    try {
      final response = await http.post(
        Uri.parse('$_baseUrl?key=$_apiKey'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'contents': [
            {
              'parts': [
                {'text': prompt}
              ]
            }
          ],
          'generationConfig': {
            'temperature': 0.7,
            'maxOutputTokens': 300,
          },
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final text =
            data['candidates'][0]['content']['parts'][0]['text'] as String;
        return text.replaceAll('```json', '').replaceAll('```', '').trim();
      }
      return '{"note": -1, "appreciation": "Erreur API ${response.statusCode}", "conseil": ""}';
    } catch (e) {
      return '{"note": -1, "appreciation": "Erreur réseau", "conseil": "$e"}';
    }
  }

  // ══════════════════════════════════════════════════════════════
  // QUIZ IA — QUESTIONS ADAPTÉES À L'ÂGE ET À LA DIFFICULTÉ
  // ══════════════════════════════════════════════════════════════
  static Future<List<Map<String, dynamic>>> generateQuizQuestions({
    required String theme,
    required int age,
    required String difficulty, // 'facile' | 'moyen' | 'difficile'
  }) async {

    // Nombre de choix selon l'âge
    int nbChoices;
    if (age <= 6) {
      nbChoices = 2;
    } else if (age <= 9) {
      nbChoices = 3;
    } else {
      nbChoices = 4;
    }

    // Texte de difficulté pour le prompt
    String difficultyText;
    switch (difficulty) {
      case 'difficile':
        difficultyText =
            'très difficile, avec des pièges et des détails précis, pour un enfant de $age ans';
        break;
      case 'moyen':
        difficultyText =
            'intermédiaire, ni trop simple ni trop difficile, adapté à un enfant de $age ans';
        break;
      default: // 'facile'
        difficultyText =
            'facile, simple et ludique, adapté à un enfant de $age ans';
    }

    final prompt = '''
Tu es un générateur de quiz éducatif pour enfants.
Génère exactement 3 questions QCM sur le thème : $theme.
Niveau de difficulté : $difficultyText.
Chaque question doit avoir exactement $nbChoices choix de réponse.
Les questions doivent être variées et intéressantes.

Réponds UNIQUEMENT avec un tableau JSON valide, sans markdown, sans texte avant ou après.
Format attendu :
[
  {
    "question": "Ta question ici ?",
    "choices": ["Réponse A", "Réponse B", "Réponse C", "Réponse D"],
    "correct": 0
  },
  {
    "question": "Ta question ici ?",
    "choices": ["Réponse A", "Réponse B", "Réponse C", "Réponse D"],
    "correct": 2
  },
  {
    "question": "Ta question ici ?",
    "choices": ["Réponse A", "Réponse B", "Réponse C", "Réponse D"],
    "correct": 1
  }
]
"correct" est l'index 0-based de la bonne réponse.
Adapte le nombre de choix à $nbChoices par question.
''';

    try {
      final response = await http.post(
        Uri.parse('$_baseUrl?key=$_apiKey'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'contents': [
            {
              'parts': [
                {'text': prompt}
              ]
            }
          ],
          'generationConfig': {
            'temperature': 0.7,
            'maxOutputTokens': 1024,
          },
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final text =
            data['candidates'][0]['content']['parts'][0]['text'] as String;

        // Nettoyage agressif du texte retourné
        String cleaned = text
            .replaceAll('```json', '')
            .replaceAll('```', '')
            .trim();

        // Extraire uniquement le tableau JSON
        final startIndex = cleaned.indexOf('[');
        final endIndex = cleaned.lastIndexOf(']');
        if (startIndex != -1 && endIndex != -1) {
          cleaned = cleaned.substring(startIndex, endIndex + 1);
        }

        final List<dynamic> parsed = jsonDecode(cleaned);
        return parsed.cast<Map<String, dynamic>>();
      } else {
        throw Exception('Status ${response.statusCode} : ${response.body}');
      }
    } catch (e) {
      throw Exception('Erreur Gemini : $e');
    }
  }
}
