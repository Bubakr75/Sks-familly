// lib/screens/checklist_screen.dart
//
// Checklist du jour : l'enfant coche ses tâches ménagères et valide d'un coup.
// Le parent peut ajouter/modifier/supprimer des tâches.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/family_provider.dart';
import '../providers/pin_provider.dart';
import '../models/child_model.dart';
import '../models/chore_model.dart';
import '../config/emerald_theme.dart';

class ChecklistScreen extends StatefulWidget {
  const ChecklistScreen({super.key});

  @override
  State<ChecklistScreen> createState() => _ChecklistScreenState();
}

class _ChecklistScreenState extends State<ChecklistScreen> {
  final Set<String> _checked = {};
  String? _selectedChildId;

  @override
  Widget build(BuildContext context) {
    final fp = context.watch<FamilyProvider>();
    final pin = context.watch<PinProvider>();
    final isParent = pin.isParentMode;
    final children = fp.children;
    final chores = fp.chores.where((c) => c.isActive).toList();

    final selectedChild = _selectedChildId != null
        ? fp.getChild(_selectedChildId!)
        : (children.isNotEmpty ? children.first : null);

    return Scaffold(
      backgroundColor: EmeraldPalette.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text('Checklist du jour', style: TextStyle(color: EmeraldPalette.textPrimary, fontWeight: FontWeight.bold)),
        iconTheme: const IconThemeData(color: EmeraldPalette.textPrimary),
        actions: [
          if (isParent)
            IconButton(
              icon: const Icon(Icons.add_circle_rounded, color: EmeraldPalette.emerald, size: 28),
              onPressed: () => _showAddChoreDialog(context, fp),
            ),
        ],
      ),
      body: children.isEmpty
          ? const Center(child: Text('Aucun enfant enregistré', style: TextStyle(color: Colors.white54)))
          : Column(
              children: [
                // Sélecteur d'enfant
                if (children.length > 1)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: DropdownButtonFormField<String>(
                      value: _selectedChildId ?? children.first.id,
                      dropdownColor: EmeraldPalette.surface,
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: EmeraldPalette.surfaceLow,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                      ),
                      items: children.map((c) => DropdownMenuItem(
                        value: c.id,
                        child: Row(children: [
                          Text(c.avatar.isNotEmpty ? c.avatar : '👤', style: const TextStyle(fontSize: 18)),
                          const SizedBox(width: 8),
                          Text(c.name, style: const TextStyle(color: Colors.white)),
                          const Spacer(),
                          Text('${c.points} pts', style: const TextStyle(color: EmeraldPalette.emeraldLight, fontSize: 12)),
                        ]),
                      )).toList(),
                      onChanged: (v) => setState(() { _selectedChildId = v; _checked.clear(); }),
                    ),
                  ),

                // Compteur de points potentiels
                if (selectedChild != null)
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [Color(0xFFD4AF37), Color(0xFFB8860B)]),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Points à gagner', style: TextStyle(color: Color(0xFF051410), fontWeight: FontWeight.w600)),
                        Text(
                          '+${chores.where((c) => _checked.contains(c.id)).fold(0, (sum, c) => sum + c.points)} pts',
                          style: const TextStyle(color: Color(0xFF051410), fontSize: 20, fontWeight: FontWeight.w900),
                        ),
                      ],
                    ),
                  ),

                // Avertissement pénalité
                if (chores.isNotEmpty && _checked.length < chores.length && _selectedChildId != null)
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.redAccent.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.redAccent.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.warning_rounded, color: Colors.redAccent, size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '${chores.length - _checked.length} tâche(s) non faite(s) = -${chores.where((c) => !_checked.contains(c.id)).fold(0, (sum, c) => sum + (c.points ~/ 2).clamp(1, 10))} pts',
                            style: const TextStyle(color: Colors.redAccent, fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  ),

                // Liste des tâches (cases à cocher)
                Expanded(
                  child: chores.isEmpty
                      ? const Center(child: Text('Aucune tâche. Le parent peut en ajouter avec le bouton +', style: TextStyle(color: Colors.white38, fontSize: 13), textAlign: TextAlign.center))
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: chores.length,
                          itemBuilder: (context, index) {
                            final chore = chores[index];
                            final isChecked = _checked.contains(chore.id);
                            return _ChoreTile(
                              chore: chore,
                              isChecked: isChecked,
                              isParent: isParent,
                              onToggle: () => setState(() {
                                if (isChecked) {
                                  _checked.remove(chore.id);
                                } else {
                                  _checked.add(chore.id);
                                }
                                HapticFeedback.selectionClick();
                              }),
                              onDelete: isParent ? () => _confirmDeleteChore(context, fp, chore) : null,
                            );
                          },
                        ),
                ),

                // Bouton Valider
                if (_checked.isNotEmpty && selectedChild != null)
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: EmeraldPalette.emerald,
                          foregroundColor: const Color(0xFF051410),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          elevation: 6,
                        ),
                        onPressed: () => _validateChores(context, fp, selectedChild, chores),
                        icon: const Icon(Icons.check_circle_rounded, size: 24),
                        label: Text(
                          'Valider (${_checked.length} tâche${_checked.length > 1 ? 's' : ''})',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
    );
  }

  void _validateChores(BuildContext context, FamilyProvider fp, ChildModel child, List<ChoreModel> allChores) async {
    final completed = allChores.where((c) => _checked.contains(c.id)).toList();
    final isParent = context.read<PinProvider>().isParentMode;
    final messenger = ScaffoldMessenger.of(context);

    if (isParent) {
      // Mode parent : appliquer direct
      // ✅ Tâches cochées = bonus
      final completed = allChores.where((c) => _checked.contains(c.id)).toList();
      final total = await fp.validateChores(child.id, completed);

      // ⚠️ Pénalités intelligentes :
      // - Tâches individuelles non cochées → pénalité (brossage de dents, lit, etc.)
      // - Tâches partagées non cochées → pénalité SEULEMENT si PERSONNE dans la famille ne l'a faite aujourd'hui
      
      // 1. Récupérer toutes les tâches ménagères faites aujourd'hui par TOUTE la famille
      final today = DateTime.now();
      final todayStart = DateTime(today.year, today.month, today.day);
      final allFamilyChoresToday = fp.history
          .where((h) => h.date.isAfter(todayStart) && h.category == 'ménage')
          .toList();
      
      // 2. Vérifier quelles tâches partagées ont déjà été faites par quelqu'un
      final sharedChoresDoneByAnyone = <String>{};
      for (final entry in allFamilyChoresToday) {
        for (final chore in allChores.where((c) => !c.isIndividual)) {
          if (entry.reason.contains(chore.label)) {
            sharedChoresDoneByAnyone.add(chore.id);
          }
        }
      }

      // 3. Pénaliser uniquement ce qui mérite l'être
      int totalPenalty = 0;
      final penaltyLabels = <String>[];

      for (final chore in allChores) {
        if (_checked.contains(chore.id)) continue; // Tâche faite = pas de pénalité

        if (chore.isIndividual) {
          // Tâche individuelle non faite → toujours pénalité
          final penalty = (chore.points ~/ 2).clamp(1, 10);
          totalPenalty += penalty;
          penaltyLabels.add('${chore.emoji} ${chore.label}');
        } else if (!sharedChoresDoneByAnyone.contains(chore.id)) {
          // Tâche partagée non faite ET personne dans la famille ne l'a faite → pénalité
          final penalty = (chore.points ~/ 2).clamp(1, 10);
          totalPenalty += penalty;
          penaltyLabels.add('${chore.emoji} ${chore.label}');
        }
        // Si tâche partagée déjà faite par quelqu'un → PAS de pénalité (logique !)
      }

      if (totalPenalty > 0) {
        final labels = penaltyLabels.join(', ');
        await fp.addPoints(child.id, totalPenalty, '⚠️ Tâches non faites : $labels',
            category: 'ménage', isBonus: false);
      }

      if (context.mounted) {
        HapticFeedback.heavyImpact();
        final net = total - totalPenalty;
        messenger.showSnackBar(SnackBar(
          content: Text(net >= 0
              ? '🎉 ${child.name} : +$total bonus, -$totalPenalty pénalité = +$net pts'
              : '⚠️ ${child.name} : +$total bonus, -$totalPenalty pénalité = $net pts'),
          backgroundColor: net >= 0 ? EmeraldPalette.emerald : Colors.redAccent,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          duration: const Duration(seconds: 4),
        ));
        setState(() => _checked.clear());
      }
    } else {
      // Mode enfant : créer une demande SILENCIEUSE (pas de notif push)
      // Le parent verra la demande dans le badge cloche sans recevoir de notification
      final total = completed.fold(0, (sum, c) => sum + c.points);
      final labels = completed.map((c) => '${c.emoji} ${c.label}').join(', ');
      await fp.createRequest(
        type: 'chore_checklist',
        childId: child.id,
        requestedBy: child.name,
        text: '✅ Tâches du jour : $labels',
        amount: total,
      );
      if (context.mounted) {
        HapticFeedback.mediumImpact();
        messenger.showSnackBar(SnackBar(
          content: Text('Demande envoyée ! +$total pts en attente du parent.'),
          backgroundColor: const Color(0xFF7C4DFF),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ));
        setState(() => _checked.clear());
      }
    }
  }

  void _showAddChoreDialog(BuildContext context, FamilyProvider fp) {
    final labelCtrl = TextEditingController();
    final pointsCtrl = TextEditingController(text: '5');
    final allEmojis = ['✅', '🛏️', '🛌', '🍽️', '🪥', '📚', '🧸', '🗑️', '🐕', '🧹', '🚗', '👕', '🪴', '🍳', '🧽', '📦'];
    String selectedEmoji = '✅';
    bool isIndividual = true; // Par défaut : tâche individuelle

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return AlertDialog(
            backgroundColor: EmeraldPalette.surface,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            title: const Text('Nouvelle tâche', style: TextStyle(color: EmeraldPalette.textPrimary, fontWeight: FontWeight.bold)),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Wrap(
                    spacing: 6,
                    children: allEmojis.map((e) => GestureDetector(
                      onTap: () => setDialogState(() => selectedEmoji = e),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: selectedEmoji == e ? EmeraldPalette.emerald.withValues(alpha: 0.2) : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: selectedEmoji == e ? EmeraldPalette.emerald : Colors.transparent),
                        ),
                        child: Text(e, style: const TextStyle(fontSize: 22)),
                      ),
                    )).toList(),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: labelCtrl,
                    style: const TextStyle(color: EmeraldPalette.textPrimary),
                    decoration: InputDecoration(
                      labelText: 'Nom de la tâche',
                      labelStyle: const TextStyle(color: EmeraldPalette.textSecondary),
                      filled: true,
                      fillColor: EmeraldPalette.surfaceLow,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: pointsCtrl,
                    style: const TextStyle(color: EmeraldPalette.textPrimary),
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Points',
                      labelStyle: const TextStyle(color: EmeraldPalette.textSecondary),
                      filled: true,
                      fillColor: EmeraldPalette.surfaceLow,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Toggle Individuel / Partagé
                  StatefulBuilder(
                    builder: (ctx, setInner) => Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setInner(() => isIndividual = true),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color: isIndividual ? Colors.blue.withValues(alpha: 0.2) : Colors.white.withValues(alpha: 0.05),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: isIndividual ? Colors.blue : Colors.white12),
                              ),
                              child: Column(
                                children: [
                                  const Text('🔵', style: TextStyle(fontSize: 18)),
                                  const SizedBox(height: 2),
                                  const Text('Individuel', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                                  const Text('Pénalité si pas fait', style: TextStyle(color: Colors.white38, fontSize: 9)),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setInner(() => isIndividual = false),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color: !isIndividual ? Colors.amber.withValues(alpha: 0.2) : Colors.white.withValues(alpha: 0.05),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: !isIndividual ? Colors.amber : Colors.white12),
                              ),
                              child: Column(
                                children: [
                                  const Text('🟡', style: TextStyle(fontSize: 18)),
                                  const SizedBox(height: 2),
                                  const Text('Partagée', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                                  const Text('Pas de pénalité si un autre l\'a fait', style: TextStyle(color: Colors.white38, fontSize: 9)),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler', style: TextStyle(color: Colors.white54))),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: EmeraldPalette.emerald, foregroundColor: const Color(0xFF051410)),
                onPressed: () {
                  final label = labelCtrl.text.trim();
                  final points = int.tryParse(pointsCtrl.text.trim()) ?? 5;
                  if (label.isEmpty) return;
                  fp.addChore(label: label, points: points, emoji: selectedEmoji, isIndividual: isIndividual);
                  Navigator.pop(ctx);
                },
                child: const Text('Ajouter', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          );
        },
      ),
    );
  }

  void _confirmDeleteChore(BuildContext context, FamilyProvider fp, ChoreModel chore) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: EmeraldPalette.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Supprimer ?', style: TextStyle(color: EmeraldPalette.textPrimary)),
        content: Text('Supprimer "${chore.label}" ?', style: const TextStyle(color: EmeraldPalette.textSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler', style: TextStyle(color: Colors.white54))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
            onPressed: () { Navigator.pop(ctx); fp.deleteChore(chore.id); },
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
  }
}

