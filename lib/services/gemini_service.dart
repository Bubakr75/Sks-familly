// lib/services/gemini_service.dart

import 'dart:convert';
import 'package:http/http.dart' as http;

class GeminiService {
  static const String _apiKey = String.fromEnvironment('GEMINI_API_KEY');
  static const String _baseUrl =
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent';

  static Future<String> generateAppreciation({
    required String childName,
    required String context,
    required Map<String, String> answers,
  }) async {
    if (_apiKey.isEmpty) {
      return '{"note": -1, "appreciation": "Clé API manquante", "conseil": ""}';
    }

    final answersText = answers.entries
        .map((e) => '- ${e.key} : ${e.value}')
        .join('\n');

    final prompt = '''
Tu es un assistant bienveillant qui aide des parents à évaluer le comportement de leurs enfants.

Contexte de la journée : $context
Prénom de l'enfant : $childName

Réponses du parent au questionnaire :
$answersText

En fonction de ces réponses :
1. Donne une note sur 20 (sois précis et juste, pas trop sévère ni trop indulgent)
2. Écris une appréciation courte et bienveillante de 2-3 phrases maximum
3. Donne un conseil rapide au parent

Réponds UNIQUEMENT au format JSON suivant, sans markdown :
{
  "note": 15,
  "appreciation": "Bonne journée dans l'ensemble...",
  "conseil": "Encouragez..."
}
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
            'maxOutputTokens': 512,
          },
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final text =
            data['candidates'][0]['content']['parts'][0]['text'] as String;
        final cleanText = text
            .replaceAll('```json', '')
            .replaceAll('```', '')
            .trim();
        return cleanText;
      } else {
        // Retourne le code d'erreur pour debug
        return '{"note": -1, "appreciation": "Erreur API ${response.statusCode}", "conseil": "${response.body.substring(0, response.body.length.clamp(0, 100))}"}';
      }
    } catch (e) {
      return '{"note": -1, "appreciation": "Erreur réseau : $e", "conseil": ""}';
    }
  }

  static Future<List<Map<String, dynamic>>> generateQuizQuestions({
    required String theme,
    required int age,
  }) async {
    if (_apiKey.isEmpty) return [];

    String difficulty;
    int nbChoices;

    if (age <= 6) {
      difficulty =
          'très simple, adapté à un enfant de $age ans, avec des mots très courts et faciles';
      nbChoices = 2;
    } else if (age <= 9) {
      difficulty = 'simple et ludique, adapté à un enfant de $age ans';
      nbChoices = 3;
    } else if (age <= 12) {
      difficulty =
          'intermédiaire, adapté à un enfant de $age ans, ni trop facile ni trop difficile';
      nbChoices = 4;
    } else {
      difficulty =
          'difficile avec des pièges subtils, adapté à un adolescent de $age ans';
      nbChoices = 4;
    }

    final prompt = '''
Tu es un générateur de quiz éducatif pour enfants et adolescents.
Génère exactement 3 questions QCM sur le thème : $theme.
Niveau de difficulté : $difficulty.
Chaque question doit avoir exactement $nbChoices choix de réponse.
Les questions doivent être variées, intéressantes et éducatives.
Réponds UNIQUEMENT avec un JSON valide, sans markdown, sans texte avant ou après.

Format JSON exact à respecter :
[
  {
    "question": "Ta question ici ?",
    "choices": ["Choix A", "Choix B", "Choix C", "Choix D"],
    "correct": 0
  },
  {
    "question": "Ta question ici ?",
    "choices": ["Choix A", "Choix B", "Choix C", "Choix D"],
    "correct": 2
  },
  {
    "question": "Ta question ici ?",
    "choices": ["Choix A", "Choix B", "Choix C", "Choix D"],
    "correct": 1
  }
]

"correct" est l'index (0-based) de la bonne réponse dans le tableau "choices".
Si $nbChoices vaut 2, le tableau "choices" ne contient que 2 éléments.
Si $nbChoices vaut 3, le tableau "choices" ne contient que 3 éléments.
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
        final cleaned = text
            .replaceAll('```json', '')
            .replaceAll('```', '')
            .trim();
        final List<dynamic> parsed = jsonDecode(cleaned);
        return parsed.cast<Map<String, dynamic>>();
      }
      return [];
    } catch (e) {
      return [];
    }
  }
}
