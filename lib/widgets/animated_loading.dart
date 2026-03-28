import 'package:flutter/material.dart';
import 'dart:math' as math;

/// Loading spinner custom avec orbites
class AnimatedLoading extends StatefulWidget {
  final String? message;
  final Color color;
  final double size;

  const AnimatedLoading({
    super.key,
    this.message,
    this.color = Colors.cyan,
    this.size = 50,
  });

  @override
  State<AnimatedLoading> createState() => _AnimatedLoadingState();
}

class _AnimatedLoadingState extends State<AnimatedLoading>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: widget.size,
          height: widget.size,
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              return CustomPaint(
                painter: _OrbitLoadingPainter(
                  progress: _controller.value,
                  color: widget.color,
                ),
              );
            },
          ),
        ),
        if (widget.message != null) ...[
          const SizedBox(height: 16),
          // Pulsing text
          AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              final opacity =
                  0.4 + 0.6 * (math.sin(_controller.value * 6.2832) + 1) / 2;
              return Opacity(opacity: opacity, child: child);
            },
            child: Text(
              widget.message!,
              style: TextStyle(color: widget.color, fontSize: 14),
            ),
          ),
        ],
      ],
    );
  }
}

class _OrbitLoadingPainter extends CustomPainter {
  final double progress;
  final Color color;

  _OrbitLoadingPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 5;

    // Draw orbit ring
    final ringPaint = Paint()
      ..color = color.withOpacity(0.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawCircle(center, radius, ringPaint);

    // Draw 3 orbiting dots
    for (int i = 0; i < 3; i++) {
      final angle =
          progress * 6.2832 + (i * 6.2832 / 3);
      final dotX = center.dx + radius * math.cos(angle);
      final dotY = center.dy + radius * math.sin(angle);

      // Dot with trail
      final dotSize = 4.0 - i * 0.8;
      final opacity = (1.0 - i * 0.25).clamp(0.3, 1.0);

      final dotPaint = Paint()
        ..color = color.withOpacity(opacity)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, dotSize * 0.5);
      canvas.drawCircle(Offset(dotX, dotY), dotSize, dotPaint);

      // Bright core
      final corePaint = Paint()..color = Colors.white.withOpacity(opacity * 0.8);
      canvas.drawCircle(Offset(dotX, dotY), dotSize * 0.4, corePaint);
    }

    // Center glow
    final centerGlow = Paint()
      ..color = color.withOpacity(0.1 + 0.1 * math.sin(progress * 12.5664))
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    canvas.drawCircle(center, 6, centerGlow);

    final centerCore = Paint()
      ..color = color.withOpacity(0.5);
    canvas.drawCircle(center, 3, centerCore);
  }

  @override
  bool shouldRepaint(covariant _OrbitLoadingPainter old) => true;
}

/// Skeleton loading shimmer effect
class ShimmerLoading extends StatefulWidget {
  final double width;
  final double height;
  final double borderRadius;

  const ShimmerLoading({
    super.key,
    this.width = double.infinity,
    this.height = 60,
    this.borderRadius = 12,
  });

  @override
  State<ShimmerLoading> createState() => _ShimmerLoadingState();
}

class _ShimmerLoadingState extends State<ShimmerLoading>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
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
      builder: (context, _) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.borderRadius),
            gradient: LinearGradient(
              begin: Alignment(-1.5 + 3 * _controller.value, 0),
              end: Alignment(-0.5 + 3 * _controller.value, 0),
              colors: [
                Colors.white.withOpacity(0.04),
                Colors.white.withOpacity(0.1),
                Colors.white.withOpacity(0.04),
              ],
            ),
          ),
        );
      },
    );
  }
}
