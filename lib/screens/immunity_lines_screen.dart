import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/family_provider.dart';
import '../widgets/animated_background.dart';
import '../widgets/glass_card.dart';
import '../widgets/tv_focus_wrapper.dart';

// ═══════════════════════════════════════════════════════════
//  BOUCLIER DORÉ PULSANT
// ═══════════════════════════════════════════════════════════
class _ShieldPulse extends StatefulWidget {
  final double size;
  final bool isExpired;
  const _ShieldPulse({this.size = 80, this.isExpired = false});
  @override
  State<_ShieldPulse> createState() => _ShieldPulseState();
}

class _ShieldPulseState extends State<_ShieldPulse> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _pulse;
  late Animation<double> _glow;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat(reverse: true);
    _pulse = Tween<double>(begin: 0.95, end: 1.08).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
    _glow = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isExpired) {
      return SizedBox(
        width: widget.size, height: widget.size,
        child: const Icon(Icons.shield_outlined, color: Colors.white24, size: 40),
      );
    }
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        return Transform.scale(
          scale: _pulse.value,
          child: Container(
            width: widget.size, height: widget.size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(colors: [
                Colors.cyanAccent.withOpacity(0.15 + 0.15 * _glow.value),
                Colors.cyanAccent.withOpacity(0.02),
              ]),
              boxShadow: [
                BoxShadow(color: Colors.cyanAccent.withOpacity(0.1 + 0.15 * _glow.value), blurRadius: 20 + 15 * _glow.value, spreadRadius: 2 * _glow.value),
                BoxShadow(color: Colors.white.withOpacity(0.05 * _glow.value), blurRadius: 30, spreadRadius: 4 * _glow.value),
              ],
            ),
            child: const Icon(Icons.shield_rounded, color: Colors.cyanAccent, size: 40),
          ),
        );
      },
    );
  }
}

// ═══════════════════════════════════════════════════════════
//  AURA DE PROTECTION — particules orbitales
// ═══════════════════════════════════════════════════════════
class _ProtectionAura extends StatefulWidget {
  final double size;
  const _ProtectionAura({this.size = 120});
  @override
  State<_ProtectionAura> createState() => _ProtectionAuraState();
}

class _ProtectionAuraState extends State<_ProtectionAura> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(seconds: 4))..repeat();
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
        return CustomPaint(
          size: Size(widget.size, widget.size),
          painter: _AuraPainter(_ctrl.value),
        );
      },
    );
  }
}

class _AuraPainter extends CustomPainter {
  final double t;
  _AuraPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final radius = size.width * 0.42;

    // Cercles orbitaux
    for (int i = 0; i < 8; i++) {
      final angle = (i / 8) * 2 * pi + t * 2 * pi;
      final dx = cx + cos(angle) * radius;
      final dy = cy + sin(angle) * radius;
      final opacity = (0.3 + 0.4 * sin(angle + t * pi)).clamp(0.0, 1.0);
      final paint = Paint()
        ..color = Colors.cyanAccent.withOpacity(opacity)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
      canvas.drawCircle(Offset(dx, dy), 2.5, paint);
    }

    // Anneau lumineux
    final ringPaint = Paint()
      ..color = Colors.cyanAccent.withOpacity(0.08 + 0.06 * sin(t * 2 * pi))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawCircle(Offset(cx, cy), radius, ringPaint);
  }

  @override
  bool shouldRepaint(covariant _AuraPainter old) => true;
}

// ═══════════════════════════════════════════════════════════
//  ANIMATION CRÉATION D'IMMUNITÉ (bouclier apparaît)
// ═══════════════════════════════════════════════════════════
class _ShieldCreateAnimation extends StatefulWidget {
  final VoidCallback onComplete;
  final int lines;
  const _ShieldCreateAnimation({required this.onComplete, required this.lines});
  @override
  State<_ShieldCreateAnimation> createState() => _ShieldCreateAnimationState();
}

