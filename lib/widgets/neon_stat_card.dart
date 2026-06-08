import 'package:flutter/material.dart';
import 'dart:math' as math;

class NeonStatCard extends StatefulWidget {
  final String label;
  final int value;
  final String? suffix;
  final IconData icon;
  final Color color;
  final double? maxValue;

  const NeonStatCard({
    super.key,
    required this.label,
    required this.value,
    this.suffix,
    required this.icon,
    required this.color,
    this.maxValue,
  });

  @override
  State<NeonStatCard> createState() => _NeonStatCardState();
}

class _NeonStatCardState extends State<NeonStatCard>
    with TickerProviderStateMixin {
  late AnimationController _enterController;
  late AnimationController _pulseController;
  late Animation<double> _scaleAnim;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();

    _enterController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _scaleAnim = CurvedAnimation(
      parent: _enterController,
      curve: Curves.elasticOut,
    );

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.3, end: 0.7).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _enterController.forward();
  }

  @override
  void dispose() {
    _enterController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_scaleAnim, _pulseAnim]),
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnim.value.clamp(0.0, 1.0),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  widget.color.withOpacity(0.08),
                  widget.color.withOpacity(0.03),
                ],
              ),
              border: Border.all(
                color: widget.color.withOpacity(0.15 + 0.1 * _pulseAnim.value),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color:
                      widget.color.withOpacity(0.1 * _pulseAnim.value),
                  blurRadius: 16,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Icon with glow
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: widget.color.withOpacity(0.1),
                    boxShadow: [
                      BoxShadow(
                        color: widget.color
                            .withOpacity(0.2 * _pulseAnim.value),
                        blurRadius: 12,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: Icon(widget.icon,
                      color: widget.color, size: 24),
                ),
                const SizedBox(height: 10),

                // Animated counter
                TweenAnimationBuilder<int>(
                  tween: IntTween(begin: 0, end: widget.value),
                  duration: const Duration(milliseconds: 1500),
                  curve: Curves.easeOut,
                  builder: (context, val, _) {
                    return Text(
                      widget.suffix != null
                          ? '$val${widget.suffix}'
                          : '$val',
                      style: TextStyle(
                        color: widget.color,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    );
                  },
                ),
                const SizedBox(height: 4),

                // Label
                Text(
                  widget.label,
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 12,
                  ),
                  textAlign: TextAlign.center,
                ),

                // Optional progress bar
                if (widget.maxValue != null && widget.maxValue! > 0) ...[
                  const SizedBox(height: 10),
                  TweenAnimationBuilder<double>(
                    tween: Tween(
                        begin: 0.0,
                        end: (widget.value / widget.maxValue!)
                            .clamp(0.0, 1.0)),
                    duration: const Duration(milliseconds: 1800),
                    curve: Curves.easeOutCubic,
                    builder: (context, value, _) {
                      return ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: Stack(
                          children: [
                            Container(
                              height: 6,
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.08),
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                            FractionallySizedBox(
                              widthFactor: value,
                              child: Container(
                                height: 6,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      widget.color.withOpacity(0.7),
                                      widget.color,
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(4),
                                  boxShadow: [
                                    BoxShadow(
                                      color: widget.color
                                          .withOpacity(0.4),
                                      blurRadius: 4,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}
