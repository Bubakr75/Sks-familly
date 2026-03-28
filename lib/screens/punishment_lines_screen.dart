import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/family_provider.dart';
import '../widgets/animated_background.dart';
import '../widgets/glass_card.dart';
import '../widgets/tv_focus_wrapper.dart';

// ═══════════════════════════════════════════════════════════
//  CAHIER OUVERT — animation d'ouverture
// ═══════════════════════════════════════════════════════════
class _NotebookOpenAnimation extends StatefulWidget {
  final VoidCallback onComplete;
  const _NotebookOpenAnimation({required this.onComplete});
  @override
  State<_NotebookOpenAnimation> createState() => _NotebookOpenAnimationState();
}

class _NotebookOpenAnimationState extends State<_NotebookOpenAnimation> with TickerProviderStateMixin {
  late AnimationController _openCtrl;
  late Animation<double> _coverRotation;
  late Animation<double> _pagesFade;
  late AnimationController _penCtrl;
  late Animation<double> _penX;
  late Animation<double> _penY;

  @override
  void initState() {
    super.initState();
    _openCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1800))..forward();
    _coverRotation = Tween<double>(begin: 0.0, end: -pi * 0.45).animate(
      CurvedAnimation(parent: _openCtrl, curve: const Interval(0.0, 0.5, curve: Curves.easeOutBack)),
    );
    _pagesFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _openCtrl, curve: const Interval(0.3, 0.6, curve: Curves.easeIn)),
    );

    _penCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 2000));
    _penX = TweenSequence<double>([
      TweenSequenceItem(tween: Tween<double>(begin: 0.0, end: 1.0), weight: 30),
      TweenSequenceItem(tween: Tween<double>(begin: 1.0, end: 0.0), weight: 10),
      TweenSequenceItem(tween: Tween<double>(begin: 0.0, end: 0.8), weight: 30),
      TweenSequenceItem(tween: Tween<double>(begin: 0.8, end: 0.0), weight: 10),
      TweenSequenceItem(tween: Tween<double>(begin: 0.0, end: 0.6), weight: 20),
    ]).animate(CurvedAnimation(parent: _penCtrl, curve: Curves.easeInOut));
    _penY = TweenSequence<double>([
      TweenSequenceItem(tween: Tween<double>(begin: 0.0, end: 0.0), weight: 30),
      TweenSequenceItem(tween: Tween<double>(begin: 0.0, end: 0.25), weight: 10),
      TweenSequenceItem(tween: Tween<double>(begin: 0.25, end: 0.25), weight: 30),
      TweenSequenceItem(tween: Tween<double>(begin: 0.25, end: 0.5), weight: 10),
      TweenSequenceItem(tween: Tween<double>(begin: 0.5, end: 0.5), weight: 20),
    ]).animate(CurvedAnimation(parent: _penCtrl, curve: Curves.easeInOut));

    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted) _penCtrl.forward().then((_) {
        Future.delayed(const Duration(milliseconds: 400), () {
          if (mounted) widget.onComplete();
        });
      });
    });
  }

  @override
  void dispose() {
    _openCtrl.dispose();
    _penCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_openCtrl, _penCtrl]),
      builder: (context, _) {
        return Center(
          child: SizedBox(
            width: 280,
            height: 340,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Page blanche (fond)
                Opacity(
                  opacity: _pagesFade.value,
                  child: Container(
                    width: 240,
                    height: 300,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF8E1),
                      borderRadius: BorderRadius.circular(4),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 10, offset: const Offset(2, 4))],
                    ),
                    child: CustomPaint(painter: _LinesPainter(_penCtrl.value)),
                  ),
                ),
                // Couverture du cahier
                Positioned(
                  left: 20,
                  child: Transform(
                    alignment: Alignment.centerLeft,
                    transform: Matrix4.identity()
                      ..setEntry(3, 2, 0.002)
                      ..rotateY(_coverRotation.value),
                    child: Container(
                      width: 240,
                      height: 300,
                      decoration: BoxDecoration(
                        color: const Color(0xFFD32F2F),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: const Color(0xFF8B0000), width: 2),
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.4), blurRadius: 8, offset: const Offset(3, 3))],
                      ),
                      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                        const Icon(Icons.menu_book_rounded, color: Colors.white70, size: 48),
                        const SizedBox(height: 8),
                        Text('PUNITION', style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 3)),
                      ]),
                    ),
                  ),
                ),
                // Stylo animé
                if (_penCtrl.isAnimating || _penCtrl.isCompleted)
                  Positioned(
                    left: 40 + _penX.value * 160,
                    top: 60 + _penY.value * 160,
                    child: Opacity(
                      opacity: _pagesFade.value,
                      child: Transform.rotate(
                        angle: 0.3,
                        child: const Text('✒️', style: TextStyle(fontSize: 24)),
                      ),
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

class _LinesPainter extends CustomPainter {
  final double progress;
  _LinesPainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFBBDEFB).withOpacity(0.4)
      ..strokeWidth = 0.8;
    // Lignes horizontales
    for (int i = 1; i <= 12; i++) {
      final y = i * size.height / 13;
      canvas.drawLine(Offset(20, y), Offset(size.width - 20, y), paint);
    }
    // Marge rouge
    final marginPaint = Paint()
      ..color = Colors.redAccent.withOpacity(0.3)
      ..strokeWidth = 1.5;
    canvas.drawLine(Offset(40, 10), Offset(40, size.height - 10), marginPaint);

    // Texte écrit progressivement
    if (progress > 0) {
      final textPaint = Paint()
        ..color = const Color(0xFF1A237E).withOpacity(0.7)
        ..strokeWidth = 1.2
        ..style = PaintingStyle.stroke;
      final linesWritten = (progress * 3).floor();
      for (int i = 0; i < linesWritten && i < 3; i++) {
        final y = (i + 2) * size.height / 13;
        final lineProgress = i < linesWritten - 1 ? 1.0 : (progress * 3 - i).clamp(0.0, 1.0);
        final endX = 50 + (size.width - 80) * lineProgress;
        // Zigzag simulant de l'écriture
        final path = Path()..moveTo(50, y);
        for (double x = 50; x < endX; x += 4) {
          path.lineTo(x + 2, y + (x.toInt() % 8 < 4 ? -1.5 : 1.5));
        }
        canvas.drawPath(path, textPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _LinesPainter old) => old.progress != progress;
}

// ═══════════════════════════════════════════════════════════
//  BARRE DE PROGRESSION ANIMÉE
// ═══════════════════════════════════════════════════════════
class _AnimatedProgressBar extends StatelessWidget {
  final double progress;
  final Color color;
  const _AnimatedProgressBar({required this.progress, required this.color});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: progress),
      duration: const Duration(milliseconds: 800),
      curve: Curves.easeOutCubic,
      builder: (context, val, _) {
        return Stack(
          children: [
            Container(
              height: 8,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.08),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            FractionallySizedBox(
              widthFactor: val.clamp(0.0, 1.0),
              child: Container(
                height: 8,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(4),
                  gradient: LinearGradient(colors: [
                    color.withOpacity(0.6),
                    color,
                  ]),
                  boxShadow: [BoxShadow(color: color.withOpacity(0.4), blurRadius: 6)],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

// ═══════════════════════════════════════════════════════════
//  ANIMATION PUNITION TERMINÉE (confettis + check)
// ═══════════════════════════════════════════════════════════
class _PunishmentCompleteAnimation extends StatefulWidget {
  final VoidCallback onComplete;
  const _PunishmentCompleteAnimation({required this.onComplete});
  @override
  State<_PunishmentCompleteAnimation> createState() => _PunishmentCompleteAnimationState();
}

class _PunishmentCompleteAnimationState extends State<_PunishmentCompleteAnimation> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;
  late Animation<double> _checkDraw;
  final _rng = Random();
  late List<_ConfettiPiece> _confetti;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1800))
      ..forward().then((_) => widget.onComplete());
    _scale = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: const Interval(0.0, 0.4, curve: Curves.elasticOut)),
    );
    _checkDraw = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: const Interval(0.2, 0.6, curve: Curves.easeOut)),
    );
    _confetti = List.generate(30, (i) => _ConfettiPiece(
      x: _rng.nextDouble(),
      speed: 100 + _rng.nextDouble() * 200,
      size: 4 + _rng.nextDouble() * 6,
      color: [Colors.greenAccent, Colors.amber, Colors.cyanAccent, Colors.pinkAccent, Colors.white][_rng.nextInt(5)],
      angle: _rng.nextDouble() * 2 * pi,
      rotSpeed: (_rng.nextDouble() - 0.5) * 6,
    ));
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
        return Stack(alignment: Alignment.center, children: [
          Container(color: Colors.green.withOpacity(0.06 * (1 - _ctrl.value))),
          CustomPaint(size: Size.infinite, painter: _ConfettiPainter(_confetti, _ctrl.value)),
          ScaleTransition(
            scale: _scale,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(
                width: 80, height: 80,
                decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.greenAccent.withOpacity(0.2),
                  border: Border.all(color: Colors.greenAccent, width: 3)),
                child: CustomPaint(painter: _CheckPainter(_checkDraw.value)),
              ),
              const SizedBox(height: 16),
              const Text('TERMINÉ !', style: TextStyle(color: Colors.greenAccent, fontSize: 28, fontWeight: FontWeight.w900, letterSpacing: 4)),
              const SizedBox(height: 4),
              Text('Punition accomplie', style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 14)),
            ]),
          ),
        ]);
      },
    );
  }
}

