// lib/screens/shop_admin_screen.dart
//
// Administration de la Boutique (Mode Parent uniquement).
// Permet d'ajouter, modifier, supprimer les récompenses et leurs coûts.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/family_provider.dart';
import '../models/reward_model.dart';
import '../config/emerald_theme.dart';

class ShopAdminScreen extends StatelessWidget {
  const ShopAdminScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final fp = context.watch<FamilyProvider>();

    return Scaffold(
      backgroundColor: const Color(0xFF051410),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text('Gérer la Boutique', style: TextStyle(color: EmeraldPalette.textPrimary, fontWeight: FontWeight.bold)),
        iconTheme: const IconThemeData(color: EmeraldPalette.textPrimary),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_rounded, color: EmeraldPalette.gold, size: 30),
            onPressed: () => _showAddEditDialog(context, fp),
          ),
        ],
      ),
      body: fp.rewards.isEmpty
          ? const Center(child: Text('Aucune récompense. Cliquez sur + pour en ajouter.', style: TextStyle(color: EmeraldPalette.textSecondary)))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: fp.rewards.length,
              itemBuilder: (context, index) {
                final reward = fp.rewards[index];
                return _RewardAdminTile(
                  reward: reward,
                  onEdit: () => _showAddEditDialog(context, fp, existing: reward),
                  onDelete: () => _confirmDelete(context, fp, reward),
                );
              },
            ),
    );
  }

  void _showAddEditDialog(BuildContext context, FamilyProvider fp, {RewardModel? existing}) {
    final titleCtrl = TextEditingController(text: existing?.title ?? '');
    final descCtrl = TextEditingController(text: existing?.description ?? '');
    final costCtrl = TextEditingController(text: existing?.cost.toString() ?? '50');
    String selectedIcon = existing?.icon ?? '🎁';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: EmeraldPalette.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(
          existing == null ? 'Nouvelle récompense' : 'Modifier',
          style: const TextStyle(color: EmeraldPalette.textPrimary, fontWeight: FontWeight.bold),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Sélecteur d'emoji
              Wrap(
                spacing: 8,
                children: ['🎁', '🎮', '🌙', '🍕', '🃏', '🍫', '🎬', '⚽', '🎨', '📚', '🎲', '🍦'].map((e) {
                  return GestureDetector(
                    onTap: () => selectedIcon = e,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: selectedIcon == e ? EmeraldPalette.gold.withValues(alpha: 0.2) : Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: selectedIcon == e ? EmeraldPalette.gold : Colors.transparent),
                      ),
                      child: Text(e, style: const TextStyle(fontSize: 24)),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: titleCtrl,
                style: const TextStyle(color: EmeraldPalette.textPrimary),
                decoration: _inputDecoration('Titre', 'Ex: 15 min de console'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: descCtrl,
                style: const TextStyle(color: EmeraldPalette.textPrimary),
                maxLines: 2,
                decoration: _inputDecoration('Description', 'Ex: 15 minutes supplémentaires'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: costCtrl,
                style: const TextStyle(color: EmeraldPalette.textPrimary),
                keyboardType: TextInputType.number,
                decoration: _inputDecoration('Coût (points)', 'Ex: 50'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler', style: TextStyle(color: EmeraldPalette.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: EmeraldPalette.emerald,
              foregroundColor: const Color(0xFF051410),
            ),
            onPressed: () async {
              final title = titleCtrl.text.trim();
              final cost = int.tryParse(costCtrl.text.trim()) ?? 50;
              if (title.isEmpty) return;

              if (existing != null) {
                // Modification : supprimer + recréer (simple)
                await fp.deleteReward(existing.id);
              }
              await fp.addReward(
                title: title,
                cost: cost,
                icon: selectedIcon,
                description: descCtrl.text.trim(),
              );
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Enregistrer', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration(String label, String hint) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: EmeraldPalette.textSecondary),
      hintText: hint,
      hintStyle: const TextStyle(color: EmeraldPalette.textMuted),
      filled: true,
      fillColor: EmeraldPalette.surfaceLow,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
    );
  }

  void _confirmDelete(BuildContext context, FamilyProvider fp, RewardModel reward) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: EmeraldPalette.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Supprimer ?', style: TextStyle(color: EmeraldPalette.textPrimary)),
        content: Text('Voulez-vous supprimer "${reward.title}" ?', style: const TextStyle(color: EmeraldPalette.textSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler', style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
            onPressed: () { Navigator.pop(ctx); fp.deleteReward(reward.id); },
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
  }
}

class _RewardAdminTile extends StatelessWidget {
  final RewardModel reward;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _RewardAdminTile({required this.reward, required this.onEdit, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: EmeraldPalette.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: EmeraldPalette.glassBorder),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: EmeraldPalette.gold.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(child: Text(reward.icon, style: const TextStyle(fontSize: 24))),
        ),
        title: Text(reward.title, style: const TextStyle(color: EmeraldPalette.textPrimary, fontWeight: FontWeight.w600)),
        subtitle: Row(
          children: [
            Icon(Icons.stars_rounded, size: 14, color: EmeraldPalette.gold),
            const SizedBox(width: 4),
            Text('${reward.cost} pts', style: const TextStyle(color: EmeraldPalette.gold, fontWeight: FontWeight.w700)),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(icon: const Icon(Icons.edit_rounded, color: EmeraldPalette.emeraldLight, size: 20), onPressed: onEdit),
            IconButton(icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 20), onPressed: onDelete),
          ],
        ),
      ),
    );
  }
}
