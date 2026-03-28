import 'package:flutter/material.dart';
import 'dart:math' as math;

class AnimatedBackground extends StatefulWidget {
  final Widget child;
  final List<Color>? colors;
  final int particleCount;
  final bool showStars;
  final bool showNebula;

  const AnimatedBackground({
    super.key,
    required this.child,
    this.colors,
    this.particleCount = 30,
    this.showStars = true,
    this.showNebula = true,
  });

  @override
  State<AnimatedBackground> createState() => _AnimatedBackgroundState();
}

class _AnimatedBackgroundState extends State<AnimatedBackground>
    with TickerProviderStateMixin {
  late AnimationController _particleController;
  late AnimationController _breathController;
  late AnimationController _starController;
  late AnimationController _nebulaController;

  late List<_Particle> _particles;
  late List<_Star> _stars;
  late Animation<double> _breathAnim;

  final _rng = math.Random();

  @override
  void initState() {
    super.initState();

    // Particles
    _particleController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    )..repeat();

    // Breathing gradient
    _breathController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat(reverse: true);
    _breathAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _breathController, curve: Curves.easeInOut),
    );

    // Stars twinkle
    _starController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();

    // Nebula drift
    _nebulaController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 15),
    )..repeat(reverse: true);

    // Generate particles
    _particles = List.generate(widget.particleCount, (_) => _Particle(_rng));

    // Generate stars
    _stars = List.generate(
      widget.showStars ? 40 : 0,
      (_) => _Star(_rng),
    );
  }

  @override
  void dispose() {
    _particleController.dispose();
    _breathController.dispose();
    _starController.dispose();
    _nebulaController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final defaultColors = [
      const Color(0xFF0A0A1A),
      const Color(0xFF0D1B2A),
      const Color(0xFF1B1040),
      const Color(0xFF0A0A1A),
    ];
    final bgColors = widget.colors ?? defaultColors;

    return Stack(
      children: [
        // Breathing gradient background
        AnimatedBuilder(
          animation: _breathAnim,
          builder: (context, _) {
            final shift = _breathAnim.value * 0.15;
            return Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment(-0.5 + shift, -1.0 + shift),
                  end: Alignment(0.5 - shift, 1.0 - shift),
                  colors: bgColors,
                ),
              ),
            );
          },
        ),

        // Nebula blobs
        if (widget.showNebula)
          AnimatedBuilder(
            animation: _nebulaController,
            builder: (context, _) {
              return CustomPaint(
                size: MediaQuery.of(context).size,
                painter: _NebulaPainter(
                  progress: _nebulaController.value,
                ),
              );
            },
          ),

        // Stars layer
        if (widget.showStars)
          AnimatedBuilder(
            animation: _starController,
            builder: (context, _) {
              return CustomPaint(
                size: MediaQuery.of(context).size,
                painter: _StarsPainter(
                  stars: _stars,
                  time: _starController.value,
                ),
              );
            },
          ),

        // Floating particles
        AnimatedBuilder(
          animation: _particleController,
          builder: (context, _) {
            return CustomPaint(
              size: MediaQuery.of(context).size,
              painter: _ParticlePainter(
                particles: _particles,
                time: _particleController.value,
              ),
            );
          },
        ),

        // Top vignette overlay
        Container(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: Alignment.center,
              radius: 1.2,
              colors: [
                Colors.transparent,
                Colors.black.withOpacity(0.3),
              ],
            ),
          ),
        ),

        // Child content
        widget.child,
      ],
    );
  }
}

// ─── Particle model ───
class _Particle {
  late double x, y, size, speed, opacity, phase;
  late Color color;

  _Particle(math.Random rng) {
    x = rng.nextDouble();
    y = rng.nextDouble();
    size = 1.5 + rng.nextDouble() * 3;
    speed = 0.2 + rng.nextDouble() * 0.8;
    opacity = 0.1 + rng.nextDouble() * 0.4;
    phase = rng.nextDouble() * 6.2832;
    final colors = [
      Colors.cyan.withOpacity(0.6),
      Colors.blue.withOpacity(0.5),
      Colors.purple.withOpacity(0.4),
      Colors.white.withOpacity(0.3),
      Colors.teal.withOpacity(0.4),
    ];
    color = colors[rng.nextInt(colors.length)];
  }
}

class _ParticlePainter extends CustomPainter {
  final List<_Particle> particles;
  final double time;

