import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/family_provider.dart';
import '../widgets/glass_card.dart';
import '../widgets/animated_background.dart';

// ─── Modèles ────────────────────────────────────────────────────────────────

class ChoreTask {
  final String id;
  final String title;
  final List<String> childIds; // enfants autorisés pour cette tâche
  final List<ChoreAssignment> assignments;

  ChoreTask({
    required this.id,
    required this.title,
    required this.childIds,
    required this.assignments,
  });

  ChoreTask copyWith({
    String? id,
    String? title,
    List<String>? childIds,
    List<ChoreAssignment>? assignments,
  }) =>
      ChoreTask(
        id: id ?? this.id,
        title: title ?? this.title,
        childIds: childIds ?? this.childIds,
        assignments: assignments ?? this.assignments,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'childIds': childIds,
        'assignments': assignments.map((a) => a.toJson()).toList(),
      };

  factory ChoreTask.fromJson(Map<String, dynamic> j) => ChoreTask(
        id: j['id'] as String,
        title: j['title'] as String,
        childIds: List<String>.from(j['childIds'] as List),
        assignments: (j['assignments'] as List)
            .map((a) => ChoreAssignment.fromJson(a as Map<String, dynamic>))
            .toList(),
      );
}

class ChoreAssignment {
  final String childId;
  final DateTime scheduledFor; // date prévue
  final String slot; // 'matin' | 'apres-midi' | 'soir'
  final bool isDone;

  ChoreAssignment({
    required this.childId,
    required this.scheduledFor,
    required this.slot,
    required this.isDone,
  });

  ChoreAssignment copyWith({
    String? childId,
    DateTime? scheduledFor,
    String? slot,
    bool? isDone,
  }) =>
      ChoreAssignment(
        childId: childId ?? this.childId,
        scheduledFor: scheduledFor ?? this.scheduledFor,
        slot: slot ?? this.slot,
        isDone: isDone ?? this.isDone,
      );

  Map<String, dynamic> toJson() => {
        'childId': childId,
        'scheduledFor': scheduledFor.toIso8601String(),
        'slot': slot,
        'isDone': isDone,
      };

  factory ChoreAssignment.fromJson(Map<String, dynamic> j) => ChoreAssignment(
        childId: j['childId'] as String,
        scheduledFor: DateTime.parse(j['scheduledFor'] as String),
        slot: j['slot'] as String,
        isDone: j['isDone'] as bool,
      );
}

// ─── Écran principal ─────────────────────────────────────────────────────────

class ChoresScreen extends StatefulWidget {
  const ChoresScreen({super.key});

  @override
  State<ChoresScreen> createState() => _ChoresScreenState();
}

