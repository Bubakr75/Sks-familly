// lib/screens/shop_admin_screen.dart
//
// Administration de la Boutique (Mode Parent uniquement).
// Permet d'ajouter, modifier, supprimer les récompenses et leurs coûts.
// Maintenant avec photo optionnelle du produit !

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../providers/family_provider.dart';
import '../models/reward_model.dart';
import '../config/emerald_theme.dart';
import '../utils/image_cache.dart';
import '../utils/image_compressor.dart';

class ShopAdminScreen extends StatelessWidget {
  const ShopAdminScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final fp = context.watch<FamilyProvider>();

    return Scaffold(
      backgroundColor: EmeraldPalette.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text('Gérer la Boutique',
            style:
                TextStyle(color: EmeraldPalette.textPrimary, fontWeight: FontWeight.bold)),
        iconTheme: const IconThemeData(color: EmeraldPalette.textPrimary),
        actions: [
          // 🔥 Bouton Soldes
          IconButton(
            icon: Icon(
              fp.isSaleActive ? Icons.local_fire_department_rounded : Icons.local_offer_outlined,
              color: fp.isSaleActive ? Colors.orange : Colors.redAccent,
              size: 26,
            ),
            onPressed: () => _showSaleDialog(context, fp),
          ),
          IconButton(
            icon: const Icon(Icons.add_circle_rounded,
                color: EmeraldPalette.gold, size: 30),
            onPressed: () => _showAddEditDialog(context, fp),
          ),
        ],
      ),
      body: fp.rewards.isEmpty
          ? const Center(
              child: Text(
                  'Aucune récompense. Cliquez sur + pour en ajouter.',
                  style: TextStyle(color: EmeraldPalette.textSecondary)))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: fp.rewards.length,
              itemBuilder: (context, index) {
                final reward = fp.rewards[index];
                return _RewardAdminTile(
                  reward: reward,
                  onEdit: () =>
                      _showAddEditDialog(context, fp, existing: reward),
                  onDelete: () => _confirmDelete(context, fp, reward),
                );
              },
            ),
    );
  }

  void _showAddEditDialog(BuildContext context, FamilyProvider fp,
      {RewardModel? existing}) {
    final titleCtrl = TextEditingController(text: existing?.title ?? '');
    final descCtrl =
        TextEditingController(text: existing?.description ?? '');
    final costCtrl =
        TextEditingController(text: existing?.cost.toString() ?? '50');
    final allEmojis = [
      '🎁', '🎮', '🌙', '🍕', '🃏', '🍫', '🎬', '⚽', '🎨', '📚',
      '🎲', '🍦', '🍔', '🚗', '✈️', '🎪', '🛌', '🎸', '📱', '💵',
      '🏆', '⭐', '🎈', '🍿', '🚲', '🏊', '🎯', '🧩', '🔌', '🎧'
    ];

    // État mutable pour le dialogue
    String selectedIcon = existing?.icon ?? '🎁';
    String? photoBase64 = existing?.photoBase64;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          Future<void> _pickPhoto(ImageSource source) async {
            try {
              final xfile = await ImagePicker().pickImage(
                source: source,
                imageQuality: 70,
                maxWidth: 600,
              );
              if (xfile == null) return;
              final bytes = await xfile.readAsBytes();
              final compressed =
                  await ImageCompressor.compressBase64(base64Encode(bytes)) ??
                      base64Encode(bytes);
              setDialogState(() => photoBase64 = compressed);
            } catch (_) {}
          }

          return AlertDialog(
            backgroundColor: EmeraldPalette.surface,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24)),
            title: Text(
              existing == null ? 'Nouvelle récompense' : 'Modifier',
              style: const TextStyle(
                  color: EmeraldPalette.textPrimary,
                  fontWeight: FontWeight.bold),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // ─── Photo du produit (optionnelle) ───
                  GestureDetector(
                    onTap: () => _showPhotoPicker(ctx, _pickPhoto),
                    child: Container(
                      width: double.infinity,
                      height: 120,
                      decoration: BoxDecoration(
                        color: EmeraldPalette.surfaceLow,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                            color: EmeraldPalette.gold.withValues(alpha: 0.3),
                            width: 1.5),
                      ),
                      child: photoBase64 != null && photoBase64!.isNotEmpty
                          ? Stack(
                              fit: StackFit.expand,
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(16),
                                  child: Image.memory(
                                    base64Decode(photoBase64!),
                                    fit: BoxFit.cover,
                                  ),
                                ),
                                Positioned(
                                  top: 6,
                                  right: 6,
                                  child: GestureDetector(
                                    onTap: () => setDialogState(
                                        () => photoBase64 = null),
                                    child: Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: const BoxDecoration(
                                        color: Colors.black87,
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(Icons.close,
                                          color: Colors.white, size: 16),
                                    ),
                                  ),
                                ),
                              ],
                            )
                          : Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.add_a_photo_rounded,
                                    color: EmeraldPalette.gold.withValues(alpha: 0.6),
                                    size: 36),
                                const SizedBox(height: 8),
                                Text('Ajouter une photo',
                                    style: TextStyle(
                                        color: EmeraldPalette.gold
                                            .withValues(alpha: 0.7),
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600)),
                                const Text('(optionnel)',
                                    style: TextStyle(
                                        color: Colors.white24, fontSize: 11)),
                              ],
                            ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Sélecteur d'emoji
                  SizedBox(
                    height: 90,
                    child: GridView.builder(
                      shrinkWrap: true,
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 6,
                              mainAxisSpacing: 4,
                              crossAxisSpacing: 4),
                      itemCount: allEmojis.length,
                      itemBuilder: (context, index) {
                        final e = allEmojis[index];
                        return GestureDetector(
                          onTap: () =>
                              setDialogState(() => selectedIcon = e),
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: selectedIcon == e
                                  ? EmeraldPalette.gold.withValues(alpha: 0.2)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                  color: selectedIcon == e
                                      ? EmeraldPalette.gold
                                      : Colors.transparent),
                            ),
                            child: Text(e,
                                style: const TextStyle(fontSize: 24)),
                          ),
                        );
                      },
                    ),
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
                    decoration: _inputDecoration(
                        'Description', 'Ex: 15 minutes supplémentaires'),
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
                child: const Text('Annuler',
                    style: TextStyle(color: EmeraldPalette.textSecondary)),
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
                    // 🔒 Mise à jour SANS changer l'ID (préserve les achats liés)
                    final updated = RewardModel(
                      id: existing.id,
                      title: title,
                      cost: cost,
                      icon: selectedIcon,
                      description: descCtrl.text.trim(),
                      category: existing.category,
                      isActive: existing.isActive,
                      maxPerWeek: existing.maxPerWeek,
                      createdAt: existing.createdAt,
                      photoBase64: photoBase64,
                    );
                    await fp.updateReward(updated);
                  } else {
                    await fp.addReward(
                      title: title,
                      cost: cost,
                      icon: selectedIcon,
                      description: descCtrl.text.trim(),
                      photoBase64: photoBase64,
                    );
                  }
                  if (ctx.mounted) Navigator.pop(ctx);
                },
                child: const Text('Enregistrer',
                    style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          );
        },
      ),
    );
  }

  /// Affiche le choix entre caméra et galerie
  void _showPhotoPicker(
      BuildContext context, Future<void> Function(ImageSource) onPick) {
    showModalBottomSheet(
      context: context,
      backgroundColor: EmeraldPalette.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading:
                  const Icon(Icons.camera_alt_rounded, color: EmeraldPalette.gold),
              title: const Text('Prendre une photo',
                  style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(ctx);
                onPick(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_rounded,
                  color: EmeraldPalette.emeraldLight),
              title: const Text('Choisir dans la galerie',
                  style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(ctx);
                onPick(ImageSource.gallery);
              },
            ),
            const SizedBox(height: 12),
          ],
        ),
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

  /// 🔥 Dialogue de gestion des soldes
  void _showSaleDialog(BuildContext context, FamilyProvider fp) {
    int selectedPercent = fp.saleDiscountPercent > 0 ? fp.saleDiscountPercent : 50;
    int selectedHours = 24;
    final labelCtrl = TextEditingController(text: fp.saleLabel.isNotEmpty ? fp.saleLabel : 'Soldes');

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => AlertDialog(
          backgroundColor: EmeraldPalette.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Row(children: [
            const Icon(Icons.local_fire_department_rounded, color: Colors.orange, size: 28),
            const SizedBox(width: 10),
            const Text('Soldes Boutique',
                style: TextStyle(color: EmeraldPalette.textPrimary, fontWeight: FontWeight.bold)),
          ]),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (fp.isSaleActive) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.orange.withValues(alpha: 0.4)),
                    ),
                    child: Row(children: [
                      const Icon(Icons.access_time, color: Colors.orange, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Vente en cours : -${fp.saleDiscountPercent}%',
                          style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ]),
                  ),
                ],
                const Text('Réduction :',
                    style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                // Choix du pourcentage
                Wrap(
                  spacing: 6,
                  children: [25, 50, 70, 90].map((p) {
                    final isSel = selectedPercent == p;
                    return GestureDetector(
                      onTap: () => setSt(() => selectedPercent = p),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: isSel ? Colors.orange.withValues(alpha: 0.25) : Colors.white.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: isSel ? Colors.orange : Colors.white12),
                        ),
                        child: Text('-$p%',
                            style: TextStyle(
                                color: isSel ? Colors.orange : Colors.white54,
                                fontWeight: FontWeight.w800)),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                const Text('Durée :',
                    style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                // Choix de la durée
                Wrap(
                  spacing: 6,
                  children: [
                    (6, '6h'),
                    (12, '12h'),
                    (24, '24h'),
                    (48, '2j'),
                    (72, '3j'),
                  ].map((item) {
                    final h = item.$1;
                    final label = item.$2;
                    final isSel = selectedHours == h;
                    return GestureDetector(
                      onTap: () => setSt(() => selectedHours = h),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: isSel ? Colors.orange.withValues(alpha: 0.25) : Colors.white.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: isSel ? Colors.orange : Colors.white12),
                        ),
                        child: Text(label,
                            style: TextStyle(
                                color: isSel ? Colors.orange : Colors.white54,
                                fontWeight: FontWeight.w600,
                                fontSize: 13)),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: labelCtrl,
                  style: const TextStyle(color: EmeraldPalette.textPrimary),
                  decoration: InputDecoration(
                    labelText: 'Nom de la vente',
                    labelStyle: const TextStyle(color: EmeraldPalette.textSecondary),
                    filled: true,
                    fillColor: EmeraldPalette.surfaceLow,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            if (fp.isSaleActive)
              TextButton(
                onPressed: () async {
                  Navigator.pop(ctx);
                  await fp.stopSale();
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('✅ Vente arrêtée'), backgroundColor: Colors.grey),
                    );
                  }
                },
                child: const Text('Arrêter la vente', style: TextStyle(color: Colors.redAccent)),
              ),
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Annuler', style: TextStyle(color: Colors.white54)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                Navigator.pop(ctx);
                await fp.startSale(
                  percent: selectedPercent,
                  durationHours: selectedHours,
                  label: labelCtrl.text.trim().isEmpty ? 'Soldes' : labelCtrl.text.trim(),
                );
                if (ctx.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('🔥 Vente lancée ! -$selectedPercent% pendant ${selectedHours}h'),
                      backgroundColor: Colors.orange,
                    ),
                  );
                }
              },
              child: const Text('Lancer 🔥', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(
      BuildContext context, FamilyProvider fp, RewardModel reward) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: EmeraldPalette.surface,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Supprimer ?',
            style: TextStyle(color: EmeraldPalette.textPrimary)),
        content: Text('Voulez-vous supprimer "${reward.title}" ?',
            style: const TextStyle(color: EmeraldPalette.textSecondary)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Annuler', style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white),
            onPressed: () {
              Navigator.pop(ctx);
              fp.deleteReward(reward.id);
            },
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
  }
}

