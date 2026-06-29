// lib/widgets/sync_status_bar.dart
//
// Petit bandeau de statut de synchronisation.
// S'affiche brièvement quand une reconnexion Firestore est en cours, et
// montre discrètement l'heure de dernière synchro dans le header.
//
// Utilisation :
//   SyncStatusBar()            // bannière de reconnexion auto (apparaît/disparaît)
//   SyncStatusChip()           // petit indicateur "Synchro il y a 2min"

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/family_provider.dart';

/// Bannière qui apparaît uniquement pendant une reconnexion Firestore.
class SyncStatusBar extends StatelessWidget {
  const SyncStatusBar({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<FamilyProvider>(
      builder: (context, provider, _) {
        if (!provider.isReconnecting) return const SizedBox.shrink();
        return Material(
          color: Colors.transparent,
          child: Container(
            margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFF00E676).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: const Color(0xFF00E676).withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor:
                        AlwaysStoppedAnimation<Color>(Color(0xFF00E676)),
                  ),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Reconnexion à la synchronisation…',
                    style: TextStyle(
                      color: Color(0xFF69F0AE),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const Icon(Icons.sync_rounded,
                    color: Color(0xFF00E676), size: 16),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Petit chip discret montrant l'heure de dernière synchro.
/// Idéal dans un header. S'affiche seulement si la synchro est activée.
class SyncStatusChip extends StatelessWidget {
  final Color? color;
  const SyncStatusChip({super.key, this.color});

  @override
  Widget build(BuildContext context) {
    return Consumer<FamilyProvider>(
      builder: (context, provider, _) {
        if (!provider.isSyncEnabled) return const SizedBox.shrink();
        final label = provider.lastSyncLabel;
        final c = color ?? const Color(0xFF94A3A0);
        final ok = label != null && !provider.isReconnecting;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: (ok ? const Color(0xFF00E676) : const Color(0xFFF59E0B))
                .withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: (ok ? const Color(0xFF00E676) : const Color(0xFFF59E0B))
                  .withValues(alpha: 0.3),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                provider.isReconnecting
                    ? Icons.sync_rounded
                    : (ok ? Icons.cloud_done_rounded : Icons.cloud_off_rounded),
                size: 12,
                color: ok ? const Color(0xFF00E676) : const Color(0xFFF59E0B),
              ),
              const SizedBox(width: 4),
              Text(
                provider.isReconnecting
                    ? 'Sync…'
                    : (label != null ? 'Sync $label' : 'Hors ligne'),
                style: TextStyle(
                  color: c,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
