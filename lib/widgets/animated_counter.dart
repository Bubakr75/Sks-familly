import 'package:flutter/material.dart';

class AnimatedCounter extends StatelessWidget {
  final int value;
  final TextStyle? style;
  final String? prefix;
  final String? suffix;
  final Duration duration;
  final Curve curve;

  const AnimatedCounter({
    super.key,
    required this.value,
    this.style,
    this.prefix,
    this.suffix,
    this.duration = const Duration(milliseconds: 1200),
    this.curve = Curves.easeOut,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<int>(
      tween: IntTween(begin: 0, end: value),
      duration: duration,
      curve: curve,
      builder: (context, val, _) {
        final text = '${prefix ?? ''}$val${suffix ?? ''}';
        return Text(text, style: style);
      },
    );
  }
}

/// Compteur avec effet "flip" vertical
class FlipCounter extends StatefulWidget {
  final int value;
  final TextStyle? style;
  final Duration duration;

  const FlipCounter({
    super.key,
    required this.value,
    this.style,
    this.duration = const Duration(milliseconds: 400),
  });

  @override
  State<FlipCounter> createState() => _FlipCounterState();
}

class _FlipCounterState extends State<FlipCounter>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _flipAnim;
  int _displayValue = 0;
  int _previousValue = 0;

  @override
  void initState() {
    super.initState();
    _displayValue = widget.value;
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    );
    _flipAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOutBack),
    );
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        setState(() => _displayValue = widget.value);
      }
    });
  }

  @override
  void didUpdateWidget(covariant FlipCounter oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      _previousValue = _displayValue;
      _controller.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final style = widget.style ??
        const TextStyle(
          color: Colors.white,
          fontSize: 24,
          fontWeight: FontWeight.bold,
        );

    return AnimatedBuilder(
      animation: _flipAnim,
      builder: (context, _) {
        final progress = _flipAnim.value;
        final showNew = progress > 0.5;
        final displayVal = showNew ? widget.value : _previousValue;

        // Flip effect
        final angle = showNew
            ? (1.0 - progress) * 3.14159 * 0.5
            : progress * 3.14159 * 0.5;

        return Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()
            ..setEntry(3, 2, 0.002)
            ..rotateX(showNew ? -angle : angle),
          child: Text(
            '$displayVal',
            style: style.copyWith(
              color: style.color?.withOpacity(
                  showNew ? progress * 2 - 1 : 1 - progress * 2),
            ),
          ),
        );
      },
    );
  }
}

/// Points animés avec couleur (+vert / -rouge)
class AnimatedPoints extends StatelessWidget {
  final int points;
  final double fontSize;
  final Duration duration;

  const AnimatedPoints({
    super.key,
    required this.points,
    this.fontSize = 16,
    this.duration = const Duration(milliseconds: 1000),
  });

  @override
  Widget build(BuildContext context) {
    final isPositive = points >= 0;
    final color = isPositive ? Colors.green : Colors.red;
    final prefix = isPositive ? '+' : '';

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: duration,
      curve: Curves.elasticOut,
      builder: (context, value, child) {
        return Transform.scale(
          scale: value.clamp(0.0, 1.2),
          child: Opacity(
            opacity: value.clamp(0.0, 1.0),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: color.withOpacity(0.3)),
                boxShadow: [
                  BoxShadow(
                    color: color.withOpacity(0.2),
                    blurRadius: 8,
                  ),
                ],
              ),
              child: TweenAnimationBuilder<int>(
                tween: IntTween(begin: 0, end: points),
                duration: duration,
                builder: (context, val, _) {
                  return Text(
                    '$prefix$val',
                    style: TextStyle(
                      color: color,
                      fontSize: fontSize,
                      fontWeight: FontWeight.bold,
                    ),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }
}
