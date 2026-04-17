import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/family_provider.dart';
import '../models/punishment_lines.dart';
import '../models/child_model.dart';
import '../widgets/animated_background.dart';
import '../widgets/glass_card.dart';
import '../services/gemini_service.dart';

class PunishmentLinesScreen extends StatefulWidget {
  const PunishmentLinesScreen({super.key});
  @override
  State<PunishmentLinesScreen> createState() => _PunishmentLinesScreenState();
}

class _PunishmentLinesScreenState extends State<PunishmentLinesScreen> {
  final TextEditingController _descController = TextEditingController();
  final TextEditingController _linesController = TextEditingController();
  ChildModel? _selectedChild;
  bool _loading = false;
  final Map<String, int> _quizCounts = {};

  @override
  void dispose() {
    _descController.dispose();
    _linesController.dispose();
    super.dispose();
  }

  Future<void> _incrementQuizCount(String childId) async {
    setState(() { _quizCounts[childId] = (_quizCounts[childId] ?? 0) + 1; });
  }

  Future<void> _savePunishment(FamilyProvider fp, ChildModel? child) async {
    if (child == null) return;
    final desc = _descController.text.trim();
    final lines = int.tryParse(_linesController.text.trim()) ?? 0;
    if (desc.isEmpty || lines <= 0) return;
    setState(() => _loading = true);
    await fp.addPunishment(child.id, desc, lines);
    _descController.clear();
    _linesController.clear();
    setState(() { _loading = false; _selectedChild = null; });
    if (mounted) Navigator.pop(context);
  }

  Future<void> _deletePunishment(FamilyProvider fp, String id) async {
    await fp.removePunishment(id);
  }

