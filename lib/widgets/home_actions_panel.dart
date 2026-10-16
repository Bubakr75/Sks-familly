import 'package:flutter/material.dart';
import '../config/emerald_theme.dart';

class HomeActionsPanel extends StatelessWidget {
  const HomeActionsPanel(
      {super.key,
      required this.showParentActions,
      required this.onBonus,
      required this.onPenalty,
      required this.onLines,
      required this.onPhoto});
  final bool showParentActions;
  final VoidCallback onBonus;
  final VoidCallback onPenalty;
  final VoidCallback onLines;
  final VoidCallback onPhoto;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const EmeraldSectionTitle(
              title: 'Au quotidien', icon: Icons.bolt_rounded),
          if (showParentActions) ...[
            Row(children: [
              Expanded(
                  child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                          backgroundColor: EmeraldPalette.emeraldDark,
                          foregroundColor: EmeraldPalette.background,
                          padding: const EdgeInsets.symmetric(vertical: 18)),
                      icon: const Icon(Icons.add_circle_outline),
                      label: const Text('Bonus'),
                      onPressed: onBonus)),
              const SizedBox(width: 10),
              Expanded(
                  child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                          backgroundColor: EmeraldPalette.warning,
                          foregroundColor: EmeraldPalette.background,
                          padding: const EdgeInsets.symmetric(vertical: 18)),
                      icon: const Icon(Icons.remove_circle_outline),
                      label: const Text('Pénalité'),
                      onPressed: onPenalty)),
            ]),
            const SizedBox(height: 10),
          ],
          EmeraldCard(
              padding: EdgeInsets.zero,
              child: ListTile(
                leading: const Icon(Icons.menu_book_rounded,
                    color: EmeraldPalette.gold),
                title: Text(
                    showParentActions
                        ? 'Lignes de punition et immunités'
                        : 'Mes lignes et immunités',
                    style: const TextStyle(
                        color: EmeraldPalette.textPrimary,
                        fontWeight: FontWeight.w700)),
                subtitle: const Text('Voir les lignes et leur progression',
                    style: TextStyle(color: EmeraldPalette.textSecondary)),
                trailing: const Icon(Icons.chevron_right_rounded,
                    color: EmeraldPalette.gold),
                onTap: onLines,
              )),
          if (showParentActions)
            Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                    onPressed: onPhoto,
                    icon: const Icon(Icons.camera_alt_outlined),
                    label: const Text('Ajouter avec Photo IA'))),
          const SizedBox(height: 8),
        ],
      );
}
