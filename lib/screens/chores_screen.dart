import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/family_provider.dart';
import '../models/child_model.dart';
import '../widgets/animated_background.dart';
import '../widgets/glass_card.dart';

class _WheelPainter extends CustomPainter {
  final List<ChildModel> children;
  final List<Color> colors;
  final double rotation;
  final List<bool> grayed;

  _WheelPainter({
    required this.children,
    required this.colors,
    required this.rotation,
    required this.grayed,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (children.isEmpty) return;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = min(size.width, size.height) / 2 - 4;
    final n = children.length;
    final sliceAngle = 2 * pi / n;

    for (int i = 0; i < n; i++) {
      final startAngle = rotation + i * sliceAngle - pi / 2;
      final color = grayed[i] ? Colors.grey.shade700 : colors[i % colors.length];

      final paint = Paint()..color = color..style = PaintingStyle.fill;
      canvas.drawArc(Rect.fromCircle(center: center, radius: radius), startAngle, sliceAngle, true, paint);

      final borderPaint = Paint()..color = Colors.black.withOpacity(0.35)..style = PaintingStyle.stroke..strokeWidth = 2;
      canvas.drawArc(Rect.fromCircle(center: center, radius: radius), startAngle, sliceAngle, true, borderPaint);

      final midAngle = startAngle + sliceAngle / 2;
      final textRadius = radius * 0.62;
      final tx = center.dx + textRadius * cos(midAngle);
      final ty = center.dy + textRadius * sin(midAngle);

      canvas.save();
      canvas.translate(tx, ty);
      canvas.rotate(midAngle + pi / 2);

      final name = children[i].name;
      final shortName = name.length > 7 ? '${name.substring(0, 6)}.' : name;

      final textPainter = TextPainter(
        text: TextSpan(
          text: shortName,
          style: TextStyle(
            color: grayed[i] ? Colors.white38 : Colors.white,
            fontSize: n <= 4 ? 14 : (n <= 6 ? 12 : 10),
            fontWeight: FontWeight.bold,
            shadows: const [Shadow(color: Colors.black54, blurRadius: 4)],
          ),
        ),
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.center,
      )..layout();
      textPainter.paint(canvas, Offset(-textPainter.width / 2, -textPainter.height / 2));
      canvas.restore();
    }

    canvas.drawCircle(center, radius * 0.12, Paint()..color = const Color(0xFF0D1B2E)..style = PaintingStyle.fill);
    canvas.drawCircle(center, radius * 0.12, Paint()..color = Colors.white24..style = PaintingStyle.stroke..strokeWidth = 2);
  }

  @override
  bool shouldRepaint(_WheelPainter old) =>
      old.rotation != rotation || old.children != children || old.grayed != grayed;
}

class ChoresScreen extends StatefulWidget {
  const ChoresScreen({super.key});

  @override
  State<ChoresScreen> createState() => _ChoresScreenState();
}

class _ChoresScreenState extends State<ChoresScreen> with TickerProviderStateMixin {
  late AnimationController _spinController;
  late Animation<double> _spinAnim;

  double _currentRotation = 0;
  int? _winnerIndex;
  bool _isSpinning = false;

  final Map<String, String> _doneTodayMap = {};
  final Set<String> _excludedIds = {};

  String _selectedChore = 'Vaisselle';
  final List<String> _chores = [
    'Vaisselle', 'Balayer', 'Passer l\'aspirateur', 'Sortir les poubelles',
    'Mettre la table', 'Débarrasser la table', 'Faire la lessive',
    'Ranger le salon', 'Nettoyer les WC', 'Faire son lit', 'Tâche personnalisée',
  ];
  final TextEditingController _customChoreCtrl = TextEditingController();

  static const _segmentColors = [
    Color(0xFF6C63FF), Color(0xFFFF6584), Color(0xFF43E97B), Color(0xFFFA8231),
    Color(0xFF00D2FF), Color(0xFFFFD93D), Color(0xFFFF5E57), Color(0xFF26de81),
  ];

  @override
  void initState() {
    super.initState();
    _spinController = AnimationController(vsync: this, duration: const Duration(milliseconds: 3500));
  }

  @override
  void dispose() {
    _spinController.dispose();
    _customChoreCtrl.dispose();
    super.dispose();
  }

  List<ChildModel> _availableChildren(List<ChildModel> all) =>
      all.where((c) => !_doneTodayMap.containsKey(c.id) && !_excludedIds.contains(c.id)).toList();

