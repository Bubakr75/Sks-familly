// =============================================================================
// SKS Family - Emerald Design System
// =============================================================================
// Design system "Émeraude Premium" inspiré de :
//   - Apple Fitness (premium feel, hiérarchie claire)
//   - Stripe Dashboard (cards nettes, KPIs organisés)
//
// Palette : Vert profond + crème + doré + accent émeraude vif
// =============================================================================

import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';

/// Palette de couleurs Emerald
class EmeraldPalette {
  EmeraldPalette._();

  // Fonds — PLUS SOMBRE pour contraste max avec les cards
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
              Color(0xFF051410),
              Color(0xFF041008),
            ],
          ),
        ),
        child: child,
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
  final int points;
  final int pointsToday;
  final int badgeCount;
  final int? streakDays;
  final Widget avatar; // Widget avatar (photo ou initiale)
  final String? bannerPhotoBase64; // Photo pour la bannière (pleine largeur)
  final String? avatarEmoji; // Emoji si pas de photo
  final VoidCallback? onTap;

  const EmeraldChildCard({
    super.key,
    required this.name,
    required this.points,
    required this.pointsToday,
    required this.badgeCount,
    this.bannerPhotoBase64,
    this.avatarEmoji,
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

  /// Décode le base64 en Uint8List pour Image.memory
  static Uint8List _decodeBase64(String b64) {
    final clean = b64.contains(',') ? b64.split(',').last : b64;
    return base64Decode(clean);
  }

  /// Bannière dégradée (quand pas de photo)
  static Widget _gradientBanner(Color accent) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            accent.withValues(alpha: 0.4),
            accent.withValues(alpha: 0.15),
          ],
        ),
      ),
      child: Center(
        child: Text(
          '👤',
          style: TextStyle(fontSize: 40, color: Colors.white.withValues(alpha: 0.3)),
        ),
      ),
    );
  }

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
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: Column(
              children: [
              // ─── BANNIÈRE PHOTO PLEINE LARGEUR (remplit tout le cadre) ───
              SizedBox(
                height: 140,
                width: double.infinity,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // Photo : BoxFit.cover remplit TOUT le cadre (haut en bas)
                    if (widget.bannerPhotoBase64 != null && widget.bannerPhotoBase64!.isNotEmpty)
                      widget.bannerPhotoBase64!.startsWith('http')
                        ? Image.network(
                            widget.bannerPhotoBase64!,
                            fit: BoxFit.cover,
                            alignment: Alignment.topCenter,
                            errorBuilder: (_, __, ___) => _gradientBanner(accent),
                          )
                        : Image.memory(
                            _decodeBase64(widget.bannerPhotoBase64!),
                            fit: BoxFit.cover,
                            alignment: Alignment.topCenter,
                            errorBuilder: (_, __, ___) => _gradientBanner(accent),
                          )
                    else
                      _gradientBanner(accent),
                    // Dégradé sombre en bas pour la lisibilité du nom
                    Align(
                      alignment: Alignment.bottomCenter,
                      child: Container(
                        height: 60,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              EmeraldPalette.surface.withValues(alpha: 0.95),
                            ],
                          ),
                        ),
                      ),
                    ),
                    // Nom par-dessus
                    Positioned(
                      bottom: 6,
                      left: 12,
                      right: 12,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.name,
                            style: EmeraldTypography.heading.copyWith(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: accent.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: accent.withValues(alpha: 0.4)),
                            ),
                            child: Text(
                              'Points disponibles',
                              style: TextStyle(
                                color: accent,
                                fontSize: 9,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              // ─── Corps de la carte : POINTS EN GROS AU CENTRE ───
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: Column(
                  children: [
                    // POINTS EN GROS (l'élément principal de la carte)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          '${widget.points}',
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.w900,
                            color: accent,
                            shadows: [Shadow(color: accent.withValues(alpha: 0.4), blurRadius: 12)],
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'points disponibles',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: EmeraldPalette.textSecondary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // ─── Mini stats : Série + Aujourd'hui + Total ───
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
                    // Série (jours sans pénalité)
                    _MiniStat(
                      icon: Icons.local_fire_department_rounded,
                      value: '${widget.streakDays ?? 0}j',
                      label: 'Série',
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
                      label: "Aujourd'hui",
                      color: EmeraldPalette.emerald,
                    ),
                    Container(
                      width: 1,
                      height: 24,
                      color: EmeraldPalette.glassBorder,
                    ),
                    // Total points bonus
                    _MiniStat(
                      icon: Icons.stars_rounded,
                      value: '${widget.points}',
                      label: 'Total',
                      color: EmeraldPalette.gold,
                    ),
                  ],
                ),
              ),
            ],  // fin Column enfants
            ),
          ),  // fin Padding
            ],  // fin Column de ClipRRect
          ),
        ),  // fin ClipRRect
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


