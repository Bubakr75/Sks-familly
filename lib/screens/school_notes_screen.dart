import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/family_provider.dart';
import '../services/gemini_service.dart';

// ─────────────────────────────────────────────
// MODÈLES INTERNES
// ─────────────────────────────────────────────

class _AiEvalResult {
  final int aiNote;
  final String appreciation;
  final String conseil;
  final String pointFort;
  final String pointAmeliorer;
  final int parentNote;
  final String context;

  _AiEvalResult({
    required this.aiNote,
    required this.appreciation,
    required this.conseil,
    required this.pointFort,
    required this.pointAmeliorer,
    required this.parentNote,
    required this.context,
  });
}

// ─────────────────────────────────────────────
// ÉCRAN PRINCIPAL
// ─────────────────────────────────────────────

class SchoolNotesScreen extends StatefulWidget {
  final String childId;
  final String childName;
  final int childAge;

  const SchoolNotesScreen({
    super.key,
    required this.childId,
    required this.childName,
    required this.childAge,
  });

  @override
  State<SchoolNotesScreen> createState() => _SchoolNotesScreenState();
}

class _SchoolNotesScreenState extends State<SchoolNotesScreen>
    with TickerProviderStateMixin {
  List<Map<String, dynamic>> _notes = [];
  bool _loading = false;

  late AnimationController _notebookController;
  late Animation<double> _notebookAnimation;

  @override
  void initState() {
    super.initState();
    _notebookController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _notebookAnimation = CurvedAnimation(
      parent: _notebookController,
      curve: Curves.easeInOut,
    );
    _notebookController.forward();
    _loadNotes();
  }

  @override
  void dispose() {
    _notebookController.dispose();
    super.dispose();
  }

  Future<void> _loadNotes() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('school_notes_${widget.childId}');
    if (raw != null) {
      final List decoded = jsonDecode(raw);
      setState(() {
        _notes = decoded.cast<Map<String, dynamic>>();
      });
    }
  }

  Future<void> _saveNotes() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        'school_notes_${widget.childId}', jsonEncode(_notes));
  }

  void _startQuestionnaire() {
    final fp = Provider.of<FamilyProvider>(context, listen: false);
    final child = fp.children.firstWhere((c) => c.id == widget.childId);

    final bonusCount = fp.getBonusCountToday(widget.childId);
    final penaltyCount = fp.getPenaltyCountToday(widget.childId);
    final activePunishments = fp.getActivePunishmentsCount(widget.childId);
    final usableImmunities = fp.getUsableImmunitiesCount(widget.childId);
    final streakDays = child.streakDays ?? 0;
    final totalPoints = child.points;
    final recentReasons = fp.getRecentReasons(widget.childId);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AiQuestionnaireSheet(
        childName: widget.childName,
        childAge: widget.childAge,
        history: _notes,
        bonusCount: bonusCount,
        penaltyCount: penaltyCount,
        activePunishments: activePunishments,
        usableImmunities: usableImmunities,
        streakDays: streakDays,
        totalPoints: totalPoints,
        recentReasons: recentReasons,
        onComplete: (result) {
          Navigator.pop(context);
          _showResult(result);
        },
      ),
    );
  }

  void _showResult(_AiEvalResult result) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AiResultSheet(
        result: result,
        childName: widget.childName,
        onSave: () {
          Navigator.pop(context);
          _saveEvaluation(result);
        },
      ),
    );
  }

  Future<void> _saveEvaluation(_AiEvalResult result) async {
    final fp = Provider.of<FamilyProvider>(context, listen: false);
    final moyenne = ((result.aiNote + result.parentNote) / 2).round();

    final note = {
      'date': DateTime.now().toIso8601String().substring(0, 10),
      'aiNote': result.aiNote,
      'parentNote': result.parentNote,
      'moyenne': moyenne,
      'appreciation': result.appreciation,
      'conseil': result.conseil,
      'point_fort': result.pointFort,
      'point_ameliorer': result.pointAmeliorer,
      'context': result.context,
    };

    setState(() {
      _notes.insert(0, note);
    });
    await _saveNotes();

    final pointsGagnes = (moyenne / 2).round();
    fp.addPoints(widget.childId, pointsGagnes, "Conseil de classe familial");

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              '✅ Évaluation sauvegardée — Moyenne : $moyenne/20 (+$pointsGagnes pts)'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  void _deleteNote(int index) {
    setState(() {
      _notes.removeAt(index);
    });
    _saveNotes();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A1F),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Conseil de Classe — ${widget.childName}',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: FadeTransition(
        opacity: _notebookAnimation,
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: _notes.isEmpty ? _buildEmpty() : _buildNotesList(),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _loading ? null : _startQuestionnaire,
        backgroundColor: const Color(0xFF6C63FF),
        icon: _loading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
            : const Icon(Icons.psychology, color: Colors.white),
        label: Text(
          _loading ? 'Analyse en cours...' : 'Conseil du soir',
          style: const TextStyle(color: Colors.white),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    if (_notes.isEmpty) return const SizedBox.shrink();
    final last = _notes.first;
    final moyenne = last['moyenne'] ?? last['aiNote'] ?? 0;
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF6C63FF), Color(0xFF3F3D56)],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const Icon(Icons.star, color: Colors.amber, size: 40),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Dernière évaluation',
                    style: TextStyle(color: Colors.white70, fontSize: 12)),
                Text('$moyenne/20',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.bold)),
                Text(last['date'] ?? '',
                    style: const TextStyle(color: Colors.white60, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.menu_book, color: Colors.white24, size: 80),
          const SizedBox(height: 16),
          const Text(
            'Aucun conseil de classe encore',
            style: TextStyle(color: Colors.white54, fontSize: 16),
          ),
          const SizedBox(height: 8),
          const Text(
            'Appuie sur le bouton pour démarrer\nle conseil du soir !',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white38, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildNotesList() {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
      itemCount: _notes.length,
      itemBuilder: (context, index) {
        final note = _notes[index];
        final moyenne = note['moyenne'] ?? note['aiNote'] ?? 0;
        final color = moyenne >= 15
            ? Colors.green
            : moyenne >= 10
                ? Colors.orange
                : Colors.red;

        return Dismissible(
          key: Key('note_$index'),
          direction: DismissDirection.endToStart,
          onDismissed: (_) => _deleteNote(index),
          background: Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 20),
            decoration: BoxDecoration(
              color: Colors.red,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.delete, color: Colors.white),
          ),
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF16213E),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: color.withOpacity(0.4)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: color),
                      ),
                      child: Text(
                        '$moyenne/20',
                        style: TextStyle(
                            color: color, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (note['aiNote'] != null)
                      Text('IA: ${note['aiNote']}/20',
                          style: const TextStyle(
                              color: Colors.white54, fontSize: 12)),
                    const Spacer(),
                    Text(
                      note['date'] ?? '',
                      style: const TextStyle(
                          color: Colors.white38, fontSize: 12),
                    ),
                  ],
                ),
                if (note['appreciation'] != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    note['appreciation'],
                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                ],
                if (note['point_fort'] != null) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.thumb_up,
                          color: Colors.greenAccent, size: 14),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          note['point_fort'],
                          style: const TextStyle(
                              color: Colors.greenAccent, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ],
                if (note['point_ameliorer'] != null) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.arrow_upward,
                          color: Colors.orangeAccent, size: 14),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          note['point_ameliorer'],
                          style: const TextStyle(
                              color: Colors.orangeAccent, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ],
                if (note['conseil'] != null) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.lightbulb,
                          color: Colors.amberAccent, size: 14),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          note['conseil'],
                          style: const TextStyle(
                              color: Colors.amberAccent, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────
// QUESTIONNAIRE IA
// ─────────────────────────────────────────────

class _AiQuestionnaireSheet extends StatefulWidget {
  final String childName;
  final int childAge;
  final List<Map<String, dynamic>> history;
  final int bonusCount;
  final int penaltyCount;
  final int activePunishments;
  final int usableImmunities;
  final int streakDays;
  final int totalPoints;
  final List<String> recentReasons;
  final Function(_AiEvalResult) onComplete;

  const _AiQuestionnaireSheet({
    required this.childName,
    required this.childAge,
    required this.history,
    required this.bonusCount,
    required this.penaltyCount,
    required this.activePunishments,
    required this.usableImmunities,
    required this.streakDays,
    required this.totalPoints,
    required this.recentReasons,
    required this.onComplete,
  });

  @override
  State<_AiQuestionnaireSheet> createState() => _AiQuestionnaireSheetState();
}

class _AiQuestionnaireSheetState extends State<_AiQuestionnaireSheet> {
  int _step = 0;
  final Map<String, dynamic> _answers = {};
  int _parentNote = 10;
  bool _loading = false;

  final List<Map<String, dynamic>> _questions = [
    {
      'key': 'comportement_general',
      'question': 'Comment a été son comportement général aujourd\'hui ?',
      'icon': '😊',
      'choices': ['Excellent', 'Bien', 'Moyen', 'Insuffisant'],
    },
    {
      'key': 'humeur',
      'question': 'Quelle était son humeur durant la journée ?',
      'icon': '🌤️',
      'choices': ['Très bonne', 'Bonne', 'Moyenne', 'Mauvaise'],
    },
    {
      'key': 'attitude_freres_soeurs',
      'question': 'Comment s\'est-il/elle comporté(e) avec ses frères et sœurs ?',
      'icon': '👨‍👩‍👧‍👦',
      'choices': ['Très bien', 'Bien', 'Quelques conflits', 'Mal'],
    },
    {
      'key': 'actes_fraternels',
      'question': 'A-t-il/elle fait des actes fraternels ou d\'entraide ?',
      'icon': '🤝',
      'choices': ['Oui, plusieurs fois', 'Oui, une fois', 'Pas vraiment', 'Non'],
    },
    {
      'key': 'respect_parents',
      'question': 'Comment a-t-il/elle parlé et réagi envers ses parents ?',
      'icon': '👨‍👩‍👦',
      'choices': ['Très respectueux(se)', 'Respectueux(se)', 'Parfois irrespectueux(se)', 'Irrespectueux(se)'],
    },
    {
      'key': 'apprentissage',
      'question': 'A-t-il/elle appris ou partagé quelque chose de nouveau aujourd\'hui ?',
      'icon': '🧠',
      'choices': ['Oui, avec enthousiasme', 'Oui, un peu', 'Pas vraiment', 'Non'],
    },
    {
      'key': 'travail_scolaire',
      'question': 'Comment s\'est passé son travail scolaire / ses devoirs ?',
      'icon': '📚',
      'choices': ['Excellent', 'Bien fait', 'À encourager', 'Pas fait'],
    },
    {
      'key': 'serviabilite',
      'question': 'A-t-il/elle été serviable et aidé sans qu\'on le demande ?',
      'icon': '🙋',
      'choices': ['Très serviable', 'Un peu', 'Rarement', 'Pas du tout'],
    },
    {
      'key': 'rangement',
      'question': 'A-t-il/elle rangé ses affaires et participé aux tâches ?',
      'icon': '🧹',
      'choices': ['Oui, spontanément', 'Après demande', 'Avec difficulté', 'Non'],
    },
    {
      'key': 'langage',
      'question': 'A-t-il/elle utilisé un langage correct et respectueux ?',
      'icon': '💬',
      'choices': ['Toujours', 'Souvent', 'Parfois', 'Rarement'],
    },
    {
      'key': 'autonomie',
      'question': 'A-t-il/elle fait preuve d\'autonomie et de responsabilité ?',
      'icon': '⭐',
      'choices': ['Très autonome', 'Assez autonome', 'A besoin d\'aide', 'Pas autonome'],
    },
    {
      'key': 'efforts',
      'question': 'A-t-il/elle fourni des efforts dans ce qu\'il/elle a fait ?',
      'icon': '💪',
      'choices': ['Beaucoup d\'efforts', 'Des efforts', 'Peu d\'efforts', 'Aucun effort'],
    },
    {
      'key': 'repetitions',
      'question': 'A-t-on dû répéter les demandes plusieurs fois ?',
      'icon': '🔁',
      'choices': ['Non, jamais', 'Une ou deux fois', 'Souvent', 'Tout le temps'],
    },
    {
      'key': 'moment_special',
      'question': 'Y a-t-il eu un moment positif ou spécial à souligner ?',
      'icon': '✨',
      'choices': ['Oui, remarquable', 'Oui, agréable', 'Rien de particulier', 'Non'],
    },
  ];

  String get _contextLabel {
    final comportement = _answers['comportement_general'] ?? '';
    final humeur = _answers['humeur'] ?? '';
    return 'Comportement: $comportement, Humeur: $humeur';
  }

  Future<void> _submitToGemini() async {
    setState(() => _loading = true);
    try {
      final result = await GeminiService.generateAppreciation(
        childName: widget.childName,
        context: _contextLabel,
        answers: _answers,
        history: widget.history,
        bonusCount: widget.bonusCount,
        penaltyCount: widget.penaltyCount,
        activePunishments: widget.activePunishments,
        usableImmunities: widget.usableImmunities,
        streakDays: widget.streakDays,
        totalPoints: widget.totalPoints,
        recentReasons: widget.recentReasons,
      );

      final json = jsonDecode(result);
      final aiNote = (json['note'] as num).toInt();
      final appreciation = json['appreciation'] as String? ?? '';
      final conseil = json['conseil'] as String? ?? '';
      final pointFort = json['point_fort'] as String? ?? '';
      final pointAmeliorer = json['point_ameliorer'] as String? ?? '';

      if (mounted) {
        widget.onComplete(_AiEvalResult(
          aiNote: aiNote,
          appreciation: appreciation,
          conseil: conseil,
          pointFort: pointFort,
          pointAmeliorer: pointAmeliorer,
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
    final isLastStep = _step == _questions.length;

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: Color(0xFF0A0A1F),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                const Icon(Icons.family_restroom,
                    color: Color(0xFF6C63FF), size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Conseil de classe — ${widget.childName}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          LinearProgressIndicator(
            value: _step / (_questions.length + 1),
            backgroundColor: Colors.white12,
            valueColor:
                const AlwaysStoppedAnimation<Color>(Color(0xFF6C63FF)),
          ),
          Expanded(
            child: isLastStep
                ? _buildParentNoteStep()
                : _buildQuestionStep(_questions[_step]),
          ),
        ],
      ),
    );
  }

  Widget _buildQuestionStep(Map<String, dynamic> q) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Question ${_step + 1} / ${_questions.length}',
            style: const TextStyle(color: Colors.white38, fontSize: 13),
          ),
          const SizedBox(height: 16),
          Text(
            '${q['icon']}  ${q['question']}',
            style: const TextStyle(
                color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 32),
          ...List.generate((q['choices'] as List).length, (i) {
            final choice = q['choices'][i] as String;
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    _answers[q['key']] = choice;
                    _step++;
                  });
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF16213E),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFF6C63FF).withOpacity(0.4)),
                  ),
                  child: Text(
                    choice,
                    style: const TextStyle(color: Colors.white, fontSize: 16),
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildParentNoteStep() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '⭐ Votre note parentale',
            style: TextStyle(
                color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Donnez votre propre note sur 20 pour cette journée.',
            style: TextStyle(color: Colors.white54, fontSize: 14),
          ),
          const SizedBox(height: 32),
          Center(
            child: Text(
              '$_parentNote / 20',
              style: const TextStyle(
                  color: Color(0xFF6C63FF),
                  fontSize: 48,
                  fontWeight: FontWeight.bold),
            ),
          ),
          Slider(
            value: _parentNote.toDouble(),
            min: 0,
            max: 20,
            divisions: 20,
            activeColor: const Color(0xFF6C63FF),
            inactiveColor: Colors.white12,
            onChanged: (v) => setState(() => _parentNote = v.round()),
          ),
          const SizedBox(height: 16),
          if (widget.bonusCount > 0 || widget.penaltyCount > 0 || widget.activePunishments > 0)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF16213E),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('📊 Données du jour prises en compte :',
                      style: TextStyle(color: Colors.white70, fontSize: 13)),
                  const SizedBox(height: 8),
                  if (widget.bonusCount > 0)
                    Text('✅ Bonus : ${widget.bonusCount}',
                        style: const TextStyle(
                            color: Colors.greenAccent, fontSize: 13)),
                  if (widget.penaltyCount > 0)
                    Text('❌ Pénalités : ${widget.penaltyCount}',
                        style: const TextStyle(
                            color: Colors.redAccent, fontSize: 13)),
                  if (widget.activePunishments > 0)
                    Text('⚠️ Punitions actives : ${widget.activePunishments}',
                        style: const TextStyle(
                            color: Colors.orangeAccent, fontSize: 13)),
                  if (widget.usableImmunities > 0)
                    Text('🛡️ Immunités : ${widget.usableImmunities}',
                        style: const TextStyle(
                            color: Colors.blueAccent, fontSize: 13)),
                  if (widget.streakDays > 1)
                    Text('🔥 Streak : ${widget.streakDays} jours',
                        style: const TextStyle(
                            color: Colors.amberAccent, fontSize: 13)),
                ],
              ),
            ),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _loading ? null : _submitToGemini,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6C63FF),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              child: _loading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text(
                      '🎓 Lancer l\'analyse IA',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// RÉSULTAT IA
// ─────────────────────────────────────────────

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
    final moyenne = ((result.aiNote + result.parentNote) / 2).round();
    final color = moyenne >= 15
        ? Colors.green
        : moyenne >= 10
            ? Colors.orange
            : Colors.red;

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: Color(0xFF0A0A1F),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Column(
                      children: [
                        const Icon(Icons.school, color: Color(0xFF6C63FF), size: 48),
                        const SizedBox(height: 8),
                        Text(
                          'Bulletin de $childName',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 24, vertical: 12),
                          decoration: BoxDecoration(
                            color: color.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: color),
                          ),
                          child: Text(
                            '$moyenne / 20',
                            style: TextStyle(
                                color: color,
                                fontSize: 40,
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'IA : ${result.aiNote}/20  •  Parent : ${result.parentNote}/20',
                          style: const TextStyle(
                              color: Colors.white54, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  _buildSection(
                    icon: Icons.comment,
                    color: Colors.blueAccent,
                    title: 'Appréciation',
                    content: result.appreciation,
                  ),
                  if (result.pointFort.isNotEmpty)
                    _buildSection(
                      icon: Icons.thumb_up,
                      color: Colors.greenAccent,
                      title: 'Point fort du jour',
                      content: result.pointFort,
                    ),
                  if (result.pointAmeliorer.isNotEmpty)
                    _buildSection(
                      icon: Icons.trending_up,
                      color: Colors.orangeAccent,
                      title: 'À améliorer',
                      content: result.pointAmeliorer,
                    ),
                  if (result.conseil.isNotEmpty)
                    _buildSection(
                      icon: Icons.lightbulb,
                      color: Colors.amberAccent,
                      title: 'Conseil pour demain',
                      content: result.conseil,
                    ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: onSave,
                icon: const Icon(Icons.save, color: Colors.white),
                label: const Text(
                  'Sauvegarder le bulletin',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6C63FF),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection({
    required IconData icon,
    required Color color,
    required String title,
    required String content,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF16213E),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(width: 8),
              Text(title,
                  style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.bold,
                      fontSize: 14)),
            ],
          ),
          const SizedBox(height: 8),
          Text(content,
              style: const TextStyle(color: Colors.white70, fontSize: 14)),
        ],
      ),
    );
  }
}