  void _spin(List<ChildModel> children) {
    final available = _availableChildren(children);
    if (available.isEmpty) { _showAllDoneDialog(); return; }
    if (_isSpinning) return;

    HapticFeedback.mediumImpact();
    final rng = Random();
    final n = available.length;
    final sliceAngle = 2 * pi / n;
    final winnerIdx = rng.nextInt(n);
    final extraSpins = 5 + rng.nextInt(3);
    final targetRotation = -winnerIdx * sliceAngle - sliceAngle / 2 + extraSpins * 2 * pi;
    final from = _currentRotation % (2 * pi);

    _spinAnim = Tween<double>(begin: from, end: targetRotation).animate(
      CurvedAnimation(parent: _spinController, curve: Curves.easeOutCubic),
    );

    setState(() { _isSpinning = true; _winnerIndex = null; });
    _spinController.reset();
    _spinController.forward().then((_) {
      final winner = available[winnerIdx];
      setState(() { _currentRotation = targetRotation; _isSpinning = false; _winnerIndex = children.indexOf(winner); });
      HapticFeedback.heavyImpact();
      _showWinnerDialog(winner, children);
    });
  }

  void _showWinnerDialog(ChildModel winner, List<ChildModel> allChildren) {
    final choreName = _selectedChore == 'Tâche personnalisée'
        ? (_customChoreCtrl.text.trim().isNotEmpty ? _customChoreCtrl.text.trim() : 'Tâche du jour')
        : _selectedChore;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🎉', style: TextStyle(fontSize: 52)),
            const SizedBox(height: 12),
            Text(winner.name, style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.cyanAccent.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.cyanAccent.withOpacity(0.4)),
              ),
              child: Text(choreName, style: const TextStyle(color: Colors.cyanAccent, fontSize: 16, fontWeight: FontWeight.w600), textAlign: TextAlign.center),
            ),
            const SizedBox(height: 16),
            const Text('C\'est son tour !', style: TextStyle(color: Colors.white70, fontSize: 14)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler', style: TextStyle(color: Colors.white38))),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.greenAccent, foregroundColor: Colors.black, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            icon: const Icon(Icons.check_circle, size: 18),
            label: const Text('Confirmer', style: TextStyle(fontWeight: FontWeight.bold)),
            onPressed: () { Navigator.pop(ctx); _confirmWinner(winner, choreName, allChildren); },
          ),
        ],
      ),
    );
  }

  void _confirmWinner(ChildModel winner, String choreName, List<ChildModel> allChildren) {
    final fp = context.read<FamilyProvider>();
    setState(() { _doneTodayMap[winner.id] = choreName; _winnerIndex = null; });
    fp.addPoints(winner.id, 3, 'Tâche ménagère : $choreName', category: 'ménage', isBonus: true);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('✅ ${winner.name} → $choreName (+3 pts)'),
      backgroundColor: Colors.green.shade700,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  void _showAllDoneDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Tout le monde a participé !', style: TextStyle(color: Colors.white)),
        content: const Text('Tous les enfants ont déjà reçu une tâche.\nAppuie sur "Réinitialiser" pour recommencer.', style: TextStyle(color: Colors.white70)),
        actions: [
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.cyanAccent, foregroundColor: Colors.black),
            icon: const Icon(Icons.refresh),
            label: const Text('Réinitialiser'),
            onPressed: () { Navigator.pop(ctx); setState(() => _doneTodayMap.clear()); },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final fp = context.watch<FamilyProvider>();
    final children = fp.children;

    return AnimatedBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          title: const Text('Tâches ménagères', style: TextStyle(color: Colors.white)),
          actions: [
            if (_doneTodayMap.isNotEmpty)
              TextButton.icon(
                onPressed: () => setState(() => _doneTodayMap.clear()),
                icon: const Icon(Icons.refresh, color: Colors.cyanAccent, size: 18),
                label: const Text('Reset', style: TextStyle(color: Colors.cyanAccent)),
              ),
          ],
        ),
        body: children.isEmpty
            ? const Center(child: Text('Aucun enfant enregistré', style: TextStyle(color: Colors.white54)))
            : SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                child: Column(
                  children: [
                    _buildChoreSelector(),
                    const SizedBox(height: 20),
                    _buildWheel(children),
                    const SizedBox(height: 20),
                    _buildSpinButton(children),
                    const SizedBox(height: 24),
                    _buildChildrenStatus(children),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildChoreSelector() {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Tâche à attribuer', style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8, runSpacing: 8,
            children: _chores.map((chore) {
              final isSelected = _selectedChore == chore;
              return GestureDetector(
                onTap: () => setState(() => _selectedChore = chore),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: isSelected ? Colors.cyanAccent.withOpacity(0.2) : Colors.white.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: isSelected ? Colors.cyanAccent : Colors.white24),
                  ),
                  child: Text(chore, style: TextStyle(color: isSelected ? Colors.cyanAccent : Colors.white60, fontSize: 12, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
                ),
              );
            }).toList(),
          ),
          if (_selectedChore == 'Tâche personnalisée') ...[
            const SizedBox(height: 12),
            TextField(
              controller: _customChoreCtrl,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Décris la tâche...',
                hintStyle: const TextStyle(color: Colors.white30),
                prefixIcon: const Icon(Icons.edit, color: Colors.cyanAccent),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.white24)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.cyanAccent)),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildWheel(List<ChildModel> children) {
    final grayed = children.map((c) => _doneTodayMap.containsKey(c.id) || _excludedIds.contains(c.id)).toList();

    return Stack(
      alignment: Alignment.topCenter,
      children: [
        Positioned(
          top: 0,
          child: Icon(Icons.arrow_drop_down, color: Colors.redAccent, size: 48, shadows: const [Shadow(color: Colors.black54, blurRadius: 8)]),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 20),
          child: AnimatedBuilder(
            animation: _isSpinning ? _spinAnim : const AlwaysStoppedAnimation(0.0),
            builder: (context, _) {
              final rot = _isSpinning ? _spinAnim.value : _currentRotation;
              return CustomPaint(
                size: const Size(300, 300),
                painter: _WheelPainter(children: children, colors: _segmentColors, rotation: rot, grayed: grayed),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSpinButton(List<ChildModel> children) {
    final available = _availableChildren(children);
    final allDone = available.isEmpty;

    return SizedBox(
      width: double.infinity, height: 56,
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: allDone ? Colors.grey.shade800 : const Color(0xFF6C63FF),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: _isSpinning ? 0 : 6,
        ),
        icon: _isSpinning
            ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            : Icon(allDone ? Icons.check_circle : Icons.casino_rounded, size: 24),
        label: Text(
          _isSpinning ? 'La roue tourne...' : allDone ? 'Tout le monde a participé !' : 'Lancer la roue (${available.length} dispo)',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        onPressed: _isSpinning || allDone ? null : () => _spin(children),
      ),
    );
  }

  Widget _buildChildrenStatus(List<ChildModel> children) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.people, color: Colors.white54, size: 16),
            const SizedBox(width: 8),
            const Text('Statut du jour', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w600, fontSize: 13)),
            const Spacer(),
            Text('${_doneTodayMap.length}/${children.length} fait(s)', style: const TextStyle(color: Colors.cyanAccent, fontSize: 12)),
          ]),
          const SizedBox(height: 12),
          ...children.map((child) {
            final done = _doneTodayMap.containsKey(child.id);
            final excluded = _excludedIds.contains(child.id);
            final choreDone = _doneTodayMap[child.id];
            return AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: excluded ? Colors.red.withOpacity(0.08) : done ? Colors.green.withOpacity(0.12) : Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: excluded ? Colors.redAccent.withOpacity(0.4) : done ? Colors.greenAccent.withOpacity(0.4) : Colors.white12),
              ),
              child: Row(children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: excluded ? Colors.red.withOpacity(0.2) : done ? Colors.green.withOpacity(0.2) : Colors.white10,
                  child: Text(
                    child.avatar.isNotEmpty ? child.avatar : child.name[0].toUpperCase(),
                    style: TextStyle(fontSize: child.avatar.isNotEmpty ? 16 : 13, color: excluded ? Colors.redAccent : done ? Colors.greenAccent : Colors.white54),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(child.name, style: TextStyle(color: excluded ? Colors.redAccent : done ? Colors.white : Colors.white70, fontWeight: done ? FontWeight.bold : FontWeight.normal, fontSize: 14)),
                  if (excluded)
                    const Text('Exclu de la roue', style: TextStyle(color: Colors.redAccent, fontSize: 11))
                  else if (done && choreDone != null)
                    Text(choreDone, style: const TextStyle(color: Colors.greenAccent, fontSize: 11))
                  else
                    const Text('En attente', style: TextStyle(color: Colors.white38, fontSize: 11)),
                ])),
                Icon(
                  excluded ? Icons.visibility_off : done ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
                  color: excluded ? Colors.redAccent : done ? Colors.greenAccent : Colors.white24,
                  size: 22,
                ),
                if (done)
                  IconButton(
                    icon: const Icon(Icons.undo, color: Colors.white38, size: 18),
                    tooltip: 'Annuler',
                    onPressed: () => setState(() => _doneTodayMap.remove(child.id)),
                  ),
                IconButton(
                  icon: Icon(excluded ? Icons.visibility : Icons.visibility_off, color: excluded ? Colors.greenAccent : Colors.redAccent, size: 18),
                  tooltip: excluded ? 'Inclure dans la roue' : 'Exclure de la roue',
                  onPressed: () => setState(() {
                    if (excluded) { _excludedIds.remove(child.id); } else { _excludedIds.add(child.id); }
                  }),
                ),
              ]),
            );
          }),
        ],
      ),
    );
  }
}