class _ChoresScreenState extends State<ChoresScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animCtrl;
  late Animation<double> _fadeAnim;

  List<ChoreTask> _tasks = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _animCtrl =
        AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeIn);
    _loadTasks();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  // ── Persistance ────────────────────────────────────────────────────────────

  Future<void> _loadTasks() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('chore_tasks_v2');
    if (raw != null) {
      final list = jsonDecode(raw) as List;
      _tasks = list
          .map((e) => ChoreTask.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    setState(() => _loading = false);
    _animCtrl.forward();
  }

  Future<void> _saveTasks() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        'chore_tasks_v2', jsonEncode(_tasks.map((t) => t.toJson()).toList()));
  }

  // ── Logique métier ─────────────────────────────────────────────────────────

  /// Retourne true si l'enfant a déjà fait cette tâche aujourd'hui
  bool _doneToday(ChoreTask task, String childId) {
    final today = DateTime.now();
    return task.assignments.any((a) =>
        a.childId == childId &&
        a.isDone &&
        a.scheduledFor.year == today.year &&
        a.scheduledFor.month == today.month &&
        a.scheduledFor.day == today.day);
  }

  /// Enfants éligibles pour le tirage (pas encore fait la tâche aujourd'hui)
  List<String> _eligibleChildren(ChoreTask task) {
    return task.childIds.where((id) => !_doneToday(task, id)).toList();
  }

  void _addTask(String title, List<String> childIds) {
    final task = ChoreTask(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: title,
      childIds: childIds,
      assignments: [],
    );
    setState(() => _tasks.add(task));
    _saveTasks();
  }

  void _deleteTask(String taskId) {
    setState(() => _tasks.removeWhere((t) => t.id == taskId));
    _saveTasks();
  }

  void _markDone(ChoreTask task, String childId, String slot, DateTime date) {
    final idx = _tasks.indexWhere((t) => t.id == task.id);
    if (idx == -1) return;
    final newAssignment = ChoreAssignment(
      childId: childId,
      scheduledFor: date,
      slot: slot,
      isDone: true,
    );
    final updated = task.copyWith(
        assignments: [...task.assignments, newAssignment]);
    setState(() => _tasks[idx] = updated);
    _saveTasks();
  }

  // ── Dialogs ────────────────────────────────────────────────────────────────

  Future<void> _showAddTaskDialog() async {
    final fp = context.read<FamilyProvider>();
    final children = fp.children;
    final titleCtrl = TextEditingController();
    final selected = <String>{};

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx2, setSt) => AlertDialog(
          backgroundColor: const Color(0xFF1E1E2E),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Nouvelle tâche',
              style: TextStyle(color: Colors.white)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: titleCtrl,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Ex : Nettoyer la table',
                    hintStyle: const TextStyle(color: Colors.white38),
                    filled: true,
                    fillColor: Colors.white10,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 16),
                const Text('Enfants participants :',
                    style: TextStyle(color: Colors.white70, fontSize: 13)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: children.map((child) {
                    final on = selected.contains(child.id);
                    return FilterChip(
                      label: Text(child.name,
                          style: TextStyle(
                              color: on ? Colors.white : Colors.white70)),
                      selected: on,
                      onSelected: (v) =>
                          setSt(() => v ? selected.add(child.id) : selected.remove(child.id)),
                      selectedColor: Colors.purpleAccent,
                      backgroundColor: Colors.white10,
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Annuler',
                    style: TextStyle(color: Colors.white38))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.purpleAccent,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12))),
              onPressed: () {
                if (titleCtrl.text.trim().isNotEmpty && selected.isNotEmpty) {
                  _addTask(titleCtrl.text.trim(), selected.toList());
                  Navigator.pop(ctx);
                }
              },
              child:
                  const Text('Créer', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showDeleteConfirm(ChoreTask task) async {
    final ok = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: const Color(0xFF1E1E2E),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title:
                const Text('Supprimer ?', style: TextStyle(color: Colors.white)),
            content: Text('Supprimer la tâche « ${task.title} » ?',
                style: const TextStyle(color: Colors.white70)),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Annuler',
                      style: TextStyle(color: Colors.white38))),
              ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Supprimer',
                      style: TextStyle(color: Colors.white))),
            ],
          ),
        ) ??
        false;
    if (ok) _deleteTask(task.id);
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          const AnimatedBackground(),
          SafeArea(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : FadeTransition(
                    opacity: _fadeAnim,
                    child: Column(
                      children: [
                        _buildHeader(),
                        Expanded(
                          child: _tasks.isEmpty
                              ? _buildEmpty()
                              : ListView.builder(
                                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                                  itemCount: _tasks.length,
                                  itemBuilder: (_, i) =>
                                      _buildTaskCard(_tasks[i]),
                                ),
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddTaskDialog,
        backgroundColor: Colors.purpleAccent,
        icon: const Icon(Icons.add, color: Colors.white),
        label:
            const Text('Ajouter une tâche', style: TextStyle(color: Colors.white)),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          const Text('🎡',
              style: TextStyle(fontSize: 28)),
          const SizedBox(width: 12),
          const Text('Tâches ménagères',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold)),
          const Spacer(),
          Text('${_tasks.length} tâche(s)',
              style: const TextStyle(color: Colors.white54, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('🏠', style: TextStyle(fontSize: 64)),
          const SizedBox(height: 16),
          const Text('Aucune tâche pour l\'instant',
              style: TextStyle(color: Colors.white70, fontSize: 16)),
          const SizedBox(height: 8),
          const Text('Appuyez sur + pour créer votre première tâche',
              style: TextStyle(color: Colors.white38, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildTaskCard(ChoreTask task) {
    final fp = context.watch<FamilyProvider>();
    final eligible = _eligibleChildren(task);
    final allDone = eligible.isEmpty && task.childIds.isNotEmpty;

    return GlassCard(
      margin: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // En-tête tâche
          Row(
            children: [
              const Text('🧹', style: TextStyle(fontSize: 22)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(task.title,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold)),
              ),
              if (allDone)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8)),
                  child: const Text('✅ Tous faits',
                      style: TextStyle(color: Colors.green, fontSize: 11)),
                ),
              IconButton(
                icon: const Icon(Icons.delete_outline,
                    color: Colors.redAccent, size: 20),
                onPressed: () => _showDeleteConfirm(task),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Participants
          Wrap(
            spacing: 6,
            children: task.childIds.map((id) {
              final child =
                  fp.children.firstWhere((c) => c.id == id, orElse: () => fp.children.first);
              final done = _doneToday(task, id);
              return Chip(
                label: Text(child.name,
                    style: TextStyle(
                        color: done ? Colors.white38 : Colors.white,
                        fontSize: 12,
                        decoration: done
                            ? TextDecoration.lineThrough
                            : null)),
                backgroundColor:
                    done ? Colors.white10 : Colors.purpleAccent.withOpacity(0.3),
                padding: EdgeInsets.zero,
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
          // Bouton roue
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: allDone
                    ? Colors.white12
                    : Colors.purpleAccent,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              icon: Text(allDone ? '🔄' : '🎡',
                  style: const TextStyle(fontSize: 18)),
              label: Text(
                allDone
                    ? 'Réinitialiser pour demain'
                    : 'Tourner la roue',
                style: const TextStyle(color: Colors.white, fontSize: 14),
              ),
              onPressed: () {
                if (allDone) {
                  // Pas de reset manuel : ça se remet auto le lendemain
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text(
                          'Tous les enfants ont fait cette tâche aujourd\'hui 🎉')));
                } else {
                  _spinWheel(task, eligible, fp);
                }
              },
            ),
          ),
          // Historique du jour
          ..._buildTodayHistory(task, fp),
        ],
      ),
    );
  }

  List<Widget> _buildTodayHistory(ChoreTask task, FamilyProvider fp) {
    final today = DateTime.now();
    final todayAssignments = task.assignments.where((a) =>
        a.isDone &&
        a.scheduledFor.year == today.year &&
        a.scheduledFor.month == today.month &&
        a.scheduledFor.day == today.day).toList();

    if (todayAssignments.isEmpty) return [];

    return [
      const SizedBox(height: 8),
      const Divider(color: Colors.white12),
      const Text('Aujourd\'hui :',
          style: TextStyle(color: Colors.white38, fontSize: 12)),
      const SizedBox(height: 4),
      ...todayAssignments.map((a) {
        final child = fp.children.firstWhere((c) => c.id == a.childId,
            orElse: () => fp.children.first);
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.green, size: 14),
              const SizedBox(width: 6),
              Text('${child.name} – ${a.slot}',
                  style: const TextStyle(color: Colors.white60, fontSize: 12)),
            ],
          ),
        );
      }),
    ];
  }

  // ── Roue de la fortune ─────────────────────────────────────────────────────

  Future<void> _spinWheel(
      ChoreTask task, List<String> eligible, FamilyProvider fp) async {
    final children =
        eligible.map((id) => fp.children.firstWhere((c) => c.id == id)).toList();

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _WheelDialog(children: children),
    );

    if (result == null) return;

    final winnerId = result['childId'] as String;
    final slot = result['slot'] as String;
    final date = result['date'] as DateTime;

    _markDone(task, winnerId, slot, date);

    final winnerName =
        fp.children.firstWhere((c) => c.id == winnerId).name;

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
            '🎡 $winnerName s\'occupe de « ${task.title} » ce $slot !'),
        backgroundColor: Colors.purpleAccent,
        duration: const Duration(seconds: 3),
      ));
    }
  }
}

