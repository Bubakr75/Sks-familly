import 'dart:convert';
import 'package:http/http.dart' as http;

class GeminiService {
  static const String _apiKey = String.fromEnvironment('GEMINI_API_KEY');
  static const String _baseUrl =
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent';

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
        return '  â€¢ $date : $note/20';
      }).join('\n');
      historyText = '\nHistorique des 5 derniers jours :\n$recent';
    }

    String contextExtra = '';
    if (bonusCount != null && bonusCount > 0)
      contextExtra += '\n- Bonus obtenus aujourd\'hui : $bonusCount';
    if (penaltyCount != null && penaltyCount > 0)
      contextExtra += '\n- PÃ©nalitÃ©s reÃ§ues aujourd\'hui : $penaltyCount';
    if (activePunishments != null && activePunishments > 0)
      contextExtra += '\n- Punitions actives en cours : $activePunishments';
    if (usableImmunities != null && usableImmunities > 0)
      contextExtra += '\n- ImmunitÃ©s disponibles (bonnes actions accumulÃ©es) : $usableImmunities';
    if (streakDays != null && streakDays > 1)
      contextExtra += '\n- SÃ©rie de bonnes journÃ©es consÃ©cutives : $streakDays jours ðŸ”¥';
    if (totalPoints != null)
      contextExtra += '\n- Points totaux accumulÃ©s : $totalPoints';
    if (recentReasons != null && recentReasons.isNotEmpty)
      contextExtra += '\n- Raisons rÃ©centes notÃ©es par les parents : ${recentReasons.take(5).join(', ')}';

    final prompt = '''
Tu es un assistant bienveillant qui aide une famille Ã  organiser un conseil de classe familial chaque soir.
Tu analyses le comportement, l'attitude et les efforts de l'enfant sur la journÃ©e.

Enfant Ã©valuÃ© : $childName
Contexte de la journÃ©e : $context
$historyText

DonnÃ©es de la journÃ©e :$contextExtra

RÃ©ponses du questionnaire familial :
$answersText

En tenant compte de TOUS ces Ã©lÃ©ments (questionnaire, bonus, pÃ©nalitÃ©s, punitions actives, immunitÃ©s, streak, points et historique), tu dois :

1. Donner une note globale sur 20 qui reflÃ¨te fidÃ¨lement l'ensemble des donnÃ©es
2. RÃ©diger une apprÃ©ciation bienveillante mais honnÃªte de 3-4 phrases, comme un bulletin scolaire familial
3. Donner un conseil concret et positif pour le lendemain
4. Identifier le point fort de la journÃ©e
5. Identifier le point Ã  amÃ©liorer

RÃ©ponds UNIQUEMENT en JSON valide, sans markdown, sans texte avant ou aprÃ¨s :
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
      return '{"note": -1, "appreciation": "Erreur rÃ©seau", "conseil": "", "point_fort": "", "point_ameliorer": ""}';
    }
  }

  static Future<List<Map<String, dynamic>>> generateQuizQuestions({
    required String theme,
    required int age,
  }) async {
    String difficulty;
    int nbChoices;

    if (age <= 6) {
      difficulty = 'trÃ¨s simple, adaptÃ© Ã  un enfant de $age ans, avec des mots trÃ¨s courts et faciles';
      nbChoices = 2;
    } else if (age <= 9) {
      difficulty = 'simple et ludique, adaptÃ© Ã  un enfant de $age ans';
      nbChoices = 3;
    } else if (age <= 12) {
      difficulty = 'intermÃ©diaire, adaptÃ© Ã  un enfant de $age ans';
      nbChoices = 4;
    } else {
      difficulty = 'difficile avec des piÃ¨ges subtils, adaptÃ© Ã  un adolescent de $age ans';
      nbChoices = 4;
    }

    final prompt = '''
Tu es un gÃ©nÃ©rateur de quiz Ã©ducatif pour enfants et adolescents.
GÃ©nÃ¨re exactement 3 questions QCM sur le thÃ¨me : $theme.
Niveau de difficultÃ© : $difficulty.
Chaque question doit avoir exactement $nbChoices choix de rÃ©ponse.
Les questions doivent Ãªtre variÃ©es, intÃ©ressantes et Ã©ducatives.

RÃ©ponds UNIQUEMENT avec un JSON valide, sans markdown, sans texte avant ou aprÃ¨s.
Format JSON exact :
[
  {"question": "...", "choices": ["A", "B", "C", "D"], "correct": 0},
  {"question": "...", "choices": ["A", "B", "C", "D"], "correct": 2},
  {"question": "...", "choices": ["A", "B", "C", "D"], "correct": 1}
]
"correct" est l'index (0-based) de la bonne rÃ©ponse.
Si $nbChoices vaut 2, le tableau "choices" ne contient que 2 Ã©lÃ©ments.
Si $nbChoices vaut 3, le tableau "choices" ne contient que 3 Ã©lÃ©ments.
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


