// lib/widgets/aurora_glass_card.dart
//
// Carte "Aurora Verre 3D" : verre dépoli (BackdropFilter blur) + surface
// translucide + bordure lumineuse + reflet de lumière en haut + glow coloré
// + EFFET 3D (relief profond, ombres étagées, perspective au tap).
//
// Variante gold : bordure dorée + glow doré pour mettre en avant (1er, badges).
//
// Utilisation :
//   AuroraGlassCard(child: ...)
//   AuroraGlassCard(gold: true, child: ...)
//   AuroraGlassCard(accentColor: Colors.cyan, child: ...)

import 'dart:ui';
import 'package:flutter/material.dart';

class AuroraGlassCard extends StatefulWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double radius;
  final Color? accentColor; // couleur du glow + bordure (défaut : blanc)
  final bool gold; // variante dorée (pour 1er, badges importants)
  final double blurSigma; // intensité du flou verre (défaut 12)
  final VoidCallback? onTap;
  final double glow; // intensité du glow coloré (0 = aucun)
  final bool tilt; // active l'effet 3D tilt au tap (défaut true)

  const AuroraGlassCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.radius = 16,
    this.accentColor,
    this.gold = false,
    this.blurSigma = 12,
    this.onTap,
    this.glow = 0.25,
    this.tilt = true,
  });

  @override
  State<AuroraGlassCard> createState() => _AuroraGlassCardState();
}

class _AuroraGlassCardState extends State<AuroraGlassCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _pressController;
  late Animation<double> _pressAnim;

  @override
  void initState() {
    super.initState();
    _pressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
    );
    _pressAnim = Tween<double>(begin: 0.0, end: 1.0)
        .animate(CurvedAnimation(parent: _pressController, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _pressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accent = widget.gold
        ? const Color(0xFFFFD700)
        : (widget.accentColor ?? const Color(0xFFFFFFFF));

    return Container(
      margin: widget.margin,
      child: GestureDetector(
        onTapDown: widget.tilt ? (_) => _pressController.forward() : null,
        onTapUp: widget.tilt ? (_) => _pressController.reverse() : null,
        onTapCancel: widget.tilt ? () => _pressController.reverse() : null,
        onTap: widget.onTap,
        child: AnimatedBuilder(
          animation: _pressAnim,
          builder: (context, child) {
            // Effet 3D : la carte s'enfonce légèrement (translateZ simulé) au tap
            final press = _pressAnim.value;
            return Transform(
              alignment: Alignment.center,
              transform: Matrix4.identity()
                ..setEntry(3, 2, 0.001) // perspective
                ..rotateX(press * 0.08) // léger basculement avant au tap
                ..scale(1.0 - press * 0.03), // léger rétrécissement
              child: child,
            );
          },
          child: Material(
            color: Colors.transparent,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(widget.radius),
              child: Stack(
                children: [
                  // 1. Flou verre (BackdropFilter)
                  Positioned.fill(
                    child: BackdropFilter(
                      filter: ImageFilter.blur(
                          sigmaX: widget.blurSigma, sigmaY: widget.blurSigma),
                      child: Container(
                        // Surface translucide dégradée
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              accent.withValues(alpha: widget.gold ? 0.16 : 0.12),
                              Colors.white.withValues(alpha: 0.04),
                            ],
                          ),
                          border: Border.all(
                            color: accent.withValues(
                                alpha: widget.gold ? 0.5 : 0.28),
                            width: 1,
                          ),
                          // OMBRES 3D MULTI-COUCHES (relief profond)
                          boxShadow: [
                            // Glow coloré (signature Aurora)
                            if (widget.glow > 0)
                              BoxShadow(
                                color: accent.withValues(alpha: widget.glow),
                                blurRadius: 24,
                                spreadRadius: -4,
                                offset: const Offset(0, 4),
                              ),
                            // Ombre de profondeur (sombre, large)
                            const BoxShadow(
                              color: Color(0x66000000),
                              blurRadius: 28,
                              offset: Offset(0, 14),
                            ),
                            // Ombre colorée large (halo 3D)
                            BoxShadow(
                              color: accent.withValues(alpha: 0.20),
                              blurRadius: 40,
                              spreadRadius: -8,
                              offset: const Offset(0, 20),
                            ),
                            // Reflet interne haut (bord lumineux verre)
                            const BoxShadow(
                              color: Color(0x33FFFFFF),
                              blurRadius: 1,
                              offset: Offset(0, 1),
                              spreadRadius: 0,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  // 2. Reflet de lumière en haut (effet "glass edge" brillant)
                  Positioned(
                    top: 0,
                    left: widget.radius * 0.5,
                    right: widget.radius * 0.5,
                    child: Container(
                      height: 2,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.transparent,
                            Colors.white.withValues(alpha: 0.6),
                            Colors.transparent,
                          ],
                        ),
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(2),
                          topRight: Radius.circular(2),
                        ),
                      ),
                    ),
                  ),
                  // 3. Contenu
                  Padding(
                    padding: widget.padding ?? const EdgeInsets.all(14),
                    child: widget.child,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
