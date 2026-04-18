// lib/services/gemini_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;

class GeminiService {
  static const String _apiKey = String.fromEnvironment('GEMINI_API_KEY');
  static const String _baseUrl =
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent';

  // ── Traduction clés → phrases lisibles ────────────────────────────────
  static const Map<String, String> _keyLabels = {
    'devoirs_existence':       'Devoirs ce soir',
    'devoirs_faits':           'Devoirs réalisés',
    'devoirs_repetition':      'Nombre de rappels pour commencer les devoirs',
    'remarques':               'Nombre de fois repris dans la journée',
    'obeissance':              'Obéissance au premier appel',
    'repetition_consignes':    'Répétition des mêmes consignes',
    'comportement_ecole':      'Comportement à l\'école',
    'taches':                  'Tâches ménagères',
    'initiative':              'Initiative positive spontanée',
    'fraternite':              'Relations avec frères / sœurs',
    'table':                   'Comportement à table',
    'politesse':               'Politesse et respect des adultes',
    'reaction_correction':     'Réaction quand on le corrige',
    'mensonge':                'Honnêteté / mensonge',
    'humeur':                  'Humeur générale de la journée',
    'coucher':                 'Coucher le soir',
    'ecran':                   'Respect du temps d\'écran',
    'hygiene':                 'Hygiène (douche, dents, mains)',
    'moment_positif':          'Moment particulièrement positif',
    'autonomie':               'Autonomie dans la journée',
    'aide_maison':             'Aide à la maison',
    'attitude':                'Attitude générale',
    'journee':                 'Déroulement de la journée',
    'medicaments':             'Prise des médicaments',
    'attitude_parents':        'Attitude envers les parents',
    'exageration':             'Exagération des symptômes',
    'comportement':            'Comportement général',
  };

  static const Map<String, String> _valueLabels = {
    // Binaires
    'oui':                     'Oui',
    'non':                     'Non',
    'na':                      'Sans objet',
    // Devoirs
    'oui_tout':                'Oui, entièrement fait',
    'partiel':                 'Partiellement fait',
    // Rappels / répétitions
    'seul':                    'De lui-même, sans rappel',
    'un_rappel':               'Un seul rappel suffi',
    'plusieurs_rappels':       'Il a fallu répéter 2 à 3 fois',
    'crise':                   'Refus ou crise',
    'peu':                     'Une ou deux fois',
    'souvent':                 'Souvent',
    'tout_le_temps':           'Constamment, tout le temps',
    // Obéissance
    'toujours':                'Obéit toujours au premier appel',
    'parfois':                 'Obéit parfois',
    'rarement':                'Obéit rarement ou jamais',
    // Comportement / attitude
    'excellent':               'Excellent',
    'exemplaire':              'Exemplement',
    'bien':                    'Bien',
    'moyen':                   'Moyen',
    'difficile':               'Difficile',
    'excellente':              'Excellente',
    'bonne':                   'Bonne',
    'moyenne':                 'Moyenne',
    // Tâches
    'faites':                  'Faites sans rappel',
    'rappel':                  'Faites après un rappel',
    'refus':                   'Refus de les faire',
    'non_demande':             'Non demandé',
    'insistance':              'Fait seulement après insistance',
    // Initiative
    'oui_plusieurs':           'Oui, plusieurs fois',
    'oui_une':                 'Oui, une fois',
    // Fraternité
    'tres_bien':               'Très bien, aide spontanée envers les frères/sœurs',
    'conflits':                'Quelques conflits mineurs',
    'conflits_graves':         'Conflits importants',
    'violence':                'Violence verbale ou physique',
    // Table
    'correct':                 'Correct',
    'agite':                   'Agité',
    // Politesse
    'tres_poli':               'Très poli, dit merci et s\'il te plaît',
    'oublis':                  'Quelques oublis de politesse',
    'irrespectueux':           'Irrespectueux',
    'insolent':                'Insolent ou grossier',
    // Réaction correction
    'accepte':                 'Accepte calmement et reconnaît son erreur',
    'ronchonne':               'Écoute mais ronchonne',
    'braque':                  'Se braque ou se tait',
    // Mensonge
    'omission':                'Petite omission, ne dit pas tout',
    'mensonge':                'Mensonge évident',
    // Humeur
    'joyeux':                  'Joyeux et positif',
    'stable':                  'Calme et stable',
    'fatigue':                 'Fatigué ou capricieux',
    'irritable':               'Irritable, sujets à des colères',
    // Coucher
    // (oui, rappel, plusieurs_rappels, difficile déjà définis)
    // Écran
    'respecte':                'Temps d\'écran respecté, pose seul les appareils',
    'leger':                   'Léger dépassement',
    'non_respecte':            'Dépasse régulièrement, doit être rappelé',
    // Hygiène
    // (seul, rappel, plusieurs_rappels, refus déjà définis)
    // Moment positif
    'oui_notable':             'Oui, geste particulièrement notable',
    'oui_petit':               'Oui, un petit moment sympa',
    // Autonomie
    'tres_autonome':           'Très autonome, se gère seul',
    'aide':                    'A besoin d\'aide régulièrement',
    'dependant':               'Très dépendant, sollicite constamment',
    // Aide maison
    'beaucoup':                'A beaucoup aidé de lui-même',
    'un_peu':                  'A un peu aidé',
    // Malade
    'tres_bien_malgre':        'Très bien malgré la maladie',
    'difficulte':              'Avec difficulté',
    'respectueux':             'Très respectueux malgré la maladie',
    'un_peu_ex':               'Un peu peut-être',
    'oui_ex':                  'Oui, exagération claire',
    // Exagération
    'un_peu':                  'Un peu peut-être',
  };

