import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/family_provider.dart';
import '../models/punishment_lines.dart';
import '../models/immunity_lines.dart';
import '../models/child_model.dart';
import '../widgets/glass_card.dart';
import '../widgets/animated_background.dart';
import '../services/gemini_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class PunishmentLinesScreen extends StatefulWidget {
  const PunishmentLinesScreen({super.key});

  @override
  State<PunishmentLinesScreen> createState() => _PunishmentLinesScreenState();
}

class _PunishmentLinesScreenState extends State<PunishmentLinesScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnim;

  String? _selectedChildId;
  bool _showAddForm = false;
  bool _showCompleted = false;

  final TextEditingController _descController = TextEditingController();
  final TextEditingController _linesController = TextEditingController();

  // Quiz IA — compteur hebdomadaire par enfant
  Map<String, int> _weeklyQuizCount = {};
  Map<String, String> _weeklyQuizWeek = {};

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _fadeAnim = CurvedAnimation(parent: _controller, curve: Curves.easeIn);
    _controller.forward();
    _loadQuizCounts();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final fp = context.read<FamilyProvider>();
      if (fp.children.isNotEmpty && _selectedChildId == null) {
        setState(() => _selectedChildId = fp.children.first.id);
      }
    });
  }

  String _currentWeekKey() {
    final now = DateTime.now();
    final monday = now.subtract(Duration(days: now.weekday - 1));
    return '${monday.year}-${monday.month}-${monday.day}';
  }

  Future<void> _loadQuizCounts() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('quiz_counts') ?? '{}';
    final weekRaw = prefs.getString('quiz_weeks') ?? '{}';
    final currentWeek = _currentWeekKey();
    final counts = Map<String, dynamic>.from(jsonDecode(raw));
    final weeks = Map<String, dynamic>.from(jsonDecode(weekRaw));
    final resetCounts = <String, int>{};
    for (final entry in counts.entries) {
      if (weeks[entry.key] == currentWeek) {
        resetCounts[entry.key] = entry.value as int;
      } else {
        resetCounts[entry.key] = 0;
      }
    }
    setState(() {
      _weeklyQuizCount = resetCounts;
      _weeklyQuizWeek = Map<String, String>.from(weeks);
    });
  }

  Future<void> _incrementQuizCount(String childId) async {
    final prefs = await SharedPreferences.getInstance();
    final currentWeek = _currentWeekKey();
    setState(() {
      _weeklyQuizCount[childId] = (_weeklyQuizCount[childId] ?? 0) + 1;
      _weeklyQuizWeek[childId] = currentWeek;
    });
    await prefs.setString('quiz_counts', jsonEncode(_weeklyQuizCount));
    await prefs.setString('quiz_weeks', jsonEncode(_weeklyQuizWeek));
  }

  int _getQuizCountForChild(String childId) {
    final currentWeek = _currentWeekKey();
    if (_weeklyQuizWeek[childId] != currentWeek) return 0;
    return _weeklyQuizCount[childId] ?? 0;
  }

  /// Estime l'âge de l'enfant à partir de son niveau
  int _estimateAge(ChildModel child) {
    final level = child.level;
    if (level <= 2) return 6;
    if (level <= 4) return 8;
    if (level <= 6) return 10;
    if (level <= 8) return 12;
    return 14;
  }

  @override
  void dispose() {
    _controller.dispose();
    _descController.dispose();
    _linesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<FamilyProvider>(
      builder: (context, fp, _) {
        final children = fp.children;
        if (children.isNotEmpty && _selectedChildId == null) {
          _selectedChildId = children.first.id;
        }
        final child = _selectedChildId != null
            ? fp.children.firstWhere((c) => c.id == _selectedChildId,
                orElse: () => children.first)
            : (children.isNotEmpty ? children.first : null);

        if (children.isEmpty) {
          return AnimatedBackground(
            child: Scaffold(
              backgroundColor: Colors.transparent,
              appBar: AppBar(
                  backgroundColor: Colors.transparent,
                  title: const Text('Punitions',
                      style: TextStyle(color: Colors.white))),
              body: const Center(
                  child: Text('Aucun enfant enregistré',
                      style: TextStyle(color: Colors.white54))),
            ),
          );
        }

        final allPunishments =
            fp.punishments.where((p) => p.childId == child!.id).toList();
        final active = allPunishments.where((p) => !p.isCompleted).toList();
        final completed =
            allPunishments.where((p) => p.isCompleted).toList();

        return AnimatedBackground(
          child: Scaffold(
            backgroundColor: Colors.transparent,
            appBar: AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              title: const Text('📜 Punitions',
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold)),
              actions: [
                IconButton(
                  icon: const Icon(Icons.add_circle_outline,
                      color: Colors.white),
                  onPressed: () =>
                      setState(() => _showAddForm = !_showAddForm),
                ),
              ],
            ),
            body: FadeTransition(
              opacity: _fadeAnim,
              child: Column(
                children: [
                  _buildChildSelector(children, child!),
                  if (_showAddForm) _buildAddForm(fp, child),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _sectionHeader(
                            '🔴 En cours',
                            '${active.length} punition${active.length > 1 ? 's' : ''}',
                            Colors.redAccent,
                          ),
                          const SizedBox(height: 8),
                          if (active.isEmpty)
                            _emptyState('✅', 'Aucune punition en cours !')
                          else
                            ...active.map((p) =>
                                _buildPunishmentCard(p, child, fp, false)),
                          const SizedBox(height: 20),
                          GestureDetector(
                            onTap: () => setState(
                                () => _showCompleted = !_showCompleted),
                            child: _sectionHeader(
                              '✅ Terminées',
                              '${completed.length} punition${completed.length > 1 ? 's' : ''}',
                              Colors.greenAccent,
                              trailing: Icon(
                                _showCompleted
                                    ? Icons.keyboard_arrow_up
                                    : Icons.keyboard_arrow_down,
                                color: Colors.white54,
                              ),
                            ),
                          ),
                          if (_showCompleted) ...[
                            const SizedBox(height: 8),
                            if (completed.isEmpty)
                              _emptyState(
                                  '📋', 'Aucune punition terminée')
                            else
                              ...completed.map((p) =>
                                  _buildPunishmentCard(p, child, fp, true)),
                          ],
                          const SizedBox(height: 40),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _sectionHeader(String title, String subtitle, Color color,
      {Widget? trailing}) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 32,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16)),
              Text(subtitle,
                  style: const TextStyle(
                      color: Colors.white38, fontSize: 12)),
            ],
          ),
        ),
        if (trailing != null) trailing,
      ],
    );
  }

  Widget _emptyState(String emoji, String message) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Center(
        child: Column(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 40)),
            const SizedBox(height: 8),
            Text(message,
                style: const TextStyle(
                    color: Colors.white54, fontSize: 14)),
          ],
        ),
      ),
    );
  }

  Widget _buildChildSelector(
      List<ChildModel> children, ChildModel selected) {
    return Container(
      height: 80,
      color: Colors.black12,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        itemCount: children.length,
        itemBuilder: (_, i) {
          final c = children[i];
          final isSelected = c.id == selected.id;
          return GestureDetector(
            onTap: () => setState(() {
              _selectedChildId = c.id;
              _showAddForm = false;
            }),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              margin: const EdgeInsets.symmetric(horizontal: 6),
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                gradient: isSelected
                    ? const LinearGradient(colors: [
                        Color(0xFF7C4DFF),
                        Color(0xFF00BCD4)
                      ])
                    : null,
                color: isSelected ? null : Colors.white10,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color: isSelected
                        ? Colors.transparent
                        : Colors.white24),
              ),
              child: Row(
                children: [
                  Text(c.avatar.isNotEmpty ? c.avatar : '🧒',
                      style: const TextStyle(fontSize: 18)),
                  const SizedBox(width: 6),
                  Text(c.name,
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: isSelected
                              ? FontWeight.bold
                              : FontWeight.normal)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildAddForm(FamilyProvider fp, ChildModel child) {
    return GlassCard(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Nouvelle punition pour ${child.name}',
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16)),
          const SizedBox(height: 12),
          _buildTextField(
              _descController, 'Description *', Icons.edit),
          const SizedBox(height: 8),
          _buildTextField(
              _linesController,
              'Nombre de lignes *',
              Icons.format_list_numbered,
              isNumber: true),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF7C4DFF),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(Icons.save),
              label: const Text('Enregistrer'),
              onPressed: () => _savePunishment(fp, child),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField(
      TextEditingController ctrl, String label, IconData icon,
      {bool isNumber = false}) {
    return TextFormField(
      controller: ctrl,
      keyboardType:
          isNumber ? TextInputType.number : TextInputType.text,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white60),
        prefixIcon: Icon(icon, color: Colors.white38),
        filled: true,
        fillColor: Colors.white10,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none),
      ),
    );
  }

  Future<void> _savePunishment(FamilyProvider fp, ChildModel child) async {
    final desc = _descController.text.trim();
    final lines = int.tryParse(_linesController.text.trim()) ?? 0;
    if (desc.isEmpty || lines <= 0) return;
    await fp.addPunishment(child.id, desc, lines);
    _descController.clear();
    _linesController.clear();
    setState(() => _showAddForm = false);
  }

  Widget _buildPunishmentCard(PunishmentLines p, ChildModel child,
      FamilyProvider fp, bool isCompleted) {
    final progress = p.progress;
    final remaining = p.totalLines - p.completedLines;
    final totalImmunity = fp.getTotalAvailableImmunity(child.id);
    final quizCount = _getQuizCountForChild(child.id);
    final quizAvailable = quizCount < 3;

    return GlassCard(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      child: Opacity(
        opacity: isCompleted ? 0.65 : 1.0,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isCompleted
                        ? Colors.greenAccent
                        : Colors.redAccent,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(p.text,
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          decoration: isCompleted
                              ? TextDecoration.lineThrough
                              : null)),
                ),
                IconButton(
                  icon: Icon(Icons.delete_outline,
                      color: isCompleted
                          ? Colors.white24
                          : Colors.redAccent),
                  onPressed: () => _confirmDelete(p, fp),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Text(
                    '${p.completedLines} / ${p.totalLines} lignes',
                    style: const TextStyle(
                        color: Colors.white70, fontSize: 13)),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: isCompleted
                        ? Colors.greenAccent.withOpacity(0.15)
                        : Colors.white10,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    isCompleted
                        ? '✅ Terminée'
                        : '${(progress * 100).round()}%',
                    style: TextStyle(
                        color: isCompleted
                            ? Colors.greenAccent
                            : Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress,
                backgroundColor: Colors.white12,
                valueColor: AlwaysStoppedAnimation<Color>(isCompleted
                    ? Colors.greenAccent
                    : const Color(0xFF7C4DFF)),
                minHeight: 8,
              ),
            ),
            if (!isCompleted) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(
                            color: Color(0xFF7C4DFF)),
                        foregroundColor: const Color(0xFF7C4DFF),
                        shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(10)),
                      ),
                      icon: const Icon(Icons.edit, size: 16),
                      label: const Text('Avancer'),
                      onPressed: () => _advanceLines(p, fp),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            Colors.greenAccent.withOpacity(0.2),
                        foregroundColor: Colors.greenAccent,
                        shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(10)),
                      ),
                      icon: const Icon(Icons.check_circle,
                          size: 16),
                      label: const Text('Terminer'),
                      onPressed: () =>
                          _completePunishment(p, fp),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              const Divider(color: Colors.white12),
              const Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: Text('💡 Réduire via :',
                    style: TextStyle(
                        color: Colors.white54,
                        fontSize: 12,
                        fontWeight: FontWeight.w600)),
              ),
              _reductionButton(
                icon: Icons.shield,
                label: totalImmunity > 0
                    ? '🛡️ Immunité ($totalImmunity lignes dispo)'
                    : '🛡️ Aucune immunité disponible',
                color: Colors.amberAccent,
                enabled: totalImmunity > 0 && remaining > 0,
                onTap: () => _showImmunityPicker(p, child, fp),
              ),
              const SizedBox(height: 8),
              _reductionButton(
                icon: Icons.handyman,
                label: '🔧 Proposer un service',
                color: Colors.lightBlueAccent,
                enabled: remaining > 0,
                onTap: () => _showServiceDialog(p, child, fp),
              ),
              const SizedBox(height: 8),
              _reductionButton(
                icon: Icons.school,
                label: '📚 Bonne note scolaire',
                color: Colors.greenAccent,
                enabled: remaining > 0,
                onTap: () =>
                    _showSchoolNoteDialog(p, child, fp),
              ),
              const SizedBox(height: 8),
              _reductionButton(
                icon: Icons.psychology,
                label: quizAvailable
                    ? '🧠 Quiz IA Gemini ($quizCount/3 cette semaine)'
                    : '🧠 Quiz IA — Limite atteinte (3/3)',
                color: Colors.purpleAccent,
                enabled: quizAvailable && remaining > 0,
                onTap: () =>
                    _showQuizThemePicker(p, child, fp),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _reductionButton({
    required IconData icon,
    required String label,
    required Color color,
    required bool enabled,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor:
              enabled ? color.withOpacity(0.15) : Colors.white10,
          foregroundColor: enabled ? color : Colors.white30,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10)),
          padding: const EdgeInsets.symmetric(vertical: 10),
        ),
        icon: Icon(icon, size: 16),
        label: Text(label, style: const TextStyle(fontSize: 13)),
        onPressed: enabled ? onTap : null,
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════
  // QUIZ IA GEMINI
  // ══════════════════════════════════════════════════════════════

  void _showQuizThemePicker(
      PunishmentLines p, ChildModel child, FamilyProvider fp) {
    final themes = [
      {'emoji': '🏛️', 'label': 'Histoire'},
      {'emoji': '🔬', 'label': 'Science'},
      {'emoji': '🌿', 'label': 'Nature'},
      {'emoji': '⚽', 'label': 'Sport'},
      {'emoji': '🌍', 'label': 'Géographie'},
      {'emoji': '🎬', 'label': 'Cinéma'},
      {'emoji': '🐾', 'label': 'Animaux'},
      {'emoji': '🎯', 'label': 'Culture générale'},
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.65,
        minChildSize: 0.5,
        maxChildSize: 0.9,
        expand: false,
        builder: (_, scrollCtrl) => Container(
          decoration: const BoxDecoration(
            color: Color(0xFF0D1B2A),
            borderRadius:
                BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                      color: Colors.white38,
                      borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 16),
              const Text('🧠 Quiz IA Gemini',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(
                '${child.name} · 3 questions adaptées',
                style: const TextStyle(
                    color: Colors.white54, fontSize: 13),
              ),
              const SizedBox(height: 4),
              Container(
                margin:
                    const EdgeInsets.symmetric(horizontal: 20),
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.purpleAccent.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color:
                          Colors.purpleAccent.withOpacity(0.3)),
                ),
                child: Text(
                  '🏆 Bonne réponse = 1 ligne retirée (max 3)',
                  style: TextStyle(
                      color: Colors.purpleAccent.shade100,
                      fontSize: 12),
                ),
              ),
              const SizedBox(height: 20),
              const Padding(
                padding: EdgeInsets.only(left: 20, bottom: 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Choisis ton thème :',
                      style: TextStyle(
                          color: Colors.white60,
                          fontWeight: FontWeight.w600)),
                ),
              ),
              Expanded(
                child: GridView.builder(
                  controller: scrollCtrl,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16),
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 2.2,
                  ),
                  itemCount: themes.length,
                  itemBuilder: (_, i) {
                    final theme = themes[i];
                    return GestureDetector(
                      onTap: () {
                        Navigator.pop(context);
                        _startQuiz(
                            p, child, fp, theme['label']!);
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.purpleAccent
                                  .withOpacity(0.2),
                              Colors.blueAccent
                                  .withOpacity(0.15),
                            ],
                          ),
                          borderRadius:
                              BorderRadius.circular(14),
                          border: Border.all(
                              color: Colors.purpleAccent
                                  .withOpacity(0.3)),
                        ),
                        child: Row(
                          mainAxisAlignment:
                              MainAxisAlignment.center,
                          children: [
                            Text(theme['emoji']!,
                                style: const TextStyle(
                                    fontSize: 24)),
                            const SizedBox(width: 8),
                            Text(theme['label']!,
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14)),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _startQuiz(PunishmentLines p, ChildModel child,
      FamilyProvider fp, String theme) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const AlertDialog(
        backgroundColor: Color(0xFF1A1A2E),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: Colors.purpleAccent),
            SizedBox(height: 16),
            Text('🧠 Gemini prépare le quiz...',
                style: TextStyle(color: Colors.white)),
            SizedBox(height: 4),
            Text('Adapté à l\'âge de l\'enfant',
                style: TextStyle(
                    color: Colors.white54, fontSize: 12)),
          ],
        ),
      ),
    );

    try {
      final questions = await GeminiService.generateQuizQuestions(
        theme: theme,
        age: _estimateAge(child),
      );
      if (mounted) Navigator.pop(context);
      if (questions.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content:
                Text('❌ Erreur Gemini — réessaie dans un instant'),
            backgroundColor: Colors.redAccent,
          ));
        }
        return;
      }
      if (mounted) {
        _showQuizDialog(p, child, fp, questions, theme);
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('❌ Erreur : $e'),
          backgroundColor: Colors.redAccent,
        ));
      }
    }
  }

  void _showQuizDialog(
      PunishmentLines p,
      ChildModel child,
      FamilyProvider fp,
      List<Map<String, dynamic>> questions,
      String theme) {
    int currentIndex = 0;
    int score = 0;
    int? selectedAnswer;
    bool answered = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final q = questions[currentIndex];
          final List<String> choices =
              List<String>.from(q['choices'] as List);
          final int correct = q['correct'] as int;

          return Dialog(
            backgroundColor: const Color(0xFF0D1B2A),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20)),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment:
                        MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.purpleAccent
                              .withOpacity(0.2),
                          borderRadius:
                              BorderRadius.circular(12),
                        ),
                        child: Text(
                          'Question ${currentIndex + 1} / ${questions.length}',
                          style: const TextStyle(
                              color: Colors.purpleAccent,
                              fontWeight: FontWeight.bold,
                              fontSize: 12),
                        ),
                      ),
                      Row(
                        children: List.generate(
                          questions.length,
                          (i) => Container(
                            margin:
                                const EdgeInsets.only(left: 4),
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: i < currentIndex
                                  ? Colors.purpleAccent
                                  : i == currentIndex
                                      ? Colors.white
                                      : Colors.white24,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(theme,
                      style: const TextStyle(
                          color: Colors.white54, fontSize: 12)),
                  const SizedBox(height: 8),
                  Text(
                    q['question'] as String,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  ...choices.asMap().entries.map((entry) {
                    final idx = entry.key;
                    final choice = entry.value;
                    Color btnColor = Colors.white10;
                    Color txtColor = Colors.white70;
                    if (answered) {
                      if (idx == correct) {
                        btnColor =
                            Colors.greenAccent.withOpacity(0.25);
                        txtColor = Colors.greenAccent;
                      } else if (idx == selectedAnswer) {
                        btnColor =
                            Colors.redAccent.withOpacity(0.25);
                        txtColor = Colors.redAccent;
                      }
                    } else if (idx == selectedAnswer) {
                      btnColor =
                          Colors.purpleAccent.withOpacity(0.25);
                      txtColor = Colors.purpleAccent;
                    }
                    return GestureDetector(
                      onTap: answered
                          ? null
                          : () {
                              setDialogState(() {
                                selectedAnswer = idx;
                                answered = true;
                                if (idx == correct) score++;
                              });
                            },
                      child: AnimatedContainer(
                        duration:
                            const Duration(milliseconds: 200),
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: btnColor,
                          borderRadius:
                              BorderRadius.circular(12),
                          border: Border.all(
                              color: answered && idx == correct
                                  ? Colors.greenAccent
                                      .withOpacity(0.5)
                                  : Colors.white12),
                        ),
                        child: Row(
                          children: [
                            Text(
                              ['A', 'B', 'C', 'D'][idx],
                              style: TextStyle(
                                  color: txtColor,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(choice,
                                  style: TextStyle(
                                      color: txtColor,
                                      fontSize: 13)),
                            ),
                            if (answered && idx == correct)
                              const Icon(Icons.check_circle,
                                  color: Colors.greenAccent,
                                  size: 16),
                            if (answered &&
                                idx == selectedAnswer &&
                                idx != correct)
                              const Icon(Icons.cancel,
                                  color: Colors.redAccent,
                                  size: 16),
                          ],
                        ),
                      ),
                    );
                  }),
                  const SizedBox(height: 16),
                  if (answered)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.purpleAccent
                              .withOpacity(0.3),
                          foregroundColor: Colors.purpleAccent,
                          shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(
                              vertical: 12),
                        ),
                        onPressed: () {
                          if (currentIndex <
                              questions.length - 1) {
                            setDialogState(() {
                              currentIndex++;
                              selectedAnswer = null;
                              answered = false;
                            });
                          } else {
                            Navigator.pop(dialogContext);
                            _showQuizResult(p, child, fp, score,
                                questions.length);
                          }
                        },
                        child: Text(
                          currentIndex < questions.length - 1
                              ? 'Question suivante →'
                              : 'Voir les résultats 🏆',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold),
                        ),
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

  void _showQuizResult(PunishmentLines p, ChildModel child,
      FamilyProvider fp, int score, int total) {
    final remaining = p.totalLines - p.completedLines;
    final linesEarned = score.clamp(0, remaining);
    String emoji;
    String message;
    if (score == total) {
      emoji = '🏆';
      message = 'Parfait ! ${child.name} a tout bon !';
    } else if (score >= total - 1) {
      emoji = '😊';
      message = 'Très bien ! Presque parfait !';
    } else if (score > 0) {
      emoji = '👍';
      message = 'Pas mal ! Continue comme ça !';
    } else {
      emoji = '😅';
      message = 'Dommage ! On réessaie la semaine prochaine !';
    }

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (ctx, setResultState) {
          int parentAdjustment = linesEarned;
          return AlertDialog(
            backgroundColor: const Color(0xFF0D1B2A),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20)),
            title: Column(
              children: [
                Text(emoji,
                    style: const TextStyle(fontSize: 48)),
                const SizedBox(height: 8),
                const Text('Résultats du Quiz',
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 18),
                    textAlign: TextAlign.center),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(message,
                    style: const TextStyle(
                        color: Colors.white70, fontSize: 14),
                    textAlign: TextAlign.center),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color:
                        Colors.purpleAccent.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                        color: Colors.purpleAccent
                            .withOpacity(0.3)),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment:
                            MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Score IA :',
                              style: TextStyle(
                                  color: Colors.white60)),
                          Text('$score / $total',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18)),
                        ],
                      ),
                      const Divider(
                          color: Colors.white12, height: 20),
                      const Text(
                          'Lignes accordées par le parent :',
                          style: TextStyle(
                              color: Colors.white60,
                              fontSize: 12)),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment:
                            MainAxisAlignment.center,
                        children: [
                          IconButton(
                            onPressed: parentAdjustment > 0
                                ? () => setResultState(
                                    () => parentAdjustment--)
                                : null,
                            icon: const Icon(
                                Icons.remove_circle,
                                color: Colors.redAccent,
                                size: 28),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 20, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.white10,
                              borderRadius:
                                  BorderRadius.circular(10),
                            ),
                            child: Text(
                              '$parentAdjustment ligne${parentAdjustment > 1 ? 's' : ''}',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18),
                            ),
                          ),
                          IconButton(
                            onPressed:
                                parentAdjustment < remaining
                                    ? () => setResultState(
                                        () => parentAdjustment++)
                                    : null,
                            icon: const Icon(Icons.add_circle,
                                color: Colors.greenAccent,
                                size: 28),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Annuler',
                    style: TextStyle(color: Colors.white38)),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      Colors.purpleAccent.withOpacity(0.25),
                  foregroundColor: Colors.purpleAccent,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                icon: const Icon(Icons.check, size: 16),
                label: Text(parentAdjustment > 0
                    ? 'Valider -$parentAdjustment ligne(s)'
                    : 'Fermer sans réduction'),
                onPressed: () async {
                  Navigator.pop(dialogContext);
                  if (parentAdjustment > 0) {
                    await fp.updatePunishmentProgress(
                        p.id, parentAdjustment);
                  }
                  await _incrementQuizCount(child.id);
                  if (mounted) {
                    ScaffoldMessenger.of(context)
                        .showSnackBar(SnackBar(
                      content: Text(parentAdjustment > 0
                          ? '🧠 Quiz validé ! $parentAdjustment ligne(s) retirée(s) !'
                          : '🧠 Quiz terminé — aucune réduction accordée'),
                      backgroundColor:
                          Colors.purpleAccent.withOpacity(0.8),
                    ));
                  }
                },
              ),
            ],
          );
        },
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════
  // MÉTHODES AVANCER / TERMINER / SUPPRIMER
  // ══════════════════════════════════════════════════════════════

  void _advanceLines(PunishmentLines p, FamilyProvider fp) {
    final ctrl = TextEditingController();
    final remaining = p.totalLines - p.completedLines;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0D1B2A),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        title: const Text('Avancer les lignes',
            style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            labelText: 'Lignes réalisées (max $remaining)',
            labelStyle:
                const TextStyle(color: Colors.white54),
            filled: true,
            fillColor: Colors.white10,
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Annuler',
                  style: TextStyle(color: Colors.white38))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor:
                    const Color(0xFF7C4DFF)),
            onPressed: () async {
              final n = int.tryParse(ctrl.text.trim()) ?? 0;
              if (n > 0) {
                await fp.updatePunishmentProgress(
                    p.id, n.clamp(0, remaining));
                if (ctx.mounted) Navigator.pop(ctx);
              }
            },
            child: const Text('Valider'),
          ),
        ],
      ),
    );
  }

  void _completePunishment(PunishmentLines p, FamilyProvider fp) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0D1B2A),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        title: const Text('Terminer la punition ?',
            style: TextStyle(color: Colors.white)),
        content: const Text(
            'Marquer cette punition comme terminée ?',
            style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Annuler',
                  style: TextStyle(color: Colors.white38))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.greenAccent
                    .withOpacity(0.3),
                foregroundColor: Colors.greenAccent),
            onPressed: () async {
              final remaining = p.totalLines - p.completedLines;
              if (remaining > 0) {
                await fp.updatePunishmentProgress(
                    p.id, remaining);
              }
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Terminer'),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(PunishmentLines p, FamilyProvider fp) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0D1B2A),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        title: const Text('Supprimer ?',
            style: TextStyle(color: Colors.white)),
        content: Text('Supprimer "${p.text}" ?',
            style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Annuler',
                  style: TextStyle(color: Colors.white38))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor:
                    Colors.redAccent.withOpacity(0.3),
                foregroundColor: Colors.redAccent),
            onPressed: () async {
              await fp.removePunishment(p.id);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════
  // SERVICE
  // ══════════════════════════════════════════════════════════════

  void _showServiceDialog(
      PunishmentLines p, ChildModel child, FamilyProvider fp) {
    final serviceCtrl = TextEditingController();
    final linesCtrl = TextEditingController();
    final services = [
      '🍽️ Faire la vaisselle',
      '🧹 Balayer / aspirer',
      '🧺 Plier le linge',
      '🗑️ Sortir les poubelles',
      '🛏️ Faire son lit parfaitement',
      '🌿 Arroser les plantes',
      '🐾 S\'occuper de l\'animal',
      '🧽 Nettoyer la salle de bain',
    ];
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setModalState) => DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.5,
          maxChildSize: 0.92,
          expand: false,
          builder: (_, scrollCtrl) => Container(
            decoration: const BoxDecoration(
              color: Color(0xFF0D1B2A),
              borderRadius:
                  BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              children: [
                const SizedBox(height: 12),
                Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                        color: Colors.white38,
                        borderRadius: BorderRadius.circular(2))),
                const SizedBox(height: 16),
                const Text('🔧 Service rendu',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(
                    '${p.totalLines - p.completedLines} lignes restantes',
                    style: const TextStyle(
                        color: Colors.white54, fontSize: 12)),
                const SizedBox(height: 16),
                Expanded(
                  child: ListView(
                    controller: scrollCtrl,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16),
                    children: [
                      const Text('Suggestions :',
                          style: TextStyle(
                              color: Colors.white60,
                              fontSize: 12,
                              fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: services.map((s) {
                          final isSelected =
                              serviceCtrl.text == s;
                          return GestureDetector(
                            onTap: () => setModalState(
                                () => serviceCtrl.text = s),
                            child: Container(
                              padding:
                                  const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 6),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? Colors.lightBlueAccent
                                        .withOpacity(0.25)
                                    : Colors.white10,
                                borderRadius:
                                    BorderRadius.circular(20),
                                border: Border.all(
                                    color: isSelected
                                        ? Colors.lightBlueAccent
                                        : Colors.white24),
                              ),
                              child: Text(s,
                                  style: TextStyle(
                                      color: isSelected
                                          ? Colors.lightBlueAccent
                                          : Colors.white60,
                                      fontSize: 12)),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: serviceCtrl,
                        style:
                            const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: 'Ou décris le service...',
                          labelStyle: const TextStyle(
                              color: Colors.white54),
                          filled: true,
                          fillColor: Colors.white10,
                          border: OutlineInputBorder(
                              borderRadius:
                                  BorderRadius.circular(12),
                              borderSide: BorderSide.none),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: linesCtrl,
                        keyboardType: TextInputType.number,
                        style:
                            const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText:
                              'Lignes à retirer (max ${p.totalLines - p.completedLines})',
                          labelStyle: const TextStyle(
                              color: Colors.white54),
                          prefixIcon: const Icon(
                              Icons.remove_circle_outline,
                              color: Colors.lightBlueAccent),
                          filled: true,
                          fillColor: Colors.white10,
                          border: OutlineInputBorder(
                              borderRadius:
                                  BorderRadius.circular(12),
                              borderSide: BorderSide.none),
                        ),
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              Colors.lightBlueAccent
                                  .withOpacity(0.25),
                          foregroundColor:
                              Colors.lightBlueAccent,
                          padding: const EdgeInsets.symmetric(
                              vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(12)),
                        ),
                        icon: const Icon(Icons.check),
                        label:
                            const Text('Valider le service'),
                        onPressed: () {
                          final service =
                              serviceCtrl.text.trim();
                          final lines = int.tryParse(
                                  linesCtrl.text.trim()) ??
                              0;
                          final maxLines = p.totalLines -
                              p.completedLines;
                          if (service.isEmpty || lines <= 0)
                            return;
                          final actual =
                              lines.clamp(0, maxLines);
                          Navigator.pop(ctx);
                          _confirmServiceReduction(
                              p, child, fp, service, actual);
                        },
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _confirmServiceReduction(PunishmentLines p, ChildModel child,
      FamilyProvider fp, String service, int lines) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        title: const Text('Confirmer le service',
            style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color:
                    Colors.lightBlueAccent.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: Colors.lightBlueAccent
                        .withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('🔧 $service',
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  Text(
                      '$lines ligne(s) retirée(s) de "${p.text}"',
                      style: const TextStyle(
                          color: Colors.white60, fontSize: 12)),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annuler',
                  style: TextStyle(color: Colors.white38))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor:
                    Colors.lightBlueAccent.withOpacity(0.25),
                foregroundColor: Colors.lightBlueAccent),
            onPressed: () async {
              await fp.updatePunishmentProgress(p.id, lines);
              if (mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context)
                    .showSnackBar(SnackBar(
                  content: Text(
                      '🔧 Service validé ! $lines ligne(s) retirée(s)'),
                  backgroundColor:
                      Colors.lightBlueAccent.withOpacity(0.8),
                ));
              }
            },
            child: const Text('Confirmer'),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════
  // NOTE SCOLAIRE
  // ══════════════════════════════════════════════════════════════

  void _showSchoolNoteDialog(
      PunishmentLines p, ChildModel child, FamilyProvider fp) {
    double note = 15;
    int getLinesFromNote(double n) {
      if (n >= 18) return 5;
      if (n >= 15) return 3;
      if (n >= 12) return 1;
      return 0;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setModalState) {
          final reduction = getLinesFromNote(note);
          final maxLines = p.totalLines - p.completedLines;
          final actual = reduction.clamp(0, maxLines);
          return DraggableScrollableSheet(
            initialChildSize: 0.55,
            minChildSize: 0.4,
            maxChildSize: 0.85,
            expand: false,
            builder: (_, scrollCtrl) => Container(
              decoration: const BoxDecoration(
                color: Color(0xFF0D1B2A),
                borderRadius: BorderRadius.vertical(
                    top: Radius.circular(24)),
              ),
              child: Column(
                children: [
                  const SizedBox(height: 12),
                  Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                          color: Colors.white38,
                          borderRadius:
                              BorderRadius.circular(2))),
                  const SizedBox(height: 16),
                  const Text('📚 Bonne note scolaire',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text('$maxLines lignes restantes',
                      style: const TextStyle(
                          color: Colors.white54, fontSize: 12)),
                  const SizedBox(height: 20),
                  Expanded(
                    child: ListView(
                      controller: scrollCtrl,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20),
                      children: [
                        Row(
                          mainAxisAlignment:
                              MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Note obtenue :',
                                style: TextStyle(
                                    color: Colors.white60,
                                    fontSize: 13)),
                            Text(
                                '${note.toStringAsFixed(1)} / 20',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16)),
                          ],
                        ),
                        Slider(
                          value: note,
                          min: 0,
                          max: 20,
                          divisions: 40,
                          activeColor: Colors.greenAccent,
                          inactiveColor: Colors.white12,
                          onChanged: (v) =>
                              setModalState(() => note = v),
                        ),
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                              color: Colors.white
                                  .withOpacity(0.05),
                              borderRadius:
                                  BorderRadius.circular(12),
                              border: Border.all(
                                  color: Colors.white12)),
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              const Text('📊 Barème :',
                                  style: TextStyle(
                                      color: Colors.white60,
                                      fontSize: 12,
                                      fontWeight:
                                          FontWeight.w600)),
                              const SizedBox(height: 8),
                              _baremeRow('18
