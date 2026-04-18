// lib/screens/school_notes_screen.dart
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/family_provider.dart';
import '../services/gemini_service.dart';
import '../widgets/animated_background.dart';
import '../widgets/glass_card.dart';
import '../widgets/tv_focus_wrapper.dart';

// ═══════════════════════════════════════════════════════════
// CAHIER QUI S'OUVRE
// ═══════════════════════════════════════════════════════════
class _SchoolNotebookOpen extends StatefulWidget {
  final VoidCallback onComplete;
  const _SchoolNotebookOpen({required this.onComplete});
  @override
  State<_SchoolNotebookOpen> createState() => _SchoolNotebookOpenState();
}

class _SchoolNotebookOpenState extends State<_SchoolNotebookOpen>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _coverRotation;
  late Animation<double> _pagesFade;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1200))
      ..forward().then((_) {
        if (mounted) widget.onComplete();
      });
    _coverRotation = Tween(begin: 0.0, end: -pi * 0.45).animate(
        CurvedAnimation(
            parent: _ctrl,
            curve: const Interval(0.0, 0.6, curve: Curves.easeOutBack)));
    _pagesFade = Tween(begin: 0.0, end: 1.0).animate(CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(0.3, 0.7, curve: Curves.easeIn)));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) => Center(
        child: SizedBox(
          width: 260,
          height: 300,
          child: Stack(alignment: Alignment.center, children: [
            Opacity(
              opacity: _pagesFade.value,
              child: Container(
                width: 220,
                height: 270,
                decoration: BoxDecoration(
                    color: const Color(0xFFFFF8E1),
                    borderRadius: BorderRadius.circular(4),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withOpacity(0.3),
                          blurRadius: 10,
                          offset: const Offset(2, 4))
                    ]),
                child: CustomPaint(painter: _SchoolPagePainter()),
              ),
            ),
            Positioned(
              left: 20,
              child: Transform(
                alignment: Alignment.centerLeft,
                transform: Matrix4.identity()
                  ..setEntry(3, 2, 0.002)
                  ..rotateY(_coverRotation.value),
                child: Container(
                  width: 220,
                  height: 270,
                  decoration: BoxDecoration(
                      color: const Color(0xFF6A1B9A),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                          color: const Color(0xFF4A148C), width: 2),
                      boxShadow: [
                        BoxShadow(
                            color: Colors.black.withOpacity(0.4),
                            blurRadius: 8,
                            offset: const Offset(3, 3))
                      ]),
                  child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.psychology_rounded,
                            color: Colors.white70, size: 48),
                        const SizedBox(height: 8),
                        Text('COMPORTEMENT',
                            style: TextStyle(
                                color: Colors.white.withOpacity(0.9),
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 2)),
                      ]),
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

class _SchoolPagePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFBBDEFB).withOpacity(0.4)
      ..strokeWidth = 0.8;
    for (int i = 1; i <= 10; i++) {
      final y = i * size.height / 11;
      canvas.drawLine(Offset(20, y), Offset(size.width - 20, y), paint);
    }
    final marginPaint = Paint()
      ..color = Colors.redAccent.withOpacity(0.3)
      ..strokeWidth = 1.5;
    canvas.drawLine(
        const Offset(40, 10), Offset(40, size.height - 10), marginPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

// ═══════════════════════════════════════════════════════════
// ÉTOILES
// ═══════════════════════════════════════════════════════════
class _StarsAnimation extends StatefulWidget {
  final int starCount;
  final VoidCallback onComplete;
  const _StarsAnimation({required this.starCount, required this.onComplete});
  @override
  State<_StarsAnimation> createState() => _StarsAnimationState();
}

class _StarsAnimationState extends State<_StarsAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1600))
      ..forward().then((_) {
        if (mounted) widget.onComplete();
      });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        final t = _ctrl.value;
        return Stack(alignment: Alignment.center, children: [
          Container(color: Colors.purple.withOpacity(0.04 * (1 - t))),
          Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(widget.starCount, (i) {
                final starDelay = i * 0.15;
                final starProgress =
                    ((t - starDelay) / 0.3).clamp(0.0, 1.0);
                final scale = Curves.elasticOut.transform(starProgress);
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Transform.scale(
                    scale: scale,
                    child: Text('⭐',
                        style: TextStyle(fontSize: 36, shadows: [
                          Shadow(
                              color: Colors.amber
                                  .withOpacity(0.6 * starProgress),
                              blurRadius: 10),
                        ])),
                  ),
                );
              })),
          if (t > 0.5)
            Positioned(
              bottom: MediaQuery.of(context).size.height * 0.32,
              child: Opacity(
                opacity: ((t - 0.5) / 0.3).clamp(0.0, 1.0),
                child: Text(
                  widget.starCount >= 4
                      ? 'EXCELLENT !'
                      : widget.starCount >= 3
                          ? 'BIEN !'
                          : widget.starCount >= 2
                              ? 'CORRECT'
                              : 'PEUT MIEUX FAIRE',
                  style: TextStyle(
                      color: widget.starCount >= 4
                          ? Colors.amber
                          : widget.starCount >= 3
                              ? Colors.greenAccent
                              : widget.starCount >= 2
                                  ? Colors.orangeAccent
                                  : Colors.redAccent,
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 3),
                ),
              ),
            ),
        ]);
      },
    );
  }
}