class _ChoreTile extends StatelessWidget {
  final ChoreModel chore;
  final bool isChecked;
  final bool isParent;
  final VoidCallback onToggle;
  final VoidCallback? onDelete;

  const _ChoreTile({
    required this.chore,
    required this.isChecked,
    required this.isParent,
    required this.onToggle,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isChecked
            ? EmeraldPalette.emerald.withValues(alpha: 0.12)
            : EmeraldPalette.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isChecked ? EmeraldPalette.emerald.withValues(alpha: 0.4) : EmeraldPalette.glassBorder,
          width: isChecked ? 1.5 : 1,
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        leading: GestureDetector(
          onTap: onToggle,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 28, height: 28,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isChecked ? EmeraldPalette.emerald : Colors.transparent,
              border: Border.all(color: isChecked ? EmeraldPalette.emerald : Colors.white24, width: 2),
            ),
            child: isChecked ? const Icon(Icons.check, color: Color(0xFF051410), size: 18) : null,
          ),
        ),
        title: Row(
          children: [
            Text(chore.emoji, style: const TextStyle(fontSize: 20)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                chore.label,
                style: TextStyle(
                  color: isChecked ? EmeraldPalette.emeraldLight : EmeraldPalette.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  decoration: isChecked ? TextDecoration.lineThrough : null,
                ),
              ),
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: EmeraldPalette.gold.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: EmeraldPalette.gold.withValues(alpha: 0.3)),
              ),
              child: Text('+${chore.points}', style: const TextStyle(color: EmeraldPalette.gold, fontSize: 12, fontWeight: FontWeight.w700)),
            ),
            if (isParent && onDelete != null) ...[
              const SizedBox(width: 4),
              IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 18),
                onPressed: onDelete,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ],
        ),
        onTap: onToggle,
      ),
    );
  }
}
