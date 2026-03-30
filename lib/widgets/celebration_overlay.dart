import 'dart:math';
import 'package:flutter/material.dart';

// ═══════════════════════════════════════════════════════════
//  CONFETTIS EXPLOSION
// ═══════════════════════════════════════════════════════════
class ConfettiOverlay extends StatefulWidget {
  final VoidCallback onComplete;
  final String? message;
  final Color? color;
  const ConfettiOverlay({super.key, required this.onComplete, this.message, this.color});
  @override
  State<ConfettiOverlay> createState() => _ConfettiOverlayState();
}

class _ConfettiOverlayState extends State<ConfettiOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  final _rng = Random();
  late List<_Particle> _particles;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 2500))
      ..forward().then((_) => widget.onComplete());
    _particles = List.generate(
        60,
        (i) => _Particle(
              x: _rng.nextDouble(),
              speed: 100 + _rng.nextDouble() * 400,
              size: 3 + _rng.nextDouble() * 6,
              color: [
                Colors.amber,
                Colors.greenAccent,
                Colors.cyanAccent,
                Colors.pinkAccent,
                Colors.purpleAccent,
                Colors.orangeAccent,
                Colors.white,
              ][_rng.nextInt(7)],
              rotSpeed: (_rng.nextDouble() - 0.5) * 12,
              wobble: _rng.nextDouble() * 2 * pi,
              delay: _rng.nextDouble() * 0.3,
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
        return Stack(
          children: [
            // Particles
            CustomPaint(
              size: Size.infinite,
              painter: _ConfettiPainter(_particles, t),
            ),
            // Message central
            if (widget.message != null && t > 0.1 && t < 0.85)
              Center(
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.0, end: 1.0),
                  duration: const Duration(milliseconds: 500),
                  curve: Curves.elasticOut,
                  builder: (context, val, child) =>
                      Transform.scale(scale: val, child: child),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 32, vertical: 20),
                    decoration: BoxDecoration(
                      color: (widget.color ?? Colors.amber).withOpacity(0.9),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color:
                              (widget.color ?? Colors.amber).withOpacity(0.5),
                          blurRadius: 30,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                    child: Text(
                      widget.message!,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 2),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _Particle {
  final double x, speed, size, rotSpeed, wobble, delay;
  final Color color;
  _Particle({
    required this.x,
    required this.speed,
    required this.size,
    required this.color,
    required this.rotSpeed,
    required this.wobble,
    required this.delay,
  });
}

class _ConfettiPainter extends CustomPainter {
  final List<_Particle> particles;
  final double t;
  _ConfettiPainter(this.particles, this.t);

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in particles) {
      final pt = ((t - p.delay) / (1.0 - p.delay)).clamp(0.0, 1.0);
      if (pt <= 0) continue;
      final dx = p.x * size.width + sin(p.wobble + pt * 8) * 30;
      final dy = -20 + p.speed * pt;
      if (dy > size.height + 20) continue;
      final opacity = (1.0 - pt * 0.6).clamp(0.0, 1.0);
      canvas.save();
      canvas.translate(dx, dy);
      canvas.rotate(p.rotSpeed * pt);
      final paint = Paint()..color = p.color.withOpacity(opacity);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
              center: Offset.zero, width: p.size, height: p.size * 0.5),
          const Radius.circular(1),
        ),
        paint,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiPainter old) => true;
}

// ═══════════════════════════════════════════════════════════
//  POINTS VOLANTS (+10, +5, etc.)
// ═══════════════════════════════════════════════════════════
class FlyingPointsOverlay extends StatefulWidget {
  final int points;
  final VoidCallback onComplete;
  final Color? color;
  const FlyingPointsOverlay(
      {super.key, required this.points, required this.onComplete, this.color});
  @override
  State<FlyingPointsOverlay> createState() => _FlyingPointsOverlayState();
}

class _FlyingPointsOverlayState extends State<FlyingPointsOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1500))
      ..forward().then((_) => widget.onComplete());
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isPositive = widget.points >= 0;
    final color = widget.color ??
        (isPositive ? Colors.greenAccent : Colors.redAccent);

    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        final t = _ctrl.value;
        final yOffset = -120 * t;
        final opacity = (1.0 - t).clamp(0.0, 1.0);
        final scale = 1.0 + t * 0.5;

        return Center(
          child: Transform.translate(
            offset: Offset(0, yOffset),
            child: Opacity(
              opacity: opacity,
              child: Transform.scale(
                scale: scale,
                child: Text(
                  '${isPositive ? '+' : ''}${widget.points}',
                  style: TextStyle(
                    color: color,
                    fontSize: 48,
                    fontWeight: FontWeight.w900,
                    shadows: [
                      Shadow(color: color.withOpacity(0.6), blurRadius: 20),
                      Shadow(color: color.withOpacity(0.3), blurRadius: 40),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

// ═══════════════════════════════════════════════════════════
//  NEON PULSE RING (autour d'un widget)
// ═══════════════════════════════════════════════════════════
class NeonPulseRing extends StatefulWidget {
  final Widget child;
  final Color color;
  final double radius;
  const NeonPulseRing(
      {super.key,
      required this.child,
      this.color = Colors.cyanAccent,
      this.radius = 60});
  @override
  State<NeonPulseRing> createState() => _NeonPulseRingState();
}

class _NeonPulseRingState extends State<NeonPulseRing>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 2000))
      ..repeat();
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
      builder: (context, child) {
        return CustomPaint(
          painter: _NeonRingPainter(
            progress: _ctrl.value,
            color: widget.color,
            radius: widget.radius,
          ),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

class _NeonRingPainter extends CustomPainter {
  final double progress;
  final Color color;
  final double radius;
  _NeonRingPainter(
      {required this.progress, required this.color, required this.radius});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final r = radius + 10 * sin(progress * 2 * pi);
    final opacity = (0.2 + 0.3 * sin(progress * 2 * pi)).clamp(0.0, 1.0);

    final paint = Paint()
      ..color = color.withOpacity(opacity)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, 6 + 4 * sin(progress * 2 * pi));

    canvas.drawCircle(center, r, paint);

    // Second ring plus léger
    final paint2 = Paint()
      ..color = color.withOpacity(opacity * 0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, 10);
    canvas.drawCircle(center, r + 8, paint2);
  }

  @override
  bool shouldRepaint(covariant _NeonRingPainter old) =>
      progress != old.progress;
}

// ═══════════════════════════════════════════════════════════
//  HELPERS POUR AFFICHER LES OVERLAYS
// ═══════════════════════════════════════════════════════════
Future<void> showConfetti(BuildContext context, {String? message, Color? color}) {
  return showGeneralDialog(
    context: context,
    barrierDismissible: false,
    barrierColor: Colors.black54,
    transitionDuration: const Duration(milliseconds: 100),
    pageBuilder: (ctx, _, __) => Material(
      color: Colors.transparent,
      child: ConfettiOverlay(
        message: message,
        color: color,
        onComplete: () => Navigator.of(ctx).pop(),
      ),
    ),
  );
}

Future<void> showFlyingPoints(BuildContext context, int points, {Color? color}) {
  return showGeneralDialog(
    context: context,
    barrierDismissible: false,
    barrierColor: Colors.transparent,
    transitionDuration: const Duration(milliseconds: 50),
    pageBuilder: (ctx, _, __) => Material(
      color: Colors.transparent,
      child: FlyingPointsOverlay(
        points: points,
        color: color,
        onComplete: () => Navigator.of(ctx).pop(),
      ),
    ),
  );
}