  @override
  Widget build(BuildContext context) {
    final fp = context.watch<FamilyProvider>();
    final children = fp.children;
    if (children.isEmpty) {
      return AnimatedBackground(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(backgroundColor: Colors.transparent,
            title: const Text('Punitions', style: TextStyle(color: Colors.white))),
          body: const Center(child: Text('Aucun enfant enregistre', style: TextStyle(color: Colors.white54))),
        ),
      );
    }
    _selectedChild ??= children.first;
    final child = _selectedChild!;
    final allPunishments = fp.punishments.where((p) => p.childId == child.id).toList();
    final active = allPunishments.where((p) => !p.isCompleted).toList();
    final completed = allPunishments.where((p) => p.isCompleted).toList();
    return AnimatedBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          title: const Text('Lignes de Punition', style: TextStyle(color: Colors.white)),
          actions: [
            IconButton(
              icon: const Icon(Icons.add_circle, color: Colors.redAccent),
              onPressed: () => _showAddDialog(context, fp, child),
            ),
          ],
        ),
        body: Column(
          children: [
            _buildChildSelector(children, child, fp),
            _buildStats(active, child),
            Expanded(
              child: active.isEmpty && completed.isEmpty
                  ? const Center(child: Text('Aucune punition', style: TextStyle(color: Colors.white54)))
                  : ListView(
                      padding: const EdgeInsets.all(12),
                      children: [
                        if (active.isNotEmpty) ...[
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 8),
                            child: Text('EN COURS', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 12)),
                          ),
                          ...active.map((p) => _buildPunishmentCard(p, child, fp)),
                        ],
                        if (completed.isNotEmpty) ...[
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 8),
                            child: Text('TERMINEES', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 12)),
                          ),
                          ...completed.map((p) => _buildPunishmentCard(p, child, fp)),
                        ],
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChildSelector(List<ChildModel> children, ChildModel selected, FamilyProvider fp) {
    return SizedBox(
      height: 70,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        itemCount: children.length,
        itemBuilder: (_, i) {
          final c = children[i];
          final isSelected = c.id == selected.id;
          final activePunishments = fp.punishments.where((p) => p.childId == c.id && !p.isCompleted).length;
          return GestureDetector(
            onTap: () => setState(() => _selectedChild = c),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              margin: const EdgeInsets.only(right: 10),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected ? Colors.redAccent.withOpacity(0.3) : Colors.white10,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: isSelected ? Colors.redAccent : Colors.white24, width: 1.5),
              ),
              child: Row(
                children: [
                  Text(c.avatar, style: const TextStyle(fontSize: 18)),
                  const SizedBox(width: 6),
                  Text(c.name, style: TextStyle(color: isSelected ? Colors.white : Colors.white70)),
                  if (activePunishments > 0) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(color: Colors.redAccent, borderRadius: BorderRadius.circular(10)),
                      child: Text('$activePunishments', style: const TextStyle(color: Colors.white, fontSize: 11)),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildStats(List<PunishmentLines> active, ChildModel child) {
    final totalLines = active.fold<int>(0, (sum, p) => sum + (p.totalLines - p.completedLines));
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: GlassCard(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _statItem('📋', '${active.length}', 'Punitions'),
            _statItem('✏', '$totalLines', 'Lignes restantes'),
            _statItem('🎯', '${_quizCounts[child.id] ?? 0}', 'Quiz faits'),
          ],
        ),
      ),
    );
  }

  Widget _statItem(String emoji, String value, String label) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(emoji, style: const TextStyle(fontSize: 20)),
        Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
        Text(label, style: const TextStyle(color: Colors.white54, fontSize: 11)),
      ],
    );
  }

  Widget _buildPunishmentCard(PunishmentLines p, ChildModel child, FamilyProvider fp) {
    final isCompleted = p.isCompleted;
    final remaining = p.totalLines - p.completedLines;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GlassCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(isCompleted ? Icons.check_circle : Icons.edit_document,
                    color: isCompleted ? Colors.green : Colors.redAccent, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(p.text,
                    style: TextStyle(color: isCompleted ? Colors.white54 : Colors.white,
                      decoration: isCompleted ? TextDecoration.lineThrough : null)),
                ),
                if (!isCompleted)
                  IconButton(
                    icon: const Icon(Icons.quiz, color: Colors.amberAccent, size: 20),
                    onPressed: () => _showQuizThemePicker(p, child, fp),
                    tooltip: 'Lancer le quiz',
                  ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.white38, size: 18),
                  onPressed: () => _deletePunishment(fp, p.id),
                ),
              ],
            ),
            if (!isCompleted) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: LinearProgressIndicator(
                      value: p.totalLines > 0 ? p.completedLines / p.totalLines : 0,
                      backgroundColor: Colors.white12,
                      valueColor: const AlwaysStoppedAnimation<Color>(Colors.redAccent),
                      minHeight: 6,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text('$remaining/${p.totalLines}', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                ],
              ),
            ],
            const SizedBox(height: 4),
            Text(_timeAgo(p.createdAt), style: const TextStyle(color: Colors.white38, fontSize: 11)),
          ],
        ),
      ),
    );
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return "A l instant";
    if (diff.inHours < 1) return 'Il y a ${diff.inMinutes} min';
    if (diff.inDays < 1) return 'Il y a ${diff.inHours}h';
    if (diff.inDays < 7) return 'Il y a ${diff.inDays}j';
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  void _showAddDialog(BuildContext context, FamilyProvider fp, ChildModel child) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Nouvelle punition', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildTextField(_descController, 'Description', Icons.edit_document),
            const SizedBox(height: 12),
            _buildTextField(_linesController, 'Nombre de lignes', Icons.format_list_numbered, isNumber: true),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler', style: TextStyle(color: Colors.white54))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () async { await _savePunishment(fp, child); if (ctx.mounted) Navigator.pop(ctx); },
            child: const Text('Ajouter'),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField(TextEditingController ctrl, String label, IconData icon, {bool isNumber = false}) {
    return TextField(
      controller: ctrl,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white54),
        prefixIcon: Icon(icon, color: Colors.redAccent),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.white24)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.redAccent)),
      ),
    );
  }

  void _showQuizThemePicker(PunishmentLines p, ChildModel child, FamilyProvider fp) {
    int currentStep = 0;
    int selectedAge = 8;
    String selectedDifficulty = 'moyen';
    String? selectedTheme;
    String? selectedHero;
    List<Map<String, dynamic>> customQuestions = [];

    final List<Map<String, dynamic>> themes = [
      {'label': 'Mathematiques', 'emoji': '🔢', 'color': 0xFF4FC3F7},
      {'label': 'Francais', 'emoji': '📝', 'color': 0xFFAB47BC},
      {'label': 'Sciences', 'emoji': '🔬', 'color': 0xFF66BB6A},
      {'label': 'Histoire', 'emoji': '🏛️', 'color': 0xFFFF8A65},
      {'label': 'Geographie', 'emoji': '🌍', 'color': 0xFF26C6DA},
      {'label': 'Culture generale', 'emoji': '🧠', 'color': 0xFFFFCA28},
      {'label': 'Personnalise', 'emoji': '⭐', 'color': 0xFFEC407A},
    ];

    final List<Map<String, dynamic>> heroes = [
      {'label': 'Pat Patrouille', 'emoji': '🐾'},
      {'label': 'Miraculous', 'emoji': '🐞'},
      {'label': 'Spider-Man', 'emoji': '🕷️'},
      {'label': 'Bluey', 'emoji': '🐕'},
      {'label': 'Peppa Pig', 'emoji': '🐷'},
      {'label': 'Minions', 'emoji': '💛'},
      {'label': 'Personnalise', 'emoji': '✨'},
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          return DraggableScrollableSheet(
            initialChildSize: 0.85,
            maxChildSize: 0.95,
            minChildSize: 0.5,
            builder: (_, scrollCtrl) => Container(
              decoration: const BoxDecoration(
                color: Color(0xFF1E1E2E),
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                children: [
                  const SizedBox(height: 8),
                  Container(width: 40, height: 4,
                    decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [0, 1, 2, 3].map((i) {
                      final done = i < currentStep;
                      final act = i == currentStep;
                      return Row(children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          width: act ? 32 : 24, height: act ? 32 : 24,
                          decoration: BoxDecoration(
                            color: done ? Colors.amberAccent : (act ? Colors.amberAccent : Colors.white24),
                            shape: BoxShape.circle,
                          ),
                          child: Center(child: done
                            ? const Icon(Icons.check, size: 14, color: Colors.black)
                            : Text('${i+1}', style: TextStyle(color: act ? Colors.black : Colors.white54, fontSize: 12, fontWeight: FontWeight.bold))),
                        ),
                        if (i < 3) Container(width: 24, height: 2, color: done ? Colors.amberAccent : Colors.white24),
                      ]);
                    }).toList(),
                  ),
                  const SizedBox(height: 8),
                  Text(['Age & Difficulte', 'Theme', 'Heros', 'Questions'][currentStep],
                    style: const TextStyle(color: Colors.white70, fontSize: 12)),
                  const SizedBox(height: 16),
                  Expanded(
                    child: SingleChildScrollView(
                      controller: scrollCtrl,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: currentStep == 0
                        ? _buildStepAgeAndDifficulty(selectedAge, selectedDifficulty,
                            (v) => setSheetState(() => selectedAge = v),
                            (v) => setSheetState(() => selectedDifficulty = v))
                        : currentStep == 1
                          ? _buildStepTheme(themes, selectedTheme, (v) => setSheetState(() => selectedTheme = v))
                          : currentStep == 2
                            ? _buildStepHeroes(heroes, selectedHero, (v) => setSheetState(() => selectedHero = v))
                            : _buildStepCustomQuestions(customQuestions, () => setSheetState(() {})),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Row(
                      children: [
                        if (currentStep > 0)
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => setSheetState(() => currentStep--),
                              style: OutlinedButton.styleFrom(foregroundColor: Colors.white54,
                                side: const BorderSide(color: Colors.white24),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                              child: const Text('Retour'),
                            ),
                          ),
                        if (currentStep > 0) const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: ElevatedButton(
                            onPressed: () async {
                              if (currentStep < 3) {
                                setSheetState(() => currentStep++);
                              } else {
                                Navigator.pop(sheetCtx);
                                await _startQuiz(p, child, fp, selectedAge, selectedDifficulty,
                                  selectedTheme ?? themes[0]['label'] as String,
                                  selectedHero, customQuestions);
                              }
                            },
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.amberAccent,
                              foregroundColor: Colors.black,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                            child: Text(currentStep < 3 ? 'Suivant' : 'Lancer le Quiz !',
                              style: const TextStyle(fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildStepAgeAndDifficulty(int age, String diff, ValueChanged<int> onAge, ValueChanged<String> onDiff) {
    final diffs = [
      {'value': 'facile', 'emoji': '🟢', 'label': 'Facile', 'desc': 'Questions simples'},
      {'value': 'moyen', 'emoji': '🟡', 'label': 'Moyen', 'desc': 'Questions moderees'},
      {'value': 'difficile', 'emoji': '🔴', 'label': 'Difficile', 'desc': 'Questions avancees'},
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Age de l enfant', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 12),
        Row(
          children: [
            IconButton(
              onPressed: age > 3 ? () => onAge(age - 1) : null,
              icon: const Icon(Icons.remove_circle, color: Colors.amberAccent),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              decoration: BoxDecoration(color: Colors.amberAccent.withOpacity(0.2), borderRadius: BorderRadius.circular(12)),
              child: Text('$age ans', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20)),
            ),
            IconButton(
              onPressed: age < 18 ? () => onAge(age + 1) : null,
              icon: const Icon(Icons.add_circle, color: Colors.amberAccent),
            ),
          ],
        ),
        const SizedBox(height: 24),
        const Text('Difficulte', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 12),
        ...diffs.map((d) => _buildDiffCard(d['value']!, d['emoji']!, d['label']!, d['desc']!, diff, onDiff)),
      ],
    );
  }

  Widget _buildDiffCard(String value, String emoji, String label, String desc, String current, ValueChanged<String> onSelect) {
    final isSelected = value == current;
    return GestureDetector(
      onTap: () => onSelect(value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSelected ? Colors.amberAccent.withOpacity(0.2) : Colors.white10,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isSelected ? Colors.amberAccent : Colors.transparent, width: 1.5),
        ),
        child: Row(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 22)),
            const SizedBox(width: 12),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label, style: TextStyle(color: isSelected ? Colors.amberAccent : Colors.white, fontWeight: FontWeight.bold)),
              Text(desc, style: const TextStyle(color: Colors.white54, fontSize: 12)),
            ]),
            if (isSelected) ...[const Spacer(), const Icon(Icons.check_circle, color: Colors.amberAccent, size: 20)],
          ],
        ),
      ),
    );
  }

  Widget _buildStepTheme(List<Map<String, dynamic>> themes, String? selected, ValueChanged<String> onSelect) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Choisir un theme', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 12),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2, childAspectRatio: 1.8, crossAxisSpacing: 10, mainAxisSpacing: 10),
          itemCount: themes.length,
          itemBuilder: (_, i) {
            final t = themes[i];
            final isSel = t['label'] == selected;
            return GestureDetector(
              onTap: () => onSelect(t['label'] as String),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                decoration: BoxDecoration(
                  color: isSel ? Color(t['color'] as int).withOpacity(0.3) : Colors.white10,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: isSel ? Color(t['color'] as int) : Colors.transparent, width: 1.5),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(t['emoji'] as String, style: const TextStyle(fontSize: 24)),
                    const SizedBox(height: 4),
                    Text(t['label'] as String,
                      style: TextStyle(color: isSel ? Colors.white : Colors.white70, fontSize: 12),
                      textAlign: TextAlign.center),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildStepHeroes(List<Map<String, dynamic>> heroes, String? selected, ValueChanged<String> onSelect) {
    final customCtrl = TextEditingController();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Heros prefere (optionnel)', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 12),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2, childAspectRatio: 1.8, crossAxisSpacing: 10, mainAxisSpacing: 10),
          itemCount: heroes.length,
          itemBuilder: (_, i) {
            final h = heroes[i];
            final isSel = h['label'] == selected;
            return GestureDetector(
              onTap: () => onSelect(h['label'] as String),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                decoration: BoxDecoration(
                  color: isSel ? Colors.purpleAccent.withOpacity(0.3) : Colors.white10,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: isSel ? Colors.purpleAccent : Colors.transparent, width: 1.5),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(h['emoji'] as String, style: const TextStyle(fontSize: 24)),
                    const SizedBox(height: 4),
                    Text(h['label'] as String,
                      style: TextStyle(color: isSel ? Colors.white : Colors.white70, fontSize: 12),
                      textAlign: TextAlign.center),
                  ],
                ),
              ),
            );
          },
        ),
        if (selected == 'Personnalise') ...[
          const SizedBox(height: 12),
          TextField(
            controller: customCtrl,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              labelText: 'Nom du heros',
              labelStyle: const TextStyle(color: Colors.white54),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.white24)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.purpleAccent)),
            ),
            onChanged: onSelect,
          ),
        ],
      ],
    );
  }

  Widget _buildStepCustomQuestions(List<Map<String, dynamic>> questions, VoidCallback refresh) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Questions personnalisees', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
            TextButton.icon(
              onPressed: () async { await _showAddCustomQuestion(questions); refresh(); },
              icon: const Icon(Icons.add, color: Colors.amberAccent, size: 18),
              label: const Text('Ajouter', style: TextStyle(color: Colors.amberAccent)),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (questions.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Center(child: Text('Aucune question\n(le quiz utilisera Gemini AI)',
              textAlign: TextAlign.center, style: TextStyle(color: Colors.white54))),
          )
        else
          ...questions.asMap().entries.map((e) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(12)),
              child: Row(
                children: [
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Q: ${e.value["question"]}', style: const TextStyle(color: Colors.white, fontSize: 13)),
                    Text('R: ${e.value["answer"]}', style: const TextStyle(color: Colors.amberAccent, fontSize: 12)),
                  ])),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.white38, size: 18),
                    onPressed: () { questions.removeAt(e.key); refresh(); },
                  ),
                ],
              ),
            ),
          )),
      ],
    );
  }

  Future<void> _showAddCustomQuestion(List<Map<String, dynamic>> questions) async {
    final qCtrl = TextEditingController();
    final aCtrl = TextEditingController();
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Nouvelle question', style: TextStyle(color: Colors.white)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: qCtrl, style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(labelText: 'Question', labelStyle: TextStyle(color: Colors.white54),
              enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
              focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.amberAccent)))),
          const SizedBox(height: 12),
          TextField(controller: aCtrl, style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(labelText: 'Reponse', labelStyle: TextStyle(color: Colors.white54),
              enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
              focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.amberAccent)))),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler', style: TextStyle(color: Colors.white54))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.amberAccent, foregroundColor: Colors.black),
            onPressed: () {
              if (qCtrl.text.isNotEmpty && aCtrl.text.isNotEmpty) {
                questions.add({'question': qCtrl.text.trim(), 'answer': aCtrl.text.trim()});
              }
              Navigator.pop(ctx);
            },
            child: const Text('Ajouter'),
          ),
        ],
      ),
    );
    qCtrl.dispose();
    aCtrl.dispose();
  }

  Future<void> _startQuiz(PunishmentLines p, ChildModel child, FamilyProvider fp,
      int age, String difficulty, String theme, String? hero,
      List<Map<String, dynamic>> customQuestions) async {
    List<Map<String, dynamic>> questions = [];

    if (customQuestions.isNotEmpty) {
      // Convertir format custom vers format standard
      questions = customQuestions.asMap().entries.map((e) => {
        'question': e.value['question'],
        'choices': [e.value['answer'], 'Faux'],
        'correct': 0,
      }).toList();
    } else {
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => const Center(child: CircularProgressIndicator(color: Colors.amberAccent)),
        );
      }
      try {
        final themeWithHero = hero != null && hero != 'Personnalise'
          ? '$theme avec des references a $hero'
          : theme;
        questions = await GeminiService.generateQuizQuestions(
          theme: themeWithHero,
          age: age,
          difficulty: difficulty,
        );
      } catch (e) {
        if (mounted) Navigator.pop(context);
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur Gemini: $e')));
        return;
      }
      if (mounted) Navigator.pop(context);
    }

    if (questions.isEmpty) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Aucune question generee')));
      return;
    }
    if (mounted) _showQuizDialog(p, child, fp, questions);
  }

  void _showQuizDialog(PunishmentLines p, ChildModel child, FamilyProvider fp,
      List<Map<String, dynamic>> questions) {
    int currentQ = 0;
    int score = 0;
    int? selectedIndex;
    bool answered = false;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final q = questions[currentQ];
          final choices = (q['choices'] as List?)?.cast<String>() ?? ['Vrai', 'Faux'];
          final correctIndex = q['correct'] as int? ?? 0;
          return AlertDialog(
            backgroundColor: const Color(0xFF1E1E2E),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Q ${currentQ + 1}/${questions.length}',
                  style: const TextStyle(color: Colors.amberAccent, fontSize: 14)),
                Text('Score: $score',
                  style: const TextStyle(color: Colors.white70, fontSize: 14)),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(q['question'] as String? ?? '',
                  style: const TextStyle(color: Colors.white, fontSize: 16)),
                const SizedBox(height: 16),
                ...choices.asMap().entries.map((e) {
                  final idx = e.key;
                  final opt = e.value;
                  Color color = Colors.white10;
                  if (answered) {
                    if (idx == correctIndex) color = Colors.green.withOpacity(0.4);
                    else if (idx == selectedIndex) color = Colors.red.withOpacity(0.4);
                  } else if (idx == selectedIndex) color = Colors.amberAccent.withOpacity(0.3);
                  return GestureDetector(
                    onTap: answered ? null : () => setDialogState(() => selectedIndex = idx),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: selectedIndex == idx && !answered ? Colors.amberAccent : Colors.transparent)),
                      child: Row(children: [
                        Expanded(child: Text(opt, style: const TextStyle(color: Colors.white))),
                        if (answered && idx == correctIndex) const Icon(Icons.check_circle, color: Colors.green, size: 18),
                        if (answered && idx == selectedIndex && idx != correctIndex) const Icon(Icons.cancel, color: Colors.red, size: 18),
                      ]),
                    ),
                  );
                }),
              ],
            ),
            actions: [
              if (!answered && selectedIndex != null)
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.amberAccent, foregroundColor: Colors.black),
                  onPressed: () {
                    final correct = selectedIndex == correctIndex;
                    setDialogState(() { answered = true; if (correct) score++; });
                  },
                  child: const Text('Valider'),
                ),
              if (answered)
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.amberAccent, foregroundColor: Colors.black),
                  onPressed: () {
                    if (currentQ + 1 < questions.length) {
                      setDialogState(() { currentQ++; selectedIndex = null; answered = false; });
                    } else {
                      Navigator.pop(dialogCtx);
                      _showQuizResult(p, child, fp, score, questions.length);
                    }
                  },
                  child: Text(currentQ + 1 < questions.length ? 'Suivant' : 'Terminer'),
                ),
            ],
          );
        },
      ),
    );
  }

  void _showQuizResult(PunishmentLines p, ChildModel child, FamilyProvider fp, int score, int total) {
    int parentAdjustment = score;
    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (ctx, setResultState) => AlertDialog(
          backgroundColor: const Color(0xFF1E1E2E),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Column(
            children: [
              Text(score >= total * 0.8 ? '🏆' : score >= total * 0.5 ? '⭐' : '💪',
                style: const TextStyle(fontSize: 40)),
              const SizedBox(height: 8),
              Text('$score / $total bonnes reponses',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Lignes d immunite a accorder :', style: TextStyle(color: Colors.white70)),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    onPressed: parentAdjustment > 0 ? () => setResultState(() => parentAdjustment--) : null,
                    icon: const Icon(Icons.remove_circle, color: Colors.redAccent, size: 32),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.amberAccent.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12)),
                    child: Text('$parentAdjustment',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 28)),
                  ),
                  IconButton(
                    onPressed: () => setResultState(() => parentAdjustment++),
                    icon: const Icon(Icons.add_circle, color: Colors.green, size: 32),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                parentAdjustment > 0 ? '+$parentAdjustment ligne(s) d immunite' : 'Aucune recompense',
                style: TextStyle(color: parentAdjustment > 0 ? Colors.amberAccent : Colors.white38, fontSize: 13)),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Fermer', style: TextStyle(color: Colors.white54)),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.amberAccent, foregroundColor: Colors.black),
              icon: const Icon(Icons.shield, size: 16),
              label: Text(parentAdjustment > 0
                ? 'Accorder +$parentAdjustment immunite(s)'
                : 'Fermer sans recompense'),
              onPressed: () async {
                Navigator.pop(dialogContext);
                if (parentAdjustment > 0) {
                  await fp.addImmunity(child.id, 'Quiz - $score/$total bonnes reponses', parentAdjustment);
                }
                await _incrementQuizCount(child.id);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text(parentAdjustment > 0
                      ? 'Quiz valide ! +$parentAdjustment ligne(s) d immunite accordee(s) !'
                      : 'Quiz termine - aucune recompense'),
                    backgroundColor: Colors.purpleAccent.withOpacity(0.8),
                  ));
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}
