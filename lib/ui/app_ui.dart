// lib/ui/app_ui.dart
//
// Composants de design unifiés SKS Family.
// Ces widgets s'adaptent automatiquement au thème actif (Émeraude / Aurora /
// Clair) via le ThemeProvider. Ils remplacent progressivement les anciens
// widgets glass_widgets.dart / animated_background.dart / glass_card.dart
// pendant la migration des écrans.
//
// Usage type :
//   final t = context.watch<ThemeProvider>().activeTheme;
//   AppBackground(child: AppCard(child: ...))

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';
import '../config/app_themes.dart';

// ─────────────────────────────────────────────────────────────
//  Raccourci : récupérer le thème actif
// ─────────────────────────────────────────────────────────────

/// Raccourci pour récupérer le [AppThemeData] actif depuis un BuildContext.
/// À préférer à `context.watch<ThemeProvider>().activeTheme` (plus court).
AppThemeData themeOf(BuildContext context) {
  return context.watch<ThemeProvider>().activeTheme;
}

// ─────────────────────────────────────────────────────────────
//  Fond d'écran adapté au thème
// ─────────────────────────────────────────────────────────────

/// Fond d'écran unifié : dégradé subtil adapté au thème actif.
/// - Sombres (Émeraude/Aurora) : dégradé sombre + halo lumineux d'accent.
/// - Clair : fond uni légèrement texturé.
class AppBackground extends StatelessWidget {
  final Widget child;
  final bool animated;

  const AppBackground({
    super.key,
    required this.child,
    this.animated = false,
  });

  @override
  Widget build(BuildContext context) {
    final t = themeOf(context);

    if (t.isDark) {
      return Stack(
        children: [
          // Dégradé de fond
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  t.background,
                  Color.lerp(t.background, Colors.black, 0.35)!,
                ],
              ),
            ),
          ),
          // Halo lumineux accent (haut-gauche)
          Positioned(
            top: -120,
            left: -80,
            child: Container(
              width: 320,
              height: 320,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    t.primary.withValues(alpha: 0.12),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          // Halo secondaire (bas-droit) pour Aurora
          if (t.id == 'aurora')
            Positioned(
              bottom: -100,
              right: -60,
              child: Container(
                width: 280,
                height: 280,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      t.gold.withValues(alpha: 0.10),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          // Contenu
          Positioned.fill(child: child),
        ],
      );
    }

    // Thème clair : fond uni avec très léger dégradé
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            t.background,
            Color.lerp(t.background, Colors.white, 0.5)!,
          ],
        ),
      ),
      child: child,
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Carte unifiée
// ─────────────────────────────────────────────────────────────

