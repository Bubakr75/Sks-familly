// lib/widgets/mode_indicator.dart
//
// Icône flottante qui reste visible sur tous les écrans pour distinguer
// clairement le mode Parent du mode Enfant.
// - Mode Parent : bouclier doré + halo doré
// - Mode Enfant : bonhomme vert discret

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/pin_provider.dart';

class ModeIndicator extends StatelessWidget {
  const ModeIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<PinProvider>(
      builder: (context, pin, _) {
        if (!pin.isPinSet) return const SizedBox.shrink();

        final isParent = pin.isParentMode;
        final color = isParent ? const Color(0xFFD4AF37) : const Color(0xFF00E676);

        return Positioned(
          top: MediaQuery.of(context).padding.top + 8,
          right: 12,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: color.withValues(alpha: 0.5), width: 1.5),
              boxShadow: isParent
                  ? [BoxShadow(color: color.withValues(alpha: 0.4), blurRadius: 12, spreadRadius: 1)]
                  : null,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isParent ? Icons.shield_rounded : Icons.child_care_rounded,
                  color: color,
                  size: 16,
                ),
                const SizedBox(width: 6),
                Text(
                  isParent ? 'PARENT' : 'ENFANT',
                  style: TextStyle(
                    color: color,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Wrap l'app avec un Overlay pour afficher le ModeIndicator par-dessus tout.
class ModeIndicatorOverlay extends StatelessWidget {
  final Widget child;
  const ModeIndicatorOverlay({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        const ModeIndicator(),
      ],
    );
  }
}
