import 'package:flutter/material.dart';
import '../config/emerald_theme.dart';

class HomeActionsPanel extends StatelessWidget {
  const HomeActionsPanel(
      {super.key,
      required this.showParentActions,
      required this.onBonus,
      required this.onPenalty,
      required this.onLines,
      required this.onTransfer,
      required this.onPhoto});
  final bool showParentActions;
  final VoidCallback onBonus;
  final VoidCallback onPenalty;
  final VoidCallback onLines;
  final VoidCallback onTransfer;
  final VoidCallback onPhoto;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          if (showParentActions) ...[
            Row(children: [
              Expanded(
                  child: _ActionTile(
                      title: 'Bonus',
                      subtitle: 'Valoriser un effort',
                      icon: Icons.add_rounded,
                      color: EmeraldPalette.emeraldLight,
                      onTap: onBonus)),
              const SizedBox(width: 10),
              Expanded(
                  child: _ActionTile(
                      title: 'Pénalité',
                      subtitle: 'Poser une limite',
                      icon: Icons.remove_rounded,
                      color: EmeraldPalette.penalty,
                      onTap: onPenalty)),
            ]),
            const SizedBox(height: 10),
          ],
          EmeraldCard(
              padding: EdgeInsets.zero,
              child: ListTile(
                leading: const Icon(Icons.menu_book_rounded,
                    color: EmeraldPalette.textSecondary),
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
                    color: EmeraldPalette.textSecondary),
                onTap: onLines,
              )),
          if (showParentActions) ...[
            const SizedBox(height: 10),
            EmeraldCard(
              padding: EdgeInsets.zero,
              child: ListTile(
                leading: const Icon(Icons.swap_horiz_rounded,
                    color: EmeraldPalette.emeraldLight),
                title: const Text('Transfert SKS',
                    style: TextStyle(
                        color: EmeraldPalette.textPrimary,
                        fontWeight: FontWeight.w700)),
                subtitle: const Text('Transférer des points entre enfants',
                    style: TextStyle(color: EmeraldPalette.textSecondary)),
                trailing: const Icon(Icons.chevron_right_rounded,
                    color: EmeraldPalette.textSecondary),
                onTap: onTransfer,
              ),
            ),
            Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                    onPressed: onPhoto,
                    icon: const Icon(Icons.camera_alt_outlined),
                    label: const Text('Ajouter avec Photo IA'))),
          ],
          const SizedBox(height: 8),
        ],
      );
}

class _ActionTile extends StatelessWidget {
  const _ActionTile(
      {required this.title,
      required this.subtitle,
      required this.icon,
      required this.color,
      required this.onTap});
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: Color.alphaBlend(
            color.withValues(alpha: .12), EmeraldPalette.background),
        borderRadius: BorderRadius.circular(24),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(icon, color: color, size: 28),
                    const SizedBox(height: 18),
                    Text(title,
                        style: TextStyle(
                            color: color,
                            fontSize: 18,
                            fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    Text(subtitle,
                        style: TextStyle(color: color, fontSize: 12)),
                  ]),
            )),
      );
}