class _ShieldCreateAnimationState extends State<_ShieldCreateAnimation> with TickerProviderStateMixin {
  late AnimationController _mainCtrl;
  late Animation<double> _shieldScale;
  late Animation<double> _shieldGlow;
  late Animation<double> _textFade;
  late AnimationController _ringCtrl;

  @override
  void initState() {
    super.initState();
    _mainCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 2000))
      ..forward().then((_) => widget.onComplete());
    _shieldScale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween<double>(begin: 0.0, end: 1.3).chain(CurveTween(curve: Curves.easeOutBack)), weight: 40),
      TweenSequenceItem(tween: Tween<double>(begin: 1.3, end: 1.0).chain(CurveTween(curve: Curves.easeInOut)), weight: 20),
      TweenSequenceItem(tween: Tween<double>(begin: 1.0, end: 1.0), weight: 40),
    ]).animate(_mainCtrl);
    _shieldGlow = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _mainCtrl, curve: const Interval(0.0, 0.5, curve: Curves.easeOut)),
    );
    _textFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _mainCtrl, curve: const Interval(0.4, 0.7, curve: Curves.easeIn)),
    );
    _ringCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 3))..repeat();
  }

  @override
  void dispose() {
    _mainCtrl.dispose();
    _ringCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_mainCtrl, _ringCtrl]),
      builder: (context, _) {
        return Stack(alignment: Alignment.center, children: [
          // Fond lumineux
          Container(color: Colors.cyanAccent.withOpacity(0.04 * _shieldGlow.value)),
          // Aura orbitale
          if (_shieldGlow.value > 0.3)
            _ProtectionAura(size: 200),
          // Onde de choc
          if (_mainCtrl.value < 0.6)
            CustomPaint(size: Size.infinite, painter: _ShockwavePainter(_mainCtrl.value)),
          // Bouclier
          Transform.scale(
            scale: _shieldScale.value,
            child: Container(
              width: 100, height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [
                  Colors.cyanAccent.withOpacity(0.3 * _shieldGlow.value),
                  Colors.cyanAccent.withOpacity(0.05 * _shieldGlow.value),
                ]),
                boxShadow: [
                  BoxShadow(color: Colors.cyanAccent.withOpacity(0.3 * _shieldGlow.value), blurRadius: 30, spreadRadius: 5),
                  BoxShadow(color: Colors.white.withOpacity(0.1 * _shieldGlow.value), blurRadius: 50, spreadRadius: 10),
                ],
              ),
              child: const Icon(Icons.shield_rounded, color: Colors.cyanAccent, size: 52),
            ),
          ),
          // Texte
          Positioned(
            bottom: MediaQuery.of(context).size.height * 0.3,
            child: FadeTransition(
              opacity: _textFade,
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Text('+${widget.lines}', style: const TextStyle(color: Colors.cyanAccent, fontSize: 48, fontWeight: FontWeight.w900, shadows: [Shadow(color: Colors.cyanAccent, blurRadius: 20)])),
                const Text('IMMUNITÉ ACTIVÉE', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 3)),
              ]),
            ),
          ),
        ]);
      },
    );
  }
}

class _ShockwavePainter extends CustomPainter {
  final double t;
  _ShockwavePainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final maxR = size.width * 0.5;
    final r = maxR * (t / 0.6).clamp(0.0, 1.0);
    final opacity = (1.0 - (t / 0.6)).clamp(0.0, 1.0) * 0.3;
    final paint = Paint()
      ..color = Colors.cyanAccent.withOpacity(opacity)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3 * (1 - (t / 0.6).clamp(0.0, 1.0));
    canvas.drawCircle(Offset(cx, cy), r, paint);
  }

  @override
  bool shouldRepaint(covariant _ShockwavePainter old) => true;
}

// ═══════════════════════════════════════════════════════════
//  ANIMATION BOUCLIER BRISÉ (expiration/suppression)
// ═══════════════════════════════════════════════════════════
class _ShieldBreakAnimation extends StatefulWidget {
  final VoidCallback onComplete;
  const _ShieldBreakAnimation({required this.onComplete});
  @override
  State<_ShieldBreakAnimation> createState() => _ShieldBreakAnimationState();
}

