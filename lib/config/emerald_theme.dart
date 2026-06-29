// =============================================================================
// SKS Family - Emerald Design System
// =============================================================================
// Design system "Émeraude Premium" inspiré de :
//   - Apple Fitness (premium feel, hiérarchie claire)
//   - Stripe Dashboard (cards nettes, KPIs organisés)
//
// Palette : Vert profond + crème + doré + accent émeraude vif
//
// NOTE : depuis l'introduction du multi-thèmes, ces composants s'adaptent au
// thème actif (Émeraude / Aurora / Clair) via le ThemeProvider. Les constantes
// EmeraldPalette.* restent disponibles pour la rétro-compatibilité (elles
// représentent toujours le thème Émeraude natif).
// =============================================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'app_themes.dart';
import '../providers/theme_provider.dart';

/// Palette de couleurs Emerald
class EmeraldPalette {
  EmeraldPalette._();

  // Fonds — PLUS SOMBR€ pour contraste max avec les cards
  static const Color background = Color(0xFF051410); // Vert nuit très sombre
  static const Color surface = Color(0xFF0F2620); // Vert surface (cards)
  static const Color surfaceHigh = Color(0xFF193530); // Cards hover/active
  static const Color surfaceLow = Color(0xFF0A1C17); // Cards secondaires

  // Accents — VERT + VIF (plus de contraste, plus premium)
  static const Color emerald = Color(0xFF00E676); // Vert vif émeraude (plus flashy)
  static const Color emeraldLight = Color(0xFF69F0AE); // Vert clair lumineux
  static const Color emeraldDark = Color(0xFF00C853); // Vert foncé profond
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
/// S'adapte au thème actif (Émeraude / Aurora / Clair).
class EmeraldCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final double radius;
  final Color? color;
  final Color? accentColor; // couleur d'accent pour l'ombre/bordure lumineuse
  final VoidCallback? onTap;
  final Border? border;
  final bool glow; // active l'ombre colorée premium

