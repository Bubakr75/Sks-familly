// lib/widgets/aurora_background.dart
//
// Fond "Aurora Verre" : dégradé sombre + 4 blobs colorés (violet/cyan/rose/indigo)
// qui flottent et se mélangent lentement pour créer une ambiance aurore immersive.
//
// Utilisation : AuroraBackground(child: ...)

import 'dart:math';
import 'package:flutter/material.dart';

class AuroraBackground extends StatefulWidget {
  final Widget child;
  final bool animated; // permet de désactiver l'animation si besoin (perf)

  const AuroraBackground({
    super.key,
    required this.child,
    this.animated = true,
  });

  @override
  State<AuroraBackground> createState() => _AuroraBackgroundState();
}

class _AuroraBackgroundState extends State<AuroraBackground>
    with TickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    );
    if (widget.animated) _controller.repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF0A0A1F),
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return CustomPaint(
            painter: _AuroraPainter(_controller.value),
            size: Size.infinite,
            child: widget.child,
          );
        },
      ),
    );
  }
}

/// Peint les blobs aurore colorés qui flottent.
class _AuroraPainter extends CustomPainter {
  final double t; // progression 0..1 de l'animation

  _AuroraPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    // Oscillations douces basées sur le temps
    final w = size.width;
    final h = size.height;

    // 4 blobs avec positions/couleurs qui évoluent
    _drawBlob(canvas, size,
      cx: w * (0.15 + 0.08 * sin(t * 2 * pi)),
      cy: h * (0.10 + 0.06 * sin(t * 2 * pi + 1)),
      r: w * 0.55,
      color: const Color(0xFF7C4DFF), // violet
      alpha: 0.55,
    );
    _drawBlob(canvas, size,
      cx: w * (0.85 + 0.07 * sin(t * 2 * pi + 2)),
      cy: h * (0.20 + 0.08 * sin(t * 2 * pi + 0.5)),
      r: w * 0.50,
      color: const Color(0xFF00E5FF), // cyan
      alpha: 0.45,
    );
    _drawBlob(canvas, size,
      cx: w * (0.20 + 0.10 * sin(t * 2 * pi + 1.5)),
      cy: h * (0.85 + 0.07 * sin(t * 2 * pi + 3)),
      r: w * 0.55,
      color: const Color(0xFFEC4899), // rose
      alpha: 0.40,
    );
    _drawBlob(canvas, size,
      cx: w * (0.80 + 0.06 * sin(t * 2 * pi + 4)),
      cy: h * (0.75 + 0.09 * sin(t * 2 * pi + 2.5)),
      r: w * 0.48,
      color: const Color(0xFF4F46E5), // indigo
      alpha: 0.38,
    );
  }

  void _drawBlob(Canvas canvas, Size size,
      {required double cx, required double cy, required double r, required Color color, required double alpha}) {
    final rect = Rect.fromCircle(center: Offset(cx, cy), radius: r);
    final paint = Paint()
      ..shader = RadialGradient(
        colors: [
          color.withValues(alpha: alpha),
          color.withValues(alpha: 0.0),
        ],
      ).createShader(rect);
    // Le MaskFilter blur donne le fondu doux des blobs aurore
    paint.maskFilter = const MaskFilter.blur(BlurStyle.normal, 60);
    canvas.drawCircle(Offset(cx, cy), r, paint);
  }

  @override
  bool shouldRepaint(covariant _AuroraPainter old) => old.t != t;
}