  // ── Score client-side 0–100 ───────────────────────────────────────────
  static int _computeClientScore(Map<String, dynamic> answers) {
    int score = 70;

    // Devoirs
    if (answers['devoirs_existence'] == 'oui') {
      switch (answers['devoirs_faits']) {
        case 'oui_tout': score += 8; break;
        case 'partiel':  score += 0; break;
        case 'non':      score -= 12; break;
      }
    }
    // Répétition pour les devoirs
    switch (answers['devoirs_repetition']) {
      case 'seul':             score += 6; break;
      case 'un_rappel':        score += 0; break;
      case 'plusieurs_rappels':score -= 6; break;
      case 'crise':            score -= 14; break;
    }
    // Nombre de fois repris
    switch (answers['remarques']) {
      case 'aucune':   score += 10; break;
      case 'une':      score += 0;  break;
      case 'deux':     score -= 8;  break;
      case 'plusieurs':score -= 16; break;
    }
    // Obéissance au premier appel
    switch (answers['obeissance']) {
      case 'toujours': score += 10; break;
      case 'souvent':  score += 3;  break;
      case 'parfois':  score -= 5;  break;
      case 'rarement': score -= 14; break;
    }
    // Répétition des consignes
    switch (answers['repetition_consignes']) {
      case 'non':           score += 8;  break;
      case 'peu':           score += 0;  break;
      case 'souvent':       score -= 8;  break;
      case 'tout_le_temps': score -= 16; break;
    }
    // Comportement école / général
    switch (answers['comportement_ecole'] ?? answers['comportement']) {
      case 'excellent':
      case 'exemplaire': score += 10; break;
      case 'bien':       score += 4;  break;
      case 'moyen':      score -= 5;  break;
      case 'difficile':  score -= 12; break;
    }
    // Tâches ménagères
    switch (answers['taches'] ?? answers['aide_maison']) {
      case 'faites':
      case 'beaucoup':          score += 8;  break;
      case 'rappel':
      case 'un_peu':            score -= 2;  break;
      case 'plusieurs_rappels':
      case 'insistance':        score -= 6;  break;
      case 'refus':
      case 'non':               score -= 12; break;
    }
    // Initiative positive
    switch (answers['initiative']) {
      case 'oui_plusieurs': score += 8; break;
      case 'oui_une':       score += 4; break;
    }
    // Fraternité
    switch (answers['fraternite']) {
      case 'tres_bien':        score += 6;  break;
      case 'bien':             score += 2;  break;
      case 'conflits':         score -= 5;  break;
      case 'conflits_graves':  score -= 12; break;
      case 'violence':         score -= 20; break;
    }
    // Politesse
    switch (answers['politesse']) {
      case 'tres_poli':    score += 8;  break;
      case 'correct':      score += 0;  break;
      case 'oublis':       score -= 4;  break;
      case 'irrespectueux':score -= 10; break;
      case 'insolent':     score -= 18; break;
    }
    // Réaction à la correction
    switch (answers['reaction_correction']) {
      case 'accepte':   score += 6;  break;
      case 'ronchonne': score -= 2;  break;
      case 'braque':    score -= 6;  break;
      case 'crise':     score -= 14; break;
    }
    // Mensonge
    switch (answers['mensonge']) {
      case 'non':      score += 4;  break;
      case 'omission': score -= 4;  break;
      case 'mensonge': score -= 12; break;
    }
    // Humeur
    switch (answers['humeur']) {
      case 'joyeux':   score += 6;  break;
      case 'stable':   score += 2;  break;
      case 'fatigue':  score -= 4;  break;
      case 'irritable':score -= 10; break;
    }
    // Table
    switch (answers['table']) {
      case 'excellent': score += 4; break;
      case 'correct':   score += 0; break;
      case 'agite':     score -= 4; break;
      case 'difficile': score -= 8; break;
    }
    // Coucher
    switch (answers['coucher']) {
      case 'oui':              score += 4;  break;
      case 'rappel':           score -= 2;  break;
      case 'plusieurs_rappels':score -= 6;  break;
      case 'difficile':        score -= 10; break;
    }
    // Écran
    switch (answers['ecran']) {
      case 'respecte':     score += 6;  break;
      case 'leger':        score -= 2;  break;
      case 'non_respecte': score -= 8;  break;
      case 'refus':        score -= 14; break;
    }
    // Hygiène
    switch (answers['hygiene']) {
      case 'seul':             score += 4;  break;
      case 'rappel':           score -= 2;  break;
      case 'plusieurs_rappels':score -= 6;  break;
      case 'refus':            score -= 10; break;
    }
    // Attitude (vacances / malade)
    switch (answers['attitude'] ?? answers['journee']) {
      case 'excellente':
      case 'tres_bien':  score += 8; break;
      case 'bonne':
      case 'correct':    score += 2; break;
      case 'moyenne':    score -= 6; break;
      case 'difficile':  score -= 12; break;
    }
    // Exagération maladie
    switch (answers['exageration']) {
      case 'non':     score += 4;  break;
      case 'un_peu':  score -= 4;  break;
      case 'oui':     score -= 10; break;
    }
    // Moment positif
    switch (answers['moment_positif']) {
      case 'oui_notable': score += 6; break;
      case 'oui_petit':   score += 2; break;
    }

    return score.clamp(0, 100);
  }