// ─── Dialog Roue ─────────────────────────────────────────────────────────────

class _WheelDialog extends StatefulWidget {
  final List<dynamic> children;
  const _WheelDialog({required this.children});

  @override
  State<_WheelDialog> createState() => _WheelDialogState();
}

class _WheelDialogState extends State<_WheelDialog>
    with SingleTickerProviderStateMixin {
  late AnimationController _spinCtrl;
  late Animation<double> _spinAnim;
  bool _spinning = false;
  int? _winnerIndex;
  String _slot = 'matin';
  bool _tomorrow = false;

  static const _colors = [
    Color(0xFF7C3AED),
    Color(0xFF2563EB),
    Color(0xFF059669),
    Color(0xFFD97706),
    Color(0xFFDC2626),
    Color(0xFF7C3AED),
  ];

  @override
  void initState() {
    super.initState();
    _spinCtrl = AnimationController(
        vsync: this, duration: const Duration(seconds: 3));
    _spinAnim = CurvedAnimation(parent: _spinCtrl, curve: Curves.decelerate);
  }

  @override
  void dispose() {
    _spinCtrl.dispose();
    super.dispose();
  }

  void _spin() {
    if (_spinning) return;
    final rng = Random();
    final winner = rng.nextInt(widget.children.length);
    final extraTurns = 5 + rng.nextInt(3);
    final targetAngle =
        (extraTurns * 2 * pi) + (winner / widget.children.length) * 2 * pi;

    setState(() {
      _spinning = true;
      _winnerIndex = null;
    });

    _spinCtrl.reset();
    _spinAnim = Tween<double>(begin: 0, end: targetAngle)
        .animate(CurvedAnimation(parent: _spinCtrl, curve: Curves.decelerate));

    _spinCtrl.forward().then((_) {
      setState(() {
        _spinning = false;
        _winnerIndex = winner;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final n = widget.children.length;

    return Dialog(
      backgroundColor: const Color(0xFF1E1E2E),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🎡 Qui fait la tâche ?',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 24),

            // Roue
            SizedBox(
              width: 220,
              height: 220,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  AnimatedBuilder(
                    animation: _spinAnim,
                    builder: (_, __) => Transform.rotate(
                      angle: _spinAnim.value,
                      child: CustomPaint(
                        size: const Size(220, 220),
                        painter: _WheelPainter(
                          children: widget.children,
                          colors: _colors,
                        ),
                      ),
                    ),
                  ),
                  // Flèche indicatrice
                  const Positioned(
                    top: 4,
                    child: Icon(Icons.arrow_drop_down,
                        color: Colors.white, size: 36),
                  ),
                  // Centre
                  Container(
                    width: 40,
                    height: 40,
                    decoration: const BoxDecoration(
                        color: Color(0xFF1E1E2E), shape: BoxShape.circle),
                    child: const Icon(Icons.star,
                        color: Colors.amber, size: 20),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Résultat
            if (_winnerIndex != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                    color: Colors.purpleAccent.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                        color: Colors.purpleAccent.withOpacity(0.4))),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('🎉 ', style: TextStyle(fontSize: 20)),
                    Text(
                      widget.children[_winnerIndex!].name,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // Créneau
              const Text('Créneau :',
                  style: TextStyle(color: Colors.white60, fontSize: 13)),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: ['matin', 'après-midi', 'soir'].map((s) {
                  final sel = _slot == s;
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: ChoiceChip(
                      label: Text(s,
                          style: TextStyle(
                              color: sel ? Colors.white : Colors.white60,
                              fontSize: 12)),
                      selected: sel,
                      onSelected: (_) => setState(() => _slot = s),
                      selectedColor: Colors.purpleAccent,
                      backgroundColor: Colors.white10,
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 8),
              // Aujourd'hui / demain
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Pour demain ?',
                      style: TextStyle(color: Colors.white60, fontSize: 13)),
                  const SizedBox(width: 8),
                  Switch(
                    value: _tomorrow,
                    onChanged: (v) => setState(() => _tomorrow = v),
                    activeColor: Colors.purpleAccent,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Colors.white24),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12))),
                      onPressed: _spin,
                      child: const Text('🔄 Retirer',
                          style: TextStyle(color: Colors.white70)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.purpleAccent,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12))),
                      onPressed: () {
                        final date = _tomorrow
                            ? DateTime.now().add(const Duration(days: 1))
                            : DateTime.now();
                        Navigator.pop(context, {
                          'childId': widget.children[_winnerIndex!].id,
                          'slot': _slot,
                          'date': date,
                        });
                      },
                      child: const Text('✅ Valider',
                          style: TextStyle(color: Colors.white)),
                    ),
                  ),
                ],
              ),
            ] else ...[
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.purpleAccent,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 32, vertical: 14)),
                icon: const Text('🎡', style: TextStyle(fontSize: 20)),
                label: Text(
                    _spinning ? 'En cours...' : 'Lancer la roue !',
                    style: const TextStyle(
                        color: Colors.white, fontSize: 16)),
                onPressed: _spinning ? null : _spin,
              ),
            ],

            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.pop(context, null),
              child: const Text('Annuler',
                  style: TextStyle(color: Colors.white38)),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Painter ─────────────────────────────────────────────────────────────────

