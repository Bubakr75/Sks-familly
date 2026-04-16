import 'dart:convert';
import 'package:http/http.dart' as http;

class GeminiService {
  static const String _apiKey = 'AIzaSyBzyWQB3qLYtVakVzInkd5Z86882kayssU'; // ← ta vraie clé API Gemini
  static const String _baseUrl =
      'https://generativelanguage.googleapis.com/v1/models/gemini-2.0-flash:generateContent';

  // ─── Génération d'appréciation ───────────────────────────────────────────
  static Future<String> generateAppreciation({
    required String childName,
    required String context,       // ← NOM EXACT attendu par school_notes_screen.dart
    required Map<String, dynamic> answers,
  }) async {
    final prompt = '''
Tu es un assistant parental bienveillant. Génère une appréciation personnalisée en français pour $childName.

Contexte du jour : $context
Réponses au questionnaire : ${jsonEncode(answers)}

Réponds UNIQUEMENT avec un objet JSON valide (sans markdown) :
{
  "note": <nombre entier entre 0 et 20>,
  "appreciation": "<texte court et encourageant>",
  "conseil": "<conseil rapide pour les parents>"
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
            'maxOutputTokens': 400,
          },
        }),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        String text = data['candidates'][0]['content']['parts'][0]['text'];
        return text.replaceAll('```json', '').replaceAll('```', '').trim();
      } else {
        return jsonEncode({
          'note': -1,
          'appreciation': 'Erreur Gemini (${response.statusCode})',
          'conseil': ''
        });
      }
    } catch (e) {
      return jsonEncode({
        'note': -1,
        'appreciation': 'Erreur : $e',
        'conseil': ''
      });
    }
  }

  // ─── Génération de questions de quiz ─────────────────────────────────────
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

    final choicesTemplate =
        List.filled(nbChoices, '"<réponse>"').join(', ');

    final prompt = '''
Génère exactement 3 questions de quiz en français sur le thème "$theme".
Niveau : $difficultyDesc. Difficulté : $difficulty.
Chaque question a exactement $nbChoices choix de réponse.

Réponds UNIQUEMENT avec un tableau JSON valide (sans markdown) :
[
  {
    "question": "<question>",
    "choices": [$choicesTemplate],
    "correct": <index de la bonne réponse (0 à ${nbChoices - 1})>
  }
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
        text = text.replaceAll('```json', '').replaceAll('```', '').trim();
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
