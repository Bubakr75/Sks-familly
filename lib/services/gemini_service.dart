// lib/services/gemini_service.dart

import 'dart:convert';
import 'package:http/http.dart' as http;

class GeminiService {
  static const String _apiKey = 'AIzaSyBzyWQB3qLYtVakVzInkd5Z86882kayssU';
  static const String _baseUrl =
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent';

  static Future<String> generateAppreciation({
    required String childName,
    required String context,
    required Map<String, String> answers,
  }) async {
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
1. Donne une note sur 20
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
          'contents': [{'parts': [{'text': prompt}]}],
          'generationConfig': {'temperature': 0.7, 'maxOutputTokens': 300},
        }),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final text = data['candidates'][0]['content']['parts'][0]['text'] as String;
        return text.replaceAll('```json', '').replaceAll('```', '').trim();
      }
      return '{"note": -1, "appreciation": "Erreur API", "conseil": ""}';
    } catch (e) {
      return '{"note": -1, "appreciation": "Erreur réseau", "conseil": ""}';
    }
  }

  static Future<List<Map<String, dynamic>>> generateQuizQuestions({
    required String theme,
    required int age,
  }) async {
    String difficulty;
    int nbChoices;

    if (age <= 6) {
      difficulty = 'très simple, adapté à un enfant de $age ans';
      nbChoices = 2;
    } else if (age <= 9) {
      difficulty = 'simple et ludique, adapté à un enfant de $age ans';
      nbChoices = 3;
    } else if (age <= 12) {
      difficulty = 'intermédiaire, adapté à un enfant de $age ans';
      nbChoices = 4;
    } else {
      difficulty = 'difficile, adapté à un adolescent de $age ans';
      nbChoices = 4;
    }

    final prompt = '''
Tu es un générateur de quiz éducatif pour enfants.
Génère exactement 3 questions QCM sur le thème : $theme.
Niveau : $difficulty.
Chaque question a exactement $nbChoices choix.
Réponds UNIQUEMENT avec un JSON valide, sans markdown, sans texte avant ou après.
Format :
[
  {"question": "...", "choices": ["A", "B", "C", "D"], "correct": 0},
  {"question": "...", "choices": ["A", "B", "C", "D"], "correct": 1},
  {"question": "...", "choices": ["A", "B", "C", "D"], "correct": 2}
]
"correct" est l'index 0-based de la bonne réponse.
Si $nbChoices vaut 2, "choices" contient 2 éléments.
Si $nbChoices vaut 3, "choices" contient 3 éléments.
''';

    try {
      final response = await http.post(
        Uri.parse('$_baseUrl?key=$_apiKey'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'contents': [{'parts': [{'text': prompt}]}],
          'generationConfig': {'temperature': 0.7, 'maxOutputTokens': 1024},
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final text = data['candidates'][0]['content']['parts'][0]['text'] as String;

        // Nettoyage agressif
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

        try {
          final List<dynamic> parsed = jsonDecode(cleaned);
          return parsed.cast<Map<String, dynamic>>();
        } catch (e) {
          throw Exception('JSON invalide : $cleaned');
        }
      } else {
        throw Exception('Status ${response.statusCode} : ${response.body}');
      }
    } catch (e) {
      rethrow;
    }
  }
}