  // ── Génération de l'appréciation IA ─────────────────────────────────
  static Future<String> generateAppreciation({
    required String childName,
    required String context,
    required Map<String, dynamic> answers,
    int bonusCount = 0,
    int penaltyCount = 0,
    int activePunishments = 0,
    int availableImmunities = 0,
    int streakDays = 0,
    int totalPoints = 0,
    List<String> recentReasons = const [],
  }) async {
    // Traduction des réponses
    final answersText = answers.entries.map((e) {
      final key = _keyLabels[e.key] ?? e.key;
      final val = _valueLabels[e.value?.toString()] ?? e.value?.toString() ?? '';
      return '• $key : $val';
    }).join('\n');

    final clientScore = _computeClientScore(answers);
    final clientNote = (clientScore / 100 * 20).round();

    final historyText = '''
Données comportementales récentes :
• Bonus reçus aujourd'hui : $bonusCount
• Pénalités reçues aujourd'hui : $penaltyCount
• Punitions actives en cours : $activePunishments
• Immunités disponibles : $availableImmunities
• Série de jours positifs consécutifs : $streakDays jour(s)
• Total de points accumulés : $totalPoints
${recentReasons.isNotEmpty ? '• Dernières raisons notées : ${recentReasons.take(5).join(', ')}' : ''}''';

    final prompt = '''
Tu es un assistant bienveillant qui aide des parents à évaluer le comportement de leurs enfants.

Contexte de la journée : $context
Prénom de l'enfant : $childName

Réponses détaillées du parent :
$answersText

$historyText

INSTRUCTIONS IMPORTANTES :
- Le score calculé depuis les réponses est $clientScore/100, soit environ $clientNote/20.
- Ta note DOIT être entre ${(clientNote - 2).clamp(0, 20)} et ${(clientNote + 2).clamp(0, 20)}.
- Ne donne JAMAIS 10/20 par défaut. Analyse chaque réponse.
- L'appréciation doit mentionner des éléments spécifiques des réponses (ex: "Les devoirs faits sans rappel", "Quelques conflits avec les frères").
- Le conseil doit être concret, actionnable, personnalisé à cette journée.

Réponds UNIQUEMENT en JSON valide sans markdown :
{
  "note": $clientNote,
  "appreciation": "Appréciation personnalisée de 2-3 phrases mentionnant des points précis...",
  "conseil": "Conseil concret et actionnable..."
}
''';

    try {
      final response = await http.post(
        Uri.parse('$_baseUrl?key=$_apiKey'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'contents': [
            {
              'parts': [{'text': prompt}]
            }
          ],
          'generationConfig': {
            'temperature': 0.4,
            'maxOutputTokens': 450,
          },
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final text =
            data['candidates'][0]['content']['parts'][0]['text'] as String;
        final cleanText =
            text.replaceAll('```json', '').replaceAll('```', '').trim();

        try {
          final parsed = jsonDecode(cleanText) as Map<String, dynamic>;
          final note = (parsed['note'] as num).toInt();
          // Filet de sécurité : si Gemini retourne 10 par défaut
          if (note == 10 && clientNote != 10) {
            parsed['note'] = clientNote;
            return jsonEncode(parsed);
          }
          // Filet de sécurité : note hors fourchette autorisée
          final min = (clientNote - 2).clamp(0, 20);
          final max = (clientNote + 2).clamp(0, 20);
          if (note < min || note > max) {
            parsed['note'] = clientNote;
            return jsonEncode(parsed);
          }
          return cleanText;
        } catch (_) {
          return '{"note": $clientNote, "appreciation": "Journée évaluée avec un score de $clientNote/20.", "conseil": "Continuez à encourager les efforts de $childName."}';
        }
      } else {
        return '{"note": $clientNote, "appreciation": "Erreur API.", "conseil": ""}';
      }
    } catch (e) {
      return '{"note": $clientNote, "appreciation": "Erreur réseau.", "conseil": ""}';
    }
  }

  // ── Quiz (inchangé) ──────────────────────────────────────────────────
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
Format JSON exact :
[
  {"question": "...", "choices": ["A", "B", "C", "D"], "correct": 0},
  {"question": "...", "choices": ["A", "B", "C", "D"], "correct": 2},
  {"question": "...", "choices": ["A", "B", "C", "D"], "correct": 1}
]
"correct" est l'index 0-based de la bonne réponse.
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
              'parts': [{'text': prompt}]
            }
          ],
          'generationConfig': {'temperature': 0.7, 'maxOutputTokens': 1024},
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
