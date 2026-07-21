// lib/screens/evening_summary_screen.dart
//
// Bilan du Soir : récap visuel de la journée + ajustement des points.
// Le parent voit tout ce qui s'est passé aujourd'hui et peut ajuster.

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/family_provider.dart';
import '../models/child_model.dart';
import '../models/history_entry.dart';
import '../config/emerald_theme.dart';

class EveningSummaryScreen extends StatefulWidget {
  const EveningSummaryScreen({super.key});

  @override
  State<EveningSummaryScreen> createState() => _EveningSummaryScreenState();
}

class _EveningSummaryScreenState extends State<EveningSummaryScreen> {
  @override
  Widget build(BuildContext context) {
    final fp = context.watch<FamilyProvider>();
    final children = fp.children;
    final today = _getTodayHistory(fp);

    return Scaffold(
      backgroundColor: EmeraldPalette.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text('🌙 Bilan du jour', style: TextStyle(color: EmeraldPalette.textPrimary, fontWeight: FontWeight.bold)),
        iconTheme: const IconThemeData(color: EmeraldPalette.textPrimary),
        actions: [
          IconButton(
            icon: const Icon(Icons.check_circle_rounded, color: EmeraldPalette.emerald, size: 28),
            onPressed: () => _validateDay(context),
          ),
        ],
      ),
      body: children.isEmpty
          ? const Center(child: Text('Aucun enfant', style: TextStyle(color: Colors.white54)))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: children.length,
              itemBuilder: (context, index) {
                final child = children[index];
                final childHistory = today.where((h) => h.childId == child.id).toList();
                return _ChildSummaryCard(
                  child: child,
                  history: childHistory,
                  onAddBonus: (amount, reason) => fp.addQuickBonus(child.id, reason),
                  onAddPenalty: (amount, reason) => fp.addQuickPenalty(child.id, reason),
                );
              },
            ),
    );
  }

  List<HistoryEntry> _getTodayHistory(FamilyProvider fp) {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    return fp.history.where((h) => h.date.isAfter(todayStart)).toList();
  }

  void _validateDay(BuildContext context) {
    HapticFeedback.heavyImpact();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: EmeraldPalette.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(children: [
          Text('🌙', style: TextStyle(fontSize: 28)),
          SizedBox(width: 10),
          Text('Journée validée !', style: TextStyle(color: EmeraldPalette.textPrimary)),
        ]),
        content: const Text('Le bilan du jour est terminé. Les enfants peuvent maintenant aller à la boutique dépenser leurs points !',
            style: TextStyle(color: EmeraldPalette.textSecondary)),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: EmeraldPalette.emerald, foregroundColor: const Color(0xFF051410)),
            onPressed: () { Navigator.pop(ctx); Navigator.pop(context); },
            child: const Text('Terminer', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// CARTE RÉCAP PAR ENFANT
// ════════════════════════════════════════════════════════════════
class _ChildSummaryCard extends StatelessWidget {
  final ChildModel child;
  final List<HistoryEntry> history;
  final Future<int> Function(int, String) onAddBonus;
  final Future<int> Function(int, String) onAddPenalty;

  const _ChildSummaryCard({
    required this.child,
    required this.history,
    required this.onAddBonus,
    required this.onAddPenalty,
  });

  @override
  Widget build(BuildContext context) {
    final accent = emeraldChildAccent(child.name);
    final bonusEntries = history.where((h) => h.isBonus && !h.isPointsTransfer).toList();
    final penaltyEntries = history.where((h) => h.isPenalty && !h.isPointsTransfer).toList();
    final totalBonus = bonusEntries.fold(0, (sum, h) => sum + h.points);
    final totalPenalty = penaltyEntries.fold(0, (sum, h) => sum + h.points);
    final net = totalBonus - totalPenalty;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: EmeraldPalette.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: accent.withValues(alpha: 0.25)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ─── Header enfant ───
            Row(
              children: [
                Text(child.avatar.isNotEmpty ? child.avatar : '👤', style: const TextStyle(fontSize: 28)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(child.name, style: const TextStyle(color: EmeraldPalette.textPrimary, fontSize: 18, fontWeight: FontWeight.w800)),
                ),
                // Net du jour
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: (net >= 0 ? EmeraldPalette.emerald : Colors.redAccent).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: (net >= 0 ? EmeraldPalette.emerald : Colors.redAccent).withValues(alpha: 0.4)),
                  ),
                  child: Text(
                    '${net >= 0 ? '+' : ''}$net pts',
                    style: TextStyle(
                      color: net >= 0 ? EmeraldPalette.emeraldLight : Colors.redAccent,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const Divider(color: Colors.white12, height: 24),

            // ─── Bonus ───
            if (bonusEntries.isNotEmpty) ...[
              Text('✅ Bonus (${bonusEntries.length})', style: const TextStyle(color: EmeraldPalette.emeraldLight, fontSize: 13, fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              ...bonusEntries.map((h) => _HistoryRow(entry: h, isBonus: true)),
            ],

            // ─── Pénalités ───
            if (penaltyEntries.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text('⚠️ Pénalités (${penaltyEntries.length})', style: const TextStyle(color: Colors.redAccent, fontSize: 13, fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              ...penaltyEntries.map((h) => _HistoryRow(entry: h, isBonus: false)),
            ],

            if (history.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text("Rien à signaler aujourd'hui 🎉", style: TextStyle(color: Colors.white38, fontSize: 13)),
              ),

            // ─── Totaux ───
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: EmeraldPalette.surfaceLow,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _TotalChip(label: 'Bonus', value: '+$totalBonus', color: EmeraldPalette.emerald),
                  Container(width: 1, height: 28, color: EmeraldPalette.glassBorder),
                  _TotalChip(label: 'Pénalités', value: '-$totalPenalty', color: Colors.redAccent),
                  Container(width: 1, height: 28, color: EmeraldPalette.glassBorder),
                  _TotalChip(label: 'Solde', value: '$net', color: net >= 0 ? EmeraldPalette.gold : Colors.redAccent),
                ],
              ),
            ),

            // ─── Ajustement rapide ───
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: EmeraldPalette.emerald.withValues(alpha: 0.2),
                      foregroundColor: EmeraldPalette.emeraldLight,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.add_circle_rounded, size: 18),
                    label: const Text('Ajuster +', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                    onPressed: () => _showQuickAdjust(context, isBonus: true),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.redAccent.withValues(alpha: 0.2),
                      foregroundColor: Colors.redAccent,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.remove_circle_rounded, size: 18),
                    label: const Text('Ajuster -', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                    onPressed: () => _showQuickAdjust(context, isBonus: false),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showQuickAdjust(BuildContext context, {required bool isBonus}) {
    final reasonCtrl = TextEditingController(text: isBonus ? 'Bonus du soir' : 'Pénalité du soir');
    int amount = isBonus ? 10 : 5;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: EmeraldPalette.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(isBonus ? 'Ajouter un bonus' : 'Ajouter une pénalité', style: const TextStyle(color: EmeraldPalette.textPrimary, fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: reasonCtrl,
                style: const TextStyle(color: EmeraldPalette.textPrimary),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: EmeraldPalette.surfaceLow,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    onPressed: () => setDialogState(() { if (amount > 1) amount--; }),
                    icon: const Icon(Icons.remove_circle_outline, color: Colors.white54),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    decoration: BoxDecoration(
                      color: (isBonus ? EmeraldPalette.emerald : Colors.redAccent).withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text('$amount pts', style: TextStyle(color: isBonus ? EmeraldPalette.emeraldLight : Colors.redAccent, fontSize: 20, fontWeight: FontWeight.w800)),
                  ),
                  IconButton(
                    onPressed: () => setDialogState(() { if (amount < 50) amount++; }),
                    icon: const Icon(Icons.add_circle_outline, color: Colors.white54),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler', style: TextStyle(color: Colors.white54))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: isBonus ? EmeraldPalette.emerald : Colors.redAccent, foregroundColor: Colors.white),
              onPressed: () async {
                Navigator.pop(ctx);
                if (isBonus) {
                  await onAddBonus(amount, reasonCtrl.text.trim());
                } else {
                  await onAddPenalty(amount, reasonCtrl.text.trim());
                }
              },
              child: const Text('Valider', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Ligne d'historique dans le bilan ──────────────────────────
class _HistoryRow extends StatelessWidget {
  final HistoryEntry entry;
  final bool isBonus;

  const _HistoryRow({required this.entry, required this.isBonus});

  void _openPhoto(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: GestureDetector(
          onTap: () => Navigator.pop(ctx),
          child: InteractiveViewer(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.memory(
                base64Decode(entry.proofPhotoBase64!),
                fit: BoxFit.contain,
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final color = isBonus ? EmeraldPalette.emeraldLight : Colors.redAccent;
    final hasPhoto = entry.hasProofPhoto;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Icon(isBonus ? Icons.add_circle_rounded : Icons.remove_circle_rounded, color: color, size: 16),
          const SizedBox(width: 8),
          // 📸 Miniature photo IA si disponible
          if (hasPhoto)
            GestureDetector(
              onTap: () => _openPhoto(context),
              child: Container(
                margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: color.withValues(alpha: 0.5), width: 1),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: Image.memory(
                    base64Decode(entry.proofPhotoBase64!),
                    width: 36,
                    height: 36,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ),
          Expanded(
            child: Text(entry.reason, style: const TextStyle(color: Colors.white70, fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
          Text('${isBonus ? '+' : '-'}${entry.points}', style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

// ─── Chip total ────────────────────────────────────────────────
class _TotalChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _TotalChip({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(value, style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.w800)),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(color: EmeraldPalette.textMuted, fontSize: 10)),
      ],
    );
  }
}
