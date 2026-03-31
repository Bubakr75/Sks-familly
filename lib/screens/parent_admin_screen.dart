import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/family_provider.dart';
import '../providers/pin_provider.dart';
import '../models/child_model.dart';
import '../models/history_entry.dart';
import '../models/punishment_lines.dart';
import '../models/immunity_lines.dart';
import '../widgets/animated_background.dart';
import '../widgets/glass_card.dart';
import '../widgets/glass_widgets.dart';
import '../widgets/tv_focus_wrapper.dart';

class ParentAdminScreen extends StatefulWidget {
  const ParentAdminScreen({super.key});

  @override
  State<ParentAdminScreen> createState() => _ParentAdminScreenState();
}

class _ParentAdminScreenState extends State<ParentAdminScreen>
    with TickerProviderStateMixin {
  late AnimationController _animCtrl;
  late Animation<double> _fade;

  String? _selectedChildId;
  int _tabIndex = 0;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
    _fade = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _animCtrl.forward();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<FamilyProvider>();
      final children = provider.sortedChildren;
      if (children.isNotEmpty && _selectedChildId == null) {
        setState(() => _selectedChildId = children.first.id);
      }
    });
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  // ── Confirmation simple ──
  Future<bool> _confirm(String title, String body) async {
    return await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0D1B2A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(title, style: const TextStyle(color: Colors.white)),
        content: Text(body, style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler', style: TextStyle(color: Colors.white54))),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF6B6B), foregroundColor: Colors.white),
            child: const Text('Confirmer'),
          ),
        ],
      ),
    ) ?? false;
  }

  // ── Double confirmation ──
  Future<bool> _doubleConfirm(String title, String body) async {
    final first = await _confirm(title, body);
    if (!first) return false;
    return await _confirm('⚠️ Dernière confirmation', 'Cette action est irréversible. Continuer ?');
  }

  void _snack(String msg, {Color color = const Color(0xFF4CAF50)}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(color: Colors.white)),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  String _formatDate(DateTime d) => '${d.day}/${d.month}/${d.year}';

  // ── Voir une photo en plein écran ──
  void _showFullPhoto(String base64) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.black,
        child: Stack(
          children: [
            InteractiveViewer(child: Image.memory(base64Decode(base64))),
            Positioned(top: 8, right: 8, child: IconButton(onPressed: () => Navigator.pop(ctx), icon: const Icon(Icons.close, color: Colors.white))),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pinProvider = context.read<PinProvider>();
    if (!pinProvider.canPerformParentAction()) {
      return AnimatedBackground(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: Center(
            child: GlassCard(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('🔒', style: TextStyle(fontSize: 48)),
                    const SizedBox(height: 12),
                    const Text('Accès refusé', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    const Text('Mode parent requis', style: TextStyle(color: Colors.white54)),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00E5FF), foregroundColor: Colors.black),
                      child: const Text('Retour'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    return AnimatedBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Consumer<FamilyProvider>(
          builder: (ctx, provider, _) {
            final children = provider.sortedChildren;
            final selectedChild = _selectedChildId != null ? provider.getChild(_selectedChildId!) : null;

            return SafeArea(
              child: FadeTransition(
                opacity: _fade,
                child: Column(
                  children: [
                    // ── Header ──
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                      child: Row(
                        children: [
                          IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white70)),
                          const Expanded(child: NeonText(text: '⚙️ Administration', fontSize: 20, color: Color(0xFF00E5FF))),
                          // Menu actions bulk
                          PopupMenuButton<String>(
                            icon: const Icon(Icons.more_vert, color: Colors.white70),
                            color: const Color(0xFF0D1B2A),
                            onSelected: (v) => _handleBulkAction(v, provider, selectedChild),
                            itemBuilder: (_) => [
                              const PopupMenuItem(value: 'clear_history', child: Text('🗑️ Vider l\'historique', style: TextStyle(color: Colors.white70))),
                              const PopupMenuItem(value: 'reset_points', child: Text('🔄 Réinitialiser les points', style: TextStyle(color: Colors.white70))),
                              const PopupMenuItem(value: 'clear_punishments', child: Text('📋 Vider les punitions', style: TextStyle(color: Colors.white70))),
                              const PopupMenuItem(value: 'clear_immunities', child: Text('🛡️ Vider les immunités', style: TextStyle(color: Colors.white70))),
                              const PopupMenuDivider(),
                              const PopupMenuItem(value: 'full_reset', child: Text('💣 Reset total', style: TextStyle(color: Color(0xFFFF6B6B)))),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // ── Sélecteur enfant ──
                    if (children.length > 1)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: children.map((c) {
                              final selected = c.id == _selectedChildId;
                              return GestureDetector(
                                onTap: () => setState(() => _selectedChildId = c.id),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  margin: const EdgeInsets.only(right: 8),
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(20),
                                    color: selected ? const Color(0xFF00E5FF).withOpacity(0.15) : Colors.white.withOpacity(0.05),
                                    border: Border.all(color: selected ? const Color(0xFF00E5FF) : Colors.white24),
                                  ),
                                  child: Text(c.name, style: TextStyle(color: selected ? const Color(0xFF00E5FF) : Colors.white70, fontWeight: selected ? FontWeight.bold : FontWeight.normal)),
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ),

                    // ── Onglets ──
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      child: Row(
                        children: [
                          _tabBtn('📜 Historique', 0, _getHistoryCount(provider)),
                          const SizedBox(width: 8),
                          _tabBtn('📋 Punitions', 1, _getPunishmentsCount(provider)),
                          const SizedBox(width: 8),
                          _tabBtn('🛡️ Immunités', 2, _getImmunitiesCount(provider)),
                        ],
                      ),
                    ),

                    // ── Contenu ──
                    Expanded(
                      child: _tabIndex == 0
                          ? _buildHistoryTab(provider)
                          : _tabIndex == 1
                              ? _buildPunishmentsTab(provider)
                              : _buildImmunitiesTab(provider),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _tabBtn(String label, int index, int count) {
    final selected = _tabIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _tabIndex = index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: selected ? const Color(0xFF00E5FF).withOpacity(0.15) : Colors.white.withOpacity(0.04),
            border: Border.all(color: selected ? const Color(0xFF00E5FF) : Colors.white12),
          ),
          child: Column(
            children: [
              Text(label, style: TextStyle(color: selected ? const Color(0xFF00E5FF) : Colors.white54, fontSize: 12, fontWeight: selected ? FontWeight.bold : FontWeight.normal)),
              if (count > 0) Text('$count', style: TextStyle(color: selected ? const Color(0xFF00E5FF) : Colors.white38, fontSize: 11)),
            ],
          ),
        ),
      ),
    );
  }

  int _getHistoryCount(FamilyProvider p) => _selectedChildId == null ? 0 : p.history.where((h) => h.childId == _selectedChildId).length;
  int _getPunishmentsCount(FamilyProvider p) => _selectedChildId == null ? 0 : p.getPunishmentsForChild(_selectedChildId!).length;
  int _getImmunitiesCount(FamilyProvider p) => _selectedChildId == null ? 0 : p.getImmunitiesForChild(_selectedChildId!).length;

  // ── TAB HISTORIQUE ──
  Widget _buildHistoryTab(FamilyProvider provider) {
    if (_selectedChildId == null) return const Center(child: Text('Sélectionne un enfant', style: TextStyle(color: Colors.white54)));
    final entries = provider.history
        .where((h) => h.childId == _selectedChildId)
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));

    if (entries.isEmpty) return const Center(child: Text('Aucun historique', style: TextStyle(color: Colors.white54)));

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: entries.length,
      itemBuilder: (ctx, i) {
        final entry = entries[i];
        final isBonus = entry.points >= 0;
        final color = isBonus ? const Color(0xFF4CAF50) : const Color(0xFFFF6B6B);
        return Dismissible(
          key: Key(entry.id),
          direction: DismissDirection.endToStart,
          background: Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 16),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), color: const Color(0xFFFF6B6B).withOpacity(0.2)),
            child: const Icon(Icons.delete_outline, color: Color(0xFFFF6B6B)),
          ),
          confirmDismiss: (_) => _confirm('Supprimer cette entrée ?', entry.description),
          onDismissed: (_) {
            provider.deleteHistoryEntry(entry.id);
            _snack('Entrée supprimée', color: const Color(0xFFFF6B6B));
          },
          child: Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              color: Colors.white.withOpacity(0.03),
              border: Border.all(color: color.withOpacity(0.2)),
            ),
            child: Row(
              children: [
                Text(entry.emoji.isNotEmpty ? entry.emoji : (isBonus ? '⭐' : '⚠️'), style: const TextStyle(fontSize: 22)),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(entry.description, style: const TextStyle(color: Colors.white, fontSize: 14), maxLines: 2, overflow: TextOverflow.ellipsis),
                      Text(_formatDate(entry.date), style: const TextStyle(color: Colors.white38, fontSize: 11)),
                    ],
                  ),
                ),
                Text('${entry.points >= 0 ? '+' : ''}${entry.points}', style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 15)),
                IconButton(
                  onPressed: () async {
                    final ok = await _confirm('Modifier cette entrée ?', 'L\'entrée sera supprimée et recréée.');
                    if (!ok || !mounted) return;
                    _showEditEntry(entry, provider);
                  },
                  icon: const Icon(Icons.edit_outlined, color: Colors.white38, size: 18),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showEditEntry(HistoryEntry entry, FamilyProvider provider) {
    final descCtrl = TextEditingController(text: entry.description);
    final pointsCtrl = TextEditingController(text: '${entry.points}');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0D1B2A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Modifier l\'entrée', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: descCtrl,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Description',
                labelStyle: const TextStyle(color: Colors.white54),
                filled: true,
                fillColor: Colors.white.withOpacity(0.05),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: pointsCtrl,
              keyboardType: const TextInputType.numberWithOptions(signed: true),
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Points',
                labelStyle: const TextStyle(color: Colors.white54),
                filled: true,
                fillColor: Colors.white.withOpacity(0.05),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler', style: TextStyle(color: Colors.white54))),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              provider.deleteHistoryEntry(entry.id);
              provider.addPoints(
                childId: entry.childId,
                points: int.tryParse(pointsCtrl.text) ?? entry.points,
                description: descCtrl.text.trim().isEmpty ? entry.description : descCtrl.text.trim(),
                emoji: entry.emoji,
                category: entry.category,
              );
              _snack('Entrée mise à jour');
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00E5FF), foregroundColor: Colors.black),
            child: const Text('Sauvegarder'),
          ),
        ],
      ),
    );
  }

  // ── TAB PUNITIONS ──
  Widget _buildPunishmentsTab(FamilyProvider provider) {
    if (_selectedChildId == null) return const Center(child: Text('Sélectionne un enfant', style: TextStyle(color: Colors.white54)));
    final punishments = provider.getPunishmentsForChild(_selectedChildId!)
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    if (punishments.isEmpty) return const Center(child: Text('Aucune punition', style: TextStyle(color: Colors.white54)));

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: punishments.length,
      itemBuilder: (ctx, i) {
        final p = punishments[i];
        final color = p.isCompleted ? const Color(0xFF4CAF50) : const Color(0xFFFF6B6B);
        return Dismissible(
          key: Key(p.id),
          direction: DismissDirection.endToStart,
          background: Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 16),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), color: const Color(0xFFFF6B6B).withOpacity(0.2)),
            child: const Icon(Icons.delete_outline, color: Color(0xFFFF6B6B)),
          ),
          confirmDismiss: (_) => _confirm('Supprimer la punition ?', p.text),
          onDismissed: (_) {
            provider.removePunishment(p.id);
            _snack('Punition supprimée', color: const Color(0xFFFF6B6B));
          },
          child: Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              color: Colors.white.withOpacity(0.03),
              border: Border.all(color: color.withOpacity(0.2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: Text(p.text, style: const TextStyle(color: Colors.white, fontSize: 14), maxLines: 2, overflow: TextOverflow.ellipsis)),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), color: color.withOpacity(0.15)),
                      child: Text(p.isCompleted ? '✅ Fait' : '🔴 En cours', style: TextStyle(color: color, fontSize: 11)),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(value: p.progress, backgroundColor: Colors.white12, valueColor: AlwaysStoppedAnimation(color), minHeight: 6),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text('${p.completedLines}/${p.totalLines}', style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Text(_formatDate(p.createdAt), style: const TextStyle(color: Colors.white38, fontSize: 11)),
                    const Spacer(),
                    if (!p.isCompleted)
                      GestureDetector(
                        onTap: () => _showEditPunishment(p, provider),
                        child: const Text('Modifier', style: TextStyle(color: Color(0xFF00E5FF), fontSize: 12)),
                      ),
                    if (!p.isCompleted) ...[
                      const SizedBox(width: 12),
                      GestureDetector(
                        onTap: () async {
                          final ok = await _confirm('Marquer comme terminé ?', p.text);
                          if (ok) {
                            provider.completePunishment(p.id);
                            _snack('Punition terminée ✅');
                          }
                        },
                        child: const Text('Terminer', style: TextStyle(color: Color(0xFF4CAF50), fontSize: 12)),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showEditPunishment(PunishmentLines p, FamilyProvider provider) {
    final addCtrl = TextEditingController(text: '1');
    int toAdd = 1;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialog) => AlertDialog(
          backgroundColor: const Color(0xFF0D1B2A),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Modifier la progression', style: TextStyle(color: Colors.white)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(p.text, style: const TextStyle(color: Colors.white70, fontSize: 13)),
              const SizedBox(height: 12),
              Text('${p.completedLines}/${p.totalLines} lignes complétées', style: const TextStyle(color: Colors.white54, fontSize: 12)),
              const SizedBox(height: 12),
              const Text('Ajouter des lignes :', style: TextStyle(color: Colors.white70, fontSize: 13)),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: addCtrl,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                      decoration: InputDecoration(filled: true, fillColor: Colors.white.withOpacity(0.07), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none)),
                      onChanged: (v) => setDialog(() => toAdd = int.tryParse(v) ?? toAdd),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Column(children: [
                    IconButton(onPressed: () { final v = (int.tryParse(addCtrl.text) ?? toAdd) + 1; addCtrl.text = '$v'; setDialog(() => toAdd = v); }, icon: const Icon(Icons.keyboard_arrow_up, color: Colors.white70)),
                    IconButton(onPressed: () { final v = (int.tryParse(addCtrl.text) ?? toAdd) - 1; if (v >= 1) { addCtrl.text = '$v'; setDialog(() => toAdd = v); } }, icon: const Icon(Icons.keyboard_arrow_down, color: Colors.white70)),
                  ]),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler', style: TextStyle(color: Colors.white54))),
            ElevatedButton(
              onPressed: () {
                final finalAdd = int.tryParse(addCtrl.text) ?? toAdd;
                if (finalAdd > 0) {
                  provider.updatePunishmentProgress(p.id, finalAdd);
                  Navigator.pop(ctx);
                  _snack('Progression mise à jour');
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4CAF50), foregroundColor: Colors.white),
              child: const Text('Valider'),
            ),
          ],
        ),
      ),
    );
  }

  // ── TAB IMMUNITÉS ──
  Widget _buildImmunitiesTab(FamilyProvider provider) {
    if (_selectedChildId == null) return const Center(child: Text('Sélectionne un enfant', style: TextStyle(color: Colors.white54)));
    final immunities = provider.getImmunitiesForChild(_selectedChildId!)
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    if (immunities.isEmpty) return const Center(child: Text('Aucune immunité', style: TextStyle(color: Colors.white54)));

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: immunities.length,
      itemBuilder: (ctx, i) {
        final imm = immunities[i];
        final color = imm.isUsable ? const Color(0xFF9C27B0) : Colors.white38;
        return Dismissible(
          key: Key(imm.id),
          direction: DismissDirection.endToStart,
          background: Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 16),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), color: const Color(0xFFFF6B6B).withOpacity(0.2)),
            child: const Icon(Icons.delete_outline, color: Color(0xFFFF6B6B)),
          ),
          confirmDismiss: (_) => _confirm('Supprimer l\'immunité ?', imm.reason),
          onDismissed: (_) {
            provider.removeImmunity(imm.id);
            _snack('Immunité supprimée', color: const Color(0xFFFF6B6B));
          },
          child: Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              color: Colors.white.withOpacity(0.03),
              border: Border.all(color: color.withOpacity(0.2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text('🛡️', style: TextStyle(fontSize: 18)),
                    const SizedBox(width: 8),
                    Expanded(child: Text(imm.reason, style: const TextStyle(color: Colors.white, fontSize: 14), maxLines: 2, overflow: TextOverflow.ellipsis)),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), color: color.withOpacity(0.15)),
                      child: Text(imm.statusLabel, style: TextStyle(color: color, fontSize: 11)),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _miniChip('Total', '${imm.lines}', const Color(0xFF9C27B0)),
                    const SizedBox(width: 8),
                    _miniChip('Utilisées', '${imm.usedLines}', const Color(0xFFFF6B6B)),
                    const SizedBox(width: 8),
                    _miniChip('Disponibles', '${imm.availableLines}', const Color(0xFF4CAF50)),
                    const Spacer(),
                    if (!imm.isUsable && !imm.isExpired)
                      GestureDetector(
                        onTap: () async {
                          final ok = await _confirm('Réactiver ?', 'Réinitialiser les lignes utilisées ?');
                          if (ok) {
                            provider.reactivateImmunity(imm.id);
                            _snack('Immunité réactivée 🛡️');
                          }
                        },
                        child: const Text('Réactiver', style: TextStyle(color: Color(0xFF00E5FF), fontSize: 12)),
                      ),
                  ],
                ),
                if (imm.expiresAt != null) ...[
                  const SizedBox(height: 4),
                  Text(imm.expiresLabel, style: const TextStyle(color: Colors.white38, fontSize: 11)),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _miniChip(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), color: color.withOpacity(0.1)),
      child: Text('$label: $value', style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
    );
  }

  // ── Actions bulk ──
  void _handleBulkAction(String action, FamilyProvider provider, ChildModel? child) async {
    if (_selectedChildId == null && action != 'full_reset') {
      _snack('Sélectionne d\'abord un enfant', color: const Color(0xFFFF6B6B));
      return;
    }
    switch (action) {
      case 'clear_history':
        if (await _doubleConfirm('Vider l\'historique', 'Supprimer tout l\'historique de ${child?.name ?? '?'} ?')) {
          provider.clearChildHistory(_selectedChildId!);
          _snack('Historique vidé');
        }
        break;
      case 'reset_points':
        if (await _doubleConfirm('Réinitialiser les points', 'Remettre à zéro les points de ${child?.name ?? '?'} ?')) {
          provider.resetChildPoints(_selectedChildId!);
          _snack('Points réinitialisés');
        }
        break;
      case 'clear_punishments':
        if (await _doubleConfirm('Vider les punitions', 'Supprimer toutes les punitions de ${child?.name ?? '?'} ?')) {
          provider.clearChildPunishments(_selectedChildId!);
          _snack('Punitions supprimées');
        }
        break;
      case 'clear_immunities':
        if (await _doubleConfirm('Vider les immunités', 'Supprimer toutes les immunités de ${child?.name ?? '?'} ?')) {
          provider.clearChildImmunities(_selectedChildId!);
          _snack('Immunités supprimées');
        }
        break;
      case 'full_reset':
        if (await _doubleConfirm('💣 Reset TOTAL', 'Effacer TOUTES les données de TOUS les enfants ? Action irréversible.')) {
          provider.resetAllData();
          _snack('Reset total effectué', color: const Color(0xFFFF6B6B));
        }
        break;
    }
  }
}
