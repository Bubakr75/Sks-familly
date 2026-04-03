// lib/screens/punishment_lines_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/family_provider.dart';
import '../models/punishment_lines.dart';
import '../models/immunity_lines.dart';
import '../models/child_model.dart';
import '../widgets/glass_card.dart';
import '../widgets/animated_background.dart';

class PunishmentLinesScreen extends StatefulWidget {
  const PunishmentLinesScreen({super.key});

  @override
  State<PunishmentLinesScreen> createState() => _PunishmentLinesScreenState();
}

class _PunishmentLinesScreenState extends State<PunishmentLinesScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnim;
  String? _selectedChildId;
  bool _showAddForm = false;
  final TextEditingController _descController = TextEditingController();
  final TextEditingController _linesController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _fadeAnim = CurvedAnimation(parent: _controller, curve: Curves.easeIn);
    _controller.forward();

    // ✅ CORRECTIF 1 : initialiser _selectedChildId dès que le widget est monté
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final fp = context.read<FamilyProvider>();
      if (fp.children.isNotEmpty && _selectedChildId == null) {
        setState(() => _selectedChildId = fp.children.first.id);
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _descController.dispose();
    _linesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<FamilyProvider>(
      builder: (context, fp, _) {
        final children = fp.children;

        // ✅ CORRECTIF 2 : garantir que _selectedChildId est toujours renseigné
        if (children.isNotEmpty && _selectedChildId == null) {
          _selectedChildId = children.first.id;
        }

        final child = _selectedChildId != null
            ? fp.children.firstWhere(
                (c) => c.id == _selectedChildId,
                orElse: () => children.first,
              )
            : (children.isNotEmpty ? children.first : null);

        if (children.isEmpty) {
          return AnimatedBackground(
            child: Scaffold(
              backgroundColor: Colors.transparent,
              appBar: AppBar(
                backgroundColor: Colors.transparent,
                title: const Text('Punitions',
                    style: TextStyle(color: Colors.white)),
              ),
              body: const Center(
                child: Text('Aucun enfant enregistré',
                    style: TextStyle(color: Colors.white54)),
              ),
            ),
          );
        }

        final punishments =
            fp.punishments.where((p) => p.childId == child!.id).toList();

        return AnimatedBackground(
          child: Scaffold(
            backgroundColor: Colors.transparent,
            appBar: AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              title: const Text('📜 Punitions',
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold)),
              actions: [
                IconButton(
                  icon: const Icon(Icons.add_circle_outline,
                      color: Colors.white),
                  onPressed: () =>
                      setState(() => _showAddForm = !_showAddForm),
                ),
              ],
            ),
            body: FadeTransition(
              opacity: _fadeAnim,
              child: Column(
                children: [
                  _buildChildSelector(children, child!),
                  if (_showAddForm) _buildAddForm(fp, child),
                  Expanded(
                    child: punishments.isEmpty
                        ? _buildEmpty()
                        : ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: punishments.length,
                            itemBuilder: (_, i) => _buildPunishmentCard(
                                punishments[i], child, fp),
                          ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ─── Sélecteur d'enfant ─────────────────────────────────────────────────────
  Widget _buildChildSelector(
      List<ChildModel> children, ChildModel selected) {
    return Container(
      height: 80,
      color: Colors.black12,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        itemCount: children.length,
        itemBuilder: (_, i) {
          final c = children[i];
          final isSelected = c.id == selected.id;
          return GestureDetector(
            onTap: () => setState(() {
              _selectedChildId = c.id;
              _showAddForm = false;
            }),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              margin: const EdgeInsets.symmetric(horizontal: 6),
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                gradient: isSelected
                    ? const LinearGradient(
                        colors: [Color(0xFF7C4DFF), Color(0xFF00BCD4)])
                    : null,
                color: isSelected ? null : Colors.white10,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color:
                        isSelected ? Colors.transparent : Colors.white24),
              ),
              child: Row(
                children: [
                  Text(c.avatar.isNotEmpty ? c.avatar : '🧒',
                      style: const TextStyle(fontSize: 18)),
                  const SizedBox(width: 6),
                  Text(c.name,
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: isSelected
                              ? FontWeight.bold
                              : FontWeight.normal)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ─── Formulaire d'ajout ──────────────────────────────────────────────────────
  Widget _buildAddForm(FamilyProvider fp, ChildModel child) {
    return GlassCard(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Nouvelle punition pour ${child.name}',
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16)),
          const SizedBox(height: 12),
          _buildTextField(_descController, 'Description *', Icons.edit),
          const SizedBox(height: 8),
          _buildTextField(_linesController, 'Nombre de lignes *',
              Icons.format_list_numbered,
              isNumber: true),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF7C4DFF),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(Icons.save),
              label: const Text('Enregistrer'),
              onPressed: () => _savePunishment(fp, child),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField(
      TextEditingController ctrl, String label, IconData icon,
      {bool isNumber = false}) {
    return TextFormField(
      controller: ctrl,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white60),
        prefixIcon: Icon(icon, color: Colors.white38),
        filled: true,
        fillColor: Colors.white10,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none),
      ),
    );
  }

  Future<void> _savePunishment(FamilyProvider fp, ChildModel child) async {
    final desc = _descController.text.trim();
    final lines = int.tryParse(_linesController.text.trim()) ?? 0;
    if (desc.isEmpty || lines <= 0) return;
    await fp.addPunishment(child.id, desc, lines);
    _descController.clear();
    _linesController.clear();
    setState(() => _showAddForm = false);
  }

  // ─── État vide ───────────────────────────────────────────────────────────────
  Widget _buildEmpty() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('✅', style: TextStyle(fontSize: 64)),
          SizedBox(height: 12),
          Text('Aucune punition en cours',
              style: TextStyle(color: Colors.white54, fontSize: 16)),
        ],
      ),
    );
  }

  // ─── Carte punition ──────────────────────────────────────────────────────────
  Widget _buildPunishmentCard(
      PunishmentLines p, ChildModel child, FamilyProvider fp) {
    final progress = p.progress;
    final remaining = p.totalLines - p.completedLines;

    // ✅ CORRECTIF 3 : on lit toujours les immunités depuis child.id résolu
    final totalImmunity = fp.getTotalAvailableImmunity(child.id);

    return GlassCard(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── En-tête ──
          Row(
            children: [
              Expanded(
                child: Text(p.text,
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold)),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline,
                    color: Colors.redAccent),
                onPressed: () => _confirmDelete(p, fp),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // ── Progression ──
          Row(
            children: [
              Text('${p.completedLines} / ${p.totalLines} lignes',
                  style: const TextStyle(
                      color: Colors.white70, fontSize: 13)),
              const Spacer(),
              Text('${(progress * 100).round()}%',
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.white12,
              valueColor: AlwaysStoppedAnimation<Color>(
                  progress >= 1.0
                      ? Colors.greenAccent
                      : const Color(0xFF7C4DFF)),
              minHeight: 8,
            ),
          ),

          // ── Badge validation en attente ──
          if (p.pendingValidation) ...[
            const SizedBox(height: 8),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.withOpacity(0.3)),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.hourglass_top_rounded,
                      color: Colors.orange, size: 14),
                  SizedBox(width: 6),
                  Text('En attente de validation parent',
                      style: TextStyle(
                          color: Colors.orange,
                          fontSize: 12,
                          fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),

          // ── Boutons Avancer / Terminer ──
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFF7C4DFF)),
                    foregroundColor: const Color(0xFF7C4DFF),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(Icons.edit, size: 16),
                  label: const Text('Avancer'),
                  onPressed: () => _advanceLines(p, fp),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.greenAccent.withOpacity(0.2),
                    foregroundColor: Colors.greenAccent,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(Icons.check_circle, size: 16),
                  label: const Text('Terminer'),
                  onPressed: () => _completePunishment(p, fp),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // ── Bouton immunité ──
          // ✅ Masqué complètement si 0 immunité ET punition terminée
          if (!p.isCompleted)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: totalImmunity > 0 && remaining > 0
                      ? Colors.amberAccent.withOpacity(0.2)
                      : Colors.white10,
                  foregroundColor: totalImmunity > 0 && remaining > 0
                      ? Colors.amberAccent
                      : Colors.white30,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                icon: const Icon(Icons.shield, size: 16),
                label: Text(
                  totalImmunity > 0
                      ? '🛡️ Utiliser une immunité ($totalImmunity lignes dispo)'
                      : '🛡️ Aucune immunité disponible',
                ),
                onPressed: totalImmunity > 0 && remaining > 0
                    ? () => _showImmunityPicker(p, child, fp)
                    : null,
              ),
            ),
        ],
      ),
    );
  }

  // ─── Sélecteur d'immunité ────────────────────────────────────────────────────
  void _showImmunityPicker(
      PunishmentLines p, ChildModel child, FamilyProvider fp) {
    final activeImmunities = fp.getUsableImmunitiesForChild(child.id);

    if (activeImmunities.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Aucune immunité disponible pour cet enfant'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => Consumer<FamilyProvider>(
        builder: (ctx, liveFp, __) {
          final liveImmunities =
              liveFp.getUsableImmunitiesForChild(child.id);

          return DraggableScrollableSheet(
            initialChildSize: 0.55,
            minChildSize: 0.35,
            maxChildSize: 0.85,
            expand: false,
            builder: (_, scrollController) => Container(
              decoration: const BoxDecoration(
                color: Color(0xFF0D1B2A),
                borderRadius:
                    BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                children: [
                  const SizedBox(height: 12),
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                        color: Colors.white38,
                        borderRadius: BorderRadius.circular(2)),
                  ),
                  const SizedBox(height: 16),
                  const Text('🛡️ Choisir une immunité',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(
                      'Punition : ${p.text} — ${p.totalLines - p.completedLines} lignes restantes',
                      style: const TextStyle(
                          color: Colors.white54, fontSize: 13)),
                  const SizedBox(height: 12),
                  liveImmunities.isEmpty
                      ? const Expanded(
                          child: Center(
                            child: Text(
                                'Toutes les immunités ont été utilisées',
                                style: TextStyle(color: Colors.white54)),
                          ),
                        )
                      : Expanded(
                          child: ListView.builder(
                            controller: scrollController,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8),
                            itemCount: liveImmunities.length,
                            itemBuilder: (_, i) {
                              final imm = liveImmunities[i];
                              final needed =
                                  p.totalLines - p.completedLines;
                              final willUse =
                                  imm.availableLines.clamp(0, needed);

                              return GlassCard(
                                margin:
                                    const EdgeInsets.only(bottom: 12),
                                padding: const EdgeInsets.all(14),
                                child: InkWell(
                                  onTap: () => _confirmImmunityUse(
                                      p, imm, liveFp, willUse),
                                  borderRadius:
                                      BorderRadius.circular(12),
                                  child: Row(
                                    children: [
                                      Container(
                                        padding:
                                            const EdgeInsets.all(10),
                                        decoration: BoxDecoration(
                                          color: Colors.cyanAccent
                                              .withOpacity(0.15),
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(
                                            Icons.shield_rounded,
                                            color: Colors.cyanAccent,
                                            size: 24),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(imm.reason,
                                                style: const TextStyle(
                                                    color: Colors.white,
                                                    fontWeight:
                                                        FontWeight.bold,
                                                    fontSize: 15)),
                                            const SizedBox(height: 4),
                                            Text(
                                                '${imm.availableLines} lignes dispo · $willUse seront utilisées',
                                                style: const TextStyle(
                                                    color: Colors.white54,
                                                    fontSize: 12)),
                                            if (imm.expiresAt != null)
                                              Text(
                                                  'Expire le ${_formatDate(imm.expiresAt!)}',
                                                  style: const TextStyle(
                                                      color:
                                                          Colors.white38,
                                                      fontSize: 11)),
                                          ],
                                        ),
                                      ),
                                      Container(
                                        padding:
                                            const EdgeInsets.symmetric(
                                                horizontal: 8,
                                                vertical: 4),
                                        decoration: BoxDecoration(
                                          color: Colors.amberAccent
                                              .withOpacity(0.2),
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          '-$willUse',
                                          style: const TextStyle(
                                              color: Colors.amberAccent,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 13),
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      const Icon(Icons.chevron_right,
                                          color: Colors.white38),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ─── Confirmation utilisation immunité ───────────────────────────────────────
  void _confirmImmunityUse(
    PunishmentLines p,
    ImmunityLines imm,
    FamilyProvider fp,
    int willUse,
  ) {
    final rootContext = context;
    Navigator.of(rootContext).pop();

    Future.microtask(() {
      showDialog(
        context: rootContext,
        builder: (_) => AlertDialog(
          backgroundColor: const Color(0xFF1A1A2E),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16)),
          title: const Text("Confirmer l'immunité",
              style: TextStyle(color: Colors.white)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Utiliser cette immunité sur la punition ?",
                  style: TextStyle(color: Colors.white70)),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.cyanAccent.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: Colors.cyanAccent.withOpacity(0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(imm.reason,
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(
                        '${imm.availableLines} lignes disponibles → $willUse seront consommées',
                        style: const TextStyle(
                            color: Colors.white54, fontSize: 12)),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.amberAccent.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: Colors.amberAccent.withOpacity(0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(p.text,
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 13)),
                    const SizedBox(height: 4),
                    Text(
                        '${p.completedLines} / ${p.totalLines} lignes · après : ${(p.completedLines + willUse).clamp(0, p.totalLines)} / ${p.totalLines}',
                        style: const TextStyle(
                            color: Colors.white54, fontSize: 12)),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(rootContext),
                child: const Text('Annuler',
                    style: TextStyle(color: Colors.white38))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amberAccent.withOpacity(0.25),
                foregroundColor: Colors.amberAccent,
              ),
              onPressed: () async {
                await fp.useImmunityOnPunishment(imm.id, p.id, willUse);
                if (mounted) {
                  Navigator.pop(rootContext);
                  ScaffoldMessenger.of(rootContext).showSnackBar(
                    SnackBar(
                      content: Text(
                          '🛡️ $willUse ligne(s) d\'immunité utilisée(s) !'),
                      backgroundColor:
                          Colors.amberAccent.withOpacity(0.8),
                    ),
                  );
                }
              },
              child: const Text('Confirmer'),
            ),
          ],
        ),
      );
    });
  }

  // ─── Helpers ──────────────────────────────────────────────────────────────
  String _formatDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  void _confirmDelete(PunishmentLines p, FamilyProvider fp) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        title: const Text('Supprimer cette punition ?',
            style: TextStyle(color: Colors.white)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annuler')),
          TextButton(
              onPressed: () {
                fp.removePunishment(p.id);
                Navigator.pop(context);
              },
              child: const Text('Supprimer',
                  style: TextStyle(color: Colors.redAccent))),
        ],
      ),
    );
  }

  void _advanceLines(PunishmentLines p, FamilyProvider fp) {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        title: const Text('Avancer les lignes',
            style: TextStyle(color: Colors.white)),
        content: TextFormField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            labelText: 'Lignes complétées',
            labelStyle: TextStyle(color: Colors.white60),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annuler')),
          TextButton(
              onPressed: () {
                final n = int.tryParse(ctrl.text) ?? 0;
                if (n > 0) fp.updatePunishmentProgress(p.id, n);
                Navigator.pop(context);
              },
              child: const Text('Valider',
                  style: TextStyle(color: Colors.greenAccent))),
        ],
      ),
    );
  }

  void _completePunishment(PunishmentLines p, FamilyProvider fp) {
    final remaining = p.totalLines - p.completedLines;
    if (remaining > 0) fp.updatePunishmentProgress(p.id, remaining);
  }
}
