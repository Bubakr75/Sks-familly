import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/family_provider.dart';
import '../models/child_model.dart';
import '../models/tribunal_model.dart';
import '../utils/pin_guard.dart';
import '../widgets/glass_card.dart';
import '../widgets/animated_background.dart';
import '../widgets/tv_focus_wrapper.dart';

// ============================================================
//  ANIMATIONS CUSTOM FLUTTER
// ============================================================

class GavelAnimation extends StatefulWidget {
  final VoidCallback? onComplete;
  const GavelAnimation({super.key, this.onComplete});
  @override
  State<GavelAnimation> createState() => _GavelAnimationState();
}

class _GavelAnimationState extends State<GavelAnimation> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _rotation;
  late Animation<double> _scale;
  int _hitCount = 0;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 400));
    _rotation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween<double>(begin: 0.0, end: -0.5).chain(CurveTween(curve: Curves.easeOut)), weight: 40),
      TweenSequenceItem(tween: Tween<double>(begin: -0.5, end: 0.05).chain(CurveTween(curve: Curves.bounceOut)), weight: 60),
    ]).animate(_ctrl);
    _scale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween<double>(begin: 1.0, end: 0.9), weight: 40),
      TweenSequenceItem(tween: Tween<double>(begin: 0.9, end: 1.15).chain(CurveTween(curve: Curves.elasticOut)), weight: 60),
    ]).animate(_ctrl);
    _ctrl.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _hitCount++;
        if (_hitCount < 3) {
          Future.delayed(const Duration(milliseconds: 200), () {
            if (mounted) _ctrl.forward(from: 0);
          });
        } else {
          widget.onComplete?.call();
        }
      }
    });
    _ctrl.forward();
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) => Transform.scale(
        scale: _scale.value,
        child: Transform.rotate(
          angle: _rotation.value,
          alignment: Alignment.bottomCenter,
          child: const Text('\u{1F528}', style: TextStyle(fontSize: 80)),
        ),
      ),
    );
  }
}

class ConfettiAnimation extends StatefulWidget {
  const ConfettiAnimation({super.key});
  @override
  State<ConfettiAnimation> createState() => _ConfettiAnimationState();
}

class _ConfettiAnimationState extends State<ConfettiAnimation> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  final List<_ConfettiParticle> _particles = [];
  final Random _random = Random();

  @override
  void initState() {
    super.initState();
    for (int i = 0; i < 50; i++) {
      _particles.add(_ConfettiParticle(
        x: _random.nextDouble(),
        y: _random.nextDouble() * -1,
        speed: 0.3 + _random.nextDouble() * 0.7,
        size: 4.0 + _random.nextDouble() * 8.0,
        color: [Colors.green, Colors.blue, Colors.yellow, Colors.purple, Colors.cyan, Colors.amber][_random.nextInt(6)],
        drift: -0.5 + _random.nextDouble(),
        rotation: _random.nextDouble() * 2 * pi,
        rotationSpeed: -2.0 + _random.nextDouble() * 4.0,
      ));
    }
    _ctrl = AnimationController(vsync: this, duration: const Duration(seconds: 3))..forward();
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) => CustomPaint(
        size: Size.infinite,
        painter: _ConfettiPainter(_particles, _ctrl.value),
      ),
    );
  }
}

class _ConfettiParticle {
  final double x, y, speed, size, drift, rotation, rotationSpeed;
  final Color color;
  _ConfettiParticle({required this.x, required this.y, required this.speed, required this.size, required this.color, required this.drift, required this.rotation, required this.rotationSpeed});
}

class _ConfettiPainter extends CustomPainter {
  final List<_ConfettiParticle> particles;
  final double progress;
  _ConfettiPainter(this.particles, this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in particles) {
      final currentY = p.y + progress * p.speed * 2;
      final currentX = p.x + progress * p.drift * 0.3;
      if (currentY > 1.2) continue;
      final opacity = (1.0 - progress).clamp(0.0, 1.0);
      final paint = Paint()..color = p.color.withOpacity(opacity);
      canvas.save();
      canvas.translate(currentX * size.width, currentY * size.height + size.height * 0.1);
      canvas.rotate(p.rotation + progress * p.rotationSpeed * pi);
      canvas.drawRect(Rect.fromCenter(center: Offset.zero, width: p.size, height: p.size * 0.6), paint);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class GuiltyFlashAnimation extends StatefulWidget {
  const GuiltyFlashAnimation({super.key});
  @override
  State<GuiltyFlashAnimation> createState() => _GuiltyFlashAnimationState();
}

class _GuiltyFlashAnimationState extends State<GuiltyFlashAnimation> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500));
    _opacity = TweenSequence<double>([
      TweenSequenceItem(tween: Tween<double>(begin: 0.0, end: 0.6), weight: 10),
      TweenSequenceItem(tween: Tween<double>(begin: 0.6, end: 0.0), weight: 15),
      TweenSequenceItem(tween: Tween<double>(begin: 0.0, end: 0.4), weight: 10),
      TweenSequenceItem(tween: Tween<double>(begin: 0.4, end: 0.0), weight: 15),
      TweenSequenceItem(tween: Tween<double>(begin: 0.0, end: 0.2), weight: 10),
      TweenSequenceItem(tween: Tween<double>(begin: 0.2, end: 0.0), weight: 40),
    ]).animate(_ctrl);
    _ctrl.forward();
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) => Container(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            colors: [Colors.red.withOpacity(_opacity.value), Colors.transparent],
            radius: 1.5,
          ),
        ),
      ),
    );
  }
}

class ScalesAnimation extends StatefulWidget {
  const ScalesAnimation({super.key});
  @override
  State<ScalesAnimation> createState() => _ScalesAnimationState();
}

class _ScalesAnimationState extends State<ScalesAnimation> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _tilt;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(seconds: 3))..repeat(reverse: true);
    _tilt = Tween<double>(begin: -0.15, end: 0.15).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) => Transform.rotate(
        angle: _tilt.value,
        child: const Text('\u{2696}', style: TextStyle(fontSize: 60)),
      ),
    );
  }
}

class GoldenParticlesAnimation extends StatefulWidget {
  const GoldenParticlesAnimation({super.key});
  @override
  State<GoldenParticlesAnimation> createState() => _GoldenParticlesAnimationState();
}

