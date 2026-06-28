// =============================================================================
// SKS Family - Emerald Design System
// =============================================================================
// Design system "Émeraude Premium" inspiré de :
//   - Apple Fitness (premium feel, hiérarchie claire)
//   - Stripe Dashboard (cards nettes, KPIs organisés)
//
// Palette : Vert profond + crème + doré + accent émeraude vif
// =============================================================================

import 'package:flutter/material.dart';

/// Palette de couleurs Emerald
class EmeraldPalette {
  EmeraldPalette._();

  // Fonds
  static const Color background = Color(0xFF0A1F1A); // Vert nuit profond
  static const Color surface = Color(0xFF122B22); // Vert surface (cards)
  static const Color surfaceHigh = Color(0xFF1A3829); // Cards hover/active
  static const Color surfaceLow = Color(0xFF0E2519); // Cards secondaires

  // Accents
  static const Color emerald = Color(0xFF10B981); // Vert vif principal
  static const Color emeraldLight = Color(0xFF34D399); // Vert clair
  static const Color emeraldDark = Color(0xFF047857); // Vert foncé
  static const Color gold = Color(0xFFD4AF37); // Doré pour médailles/récompenses
  static const Color goldLight = Color(0xFFF4D160); // Doré clair

  // Textes
  static const Color textPrimary = Color(0xFFF5F1E8); // Crème
  static const Color textSecondary = Color(0xFF94A3A0); // Vert gris
  static const Color textMuted = Color(0xFF5A6B66); // Vert gris foncé

  // États
  static const Color success = Color(0xFF10B981);
  static const Color warning = Color(0xFFF59E0B); // Ambre
  static const Color error = Color(0xFFEF4444); // Rouge
  static const Color info = Color(0xFF3B82F6); // Bleu

  // Médaillles (podium)
  static const Color goldMedal = Color(0xFFD4AF37);
  static const Color silverMedal = Color(0xFFB8C5CA);
  static const Color bronzeMedal = Color(0xFFCD7F32);

  // Glassmorphism
  static Color glassLight = Colors.white.withValues(alpha: 0.04);
  static Color glassBorder = Colors.white.withValues(alpha: 0.08);
  static Color glassHighlight = Colors.white.withValues(alpha: 0.12);

  // Gradients
  static const LinearGradient emeraldGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF10B981), Color(0xFF047857)],
  );

  static const LinearGradient goldGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFF4D160), Color(0xFFD4AF37)],
  );

  static const LinearGradient surfaceGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF1A3829), Color(0xFF0E2519)],
  );

  static const LinearGradient headerGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFF0A1F1A), Color(0xFF0A1F1A)],
  );
}

/// Typographies Emerald
class EmeraldTypography {
  EmeraldTypography._();

  // Pour les titres principaux - épais, épuré
  static const TextStyle display = TextStyle(
    fontFamily: 'SF Pro Display',
    fontFamilyFallback: ['Inter', 'Helvetica', 'Arial'],
    fontWeight: FontWeight.w700,
    color: EmeraldPalette.textPrimary,
    letterSpacing: -0.5,
  );

  // Titre de section
  static const TextStyle heading = TextStyle(
    fontFamily: 'SF Pro Display',
    fontFamilyFallback: ['Inter', 'Helvetica', 'Arial'],
    fontWeight: FontWeight.w700,
    color: EmeraldPalette.textPrimary,
    letterSpacing: -0.2,
  );

  // Sous-titre / corps
  static const TextStyle body = TextStyle(
    fontFamily: 'Inter',
    fontFamilyFallback: ['Helvetica', 'Arial'],
    fontWeight: FontWeight.w400,
    color: EmeraldPalette.textPrimary,
  );

  // Texte secondaire
  static const TextStyle caption = TextStyle(
    fontFamily: 'Inter',
    fontFamilyFallback: ['Helvetica', 'Arial'],
    fontWeight: FontWeight.w500,
    color: EmeraldPalette.textSecondary,
  );

