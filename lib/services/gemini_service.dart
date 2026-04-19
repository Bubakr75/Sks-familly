import 'dart:convert';
import 'package:http/http.dart' as http;

class GeminiService {
  static const String _apiKey = String.fromEnvironment('GEMINI_API_KEY');
  static const String _baseUrl =
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent';

  static Future<String> generateAppreciation({
    required String childName,
    required String context,
    required Map<String, dynamic> answers,
    List<Map<String, dynamic>>? history,
    int? bonusCount,
    int? penaltyCount,
    int? activePunishments,
    int? usableImmunities,
    int? streakDays,
    int? totalPoints,
    List<String>? recentReasons,
  }) async {
    final answersText = answers.entries.map((e) {
      return '- ${e.key} : ${e.value}';
    }).join('\n');

    String historyText = '';
    if (history != null && history.isNotEmpty) {
      final recent = history.take(5).map((h) {
        final date = h['date'] ?? '';
        final note = h['aiNote'] ?? h['note'] ?? '?';
        return '  • $date : $note/20';
      }).join('\n');
      historyText = '\nHistorique des 5 derniers jours :\n$recent';
    }

    String contextExtra = '';
    if (bonusCount != null && bonusCount > 0)
      contextExtra += '\n- Bonus obtenus aujourd\'hui : $bonusCount';
    if (penaltyCount != null && penaltyCount > 0)
      contextExtra += '\n- Pénalités reçues aujourd\'hui : $penaltyCount';
    if (activePunishments != null && activePunishments > 0)
      contextExtra += '\n- Punitions actives en cours : $activePunishments';
    if (usableImmunities != null && usableImmunities > 0)
      contextExtra += '\n- Immunités disponibles (bonnes actions accumulées) : $usableImmunities';
    if (streakDays != null && streakDays > 1)
      contextExtra += '\n- Série de bonnes journées consécutives : $streakDays jours 🔥';
    if (totalPoints != null)
      contextExtra += '\n- Points totaux accumulés : $totalPoints';
    if (recentReasons != null && recentReasons.isNotEmpty)
      contextExtra += '\n- Raisons récentes notées par les parents : ${recentReasons.take(5).join(', ')}';

    final prompt = '''
Tu es un assistant bienveillant qui aide une famille à organiser un conseil de classe familial chaque soir.
Tu analyses le comportement, l'attitude et les efforts de l'enfant sur la journée.

Enfant évalué : $childName
Contexte de la journée : $context
$historyText

Données de la journée :$contextExtra

Réponses du questionnaire familial :
$answersText

En tenant compte de TOUS ces éléments (questionnaire, bonus, pénalités, punitions actives, immunités, streak, points et historique), tu dois :

1. Donner une note globale sur 20 qui reflète fidèlement l'ensemble des données
2. Rédiger une appréciation bienveillante mais honnête de 3-4 phrases, comme un bulletin scolaire familial
3. Donner un conseil concret et positif pour le lendemain
4. Identifier le point fort de la journée
5. Identifier le point à améliorer

Réponds UNIQUEMENT en JSON valide, sans markdown, sans texte avant ou après :
{
  "note": 15,
  "appreciation": "...",
  "conseil": "...",
  "point_fort": "...",
  "point_ameliorer": "..."
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
            'temperature': 0.5,
            'maxOutputTokens': 600,
          },
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final text =
            data['candidates'][0]['content']['parts'][0]['text'] as String;
        final cleanText =
            text.replaceAll('```json', '').replaceAll('```', '').trim();
        return cleanText;
      } else {
        return '{"note": -1, "appreciation": "Erreur API (${response.statusCode})", "conseil": "", "point_fort": "", "point_ameliorer": ""}';
      }
    } catch (e) {
      return '{"note": -1, "appreciation": "Erreur réseau", "conseil": "", "point_fort": "", "point_ameliorer": ""}';
    }
  }

  static Future<List<Map<String, dynamic>>> generateQuizQuestions({
    required String theme,
    required int age,
  }) async {
    String difficulty;
    int nbChoices;

    if (age <= 6) {
      difficulty = 'très simple, adapté à un enfant de $age ans, avec des mots très courts et faciles';
      nbChoices = 2;
    } else if (age <= 9) {
      difficulty = 'simple et ludique, adapté à un enfant de $age ans';
      nbChoices = 3;
    } else if (age <= 12) {
      difficulty = 'intermédiaire, adapté à un enfant de $age ans';
      nbChoices = 4;
    } else {
      difficulty = 'difficile avec des pièges subtils, adapté à un adolescent de $age ans';
      nbChoices = 4;
    }

    final prompt = '''
Tu es un générateur de quiz éducatif pour enfants et adolescents.
Génère exactement 3 questions QCM sur le thème : $theme.
Niveau de difficulté : $difficulty.
Chaque question doit avoir exactement $nbChoices choix de réponse.
Les questions doivent être variées, intéressantes et éducatives.

Réponds UNIQUEMENT avec un JSON valide, sans markdown, sans texte avant ou après.
Format JSON exact :
[
  {"question": "...", "choices": ["A", "B", "C", "D"], "correct": 0},
  {"question": "...", "choices": ["A", "B", "C", "D"], "correct": 2},
  {"question": "...", "choices": ["A", "B", "C", "D"], "correct": 1}
]
"correct" est l'index (0-based) de la bonne réponse.
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
        final cleaned =
            text.replaceAll('```json', '').replaceAll('```', '').trim();
        final List<dynamic> parsed = jsonDecode(cleaned);
        return parsed.cast<Map<String, dynamic>>();
      }
      return [];
    } catch (e) {
      return [];
    }
  }
}