class _ConfettiPiece {
  final double x, speed, size, angle, rotSpeed;
  final Color color;
  _ConfettiPiece({required this.x, required this.speed, required this.size, required this.color, required this.angle, required this.rotSpeed});
}

class _ConfettiPainter extends CustomPainter {
  final List<_ConfettiPiece> pieces;
  final double t;
  _ConfettiPainter(this.pieces, this.t);

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in pieces) {
      final dx = p.x * size.width + sin(p.angle + t * 4) * 20;
      final dy = -20 + p.speed * t;
      if (dy > size.height) continue;
      final opacity = (1.0 - t * 0.6).clamp(0.0, 1.0);
      canvas.save();
      canvas.translate(dx, dy);
      canvas.rotate(p.rotSpeed * t);
      final paint = Paint()..color = p.color.withOpacity(opacity);
      canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: Offset.zero, width: p.size, height: p.size * 0.6), const Radius.circular(1)), paint);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiPainter old) => true;
}

class _CheckPainter extends CustomPainter {
  final double progress;
  _CheckPainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    if (progress == 0) return;
    final paint = Paint()
      ..color = Colors.greenAccent
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final path = Path();
    final p1 = Offset(size.width * 0.25, size.height * 0.52);
    final p2 = Offset(size.width * 0.42, size.height * 0.68);
    final p3 = Offset(size.width * 0.75, size.height * 0.32);

