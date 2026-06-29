import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/child_model.dart';
import '../services/gemini_service.dart';
import '../providers/family_provider.dart';
import '../widgets/aurora_background.dart';

class MultiChildEvaluationScreen extends StatefulWidget {
  const MultiChildEvaluationScreen({Key? key}) : super(key: key);
  @override
  State<MultiChildEvaluationScreen> createState() => _MultiChildEvaluationScreenState();
}

class _MultiChildEvaluationScreenState extends State<MultiChildEvaluationScreen> with TickerProviderStateMixin {
  int _step = 0;
  final Set<String> _selectedIds = {};
  final Map<String, double> _parentNotes = {};
  bool _evaluating = false;
  Map<String, _AiEvalResult> _results = {};
  int _currentQuestion = 0;
  final List<Map<String, dynamic>> _questions = GeminiService.generateQuizQuestions(theme: '', age: 10);
  final Map<String, List<int?>> _answersPerChild = {};

  static const _cardBg = Color(0xFF1A2744);
  static const _accent = Color(0xFF6C63FF);
  static const _accentLight = Color(0xFF9D97FF);

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
      setState(() => _evaluating = false);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: ' + e.toString()), backgroundColor: Colors.redAccent));
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
    return AuroraBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
            onPressed: () => _step == 0 ? Navigator.pop(context) : setState(() => _step--),
          ),
          title: Text(
            _step == 0 ? 'Notes' : _step == 1 ? 'Question ${_currentQuestion + 1}/${_questions.length}' : _step == 2 ? 'Notes parentales' : 'Bulletins',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          actions: [
            if (_step > 0 && _step < 3)
              Container(
                margin: const EdgeInsets.only(right: 16),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(color: _accent.withOpacity(0.2), borderRadius: BorderRadius.circular(20), border: Border.all(color: _accent.withOpacity(0.5))),
                child: Text('Étape ${_step}/3', style: const TextStyle(color: _accentLight, fontSize: 12, fontWeight: FontWeight.bold)),
              ),
          ],
        ),
        body: AnimatedSwitcher(
          duration: const Duration(milliseconds: 350),
          transitionBuilder: (child, anim) => SlideTransition(
            position: Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero).animate(anim),
            child: child,
          ),
          child: _step == 0 ? _buildSelection() : _step == 1 ? _buildQuestionnaire() : _step == 2 ? _buildParentNotes() : _buildResults(),
        ),
      ),
    );
  }

  Widget _buildSelection() {
    final fp = context.watch<FamilyProvider>();
    final children = fp.children;
    return Column(
      key: const ValueKey(0),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Qui évaluer ?', style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(
              _selectedIds.isEmpty ? 'Sélectionnez au moins un enfant' : '${_selectedIds.length} enfant(s) sélectionné(s)',
              style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 14),
            ),
          ]),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: children.length,
            itemBuilder: (ctx, i) {
              final child = children[i];
              final selected = _selectedIds.contains(child.id);
              final colors = [const Color(0xFF6C63FF), const Color(0xFFFF6584), const Color(0xFF43E97B), const Color(0xFFFA8231), const Color(0xFF00D2FF)];
              final color = colors[i % colors.length];
              return GestureDetector(
                onTap: () => setState(() { if (selected) _selectedIds.remove(child.id); else _selectedIds.add(child.id); }),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: selected ? color.withOpacity(0.15) : _cardBg,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: selected ? color : Colors.white.withOpacity(0.08), width: selected ? 2 : 1),
                    boxShadow: selected ? [BoxShadow(color: color.withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 4))] : [],
                  ),
                  child: Row(children: [
                    Container(
                      width: 48, height: 48,
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.2),
                        shape: BoxShape.circle,
                        border: Border.all(color: color.withOpacity(0.5)),
                      ),
                      child: Center(child: Text(
                        child.avatar.isNotEmpty ? child.avatar : child.name[0],
                        style: TextStyle(fontSize: child.avatar.isNotEmpty ? 22 : 18, fontWeight: FontWeight.bold, color: color),
                      )),
                    ),
                    const SizedBox(width: 14),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(child.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                      Text('${child.points} pts • Niveau ${child.level}', style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12)),
                    ])),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      width: 28, height: 28,
                      decoration: BoxDecoration(
                        color: selected ? color : Colors.transparent,
                        shape: BoxShape.circle,
                        border: Border.all(color: selected ? color : Colors.white30, width: 2),
                      ),
                      child: selected ? const Icon(Icons.check, color: Colors.white, size: 16) : null,
                    ),
                  ]),
                ),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(20),
          child: SizedBox(
            width: double.infinity, height: 56,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _selectedIds.isNotEmpty ? _accent : Colors.white12,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: _selectedIds.isNotEmpty ? 8 : 0,
                shadowColor: _accent.withOpacity(0.5),
              ),
              onPressed: _selectedIds.isNotEmpty ? _startEvaluation : null,
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                const Icon(Icons.play_arrow_rounded, size: 22),
                const SizedBox(width: 8),
                Text('Commencer (${_selectedIds.length} enfant(s))', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ]),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildQuestionnaire() {
    final children = _selectedChildren;
    final q = _questions[_currentQuestion];
    final qAnswers = List<String>.from(q['answers'] ?? []);
    final progress = (_currentQuestion + 1) / _questions.length;

    return Column(
      key: const ValueKey(1),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: Column(children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text('${_currentQuestion + 1} / ${_questions.length}', style: const TextStyle(color: Colors.white60, fontSize: 13)),
              Text('${(progress * 100).round()}%', style: const TextStyle(color: _accentLight, fontSize: 13, fontWeight: FontWeight.bold)),
            ]),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: progress,
                backgroundColor: Colors.white.withOpacity(0.1),
                valueColor: const AlwaysStoppedAnimation<Color>(_accent),
                minHeight: 6,
              ),
            ),
          ]),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: _accent.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: _accent.withOpacity(0.3)),
                ),
                child: Row(children: [
                  Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(color: _accent, shape: BoxShape.circle),
                    child: Center(child: Text('Q${_currentQuestion + 1}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12))),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Text(q['question'] ?? '', style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600))),
                ]),
              ),
              const SizedBox(height: 16),
              ...children.map((child) {
                final selectedAnswer = (_answersPerChild[child.id] ?? List.filled(_questions.length, null))[_currentQuestion];
                final colors = [const Color(0xFF6C63FF), const Color(0xFFFF6584), const Color(0xFF43E97B), const Color(0xFFFA8231), const Color(0xFF00D2FF)];
                final color = colors[children.indexOf(child) % colors.length];
                return Container(
                  margin: const EdgeInsets.only(bottom: 14),
                  decoration: BoxDecoration(
                    color: _cardBg,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: selectedAnswer != null ? color.withOpacity(0.4) : Colors.white.withOpacity(0.08)),
                  ),
                  child: Column(children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.1),
                        borderRadius: const BorderRadius.only(topLeft: Radius.circular(18), topRight: Radius.circular(18)),
                      ),
                      child: Row(children: [
                        CircleAvatar(radius: 14, backgroundColor: color.withOpacity(0.3), child: Text(child.name[0], style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold))),
                        const SizedBox(width: 8),
                        Text(child.name, style: TextStyle(color: color, fontWeight: FontWeight.bold)),
                        if (selectedAnswer != null) ...[
                          const Spacer(),
                          Icon(Icons.check_circle, color: color, size: 18),
                        ],
                      ]),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(10),
                      child: Wrap(
                        spacing: 8, runSpacing: 8,
                        children: qAnswers.asMap().entries.map((ae) {
                          final isSelected = selectedAnswer == ae.key;
                          return GestureDetector(
                            onTap: () => _setAnswer(child.id, _currentQuestion, ae.key),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              decoration: BoxDecoration(
                                color: isSelected ? color : Colors.white.withOpacity(0.05),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: isSelected ? color : Colors.white24),
                                boxShadow: isSelected ? [BoxShadow(color: color.withOpacity(0.4), blurRadius: 8)] : [],
                              ),
                              child: Text(ae.value, style: TextStyle(color: isSelected ? Colors.white : Colors.white60, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal, fontSize: 13)),
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
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(children: [
            if (_currentQuestion > 0)
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    side: const BorderSide(color: Colors.white24),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: () => setState(() => _currentQuestion--),
                  child: const Text('Précédent', style: TextStyle(color: Colors.white70)),
                ),
              ),
            if (_currentQuestion > 0) const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _currentQuestionAnswered ? _accent : Colors.white12,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: _currentQuestionAnswered ? 6 : 0,
                  shadowColor: _accent.withOpacity(0.5),
                ),
                onPressed: _currentQuestionAnswered ? () {
                  if (_currentQuestion < _questions.length - 1) {
                    setState(() => _currentQuestion++);
                  } else {
                    setState(() => _step = 2);
                  }
                } : null,
                child: Text(
                  _currentQuestion < _questions.length - 1 ? 'Question suivante →' : 'Terminer →',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ]),
        ),
      ],
    );
  }

  Widget _buildParentNotes() {
    final children = _selectedChildren;
    return Column(
      key: const ValueKey(2),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Notes parentales', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text('Donnez une note individuelle à chaque enfant', style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 13)),
          ]),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: children.map((child) {
              final note = _parentNotes[child.id] ?? 10.0;
              final colors = [const Color(0xFF6C63FF), const Color(0xFFFF6584), const Color(0xFF43E97B), const Color(0xFFFA8231), const Color(0xFF00D2FF)];
              final color = colors[children.indexOf(child) % colors.length];
              final noteColor = note >= 16 ? const Color(0xFF43E97B) : note >= 12 ? const Color(0xFFFFD93D) : const Color(0xFFFF6584);
              return Container(
                margin: const EdgeInsets.only(bottom: 14),
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: _cardBg,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: color.withOpacity(0.2)),
                ),
                child: Column(children: [
                  Row(children: [
                    CircleAvatar(
                      radius: 22,
                      backgroundColor: color.withOpacity(0.2),
                      child: Text(child.avatar.isNotEmpty ? child.avatar : child.name[0], style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: child.avatar.isNotEmpty ? 18 : 16)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: Text(child.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16))),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(color: noteColor.withOpacity(0.15), borderRadius: BorderRadius.circular(12), border: Border.all(color: noteColor.withOpacity(0.4))),
                      child: Text('${note.round()}/20', style: TextStyle(color: noteColor, fontWeight: FontWeight.bold, fontSize: 20)),
                    ),
                  ]),
                  const SizedBox(height: 12),
                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      activeTrackColor: color,
                      inactiveTrackColor: color.withOpacity(0.15),
                      thumbColor: color,
                      overlayColor: color.withOpacity(0.2),
                    ),
                    child: Slider(value: note, min: 0, max: 20, divisions: 20, onChanged: (v) => setState(() => _parentNotes[child.id] = v)),
                  ),
                ]),
              );
            }).toList(),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(20),
          child: SizedBox(
            width: double.infinity, height: 56,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _accent, foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 8, shadowColor: _accent.withOpacity(0.5),
              ),
              onPressed: _evaluating ? null : _submitEvaluation,
              child: _evaluating
                  ? const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)),
                      SizedBox(width: 12),
                      Text('Analyse IA en cours...', style: TextStyle(fontWeight: FontWeight.bold)),
                    ])
                  : const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Icon(Icons.auto_awesome, size: 20),
                      SizedBox(width: 8),
                      Text('Générer les bulletins IA', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ]),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildResults() {
    final children = _selectedChildren;
    return Column(
      key: const ValueKey(3),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: Row(children: [
            const Text('Bulletins', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
            const Spacer(),
            Text('${children.length} enfant(s)', style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 13)),
          ]),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: children.map((child) {
              final result = _results[child.id];
              if (result == null) return const SizedBox.shrink();
              final moyenne = result.aiNote >= 0 ? ((result.aiNote + result.parentNote) / 2).round() : result.parentNote;
              final noteColor = moyenne >= 16 ? const Color(0xFF43E97B) : moyenne >= 12 ? const Color(0xFFFFD93D) : const Color(0xFFFF6584);
              final colors = [const Color(0xFF6C63FF), const Color(0xFFFF6584), const Color(0xFF43E97B), const Color(0xFFFA8231), const Color(0xFF00D2FF)];
              final color = colors[children.indexOf(child) % colors.length];
              return Container(
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: _cardBg,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: color.withOpacity(0.2)),
                  boxShadow: [BoxShadow(color: color.withOpacity(0.1), blurRadius: 16, offset: const Offset(0, 4))],
                ),
                child: Column(children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [color.withOpacity(0.3), color.withOpacity(0.1)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                      borderRadius: const BorderRadius.only(topLeft: Radius.circular(24), topRight: Radius.circular(24)),
                    ),
                    child: Row(children: [
                      CircleAvatar(
                        radius: 24, backgroundColor: color.withOpacity(0.3),
                        child: Text(child.avatar.isNotEmpty ? child.avatar : child.name[0], style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: child.avatar.isNotEmpty ? 20 : 18)),
                      ),
                      const SizedBox(width: 14),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(child.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                        Text('${child.points} pts • Niveau ${child.level}', style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12)),
                      ])),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(color: noteColor.withOpacity(0.2), borderRadius: BorderRadius.circular(14), border: Border.all(color: noteColor.withOpacity(0.5))),
                        child: Text('$moyenne/20', style: TextStyle(color: noteColor, fontWeight: FontWeight.bold, fontSize: 26)),
                      ),
                    ]),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(children: [
                      Row(children: [
                        Expanded(child: _noteBox('Note IA', result.aiNote >= 0 ? result.aiNote : '—', Colors.blue)),
                        const SizedBox(width: 12),
                        Expanded(child: _noteBox('Note Parent', result.parentNote, Colors.purple)),
                      ]),
                      const SizedBox(height: 14),
                      if (result.appreciation.isNotEmpty) _infoTile('💬', 'Appréciation', result.appreciation, Colors.blue),
                      if (result.pointFort.isNotEmpty) _infoTile('💪', 'Point fort', result.pointFort, const Color(0xFF43E97B)),
                      if (result.pointAmeliorer.isNotEmpty) _infoTile('📈', 'À améliorer', result.pointAmeliorer, const Color(0xFFFFD93D)),
                      if (result.conseil.isNotEmpty) _infoTile('💡', 'Conseil', result.conseil, Colors.purple),
                    ]),
                  ),
                ]),
              );
            }).toList(),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(20),
          child: SizedBox(
            width: double.infinity, height: 56,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF43E97B), foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 8, shadowColor: const Color(0xFF43E97B).withOpacity(0.5),
              ),
              icon: const Icon(Icons.save_rounded, size: 22),
              label: const Text('Enregistrer tous les bulletins', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              onPressed: _saveAll,
            ),
          ),
        ),
      ],
    );
  }

  Widget _noteBox(String label, dynamic note, Color color) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(14), border: Border.all(color: color.withOpacity(0.2))),
      child: Column(children: [
        Text(label, style: TextStyle(color: color.withOpacity(0.8), fontWeight: FontWeight.bold, fontSize: 11)),
        const SizedBox(height: 6),
        Text(note is int ? '$note/20' : '$note', style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 22)),
      ]),
    );
  }

  Widget _infoTile(String emoji, String title, String content, Color color) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: color.withOpacity(0.05), borderRadius: BorderRadius.circular(14), border: Border.all(color: color.withOpacity(0.15))),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(emoji, style: const TextStyle(fontSize: 18)),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12)),
          const SizedBox(height: 4),
          Text(content, style: const TextStyle(color: Colors.white70, fontSize: 13)),
        ])),
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