int _percentToStars(double percent) {
  if (percent >= 90) return 5;
  if (percent >= 75) return 4;
  if (percent >= 60) return 3;
  if (percent >= 40) return 2;
  return 1;
}

Future<void> showSchoolNotebookAnimation(BuildContext context) {
  return showGeneralDialog(
    context: context,
    barrierDismissible: false,
    barrierColor: Colors.black87,
    transitionDuration: const Duration(milliseconds: 100),
    pageBuilder: (ctx, _, __) => Material(
      color: Colors.transparent,
      child: _SchoolNotebookOpen(onComplete: () => Navigator.of(ctx).pop()),
    ),
  );
}

Future<void> showStarsAnimation(BuildContext context, double percent) {
  final stars = _percentToStars(percent);
  return showGeneralDialog(
    context: context,
    barrierDismissible: false,
    barrierColor: Colors.black87,
    transitionDuration: const Duration(milliseconds: 100),
    pageBuilder: (ctx, _, __) => Material(
      color: Colors.transparent,
      child: _StarsAnimation(
          starCount: stars, onComplete: () => Navigator.of(ctx).pop()),
    ),
  );
}

// ═══════════════════════════════════════════════════════════
// MODÈLE NOTE IA
// ═══════════════════════════════════════════════════════════
class _AiEvalResult {
  final int aiNote;
  final String appreciation;
  final String conseil;
  final int parentNote;
  final String context;
  const _AiEvalResult({
    required this.aiNote,
    required this.appreciation,
    required this.conseil,
    required this.parentNote,
    required this.context,
  });
}

// ═══════════════════════════════════════════════════════════
// QUESTIONNAIRE IA
// ═══════════════════════════════════════════════════════════
class _AiQuestionnaireSheet extends StatefulWidget {
  final String childName;
  final String childId;
  final Function(_AiEvalResult) onComplete;
  const _AiQuestionnaireSheet({
    required this.childName,
    required this.childId,
    required this.onComplete,
  });
  @override
  State<_AiQuestionnaireSheet> createState() => _AiQuestionnaireSheetState();
}

class _AiQuestionnaireSheetState extends State<_AiQuestionnaireSheet> {
  int _step = 0;
  String _context = '';
  final Map<String, String> _answers = {};
  int _parentNote = 10;
  bool _loading = false;

  static const _contexts = [
    {'emoji': '🏫', 'label': 'Jour d\'école', 'value': 'jour_ecole'},
    {'emoji': '🏠', 'label': 'Mercredi / Samedi', 'value': 'demi_journee'},
    {'emoji': '🌴', 'label': 'Vacances', 'value': 'vacances'},
    {'emoji': '🤒', 'label': 'Enfant malade', 'value': 'malade'},
    {'emoji': '🎉', 'label': 'Jour spécial / Fête', 'value': 'special'},
  ];

