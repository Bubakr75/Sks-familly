import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class GeminiService {
  // ✅ Modèle corrigé : gemini-2.0-flash (gemini-2.5-flash n'existe pas/plus)
  // ✅ Clé API récupérée via --dart-define (plus en dur pour la sécurité)
  static const _baseUrl =
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent';
  static const _apiKey = String.fromEnvironment('GEMINI_API_KEY',
      defaultValue: '');

  /// True si la clé API Gemini est configurée (sinon les appels sont désactivés).
  static bool get isConfigured => _apiKey.isNotEmpty;

  /// Vérifie que la clé est configurée avant tout appel.
  static bool _checkKey() {
    if (_apiKey.isEmpty) {
      if (kDebugMode) {
        debugPrint('GeminiService: GEMINI_API_KEY non configurée ! '
            'Lance avec --dart-define=GEMINI_API_KEY=TA_CLE');
      }
      return false;
    }
    return true;
  }

  static List<Map<String, dynamic>> generateQuizQuestions({required String theme, required int age}) {
    return [
      {'question': 'A-t-il/elle répété les mêmes erreurs après correction ?', 'answers': ['Jamais', 'Rarement', 'Souvent', 'Toujours'], 'correctIndex': 0},
      {'question': 'A-t-il/elle eu un bon comportement avec ses frères/sœurs ?', 'answers': ['Toujours', 'Souvent', 'Rarement', 'Jamais'], 'correctIndex': 0},
      {'question': 'A-t-il/elle été respectueux(se) envers ses parents ?', 'answers': ['Toujours', 'Souvent', 'Rarement', 'Jamais'], 'correctIndex': 0},
      {'question': 'A-t-il/elle utilisé des gros mots ou mal parlé ?', 'answers': ['Jamais', 'Rarement', 'Souvent', 'Toujours'], 'correctIndex': 0},
      {'question': 'Quelle était son attitude générale cette semaine ?', 'answers': ['Excellente', 'Bonne', 'Moyenne', 'Mauvaise'], 'correctIndex': 0},
      {'question': 'A-t-il/elle boudé ou fait la tête ?', 'answers': ['Jamais', 'Rarement', 'Souvent', 'Toujours'], 'correctIndex': 0},
      {'question': 'A-t-il/elle rendu service spontanément ?', 'answers': ['Souvent', 'Parfois', 'Rarement', 'Jamais'], 'correctIndex': 0},
      {'question': 'A-t-il/elle eu un acte fraternel ou généreux ?', 'answers': ['Oui plusieurs fois', 'Une fois', 'Rarement', 'Aucun'], 'correctIndex': 0},
      {'question': 'Comment a-t-il/elle géré ses disputes ou conflits ?', 'answers': ['Très bien', 'Bien', 'Difficilement', 'Très mal'], 'correctIndex': 0},
      {'question': 'A-t-il/elle fait ses devoirs sans rappel ?', 'answers': ['Toujours', 'Souvent', 'Rarement', 'Jamais'], 'correctIndex': 0},
    ];
  }

  // 'positive': index 0 = meilleur, index max = pire
  // 'negative': index 0 = pire, index max = meilleur
  static const List<String> _questionSense = [
    'negative', // Q1: repeter erreurs: Jamais(idx0)=bon
    'positive', // Q2: comportement freres: Toujours(idx0)=bon
    'positive', // Q3: respect parents: Toujours(idx0)=bon
    'negative', // Q4: gros mots: Jamais(idx0)=bon
    'positive', // Q5: attitude: Excellente(idx0)=bon
    'negative', // Q6: bouder: Jamais(idx0)=bon
    'positive', // Q7: rendre service: Souvent(idx0)=bon
    'positive', // Q8: acte fraternel: Oui(idx0)=bon
    'positive', // Q9: gestion disputes: Tres bien(idx0)=bon
    'positive', // Q10: devoirs: Toujours(idx0)=bon
  ];

  static int calculateScore(List<Map<String, dynamic>> questions, List<dynamic> answers) {
    if (questions.isEmpty) return 10;
    double total = 0;
    for (int i = 0; i < questions.length && i < answers.length; i++) {
      final val = answers[i];
      int idx = 0;
      if (val is num) {
        idx = val.toInt();
      } else if (val is String) {
        final opts = questions[i]['answers'] as List<dynamic>? ?? [];
        idx = opts.indexOf(val);
        if (idx < 0) idx = 0;
      }
      final List<dynamic> opts = questions[i]['answers'] as List<dynamic>? ?? [];
      final int n = opts.isNotEmpty ? opts.length - 1 : 3;
      if (n <= 0) continue;
      final sense = i < _questionSense.length ? _questionSense[i] : 'positive';
      double points;
      if (sense == 'negative') {
        // index 0 = bonne reponse (Jamais/Non), index max = mauvaise (Toujours)
        points = idx * (20.0 / (n * questions.length));
      } else {
        // index 0 = bonne reponse (Toujours/Excellente), index max = mauvaise
        points = (n - idx) * (20.0 / (n * questions.length));
      }
      total += points;
    }
    return total.round().clamp(0, 20);
  }

  static String _extract(String text, String key) {
    final patterns = [
      RegExp(key + r'\s*:\s*\*\*(.+?)\*\*', dotAll: true),
      RegExp(key + r'\s*:\s*(.+?)(?=\n[A-Z_]+\s*:|$)', dotAll: true),
    ];
    for (final p in patterns) {
      final m = p.firstMatch(text);
      if (m != null) return m.group(1)!.trim().replaceAll('**', '').trim();
    }
    final simple = RegExp(key + r'[:\s]+(.+)', caseSensitive: false);
    final m2 = simple.firstMatch(text);
    if (m2 != null) return m2.group(1)!.trim().replaceAll('**', '').trim();
    return '';
  }

  static Future<Map<String, dynamic>> _evaluateOneChild({
    required String childName,
    required int score,
    required List<dynamic> rawAnswers,
    required List<Map<String, dynamic>> questions,
  }) async {
    final List<String> details = [];
    for (int i = 0; i < questions.length && i < rawAnswers.length; i++) {
      details.add('- ' + (questions[i]['question'] ?? '') + ' => ' + rawAnswers[i].toString());
    }
    final answersText = details.join('\n');
    final prompt = '''Tu es un éducateur bienveillant et expert en développement de l'enfant.
Évalue le comportement de $childName cette semaine.
Note calculée sur ses réponses : $score/20.

Détail des réponses :
$answersText

Rédige une évaluation personnalisée, chaleureuse et encourageante en français.
Utilise EXACTEMENT ce format (une ligne par section) :

APPRECIATION: [2-3 phrases personnalisées sur son comportement global cette semaine]
POINT_FORT: [1 phrase sur ce qu il fait particulièrement bien]
POINT_AMELIORER: [1 phrase bienveillante sur un axe de progrès]
CONSEIL: [1 conseil pratique et motivant pour la semaine prochaine]''';

    try {
      if (!_checkKey()) {
        return {'nom': childName, 'note': score, 'appreciation': 'L\'assistant IA n\'est pas configuré. Vérifiez la clé API Gemini.', 'point_fort': '—', 'point_ameliorer': '—', 'conseil': '—'};
      }
      final response = await http.post(
        Uri.parse(_baseUrl + '?key=' + _apiKey),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'contents': [{'parts': [{'text': prompt}]}],
          'generationConfig': {'temperature': 0.75, 'maxOutputTokens': 600},
        }),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final text = data['candidates'][0]['content']['parts'][0]['text'] as String;
        print('EVAL_OK_' + childName + ': ' + text.substring(0, text.length > 150 ? 150 : text.length));
        final appreciation = _extract(text, 'APPRECIATION');
        final pointFort = _extract(text, 'POINT_FORT');
        final pointAmeliorer = _extract(text, 'POINT_AMELIORER');
        final conseil = _extract(text, 'CONSEIL');
        return {
          'nom': childName,
          'note': score,
          'appreciation': appreciation.isNotEmpty ? appreciation : text.split('\n').first.trim(),
          'point_fort': pointFort.isNotEmpty ? pointFort : 'Bon comportement général',
          'point_ameliorer': pointAmeliorer.isNotEmpty ? pointAmeliorer : 'Continuer les efforts',
          'conseil': conseil.isNotEmpty ? conseil : 'Garde le cap !',
        };
      } else {
        print('EVAL_ERR_' + childName + ': ' + response.statusCode.toString());
        return {'nom': childName, 'note': score, 'appreciation': 'Bonne semaine dans l\'ensemble.', 'point_fort': 'Comportement correct', 'point_ameliorer': 'Maintenir les efforts', 'conseil': 'Continue comme ça !'};
      }
    } catch (e) {
      print('EVAL_CATCH_' + childName + ': ' + e.toString());
      return {'nom': childName, 'note': score, 'appreciation': 'Bonne semaine dans l\'ensemble.', 'point_fort': 'Comportement correct', 'point_ameliorer': 'Maintenir les efforts', 'conseil': 'Continue comme ça !'};
    }
  }

  static Future<Map<String, dynamic>> generateGroupAppreciation({
    required List<String> childNames,
    required String context,
    required Map<String, dynamic> answers,
  }) async {
    print('GROUP_EVAL: ' + childNames.length.toString() + ' enfants');
    final questions = generateQuizQuestions(theme: context, age: 10);
    final futures = childNames.map((name) {
      final raw = answers[name];
      List<dynamic> childAnswers;
      if (raw is List) {
        childAnswers = raw;
      } else if (raw is Map) {
        childAnswers = raw.values.toList();
      } else {
        childAnswers = [];
      }
      final score = calculateScore(questions, childAnswers);
      return _evaluateOneChild(childName: name, score: score, rawAnswers: childAnswers, questions: questions);
    });
    final results = await Future.wait(futures);
    print('GROUP_DONE: ' + results.length.toString() + ' resultats');
    return {'evaluations': results};
  }

  static Future<String> generateAppreciation({
    required String childName,
    int age = 10,
    required String context,
    required Map<String, dynamic> answers,
    dynamic history,
    int bonusCount = 0,
    int penaltyCount = 0,
    dynamic activePunishments,
    dynamic usableImmunities,
    int streakDays = 0,
    int totalPoints = 0,
    dynamic recentReasons,
  }) async {
    final questions = generateQuizQuestions(theme: context, age: age);
    final score = calculateScore(questions, answers.values.toList());
    final result = await _evaluateOneChild(
      childName: childName,
      score: score,
      rawAnswers: answers.values.toList(),
      questions: questions,
    );
    return jsonEncode({
      'note': result['note'],
      'appreciation': result['appreciation'],
      'conseil': result['conseil'],
      'point_fort': result['point_fort'],
      'point_ameliorer': result['point_ameliorer'],
    });
  }
  // ── Chat conseil enfant ──────────────────────────────────────────────────
  static Future<String> chatWithChild({
    required String childName,
    required int age,
    required String message,
    List<Map<String, String>> history = const [],
  }) async {
    final systemPrompt = '''Tu es un assistant bienveillant et encourageant pour les enfants.
Tu parles a $childName qui a $age ans.
Reponds de facon simple, positive et adaptee a son age.
Tu peux l aider avec ses devoirs, ses questions, ses problemes du quotidien.
Sois toujours encourageant et bienveillant. Reponds en francais.''';

    final contents = <Map<String, dynamic>>[];
    contents.add({'parts': [{'text': systemPrompt}], 'role': 'user'});
    contents.add({'parts': [{'text': 'Bonjour ! Je suis pret a t aider.'}], 'role': 'model'});
    for (final h in history) {
      contents.add({'parts': [{'text': h['content'] ?? ''}], 'role': h['role'] == 'user' ? 'user' : 'model'});
    }
    contents.add({'parts': [{'text': message}], 'role': 'user'});

    try {
      if (!_checkKey()) return 'L\'assistant IA n\'est pas configuré.';
      final response = await http.post(
        Uri.parse(_baseUrl + '?key=' + _apiKey),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'contents': contents,
          'generationConfig': {'temperature': 0.8, 'maxOutputTokens': 800},
        }),
      ).timeout(const Duration(seconds: 20));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['candidates'][0]['content']['parts'][0]['text'] as String;
      }
      return 'Je suis la pour t aider ! Pose-moi ta question.';
    } catch (e) {
      return 'Desolee, je ne peux pas repondre maintenant. Reessaie !';
    }
  }

  // ── Verdict Tribunal ─────────────────────────────────────────────────────
  static Future<Map<String, dynamic>> judgeTribunal({
    required String title,
    required String description,
    required String plaintiffName,
    required String accusedName,
  }) async {
    final prompt = '''Tu es un juge impartial dans un tribunal familial pour enfants.
Analyse ce cas et rends un verdict juste et educatif.

Titre de l affaire : $title
Description : $description
Plaignant : $plaintiffName
Accuse : $accusedName

Rends ton verdict en utilisant EXACTEMENT ce format :

VERDICT: [coupable/innocent/classe]
RAISON: [2-3 phrases expliquant le verdict de facon educative]
SANCTION: [si coupable: suggestion de sanction adaptee, sinon: rien]
CONSEIL: [1 conseil pour les deux parties pour eviter ce genre de conflit]''';

    try {
      if (!_checkKey()) {
        return {'verdict': 'dismissed', 'raison': 'L\'assistant IA n\'est pas configuré.', 'sanction': '', 'conseil': ''};
      }
      final response = await http.post(
        Uri.parse(_baseUrl + '?key=' + _apiKey),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'contents': [{'parts': [{'text': prompt}], 'role': 'user'}],
          'generationConfig': {'temperature': 0.6, 'maxOutputTokens': 500},
        }),
      ).timeout(const Duration(seconds: 20));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final text = data['candidates'][0]['content']['parts'][0]['text'] as String;
        final verdict = _extract(text, 'VERDICT').toLowerCase();
        final raison = _extract(text, 'RAISON');
        final sanction = _extract(text, 'SANCTION');
        final conseil = _extract(text, 'CONSEIL');
        return {
          'verdict': verdict.contains('coupable') ? 'guilty' : verdict.contains('innocent') ? 'innocent' : 'dismissed',
          'raison': raison.isNotEmpty ? raison : 'Verdict rendu par l IA.',
          'sanction': sanction,
          'conseil': conseil,
          'rawText': text,
        };
      }
      return {'verdict': 'dismissed', 'raison': 'Impossible de juger pour le moment.', 'sanction': '', 'conseil': ''};
    } catch (e) {
      return {'verdict': 'dismissed', 'raison': 'Erreur de connexion.', 'sanction': '', 'conseil': ''};
    }
  }

  // ── Enigme de punition ───────────────────────────────────────────────────
  static Future<Map<String, dynamic>> generateEnigme({
    required int age,
    required String theme,
  }) async {
    final prompt = '''Genere une enigme amusante et educative pour un enfant de $age ans.
Theme : $theme
L enigme doit etre adaptee a l age, ni trop facile ni trop difficile.
Reponds UNIQUEMENT avec ce format exact :

ENIGME: [la question ou devinette]
INDICE: [un petit indice si l enfant bloque]
REPONSE: [la reponse]
EXPLICATION: [courte explication educative]''';

    try {
      if (!_checkKey()) {
        return {'enigme': 'L\'assistant IA n\'est pas configuré.', 'indice': '', 'reponse': '', 'explication': ''};
      }
      final response = await http.post(
        Uri.parse(_baseUrl + '?key=' + _apiKey),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'contents': [{'parts': [{'text': prompt}], 'role': 'user'}],
          'generationConfig': {'temperature': 0.9, 'maxOutputTokens': 400},
        }),
      ).timeout(const Duration(seconds: 20));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final text = data['candidates'][0]['content']['parts'][0]['text'] as String;
        return {
          'enigme': _extract(text, 'ENIGME'),
          'indice': _extract(text, 'INDICE'),
          'reponse': _extract(text, 'REPONSE'),
          'explication': _extract(text, 'EXPLICATION'),
        };
      }
      return {'enigme': 'Je suis leger comme une plume mais meme le plus fort ne peut me tenir longtemps. Qui suis-je ?', 'indice': 'Pense a la respiration...', 'reponse': 'Le souffle', 'explication': 'Le souffle est invisible mais essentiel a la vie !'};
    } catch (e) {
      return {'enigme': 'Plus je seche, plus je suis mouilee. Qui suis-je ?', 'indice': 'C est utile apres le bain...', 'reponse': 'Une serviette', 'explication': 'La serviette absorbe l eau en sechant !'};
    }
  }
  static Future<String> chatFamilyAssistant({required String message, required String familyContext, List<Map<String, String>> history = const []}) async {
    if (!_checkKey()) return 'L\'assistant IA n\'est pas configuré.';
    final systemPrompt = 'Tu es un assistant familial intelligent et bienveillant.\n' + 'Tu as acces aux donnees completes de la famille.\n' + familyContext;
    final contents = <Map<String, dynamic>>[{'parts': [{'text': systemPrompt}], 'role': 'user'}, {'parts': [{'text': 'Bonjour!'}], 'role': 'model'}];
    for (final h in history) { contents.add({'parts': [{'text': h['content'] ?? ''}], 'role': h['role'] == 'user' ? 'user' : 'model'}); }
    contents.add({'parts': [{'text': message}], 'role': 'user'});
    try { final response = await http.post(Uri.parse(_baseUrl + '?key=' + _apiKey), headers: {'Content-Type': 'application/json'}, body: jsonEncode({'contents': contents, 'generationConfig': {'temperature': 0.7, 'maxOutputTokens': 1000}})).timeout(const Duration(seconds: 30));
    if (response.statusCode == 200) { final data = jsonDecode(response.body); return data['candidates'][0]['content']['parts'][0]['text'] as String; }
    return 'Je ne peux pas repondre pour le moment.'; } catch (e) { return 'Erreur de connexion.'; } }
}
