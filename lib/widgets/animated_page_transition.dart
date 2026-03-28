import 'package:flutter/material.dart';
import 'dart:math' as math;

/// Route avec transition slide + fade
class SlidePageRoute<T> extends PageRouteBuilder<T> {
  final Widget page;
  final SlideDirection direction;

  SlidePageRoute({
    required this.page,
    this.direction = SlideDirection.right,
  }) : super(
          pageBuilder: (context, animation, secondaryAnimation) => page,
          transitionDuration: const Duration(milliseconds: 500),
          reverseTransitionDuration: const Duration(milliseconds: 400),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            final offsetBegin = _getOffset(direction);
            final tween = Tween(begin: offsetBegin, end: Offset.zero)
                .chain(CurveTween(curve: Curves.easeOutCubic));
            final fadeTween = Tween(begin: 0.0, end: 1.0)
                .chain(CurveTween(curve: Curves.easeIn));

            return SlideTransition(
              position: animation.drive(tween),
              child: FadeTransition(
                opacity: animation.drive(fadeTween),
                child: child,
              ),
            );
          },
        );

  static Offset _getOffset(SlideDirection dir) {
    switch (dir) {
      case SlideDirection.right:
        return const Offset(1.0, 0.0);
      case SlideDirection.left:
        return const Offset(-1.0, 0.0);
      case SlideDirection.up:
        return const Offset(0.0, 1.0);
      case SlideDirection.down:
        return const Offset(0.0, -1.0);
    }
  }
}

/// Route avec zoom + fade
class ZoomPageRoute<T> extends PageRouteBuilder<T> {
  final Widget page;

  ZoomPageRoute({required this.page})
      : super(
          pageBuilder: (context, animation, secondaryAnimation) => page,
          transitionDuration: const Duration(milliseconds: 600),
          reverseTransitionDuration: const Duration(milliseconds: 400),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            final scaleTween = Tween(begin: 0.85, end: 1.0)
                .chain(CurveTween(curve: Curves.easeOutBack));
            final fadeTween = Tween(begin: 0.0, end: 1.0)
                .chain(CurveTween(curve: Curves.easeIn));

            return ScaleTransition(
              scale: animation.drive(scaleTween),
              child: FadeTransition(
                opacity: animation.drive(fadeTween),
                child: child,
              ),
            );
          },
        );
}

/// Route avec rotation + scale (pour les pages fun)
class SpinPageRoute<T> extends PageRouteBuilder<T> {
  final Widget page;

  SpinPageRoute({required this.page})
      : super(
          pageBuilder: (context, animation, secondaryAnimation) => page,
          transitionDuration: const Duration(milliseconds: 700),
          reverseTransitionDuration: const Duration(milliseconds: 400),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            final rotateTween = Tween(begin: 0.1, end: 0.0)
                .chain(CurveTween(curve: Curves.easeOutCubic));
            final scaleTween = Tween(begin: 0.8, end: 1.0)
                .chain(CurveTween(curve: Curves.easeOutBack));
            final fadeTween = Tween(begin: 0.0, end: 1.0)
                .chain(CurveTween(curve: Curves.easeIn));

            return FadeTransition(
              opacity: animation.drive(fadeTween),
              child: ScaleTransition(
                scale: animation.drive(scaleTween),
                child: RotationTransition(
                  turns: animation.drive(rotateTween),
                  child: child,
                ),
              ),
            );
          },
        );
}

/// Route avec effet de "porte qui s'ouvre" (3D perspective)
class DoorPageRoute<T> extends PageRouteBuilder<T> {
  final Widget page;

  DoorPageRoute({required this.page})
      : super(
          pageBuilder: (context, animation, secondaryAnimation) => page,
          transitionDuration: const Duration(milliseconds: 600),
          reverseTransitionDuration: const Duration(milliseconds: 400),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            final curved = CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
            );

            return AnimatedBuilder(
              animation: curved,
              builder: (context, _) {
                final angle = (1 - curved.value) * math.pi / 4;
                return Transform(
                  alignment: Alignment.centerLeft,
                  transform: Matrix4.identity()
                    ..setEntry(3, 2, 0.001)
                    ..rotateY(angle),
                  child: Opacity(
                    opacity: curved.value.clamp(0.0, 1.0),
                    child: child,
                  ),
                );
              },
            );
          },
        );
}

/// Route avec effet cascade / reveal circulaire
class CircularRevealPageRoute<T> extends PageRouteBuilder<T> {
  final Widget page;
  final Offset? center;

  CircularRevealPageRoute({required this.page, this.center})
      : super(
          pageBuilder: (context, animation, secondaryAnimation) => page,
          transitionDuration: const Duration(milliseconds: 700),
          reverseTransitionDuration: const Duration(milliseconds: 500),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            final curved = CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
            );

            return AnimatedBuilder(
              animation: curved,
              builder: (context, _) {
                final size = MediaQuery.of(context).size;
                final maxRadius = math.sqrt(
                    size.width * size.width + size.height * size.height);
                final revealCenter =
                    Offset(size.width / 2, size.height / 2);

                return ClipOval(
                  clipper: _CircularRevealClipper(
                    center: revealCenter,
                    radius: maxRadius * curved.value,
                  ),
                  child: child,
                );
              },
            );
          },
        );
}

class _CircularRevealClipper extends CustomClipper<Rect> {
  final Offset center;
  final double radius;

  _CircularRevealClipper({required this.center, required this.radius});

  @override
  Rect getClip(Size size) {
    return Rect.fromCircle(center: center, radius: radius);
  }

  @override
  bool shouldReclip(covariant _CircularRevealClipper oldClipper) =>
      radius != oldClipper.radius || center != oldClipper.center;
}

enum SlideDirection { right, left, up, down }
