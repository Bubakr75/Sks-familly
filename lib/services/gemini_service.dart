// lib/services/gemini_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;

class GeminiService {
  static const String _apiKey = String.fromEnvironment('GEMINI_API_KEY');
  static const String _baseUrl =
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent';

  // ── Labels pour les clés du questionnaire ──
  static const Map<String, String> _keyLabels = {
    'comportement_general': 'Comportement général',
    'travail_scolaire': 'Travail scolaire',
    'rangement': 'Rangement / ménage',
    'respect': 'Respect envers les autres',
    'autonomie': 'Autonomie',
    'humeur': 'Humeur de la journée',
    'efforts': 'Efforts fournis',
    'cooperation': 'Coopération familiale',
  };

  static const Map<String, String> _valueLabels = {
    'excellent': 'Excellent',
    'bien': 'Bien',
    'moyen': 'Moyen',
    'insuffisant': 'Insuffisant',
    'tres_bien': 'Très bien',
    'passable': 'Passable',
    'mauvais': 'Mauvais',
  };

  // ── Score client calculé à partir des réponses ──
  static double _computeClientScore(Map<String, dynamic> answers) {
    const scoreMap = {
      'excellent': 20.0,
      'tres_bien': 17.0,
      'bien': 14.0,
      'moyen': 11.0,
      'passable': 8.0,
      'insuffisant': 5.0,
      'mauvais': 2.0,
    };
    if (answers.isEmpty) return -1;
    double total = 0;
    int count = 0;
    for (final v in answers.values) {
      final key = v.toString().toLowerCase().replaceAll(' ', '_');
      if (scoreMap.containsKey(key)) {
        total += scoreMap[key]!;
        count++;
      }
    }
    return count > 0 ? (total / count) : -1;
  }

  // ── Génère une appréciation IA enrichie ──
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
      final keyLabel = _keyLabels[e.key] ?? e.key;
      final valLabel = _valueLabels[e.value.toString().toLowerCase().replaceAll(' ', '_')] ?? e.value.toString();
      return '- $keyLabel : $valLabel';
    }).join('\n');

    final clientScore = _computeClientScore(answers);
    final scoreHint = clientScore >= 0
        ? 'Score calculé côté app : ${clientScore.toStringAsFixed(1)}/20. '
          'Ta note finale doit rester proche de ce score (±2 points max).'
        : '';

    String historyText = '';
    if (history != null && history.isNotEmpty) {
      final recent = history.take(5).map((h) {
        final date = h['date'] ?? '';
        final note = h['aiNote'] ?? h['note'] ?? '?';
        return '  • $date → $note/20';
      }).join('\n');
      historyText = '\nHistorique récent (5 derniers jours) :\n$recent';
    }

    String contextExtra = '';
    if (bonusCount != null) contextExtra += '\nBonus aujourd\'hui : $bonusCount';
    if (penaltyCount != null) contextExtra += '\nPénalités aujourd\'hui : $penaltyCount';
    if (activePunishments != null) contextExtra += '\nPunitions actives : $activePunishments';
    if (usableImmunities != null) contextExtra += '\nImmunités disponibles : $usableImmunities';
    if (streakDays != null) contextExtra += '\nStreak de jours consécutifs : $streakDays';
    if (totalPoints != null) contextExtra += '\nPoints totaux : $totalPoints';
    if (recentReasons != null && recentReasons.isNotEmpty) {
      contextExtra += '\nRaisons récentes : ${recentReasons.take(5).join(', ')}';
    }

    final prompt = '''
Tu es un assistant bienveillant qui aide des parents à évaluer le comportement de leurs enfants.

Contexte de la journée : $context$contextExtra
Prénom de l'enfant : $childName
$historyText

Réponses du parent au questionnaire :
$answersText

$scoreHint

En fonction de ces réponses :
1. Donne une note sur 20 (respecte le score calculé ±2 points)
2. Écris une appréciation courte et bienveillante de 2-3 phrases maximum
3. Donne un conseil rapide et concret au parent

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
            'temperature': 0.5,
            'maxOutputTokens': 400,
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
        return '{"note": -1, "appreciation": "Erreur API (${response.statusCode})", "conseil": ""}';
      }
    } catch (e) {
      return '{"note": -1, "appreciation": "Erreur réseau", "conseil": ""}';
    }
  }

  // ── Génère des questions de quiz ──
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
      difficulty = 'intermédiaire, adapté à un enfant de $age ans, ni trop facile ni trop difficile';
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