  // KPI nombre (très gros)
  static const TextStyle kpiNumber = TextStyle(
    fontFamily: 'SF Pro Display',
    fontFamilyFallback: ['Inter', 'Helvetica', 'Arial'],
    fontWeight: FontWeight.w800,
    color: EmeraldPalette.emeraldLight,
    letterSpacing: -1,
  );

  // Label uppercase petit
  static const TextStyle label = TextStyle(
    fontFamily: 'Inter',
    fontFamilyFallback: ['Helvetica', 'Arial'],
    fontWeight: FontWeight.w600,
    color: EmeraldPalette.textSecondary,
    letterSpacing: 1.2,
  );
}

/// Composant : Card émeraude (style Stripe, bords nets, ombre subtile)
class EmeraldCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final double radius;
  final Color? color;
  final VoidCallback? onTap;
  final Border? border;

  const EmeraldCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.radius = 16,
    this.color,
    this.onTap,
    this.border,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(radius),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: color ?? EmeraldPalette.surface,
            borderRadius: BorderRadius.circular(radius),
            border: border ??
                Border.all(color: EmeraldPalette.glassBorder, width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.25),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}

/// Composant : KPI Card (style Stripe Dashboard)
class EmeraldKpiCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color? accentColor;
  final String? sublabel;
  final bool animateCountUp;

  const EmeraldKpiCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    this.accentColor,
    this.sublabel,
    this.animateCountUp = false,
  });

  @override
  Widget build(BuildContext context) {
    final accent = accentColor ?? EmeraldPalette.emerald;

    return EmeraldCard(
      padding: const EdgeInsets.all(14),
      radius: 14,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: accent, size: 14),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label.toUpperCase(),
                  style: EmeraldTypography.label.copyWith(
                    fontSize: 9,
                    letterSpacing: 1.4,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (animateCountUp)
            _CountUpText(
              text: value,
              style: EmeraldTypography.kpiNumber.copyWith(fontSize: 22),
            )
          else
            Text(
              value,
              style: EmeraldTypography.kpiNumber.copyWith(fontSize: 22),
            ),
          if (sublabel != null) ...[
            const SizedBox(height: 2),
            Text(
              sublabel!,
              style: EmeraldTypography.caption.copyWith(fontSize: 10),
            ),
          ],
        ],
      ),
    );
  }
}