  List<Map<String, dynamic>> get _questions {
    switch (_context) {
      case 'jour_ecole':
        return [
          {
            'question': '📚 Avait-il des devoirs ce soir ?',
            'key': 'devoirs_existence',
            'options': [
              {'label': '✅ Oui', 'value': 'oui'},
              {'label': '❌ Non', 'value': 'non'},
            ],
          },
          if (_answers['devoirs_existence'] == 'oui') ...[
            {
              'question': '✏️ Les devoirs ont été faits ?',
              'key': 'devoirs_faits',
              'options': [
                {'label': '✅ Oui, tout', 'value': 'oui_tout'},
                {'label': '⚠️ Partiellement', 'value': 'partiel'},
                {'label': '❌ Non', 'value': 'non'},
              ],
            },
          ],
          {
            'question': '😤 Combien de remarques dans la journée ?',
            'key': 'remarques',
            'options': [
              {'label': '0️⃣ Aucune', 'value': 'aucune'},
              {'label': '1️⃣ Une', 'value': 'une'},
              {'label': '2️⃣ Deux', 'value': 'deux'},
              {'label': '3️⃣ Trois+', 'value': 'plusieurs'},
            ],
          },
          {
            'question': '🏫 Comportement à l\'école ?',
            'key': 'comportement_ecole',
            'options': [
              {'label': '😇 Excellent', 'value': 'excellent'},
              {'label': '🙂 Bien', 'value': 'bien'},
              {'label': '😐 Moyen', 'value': 'moyen'},
              {'label': '😤 Difficile', 'value': 'difficile'},
            ],
          },
          {
            'question': '🔁 A-t-on dû répéter plusieurs fois ?',
            'key': 'repetitions',
            'options': [
              {'label': '✅ Non, jamais', 'value': 'jamais'},
              {'label': '🔁 1 ou 2 fois', 'value': 'une_deux'},
              {'label': '😤 3 fois ou plus', 'value': 'trois_plus'},
              {'label': '😡 Sans cesse', 'value': 'sans_cesse'},
            ],
          },
          {
            'question': '🙏 Obéissance générale ?',
            'key': 'obeissance',
            'options': [
              {'label': '😇 Toujours', 'value': 'toujours'},
              {'label': '🙂 Souvent', 'value': 'souvent'},
              {'label': '😐 Parfois', 'value': 'parfois'},
              {'label': '😤 Rarement', 'value': 'rarement'},
              {'label': '😡 Jamais', 'value': 'jamais'},
            ],
          },
          {
            'question': '🏠 Tâches ménagères effectuées ?',
            'key': 'taches',
            'options': [
              {'label': '✅ Faites', 'value': 'faites'},
              {'label': '⚠️ Rappel nécessaire', 'value': 'rappel'},
              {'label': '❌ Refus', 'value': 'refus'},
              {'label': '➖ Non demandé', 'value': 'non_demande'},
            ],
          },
          {
            'question': '🤝 Actes fraternels envers les frères/sœurs ?',
            'key': 'fraternite',
            'options': [
              {'label': '😇 Très bien', 'value': 'tres_bien'},
              {'label': '🙂 Bien', 'value': 'bien'},
              {'label': '😐 Conflits mineurs', 'value': 'conflits'},
              {'label': '😡 Conflits importants', 'value': 'conflits_graves'},
              {'label': '➖ Enfant unique', 'value': 'na'},
            ],
          },
          {
            'question': '🍽️ Comportement à table ?',
            'key': 'table',
            'options': [
              {'label': '😇 Excellent', 'value': 'excellent'},
              {'label': '🙂 Correct', 'value': 'correct'},
              {'label': '😐 Agité', 'value': 'agite'},
              {'label': '😤 Difficile', 'value': 'difficile'},
            ],
          },
          {
            'question': '💬 Politesse et respect des adultes ?',
            'key': 'politesse',
            'options': [
              {'label': '😇 Très poli', 'value': 'tres_poli'},
              {'label': '🙂 Correct', 'value': 'correct'},
              {'label': '😐 Quelques oublis', 'value': 'oublis'},
              {'label': '😤 Irrespectueux', 'value': 'irrespectueux'},
            ],
          },
          {
            'question': '🔄 Réaction face aux corrections ?',
            'key': 'reaction_correction',
            'options': [
              {'label': '😇 Accepte bien', 'value': 'accepte_bien'},
              {'label': '😐 Accepte difficilement', 'value': 'accepte_difficilement'},
              {'label': '😡 Refuse / s\'énerve', 'value': 'refuse'},
            ],
          },
          {
            'question': '🤥 Honnêteté dans la journée ?',
            'key': 'honnetete',
            'options': [
              {'label': '😇 Toujours honnête', 'value': 'toujours'},
              {'label': '🙂 Globalement', 'value': 'souvent'},
              {'label': '😐 Quelques mensonges', 'value': 'parfois'},
              {'label': '😡 A menti', 'value': 'jamais'},
            ],
          },
          {
            'question': '😊 Humeur générale de la journée ?',
            'key': 'humeur_generale',
            'options': [
              {'label': '😄 Positive', 'value': 'positive'},
              {'label': '😐 Neutre', 'value': 'neutre'},
              {'label': '😞 Négative', 'value': 'negative'},
            ],
          },
          {
            'question': '🛏️ Coucher sans problème ?',
            'key': 'coucher',
            'options': [
              {'label': '✅ Oui, sans souci', 'value': 'oui'},
              {'label': '⚠️ Petit rappel', 'value': 'rappel'},
              {'label': '❌ Difficile', 'value': 'difficile'},
            ],
          },
          {
            'question': '📱 Respect du temps d\'écran ?',
            'key': 'ecran',
            'options': [
              {'label': '✅ Respecté', 'value': 'respecte'},
              {'label': '⚠️ Petit dépassement', 'value': 'leger'},
              {'label': '❌ Non respecté', 'value': 'non_respecte'},
            ],
          },
          {
            'question': '🚿 Hygiène personnelle effectuée ?',
            'key': 'hygiene',
            'options': [
              {'label': '✅ Oui, sans rappel', 'value': 'oui'},
              {'label': '⚠️ Après rappel', 'value': 'partiellement'},
              {'label': '❌ Refus', 'value': 'non'},
            ],
          },
          {
            'question': '⭐ Y a-t-il eu un moment positif notable ?',
            'key': 'moment_positif',
            'options': [
              {'label': '✅ Oui', 'value': 'oui'},
              {'label': '❌ Non', 'value': 'non'},
            ],
          },
        ];
      case 'demi_journee':
        return [
          {
            'question': '🔁 A-t-on dû répéter plusieurs fois ?',
            'key': 'repetitions',
            'options': [
              {'label': '✅ Non, jamais', 'value': 'jamais'},
              {'label': '🔁 1 ou 2 fois', 'value': 'une_deux'},
              {'label': '😤 3 fois ou plus', 'value': 'trois_plus'},
              {'label': '😡 Sans cesse', 'value': 'sans_cesse'},
            ],
          },
          {
            'question': '🙏 Obéissance générale ?',
            'key': 'obeissance',
            'options': [
              {'label': '😇 Toujours', 'value': 'toujours'},
              {'label': '🙂 Souvent', 'value': 'souvent'},
              {'label': '😐 Parfois', 'value': 'parfois'},
              {'label': '😤 Rarement', 'value': 'rarement'},
              {'label': '😡 Jamais', 'value': 'jamais'},
            ],
          },
          {
            'question': '🏠 Tâches ménagères effectuées ?',
            'key': 'taches',
            'options': [
              {'label': '✅ Faites', 'value': 'faites'},
              {'label': '⚠️ Rappel nécessaire', 'value': 'rappel'},
              {'label': '❌ Refus', 'value': 'refus'},
              {'label': '➖ Non demandé', 'value': 'non_demande'},
            ],
          },
          {
            'question': '🤝 Actes fraternels ?',
            'key': 'fraternite',
            'options': [
              {'label': '😇 Très bien', 'value': 'tres_bien'},
              {'label': '🙂 Bien', 'value': 'bien'},
              {'label': '😐 Conflits mineurs', 'value': 'conflits'},
              {'label': '😡 Conflits importants', 'value': 'conflits_graves'},
              {'label': '➖ Enfant unique', 'value': 'na'},
            ],
          },
          {
            'question': '📱 Respect du temps d\'écran ?',
            'key': 'ecran',
            'options': [
              {'label': '✅ Respecté', 'value': 'respecte'},
              {'label': '⚠️ Petit dépassement', 'value': 'leger'},
              {'label': '❌ Non respecté', 'value': 'non_respecte'},
            ],
          },
          {
            'question': '💬 Politesse et respect ?',
            'key': 'politesse',
            'options': [
              {'label': '😇 Très poli', 'value': 'tres_poli'},
              {'label': '🙂 Correct', 'value': 'correct'},
              {'label': '😐 Quelques oublis', 'value': 'oublis'},
              {'label': '😤 Irrespectueux', 'value': 'irrespectueux'},
            ],
          },
          {
            'question': '🎯 Autonomie dans la journée ?',
            'key': 'autonomie',
            'options': [
              {'label': '😇 Très autonome', 'value': 'tres_autonome'},
              {'label': '🙂 Correct', 'value': 'correct'},
              {'label': '😐 Besoin d\'aide', 'value': 'aide'},
            ],
          },
          {
            'question': '🛏️ Coucher sans problème ?',
            'key': 'coucher',
            'options': [
              {'label': '✅ Oui', 'value': 'oui'},
              {'label': '⚠️ Rappel', 'value': 'rappel'},
              {'label': '❌ Difficile', 'value': 'difficile'},
            ],
          },
        ];
      case 'vacances':
        return [
          {
            'question': '🔁 A-t-on dû répéter plusieurs fois ?',
            'key': 'repetitions',
            'options': [
              {'label': '✅ Non, jamais', 'value': 'jamais'},
              {'label': '🔁 1 ou 2 fois', 'value': 'une_deux'},
              {'label': '😤 3 fois ou plus', 'value': 'trois_plus'},
              {'label': '😡 Sans cesse', 'value': 'sans_cesse'},
            ],
          },
          {
            'question': '🏠 A aidé à la maison ?',
            'key': 'aide_maison',
            'options': [
              {'label': '😇 Beaucoup', 'value': 'beaucoup'},
              {'label': '🙂 Un peu', 'value': 'un_peu'},
              {'label': '❌ Pas du tout', 'value': 'non'},
            ],
          },
          {
            'question': '🤝 Actes fraternels ?',
            'key': 'fraternite',
            'options': [
              {'label': '😇 Très bien', 'value': 'tres_bien'},
              {'label': '🙂 Bien', 'value': 'bien'},
              {'label': '😐 Conflits mineurs', 'value': 'conflits'},
              {'label': '😡 Conflits importants', 'value': 'conflits_graves'},
              {'label': '➖ Enfant unique', 'value': 'na'},
            ],
          },
          {
            'question': '📱 Respect du temps d\'écran ?',
            'key': 'ecran',
            'options': [
              {'label': '✅ Respecté', 'value': 'respecte'},
              {'label': '⚠️ Léger dépassement', 'value': 'leger'},
              {'label': '❌ Non respecté', 'value': 'non_respecte'},
            ],
          },
          {
            'question': '😊 Attitude générale de la journée ?',
            'key': 'attitude',
            'options': [
              {'label': '😇 Excellente', 'value': 'excellente'},
              {'label': '🙂 Bonne', 'value': 'bonne'},
              {'label': '😐 Moyenne', 'value': 'moyenne'},
              {'label': '😤 Difficile', 'value': 'difficile'},
            ],
          },
          {
            'question': '💬 Politesse et respect ?',
            'key': 'politesse',
            'options': [
              {'label': '😇 Très poli', 'value': 'tres_poli'},
              {'label': '🙂 Correct', 'value': 'correct'},
              {'label': '😐 Quelques oublis', 'value': 'oublis'},
              {'label': '😤 Irrespectueux', 'value': 'irrespectueux'},
            ],
          },
          {
            'question': '🛏️ Coucher sans problème ?',
            'key': 'coucher',
            'options': [
              {'label': '✅ Oui', 'value': 'oui'},
              {'label': '⚠️ Rappel', 'value': 'rappel'},
              {'label': '❌ Difficile', 'value': 'difficile'},
            ],
          },
        ];
      case 'malade':
        return [
          {
            'question': '😷 Comment s\'est passée la journée ?',
            'key': 'journee',
            'options': [
              {'label': '😇 Très bien malgré tout', 'value': 'tres_bien'},
              {'label': '🙂 Correct', 'value': 'correct'},
              {'label': '😐 Difficile', 'value': 'difficile'},
            ],
          },
          {
            'question': '💊 A pris ses médicaments sans problème ?',
            'key': 'medicaments',
            'options': [
              {'label': '✅ Oui', 'value': 'oui'},
              {'label': '⚠️ Avec difficulté', 'value': 'difficulte'},
              {'label': '❌ Refus', 'value': 'refus'},
              {'label': '➖ Pas de médicaments', 'value': 'na'},
            ],
          },
          {
            'question': '💬 Attitude envers les parents ?',
            'key': 'attitude_parents',
            'options': [
              {'label': '😇 Très respectueux', 'value': 'respectueux'},
              {'label': '🙂 Correct', 'value': 'correct'},
              {'label': '😤 Difficile', 'value': 'difficile'},
            ],
          },
        ];
      case 'special':
        return [
          {
            'question': '🎉 Comportement général ?',
            'key': 'comportement',
            'options': [
              {'label': '😇 Exemplaire', 'value': 'exemplaire'},
              {'label': '🙂 Bien', 'value': 'bien'},
              {'label': '😐 Moyen', 'value': 'moyen'},
              {'label': '😤 Difficile', 'value': 'difficile'},
            ],
          },
          {
            'question': '🤝 Actes fraternels ?',
            'key': 'fraternite',
            'options': [
              {'label': '😇 Très bien', 'value': 'tres_bien'},
              {'label': '🙂 Bien', 'value': 'bien'},
              {'label': '😐 Conflits', 'value': 'conflits'},
              {'label': '➖ Enfant unique', 'value': 'na'},
            ],
          },
          {
            'question': '💬 Politesse avec les invités/famille ?',
            'key': 'politesse',
            'options': [
              {'label': '😇 Très poli', 'value': 'tres_poli'},
              {'label': '🙂 Correct', 'value': 'correct'},
              {'label': '😐 Quelques oublis', 'value': 'oublis'},
              {'label': '😤 Irrespectueux', 'value': 'irrespectueux'},
            ],
          },
          {
            'question': '🛏️ Coucher sans problème ?',
            'key': 'coucher',
            'options': [
              {'label': '✅ Oui', 'value': 'oui'},
              {'label': '⚠️ Rappel', 'value': 'rappel'},
              {'label': '❌ Difficile', 'value': 'difficile'},
            ],
          },
        ];
      default:
        return [];
    }
  }