class _WheelPainter extends CustomPainter {
  final List<dynamic> children;
  final List<Color> colors;

  _WheelPainter({required this.children, required this.colors});

  @override
  void paint(Canvas canvas, Size size) {
    final n = children.length;
    final sweep = 2 * pi / n;
    final radius = size.width / 2;
    final center = Offset(radius, radius);
    final paint = Paint()..style = PaintingStyle.fill;
    final textPainter = TextPainter(textDirection: TextDirection.ltr);

    for (int i = 0; i < n; i++) {
      paint.color = colors[i % colors.length];
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        i * sweep - pi / 2,
        sweep,
        true,
        paint,
      );

      // Texte
      final angle = i * sweep - pi / 2 + sweep / 2;
      final textRadius = radius * 0.65;
      final textOffset = Offset(
        center.dx + textRadius * cos(angle),
        center.dy + textRadius * sin(angle),
      );

      textPainter.text = TextSpan(
        text: children[i].name.length > 6
            ? children[i].name.substring(0, 6)
            : children[i].name,
        style: const TextStyle(
            color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
      );
      textPainter.layout();
      canvas.save();
      canvas.translate(textOffset.dx, textOffset.dy);
      canvas.rotate(angle + pi / 2);
      canvas.translate(-textPainter.width / 2, -textPainter.height / 2);
      textPainter.paint(canvas, Offset.zero);
      canvas.restore();
    }

    // Bordure
    paint
      ..color = Colors.white.withOpacity(0.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawCircle(center, radius, paint);

    for (int i = 0; i < n; i++) {
      final angle = i * sweep - pi / 2;
      paint.color = Colors.white.withOpacity(0.15);
      canvas.drawLine(
        center,
        Offset(center.dx + radius * cos(angle),
            center.dy + radius * sin(angle)),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_WheelPainter old) => true;
}