/// Composant : Quick Action tile (grille 3 colonnes)
class EmeraldActionTile extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color accentColor;
  final VoidCallback onTap;

  const EmeraldActionTile({
    super.key,
    required this.label,
    required this.icon,
    required this.accentColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            color: EmeraldPalette.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: accentColor.withValues(alpha: 0.2),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: accentColor.withValues(alpha: 0.3),
                    width: 1,
                  ),
                ),
                child: Icon(icon, color: accentColor, size: 22),
              ),
              const SizedBox(height: 8),
              Text(
                label,
                style: EmeraldTypography.body.copyWith(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Composant : Podium row (style Apple Fitness — épuré, lisible)
class EmeraldPodiumRow extends StatelessWidget {
  final int rank;
  final String name;
  final int points;
  final String level;
  final Widget avatar;
  final bool isTop;

  const EmeraldPodiumRow({
    super.key,
    required this.rank,
    required this.name,
    required this.points,
    required this.level,
    required this.avatar,
    this.isTop = false,
  });

  Color get _rankColor {
    switch (rank) {
      case 1:
        return EmeraldPalette.goldMedal;
      case 2:
        return EmeraldPalette.silverMedal;
      case 3:
        return EmeraldPalette.bronzeMedal;
      default:
        return EmeraldPalette.textMuted;
    }
  }

  String get _rankEmoji {
    switch (rank) {
      case 1:
        return '🥇';
      case 2:
        return '🥈';
      case 3:
        return '🥉';
      default:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isTop
            ? EmeraldPalette.gold.withValues(alpha: 0.05)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        border: isTop
            ? Border.all(
                color: EmeraldPalette.gold.withValues(alpha: 0.3),
                width: 1,
              )
            : null,
      ),
      child: Row(
        children: [
          // Rang
          SizedBox(
            width: 36,
            child: Text(
              _rankEmoji.isNotEmpty ? _rankEmoji : '#$rank',
              style: TextStyle(
                fontSize: _rankEmoji.isNotEmpty ? 20 : 14,
                fontWeight: FontWeight.w800,
                color: _rankColor,
              ),
            ),
          ),
          // Avatar
          avatar,
          const SizedBox(width: 12),
          // Nom + niveau
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: EmeraldTypography.heading.copyWith(
                    fontSize: 15,
                    fontWeight: isTop ? FontWeight.w700 : FontWeight.w600,
                  ),
                ),
                Text(
                  level,
                  style: EmeraldTypography.caption.copyWith(fontSize: 11),
                ),
              ],
            ),
          ),
          // Points
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$points',
                style: EmeraldTypography.kpiNumber.copyWith(
                  fontSize: 18,
                  color: isTop ? EmeraldPalette.goldLight : EmeraldPalette.emeraldLight,
                ),
              ),
              Text(
                'pts',
                style: EmeraldTypography.caption.copyWith(fontSize: 10),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Composant : Header premium avec greeting
class EmeraldHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData? actionIcon;
  final VoidCallback? onActionTap;

  const EmeraldHeader({
    super.key,
    required this.title,
    required this.subtitle,
    this.actionIcon,
    this.onActionTap,
  });

  @override
  Widget build(BuildContext context) {
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
                  style: EmeraldTypography.display.copyWith(fontSize: 28),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: EmeraldTypography.caption.copyWith(fontSize: 13),
                ),
              ],
            ),
          ),
          if (actionIcon != null)
            Material(
              color: EmeraldPalette.surface,
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                onTap: onActionTap,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: EmeraldPalette.glassBorder,
                      width: 1,
                    ),
                  ),
                  child: Icon(
                    actionIcon,
                    color: EmeraldPalette.textPrimary,
                    size: 22,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Composant : Section title (label uppercase style Stripe)
class EmeraldSectionTitle extends StatelessWidget {
  final String title;
  final IconData? icon;
  final String? trailing;

  const EmeraldSectionTitle({
    super.key,
    required this.title,
    this.icon,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 10),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(
              icon,
              size: 14,
              color: EmeraldPalette.emeraldLight,
            ),
            const SizedBox(width: 6),
          ],
          Text(
            title.toUpperCase(),
            style: EmeraldTypography.label.copyWith(
              fontSize: 11,
              letterSpacing: 1.5,
            ),
          ),
          const Spacer(),
          if (trailing != null)
            Text(
              trailing!,
              style: EmeraldTypography.caption.copyWith(fontSize: 11),
            ),
        ],
      ),
    );
  }
}

/// Animation count-up pour les chiffres
class _CountUpText extends StatefulWidget {
  final String text;
  final TextStyle style;
  final Duration duration;

  const _CountUpText({
    required this.text,
    required this.style,
    this.duration = const Duration(milliseconds: 1200),
  });

  @override
  State<_CountUpText> createState() => _CountUpTextState();
}

class _CountUpTextState extends State<_CountUpText>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  late int _targetValue;

  @override
  void initState() {
    super.initState();
    _targetValue = int.tryParse(widget.text.replaceAll(RegExp(r'[^\d]'), '')) ?? 0;
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    );
    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_targetValue == 0) {
      return Text(widget.text, style: widget.style);
    }
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, _) {
        final current = (_targetValue * _animation.value).round();
        // Conserver les caractères non-numériques (ex: suffixes)
        final prefix = widget.text.replaceAll(RegExp(r'[\d]'), '');
        return Text('$current$prefix', style: widget.style);
      },
    );
  }
}

/// Fond émeraude avec gradient subtil
class EmeraldBackground extends StatelessWidget {
  final Widget child;

  const EmeraldBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: EmeraldPalette.background,
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF0A1F1A),
              Color(0xFF0A1F1A),
              Color(0xFF081511),
            ],
            stops: [0, 0.5, 1],
          ),
        ),
        child: child,
      ),
    );
  }
}

