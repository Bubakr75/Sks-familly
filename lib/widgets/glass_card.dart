import 'dart:ui';
import 'package:flutter/material.dart';

/// Glassmorphism card with frosted glass effect
class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets? padding;
  final EdgeInsets? margin;
  final double borderRadius;
  final Color? borderColor;
  final double blur;
  final Color? glowColor;
  final VoidCallback? onTap;

  const GlassCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.borderRadius = 20,
    this.borderColor,
    this.blur = 10,
    this.glowColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final glow = glowColor ?? theme.colorScheme.primary;

    if (!isDark) {
      // Light mode: regular card
      return Card(
        margin: margin ?? const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: InkWell(
          borderRadius: BorderRadius.circular(borderRadius),
          onTap: onTap,
          child: Padding(
            padding: padding ?? const EdgeInsets.all(16),
            child: child,
          ),
        ),
      );
    }

    return Container(
      margin: margin ?? const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: glowColor != null
            ? [
                BoxShadow(
                  color: glow.withValues(alpha: 0.15),
                  blurRadius: 20,
                  spreadRadius: -2,
                ),
              ]
            : null,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(borderRadius),
              onTap: onTap,
              child: Container(
                padding: padding ?? const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(borderRadius),
                  color: Colors.white.withValues(alpha: 0.05),
                  border: Border.all(
                    color: borderColor ?? Colors.white.withValues(alpha: 0.08),
                    width: 1,
                  ),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.white.withValues(alpha: 0.08),
                      Colors.white.withValues(alpha: 0.02),
                    ],
                  ),
                ),
                child: child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Neon glow text widget
class NeonText extends StatelessWidget {
  final String text;
  final double fontSize;
  final FontWeight fontWeight;
  final Color? color;
  final double glowIntensity;

  const NeonText({
    super.key,
    required this.text,
    this.fontSize = 16,
    this.fontWeight = FontWeight.bold,
    this.color,
    this.glowIntensity = 0.6,
  });

  @override
  Widget build(BuildContext context) {
    final neonColor = color ?? Theme.of(context).colorScheme.primary;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (!isDark) {
      return Text(text, style: TextStyle(fontSize: fontSize, fontWeight: fontWeight, color: neonColor));
    }

    return Text(
      text,
      style: TextStyle(
        fontSize: fontSize,
        fontWeight: fontWeight,
        color: neonColor,
        shadows: [
          Shadow(color: neonColor.withValues(alpha: glowIntensity), blurRadius: 12),
          Shadow(color: neonColor.withValues(alpha: glowIntensity * 0.5), blurRadius: 24),
        ],
      ),
    );
  }
}

/// Animated neon border container
class NeonBorder extends StatelessWidget {
  final Widget child;
  final Color? color;
  final double borderRadius;
  final double width;

  const NeonBorder({
    super.key,
    required this.child,
    this.color,
    this.borderRadius = 20,
    this.width = 1.5,
  });

  @override
  Widget build(BuildContext context) {
    final neonColor = color ?? Theme.of(context).colorScheme.primary;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (!isDark) {
      return Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(borderRadius),
          border: Border.all(color: neonColor.withValues(alpha: 0.3), width: width),
        ),
        child: child,
      );
    }

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: neonColor.withValues(alpha: 0.5), width: width),
        boxShadow: [
          BoxShadow(color: neonColor.withValues(alpha: 0.2), blurRadius: 8, spreadRadius: -2),
          BoxShadow(color: neonColor.withValues(alpha: 0.1), blurRadius: 16, spreadRadius: -4),
        ],
      ),
      child: child,
    );
  }
}

/// Glowing icon widget
class GlowIcon extends StatelessWidget {
  final IconData icon;
  final double size;
  final Color? color;

  const GlowIcon({super.key, required this.icon, this.size = 24, this.color});

  @override
  Widget build(BuildContext context) {
    final iconColor = color ?? Theme.of(context).colorScheme.primary;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Icon(
      icon,
      size: size,
      color: iconColor,
      shadows: isDark
          ? [Shadow(color: iconColor.withValues(alpha: 0.6), blurRadius: 12)]
          : null,
    );
  }
}