  String get _contextLabel {
    final c = _contexts.firstWhere(
        (c) => c['value'] == _context,
        orElse: () => {'label': ''});
    return c['label'] as String;
  }

  // ── SUBMIT CORRIGÉ : utilise FamilyProvider, pas child.punishments ──
    Future<void> _submitToGemini() async {
    setState(() => _loading = true);
    try {
      final result = await GeminiService.generateAppreciation(
        childName: widget.childName,
        context: _contextLabel,
        answers: _answers,
      );
      final json = jsonDecode(result);
      final aiNote = (json['note'] as num).toInt();
      final appreciation = json['appreciation'] as String;
      final conseil = json['conseil'] as String;
      if (mounted) {
        widget.onComplete(_AiEvalResult(
          aiNote: aiNote,
          appreciation: appreciation,
          conseil: conseil,
          parentNote: _parentNote,
          context: _contextLabel,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Erreur IA : $e'),
          backgroundColor: Colors.redAccent,
        ));
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_step == 0) return _buildContextStep();
    final questions = _questions;
    if (_step > questions.length) return _buildParentNoteStep();
    final q = questions[_step - 1];
    return _buildQuestionStep(q);
  }

  Widget _buildContextStep() {
    return _buildSheetContainer(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildHeader('🌅 Quel est le contexte de la journée ?',
              'Cela permet à l\'IA d\'adapter ses questions'),
          const SizedBox(height: 24),
          ..._contexts.map((c) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _buildOptionButton(
                  label: '${c['emoji']} ${c['label']}',
                  selected: false,
                  onTap: () {
                    setState(() {
                      _context = c['value'] as String;
                      _step = 1;
                      _answers.clear();
                    });
                  },
                  color: Colors.deepPurpleAccent,
                ),
              )),
        ],
      ),
    );
  }

  Widget _buildQuestionStep(Map<String, dynamic> q) {
    final questions = _questions;
    final total = questions.length;
    final progress = (_step - 1) / total;
    final options = q['options'] as List<Map<String, String>>;
    final key = q['key'] as String;

    return _buildSheetContainer(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: progress,
                  backgroundColor: Colors.white12,
                  valueColor: const AlwaysStoppedAnimation<Color>(
                      Colors.deepPurpleAccent),
                  minHeight: 6,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Text('$_step/$total',
                style:
                    const TextStyle(color: Colors.white54, fontSize: 12)),
          ]),
          const SizedBox(height: 20),
          _buildHeader(q['question'] as String, ''),
          const SizedBox(height: 20),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: options.map((opt) {
              final selected = _answers[key] == opt['value'];
              return _buildOptionButton(
                label: opt['label']!,
                selected: selected,
                color: Colors.deepPurpleAccent,
                onTap: () {
                  setState(() {
                    _answers[key] = opt['value']!;
                  });
                  Future.delayed(const Duration(milliseconds: 300), () {
                    if (mounted) {
                      setState(() => _step++);
                    }
                  });
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          TextButton.icon(
            onPressed: () => setState(() {
              if (_step > 1) {
                _step--;
              } else {
                _step = 0;
                _context = '';
              }
            }),
            icon: const Icon(Icons.arrow_back, color: Colors.white38, size: 16),
            label: const Text('Retour',
                style: TextStyle(color: Colors.white38, fontSize: 12)),
          ),
        ],
      ),
    );
  }

  Widget _buildParentNoteStep() {
    return _buildSheetContainer(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildHeader('👨‍👩‍👧 Votre note en tant que parent',
              'L\'IA a analysé vos réponses. Donnez aussi votre ressenti.'),
          const SizedBox(height: 24),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            GestureDetector(
              onTap: () {
                if (_parentNote > 0) setState(() => _parentNote--);
              },
              child: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white10,
                  border: Border.all(color: Colors.white24),
                ),
                child: const Icon(Icons.remove, color: Colors.white70),
              ),
            ),
            const SizedBox(width: 20),
            TweenAnimationBuilder<double>(
              key: ValueKey(_parentNote),
              tween: Tween(
                  begin: (_parentNote - 1).toDouble(),
                  end: _parentNote.toDouble()),
              duration: const Duration(milliseconds: 200),
              builder: (_, val, __) => Text(
                '${val.round()} / 20',
                style: TextStyle(
                  color: val >= 10 ? Colors.greenAccent : Colors.redAccent,
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 20),
            GestureDetector(
              onTap: () {
                if (_parentNote < 20) setState(() => _parentNote++);
              },
              child: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white10,
                  border: Border.all(color: Colors.white24),
                ),
                child: const Icon(Icons.add, color: Colors.white70),
              ),
            ),
          ]),
          const SizedBox(height: 12),
          Slider(
            value: _parentNote.toDouble(),
            min: 0,
            max: 20,
            divisions: 20,
            activeColor: Colors.deepPurpleAccent,
            inactiveColor: Colors.white12,
            onChanged: (v) => setState(() => _parentNote = v.round()),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _loading ? null : _submitToGemini,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurpleAccent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
              ),
              icon: _loading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.auto_awesome),
              label: Text(
                _loading ? 'Analyse en cours...' : '✨ Obtenir l\'avis de l\'IA',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: () => setState(() => _step--),
            icon: const Icon(Icons.arrow_back, color: Colors.white38, size: 16),
            label: const Text('Retour',
                style: TextStyle(color: Colors.white38, fontSize: 12)),
          ),
        ],
      ),
    );
  }

  Widget _buildSheetContainer({required Widget child}) {
    return Container(
      constraints:
          BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
      decoration: const BoxDecoration(
        color: Color(0xFF12122A),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          child,
          SizedBox(height: MediaQuery.of(context).padding.bottom),
        ]),
      ),
    );
  }

  Widget _buildHeader(String title, String subtitle) {
    return Column(children: [
      Text(title,
          style: const TextStyle(
              color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
          textAlign: TextAlign.center),
      if (subtitle.isNotEmpty) ...[
        const SizedBox(height: 6),
        Text(subtitle,
            style: const TextStyle(color: Colors.white54, fontSize: 13),
            textAlign: TextAlign.center),
      ],
    ]);
  }

  Widget _buildOptionButton({
    required String label,
    required bool selected,
    required VoidCallback onTap,
    required Color color,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: BoxDecoration(
          color: selected
              ? color.withOpacity(0.25)
              : Colors.white.withOpacity(0.06),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? color : Colors.white.withOpacity(0.12),
            width: selected ? 2 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? color : Colors.white70,
            fontSize: 15,
            fontWeight: selected ? FontWeight.bold : FontWeight.normal,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// RÉSULTAT IA
// ═══════════════════════════════════════════════════════════
class _AiResultSheet extends StatelessWidget {
  final _AiEvalResult result;
  final String childName;
  final VoidCallback onSave;
  const _AiResultSheet({
    required this.result,
    required this.childName,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    final aiColor = result.aiNote >= 14
        ? Colors.greenAccent
        : result.aiNote >= 10
            ? Colors.orangeAccent
            : Colors.redAccent;
    final parentColor = result.parentNote >= 14
        ? Colors.greenAccent
        : result.parentNote >= 10
            ? Colors.orangeAccent
            : Colors.redAccent;

    return Container(
      constraints:
          BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.9),
      decoration: const BoxDecoration(
        color: Color(0xFF12122A),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
                color: Colors.white24, borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(height: 20),
          const Text('✨ Évaluation IA',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text('Contexte : ${result.context}',
              style: const TextStyle(color: Colors.white54, fontSize: 13)),
          const SizedBox(height: 24),
          Row(children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: aiColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: aiColor.withOpacity(0.4)),
                ),
                child: Column(children: [
                  const Text('🤖 Note IA',
                      style:
                          TextStyle(color: Colors.white70, fontSize: 12)),
                  const SizedBox(height: 8),
                  Text('${result.aiNote}/20',
                      style: TextStyle(
                          color: aiColor,
                          fontSize: 32,
                          fontWeight: FontWeight.bold)),
                ]),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: parentColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: parentColor.withOpacity(0.4)),
                ),
                child: Column(children: [
                  const Text('👨‍👩‍👧 Note parent',
                      style:
                          TextStyle(color: Colors.white70, fontSize: 12)),
                  const SizedBox(height: 8),
                  Text('${result.parentNote}/20',
                      style: TextStyle(
                          color: parentColor,
                          fontSize: 32,
                          fontWeight: FontWeight.bold)),
                ]),
              ),
            ),
          ]),
          const SizedBox(height: 20),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.deepPurple.withOpacity(0.15),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                  color: Colors.deepPurpleAccent.withOpacity(0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('💬 Appréciation IA',
                    style: TextStyle(
                        color: Colors.deepPurpleAccent,
                        fontWeight: FontWeight.bold,
                        fontSize: 13)),
                const SizedBox(height: 8),
                Text(result.appreciation,
                    style: const TextStyle(
                        color: Colors.white70, fontSize: 14, height: 1.5)),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.teal.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.tealAccent.withOpacity(0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('💡 Conseil',
                    style: TextStyle(
                        color: Colors.tealAccent,
                        fontWeight: FontWeight.bold,
                        fontSize: 13)),
                const SizedBox(height: 8),
                Text(result.conseil,
                    style: const TextStyle(
                        color: Colors.white70, fontSize: 14, height: 1.5)),
              ],
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: onSave,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurpleAccent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
              ),
              icon: const Icon(Icons.save_rounded),
              label: const Text('Enregistrer l\'évaluation',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ),
        ]),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// SCREEN PRINCIPAL