// ─── Carte admin avec photo ──────────────────────────────────
class _RewardAdminTile extends StatelessWidget {
  final RewardModel reward;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _RewardAdminTile(
      {required this.reward, required this.onEdit, required this.onDelete});

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
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(
            width: 48,
            height: 48,
            child: reward.hasPhoto
                ? Image.memory(
                    base64Decode(reward.photoBase64!),
                    fit: BoxFit.cover,
                  )
                : Container(
                    color: EmeraldPalette.gold.withValues(alpha: 0.15),
                    child: Center(
                        child: Text(reward.icon,
                            style: const TextStyle(fontSize: 24))),
                  ),
          ),
        ),
        title: Text(reward.title,
            style: const TextStyle(
                color: EmeraldPalette.textPrimary,
                fontWeight: FontWeight.w600)),
        subtitle: Row(
          children: [
            const Icon(Icons.stars_rounded,
                size: 14, color: EmeraldPalette.gold),
            const SizedBox(width: 4),
            Text('${reward.cost} pts',
                style: const TextStyle(
                    color: EmeraldPalette.gold,
                    fontWeight: FontWeight.w700)),
            if (reward.hasPhoto) ...[
              const SizedBox(width: 8),
              const Icon(Icons.photo_camera_rounded,
                  size: 12, color: Colors.white24),
            ],
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
                icon: const Icon(Icons.edit_rounded,
                    color: EmeraldPalette.emeraldLight, size: 20),
                onPressed: onEdit),
            IconButton(
                icon: const Icon(Icons.delete_outline_rounded,
                    color: Colors.redAccent, size: 20),
                onPressed: onDelete),
          ],
        ),
      ),
    );
  }
}
