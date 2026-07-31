import 'package:flutter/material.dart';

import '../config/emerald_theme.dart';

class FamilyInboxBell extends StatelessWidget {
  const FamilyInboxBell({
    required this.unreadCount,
    required this.onTap,
    super.key,
  });

  final int unreadCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      key: const ValueKey('family-inbox-bell'),
      button: true,
      label: 'Demandes familiales',
      value: '$unreadCount non lues',
      child: SizedBox(
        width: 52,
        height: 52,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Stack(
            clipBehavior: Clip.hardEdge,
            children: [
              Positioned.fill(
                child: Container(
                  margin: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: EmeraldPalette.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: unreadCount > 0
                          ? EmeraldPalette.warning
                          : EmeraldPalette.glassBorder,
                    ),
                  ),
                  child: Center(
                    child: Icon(
                      unreadCount > 0
                          ? Icons.notifications_active_rounded
                          : Icons.notifications_none_rounded,
                      color: unreadCount > 0
                          ? EmeraldPalette.warning
                          : EmeraldPalette.textSecondary,
                      size: 24,
                    ),
                  ),
                ),
              ),
              if (unreadCount > 0)
                Positioned(
                  top: 0,
                  right: 0,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(
                      color: EmeraldPalette.warning,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: EmeraldPalette.background,
                        width: 1.5,
                      ),
                    ),
                    child: Text(
                      unreadCount > 9 ? '9+' : '$unreadCount',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
