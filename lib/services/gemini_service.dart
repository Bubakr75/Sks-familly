// lib/services/gemini_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;

class GeminiService {
  static const String _apiKey = String.fromEnvironment('GEMINI_API_KEY');
  static const String _baseUrl =
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent';

  // ─── Labels lisibles pour les clés/valeurs du questionnaire ───
  static const Map<String, String> _keyLabels = {
    'devoirs_existence': 'Avait-il des devoirs ?',
    'devoirs_faits': 'Devoirs faits ?',
    'remarques': 'Nombre de remarques',
    'comportement_ecole': 'Comportement à l\'école',
    'taches': 'Tâches ménagères',
    'fraternite': 'Relations fraternelles',
    'table': 'Comportement à table',
    'politesse': 'Politesse et respect',
    'coucher': 'Coucher',
    'ecran': 'Respect du temps d\'écran',
    'autonomie': 'Autonomie',
    'aide_maison': 'Aide à la maison',
    'attitude': 'Attitude générale',
    'journee': 'Déroulement de la journée',
    'medicaments': 'Prise de médicaments',
    'attitude_parents': 'Attitude envers les parents',
    'comportement': 'Comportement général',
  };

  static const Map<String, String> _valueLabels = {
    'oui': 'Oui',
    'non': 'Non',
    'oui_tout': 'Oui, tout fait',
    'partiel': 'Partiellement fait',
    'aucune': 'Aucune remarque',
    'une': 'Une remarque',
    'deux': 'Deux remarques',
    'plusieurs': 'Trois remarques ou plus',
    'excellent': 'Excellent',
    'bien': 'Bien',
    'moyen': 'Moyen',
    'difficile': 'Difficile',
    'faites': 'Faites sans problème',
    'rappel': 'Faites après rappel',
    'refus': 'Refus de faire',
    'non_demande': 'Non demandé',
    'tres_bien': 'Très bien',
    'conflits': 'Quelques conflits mineurs',
    'conflits_graves': 'Conflits importants',
    'na': 'Sans objet (enfant unique)',
    'correct': 'Correct',
    'agite': 'Agité',
    'tres_poli': 'Très poli',
    'oublis': 'Quelques oublis de politesse',
    'irrespectueux': 'Irrespectueux',
    'rappel_petit': 'Petit rappel nécessaire',
    'respecte': 'Respecté',
    'leger': 'Léger dépassement',
    'non_respecte': 'Non respecté',
    'tres_autonome': 'Très autonome',
    'aide': 'A eu besoin d\'aide',
    'beaucoup': 'Beaucoup aidé',
    'un_peu': 'Un peu aidé',
    'excellente': 'Excellente',
    'bonne': 'Bonne',
    'moyenne': 'Moyenne',
    'tres_bien_malgre_tout': 'Très bien malgré la maladie',
    'difficulte': 'Avec difficulté',
    'respectueux': 'Respectueux',
    'exemplaire': 'Exemplaire',
  };

  static String _labelFor(String key, String val) {
    final k = _keyLabels[key] ?? key;
    final v = _valueLabels[val] ?? val;
    return '• $k : $v';
  }