class _ShieldBreakAnimationState extends State<_ShieldBreakAnimation> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  final _rng = Random();
  late List<_ShardParticle> _shards;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500))
      ..forward().then((_) => widget.onComplete());
    _shards = List.generate(18, (i) => _ShardParticle(
      angle: (i / 18) * 2 * pi + _rng.nextDouble() * 0.3,
      speed: 60 + _rng.nextDouble() * 120,
      size: 5 + _rng.nextDouble() * 10,
      rotSpeed: (_rng.nextDouble() - 0.5) * 8,
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
        final t = _ctrl.value;
        return Stack(alignment: Alignment.center, children: [
          // Flash blanc
          if (t < 0.15)
            Container(color: Colors.white.withOpacity((0.15 - t) / 0.15 * 0.5)),
          // Éclats
          CustomPaint(size: Size.infinite, painter: _ShardPainter(_shards, t)),
          // Bouclier qui se fissure et disparaît
          if (t < 0.5)
            Opacity(
              opacity: (1.0 - t * 2).clamp(0.0, 1.0),
              child: Transform.scale(
                scale: 1.0 + t * 0.3,
                child: const Icon(Icons.shield_rounded, color: Colors.white38, size: 52),
              ),
            ),
          // Texte
          if (t > 0.3)
            Opacity(
              opacity: ((t - 0.3) / 0.3).clamp(0.0, 1.0) * (1.0 - ((t - 0.7) / 0.3).clamp(0.0, 1.0)),
              child: const Column(mainAxisSize: MainAxisSize.min, children: [
                Text('💔', style: TextStyle(fontSize: 40)),
                SizedBox(height: 8),
                Text('BOUCLIER BRISÉ', style: TextStyle(color: Colors.redAccent, fontSize: 20, fontWeight: FontWeight.bold, letterSpacing: 3)),
              ]),
            ),
        ]);
      },
    );
  }
}

class _ShardParticle {
  final double angle, speed, size, rotSpeed;
  _ShardParticle({required this.angle, required this.speed, required this.size, required this.rotSpeed});
}

class _ShardPainter extends CustomPainter {
  final List<_ShardParticle> shards;
  final double t;
  _ShardPainter(this.shards, this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    for (final s in shards) {
      final dist = s.speed * t;
      final dx = cx + cos(s.angle) * dist;
      final dy = cy + sin(s.angle) * dist + 40 * t * t; // gravité
      final opacity = (1.0 - t).clamp(0.0, 1.0);
      if (opacity <= 0) continue;
      canvas.save();
      canvas.translate(dx, dy);
      canvas.rotate(s.rotSpeed * t);
      final paint = Paint()..color = Colors.cyanAccent.withOpacity(opacity * 0.7);
      // Triangle (éclat)
      final path = Path()
        ..moveTo(0, -s.size / 2)
        ..lineTo(s.size / 3, s.size / 2)
        ..lineTo(-s.size / 3, s.size / 2)
        ..close();
      canvas.drawPath(path, paint);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _ShardPainter old) => true;
}

// ═══════════════════════════════════════════════════════════
//  DIALOGUES D'ANIMATION
// ═══════════════════════════════════════════════════════════
Future<void> showShieldCreateAnimation(BuildContext context, int lines) {
  return showGeneralDialog(
    context: context, barrierDismissible: false, barrierColor: Colors.black87,
    transitionDuration: const Duration(milliseconds: 100),
    pageBuilder: (ctx, _, __) => Material(color: Colors.transparent,
      child: _ShieldCreateAnimation(lines: lines, onComplete: () => Navigator.of(ctx).pop())),
  );
}

Future<void> showShieldBreakAnimation(BuildContext context) {
  return showGeneralDialog(
    context: context, barrierDismissible: false, barrierColor: Colors.black87,
    transitionDuration: const Duration(milliseconds: 100),
    pageBuilder: (ctx, _, __) => Material(color: Colors.transparent,
      child: _ShieldBreakAnimation(onComplete: () => Navigator.of(ctx).pop())),
  );
}

// ═══════════════════════════════════════════════════════════
//  IMMUNITY LINES SCREEN
// ═══════════════════════════════════════════════════════════
class ImmunityLinesScreen extends StatefulWidget {
  const ImmunityLinesScreen({super.key});
  @override
  State<ImmunityLinesScreen> createState() => _ImmunityLinesScreenState();
}

class _ImmunityLinesScreenState extends State<ImmunityLinesScreen> {

