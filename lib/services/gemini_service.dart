// lib/services/gemini_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;

class GeminiService {
  static const String _apiKey = 'AIzaSy...'; // ← ta vraie clé ici

  static const String _baseUrl =
      'https://generativelanguage.googleapis.com/v1/models/gemini-2.0-flash:generateContent';

  // ─── GÉNÉRATION D'APPRÉCIATION ───────────────────────────────
  static Future<String> generateAppreciation({
    required String childName,
    required String dailyContext,
    required Map<String, dynamic> answers,
  }) async {
    final prompt = '''
Tu es un assistant parental bienveillant. Génère une appréciation personnalisée en français pour $childName.

Contexte du jour : $dailyContext
Réponses au questionnaire : ${jsonEncode(answers)}

Réponds UNIQUEMENT avec un objet JSON valide (sans markdown) :
{
  "score": <nombre entre 0 et 100>,
  "appreciation": "<texte court et encourageant>",
  "tip": "<conseil rapide pour les parents>"
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
            'maxOutputTokens': 300,
          },
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        String text = data['candidates'][0]['content']['parts'][0]['text'];
        // Nettoyage des balises markdown
        text = text.replaceAll('```json', '').replaceAll('```', '').trim();
        return text;
      } else {
        return jsonEncode({'score': -1, 'appreciation': 'Erreur Gemini', 'tip': ''});
      }
    } catch (e) {
      return jsonEncode({'score': -1, 'appreciation': 'Erreur : $e', 'tip': ''});
    }
  }

  // ─── GÉNÉRATION DE QUIZ ───────────────────────────────────────
  static Future<List<Map<String, dynamic>>> generateQuizQuestions({
    required String theme,
    required int age,
    required String difficulty,
  }) async {
    String difficultyDesc;
    int nbChoices;

    if (age <= 7) {
      difficultyDesc = 'très simple, pour un enfant de $age ans';
      nbChoices = 2;
    } else if (age <= 10) {
      difficultyDesc = 'simple, pour un enfant de $age ans';
      nbChoices = 3;
    } else if (age <= 13) {
      difficultyDesc = 'intermédiaire, pour un enfant de $age ans';
      nbChoices = 4;
    } else {
      difficultyDesc = 'difficile, pour un adolescent de $age ans';
      nbChoices = 4;
    }

    final prompt = '''
Génère exactement 3 questions de quiz en français sur le thème "$theme".
Niveau : $difficultyDesc. Difficulté : $difficulty.
Chaque question a exactement $nbChoices choix de réponse.

Réponds UNIQUEMENT avec un tableau JSON valide (sans markdown) :
[
  {
    "question": "<question>",
    "choices": ["<choix1>", "<choix2>"${nbChoices >= 3 ? ', "<choix3>"' : ''}${nbChoices >= 4 ? ', "<choix4>"' : ''}],
    "correct": <index de la bonne réponse (0 à ${nbChoices - 1})>
  },
  ...
]
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
        String text = data['candidates'][0]['content']['parts'][0]['text'];

        // Nettoyage des balises markdown
        text = text.replaceAll('```json', '').replaceAll('```', '').trim();

        // Extraction du tableau JSON
        final start = text.indexOf('[');
        final end = text.lastIndexOf(']');
        if (start == -1 || end == -1) return [];

        final jsonStr = text.substring(start, end + 1);
        final List<dynamic> parsed = jsonDecode(jsonStr);
        return parsed.map((q) => Map<String, dynamic>.from(q)).toList();
      } else {
        throw Exception('Erreur Gemini : ${response.body}');
      }
    } catch (e) {
      throw Exception('Erreur Gemini : $e');
    }
  }
}
