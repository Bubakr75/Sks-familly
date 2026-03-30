import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';

/// Animated floating particles background
class ParticlesBackground extends StatefulWidget {
  final Widget child;
  final int particleCount;
  final List<Color>? colors;

  const ParticlesBackground({
    super.key,
    required this.child,
    this.particleCount = 30,
    this.colors,
  });

  @override
  State<ParticlesBackground> createState() => _ParticlesBackgroundState();
}

class _ParticlesBackgroundState extends State<ParticlesBackground>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late List<_Particle> _particles;
  final _random = Random();

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    )..repeat();
    _particles =
        List.generate(widget.particleCount, (_) => _createParticle());
  }

  _Particle _createParticle() {
    final colors = widget.colors ??
        [
          const Color(0xFF00E676),
          const Color(0xFF00BCD4),
          const Color(0xFF7C4DFF),
          const Color(0xFFFFD740),
          const Color(0xFF00E5FF),
        ];
    return _Particle(
      x: _random.nextDouble(),
      y: _random.nextDouble(),
      size: _random.nextDouble() * 4 + 1,
      speedX: (_random.nextDouble() - 0.5) * 0.3,
      speedY: (_random.nextDouble() - 0.5) * 0.3,
      opacity: _random.nextDouble() * 0.4 + 0.1,
      color: colors[_random.nextInt(colors.length)],
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF0A0E21),
                Color(0xFF0D1B2A),
                Color(0xFF0A2342),
                Color(0xFF0D1B2A),
              ],
              stops: [0.0, 0.3, 0.7, 1.0],
            ),
          ),
        ),
        AnimatedBuilder(
          animation: _controller,
          builder: (_, __) => CustomPaint(
            size: Size.infinite,
            painter: _ParticlesPainter(_particles, _controller.value),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: const Alignment(-0.5, -0.8),
              radius: 1.5,
              colors: [
                const Color(0xFF00E676).withOpacity(0.05),
                Colors.transparent,
              ],
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: const Alignment(0.7, 0.6),
              radius: 1.2,
              colors: [
                const Color(0xFF00BCD4).withOpacity(0.04),
                Colors.transparent,
              ],
            ),
          ),
        ),
        widget.child,
      ],
    );
  }
}

class _Particle {
  double x, y, size, speedX, speedY, opacity;
  Color color;

  _Particle({
    required this.x,
    required this.y,
    required this.size,
    required this.speedX,
    required this.speedY,
    required this.opacity,
    required this.color,
  });
}

class _ParticlesPainter extends CustomPainter {
  final List<_Particle> particles;
  final double progress;

  _ParticlesPainter(this.particles, this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in particles) {
      final x = ((p.x + p.speedX * progress) % 1.0) * size.width;
      final y = ((p.y + p.speedY * progress) % 1.0) * size.height;

      final paint = Paint()
        ..color = p.color.withOpacity(
            p.opacity * (0.5 + 0.5 * sin(progress * pi * 2 + p.x * 10)))
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, p.size * 2);

      canvas.drawCircle(Offset(x, y), p.size, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _ParticlesPainter old) => true;
}

/// Texte néon avec effet de lueur
class NeonText extends StatelessWidget {
  final String text;
  final double fontSize;
  final Color color;
  final FontWeight fontWeight;
  final double glowIntensity; // ✅ paramètre optionnel ajouté

  const NeonText({
    super.key,
    required this.text,
    this.fontSize = 24,
    this.color = const Color(0xFF00E676),
    this.fontWeight = FontWeight.bold,
    this.glowIntensity = 0.6, // ✅ valeur par défaut
  });

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontSize: fontSize,
        fontWeight: fontWeight,
        color: color,
        shadows: [
          Shadow(
              color: color.withOpacity(glowIntensity),
              blurRadius: 12),
          Shadow(
              color: color.withOpacity(glowIntensity * 0.5),
              blurRadius: 24),
        ],
      ),
    );
  }
}

/// Anneau lumineux animé autour d'un avatar
class GlowRing extends StatefulWidget {
  final Widget child;
  final double size;
  final Color color;
  final double strokeWidth;

  const GlowRing({
    super.key,
    required this.child,
    this.size = 60,
    this.color = const Color(0xFF00E676),
    this.strokeWidth = 2.5,
  });

  @override
  State<GlowRing> createState() => _GlowRingState();
}

class _GlowRingState extends State<GlowRing>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (_, __) {
        final glowIntensity =
            0.3 + 0.3 * sin(_controller.value * pi * 2);
        return Container(
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: widget.color.withOpacity(glowIntensity),
                blurRadius: 16,
                spreadRadius: 2,
              ),
            ],
            border: Border.all(
              color: widget.color.withOpacity(
                  0.6 + 0.4 * sin(_controller.value * pi * 2)),
              width: widget.strokeWidth,
            ),
          ),
          child: ClipOval(child: widget.child),
        );
      },
    );
  }
}

/// Barre de progression avec dégradé et lueur
class GlowProgressBar extends StatelessWidget {
  final double value;
  final double height;
  final Color startColor;
  final Color endColor;

  const GlowProgressBar({
    super.key,
    required this.value,
    this.height = 8,
    this.startColor = const Color(0xFF00E676),
    this.endColor = const Color(0xFF00BCD4),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(height / 2),
        color: Colors.white.withOpacity(0.08),
      ),
      child: FractionallySizedBox(
        alignment: Alignment.centerLeft,
        widthFactor: value.clamp(0.0, 1.0),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(height / 2),
            gradient: LinearGradient(
                colors: [startColor, endColor]),
            boxShadow: [
              BoxShadow(
                color: endColor.withOpacity(0.5),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Icône avec effet de lueur (glow)
class GlowIcon extends StatelessWidget {
  final IconData icon;
  final double size;
  final Color? color;

  const GlowIcon({
    super.key,
    required this.icon,
    this.size = 24,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final c = color ?? Theme.of(context).colorScheme.primary;
    return Icon(
      icon,
      size: size,
      color: c,
      shadows: [
        Shadow(color: c.withOpacity(0.6), blurRadius: 12),
        Shadow(color: c.withOpacity(0.3), blurRadius: 24),
      ],
    );
  }
}
