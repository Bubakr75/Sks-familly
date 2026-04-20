import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/child_model.dart';
import '../services/gemini_service.dart';
import '../providers/family_provider.dart';

class MultiChildEvaluationScreen extends StatefulWidget {
  const MultiChildEvaluationScreen({Key? key}) : super(key: key);

  @override
  State<MultiChildEvaluationScreen> createState() => _MultiChildEvaluationScreenState();
}

class _MultiChildEvaluationScreenState extends State<MultiChildEvaluationScreen> {
  int _step = 0;
  final Set<String> _selectedIds = {};
  final Map<String, double> _parentNotes = {};
  bool _evaluating = false;
  Map<String, _AiEvalResult> _results = {};
  int _currentQuestion = 0;

  final List<Map<String, dynamic>> _questions = GeminiService.generateQuizQuestions(theme: '', age: 10);
  // answersPerChild[childId][questionIndex] = answerIndex
  final Map<String, List<int?>> _answersPerChild = {};

  List<ChildModel> get _selectedChildren {
    final fp = context.read<FamilyProvider>();
    return fp.children.where((c) => _selectedIds.contains(c.id)).toList();
  }

  bool get _currentQuestionAnswered {
    for (final child in _selectedChildren) {
      final answers = _answersPerChild[child.id] ?? [];
      if (answers.length <= _currentQuestion || answers[_currentQuestion] == null) return false;
    }
    return true;
  }

  bool get _allAnswered {
    for (final child in _selectedChildren) {
      final answers = _answersPerChild[child.id] ?? [];
      if (answers.length < _questions.length) return false;
      if (answers.any((a) => a == null)) return false;
    }
    return true;
  }

  void _startEvaluation() {
    for (final child in _selectedChildren) {
      _answersPerChild[child.id] = List.filled(_questions.length, null);
      _parentNotes[child.id] = 10.0;
    }
    setState(() { _currentQuestion = 0; _step = 1; });
  }

  void _setAnswer(String childId, int questionIndex, int answerIndex) {
    setState(() {
      if (_answersPerChild[childId] == null) {
        _answersPerChild[childId] = List.filled(_questions.length, null);
      }
      _answersPerChild[childId]![questionIndex] = answerIndex;
    });
  }

  Future<void> _submitEvaluation() async {
    if (_evaluating) return;
    setState(() => _evaluating = true);

    final children = _selectedChildren;
    final names = children.map((c) => c.name).toList();

    final Map<String, dynamic> allAnswers = {};
    for (final child in children) {
      final answers = _answersPerChild[child.id] ?? [];
      final Map<String, dynamic> childAnswers = {};
      for (int i = 0; i < _questions.length; i++) {
        final q = _questions[i];
        final answerIndex = i < answers.length ? (answers[i] ?? 0) : 0;
        final answersList = List<String>.from(q['answers'] ?? []);
        childAnswers['q' + i.toString()] = answerIndex < answersList.length ? answersList[answerIndex] : '';
      }
      allAnswers[child.name] = childAnswers;
    }

    try {
      final parsed = await GeminiService.generateGroupAppreciation(
        childNames: names,
        context: 'Evaluation comportement enfants a la maison',
        answers: allAnswers,
      );

      final List<dynamic> evaluations = parsed['evaluations'] ?? [];
      final Map<String, _AiEvalResult> results = {};

      for (final child in children) {
        Map<String, dynamic> data = {};
        for (final e in evaluations) {
          final nom = (e['nom'] ?? '').toString().toLowerCase().trim();
          final childName = child.name.toLowerCase().trim();
          if (nom == childName || nom.contains(childName) || childName.contains(nom)) {
            data = Map<String, dynamic>.from(e);
            break;
          }
        }
        results[child.id] = _AiEvalResult(
          aiNote: data.isEmpty ? -1 : (data['note'] ?? -1).toInt(),
          appreciation: data['appreciation'] ?? '',
          conseil: data['conseil'] ?? '',
          pointFort: data['point_fort'] ?? '',
          pointAmeliorer: data['point_ameliorer'] ?? '',
          parentNote: (_parentNotes[child.id] ?? 10).round(),
        );
      }
      setState(() { _results = results; _evaluating = false; _step = 3; });
    } catch (e) {
      print('EVAL_ERROR: ' + e.toString());
      setState(() => _evaluating = false);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: ' + e.toString())));
    }
  }

