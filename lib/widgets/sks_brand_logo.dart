import 'package:flutter/material.dart';

/// Logo commun aux points d’entrée de l’application.
class SksBrandLogo extends StatelessWidget {
  const SksBrandLogo({super.key, this.size = 44});

  final double size;

  @override
  Widget build(BuildContext context) => Semantics(
        label: 'Logo SKS Family',
        image: true,
        child: ExcludeSemantics(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(size * .23),
            child: Image.asset(
              'assets/icon/app_icon.png',
              width: size,
              height: size,
              fit: BoxFit.contain,
              filterQuality: FilterQuality.medium,
            ),
          ),
        ),
      );
}

/// Signature décorative statique : derrière le contenu et sans interaction.
class SksBrandWatermark extends StatelessWidget {
  const SksBrandWatermark({super.key});

  @override
  Widget build(BuildContext context) => Positioned.fill(
        child: IgnorePointer(
          child: ExcludeSemantics(
            child: RepaintBoundary(
              child: LayoutBuilder(builder: (context, constraints) {
                final size = (constraints.maxWidth * .82).clamp(220.0, 380.0);
                return ClipRect(
                  child: Align(
                    alignment: const Alignment(1.7, -.65),
                    child: Opacity(
                      opacity: .08,
                      child: ColorFiltered(
                        colorFilter: const ColorFilter.mode(
                            Colors.white, BlendMode.saturation),
                        child: SksBrandLogo(size: size),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
        ),
      );
}

/// Bandeau de marque lisible, avec un fond réservé au logo.
class SksBrandBanner extends StatelessWidget {
  const SksBrandBanner({super.key});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
              colors: [Color(0xFF163E30), Color(0xFF1C2B25)]),
          borderRadius: BorderRadius.circular(24),
          border:
              Border.all(color: const Color(0xFF78D5A5).withValues(alpha: .2)),
        ),
        child: Row(children: [
          const Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                Text('SKS FAMILY',
                    style: TextStyle(
                        color: Color(0xFF91DEB6),
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 2)),
                SizedBox(height: 5),
                Text('Grandir ensemble.',
                    style: TextStyle(
                        color: Color(0xFFF5F1E8),
                        fontSize: 23,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -.7)),
                SizedBox(height: 4),
                Text('Chaque effort compte.',
                    style: TextStyle(color: Color(0xFFBACFC2), fontSize: 12)),
              ])),
          const SizedBox(width: 10),
          const SksBrandLogo(size: 70),
        ]),
      );
}

/// Signature commune aux titres des onglets principaux.
class SksPageTitle extends StatelessWidget {
  const SksPageTitle(this.title, {super.key});
  final String title;
  @override
  Widget build(BuildContext context) => Row(children: [
        const SksBrandLogo(size: 32),
        const SizedBox(width: 10),
        Expanded(
            child: Text(title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    color: Color(0xFFF5F1E8),
                    fontSize: 18,
                    fontWeight: FontWeight.w700))),
      ]);
}