  _ParticlePainter({required this.particles, required this.time});

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in particles) {
      // Float upward, drift horizontally with sine
      final t = (time * p.speed + p.phase) % 1.0;
      final px = (p.x + math.sin(t * 6.2832 + p.phase) * 0.04) * size.width;
      final py = (p.y - t * 0.3).remainder(1.0).abs() * size.height;

      // Twinkle
      final twinkle = 0.5 + 0.5 * math.sin(time * 6.2832 * 2 + p.phase);
      final currentOpacity = (p.opacity * twinkle).clamp(0.0, 1.0);

      final paint = Paint()
        ..color = p.color.withOpacity(currentOpacity)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, p.size * 0.8);

      canvas.drawCircle(Offset(px, py), p.size, paint);

      // Small bright core
      final corePaint = Paint()
        ..color = Colors.white.withOpacity(currentOpacity * 0.6);
      canvas.drawCircle(Offset(px, py), p.size * 0.3, corePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _ParticlePainter old) => true;
}

// ─── Star model ───
class _Star {
  late double x, y, size, twinkleSpeed, phase;

  _Star(math.Random rng) {
    x = rng.nextDouble();
    y = rng.nextDouble();
    size = 0.5 + rng.nextDouble() * 1.5;
    twinkleSpeed = 1.0 + rng.nextDouble() * 3.0;
    phase = rng.nextDouble() * 6.2832;
  }
}

class _StarsPainter extends CustomPainter {
  final List<_Star> stars;
  final double time;

  _StarsPainter({required this.stars, required this.time});

  @override
  void paint(Canvas canvas, Size size) {
    for (final s in stars) {
      final twinkle =
          0.3 + 0.7 * ((math.sin(time * 6.2832 * s.twinkleSpeed + s.phase) + 1) / 2);
      final px = s.x * size.width;
      final py = s.y * size.height;

      // Star glow
      final glowPaint = Paint()
        ..color = Colors.white.withOpacity(twinkle * 0.15)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, s.size * 3);
      canvas.drawCircle(Offset(px, py), s.size * 2, glowPaint);

      // Star core
      final corePaint = Paint()
        ..color = Colors.white.withOpacity(twinkle * 0.8);
      canvas.drawCircle(Offset(px, py), s.size, corePaint);

      // Cross sparkle for bright stars
      if (s.size > 1.0 && twinkle > 0.7) {
        final sparklePaint = Paint()
          ..color = Colors.white.withOpacity((twinkle - 0.7) * 2)
          ..strokeWidth = 0.5;
        final len = s.size * 3 * twinkle;
        canvas.drawLine(
            Offset(px - len, py), Offset(px + len, py), sparklePaint);
        canvas.drawLine(
            Offset(px, py - len), Offset(px, py + len), sparklePaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _StarsPainter old) => true;
}

// ─── Nebula painter ───
class _NebulaPainter extends CustomPainter {
  final double progress;

  _NebulaPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    // Blob 1 - cyan
    _drawNebula(
      canvas,
      Offset(
        size.width * (0.2 + 0.15 * math.sin(progress * 6.2832)),
        size.height * (0.3 + 0.1 * math.cos(progress * 6.2832)),
      ),
      size.width * 0.35,
      Colors.cyan.withOpacity(0.03),
    );

    // Blob 2 - purple
    _drawNebula(
      canvas,
      Offset(
        size.width * (0.7 - 0.1 * math.cos(progress * 6.2832 + 1)),
        size.height * (0.6 + 0.15 * math.sin(progress * 6.2832 + 2)),
      ),
      size.width * 0.4,
      Colors.purple.withOpacity(0.025),
    );

    // Blob 3 - blue
    _drawNebula(
      canvas,
      Offset(
        size.width * (0.5 + 0.2 * math.sin(progress * 6.2832 + 3)),
        size.height * (0.15 + 0.1 * math.cos(progress * 6.2832 + 1)),
      ),
      size.width * 0.3,
      Colors.blue.withOpacity(0.02),
    );
  }

  void _drawNebula(Canvas canvas, Offset center, double radius, Color color) {
    final paint = Paint()
      ..color = color
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, radius * 0.6);
    canvas.drawCircle(center, radius, paint);
  }

  @override
  bool shouldRepaint(covariant _NebulaPainter old) =>
      progress != old.progress;
}
