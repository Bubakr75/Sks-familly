import 'package:flutter/material.dart';
import 'dart:math' as math;

class ConfettiOverlay extends StatefulWidget {
  final Duration duration;
  final int particleCount;
  final VoidCallback? onComplete;

  const ConfettiOverlay({
    super.key,
    this.duration = const Duration(milliseconds: 2500),
    this.particleCount = 50,
    this.onComplete,
  });

  @override
  State<ConfettiOverlay> createState() => _ConfettiOverlayState();
}

class _ConfettiOverlayState extends State<ConfettiOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late List<_ConfettiPiece> _pieces;
  final _rng = math.Random();

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    );

    _pieces = List.generate(
      widget.particleCount,
      (_) => _ConfettiPiece(_rng),
    );

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        widget.onComplete?.call();
      }
    });

    _controller.forward();
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
        return CustomPaint(
          size: MediaQuery.of(context).size,
          painter: _ConfettiPainter(
            pieces: _pieces,
            progress: _controller.value,
          ),
        );
      },
    );
  }
}

class _ConfettiPiece {
  late double x, velocityX, velocityY, rotation, rotationSpeed;
  late double size, gravity;
  late Color color;
  late int shape; // 0=rect, 1=circle, 2=triangle

  _ConfettiPiece(math.Random rng) {
    x = rng.nextDouble();
    velocityX = (rng.nextDouble() - 0.5) * 0.4;
    velocityY = -0.5 - rng.nextDouble() * 0.8;
    rotation = rng.nextDouble() * 6.2832;
    rotationSpeed = (rng.nextDouble() - 0.5) * 10;
    size = 4 + rng.nextDouble() * 8;
    gravity = 0.8 + rng.nextDouble() * 0.6;
    shape = rng.nextInt(3);
    color = [
      Colors.red,
      Colors.blue,
      Colors.green,
      Colors.yellow,
      Colors.purple,
      Colors.orange,
      Colors.pink,
      Colors.cyan,
      Colors.amber,
      Colors.teal,
    ][rng.nextInt(10)];
  }
}

class _ConfettiPainter extends CustomPainter {
  final List<_ConfettiPiece> pieces;
  final double progress;

  _ConfettiPainter({required this.pieces, required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in pieces) {
      final t = progress;

      // Physics: launch up then fall with gravity
      final px = (p.x + p.velocityX * t) * size.width;
      final py = size.height * 0.5 +
          (p.velocityY * t + 0.5 * p.gravity * t * t) * size.height;

      // Fade out near end
      final opacity = t > 0.7 ? (1.0 - (t - 0.7) / 0.3) : 1.0;
      if (opacity <= 0) continue;

      final paint = Paint()..color = p.color.withOpacity(opacity.clamp(0.0, 1.0));

      canvas.save();
      canvas.translate(px, py);
      canvas.rotate(p.rotation + p.rotationSpeed * t);

      switch (p.shape) {
        case 0: // Rectangle
          canvas.drawRect(
            Rect.fromCenter(
                center: Offset.zero, width: p.size, height: p.size * 0.6),
            paint,
          );
          break;
        case 1: // Circle
          canvas.drawCircle(Offset.zero, p.size * 0.4, paint);
          break;
        case 2: // Triangle
          final path = Path()
            ..moveTo(0, -p.size * 0.4)
            ..lineTo(-p.size * 0.35, p.size * 0.3)
            ..lineTo(p.size * 0.35, p.size * 0.3)
            ..close();
          canvas.drawPath(path, paint);
          break;
      }

      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiPainter old) => true;
}

/// Helper function pour afficher les confettis facilement
void showConfetti(BuildContext context, {int count = 50, Duration? duration}) {
  final overlay = Overlay.of(context);
  late OverlayEntry entry;

  entry = OverlayEntry(
    builder: (context) => ConfettiOverlay(
      particleCount: count,
      duration: duration ?? const Duration(milliseconds: 2500),
      onComplete: () => entry.remove(),
    ),
  );

  overlay.insert(entry);
}