/// Carte de contenu unifiée.
/// - Sombre : surface + bordure verre + ombre.
/// - Clair : blanc + ombre douce + bordure très légère.
class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final Color? color;
  final Color? accentColor;
  final VoidCallback? onTap;
  final Border? border;
  final EdgeInsetsGeometry? margin;

  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.radius = 16,
    this.color,
    this.accentColor,
    this.onTap,
    this.border,
    this.margin,
  });

  @override
  Widget build(BuildContext context) {
    final t = themeOf(context);
    final accent = accentColor ?? t.primary;

    return Container(
      margin: margin,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(radius),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              color: color ?? t.surface,
              borderRadius: BorderRadius.circular(radius),
              border: border ??
                  Border.all(
                    color: t.isDark
                        ? accent.withValues(alpha: 0.18)
                        : t.glassBorder,
                    width: t.isDark ? 1 : 1,
                  ),
              boxShadow: t.isDark
                  ? [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.25),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.06),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Texte + Icône avec lueur (adapté)
// ─────────────────────────────────────────────────────────────

/// Texte avec une légère lueur (sombre) ou ombre douce (clair).
class AppGlowText extends StatelessWidget {
  final String text;
  final double fontSize;
  final FontWeight? fontWeight;
  final Color? color;
  final double glow;
  final TextAlign? textAlign;
  final int? maxLines;
  final TextOverflow? overflow;

  const AppGlowText(
    this.text, {
    super.key,
    this.fontSize = 16,
    this.fontWeight,
    this.color,
    this.glow = 0.4,
    this.textAlign,
    this.maxLines,
    this.overflow,
  });

  @override
  Widget build(BuildContext context) {
    final t = themeOf(context);
    final c = color ?? t.textPrimary;
    return Text(
      text,
      textAlign: textAlign,
      maxLines: maxLines,
      overflow: overflow,
      style: TextStyle(
        fontSize: fontSize,
        fontWeight: fontWeight,
        color: c,
        height: 1.3,
        shadows: t.isDark
            ? [
                Shadow(color: c.withValues(alpha: glow), blurRadius: 12),
              ]
            : null,
      ),
    );
  }
}

/// Icône avec lueur (sombre) ou neutre (clair).
class AppGlowIcon extends StatelessWidget {
  final IconData icon;
  final double size;
  final Color? color;
  final double glow;

  const AppGlowIcon(
    this.icon, {
    super.key,
    this.size = 24,
    this.color,
    this.glow = 0.5,
  });

  @override
  Widget build(BuildContext context) {
    final t = themeOf(context);
    final c = color ?? t.primary;
    return Icon(
      icon,
      size: size,
      color: c,
      shadows: t.isDark
          ? [
              Shadow(color: c.withValues(alpha: glow), blurRadius: 12),
            ]
          : null,
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Barre de progression unifiée
// ─────────────────────────────────────────────────────────────

/// Barre de progression avec dégradé d'accent.
class AppProgressBar extends StatelessWidget {
  final double value; // 0.0 → 1.0
  final double height;
  final Color? color;
  final Color? trackColor;

  const AppProgressBar({
    super.key,
    required this.value,
    this.height = 8,
    this.color,
    this.trackColor,
  });

  @override
  Widget build(BuildContext context) {
    final t = themeOf(context);
    final c = color ?? t.primary;

    return ClipRRect(
      borderRadius: BorderRadius.circular(height / 2),
      child: SizedBox(
        height: height,
        child: Stack(
          children: [
            // Track
            Container(
              decoration: BoxDecoration(
                color: trackColor ?? t.surfaceHigh,
                borderRadius: BorderRadius.circular(height / 2),
              ),
            ),
            // Fill
            FractionallySizedBox(
              widthFactor: value.clamp(0.0, 1.0),
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [c, Color.lerp(c, Colors.white, 0.25)!],
                  ),
                  borderRadius: BorderRadius.circular(height / 2),
                  boxShadow: [
                    BoxShadow(
                      color: c.withValues(alpha: 0.5),
                      blurRadius: 6,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Header unifié (titre + sous-titre + option action)
// ─────────────────────────────────────────────────────────────

class AppHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData? actionIcon;
  final VoidCallback? onActionTap;
  final Widget? trailing;
  final double titleSize;

  const AppHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.actionIcon,
    this.onActionTap,
    this.trailing,
    this.titleSize = 26,
  });

  @override
  Widget build(BuildContext context) {
    final t = themeOf(context);
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 16),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: titleSize,
                    fontWeight: FontWeight.w800,
                    color: t.textPrimary,
                    letterSpacing: -0.5,
                    height: 1.15,
                    shadows: t.isDark
                        ? [
                            Shadow(
                                color: t.textPrimary
                                    .withValues(alpha: 0.15),
                                blurRadius: 16),
                          ]
                        : null,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    subtitle!,
                    style: TextStyle(
                      fontSize: 13,
                      color: t.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null) trailing!,
          if (actionIcon != null)
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: Material(
                color: t.surface,
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  onTap: onActionTap,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: t.glassBorder, width: 1),
                    ),
                    child: Icon(actionIcon,
                        color: t.textPrimary, size: 22),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Section title (label uppercase)
// ─────────────────────────────────────────────────────────────

class AppSectionTitle extends StatelessWidget {
  final String title;
  final IconData? icon;
  final String? trailing;

  const AppSectionTitle({
    super.key,
    required this.title,
    this.icon,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final t = themeOf(context);
    return Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 10),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: t.primaryLight),
            const SizedBox(width: 6),
          ],
          Text(
            title.toUpperCase(),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: t.textSecondary,
              letterSpacing: 1.5,
            ),
          ),
          const Spacer(),
          if (trailing != null)
            Text(
              trailing!,
              style: TextStyle(
                fontSize: 11,
                color: t.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Bouton d'action primaire (pill dégradé)
// ─────────────────────────────────────────────────────────────

class AppPrimaryButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final bool expanded;
  final Color? color;
  final bool loading;

  const AppPrimaryButton({
    super.key,
    required this.label,
    this.icon,
    this.onPressed,
    this.expanded = true,
    this.color,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    final t = themeOf(context);
    final c = color ?? t.primary;
    return Opacity(
      opacity: onPressed == null ? 0.5 : 1,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: loading ? null : onPressed,
          borderRadius: BorderRadius.circular(14),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [c, Color.lerp(c, Colors.black, 0.2)!],
              ),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: c.withValues(alpha: 0.4),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: expanded ? MainAxisSize.max : MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (loading)
                  SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                else if (icon != null) ...[
                  Icon(icon, color: Colors.white, size: 18),
                  const SizedBox(width: 8),
                ],
                Flexible(
                  child: Text(
                    label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Avatar avec halo coloré
// ─────────────────────────────────────────────────────────────

/// Avatar circulaire avec halo coloré optionnel.
class AppAvatar extends StatelessWidget {
  final Widget child;
  final double size;
  final Color? ringColor;
  final bool glow;

  const AppAvatar({
    super.key,
    required this.child,
    this.size = 56,
    this.ringColor,
    this.glow = false,
  });

  @override
  Widget build(BuildContext context) {
    final t = themeOf(context);
    final c = ringColor ?? t.primary;
    return Stack(
      alignment: Alignment.center,
      children: [
        if (glow)
          Container(
            width: size + 12,
            height: size + 12,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [c.withValues(alpha: 0.3), Colors.transparent],
              ),
            ),
          ),
        Container(
          width: size + 2,
          height: size + 2,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: c.withValues(alpha: 0.6), width: 2),
          ),
        ),
        ClipOval(
          child: SizedBox(width: size, height: size, child: child),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Puce / Badge coloré
// ─────────────────────────────────────────────────────────────

class AppChip extends StatelessWidget {
  final String label;
  final Color? color;
  final IconData? icon;
  final VoidCallback? onTap;

  const AppChip({
    super.key,
    required this.label,
    this.color,
    this.icon,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final t = themeOf(context);
    final c = color ?? t.primary;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: c.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: c.withValues(alpha: 0.3), width: 1),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 12, color: c),
                const SizedBox(width: 4),
              ],
              Text(
                label,
                style: TextStyle(
                  color: c,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Helpers couleur
// ─────────────────────────────────────────────────────────────

/// Couleur d'accent par enfant (stable selon le nom).
Color appChildAccent(BuildContext context, String name) {
  final t = themeOf(context);
  const palette = [
    Color(0xFF00E676), // émeraude
    Color(0xFFD4AF37), // or
    Color(0xFF8B5CF6), // Violet
    Color(0xFFEC4899), // Rose
    Color(0xFF3B82F6), // Bleu
    Color(0xFFF59E0B), // Ambre
    Color(0xFF06B6D4), // Cyan
    Color(0xFFEF4444), // Rouge
  ];
  if (name.isEmpty) return t.primary;
  return palette[name.codeUnitAt(0) % palette.length];
}

/// Dégradé de fond décoratif (pour splash / bannières).
LinearGradient appAccentGradient(BuildContext context) {
  final t = themeOf(context);
  return LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [t.primary, Color.lerp(t.primary, Colors.black, 0.25)!],
  );
}