// ═══════════════════════════════════════════════════════════
class SchoolNotesScreen extends StatefulWidget {
  final String childId;
  const SchoolNotesScreen({super.key, required this.childId});
  @override
  State<SchoolNotesScreen> createState() => _SchoolNotesScreenState();
}

class _SchoolNotesScreenState extends State<SchoolNotesScreen> {
  void _startAiQuestionnaire(FamilyProvider provider) {
    final child = provider.getChild(widget.childId);
    if (child == null) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _AiQuestionnaireSheet(
        childName: child.name,
        childId: widget.childId,
        onComplete: (result) {
          Navigator.pop(ctx);
          _showAiResult(result, provider);
        },
      ),
    );
  }

  void _showAiResult(_AiEvalResult result, FamilyProvider provider) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _AiResultSheet(
        result: result,
        childName: provider.getChild(widget.childId)?.name ?? '',
        onSave: () {
          Navigator.pop(ctx);
          _saveAiEvaluation(result, provider);
        },
      ),
    );
  }

  Future<void> _saveAiEvaluation(
      _AiEvalResult result, FamilyProvider provider) async {
    final avgNote = ((result.aiNote + result.parentNote) / 2).round();
    final percent = avgNote / 20 * 100;

    await provider.addPoints(
      widget.childId,
      avgNote,
      'Évaluation IA (${result.context}) — IA:${result.aiNote}/20 Parent:${result.parentNote}/20',
      category: 'school_note',
      isBonus: true,
      date: DateTime.now(),
    );

    if (!mounted) return;
    await showStarsAnimation(context, percent);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('✨ Évaluation sauvegardée — Moyenne : $avgNote/20'),
        backgroundColor: Colors.deepPurple,
      ));
    }
  }

  void _showAddNote(FamilyProvider provider) async {
    await showSchoolNotebookAnimation(context);
    if (!mounted) return;

    String subject = '';
    int value = 10;
    DateTime selectedDate = DateTime.now();
    final subjectController = TextEditingController();
    const quickSubjects = [
      'Comportement',
      'Respect',
      'Travail en classe',
      'Effort',
      'Politesse',
      'Coopération',
      'Autonomie',
      'Ponctualité'
    ];

    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(builder: (context, setModalState) {
          return DraggableScrollableSheet(
            initialChildSize: 0.85,
            minChildSize: 0.5,
            maxChildSize: 0.95,
            builder: (context, scrollController) {
              return Container(
                decoration: BoxDecoration(
                    color: Colors.grey[900]?.withOpacity(0.95),
                    borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(24))),
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(20),
                  children: [
                    Center(
                        child: Container(
                            width: 40,
                            height: 4,
                            decoration: BoxDecoration(
                                color: Colors.white24,
                                borderRadius: BorderRadius.circular(2)))),
                    const SizedBox(height: 16),
                    Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          TweenAnimationBuilder<double>(
                            tween: Tween(begin: 0, end: 1),
                            duration: const Duration(milliseconds: 600),
                            curve: Curves.elasticOut,
                            builder: (context, val, child) =>
                                Transform.scale(scale: val, child: child),
                            child: const Text('🧠',
                                style: TextStyle(fontSize: 28)),
                          ),
                          const SizedBox(width: 10),
                          const Text('Nouvelle note comportementale',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold)),
                        ]),
                    const SizedBox(height: 24),
                    const Text('Date',
                        style:
                            TextStyle(color: Colors.white70, fontSize: 14)),
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: selectedDate,
                          firstDate: DateTime(2020),
                          lastDate: DateTime.now(),
                          builder: (context, child) => Theme(
                            data: ThemeData.dark().copyWith(
                              colorScheme: const ColorScheme.dark(
                                primary: Colors.purpleAccent,
                                onPrimary: Colors.white,
                                surface: Color(0xFF2A2A3E),
                              ),
                            ),
                            child: child!,
                          ),
                        );
                        if (picked != null) {
                          setModalState(() => selectedDate = picked);
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.06),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                              color: Colors.purpleAccent.withOpacity(0.4)),
                        ),
                        child: Row(children: [
                          const Icon(Icons.calendar_today_rounded,
                              color: Colors.purpleAccent, size: 18),
                          const SizedBox(width: 10),
                          Text(
                            '${selectedDate.day.toString().padLeft(2, '0')}/${selectedDate.month.toString().padLeft(2, '0')}/${selectedDate.year}',
                            style: const TextStyle(
                                color: Colors.white, fontSize: 15),
                          ),
                          const Spacer(),
                          const Icon(Icons.edit_calendar_rounded,
                              color: Colors.white38, size: 16),
                        ]),
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text('Critère',
                        style:
                            TextStyle(color: Colors.white70, fontSize: 14)),
                    const SizedBox(height: 8),
                    Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: quickSubjects.map((s) {
                          final isSelected = subject == s;
                          return GestureDetector(
                            onTap: () => setModalState(() {
                              subject = isSelected ? '' : s;
                              if (subject.isNotEmpty)
                                subjectController.clear();
                            }),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 8),
                              decoration: BoxDecoration(
                                  color: isSelected
                                      ? Colors.purpleAccent.withOpacity(0.2)
                                      : Colors.white.withOpacity(0.06),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                      color: isSelected
                                          ? Colors.purpleAccent
                                          : Colors.white24)),
                              child: Text(s,
                                  style: TextStyle(
                                      color: isSelected
                                          ? Colors.purpleAccent
                                          : Colors.white70,
                                      fontSize: 13)),
                            ),
                          );
                        }).toList()),
                    const SizedBox(height: 12),
                    TextField(
                      controller: subjectController,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                          hintText: 'Ou saisissez un critère...',
                          hintStyle:
                              const TextStyle(color: Colors.white38),
                          filled: true,
                          fillColor: Colors.white.withOpacity(0.06),
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide.none),
                          focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: const BorderSide(
                                  color: Colors.purpleAccent))),
                      onChanged: (val) {
                        if (val.isNotEmpty) {
                          setModalState(() => subject = '');
                        }
                      },
                    ),
                    const SizedBox(height: 20),
                    const Text('Note',
                        style:
                            TextStyle(color: Colors.white70, fontSize: 14)),
                    const SizedBox(height: 8),
                    Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          IconButton(
                            onPressed: value > 0
                                ? () => setModalState(() => value--)
                                : null,
                            icon: const Icon(Icons.remove_circle_outline,
                                color: Colors.purpleAccent),
                          ),
                          Text('$value / 20',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold)),
                          IconButton(
                            onPressed: value < 20
                                ? () => setModalState(() => value++)
                                : null,
                            icon: const Icon(Icons.add_circle_outline,
                                color: Colors.purpleAccent),
                          ),
                        ]),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: () async {
                        final label = subjectController.text.trim().isNotEmpty
                            ? subjectController.text.trim()
                            : subject;
                        if (label.isEmpty) return;
                        Navigator.pop(ctx);
                        await provider.addPoints(
                          widget.childId,
                          value,
                          'Note comportement ($label) : $value/20',
                          category: 'school_note',
                          isBonus: true,
                          date: selectedDate,
                        );
                        if (mounted) {
                          await showStarsAnimation(
                              context, value / 20 * 100);
                          if (mounted) {
                            ScaffoldMessenger.of(context)
                                .showSnackBar(SnackBar(
                              content: Text(
                                  '📝 Note enregistrée : $value/20 — $label'),
                              backgroundColor: Colors.deepPurple,
                            ));
                          }
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.purpleAccent,
                        foregroundColor: Colors.white,
                        padding:
                            const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                      icon: const Icon(Icons.save_rounded),
                      label: const Text('Enregistrer la note',
                          style: TextStyle(
                              fontSize: 15, fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              );
            },
          );
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<FamilyProvider>(
      builder: (context, fp, _) {
        final child = fp.getChild(widget.childId);
        final notes = fp.history
            .where((h) =>
                h.childId == widget.childId && h.category == 'school_note')
            .toList()
          ..sort((a, b) => b.date.compareTo(a.date));

        return AnimatedBackground(
          child: Scaffold(
            backgroundColor: Colors.transparent,
            appBar: AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              title: Text(
                '📒 Notes — ${child?.name ?? ''}',
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
            body: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 12),
                  child: Row(children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _startAiQuestionnaire(fp),
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              Colors.deepPurpleAccent.withOpacity(0.8),
                          foregroundColor: Colors.white,
                          padding:
                              const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                        ),
                        icon: const Icon(Icons.auto_awesome),
                        label: const Text('Évaluation IA',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _showAddNote(fp),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(
                              color: Colors.purpleAccent),
                          foregroundColor: Colors.purpleAccent,
                          padding:
                              const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                        ),
                        icon: const Icon(Icons.edit_note),
                        label: const Text('Note manuelle',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ]),
                ),
                Expanded(
                  child: notes.isEmpty
                      ? const Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('📒',
                                  style: TextStyle(fontSize: 48)),
                              SizedBox(height: 12),
                              Text('Aucune note enregistrée',
                                  style: TextStyle(
                                      color: Colors.white54,
                                      fontSize: 16)),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: notes.length,
                          itemBuilder: (ctx, i) {
                            final n = notes[i];
                            final color = n.points >= 14
                                ? Colors.greenAccent
                                : n.points >= 10
                                    ? Colors.orangeAccent
                                    : Colors.redAccent;
                            return GlassCard(
                              margin:
                                  const EdgeInsets.only(bottom: 10),
                              padding: const EdgeInsets.all(14),
                              child: Row(children: [
                                Container(
                                  width: 48,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: color.withOpacity(0.15),
                                    border: Border.all(
                                        color: color.withOpacity(0.4)),
                                  ),
                                  child: Center(
                                    child: Text(
                                      '${n.points}',
                                      style: TextStyle(
                                          color: color,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(n.reason,
                                          style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 13),
                                          maxLines: 2,
                                          overflow:
                                              TextOverflow.ellipsis),
                                      const SizedBox(height: 4),
                                      Text(
                                        '${n.date.day.toString().padLeft(2, '0')}/${n.date.month.toString().padLeft(2, '0')}/${n.date.year}',
                                        style: const TextStyle(
                                            color: Colors.white38,
                                            fontSize: 11),
                                      ),
                                    ],
                                  ),
                                ),
                              ]),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