  // ─── Génération de l'appréciation IA ─────────────────────────
  static Future<String> generateAppreciation({
    required String childName,
    required String context,
    required Map<String, String> answers,
    // Historique enrichi
    int totalBonusToday = 0,
    int totalPenaltyToday = 0,
    int activePunishments = 0,
    int availableImmunities = 0,
    int streakDays = 0,
    int pointsTotal = 0,
    List<String> recentReasons = const [],
  }) async {
    // Construction des réponses en langage naturel
    final answersText = answers.entries
        .map((e) => _labelFor(e.key, e.value))
        .join('\n');

    // Résumé de l'historique récent
    final historyText = [
      if (totalBonusToday > 0)
        '- $totalBonusToday bonus accordé(s) aujourd\'hui',
      if (totalPenaltyToday > 0)
        '- $totalPenaltyToday pénalité(s) reçue(s) aujourd\'hui',
      if (activePunishments > 0)
        '- $activePunishments punition(s) de lignes en cours',
      if (availableImmunities > 0)
        '- $availableImmunities ligne(s) d\'immunité disponible(s)',
      if (streakDays > 0)
        '- Série positive de $streakDays jour(s) sans pénalité',
      if (pointsTotal > 0) '- Total de points accumulés : $pointsTotal pts',
      if (recentReasons.isNotEmpty)
        '- Dernières raisons notées : ${recentReasons.take(3).join(', ')}',
    ].join('\n');

    // Score intermédiaire calculé côté client pour guider l'IA
    final clientScore = _computeClientScore(answers);

    final prompt = '''
Tu es un assistant bienveillant qui aide des parents à évaluer le comportement de leurs enfants.

Contexte de la journée : $context
Prénom de l'enfant : $childName

Réponses détaillées du parent au questionnaire de comportement :
$answersText

Données comportementales récentes issues de l'historique familial :
${historyText.isEmpty ? '- Aucune donnée historique disponible' : historyText}

Indice de comportement calculé automatiquement (sur 100) : $clientScore/100
Cet indice est basé sur les réponses au questionnaire. Utilise-le comme base pour calibrer ta note.

Instructions pour la note :
- La note doit être comprise entre 0 et 20
- Un indice de 90-100 correspond à une note de 17-20
- Un indice de 75-89 correspond à une note de 14-16
- Un indice de 60-74 correspond à une note de 11-13
- Un indice de 40-59 correspond à une note de 8-10
- Un indice de 20-39 correspond à une note de 5-7
- Un indice de 0-19 correspond à une note de 0-4
- Tiens compte de l'historique (punitions en cours, pénalités du jour) pour ajuster légèrement
- Ne donne JAMAIS 10/20 par défaut : calcule vraiment en fonction des éléments fournis
- Sois juste, bienveillant mais honnête

Réponds UNIQUEMENT au format JSON suivant, sans markdown, sans texte avant ou après :
{
  "note": 15,
  "appreciation": "Appréciation courte et bienveillante de 2-3 phrases maximum...",
  "conseil": "Un conseil court et constructif pour le parent..."
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
            'temperature': 0.4,
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
        return '{"note": -1, "appreciation": "Erreur API", "conseil": ""}';
      }
    } catch (e) {
      return '{"note": -1, "appreciation": "Erreur réseau", "conseil": ""}';
    }
  }

  // ─── Calcul du score côté client ──────────────────────────────
  // Retourne un score entre 0 et 100 basé sur les réponses
  static int _computeClientScore(Map<String, String> answers) {
    int total = 0;
    int count = 0;

    void add(String key, Map<String, int> scoring) {
      final val = answers[key];
      if (val != null && scoring.containsKey(val)) {
        total += scoring[val]!;
        count++;
      }
    }

    // Devoirs
    add('devoirs_existence', {'oui': 50, 'non': 100});
    add('devoirs_faits', {'oui_tout': 100, 'partiel': 50, 'non': 0});

    // Remarques (inversé : moins = mieux)
    add('remarques', {
      'aucune': 100,
      'une': 70,
      'deux': 40,
      'plusieurs': 10,
    });

    // Comportement école
    add('comportement_ecole', {
      'excellent': 100,
      'bien': 75,
      'moyen': 45,
      'difficile': 10,
    });

    // Tâches
    add('taches', {
      'faites': 100,
      'rappel': 60,
      'refus': 0,
      'non_demande': 80,
    });

    // Fraternité
    add('fraternite', {
      'tres_bien': 100,
      'bien': 75,
      'conflits': 40,
      'conflits_graves': 5,
      'na': 80,
    });

    // Table
    add('table', {
      'excellent': 100,
      'correct': 75,
      'agite': 40,
      'difficile': 10,
    });

    // Politesse
    add('politesse', {
      'tres_poli': 100,
      'correct': 75,
      'oublis': 40,
      'irrespectueux': 5,
    });

    // Coucher
    add('coucher', {
      'oui': 100,
      'rappel': 60,
      'difficile': 20,
    });

    // Écran
    add('ecran', {
      'respecte': 100,
      'leger': 60,
      'non_respecte': 10,
    });

    // Autonomie
    add('autonomie', {
      'tres_autonome': 100,
      'correct': 70,
      'aide': 40,
    });

    // Aide maison (vacances)
    add('aide_maison', {
      'beaucoup': 100,
      'un_peu': 65,
      'non': 10,
    });

    // Attitude générale
    add('attitude', {
      'excellente': 100,
      'bonne': 75,
      'moyenne': 45,
      'difficile': 10,
    });

    // Journée malade
    add('journee', {
      'tres_bien': 100,
      'correct': 65,
      'difficile': 30,
    });

    // Médicaments
    add('medicaments', {
      'oui': 100,
      'difficulte': 60,
      'refus': 10,
      'na': 80,
    });

    // Attitude parents
    add('attitude_parents', {
      'respectueux': 100,
      'correct': 65,
      'difficile': 10,
    });

    // Comportement général (jour spécial)
    add('comportement', {
      'exemplaire': 100,
      'bien': 75,
      'moyen': 45,
      'difficile': 10,
    });

    if (count == 0) return 50;
    return (total / count).round();
  }

  // ─── Génération quiz (inchangé) ───────────────────────────────
  static Future<List<Map<String, dynamic>>> generateQuizQuestions({
    required String theme,
    required int age,
  }) async {
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
        final List parsed = jsonDecode(cleaned);
        return parsed.cast<Map<String, dynamic>>();
      }
      return [];
    } catch (e) {
      return [];
    }
  }
}