    if (progress <= 0.5) {
      final t = progress / 0.5;
      path.moveTo(p1.dx, p1.dy);
      path.lineTo(p1.dx + (p2.dx - p1.dx) * t, p1.dy + (p2.dy - p1.dy) * t);
    } else {
      final t = (progress - 0.5) / 0.5;
      path.moveTo(p1.dx, p1.dy);
      path.lineTo(p2.dx, p2.dy);
      path.lineTo(p2.dx + (p3.dx - p2.dx) * t, p2.dy + (p3.dy - p2.dy) * t);
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _CheckPainter old) => old.progress != progress;
}

// ═══════════════════════════════════════════════════════════
//  DIALOGUES ANIMÉS
// ═══════════════════════════════════════════════════════════
Future<void> showNotebookAnimation(BuildContext context) {
  return showGeneralDialog(
    context: context,
    barrierDismissible: false,
    barrierColor: Colors.black87,
    transitionDuration: const Duration(milliseconds: 100),
    pageBuilder: (ctx, _, __) => Material(
      color: Colors.transparent,
      child: _NotebookOpenAnimation(onComplete: () => Navigator.of(ctx).pop()),
    ),
  );
}

Future<void> showPunishmentCompleteAnimation(BuildContext context) {
  return showGeneralDialog(
    context: context,
    barrierDismissible: false,
    barrierColor: Colors.black87,
    transitionDuration: const Duration(milliseconds: 100),
    pageBuilder: (ctx, _, __) => Material(
      color: Colors.transparent,
      child: _PunishmentCompleteAnimation(onComplete: () => Navigator.of(ctx).pop()),
    ),
  );
}

// ═══════════════════════════════════════════════════════════
//  PUNISHMENT LINES SCREEN
// ═══════════════════════════════════════════════════════════
class PunishmentLinesScreen extends StatefulWidget {
  const PunishmentLinesScreen({super.key});
  @override
  State<PunishmentLinesScreen> createState() => _PunishmentLinesScreenState();
}

class _PunishmentLinesScreenState extends State<PunishmentLinesScreen> {