  void _saveAll() {
    final fp = context.read<FamilyProvider>();
    for (final child in _selectedChildren) {
      final result = _results[child.id];
      if (result == null) continue;
      final moyenne = ((result.aiNote + result.parentNote) / 2).round();
      fp.addNote(child.id, 'Bulletin: IA=' + result.aiNote.toString() + '/20 Parent=' + result.parentNote.toString() + '/20 Moy=' + moyenne.toString() + '/20 | ' + result.appreciation);
    }
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FF),
      appBar: AppBar(
        title: Text(_step == 0 ? 'Evaluation groupe' : _step == 1 ? 'Question ' + (_currentQuestion + 1).toString() + '/' + _questions.length.toString() : _step == 2 ? 'Notes parentales' : 'Bulletins'),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _step == 0 ? _buildSelection() : _step == 1 ? _buildQuestionnaire() : _step == 2 ? _buildParentNotes() : _buildResults(),
    );
  }

  // ─── ETAPE 0 : Selection ─────────────────────────────────────────────
  Widget _buildSelection() {
    final fp = context.watch<FamilyProvider>();
    final children = fp.children;
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: const BoxDecoration(
            color: Colors.indigo,
            borderRadius: BorderRadius.only(bottomLeft: Radius.circular(24), bottomRight: Radius.circular(24)),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Qui evaluer ?', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(_selectedIds.isEmpty ? 'Selectionnez au moins un enfant' : _selectedIds.length.toString() + ' enfant(s) selectionne(s)', style: TextStyle(color: Colors.white.withOpacity(0.8))),
          ]),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: children.length,
            itemBuilder: (ctx, i) {
              final child = children[i];
              final selected = _selectedIds.contains(child.id);
              return GestureDetector(
                onTap: () => setState(() { if (selected) _selectedIds.remove(child.id); else _selectedIds.add(child.id); }),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: selected ? Colors.indigo.withOpacity(0.1) : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: selected ? Colors.indigo : Colors.grey.shade200, width: selected ? 2 : 1),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 2))],
                  ),
                  child: Row(children: [
                    CircleAvatar(
                      backgroundColor: selected ? Colors.indigo : Colors.grey.shade200,
                      child: Text(child.name[0], style: TextStyle(color: selected ? Colors.white : Colors.grey, fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(child.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      Text(child.points.toString() + ' pts • Niveau ' + child.level.toString(), style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                    ])),
                    if (selected) const Icon(Icons.check_circle, color: Colors.indigo),
                  ]),
                ),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _selectedIds.isNotEmpty ? Colors.indigo : Colors.grey,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 0,
              ),
              onPressed: _selectedIds.isNotEmpty ? _startEvaluation : null,
              child: Text('Commencer l evaluation (' + _selectedIds.length.toString() + ' enfant(s))', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ),
        ),
      ],
    );
  }

  // ─── ETAPE 1 : Questionnaire ─────────────────────────────────────────
  Widget _buildQuestionnaire() {
    final children = _selectedChildren;
    final q = _questions[_currentQuestion];
    final qAnswers = List<String>.from(q['answers'] ?? []);
    final progress = (_currentQuestion + 1) / _questions.length;

    return Column(
      children: [
        // Barre de progression
        Container(
          color: Colors.indigo,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: progress,
                backgroundColor: Colors.white.withOpacity(0.3),
                valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                minHeight: 6,
              ),
            ),
          ]),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // Question
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 12)],
                ),
                child: Text(q['question'] ?? '', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 20),
              // Enfants avec leurs reponses
              ...children.map((child) {
                final selectedAnswer = (_answersPerChild[child.id] ?? List.filled(_questions.length, null))[_currentQuestion];
                return Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8)],
                  ),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    // En-tete enfant
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.indigo.withOpacity(0.08),
                        borderRadius: const BorderRadius.only(topLeft: Radius.circular(16), topRight: Radius.circular(16)),
                      ),
                      child: Row(children: [
                        CircleAvatar(radius: 14, backgroundColor: Colors.indigo, child: Text(child.name[0], style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold))),
                        const SizedBox(width: 8),
                        Text(child.name, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.indigo)),
                        if (selectedAnswer != null) ...[
                          const Spacer(),
                          const Icon(Icons.check_circle, color: Colors.green, size: 18),
                        ],
                      ]),
                    ),
                    // Reponses
                    Padding(
                      padding: const EdgeInsets.all(8),
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: qAnswers.asMap().entries.map((ae) {
                          final isSelected = selectedAnswer == ae.key;
                          return GestureDetector(
                            onTap: () => _setAnswer(child.id, _currentQuestion, ae.key),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              decoration: BoxDecoration(
                                color: isSelected ? Colors.indigo : Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: isSelected ? Colors.indigo : Colors.grey.shade300),
                              ),
                              child: Text(ae.value, style: TextStyle(color: isSelected ? Colors.white : Colors.black87, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal, fontSize: 13)),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ]),
                );
              }),
            ]),
          ),
        ),
        // Navigation
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(children: [
            if (_currentQuestion > 0)
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  onPressed: () => setState(() => _currentQuestion--),
                  child: const Text('Precedent'),
                ),
              ),
            if (_currentQuestion > 0) const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _currentQuestionAnswered ? Colors.indigo : Colors.grey,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                onPressed: _currentQuestionAnswered ? () {
                  if (_currentQuestion < _questions.length - 1) {
                    setState(() => _currentQuestion++);
                  } else {
                    setState(() => _step = 2);
                  }
                } : null,
                child: Text(_currentQuestion < _questions.length - 1 ? 'Question suivante' : 'Terminer le questionnaire', style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ]),
        ),
      ],
    );
  }

  // ─── ETAPE 2 : Notes parentales ──────────────────────────────────────
  Widget _buildParentNotes() {
    final children = _selectedChildren;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Note parentale', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        const Text('Donnez une note individuelle a chaque enfant', style: TextStyle(color: Colors.grey)),
        const SizedBox(height: 20),
        ...children.map((child) {
          final note = _parentNotes[child.id] ?? 10.0;
          return Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8)],
            ),
            child: Column(children: [
              Row(children: [
                CircleAvatar(backgroundColor: Colors.indigo.withOpacity(0.1), child: Text(child.name[0], style: const TextStyle(color: Colors.indigo, fontWeight: FontWeight.bold))),
                const SizedBox(width: 12),
                Expanded(child: Text(child.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(color: Colors.indigo.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
                  child: Text(note.round().toString() + '/20', style: const TextStyle(color: Colors.indigo, fontWeight: FontWeight.bold, fontSize: 18)),
                ),
              ]),
              const SizedBox(height: 12),
              Slider(
                value: note,
                min: 0,
                max: 20,
                divisions: 20,
                activeColor: Colors.indigo,
                onChanged: (v) => setState(() => _parentNotes[child.id] = v),
              ),
            ]),
          );
        }),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.indigo,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              elevation: 0,
            ),
            onPressed: _evaluating ? null : _submitEvaluation,
            child: _evaluating
                ? const Row(mainAxisAlignment: MainAxisAlignment.center, children: [CircularProgressIndicator(color: Colors.white, strokeWidth: 2), SizedBox(width: 12), Text('Evaluation IA en cours...')])
                : const Text('Generer les bulletins IA', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ),
        ),
      ]),
    );
  }

  // ─── ETAPE 3 : Resultats ─────────────────────────────────────────────
  Widget _buildResults() {
    final children = _selectedChildren;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(children: [
        const Text('Bulletins', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        ...children.map((child) {
          final result = _results[child.id];
          if (result == null) return const SizedBox.shrink();
          final moyenne = ((result.aiNote + result.parentNote) / 2).round();
          final color = moyenne >= 16 ? Colors.green : moyenne >= 12 ? Colors.orange : Colors.red;
          return Container(
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 12)],
            ),
            child: Column(children: [
              // En-tete
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [color.withOpacity(0.7), color], begin: Alignment.topLeft, end: Alignment.bottomRight),
                  borderRadius: const BorderRadius.only(topLeft: Radius.circular(20), topRight: Radius.circular(20)),
                ),
                child: Row(children: [
                  CircleAvatar(backgroundColor: Colors.white.withOpacity(0.3), child: Text(child.name[0], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                  const SizedBox(width: 12),
                  Expanded(child: Text(child.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18))),
                  Text(moyenne.toString() + '/20', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 28)),
                ]),
              ),
              // Notes
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(children: [
                  Row(children: [
                    Expanded(child: _noteBox('Note IA', result.aiNote, Colors.blue)),
                    const SizedBox(width: 12),
                    Expanded(child: _noteBox('Note Parent', result.parentNote, Colors.purple)),
                  ]),
                  const SizedBox(height: 16),
                  if (result.appreciation.isNotEmpty) _infoTile('💬 Appreciation', result.appreciation, Colors.blue),
                  if (result.pointFort.isNotEmpty) _infoTile('💪 Point fort', result.pointFort, Colors.green),
                  if (result.pointAmeliorer.isNotEmpty) _infoTile('📈 A ameliorer', result.pointAmeliorer, Colors.orange),
                  if (result.conseil.isNotEmpty) _infoTile('💡 Conseil', result.conseil, Colors.purple),
                ]),
              ),
            ]),
          );
        }),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.indigo,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              elevation: 0,
            ),
            icon: const Icon(Icons.save),
            label: const Text('Enregistrer tous les bulletins', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            onPressed: _saveAll,
          ),
        ),
      ]),
    );
  }

  Widget _noteBox(String label, int note, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
      child: Column(children: [
        Text(label, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12)),
        const SizedBox(height: 4),
        Text(note.toString() + '/20', style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 20)),
      ]),
    );
  }

  Widget _infoTile(String title, String content, Color color) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: color.withOpacity(0.06), borderRadius: BorderRadius.circular(12), border: Border.all(color: color.withOpacity(0.2))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12)),
        const SizedBox(height: 4),
        Text(content, style: const TextStyle(fontSize: 14)),
      ]),
    );
  }
}

class _AiEvalResult {
  final int aiNote;
  final String appreciation;
  final String conseil;
  final String pointFort;
  final String pointAmeliorer;
  final int parentNote;

  const _AiEvalResult({
    required this.aiNote,
    required this.appreciation,
    required this.conseil,
    required this.pointFort,
    required this.pointAmeliorer,
    required this.parentNote,
  });
}