  const EmeraldCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.radius = 16,
    this.color,
    this.accentColor,
    this.onTap,
    this.border,
    this.glow = true,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.watch<ThemeProvider>().activeTheme;
    final accent = accentColor ?? t.primary;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(radius),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            // Dégradé vertical subtil : surface → légèrement plus clair en haut
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                (color ?? t.surface),
                Color.lerp((color ?? t.surface), Colors.black, 0.12)!,
              ],
            ),
            borderRadius: BorderRadius.circular(radius),
            border: border ??
                Border.all(color: accent.withValues(alpha: 0.15), width: 1),
            boxShadow: [
              // Ombre principale (profondeur)
              BoxShadow(
                color: Colors.black.withValues(alpha: t.isDark ? 0.3 : 0.08),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
              // Ombre colorée premium (glow vert/ambre) — signature Émeraude++
              if (glow)
                BoxShadow(
                  color: accent.withValues(alpha: t.isDark ? 0.18 : 0.10),
                  blurRadius: 20,
                  spreadRadius: -2,
                  offset: const Offset(0, 2),
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
      radius: 16,
      accentColor: accent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Icône dans un halo lumineux (signature Émeraude++)
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      accent.withValues(alpha: 0.22),
                      accent.withValues(alpha: 0.08),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(9),
                  border: Border.all(
                      color: accent.withValues(alpha: 0.35), width: 1),
                ),
                child: Icon(icon, color: accent, size: 15),
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
          const SizedBox(height: 12),
          if (animateCountUp)
            _CountUpText(
              text: value,
              style: EmeraldTypography.kpiNumber.copyWith(
                fontSize: 24,
                color: EmeraldPalette.textPrimary,
                height: 1,
              ),
            )
          else
            Text(
              value,
              style: EmeraldTypography.kpiNumber.copyWith(
                fontSize: 24,
                color: EmeraldPalette.textPrimary,
                height: 1,
              ),
            ),
          if (sublabel != null) ...[
            const SizedBox(height: 3),
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
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                EmeraldPalette.surface,
                Color.lerp(EmeraldPalette.surface, Colors.black, 0.12)!,
              ],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: accentColor.withValues(alpha: 0.2),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.25),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
              // glow coloré premium
              BoxShadow(
                color: accentColor.withValues(alpha: 0.14),
                blurRadius: 18,
                spreadRadius: -3,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(11),
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    colors: [
                      accentColor.withValues(alpha: 0.28),
                      accentColor.withValues(alpha: 0.10),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(13),
                  border: Border.all(
                    color: accentColor.withValues(alpha: 0.4),
                    width: 1,
                  ),
                ),
                child: Icon(icon, color: accentColor, size: 22),
              ),
              const SizedBox(height: 9),
              Text(
                label,
                style: EmeraldTypography.body.copyWith(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Composant : Podium row (style Apple Fitness épuré + glow doré pour le #1)
class EmeraldPodiumRow extends StatefulWidget {
  final int rank;
  final String name;
  final int points;
  final String level;
  final Widget avatar;
  final bool isTop;
  final double levelProgress; // 0.0 → 1.0 (progression vers niveau suivant)

  const EmeraldPodiumRow({
    super.key,
    required this.rank,
    required this.name,
    required this.points,
    required this.level,
    required this.avatar,
    this.isTop = false,
    this.levelProgress = 0.0,
  });

  @override
  State<EmeraldPodiumRow> createState() => _EmeraldPodiumRowState();
}

class _EmeraldPodiumRowState extends State<EmeraldPodiumRow>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );
    _pulseAnim = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(
        parent: _pulseController,
        curve: Curves.easeInOut,
      ),
    );
    if (widget.isTop) _pulseController.repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Color get _rankColor {
    switch (widget.rank) {
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
    switch (widget.rank) {
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
    return AnimatedBuilder(
      animation: _pulseAnim,
      builder: (context, child) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: widget.isTop
                ? EmeraldPalette.gold.withValues(alpha: 0.08)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
            border: widget.isTop
                ? Border.all(
                    color: EmeraldPalette.gold
                        .withValues(alpha: 0.4 + _pulseAnim.value * 0.3),
                    width: 1.5,
                  )
                : Border.all(
                    color: EmeraldPalette.glassBorder,
                    width: 1,
                  ),
            boxShadow: widget.isTop
                ? [
                    BoxShadow(
                      color: EmeraldPalette.gold
                          .withValues(alpha: 0.15 * _pulseAnim.value),
                      blurRadius: 20,
                      spreadRadius: 1,
                    ),
                  ]
                : null,
          ),
          child: child,
        );
      },
      child: Row(
        children: [
          // Rang (médaille ou #)
          SizedBox(
            width: 36,
            child: Text(
              _rankEmoji.isNotEmpty ? _rankEmoji : '#${widget.rank}',
              style: TextStyle(
                fontSize: _rankEmoji.isNotEmpty ? 22 : 14,
                fontWeight: FontWeight.w800,
                color: _rankColor,
              ),
            ),
          ),
          // Avatar
          widget.avatar,
          const SizedBox(width: 12),
          // Nom + niveau + barre de progression
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.name,
                  style: EmeraldTypography.heading.copyWith(
                    fontSize: 15,
                    fontWeight:
                        widget.isTop ? FontWeight.w700 : FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  widget.level,
                  style: EmeraldTypography.caption.copyWith(fontSize: 10),
                ),
                const SizedBox(height: 6),
                // Barre de progression vers niveau suivant
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: SizedBox(
                    height: 4,
                    child: Stack(
                      children: [
                        // Track
                        Container(
                          decoration: BoxDecoration(
                            color: EmeraldPalette.surfaceHigh,
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                        // Fill animé
                        FractionallySizedBox(
                          widthFactor:
                              widget.levelProgress.clamp(0.0, 1.0),
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: widget.isTop
                                  ? EmeraldPalette.goldGradient
                                  : EmeraldPalette.emeraldGradient,
                              borderRadius: BorderRadius.circular(3),
                              boxShadow: [
                                BoxShadow(
                                  color: (widget.isTop
                                          ? EmeraldPalette.gold
                                          : EmeraldPalette.emerald)
                                      .withValues(alpha: 0.5),
                                  blurRadius: 6,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          // Points
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${widget.points}',
                style: EmeraldTypography.kpiNumber.copyWith(
                  fontSize: 20,
                  color: widget.isTop
                      ? EmeraldPalette.goldLight
                      : EmeraldPalette.emeraldLight,
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

/// Fond émeraude avec gradient subtil — s'adapte au thème actif.
/// Fond premium avec dégradé + halos lumineux colorés (signature Émeraude++).
/// Des orbes de lueur (vert/or) flottent lentement en arrière-plan pour donner
/// de la profondeur et une ambiance premium, sans distraire.
class EmeraldBackground extends StatefulWidget {
  final Widget child;

  const EmeraldBackground({super.key, required this.child});

  @override
  State<EmeraldBackground> createState() => _EmeraldBackgroundState();
}

class _EmeraldBackgroundState extends State<EmeraldBackground>
    with TickerProviderStateMixin {
  late final AnimationController _breathe;

  @override
  void initState() {
    super.initState();
    _breathe = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _breathe.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.watch<ThemeProvider>().activeTheme;
    return Container(
      color: t.background,
      child: AnimatedBuilder(
        animation: _breathe,
        builder: (context, _) {
          // Oscillation douce de l'intensité des halos
          final p = Curves.easeInOut.transform(_breathe.value);
          final glow1 = 0.10 + p * 0.06; // 0.10 → 0.16
          final glow2 = 0.06 + p * 0.05; // 0.06 → 0.11

          return Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: t.isDark
                    ? [
                        t.background,
                        Color.lerp(t.background, Colors.black, 0.4)!
                      ]
                    : [
                        t.background,
                        Color.lerp(t.background, Colors.white, 0.5)!
                      ],
              ),
            ),
            child: Stack(
              children: [
                // Halo primaire (accent) — haut gauche
                Positioned(
                  top: -100,
                  left: -80,
                  child: IgnorePointer(
                    child: Container(
                      width: 340,
                      height: 340,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            t.primary.withValues(alpha: glow1),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                // Halo secondaire (or) — bas droit
                Positioned(
                  bottom: -120,
                  right: -60,
                  child: IgnorePointer(
                    child: Container(
                      width: 300,
                      height: 300,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            t.gold.withValues(alpha: glow2),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                // Contenu par-dessus
                Positioned.fill(child: widget.child),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Composant : Activité récente (ligne d'historique premium)
class EmeraldActivityRow extends StatelessWidget {
  final String childName;
  final String reason;
  final int points;
  final bool isBonus;
  final DateTime date;
  final String? actionBy;
  final VoidCallback? onTap;

  const EmeraldActivityRow({
    super.key,
    required this.childName,
    required this.reason,
    required this.points,
    required this.isBonus,
    required this.date,
    this.actionBy,
    this.onTap,
  });

  String _timeAgo() {
    final diff = DateTime.now().difference(date);
    if (diff.inMinutes < 1) return "À l'instant";
    if (diff.inMinutes < 60) return 'Il y a ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'Il y a ${diff.inHours} h';
    if (diff.inDays < 7) return 'Il y a ${diff.inDays} j';
    return '${date.day}/${date.month}';
  }

  @override
  Widget build(BuildContext context) {
    final accent = isBonus ? EmeraldPalette.emerald : EmeraldPalette.error;
    final sign = isBonus ? '+' : '-';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            children: [
              // Icône accent
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: accent.withValues(alpha: 0.3),
                    width: 1,
                  ),
                ),
                child: Icon(
                  isBonus ? Icons.add_rounded : Icons.remove_rounded,
                  color: accent,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              // Infos
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          childName,
                          style: EmeraldTypography.heading.copyWith(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(
                            color: accent.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '$sign$points',
                            style: TextStyle(
                              color: accent,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      reason,
                      style: EmeraldTypography.caption.copyWith(fontSize: 12),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _timeAgo() + (actionBy != null ? ' · $actionBy' : ''),
                      style: EmeraldTypography.caption.copyWith(
                        fontSize: 10,
                        color: EmeraldPalette.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: EmeraldPalette.textMuted,
                size: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Helper : Formate une date en français ("lundi 5 juin")
String emeraldFormatDate(DateTime date) {
  const weekdays = [
    'lundi',
    'mardi',
    'mercredi',
    'jeudi',
    'vendredi',
    'samedi',
    'dimanche'
  ];
  const months = [
    'janvier',
    'février',
    'mars',
    'avril',
    'mai',
    'juin',
    'juillet',
    'août',
    'septembre',
    'octobre',
    'novembre',
    'décembre'
  ];
  return '${weekdays[date.weekday - 1]} ${date.day} ${months[date.month - 1]}';
}

/// Couleur personnalisée par enfant (basée sur son nom)
Color emeraldChildAccent(String name) {
  const palette = [
    EmeraldPalette.emerald,
    EmeraldPalette.gold,
    Color(0xFF8B5CF6), // Violet
    Color(0xFFEC4899), // Rose
    Color(0xFF3B82F6), // Bleu
    Color(0xFFF59E0B), // Ambre
    Color(0xFF06B6D4), // Cyan
    Color(0xFFEF4444), // Rouge
  ];
  if (name.isEmpty) return palette[0];
  return palette[name.codeUnitAt(0) % palette.length];
}

/// Composant : Carte Membre Premium (style carte de visite)
/// Valorise chaque enfant individuellement, sans compétition.
class EmeraldChildCard extends StatefulWidget {
  final String name;
  final String levelTitle;
  final double levelProgress; // 0.0 → 1.0
  final int points;
  final int pointsToday;
  final int badgeCount;
  final int? streakDays;
  final Widget avatar; // Widget avatar (photo ou initiale)
  final VoidCallback? onTap;

  const EmeraldChildCard({
    super.key,
    required this.name,
    required this.levelTitle,
    required this.levelProgress,
    required this.points,
    required this.pointsToday,
    required this.badgeCount,
    this.streakDays,
    required this.avatar,
    this.onTap,
  });

  @override
  State<EmeraldChildCard> createState() => _EmeraldChildCardState();
}

class _EmeraldChildCardState extends State<EmeraldChildCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _shimmerController;
  late Animation<double> _shimmerAnim;

  @override
  void initState() {
    super.initState();
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    );
    _shimmerAnim = Tween<double>(begin: -1.0, end: 2.0).animate(
      CurvedAnimation(parent: _shimmerController, curve: Curves.easeInOut),
    );
    _shimmerController.repeat();
  }

  @override
  void dispose() {
    _shimmerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accent = emeraldChildAccent(widget.name);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: EmeraldPalette.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: accent.withValues(alpha: 0.25),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.25),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              // ─── Avatar avec halo coloré + shimmer ───
              Stack(
                alignment: Alignment.center,
                children: [
                  // Halo
                  Container(
                    width: 76,
                    height: 76,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          accent.withValues(alpha: 0.3),
                          accent.withValues(alpha: 0.0),
                        ],
                      ),
                    ),
                  ),
                  // Avatar (clipé en cercle)
                  ClipOval(
                    child: SizedBox(
                      width: 64,
                      height: 64,
                      child: widget.avatar,
                    ),
                  ),
                  // Bordure colorée
                  Container(
                    width: 66,
                    height: 66,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: accent.withValues(alpha: 0.6),
                        width: 2,
                      ),
                    ),
                  ),
                  // Shimmer subtil
                  AnimatedBuilder(
                    animation: _shimmerAnim,
                    builder: (context, _) {
                      return ClipOval(
                        child: SizedBox(
                          width: 64,
                          height: 64,
                          child: ShaderMask(
                            shaderCallback: (bounds) {
                              return LinearGradient(
                                begin: Alignment(
                                    _shimmerAnim.value - 0.5, 0),
                                end: Alignment(
                                    _shimmerAnim.value + 0.5, 0),
                                colors: [
                                  Colors.transparent,
                                  Colors.white.withValues(alpha: 0.15),
                                  Colors.transparent,
                                ],
                              ).createShader(bounds);
                            },
                            blendMode: BlendMode.srcOver,
                            child: Container(color: Colors.transparent),
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // ─── Nom + niveau ───
              Text(
                widget.name,
                style: EmeraldTypography.heading.copyWith(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  widget.levelTitle,
                  style: TextStyle(
                    color: accent,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 10),

              // ─── Barre de progression vers niveau suivant ───
              ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: SizedBox(
                  height: 4,
                  child: Stack(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          color: EmeraldPalette.surfaceHigh,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                      FractionallySizedBox(
                        widthFactor:
                            widget.levelProgress.clamp(0.0, 1.0),
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                accent,
                                accent.withValues(alpha: 0.7),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(3),
                            boxShadow: [
                              BoxShadow(
                                color: accent.withValues(alpha: 0.5),
                                blurRadius: 6,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${(widget.levelProgress * 100).round()}%',
                    style: EmeraldTypography.caption.copyWith(
                      fontSize: 9,
                      color: EmeraldPalette.textMuted,
                    ),
                  ),
                  Text(
                    '${widget.points} pts',
                    style: EmeraldTypography.caption.copyWith(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: accent,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // ─── Mini stats : Badges + Streak ───
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: EmeraldPalette.surfaceLow,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    // Badges
                    _MiniStat(
                      icon: Icons.emoji_events_rounded,
                      value: '${widget.badgeCount}',
                      label: 'badges',
                      color: EmeraldPalette.gold,
                    ),
                    Container(
                      width: 1,
                      height: 24,
                      color: EmeraldPalette.glassBorder,
                    ),
                    // Streak
                    _MiniStat(
                      icon: Icons.local_fire_department_rounded,
                      value: '${widget.streakDays ?? 0}j',
                      label: 'streak',
                      color: EmeraldPalette.warning,
                    ),
                    Container(
                      width: 1,
                      height: 24,
                      color: EmeraldPalette.glassBorder,
                    ),
                    // Points du jour
                    _MiniStat(
                      icon: Icons.bolt_rounded,
                      value: '+${widget.pointsToday}',
                      label: "aujourd'hui",
                      color: EmeraldPalette.emerald,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;

  const _MiniStat({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 14),
        const SizedBox(height: 2),
        Text(
          value,
          style: EmeraldTypography.kpiNumber.copyWith(
            fontSize: 12,
            color: color,
          ),
        ),
        Text(
          label,
          style: EmeraldTypography.caption.copyWith(
            fontSize: 8,
            color: EmeraldPalette.textMuted,
          ),
        ),
      ],
    );
  }
}

/// Composant : BANDEAU de MODE (Parent / Enfant)
/// Affiche un bandeau coloré en haut de l'écran pour distinguer visuellement
/// le mode actuel. CRITIQUE pour la sécurité : évite qu'un enfant croie être
/// en mode enfant alors qu'il est en mode parent.
///
/// - Mode PARENT : bandeau doré "MODE PARENT · {nom}" + bouton verrouiller
/// - Mode ENFANT : bandeau émeraude discret "Mode Enfant · {nom}"
class EmeraldModeBanner extends StatelessWidget {
  final bool isParentMode;
  final String parentName;
  final String childName;
  final VoidCallback? onLockTap; // Pour verrouiller le mode parent
  final VoidCallback? onUnlockTap; // Pour activer le mode parent (depuis mode enfant)

  const EmeraldModeBanner({
    super.key,
    required this.isParentMode,
    required this.parentName,
    required this.childName,
    this.onLockTap,
    this.onUnlockTap,
  });

  @override
  Widget build(BuildContext context) {
    if (isParentMode) {
      // ─── MODE PARENT : bandeau doré voyant ───
      return Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              EmeraldPalette.gold.withValues(alpha: 0.18),
              EmeraldPalette.goldLight.withValues(alpha: 0.08),
            ],
          ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: EmeraldPalette.gold.withValues(alpha: 0.5),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: EmeraldPalette.gold.withValues(alpha: 0.15),
              blurRadius: 12,
              spreadRadius: 1,
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: EmeraldPalette.gold.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.shield_rounded,
                color: EmeraldPalette.goldLight,
                size: 16,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'MODE PARENT',
                    style: EmeraldTypography.label.copyWith(
                      fontSize: 10,
                      color: EmeraldPalette.goldLight,
                      letterSpacing: 1.5,
                    ),
                  ),
                  Text(
                    parentName,
                    style: EmeraldTypography.heading.copyWith(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (onLockTap != null)
              GestureDetector(
                onTap: onLockTap,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: EmeraldPalette.gold.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: EmeraldPalette.gold.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.lock_rounded,
                        color: EmeraldPalette.goldLight,
                        size: 14,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Verrouiller',
                        style: EmeraldTypography.caption.copyWith(
                          fontSize: 11,
                          color: EmeraldPalette.goldLight,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      );
    } else {
      // ─── MODE ENFANT : bandeau émeraude discret ───
      return Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: EmeraldPalette.emerald.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: EmeraldPalette.emerald.withValues(alpha: 0.25),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: EmeraldPalette.emerald.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.child_care_rounded,
                color: EmeraldPalette.emeraldLight,
                size: 14,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Mode Enfant · $childName',
                style: EmeraldTypography.caption.copyWith(
                  fontSize: 12,
                  color: EmeraldPalette.emeraldLight,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            // Bouton "Mode Parent" pour activer le mode parent
            if (onUnlockTap != null)
              GestureDetector(
                onTap: onUnlockTap,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: EmeraldPalette.gold.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: EmeraldPalette.gold.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.shield_rounded,
                        color: EmeraldPalette.goldLight,
                        size: 14,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Mode Parent',
                        style: EmeraldTypography.caption.copyWith(
                          fontSize: 11,
                          color: EmeraldPalette.goldLight,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      );
    }
  }
}