  void _showAddImmunity() {
    final provider = context.read<FamilyProvider>();
    final children = provider.children;
    String? selectedChildId;
    String reason = '';
    int lines = 1;
    bool hasExpiry = false;
    int expiryDays = 7;
    final reasonController = TextEditingController();

    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(builder: (context, setModalState) {
          return DraggableScrollableSheet(
            initialChildSize: 0.75, minChildSize: 0.5, maxChildSize: 0.9,
            builder: (context, scrollController) {
              return Container(
                decoration: BoxDecoration(color: Colors.grey[900]?.withOpacity(0.95), borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
                child: ListView(controller: scrollController, padding: const EdgeInsets.all(20), children: [
                  Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)))),
                  const SizedBox(height: 16),
                  // Titre avec bouclier animé
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    TweenAnimationBuilder<double>(
                      tween: Tween<double>(begin: 0, end: 1),
                      duration: const Duration(milliseconds: 800),
                      curve: Curves.elasticOut,
                      builder: (context, val, child) => Transform.scale(scale: val, child: child),
                      child: const Icon(Icons.shield_rounded, color: Colors.cyanAccent, size: 28),
                    ),
                    const SizedBox(width: 10),
                    const Text('Nouvelle immunité', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
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
                            color: isSelected ? Colors.cyanAccent.withOpacity(0.2) : Colors.white.withOpacity(0.06),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: isSelected ? Colors.cyanAccent : Colors.white24),
                          ),
                          child: Text(child.name, style: TextStyle(color: isSelected ? Colors.cyanAccent : Colors.white70, fontWeight: FontWeight.w600)),
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
                      hintText: 'Ex: Excellent bulletin...', hintStyle: const TextStyle(color: Colors.white38),
                      filled: true, fillColor: Colors.white.withOpacity(0.06),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Colors.cyanAccent)),
                    ),
                    onChanged: (val) => reason = val,
                  ),
                  const SizedBox(height: 20),
                  const Text('Nombre de lignes d\'immunité', style: TextStyle(color: Colors.white70, fontSize: 14)),
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
                    TweenAnimationBuilder<double>(
                      tween: Tween<double>(begin: lines.toDouble(), end: lines.toDouble()),
                      duration: const Duration(milliseconds: 200),
                      builder: (context, val, _) => Text('${val.round()}', style: const TextStyle(color: Colors.cyanAccent, fontSize: 36, fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(width: 24),
                    TvFocusWrapper(
                      onTap: () { if (lines < 20) setModalState(() => lines++); },
                      child: GestureDetector(
                        onTap: () { if (lines < 20) setModalState(() => lines++); },
                        child: Container(width: 44, height: 44, decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withOpacity(0.1), border: Border.all(color: Colors.white24)),
                          child: const Icon(Icons.add, color: Colors.white70)),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 8),
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [1, 3, 5, 10].map((val) {
                    return Padding(padding: const EdgeInsets.symmetric(horizontal: 4), child: TvFocusWrapper(
                      onTap: () => setModalState(() => lines = val),
                      child: OutlinedButton(
                        onPressed: () => setModalState(() => lines = val),
                        style: OutlinedButton.styleFrom(foregroundColor: lines == val ? Colors.cyanAccent : Colors.white54, side: BorderSide(color: lines == val ? Colors.cyanAccent : Colors.white24), padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))),
                        child: Text('$val'),
                      ),
                    ));
                  }).toList()),
                  const SizedBox(height: 20),
                  TvFocusWrapper(
                    onTap: () => setModalState(() => hasExpiry = !hasExpiry),
                    child: GestureDetector(
                      onTap: () => setModalState(() => hasExpiry = !hasExpiry),
                      child: Row(children: [
                        Switch(value: hasExpiry, activeColor: Colors.cyanAccent, onChanged: (val) => setModalState(() => hasExpiry = val)),
                        const SizedBox(width: 8),
                        Text('Définir une expiration', style: TextStyle(color: hasExpiry ? Colors.cyanAccent : Colors.white54)),
                      ]),
                    ),
                  ),
                  if (hasExpiry) ...[
                    const SizedBox(height: 8),
                    Row(mainAxisAlignment: MainAxisAlignment.center, children: [7, 14, 30, 60].map((val) {
                      return Padding(padding: const EdgeInsets.symmetric(horizontal: 4), child: TvFocusWrapper(
                        onTap: () => setModalState(() => expiryDays = val),
                        child: OutlinedButton(
                          onPressed: () => setModalState(() => expiryDays = val),
                          style: OutlinedButton.styleFrom(foregroundColor: expiryDays == val ? Colors.orangeAccent : Colors.white54, side: BorderSide(color: expiryDays == val ? Colors.orangeAccent : Colors.white24), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))),
                          child: Text('${val}j'),
                        ),
                      ));
                    }).toList()),
                  ],
                  const SizedBox(height: 28),
                  SizedBox(width: double.infinity, height: 52, child: TvFocusWrapper(
                    onTap: () async {
                      if (selectedChildId == null || reason.isEmpty) {
                        ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Sélectionnez un enfant et une raison'), backgroundColor: Colors.orangeAccent));
                        return;
                      }
                      provider.addImmunity(selectedChildId!, reason, lines, expiresAt: hasExpiry ? DateTime.now().add(Duration(days: expiryDays)) : null);
                      Navigator.pop(ctx);
                      // Animation bouclier créé
                      await showShieldCreateAnimation(this.context, lines);
                    },
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        if (selectedChildId == null || reason.isEmpty) {
                          ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Sélectionnez un enfant et une raison'), backgroundColor: Colors.orangeAccent));
                          return;
                        }
                        provider.addImmunity(selectedChildId!, reason, lines, expiresAt: hasExpiry ? DateTime.now().add(Duration(days: expiryDays)) : null);
                        Navigator.pop(ctx);
                        await showShieldCreateAnimation(this.context, lines);
                      },
                      icon: const Icon(Icons.shield),
                      label: const Text('Créer l\'immunité', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.cyanAccent.shade700, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
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

  String _getImmunityStatus(dynamic immunity) {
    if (immunity.isFullyUsed == true) return 'used';
    if (immunity.isExpired == true) return 'expired';
    return 'usable';
  }

  Color _getStatusColor(String status) {
    switch (status) { case 'usable': return Colors.greenAccent; case 'used': return Colors.white38; case 'expired': return Colors.redAccent; default: return Colors.white54; }
  }

  String _getStatusLabel(String status) {
    switch (status) { case 'usable': return 'Disponible'; case 'used': return 'Utilisée'; case 'expired': return 'Expirée'; default: return ''; }
  }

  IconData _getStatusIcon(String status) {
    switch (status) { case 'usable': return Icons.shield; case 'used': return Icons.check_circle_outline; case 'expired': return Icons.timer_off; default: return Icons.help_outline; }
  }

  String _formatDate(DateTime date) => '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';

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
              child: const Icon(Icons.shield_rounded, color: Colors.cyanAccent, size: 22),
            ),
            const SizedBox(width: 8),
            const Text('Lignes d\'immunité'),
          ]),
          backgroundColor: Colors.transparent, elevation: 0,
        ),
        body: Consumer<FamilyProvider>(
          builder: (context, provider, _) {
            final children = provider.children;
            if (children.isEmpty) return const Center(child: Text('Aucun enfant enregistré', style: TextStyle(color: Colors.white54)));
            return Column(
              children: [
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                    itemCount: children.length,
                    itemBuilder: (context, index) {
                      final child = children[index];
                      final immunities = provider.getImmunitiesForChild(child.id);
                      final usable = immunities.where((i) => _getImmunityStatus(i) == 'usable').toList();
                      final used = immunities.where((i) => _getImmunityStatus(i) == 'used').toList();
                      final expired = immunities.where((i) => _getImmunityStatus(i) == 'expired').toList();
                      final totalLines = usable.fold<int>(0, (sum, i) => sum + (i.availableLines as int));

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: GlassCard(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Row(children: [
                                // Bouclier pulsant pour chaque enfant
                                SizedBox(width: 44, height: 44, child: _ShieldPulse(size: 44, isExpired: totalLines == 0)),
                                const SizedBox(width: 12),
                                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  Text(child.name, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
                                  Text('${child.points} pts', style: const TextStyle(color: Colors.white54, fontSize: 13)),
                                ])),
                                Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: totalLines > 0 ? Colors.greenAccent.withOpacity(0.15) : Colors.white.withOpacity(0.05),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(color: totalLines > 0 ? Colors.greenAccent.withOpacity(0.5) : Colors.white12),
                                  ),
                                  child: Text('$totalLines lignes dispo', style: TextStyle(color: totalLines > 0 ? Colors.greenAccent : Colors.white38, fontSize: 12, fontWeight: FontWeight.bold))),
                              ]),
                              if (immunities.isEmpty)
                                const Padding(padding: EdgeInsets.only(top: 16), child: Text('Aucune immunité', style: TextStyle(color: Colors.white38))),
                              if (usable.isNotEmpty) ...[const SizedBox(height: 16), _sectionChip('Disponibles', Colors.greenAccent, usable.length), ...usable.map((imm) => _buildImmunityTile(imm, child, 'usable'))],
                              if (used.isNotEmpty) ...[const SizedBox(height: 12), _sectionChip('Utilisées', Colors.white38, used.length), ...used.map((imm) => _buildImmunityTile(imm, child, 'used'))],
                              if (expired.isNotEmpty) ...[const SizedBox(height: 12), _sectionChip('Expirées', Colors.redAccent, expired.length), ...expired.map((imm) => _buildImmunityTile(imm, child, 'expired'))],
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
                    onTap: _showAddImmunity,
                    child: ElevatedButton.icon(
                      onPressed: _showAddImmunity,
                      icon: const Icon(Icons.add),
                      label: const Text('Ajouter une immunité', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.cyanAccent.shade700, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
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

  Widget _sectionChip(String label, Color color, int count) {
    return Padding(padding: const EdgeInsets.only(bottom: 8), child: Row(children: [
      Container(width: 8, height: 8, decoration: BoxDecoration(shape: BoxShape.circle, color: color)),
      const SizedBox(width: 8),
      Text('$label ($count)', style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w600)),
    ]));
  }

  Widget _buildImmunityTile(dynamic immunity, dynamic child, String status) {
    final statusColor = _getStatusColor(status);
    final isExpired = status == 'expired';
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: TvFocusWrapper(
        onTap: () => _showImmunityDetail(immunity, child),
        child: GestureDetector(
          onTap: () => _showImmunityDetail(immunity, child),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.06),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: statusColor.withOpacity(isExpired ? 0.3 : 0.2)),
            ),
            child: Row(children: [
              // Mini bouclier animé ou icône statique
              if (status == 'usable')
                SizedBox(width: 24, height: 24, child: TweenAnimationBuilder<double>(
                  tween: Tween<double>(begin: 0.8, end: 1.0),
                  duration: const Duration(milliseconds: 600),
                  curve: Curves.elasticOut,
                  builder: (context, val, child) => Transform.scale(scale: val, child: child),
                  child: Icon(Icons.shield_rounded, color: statusColor, size: 20),
                ))
              else
                Icon(_getStatusIcon(status), color: statusColor, size: 20),
              const SizedBox(width: 10),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(immunity.reason, style: const TextStyle(color: Colors.white, fontSize: 14), maxLines: 1, overflow: TextOverflow.ellipsis),
                if (immunity.expiresAt != null) Text('Expire: ${_formatDate(immunity.expiresAt!)}', style: const TextStyle(color: Colors.white38, fontSize: 11)),
              ])),
              Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: statusColor.withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
                child: Text('${immunity.availableLines}L', style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 12))),
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right, color: Colors.white24, size: 18),
            ]),
          ),
        ),
      ),
    );
  }

  void _showImmunityDetail(dynamic immunity, dynamic child) {
    final status = _getImmunityStatus(immunity);
    final statusColor = _getStatusColor(status);
    showModalBottomSheet(
      context: context, backgroundColor: Colors.transparent, isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.6, minChildSize: 0.3, maxChildSize: 0.8,
        builder: (context, scrollController) => Container(
          decoration: BoxDecoration(color: Colors.grey[900]?.withOpacity(0.95), borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
          child: ListView(controller: scrollController, padding: const EdgeInsets.all(20), children: [
            Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 16),
            // Bouclier animé en haut du détail
            Center(child: SizedBox(
              width: 100, height: 100,
              child: Stack(alignment: Alignment.center, children: [
                if (status == 'usable') _ProtectionAura(size: 100),
                _ShieldPulse(size: 60, isExpired: status == 'expired'),
              ]),
            )),
            const SizedBox(height: 16),
            Center(child: Text(immunity.reason, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold), textAlign: TextAlign.center)),
            const SizedBox(height: 20),
            _detailRow('Enfant', child.name),
            _detailRow('Statut', _getStatusLabel(status), valueColor: statusColor),
            _detailRow('Lignes totales', '${immunity.lines}'),
            _detailRow('Lignes utilisées', '${immunity.usedLines}'),
            _detailRow('Lignes restantes', '${immunity.availableLines}'),
            _detailRow('Créée le', _formatDate(immunity.createdAt)),
            if (immunity.expiresAt != null)
              _detailRow('Expire le', _formatDate(immunity.expiresAt!), valueColor: status == 'expired' ? Colors.redAccent : Colors.orangeAccent),
            const SizedBox(height: 24),
            if (status == 'usable')
              Row(children: [
                Expanded(child: TvFocusWrapper(
                  onTap: () async {
                    Navigator.pop(ctx);
                    await showShieldBreakAnimation(this.context);
                    if (mounted) {
                      context.read<FamilyProvider>().removeImmunity(immunity.id);
                      setState(() {});
                    }
                  },
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      Navigator.pop(ctx);
                      await showShieldBreakAnimation(this.context);
                      if (mounted) {
                        context.read<FamilyProvider>().removeImmunity(immunity.id);
                        setState(() {});
                      }
                    },
                    icon: const Icon(Icons.delete_outline, size: 18), label: const Text('Supprimer'),
                    style: OutlinedButton.styleFrom(foregroundColor: Colors.redAccent, side: const BorderSide(color: Colors.redAccent), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  ),
                )),
                const SizedBox(width: 12),
                Expanded(child: TvFocusWrapper(
                  onTap: () { Navigator.pop(ctx); _tradeImmunity(immunity, child); },
                  child: ElevatedButton.icon(
                    onPressed: () { Navigator.pop(ctx); _tradeImmunity(immunity, child); },
                    icon: const Icon(Icons.swap_horiz, size: 18), label: const Text('Échanger'),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.orangeAccent.shade700, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
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

  void _tradeImmunity(dynamic immunity, dynamic child) {
    context.read<FamilyProvider>().createTrade(child.id, '', immunity.availableLines, 'Échange immunité: ${immunity.reason}');
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Échange proposé !'), backgroundColor: Colors.orangeAccent));
  }
}