class _GoldenParticlesAnimationState extends State<GoldenParticlesAnimation> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  final List<_GoldenParticle> _particles = [];
  final Random _random = Random();

  @override
  void initState() {
    super.initState();
    for (int i = 0; i < 20; i++) {
      _particles.add(_GoldenParticle(
        x: _random.nextDouble(),
        y: _random.nextDouble(),
        speed: 0.2 + _random.nextDouble() * 0.5,
        size: 2.0 + _random.nextDouble() * 4.0,
        opacity: 0.3 + _random.nextDouble() * 0.7,
        phase: _random.nextDouble() * 2 * pi,
      ));
    }
    _ctrl = AnimationController(vsync: this, duration: const Duration(seconds: 4))..repeat();
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) => CustomPaint(
        size: Size.infinite,
        painter: _GoldenPainter(_particles, _ctrl.value),
      ),
    );
  }
}

class _GoldenParticle {
  final double x, y, speed, size, opacity, phase;
  _GoldenParticle({required this.x, required this.y, required this.speed, required this.size, required this.opacity, required this.phase});
}

class _GoldenPainter extends CustomPainter {
  final List<_GoldenParticle> particles;
  final double progress;
  _GoldenPainter(this.particles, this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in particles) {
      final currentY = (p.y - progress * p.speed) % 1.0;
      final pulse = (sin(progress * 2 * pi + p.phase) + 1) / 2;
      final paint = Paint()
        ..color = Color.lerp(const Color(0xFFFFD740), const Color(0xFFFFA000), pulse)!.withOpacity(p.opacity * pulse)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, p.size * 0.8);
      canvas.drawCircle(Offset(p.x * size.width, currentY * size.height), p.size * (0.8 + pulse * 0.4), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// ============================================================
//  DIALOG ANIMATIONS
// ============================================================

Future<void> showVerdictAnimation(BuildContext context, TribunalVerdict verdict) async {
  await showGeneralDialog(
    context: context,
    barrierDismissible: false,
    barrierColor: Colors.black87,
    transitionDuration: const Duration(milliseconds: 300),
    pageBuilder: (_, __, ___) => _VerdictAnimationDialog(verdict: verdict),
  );
}

class _VerdictAnimationDialog extends StatefulWidget {
  final TribunalVerdict verdict;
  const _VerdictAnimationDialog({required this.verdict});
  @override
  State<_VerdictAnimationDialog> createState() => _VerdictAnimationDialogState();
}

class _VerdictAnimationDialogState extends State<_VerdictAnimationDialog> with TickerProviderStateMixin {
  late AnimationController _textCtrl;
  late Animation<double> _textScale;
  late Animation<double> _textOpacity;
  bool _showVerdict = false;

  @override
  void initState() {
    super.initState();
    _textCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _textScale = Tween<double>(begin: 0.3, end: 1.0).animate(CurvedAnimation(parent: _textCtrl, curve: Curves.elasticOut));
    _textOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(parent: _textCtrl, curve: Curves.easeIn));
    Future.delayed(const Duration(milliseconds: 1200), () {
      if (mounted) {
        setState(() => _showVerdict = true);
        _textCtrl.forward();
      }
    });
    Future.delayed(const Duration(seconds: 4), () {
      if (mounted) Navigator.pop(context);
    });
  }

  @override
  void dispose() { _textCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final isGuilty = widget.verdict == TribunalVerdict.guilty;
    final isInnocent = widget.verdict == TribunalVerdict.innocent;

    return Material(
      color: Colors.transparent,
      child: Stack(
        children: [
          if (isGuilty) const Positioned.fill(child: GuiltyFlashAnimation()),
          if (isInnocent) const Positioned.fill(child: ConfettiAnimation()),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                GavelAnimation(onComplete: () {}),
                const SizedBox(height: 30),
                if (_showVerdict)
                  AnimatedBuilder(
                    animation: _textCtrl,
                    builder: (_, __) => Opacity(
                      opacity: _textOpacity.value,
                      child: Transform.scale(
                        scale: _textScale.value,
                        child: Column(
                          children: [
                            Text(
                              isGuilty ? '\u{274C}' : isInnocent ? '\u{2705}' : '\u{1F5C4}',
                              style: const TextStyle(fontSize: 60),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              isGuilty ? 'COUPABLE' : isInnocent ? 'INNOCENT' : 'CLASSÉ',
                              style: TextStyle(
                                color: isGuilty ? Colors.red : isInnocent ? Colors.green : Colors.grey,
                                fontSize: 36,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 4,
                                shadows: [
                                  Shadow(color: (isGuilty ? Colors.red : isInnocent ? Colors.green : Colors.grey).withOpacity(0.5), blurRadius: 20),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

Future<void> showHearingOpenAnimation(BuildContext context) async {
  await showGeneralDialog(
    context: context,
    barrierDismissible: false,
    barrierColor: Colors.black87,
    transitionDuration: const Duration(milliseconds: 300),
    pageBuilder: (_, __, ___) => const _HearingOpenDialog(),
  );
}

class _HearingOpenDialog extends StatefulWidget {
  const _HearingOpenDialog();
  @override
  State<_HearingOpenDialog> createState() => _HearingOpenDialogState();
}

class _HearingOpenDialogState extends State<_HearingOpenDialog> with TickerProviderStateMixin {
  late AnimationController _textCtrl;
  late Animation<double> _textOpacity;
  bool _showText = false;

  @override
  void initState() {
    super.initState();
    _textCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _textOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(_textCtrl);
    Future.delayed(const Duration(milliseconds: 1400), () {
      if (mounted) { setState(() => _showText = true); _textCtrl.forward(); }
    });
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) Navigator.pop(context);
    });
  }

  @override
  void dispose() { _textCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Stack(
        children: [
          const Positioned.fill(child: GoldenParticlesAnimation()),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                GavelAnimation(onComplete: () {}),
                const SizedBox(height: 30),
                if (_showText)
                  AnimatedBuilder(
                    animation: _textCtrl,
                    builder: (_, __) => Opacity(
                      opacity: _textOpacity.value,
                      child: const Column(
                        children: [
                          Text('AUDIENCE OUVERTE', style: TextStyle(color: Color(0xFFFFD740), fontSize: 28, fontWeight: FontWeight.w900, letterSpacing: 3, shadows: [Shadow(color: Color(0x80FFD740), blurRadius: 20)])),
                          SizedBox(height: 8),
                          Text('Le tribunal est en session', style: TextStyle(color: Colors.white54, fontSize: 16)),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

Future<void> showDeliberationAnimation(BuildContext context) async {
  await showGeneralDialog(
    context: context,
    barrierDismissible: false,
    barrierColor: Colors.black87,
    transitionDuration: const Duration(milliseconds: 300),
    pageBuilder: (_, __, ___) => const _DeliberationDialog(),
  );
}

class _DeliberationDialog extends StatefulWidget {
  const _DeliberationDialog();
  @override
  State<_DeliberationDialog> createState() => _DeliberationDialogState();
}

class _DeliberationDialogState extends State<_DeliberationDialog> with TickerProviderStateMixin {
  late AnimationController _textCtrl;
  late Animation<double> _textOpacity;

  @override
  void initState() {
    super.initState();
    _textCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _textOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(_textCtrl);
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) _textCtrl.forward();
    });
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) Navigator.pop(context);
    });
  }

  @override
  void dispose() { _textCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Stack(
        children: [
          const Positioned.fill(child: GoldenParticlesAnimation()),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const ScalesAnimation(),
                const SizedBox(height: 30),
                AnimatedBuilder(
                  animation: _textCtrl,
                  builder: (_, __) => Opacity(
                    opacity: _textOpacity.value,
                    child: const Column(
                      children: [
                        Text('DÉLIBÉRATION', style: TextStyle(color: Color(0xFFFFD740), fontSize: 28, fontWeight: FontWeight.w900, letterSpacing: 3, shadows: [Shadow(color: Color(0x80FFD740), blurRadius: 20)])),
                        SizedBox(height: 8),
                        Text('Le jury se retire pour délibérer...', style: TextStyle(color: Colors.white54, fontSize: 16)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
//  TV FRIENDLY TEXT FIELD
// ============================================================

class TvTextField extends StatelessWidget {
  final TextEditingController controller;
  final String labelText;
  final String? hintText;
  final int maxLines;
  final FocusNode? focusNode;

  const TvTextField({
    super.key,
    required this.controller,
    required this.labelText,
    this.hintText,
    this.maxLines = 1,
    this.focusNode,
  });

  @override
  Widget build(BuildContext context) {
    return Focus(
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent) {
          if (event.logicalKey == LogicalKeyboardKey.arrowDown ||
              event.logicalKey == LogicalKeyboardKey.arrowUp) {
            if (maxLines <= 1) {
              final direction = event.logicalKey == LogicalKeyboardKey.arrowDown
                  ? TraversalDirection.down
                  : TraversalDirection.up;
              FocusTraversalGroup.maybeOf(context)?.inDirection(node, direction);
              return KeyEventResult.handled;
            }
          }
          if (event.logicalKey == LogicalKeyboardKey.escape ||
              event.logicalKey == LogicalKeyboardKey.goBack) {
            node.unfocus();
            return KeyEventResult.handled;
          }
        }
        return KeyEventResult.ignored;
      },
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        style: const TextStyle(color: Colors.white),
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: labelText,
          hintText: hintText,
          hintStyle: TextStyle(color: Colors.grey[700]),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFFFD740), width: 2),
          ),
        ),
      ),
    );
  }
}

// ============================================================
//  TRIBUNAL SCREEN
// ============================================================

class TribunalScreen extends StatefulWidget {
  const TribunalScreen({super.key});
  @override
  State<TribunalScreen> createState() => _TribunalScreenState();
}

class _TribunalScreenState extends State<TribunalScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  static const _courtBrown = Color(0xFF5D4037);
  static const _courtGold = Color(0xFFFFD740);
  static const _courtRed = Color(0xFFFF1744);
  static const _courtGreen = Color(0xFF00E676);
  static const _courtBlue = Color(0xFF448AFF);
  static const _courtPurple = Color(0xFF7C4DFF);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E21),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('\u{2696}', style: TextStyle(fontSize: 24)),
            SizedBox(width: 8),
            Text('Tribunal Familial', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 20)),
          ],
        ),
        centerTitle: true,
      ),
      floatingActionButton: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: _courtRed.withOpacity(0.3), blurRadius: 16)],
        ),
        child: TvFocusWrapper(
          child: FloatingActionButton.extended(
            heroTag: 'file_complaint',
            backgroundColor: _courtRed,
            onPressed: () => PinGuard.guardAction(context, () => _showFileComplaint(context)),
            icon: const Icon(Icons.gavel_rounded),
            label: const Text('Déposer une plainte', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ),
      ),
      body: Consumer<FamilyProvider>(
        builder: (context, provider, _) {
          return AnimatedBackground(
            child: Column(
              children: [
                _buildTribunalStats(provider),
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: TabBar(
                    controller: _tabController,
                    indicator: BoxDecoration(
                      color: _courtBrown.withOpacity(0.4),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    labelColor: Colors.white,
                    unselectedLabelColor: Colors.white54,
                    dividerHeight: 0,
                    tabs: [
                      Tab(
                        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                          const Text('\u{1F4CB}', style: TextStyle(fontSize: 16)),
                          const SizedBox(width: 6),
                          Text('En cours (${provider.activeTribunalCases.length})', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                        ]),
                      ),
                      Tab(
                        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                          const Text('\u{1F4C1}', style: TextStyle(fontSize: 16)),
                          const SizedBox(width: 6),
                          Text('Archives (${provider.closedTribunalCases.length})', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                        ]),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildActiveCases(provider),
                      _buildClosedCases(provider),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildTribunalStats(FamilyProvider provider) {
    final total = provider.tribunalCases.length;
    final active = provider.activeTribunalCases.length;
    final verdicts = provider.closedTribunalCases.length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Stack(
        children: [
          Row(
            children: [
              _statCard('\u{2696}', '$total', 'Total', _courtGold),
              const SizedBox(width: 8),
              _statCard('\u{1F525}', '$active', 'En cours', _courtRed),
              const SizedBox(width: 8),
              _statCard('\u{1F528}', '$verdicts', 'Jugés', _courtGreen),
            ],
          ),
          const Positioned.fill(
            child: IgnorePointer(child: GoldenParticlesAnimation()),
          ),
        ],
      ),
    );
  }

  Widget _statCard(String emoji, String value, String label, Color color) {
    return Expanded(
      child: GlassCard(
        margin: EdgeInsets.zero,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        borderRadius: 14,
        child: Column(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 20)),
            const SizedBox(height: 4),
            Text(value, style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 20)),
            Text(label, style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 10)),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveCases(FamilyProvider provider) {
    final cases = provider.activeTribunalCases;
    if (cases.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const ScalesAnimation(),
            const SizedBox(height: 16),
            const Text('Aucune affaire en cours', style: TextStyle(color: Colors.white54, fontSize: 16)),
            const SizedBox(height: 8),
            Text('La paix règne dans la famille !', style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 14)),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      itemCount: cases.length,
      itemBuilder: (context, index) => _buildCaseCard(cases[index], provider),
    );
  }

  Widget _buildClosedCases(FamilyProvider provider) {
    final cases = provider.closedTribunalCases;
    if (cases.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('\u{1F4C1}', style: TextStyle(fontSize: 64)),
            SizedBox(height: 16),
            Text('Aucune archive', style: TextStyle(color: Colors.white54, fontSize: 16)),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      itemCount: cases.length,
      itemBuilder: (context, index) => _buildCaseCard(cases[index], provider),
    );
  }

  Widget _buildCaseCard(TribunalCase tc, FamilyProvider provider) {
    final plaintiff = provider.getChild(tc.plaintiffId);
    final accused = provider.getChild(tc.accusedId);

    return TvFocusWrapper(
      child: GestureDetector(
        onTap: () => _showCaseDetail(context, tc, provider),
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [_courtBrown.withOpacity(0.15), tc.statusColor.withOpacity(0.08)],
            ),
            border: Border.all(color: tc.statusColor.withOpacity(0.3)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(tc.statusEmoji, style: const TextStyle(fontSize: 20)),
                    const SizedBox(width: 8),
                    Expanded(child: Text(tc.title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16), maxLines: 1, overflow: TextOverflow.ellipsis)),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(color: tc.statusColor.withOpacity(0.15), borderRadius: BorderRadius.circular(8), border: Border.all(color: tc.statusColor.withOpacity(0.3))),
                      child: Text(tc.statusLabel, style: TextStyle(color: tc.statusColor, fontSize: 10, fontWeight: FontWeight.w700)),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: _buildPartyChip(plaintiff, 'Plaignant', _courtBlue)),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(color: _courtRed.withOpacity(0.15), borderRadius: BorderRadius.circular(10), border: Border.all(color: _courtRed.withOpacity(0.3))),
                        child: const Text('VS', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 14)),
                      ),
                    ),
                    Expanded(child: _buildPartyChip(accused, 'Accusé', _courtRed)),
                  ],
                ),
                const SizedBox(height: 10),
                Text(tc.description, style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 13), maxLines: 2, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 8),
                if (tc.totalVotes > 0) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(color: _courtPurple.withOpacity(0.1), borderRadius: BorderRadius.circular(8), border: Border.all(color: _courtPurple.withOpacity(0.2))),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('\u{1F5F3}', style: TextStyle(fontSize: 14)),
                        const SizedBox(width: 6),
                        Text('${tc.totalVotes} vote${tc.totalVotes > 1 ? 's' : ''}', style: TextStyle(color: _courtPurple, fontSize: 11, fontWeight: FontWeight.w700)),
                        const SizedBox(width: 8),
                        Text('\u{274C} ${tc.guiltyVotes}', style: TextStyle(color: _courtRed, fontSize: 11, fontWeight: FontWeight.w700)),
                        const SizedBox(width: 6),
                        Text('\u{2705} ${tc.innocentVotes}', style: TextStyle(color: _courtGreen, fontSize: 11, fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                Row(
                  children: [
                    Icon(Icons.calendar_today_rounded, size: 12, color: Colors.white.withOpacity(0.4)),
                    const SizedBox(width: 4),
                    Text(_formatDate(tc.filedDate), style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 11)),
                    if (tc.scheduledDate != null) ...[
                      const SizedBox(width: 12),
                      Icon(Icons.access_time_rounded, size: 12, color: _courtGold.withOpacity(0.7)),
                      const SizedBox(width: 4),
                      Text('Audience: ${_formatDateTime(tc.scheduledDate!)}', style: TextStyle(color: _courtGold.withOpacity(0.7), fontSize: 11, fontWeight: FontWeight.w600)),
                    ],
                    const Spacer(),
                    if (tc.participants.length > 2)
                      Row(children: [
                        Icon(Icons.people_rounded, size: 12, color: Colors.white.withOpacity(0.4)),
                        const SizedBox(width: 4),
                        Text('${tc.participants.length}', style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 11)),
                      ]),
                  ],
                ),
                if (tc.verdict != null) ...[
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: tc.verdict == TribunalVerdict.guilty ? _courtRed.withOpacity(0.1) : tc.verdict == TribunalVerdict.innocent ? _courtGreen.withOpacity(0.1) : Colors.grey.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        Text(tc.verdictEmoji, style: const TextStyle(fontSize: 18)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Verdict: ${tc.verdictLabel}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13)),
                              if (tc.verdictReason != null)
                                Text(tc.verdictReason!, style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPartyChip(ChildModel? child, String role, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: color.withOpacity(0.2))),
      child: Column(
        children: [
          if (child != null && child.hasPhoto)
            ClipOval(child: Image.memory(base64Decode(child.photoBase64), width: 32, height: 32, fit: BoxFit.cover, errorBuilder: (_, __, ___) => _avatarText(child)))
          else
            _avatarText(child),
          const SizedBox(height: 4),
          Text(child?.name ?? 'Inconnu', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
          Text(role, style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _avatarText(ChildModel? child) {
    return Container(
      width: 32, height: 32,
      decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withOpacity(0.15)),
      child: Center(child: Text(child?.avatar.isNotEmpty == true ? child!.avatar : '\u{1F464}', style: const TextStyle(fontSize: 18))),
    );
  }
  void _showCaseDetail(BuildContext context, TribunalCase tc, FamilyProvider provider) {
    final plaintiff = provider.getChild(tc.plaintiffId);
    final accused = provider.getChild(tc.accusedId);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF0D1B2A),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => DraggableScrollableSheet(
          initialChildSize: 0.85,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          expand: false,
          builder: (_, sc) => ListView(
            controller: sc,
            padding: const EdgeInsets.all(24),
            children: [
              Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[700], borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 16),
              if (tc.status == TribunalStatus.deliberation)
                const Center(child: SizedBox(height: 80, child: ScalesAnimation()))
              else
                const Center(child: Text('\u{2696}', style: TextStyle(fontSize: 40))),
              const SizedBox(height: 8),
              Center(child: Text(tc.title, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800), textAlign: TextAlign.center)),
              const SizedBox(height: 8),
              Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(color: tc.statusColor.withOpacity(0.15), borderRadius: BorderRadius.circular(10), border: Border.all(color: tc.statusColor.withOpacity(0.3))),
                  child: Text('${tc.statusEmoji} ${tc.statusLabel}', style: TextStyle(color: tc.statusColor, fontWeight: FontWeight.w700)),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(child: _buildDetailParty(plaintiff, 'Plaignant', _courtBlue, tc.plaintiffPoints)),
                  const Padding(padding: EdgeInsets.symmetric(horizontal: 8), child: Text('VS', style: TextStyle(color: Colors.white54, fontWeight: FontWeight.w900, fontSize: 20))),
                  Expanded(child: _buildDetailParty(accused, 'Accusé', _courtRed, tc.accusedPoints)),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(14), border: Border.all(color: Colors.white.withOpacity(0.1))),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Motif de la plainte', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14)),
                    const SizedBox(height: 6),
                    Text(tc.description, style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 13)),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _buildVoteSection(ctx, tc, provider, setModalState),
              if (tc.prosecutionLawyer != null || tc.defenseLawyer != null) ...[
                const Text('\u{1F4BC} Avocats', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16)),
                const SizedBox(height: 8),
                if (tc.prosecutionLawyer != null) _buildParticipantTile(tc.prosecutionLawyer!, provider, "Avocat de l'accusation", _courtBlue),
                if (tc.defenseLawyer != null) _buildParticipantTile(tc.defenseLawyer!, provider, 'Avocat de la défense', _courtPurple),
                const SizedBox(height: 16),
              ],
              if (tc.witnesses.isNotEmpty) ...[
                const Text('\u{1F9D1}\u{200D}\u{2696} Témoins', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16)),
                const SizedBox(height: 8),
                ...tc.witnesses.map((w) => _buildParticipantTile(w, provider, 'Témoin', Colors.amber)),
                const SizedBox(height: 16),
              ],
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(14)),
                child: Column(
                  children: [
                    _dateRow(Icons.description_rounded, 'Plainte déposée', _formatDateTime(tc.filedDate), Colors.white54),
                    if (tc.scheduledDate != null) _dateRow(Icons.event_rounded, 'Audience prévue', _formatDateTime(tc.scheduledDate!), _courtGold),
                    if (tc.verdictDate != null) _dateRow(Icons.gavel_rounded, 'Verdict rendu', _formatDateTime(tc.verdictDate!), _courtGreen),
                  ],
                ),
              ),
              if (tc.verdict != null) ...[
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    gradient: LinearGradient(colors: [
                      tc.verdict == TribunalVerdict.guilty ? _courtRed.withOpacity(0.15) : tc.verdict == TribunalVerdict.innocent ? _courtGreen.withOpacity(0.15) : Colors.grey.withOpacity(0.15),
                      Colors.transparent,
                    ]),
                    border: Border.all(color: tc.verdict == TribunalVerdict.guilty ? _courtRed.withOpacity(0.3) : tc.verdict == TribunalVerdict.innocent ? _courtGreen.withOpacity(0.3) : Colors.grey.withOpacity(0.3)),
                  ),
                  child: Column(
                    children: [
                      Text(tc.verdictEmoji, style: const TextStyle(fontSize: 36)),
                      const SizedBox(height: 8),
                      Text('VERDICT: ${tc.verdictLabel.toUpperCase()}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18)),
                      if (tc.verdictReason != null) ...[
                        const SizedBox(height: 8),
                        Text(tc.verdictReason!, style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 13), textAlign: TextAlign.center),
                      ],
                      if (tc.votes.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(color: _courtPurple.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                          child: Column(
                            children: [
                              const Text('\u{1F5F3} Résultats des votes', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13)),
                              const SizedBox(height: 6),
                              ...tc.votes.map((v) {
                                final vChild = provider.getChild(v.childId);
                                final wasRight = v.vote == tc.verdict;
                                return Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 2),
                                  child: Row(
                                    children: [
                                      Text(vChild?.avatar ?? '\u{1F464}', style: const TextStyle(fontSize: 16)),
                                      const SizedBox(width: 6),
                                      Expanded(child: Text(vChild?.name ?? '?', style: const TextStyle(color: Colors.white, fontSize: 12))),
                                      Text(v.vote == TribunalVerdict.guilty ? '\u{274C} Coupable' : '\u{2705} Innocent',
                                          style: TextStyle(color: v.vote == TribunalVerdict.guilty ? _courtRed : _courtGreen, fontSize: 11, fontWeight: FontWeight.w600)),
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(color: (wasRight ? _courtGreen : _courtRed).withOpacity(0.15), borderRadius: BorderRadius.circular(6)),
                                        child: Text(wasRight ? '+1' : '-1', style: TextStyle(color: wasRight ? _courtGreen : _courtRed, fontWeight: FontWeight.w900, fontSize: 12)),
                                      ),
                                    ],
                                  ),
                                );
                              }),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
              if (!tc.isClosed) ...[
                const SizedBox(height: 20),
                _buildActionButtons(ctx, tc, provider),
              ],
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVoteSection(BuildContext ctx, TribunalCase tc, FamilyProvider provider, StateSetter setModalState) {
    final canVoteNow = tc.status == TribunalStatus.inProgress || tc.status == TribunalStatus.deliberation;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _courtPurple.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _courtPurple.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('\u{1F5F3}', style: TextStyle(fontSize: 20)),
              const SizedBox(width: 8),
              const Text('Votes du jury', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16)),
              const Spacer(),
              if (tc.votingEnabled)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: _courtGreen.withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
                  child: Text('Vote ouvert', style: TextStyle(color: _courtGreen, fontSize: 11, fontWeight: FontWeight.w700)),
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: Colors.orange.withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
                  child: Text('Vote fermé', style: TextStyle(color: Colors.orange, fontSize: 11, fontWeight: FontWeight.w700)),
                ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: _courtPurple.withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
                child: Text('${tc.totalVotes} vote${tc.totalVotes > 1 ? 's' : ''}', style: TextStyle(color: _courtPurple, fontSize: 11, fontWeight: FontWeight.w700)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (tc.totalVotes > 0) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: SizedBox(
                height: 24,
                child: Row(
                  children: [
                    if (tc.guiltyVotes > 0)
                      Expanded(
                        flex: tc.guiltyVotes,
                        child: Container(
                          color: _courtRed.withOpacity(0.6),
                          child: Center(child: Text('\u{274C} ${tc.guiltyVotes}', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700))),
                        ),
                      ),
                    if (tc.innocentVotes > 0)
                      Expanded(
                        flex: tc.innocentVotes,
                        child: Container(
                          color: _courtGreen.withOpacity(0.6),
                          child: Center(child: Text('\u{2705} ${tc.innocentVotes}', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700))),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            ...tc.votes.map((v) {
              final vChild = provider.getChild(v.childId);
              return Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    Text(vChild?.avatar ?? '\u{1F464}', style: const TextStyle(fontSize: 16)),
                    const SizedBox(width: 6),
                    Text(vChild?.name ?? '?', style: const TextStyle(color: Colors.white, fontSize: 12)),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: (v.vote == TribunalVerdict.guilty ? _courtRed : _courtGreen).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: (v.vote == TribunalVerdict.guilty ? _courtRed : _courtGreen).withOpacity(0.3)),
                      ),
                      child: Text(
                        v.vote == TribunalVerdict.guilty ? '\u{274C} Coupable' : '\u{2705} Innocent',
                        style: TextStyle(color: v.vote == TribunalVerdict.guilty ? _courtRed : _courtGreen, fontSize: 11, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
              );
            }),
            const SizedBox(height: 10),
          ] else
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                !tc.votingEnabled ? 'Le juge n\'a pas encore ouvert le vote' : 'Aucun vote pour le moment',
                style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 12),
              ),
            ),
          if (canVoteNow && tc.votingEnabled) ...[
            const Divider(color: Colors.white12),
            const SizedBox(height: 6),
            Text('Choisir un enfant pour voter :', style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 12, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            ...provider.children
                .where((c) => tc.canVote(c.id))
                .map((child) => Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white.withOpacity(0.1)),
                      ),
                      child: Row(
                        children: [
                          Text(child.avatar.isNotEmpty ? child.avatar : '\u{1F466}', style: const TextStyle(fontSize: 20)),
                          const SizedBox(width: 8),
                          Expanded(child: Text(child.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13))),
                          TvFocusWrapper(
                            child: _voteButton('\u{274C} Coupable', _courtRed, () async {
                              await provider.castTribunalVote(tc.id, child.id, TribunalVerdict.guilty);
                              setModalState(() {});
                              if (mounted) setState(() {});
                            }),
                          ),
                          const SizedBox(width: 6),
                          TvFocusWrapper(
                            child: _voteButton('\u{2705} Innocent', _courtGreen, () async {
                              await provider.castTribunalVote(tc.id, child.id, TribunalVerdict.innocent);
                              setModalState(() {});
                              if (mounted) setState(() {});
                            }),
                          ),
                        ],
                      ),
                    )),
            if (provider.children.where((c) => tc.canVote(c.id)).isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Text('Tous les enfants éligibles ont voté \u{2705}', style: TextStyle(color: _courtGreen.withOpacity(0.7), fontSize: 12, fontWeight: FontWeight.w600)),
              ),
          ],
        ],
      ),
    );
  }

  Widget _voteButton(String label, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(8), border: Border.all(color: color.withOpacity(0.3))),
        child: Text(label, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w700)),
      ),
    );
  }

  Widget _buildDetailParty(ChildModel? child, String role, Color color, int points) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: color.withOpacity(0.08), borderRadius: BorderRadius.circular(16), border: Border.all(color: color.withOpacity(0.2))),
      child: Column(
        children: [
          if (child != null && child.hasPhoto)
            ClipOval(child: Image.memory(base64Decode(child.photoBase64), width: 50, height: 50, fit: BoxFit.cover, errorBuilder: (_, __, ___) => _bigAvatar(child)))
          else
            _bigAvatar(child),
          const SizedBox(height: 8),
          Text(child?.name ?? '?', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14)),
          Text(role, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
          if (points != 0) ...[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: (points > 0 ? _courtGreen : _courtRed).withOpacity(0.15), borderRadius: BorderRadius.circular(6)),
              child: Text('${points > 0 ? '+' : ''}$points pts', style: TextStyle(color: points > 0 ? _courtGreen : _courtRed, fontWeight: FontWeight.w800, fontSize: 12)),
            ),
          ],
        ],
      ),
    );
  }

  Widget _bigAvatar(ChildModel? child) {
    return Container(
      width: 50, height: 50,
      decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withOpacity(0.15)),
      child: Center(child: Text(child?.avatar.isNotEmpty == true ? child!.avatar : '\u{1F464}', style: const TextStyle(fontSize: 26))),
    );
  }

  Widget _buildParticipantTile(TribunalParticipant participant, FamilyProvider provider, String roleLabel, Color color) {
    final child = provider.getChild(participant.childId);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: color.withOpacity(0.06), borderRadius: BorderRadius.circular(12), border: Border.all(color: color.withOpacity(0.15))),
      child: Row(
        children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(shape: BoxShape.circle, color: color.withOpacity(0.15)),
            child: Center(child: Text(child?.avatar ?? '\u{1F464}', style: const TextStyle(fontSize: 18))),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(child?.name ?? 'Inconnu', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14)),
                Text(roleLabel, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w500)),
                if (participant.testimony != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text('"${participant.testimony}"', style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12, fontStyle: FontStyle.italic), maxLines: 2, overflow: TextOverflow.ellipsis),
                  ),
              ],
            ),
          ),
          if (participant.testimonyVerified != null)
            Icon(participant.testimonyVerified! ? Icons.check_circle : Icons.cancel, color: participant.testimonyVerified! ? _courtGreen : _courtRed, size: 20),
          if (participant.pointsAwarded != 0) ...[
            const SizedBox(width: 8),
            Text('${participant.pointsAwarded > 0 ? '+' : ''}${participant.pointsAwarded}', style: TextStyle(color: participant.pointsAwarded > 0 ? _courtGreen : _courtRed, fontWeight: FontWeight.w800, fontSize: 14)),
          ],
        ],
      ),
    );
  }

  Widget _dateRow(IconData icon, String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Text(label, style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12)),
          const Spacer(),
          Text(value, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildActionButtons(BuildContext ctx, TribunalCase tc, FamilyProvider provider) {
    return Column(
      children: [
        if (tc.status == TribunalStatus.inProgress || tc.status == TribunalStatus.deliberation)
          TvFocusWrapper(
            child: _actionButton(
              tc.votingEnabled ? '\u{1F512} Fermer le vote des jurés' : '\u{1F5F3} Ouvrir le vote des jurés',
              tc.votingEnabled ? Colors.orange : _courtPurple,
              () async {
                if (tc.votingEnabled) {
                  await provider.disableTribunalVoting(tc.id);
                } else {
                  await provider.enableTribunalVoting(tc.id);
                }
                if (ctx.mounted) Navigator.pop(ctx);
              },
            ),
          ),
        if (tc.status == TribunalStatus.filed)
          TvFocusWrapper(
            child: _actionButton('\u{1F4C5} Programmer l\'audience', _courtBlue, () {
              Navigator.pop(ctx);
              _showScheduleHearing(context, tc, provider);
            }),
          ),
        if (tc.status == TribunalStatus.scheduled)
          TvFocusWrapper(
            child: _actionButton('\u{2696} Ouvrir l\'audience', _courtPurple, () async {
              await provider.startTribunalHearing(tc.id);
              if (ctx.mounted) Navigator.pop(ctx);
              if (mounted) await showHearingOpenAnimation(context);
            }),
          ),
        if (tc.status == TribunalStatus.inProgress)
          TvFocusWrapper(
            child: _actionButton('\u{1F914} Passer en délibération', _courtGold, () async {
              await provider.startTribunalDeliberation(tc.id);
              if (ctx.mounted) Navigator.pop(ctx);
              if (mounted) await showDeliberationAnimation(context);
            }),
          ),
        if (tc.status == TribunalStatus.inProgress || tc.status == TribunalStatus.deliberation)
          TvFocusWrapper(
            child: _actionButton('\u{1F528} Rendre le verdict', _courtGreen, () {
              Navigator.pop(ctx);
              _showRenderVerdict(context, tc, provider);
            }),
          ),
        const SizedBox(height: 8),
        TvFocusWrapper(
          child: _actionButton('\u{1F5C4} Classer sans suite', Colors.grey, () async {
            await provider.dismissTribunalCase(tc.id);
            if (ctx.mounted) Navigator.pop(ctx);
          }),
        ),
      ],
    );
  }

  Widget _actionButton(String label, Color color, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: SizedBox(
        width: double.infinity,
        height: 48,
        child: FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: color.withOpacity(0.15),
            foregroundColor: color,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: BorderSide(color: color.withOpacity(0.3))),
          ),
          onPressed: onTap,
          child: Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
        ),
      ),
    );
  }

  void _showFileComplaint(BuildContext context) {
    final provider = context.read<FamilyProvider>();
    if (provider.children.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: const Text('Il faut au moins 2 enfants pour déposer une plainte'), backgroundColor: _courtRed, behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))));
      return;
    }

    final titleCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    String? plaintiffId;
    String? accusedId;
    String? prosecutionLawyerId;
    String? defenseLawyerId;
    List<String> witnessIds = [];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF0D1B2A),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) {
          final availableForLawyers = provider.children.where((c) => c.id != plaintiffId && c.id != accusedId).toList();
          final availableForWitnesses = provider.children.where((c) => c.id != plaintiffId && c.id != accusedId && c.id != prosecutionLawyerId && c.id != defenseLawyerId).toList();

          return Padding(
            padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[700], borderRadius: BorderRadius.circular(2)))),
                  const SizedBox(height: 16),
                  const Row(children: [Text('\u{2696}', style: TextStyle(fontSize: 24)), SizedBox(width: 10), Text('Déposer une plainte', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800))]),
                  const SizedBox(height: 20),
                  TvTextField(
                    controller: titleCtrl,
                    labelText: 'Titre de la plainte',
                    hintText: 'Ex: Vol de jouet, Bagarre...',
                  ),
                  const SizedBox(height: 14),
                  TvTextField(
                    controller: descCtrl,
                    labelText: 'Description des faits',
                    hintText: 'Racontez ce qui s\'est passé...',
                    maxLines: 3,
                  ),
                  const SizedBox(height: 14),
                  _childDropdown('Plaignant (qui porte plainte)', plaintiffId, provider.children, _courtBlue, (v) {
                    setState(() { plaintiffId = v; if (prosecutionLawyerId == v) prosecutionLawyerId = null; if (defenseLawyerId == v) defenseLawyerId = null; witnessIds.remove(v); });
                  }),
                  const SizedBox(height: 14),
                  _childDropdown('Accusé', accusedId, provider.children.where((c) => c.id != plaintiffId).toList(), _courtRed, (v) {
                    setState(() { accusedId = v; if (prosecutionLawyerId == v) prosecutionLawyerId = null; if (defenseLawyerId == v) defenseLawyerId = null; witnessIds.remove(v); });
                  }),
                  if (availableForLawyers.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    _childDropdown("Avocat de l'accusation (optionnel)", prosecutionLawyerId, availableForLawyers, _courtBlue, (v) { setState(() { prosecutionLawyerId = v; witnessIds.remove(v); }); }, optional: true),
                    const SizedBox(height: 14),
                    _childDropdown('Avocat de la défense (optionnel)', defenseLawyerId, availableForLawyers.where((c) => c.id != prosecutionLawyerId).toList(), _courtPurple, (v) { setState(() { defenseLawyerId = v; witnessIds.remove(v); }); }, optional: true),
                  ],
                  if (availableForWitnesses.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    Text('Témoins (optionnel)', style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 13, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8, runSpacing: 8,
                      children: availableForWitnesses.map((c) {
                        final isSelected = witnessIds.contains(c.id);
                        return TvFocusWrapper(
                          child: FilterChip(selected: isSelected, label: Text('${c.avatar.isEmpty ? "\u{1F466}" : c.avatar} ${c.name}'), selectedColor: Colors.amber.withOpacity(0.2), checkmarkColor: Colors.amber, onSelected: (v) { setState(() { if (v) { witnessIds.add(c.id); } else { witnessIds.remove(c.id); } }); }),
                        );
                      }).toList(),
                    ),
                  ],
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity, height: 52,
                    child: TvFocusWrapper(
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(backgroundColor: _courtRed),
                        onPressed: (titleCtrl.text.trim().isNotEmpty && descCtrl.text.trim().isNotEmpty && plaintiffId != null && accusedId != null)
                            ? () async {
                                await provider.fileTribunalCase(title: titleCtrl.text.trim(), description: descCtrl.text.trim(), plaintiffId: plaintiffId!, accusedId: accusedId!, prosecutionLawyerId: prosecutionLawyerId, defenseLawyerId: defenseLawyerId, witnessIds: witnessIds.isNotEmpty ? witnessIds : null);
                                if (ctx.mounted) Navigator.pop(ctx);
                                if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: const Row(children: [Text('\u{2696}', style: TextStyle(fontSize: 18)), SizedBox(width: 8), Text('Plainte déposée !')]), backgroundColor: _courtRed, behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))));
                              }
                            : null,
                        icon: const Icon(Icons.gavel_rounded),
                        label: const Text('Déposer la plainte', style: TextStyle(fontWeight: FontWeight.w700)),
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

  Widget _childDropdown(String label, String? value, List<ChildModel> children, Color color, ValueChanged<String?> onChanged, {bool optional = false}) {
    return DropdownButtonFormField<String>(
      value: value,
      dropdownColor: const Color(0xFF162033),
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(labelText: label, labelStyle: TextStyle(color: color.withOpacity(0.7)), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: color.withOpacity(0.3)))),
      items: [
        if (optional) const DropdownMenuItem(value: null, child: Text('Aucun', style: TextStyle(color: Colors.grey))),
        ...children.map((c) => DropdownMenuItem(value: c.id, child: Text('${c.avatar.isEmpty ? "\u{1F466}" : c.avatar} ${c.name}'))),
      ],
      onChanged: onChanged,
    );
  }

  void _showScheduleHearing(BuildContext context, TribunalCase tc, FamilyProvider provider) {
    DateTime selectedDate = DateTime.now().add(const Duration(days: 1));
    TimeOfDay selectedTime = const TimeOfDay(hour: 14, minute: 0);

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0D1B2A),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[700], borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 16),
              const Text('\u{1F4C5} Programmer l\'audience', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(height: 20),
              TvFocusWrapper(
                autofocus: true,
                child: ListTile(
                  leading: const Icon(Icons.calendar_today_rounded, color: Color(0xFF448AFF)),
                  title: Text('${selectedDate.day}/${selectedDate.month}/${selectedDate.year}', style: const TextStyle(color: Colors.white)),
                  subtitle: const Text('Date', style: TextStyle(color: Colors.grey)),
                  onTap: () async {
                    final picked = await showDatePicker(context: ctx, initialDate: selectedDate, firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 365)));
                    if (picked != null) setState(() => selectedDate = picked);
                  },
                ),
              ),
              TvFocusWrapper(
                child: ListTile(
                  leading: const Icon(Icons.access_time_rounded, color: Color(0xFFFFD740)),
                  title: Text('${selectedTime.hour}:${selectedTime.minute.toString().padLeft(2, '0')}', style: const TextStyle(color: Colors.white)),
                  subtitle: const Text('Heure', style: TextStyle(color: Colors.grey)),
                  onTap: () async {
                    final picked = await showTimePicker(context: ctx, initialTime: selectedTime);
                    if (picked != null) setState(() => selectedTime = picked);
                  },
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity, height: 52,
                child: TvFocusWrapper(
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(backgroundColor: _courtBlue),
                    onPressed: () async {
                      final date = DateTime(selectedDate.year, selectedDate.month, selectedDate.day, selectedTime.hour, selectedTime.minute);
                      await provider.scheduleTribunalHearing(tc.id, date);
                      if (ctx.mounted) Navigator.pop(ctx);
                    },
                    icon: const Icon(Icons.event_rounded),
                    label: const Text('Confirmer', style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showRenderVerdict(BuildContext context, TribunalCase tc, FamilyProvider provider) {
    TribunalVerdict? selectedVerdict;
    final reasonCtrl = TextEditingController();
    int plaintiffPts = 0;
    int accusedPts = 0;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF0D1B2A),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => Padding(
          padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[700], borderRadius: BorderRadius.circular(2)))),
                const SizedBox(height: 16),
                const Center(child: Text('\u{1F528} Rendre le verdict', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800))),
                const SizedBox(height: 20),
                const Text('Verdict', style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _verdictChip('\u{274C} Coupable', TribunalVerdict.guilty, _courtRed, selectedVerdict, (v) => setState(() => selectedVerdict = v)),
                    const SizedBox(width: 8),
                    _verdictChip('\u{2705} Innocent', TribunalVerdict.innocent, _courtGreen, selectedVerdict, (v) => setState(() => selectedVerdict = v)),
                    const SizedBox(width: 8),
                    _verdictChip('\u{1F5C4} Classé', TribunalVerdict.dismissed, Colors.grey, selectedVerdict, (v) => setState(() => selectedVerdict = v)),
                  ],
                ),
                const SizedBox(height: 16),
                TvTextField(
                  controller: reasonCtrl,
                  labelText: 'Raison du verdict',
                  maxLines: 2,
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(child: _pointsField('Plaignant (pts)', plaintiffPts, (v) => setState(() => plaintiffPts = v))),
                    const SizedBox(width: 12),
                    Expanded(child: _pointsField('Accusé (pts)', accusedPts, (v) => setState(() => accusedPts = v))),
                  ],
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity, height: 52,
                  child: TvFocusWrapper(
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(backgroundColor: _courtGreen),
                      onPressed: selectedVerdict != null
                          ? () async {
                              await provider.renderVerdict(caseId: tc.id, verdict: selectedVerdict!, reason: reasonCtrl.text.trim().isEmpty ? selectedVerdict!.name : reasonCtrl.text.trim(), plaintiffPoints: plaintiffPts, accusedPoints: accusedPts);
                              if (ctx.mounted) Navigator.pop(ctx);
                              if (mounted) await showVerdictAnimation(context, selectedVerdict!);
                            }
                          : null,
                      icon: const Icon(Icons.gavel_rounded),
                      label: const Text('Prononcer le verdict', style: TextStyle(fontWeight: FontWeight.w700)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _verdictChip(String label, TribunalVerdict verdict, Color color, TribunalVerdict? selected, ValueChanged<TribunalVerdict> onTap) {
    final isSelected = selected == verdict;
    return Expanded(
      child: TvFocusWrapper(
        child: GestureDetector(
          onTap: () => onTap(verdict),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: isSelected ? color.withOpacity(0.2) : Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: isSelected ? color : Colors.white.withOpacity(0.1), width: isSelected ? 2 : 1),
            ),
            child: Center(child: Text(label, style: TextStyle(color: isSelected ? color : Colors.white54, fontSize: 11, fontWeight: FontWeight.w700))),
          ),
        ),
      ),
    );
  }

  Widget _pointsField(String label, int value, ValueChanged<int> onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 12)),
        const SizedBox(height: 6),
        Row(
          children: [
            TvFocusWrapper(child: IconButton(icon: Icon(Icons.remove_circle_rounded, color: _courtRed, size: 28), onPressed: () => onChanged(value - 1))),
            Expanded(child: Center(child: Text('$value', style: TextStyle(color: value > 0 ? _courtGreen : value < 0 ? _courtRed : Colors.white, fontWeight: FontWeight.w900, fontSize: 20)))),
            TvFocusWrapper(child: IconButton(icon: Icon(Icons.add_circle_rounded, color: _courtGreen, size: 28), onPressed: () => onChanged(value + 1))),
          ],
        ),
      ],
    );
  }

  String _formatDate(DateTime d) => '${d.day}/${d.month}/${d.year}';
  String _formatDateTime(DateTime d) => '${d.day}/${d.month}/${d.year} ${d.hour}:${d.minute.toString().padLeft(2, '0')}';
}
