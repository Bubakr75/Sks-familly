import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';

class AnimatedBackground extends StatelessWidget {
  final Widget child;
  final bool showParticles;
  const AnimatedBackground({super.key, required this.child, this.showParticles = true});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (!isDark) {
     return child;
    }

    final themeProv = context.watch<ThemeProvider>();
    final bgColor = themeProv.backgroundColor;

    final hsl = HSLColor.fromColor(bgColor);
    final lighter = hsl.withLightness((hsl.lightness + 0.03).clamp(0.0, 1.0)).toColor();
    final darker = hsl.withLightness((hsl.lightness - 0.02).clamp(0.0, 1.0)).toColor();

    return Stack(
      children: [
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [bgColor, lighter, bgColor, darker],
              stops: const [0.0, 0.3, 0.7, 1.0],
            ),
          ),
        ),
        Positioned(
          top: -100,
          left: -50,
          child: Container(
            width: 300,
            height: 300,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  theme.colorScheme.primary.withValues(alpha: 0.06),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
        child,
      ],
    );
  }
}
