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
    final total = await fp.validateChores(child.id, completed);

    if (context.mounted) {
      HapticFeedback.heavyImpact();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('🎉 +$total pts bonus pour ${child.name} !'),
        backgroundColor: EmeraldPalette.emerald,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ));
      setState(() => _checked.clear());
    }
  }

  void _showAddChoreDialog(BuildContext context, FamilyProvider fp) {
    final labelCtrl = TextEditingController();
    final pointsCtrl = TextEditingController(text: '5');
    final allEmojis = ['✅', '🛏️', '🛌', '🍽️', '🪥', '📚', '🧸', '🗑️', '🐕', '🧹', '🚗', '👕', '🪴', '🍳', '🧽', '📦'];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          String selectedEmoji = '✅';
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
                  fp.addChore(label: label, points: points, emoji: selectedEmoji);
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
