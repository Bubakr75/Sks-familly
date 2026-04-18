import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/family_provider.dart';
import '../models/child_model.dart';
import '../models/punishment_lines.dart';
import '../widgets/animated_background.dart';
import '../widgets/glass_card.dart';

class BalanceScreen extends StatefulWidget {
  const BalanceScreen({super.key});

  @override
  State<BalanceScreen> createState() => _BalanceScreenState();
}

class _BalanceScreenState extends State<BalanceScreen> {
  final Set<String> _selectedIds = {};

  void _toggleChild(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else {
        _selectedIds.add(id);
      }
    });
  }

  // ─── Dialog : ajouter immunité à la sélection ────────────
  Future<void> _showAddImmunityDialog(FamilyProvider fp) async {
    int lines = 1;
    final descCtrl = TextEditingController(text: 'Accord parental');
    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          backgroundColor: const Color(0xFF1E1E2E),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Ajouter immunite', style: TextStyle(color: Colors.white)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${_selectedIds.length} enfant(s) selectionne(s)',
                style: const TextStyle(color: Colors.white54, fontSize: 13),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: descCtrl,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Raison',
                  labelStyle: const TextStyle(color: Colors.white54),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.white24),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.amberAccent),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    onPressed: lines > 1 ? () => setS(() => lines--) : null,
                    icon: const Icon(Icons.remove_circle, color: Colors.redAccent, size: 32),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.amberAccent.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '$lines',
                      style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold, fontSize: 28),
                    ),
                  ),
                  IconButton(
                    onPressed: () => setS(() => lines++),
                    icon: const Icon(Icons.add_circle, color: Colors.green, size: 32),
                  ),
                ],
              ),
              Text(
                '$lines ligne(s) d immunite par enfant',
                style: const TextStyle(color: Colors.amberAccent, fontSize: 13),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Annuler', style: TextStyle(color: Colors.white54)),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amberAccent,
                foregroundColor: Colors.black,
              ),
              icon: const Icon(Icons.shield, size: 16),
              label: Text('Accorder (${_selectedIds.length})'),
              onPressed: () async {
                final reason = descCtrl.text.trim().isEmpty
                    ? 'Accord parental'
                    : descCtrl.text.trim();
                Navigator.pop(ctx);
                for (final id in _selectedIds) {
                  await fp.addImmunity(id, reason, lines);
                }
                if (mounted) {
                  setState(() => _selectedIds.clear());
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('+$lines ligne(s) d immunite accordee(s)'),
                      backgroundColor: Colors.amberAccent.withOpacity(0.8),
                    ),
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
    descCtrl.dispose();
  }

  // ─── Dialog : ajouter punition à la sélection ───────────
  Future<void> _showAddPunishmentDialog(FamilyProvider fp) async {
    int lines = 1;
    final descCtrl = TextEditingController();
    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          backgroundColor: const Color(0xFF1E1E2E),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Ajouter punition', style: TextStyle(color: Colors.white)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${_selectedIds.length} enfant(s) selectionne(s)',
                style: const TextStyle(color: Colors.white54, fontSize: 13),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: descCtrl,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Description',
                  labelStyle: const TextStyle(color: Colors.white54),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.white24),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.redAccent),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    onPressed: lines > 1 ? () => setS(() => lines--) : null,
                    icon: const Icon(Icons.remove_circle, color: Colors.redAccent, size: 32),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.redAccent.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '$lines',
                      style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold, fontSize: 28),
                    ),
                  ),
                  IconButton(
                    onPressed: () => setS(() => lines++),
                    icon: const Icon(Icons.add_circle, color: Colors.green, size: 32),
                  ),
                ],
              ),
              Text(
                '$lines ligne(s) de punition par enfant',
                style: const TextStyle(color: Colors.redAccent, fontSize: 13),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Annuler', style: TextStyle(color: Colors.white54)),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
              ),
              icon: const Icon(Icons.edit_document, size: 16),
              label: Text('Punir (${_selectedIds.length})'),
              onPressed: () async {
                final desc = descCtrl.text.trim();
                if (desc.isEmpty) return;
                Navigator.pop(ctx);
                for (final id in _selectedIds) {
                  await fp.addPunishment(id, desc, lines);
                }
                if (mounted) {
                  setState(() => _selectedIds.clear());
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Punition ajoutee a ${_selectedIds.length} enfant(s)'),
                      backgroundColor: Colors.redAccent.withOpacity(0.8),
                    ),
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
    descCtrl.dispose();
  }

  // ─── Dialog : utiliser immunité sur une punition ─────────
  Future<void> _showUseImmunityDialog(
      FamilyProvider fp, ChildModel child) async {
    final activePunishments = fp.punishments
        .where((p) => p.childId == child.id && !p.isCompleted)
        .toList();
    final immunities = fp.getUsableImmunitiesForChild(child.id);

    if (activePunishments.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Aucune punition active pour cet enfant')),
      );
      return;
    }
    if (immunities.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Aucune immunite disponible')),
      );
      return;
    }

    PunishmentLines? selectedPunishment;
    String? selectedImmunityId;
    int linesToUse = 1;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          backgroundColor: const Color(0xFF1E1E2E),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            'Utiliser immunite pour ${child.name}',
            style: const TextStyle(color: Colors.white),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Choisir une punition :', style: TextStyle(color: Colors.white70, fontSize: 13)),
                const SizedBox(height: 8),
                ...activePunishments.map((p) {
                  final remaining = p.totalLines - p.completedLines;
                  return GestureDetector(
                    onTap: () => setS(() => selectedPunishment = p),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: selectedPunishment?.id == p.id
                            ? Colors.redAccent.withOpacity(0.3)
                            : Colors.white10,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: selectedPunishment?.id == p.id
                              ? Colors.redAccent
                              : Colors.white24,
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.edit_document, color: Colors.redAccent, size: 16),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              p.text,
                              style: const TextStyle(color: Colors.white, fontSize: 13),
                            ),
                          ),
                          Text(
                            '$remaining lignes',
                            style: const TextStyle(color: Colors.redAccent, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
                const SizedBox(height: 12),
                const Text('Choisir une immunite :', style: TextStyle(color: Colors.white70, fontSize: 13)),
                const SizedBox(height: 8),
                ...immunities.map((im) => GestureDetector(
                  onTap: () => setS(() => selectedImmunityId = im.id),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: selectedImmunityId == im.id
                          ? Colors.amberAccent.withOpacity(0.3)
                          : Colors.white10,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: selectedImmunityId == im.id
                            ? Colors.amberAccent
                            : Colors.white24,
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.shield, color: Colors.amberAccent, size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            im.reason,
                            style: const TextStyle(color: Colors.white, fontSize: 13),
                          ),
                        ),
                        Text(
                          '${im.availableLines} dispo',
                          style: const TextStyle(color: Colors.amberAccent, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                )),
                const SizedBox(height: 12),
                if (selectedPunishment != null && selectedImmunityId != null) ...[
                  const Text('Lignes a utiliser :', style: TextStyle(color: Colors.white70, fontSize: 13)),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        onPressed: linesToUse > 1 ? () => setS(() => linesToUse--) : null,
                        icon: const Icon(Icons.remove_circle, color: Colors.redAccent),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.amberAccent.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '$linesToUse',
                          style: const TextStyle(
                            color: Colors.white, fontWeight: FontWeight.bold, fontSize: 24),
                        ),
                      ),
                      IconButton(
                        onPressed: () => setS(() => linesToUse++),
                        icon: const Icon(Icons.add_circle, color: Colors.green),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Annuler', style: TextStyle(color: Colors.white54)),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amberAccent,
                foregroundColor: Colors.black,
              ),
              icon: const Icon(Icons.shield, size: 16),
              label: const Text('Utiliser'),
              onPressed: selectedPunishment != null && selectedImmunityId != null
                  ? () async {
                      Navigator.pop(ctx);
                      await fp.useImmunityOnPunishment(
                          selectedImmunityId!, selectedPunishment!.id, linesToUse);
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                                '$linesToUse ligne(s) d immunite utilisee(s) sur "${selectedPunishment!.text}"'),
                            backgroundColor: Colors.green.withOpacity(0.8),
                          ),
                        );
                      }
                    }
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final fp = context.watch<FamilyProvider>();
    final children = fp.children;

    return AnimatedBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          title: const Text('Punitions vs Immunites', style: TextStyle(color: Colors.white)),
          actions: [
            if (_selectedIds.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.cyanAccent.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.cyanAccent),
                    ),
                    child: Text(
                      '${_selectedIds.length} selectionne(s)',
                      style: const TextStyle(color: Colors.cyanAccent, fontSize: 12),
                    ),
                  ),
                ),
              ),
          ],
        ),
        body: children.isEmpty
            ? const Center(
                child: Text('Aucun enfant enregistre',
                    style: TextStyle(color: Colors.white54)),
              )
            : Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    child: Row(
                      children: const [
                        Icon(Icons.touch_app, color: Colors.white38, size: 15),
                        SizedBox(width: 6),
                        Text(
                          'Appuie sur une carte pour selectionner',
                          style: TextStyle(color: Colors.white38, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 100),
                      itemCount: children.length,
                      itemBuilder: (_, i) => _buildChildCard(children[i], fp),
                    ),
                  ),
                ],
              ),
        bottomNavigationBar: _selectedIds.isNotEmpty
            ? Container(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
                decoration: BoxDecoration(
                  color: const Color(0xFF0D1B2E).withOpacity(0.97),
                  border: Border(
                    top: BorderSide(color: Colors.white.withOpacity(0.1)),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.redAccent,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                        ),
                        icon: const Icon(Icons.edit_document),
                        label: const Text('Punir', style: TextStyle(fontWeight: FontWeight.bold)),
                        onPressed: () => _showAddPunishmentDialog(fp),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.amberAccent,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                        ),
                        icon: const Icon(Icons.shield),
                        label: const Text('Immunite', style: TextStyle(fontWeight: FontWeight.bold)),
                        onPressed: () => _showAddImmunityDialog(fp),
                      ),
                    ),
                  ],
                ),
              )
            : null,
      ),
    );
  }

  // ─── Carte enfant ─────────────────────────────────────────
  Widget _buildChildCard(ChildModel child, FamilyProvider fp) {
    final isSelected = _selectedIds.contains(child.id);
    final activePunishments = fp.punishments
        .where((p) => p.childId == child.id && !p.isCompleted)
        .toList();
    final punishmentLines = activePunishments.fold<int>(
        0, (sum, p) => sum + (p.totalLines - p.completedLines));
    final immunityLines = fp.getTotalAvailableImmunity(child.id);
    final immunities = fp.getImmunitiesForChild(child.id);
    final balance = immunityLines - punishmentLines;

    return GestureDetector(
      onTap: () => _toggleChild(child.id),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? Colors.cyanAccent : Colors.transparent,
            width: 2,
          ),
        ),
        child: GlassCard(
          child: Column(
            children: [
              // En-tête
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: Colors.cyanAccent.withOpacity(0.2),
                    child: Text(
                      child.avatar.isNotEmpty ? child.avatar : child.name[0].toUpperCase(),
                      style: const TextStyle(fontSize: 20),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      child.name,
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ),
                  if (isSelected)
                    const Icon(Icons.check_circle, color: Colors.cyanAccent, size: 22),
                  const SizedBox(width: 8),
                  // Badge balance
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: balance >= 0
                          ? Colors.green.withOpacity(0.2)
                          : Colors.red.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      balance >= 0 ? '+$balance' : '$balance',
                      style: TextStyle(
                        color: balance >= 0 ? Colors.greenAccent : Colors.redAccent,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Compteurs punitions / immunités
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.redAccent.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.redAccent.withOpacity(0.3)),
                      ),
                      child: Column(
                        children: [
                          const Icon(Icons.edit_document, color: Colors.redAccent, size: 22),
                          const SizedBox(height: 4),
                          Text(
                            '$punishmentLines',
                            style: const TextStyle(
                                color: Colors.redAccent,
                                fontWeight: FontWeight.bold,
                                fontSize: 22),
                          ),
                          const Text('lignes punition',
                              style: TextStyle(color: Colors.white54, fontSize: 11)),
                          Text(
                            '${activePunishments.length} punition(s)',
                            style: const TextStyle(color: Colors.white38, fontSize: 10),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Text(
                      balance >= 0 ? '😊' : '😰',
                      style: const TextStyle(fontSize: 24),
                    ),
                  ),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.amberAccent.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.amberAccent.withOpacity(0.3)),
                      ),
                      child: Column(
                        children: [
                          const Icon(Icons.shield, color: Colors.amberAccent, size: 22),
                          const SizedBox(height: 4),
                          Text(
                            '$immunityLines',
                            style: const TextStyle(
                                color: Colors.amberAccent,
                                fontWeight: FontWeight.bold,
                                fontSize: 22),
                          ),
                          const Text('lignes immunite',
                              style: TextStyle(color: Colors.white54, fontSize: 11)),
                          Text(
                            '${immunities.length} immunite(s)',
                            style: const TextStyle(color: Colors.white38, fontSize: 10),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              // Barre de progression
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: punishmentLines + immunityLines > 0
                      ? immunityLines / (punishmentLines + immunityLines)
                      : 1.0,
                  backgroundColor: Colors.redAccent.withOpacity(0.3),
                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.amberAccent),
                  minHeight: 6,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Punitions', style: TextStyle(color: Colors.redAccent, fontSize: 10)),
                  Text(
                    balance >= 0 ? 'En avance !' : 'Derriere !',
                    style: TextStyle(
                      color: balance >= 0 ? Colors.greenAccent : Colors.orangeAccent,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Text('Immunites', style: TextStyle(color: Colors.amberAccent, fontSize: 10)),
                ],
              ),
              // Bouton utiliser immunité (visible quand carte sélectionnée)
              if (isSelected && punishmentLines > 0 && immunityLines > 0) ...[
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.amberAccent,
                      side: const BorderSide(color: Colors.amberAccent),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: const Icon(Icons.shield, size: 16),
                    label: const Text('Utiliser immunite sur une punition'),
                    onPressed: () => _showUseImmunityDialog(fp, child),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
