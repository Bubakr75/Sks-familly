import 'dart:convert';
import 'package:http/http.dart' as http;

class GeminiService {
  static const _baseUrl = 'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent';
  static const _apiKey = 'AIzaSyB2-EEc6HBg3Amc8cfP8vun9RO64qDHHx4';

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
}










