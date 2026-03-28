import 'package:flutter/material.dart';
import 'dart:ui';
import 'dart:math' as math;

class GlassCard extends StatefulWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final double borderRadius;
  final bool animate;
  final Color? glowColor;
  final VoidCallback? onTap;

  const GlassCard({
    super.key,
    required this.child,
    this.padding,
    this.borderRadius = 16,
    this.animate = true,
    this.glowColor,
    this.onTap,
  });

  @override
  State<GlassCard> createState() => _GlassCardState();
}

class _GlassCardState extends State<GlassCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _shimmerController;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    );
    if (widget.animate) {
      Future.delayed(
        Duration(milliseconds: math.Random().nextInt(2000)),
        () {
          if (mounted) _shimmerController.repeat();
        },
      );
    }
  }

  @override
  void dispose() {
    _shimmerController.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails _) {
    setState(() => _isPressed = true);
  }

  void _onTapUp(TapUpDetails _) {
    setState(() => _isPressed = false);
    widget.onTap?.call();
  }

  void _onTapCancel() {
    setState(() => _isPressed = false);
  }

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOutBack,
      builder: (context, enterValue, child) {
        return Transform.scale(
          scale: 0.85 + 0.15 * enterValue,
          child: Opacity(
            opacity: enterValue.clamp(0.0, 1.0),
            child: child,
          ),
        );
      },
      child: GestureDetector(
        onTapDown: widget.onTap != null ? _onTapDown : null,
        onTapUp: widget.onTap != null ? _onTapUp : null,
        onTapCancel: widget.onTap != null ? _onTapCancel : null,
        child: AnimatedScale(
          scale: _isPressed ? 0.96 : 1.0,
          duration: const Duration(milliseconds: 120),
          child: AnimatedBuilder(
            animation: _shimmerController,
            builder: (context, child) {
              return CustomPaint(
                foregroundPainter: widget.animate
                    ? _ShimmerPainter(
                        progress: _shimmerController.value,
                        borderRadius: widget.borderRadius,
                        glowColor: widget.glowColor ?? Colors.cyan,
                      )
                    : null,
                child: child,
              );
            },
            child: ClipRRect(
              borderRadius: BorderRadius.circular(widget.borderRadius),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                child: Container(
                  padding: widget.padding ??
                      const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    borderRadius:
                        BorderRadius.circular(widget.borderRadius),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.white.withOpacity(0.12),
                        Colors.white.withOpacity(0.05),
                        Colors.white.withOpacity(0.02),
                      ],
                    ),
                    border: Border.all(
                      color: (widget.glowColor ?? Colors.cyan)
                          .withOpacity(0.12),
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                      BoxShadow(
                        color: (widget.glowColor ?? Colors.cyan)
                            .withOpacity(0.05),
                        blurRadius: 20,
                        spreadRadius: -2,
                      ),
                    ],
                  ),
                  child: widget.child,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Peint un reflet lumineux qui glisse en diagonale sur la carte
class _ShimmerPainter extends CustomPainter {
  final double progress;
  final double borderRadius;
  final Color glowColor;

  _ShimmerPainter({
    required this.progress,
    required this.borderRadius,
    required this.glowColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Radius.circular(borderRadius),
    );

    // Clip to card shape
    canvas.save();
    canvas.clipRRect(rrect);

    // Moving shimmer band
    final shimmerWidth = size.width * 0.35;
    final totalTravel = size.width + shimmerWidth * 2;
    final xPos = -shimmerWidth + totalTravel * progress;

    final shimmerPaint = Paint()
      ..shader = LinearGradient(
        colors: [
          Colors.transparent,
          glowColor.withOpacity(0.06),
          Colors.white.withOpacity(0.1),
          glowColor.withOpacity(0.06),
          Colors.transparent,
        ],
        stops: const [0.0, 0.3, 0.5, 0.7, 1.0],
      ).createShader(
        Rect.fromLTWH(xPos, 0, shimmerWidth, size.height),
      );

    canvas.drawRect(
      Rect.fromLTWH(xPos, 0, shimmerWidth, size.height),
      shimmerPaint,
    );

    canvas.restore();

    // Animated border glow (subtle)
    final borderPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..shader = SweepGradient(
        center: Alignment.center,
        startAngle: progress * 6.2832,
        colors: [
          Colors.transparent,
          glowColor.withOpacity(0.15),
          Colors.transparent,
          glowColor.withOpacity(0.08),
          Colors.transparent,
        ],
        stops: const [0.0, 0.25, 0.5, 0.75, 1.0],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    canvas.drawRRect(rrect, borderPaint);
  }

  @override
  bool shouldRepaint(covariant _ShimmerPainter old) =>
      progress != old.progress;
}