  void _showAddPunishment() async {
    // Animation cahier qui s'ouvre
    await showNotebookAnimation(context);
    if (!mounted) return;

    final provider = context.read<FamilyProvider>();
    final children = provider.children;
    String? selectedChildId;
    String reason = '';
    int lines = 10;
    final reasonController = TextEditingController();

    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(builder: (context, setModalState) {
          return DraggableScrollableSheet(
            initialChildSize: 0.7, minChildSize: 0.5, maxChildSize: 0.9,
            builder: (context, scrollController) {
              return Container(
                decoration: BoxDecoration(color: Colors.grey[900]?.withOpacity(0.95), borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
                child: ListView(controller: scrollController, padding: const EdgeInsets.all(20), children: [
                  Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)))),
                  const SizedBox(height: 16),
                  // Titre avec icône animée
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    TweenAnimationBuilder<double>(
                      tween: Tween<double>(begin: 0, end: 1),
                      duration: const Duration(milliseconds: 600),
                      curve: Curves.elasticOut,
                      builder: (context, val, child) => Transform.scale(scale: val, child: child),
                      child: const Text('📕', style: TextStyle(fontSize: 28)),
                    ),
                    const SizedBox(width: 10),
                    const Text('Nouvelle punition', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                  ]),
                  const SizedBox(height: 24),
                  const Text('Enfant', style: TextStyle(color: Colors.white70, fontSize: 14)),
                  const SizedBox(height: 8),
                  Wrap(spacing: 8, runSpacing: 8, children: children.map((child) {
                    final isSelected = selectedChildId == child.id;
                    return TvFocusWrapper(
                      autofocus: children.first.id == child.id,
                      onTap: () => setModalState(() => selectedChildId = child.id),
                      child: GestureDetector(
                        onTap: () => setModalState(() => selectedChildId = child.id),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          decoration: BoxDecoration(
                            color: isSelected ? Colors.redAccent.withOpacity(0.2) : Colors.white.withOpacity(0.06),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: isSelected ? Colors.redAccent : Colors.white24),
                          ),
                          child: Text(child.name, style: TextStyle(color: isSelected ? Colors.redAccent : Colors.white70, fontWeight: FontWeight.w600)),
                        ),
                      ),
                    );
                  }).toList()),
                  const SizedBox(height: 20),
                  const Text('Raison', style: TextStyle(color: Colors.white70, fontSize: 14)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: reasonController, style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Ex: Insolence, bagarre...', hintStyle: const TextStyle(color: Colors.white38),
                      filled: true, fillColor: Colors.white.withOpacity(0.06),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Colors.redAccent)),
                    ),
                    onChanged: (val) => reason = val,
                  ),
                  const SizedBox(height: 20),
                  const Text('Nombre de lignes', style: TextStyle(color: Colors.white70, fontSize: 14)),
                  const SizedBox(height: 8),
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    TvFocusWrapper(
                      onTap: () { if (lines > 1) setModalState(() => lines--); },
                      child: GestureDetector(
                        onTap: () { if (lines > 1) setModalState(() => lines--); },
                        child: Container(width: 44, height: 44, decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withOpacity(0.1), border: Border.all(color: Colors.white24)),
                          child: const Icon(Icons.remove, color: Colors.white70)),
                      ),
                    ),
                    const SizedBox(width: 24),
                    // Animation du compteur
                    TweenAnimationBuilder<double>(
                      tween: Tween<double>(begin: lines.toDouble(), end: lines.toDouble()),
                      duration: const Duration(milliseconds: 200),
                      builder: (context, val, _) => Text('${val.round()}', style: const TextStyle(color: Colors.redAccent, fontSize: 36, fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(width: 24),
                    TvFocusWrapper(
                      onTap: () { if (lines < 100) setModalState(() => lines++); },
                      child: GestureDetector(
                        onTap: () { if (lines < 100) setModalState(() => lines++); },
                        child: Container(width: 44, height: 44, decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withOpacity(0.1), border: Border.all(color: Colors.white24)),
                          child: const Icon(Icons.add, color: Colors.white70)),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 8),
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [5, 10, 20, 50].map((val) {
                    return Padding(padding: const EdgeInsets.symmetric(horizontal: 4), child: TvFocusWrapper(
                      onTap: () => setModalState(() => lines = val),
                      child: OutlinedButton(
                        onPressed: () => setModalState(() => lines = val),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: lines == val ? Colors.redAccent : Colors.white54,
                          side: BorderSide(color: lines == val ? Colors.redAccent : Colors.white24),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        ),
                        child: Text('$val'),
                      ),
                    ));
                  }).toList()),
                  const SizedBox(height: 28),
                  SizedBox(width: double.infinity, height: 52, child: TvFocusWrapper(
                    onTap: () {
                      if (selectedChildId == null || reason.isEmpty) {
                        ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Sélectionnez un enfant et une raison'), backgroundColor: Colors.orangeAccent));
                        return;
                      }
                      provider.addPunishment(selectedChildId!, reason, lines);
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(this.context).showSnackBar(SnackBar(content: Text('$lines ligne(s) de punition ajoutée(s)'), backgroundColor: Colors.redAccent));
                    },
                    child: ElevatedButton.icon(
                      onPressed: () {
                        if (selectedChildId == null || reason.isEmpty) {
                          ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Sélectionnez un enfant et une raison'), backgroundColor: Colors.orangeAccent));
                          return;
                        }
                        provider.addPunishment(selectedChildId!, reason, lines);
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(this.context).showSnackBar(SnackBar(content: Text('$lines ligne(s) de punition ajoutée(s)'), backgroundColor: Colors.redAccent));
                      },
                      icon: const Icon(Icons.gavel),
                      label: const Text('Créer la punition', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent.shade700, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                    ),
                  )),
                ]),
              );
            },
          );
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: Row(mainAxisSize: MainAxisSize.min, children: [
            TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0, end: 1),
              duration: const Duration(milliseconds: 800),
              curve: Curves.elasticOut,
              builder: (context, val, child) => Transform.scale(scale: val, child: child),
              child: const Text('📕', style: TextStyle(fontSize: 22)),
            ),
            const SizedBox(width: 8),
            const Text('Lignes de punition'),
          ]),
          backgroundColor: Colors.transparent, elevation: 0,
        ),
        body: Consumer<FamilyProvider>(
          builder: (context, provider, _) {
            final children = provider.children;
            if (children.isEmpty) {
              return const Center(child: Text('Aucun enfant enregistré', style: TextStyle(color: Colors.white54)));
            }
            return Column(
              children: [
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                    itemCount: children.length,
                    itemBuilder: (context, index) {
                      final child = children[index];
                      final punishments = provider.punishments.where((p) => p.childId == child.id).toList();
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: GlassCard(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Row(children: [
                                CircleAvatar(radius: 20, backgroundColor: Colors.redAccent.withOpacity(0.3),
                                  child: Text(child.name.isNotEmpty ? child.name[0].toUpperCase() : '?', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                                const SizedBox(width: 12),
                                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  Text(child.name, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
                                  Text('${punishments.length} punition(s)', style: const TextStyle(color: Colors.white54, fontSize: 13)),
                                ])),
                              ]),
                              if (punishments.isEmpty)
                                const Padding(padding: EdgeInsets.only(top: 12), child: Text('Aucune punition', style: TextStyle(color: Colors.white38)))
                              else ...[
                                const SizedBox(height: 12),
                                ...punishments.map((p) {
                                  final isDone = p.isCompleted;
                                  final progress = p.totalLines > 0 ? p.completedLines / p.totalLines : 0.0;
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 8),
                                    child: TvFocusWrapper(
                                      onTap: () => _showPunishmentDetail(p, child, provider),
                                      child: GestureDetector(
                                        onTap: () => _showPunishmentDetail(p, child, provider),
                                        child: Container(
                                          padding: const EdgeInsets.all(12),
                                          decoration: BoxDecoration(
                                            color: (isDone ? Colors.greenAccent : Colors.redAccent).withOpacity(0.06),
                                            borderRadius: BorderRadius.circular(12),
                                            border: Border.all(color: (isDone ? Colors.greenAccent : Colors.redAccent).withOpacity(0.2)),
                                          ),
                                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                            Row(children: [
                                              Icon(isDone ? Icons.check_circle : Icons.pending, color: isDone ? Colors.greenAccent : Colors.redAccent, size: 20),
                                              const SizedBox(width: 10),
                                              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                                Text(p.text, style: const TextStyle(color: Colors.white, fontSize: 14), maxLines: 1, overflow: TextOverflow.ellipsis),
                                                Text(isDone ? 'Terminé' : '${p.completedLines}/${p.totalLines} lignes', style: TextStyle(color: isDone ? Colors.greenAccent : Colors.white38, fontSize: 11)),
                                              ])),
                                              Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: Colors.redAccent.withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
                                                child: Text('${p.totalLines}L', style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 12))),
                                              const SizedBox(width: 4),
                                              const Icon(Icons.chevron_right, color: Colors.white24, size: 18),
                                            ]),
                                            if (!isDone) ...[
                                              const SizedBox(height: 8),
                                              _AnimatedProgressBar(progress: progress, color: Colors.redAccent),
                                            ],
                                          ]),
                                        ),
                                      ),
                                    ),
                                  );
                                }),
                              ],
                            ]),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  child: SizedBox(width: double.infinity, height: 52, child: TvFocusWrapper(
                    onTap: _showAddPunishment,
                    child: ElevatedButton.icon(
                      onPressed: _showAddPunishment,
                      icon: const Icon(Icons.add),
                      label: const Text('Ajouter une punition', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent.shade700, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                    ),
                  )),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  void _showPunishmentDetail(dynamic punishment, dynamic child, FamilyProvider provider) {
    final isDone = punishment.isCompleted;
    final progress = punishment.totalLines > 0 ? punishment.completedLines / punishment.totalLines : 0.0;

    showModalBottomSheet(
      context: context, backgroundColor: Colors.transparent, isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.55, minChildSize: 0.3, maxChildSize: 0.7,
        builder: (context, scrollController) => Container(
          decoration: BoxDecoration(color: Colors.grey[900]?.withOpacity(0.95), borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
          child: ListView(controller: scrollController, padding: const EdgeInsets.all(20), children: [
            Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 16),
            // Titre avec animation
            Row(children: [
              Icon(isDone ? Icons.check_circle : Icons.menu_book_rounded, color: isDone ? Colors.greenAccent : Colors.redAccent, size: 28),
              const SizedBox(width: 10),
              Expanded(child: Text(punishment.text, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold))),
            ]),
            const SizedBox(height: 20),
            // Barre de progression animée
            if (!isDone) ...[
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                const Text('Progression', style: TextStyle(color: Colors.white54, fontSize: 14)),
                Text('${(progress * 100).round()}%', style: TextStyle(color: progress >= 1 ? Colors.greenAccent : Colors.redAccent, fontWeight: FontWeight.bold)),
              ]),
              const SizedBox(height: 8),
              _AnimatedProgressBar(progress: progress, color: Colors.redAccent),
              const SizedBox(height: 16),
            ],
            _detailRow('Enfant', child.name),
            _detailRow('Lignes', '${punishment.completedLines}/${punishment.totalLines}'),
            _detailRow('Statut', isDone ? 'Terminé' : 'En cours', valueColor: isDone ? Colors.greenAccent : Colors.redAccent),
            if (punishment.createdAt != null)
              _detailRow('Date', '${punishment.createdAt.day.toString().padLeft(2, '0')}/${punishment.createdAt.month.toString().padLeft(2, '0')}/${punishment.createdAt.year}'),
            const SizedBox(height: 24),
            if (!isDone)
              Row(children: [
                Expanded(child: TvFocusWrapper(
                  onTap: () { provider.removePunishment(punishment.id); Navigator.pop(ctx); setState(() {}); },
                  child: OutlinedButton.icon(
                    onPressed: () { provider.removePunishment(punishment.id); Navigator.pop(ctx); setState(() {}); },
                    icon: const Icon(Icons.delete_outline, size: 18), label: const Text('Supprimer'),
                    style: OutlinedButton.styleFrom(foregroundColor: Colors.redAccent, side: const BorderSide(color: Colors.redAccent), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  ),
                )),
                const SizedBox(width: 12),
                Expanded(child: TvFocusWrapper(
                  onTap: () async {
                    provider.updatePunishmentProgress(punishment.id, punishment.totalLines - punishment.completedLines);
                    Navigator.pop(ctx);
                    // Animation de complétion
                    await showPunishmentCompleteAnimation(this.context);
                    if (mounted) setState(() {});
                  },
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      provider.updatePunishmentProgress(punishment.id, punishment.totalLines - punishment.completedLines);
                      Navigator.pop(ctx);
                      await showPunishmentCompleteAnimation(this.context);
                      if (mounted) setState(() {});
                    },
                    icon: const Icon(Icons.check_circle, size: 18), label: const Text('Terminer'),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.greenAccent.shade700, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  ),
                )),
              ]),
          ]),
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value, {Color? valueColor}) {
    return Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(label, style: const TextStyle(color: Colors.white54, fontSize: 14)),
      Text(value, style: TextStyle(color: valueColor ?? Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
    ]));
  }
}
