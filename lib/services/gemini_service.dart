// lib/services/gemini_service.dart

import 'dart:convert';
import 'package:http/http.dart' as http;

class GeminiService {
  static const String _apiKey = 'AIzaSyBQ68fPyI7ECRUQMYrDyKSuT0N-uoBF5CQ'; // ← remplace par ta nouvelle clé
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
            'maxOutputTokens': 300,
          },
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final text = data['candidates'][0]['content']['parts'][0]['text'] as String;
        // Nettoie le JSON si besoin
        final cleanText = text
            .replaceAll('```json', '')
            .replaceAll('```', '')
            .trim();
        return cleanText;
      } else {
        return '{"note": -1, "appreciation": "Erreur API", "conseil": ""}';
      }
    } catch (e) {
      return '{"note": -1, "appreciation": "Erreur réseau", "conseil": ""}';
    }
  }
}
