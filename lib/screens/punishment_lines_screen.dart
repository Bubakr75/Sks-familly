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

  // ─── Sélecteur d'enfant ──────────────────────────────────────────────────────
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
          const SizedBox(height: 10),

          // ══════════════════════════════════════════════════════
          // ── SECTION RÉDUCTIONS ──
          // ══════════════════════════════════════════════════════
          if (!p.isCompleted) ...[
            const Divider(color: Colors.white12),
            const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: Text('💡 Réduire la punition via :',
                  style: TextStyle(
                      color: Colors.white54,
                      fontSize: 12,
                      fontWeight: FontWeight.w600)),
            ),

            // ── 1. Immunité ──
            _reductionButton(
              icon: Icons.shield,
              label: totalImmunity > 0
                  ? '🛡️ Immunité  ($totalImmunity lignes dispo)'
                  : '🛡️ Aucune immunité disponible',
              color: Colors.amberAccent,
              enabled: totalImmunity > 0 && remaining > 0,
              onTap: () => _showImmunityPicker(p, child, fp),
            ),
            const SizedBox(height: 8),

            // ── 2. Service rendu ──
            _reductionButton(
              icon: Icons.handyman,
              label: '🔧 Proposer un service',
              color: Colors.lightBlueAccent,
              enabled: remaining > 0,
              onTap: () => _showServiceDialog(p, child, fp),
            ),
            const SizedBox(height: 8),

            // ── 3. Note scolaire ──
            _reductionButton(
              icon: Icons.school,
              label: '📚 Bonne note scolaire',
              color: Colors.greenAccent,
              enabled: remaining > 0,
              onTap: () => _showSchoolNoteDialog(p, child, fp),
            ),
          ],
        ],
      ),
    );
  }

  // ── Bouton réduction générique ───────────────────────────────────────────────
  Widget _reductionButton({
    required IconData icon,
    required String label,
    required Color color,
    required bool enabled,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: enabled
              ? color.withOpacity(0.15)
              : Colors.white10,
          foregroundColor: enabled ? color : Colors.white30,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10)),
          padding: const EdgeInsets.symmetric(vertical: 10),
        ),
        icon: Icon(icon, size: 16),
        label: Text(label, style: const TextStyle(fontSize: 13)),
        onPressed: enabled ? onTap : null,
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════════
  // ── DIALOG : Service rendu ───────────────────────────────────────────────────
  // ══════════════════════════════════════════════════════════════════════════════
  void _showServiceDialog(
      PunishmentLines p, ChildModel child, FamilyProvider fp) {
    final serviceCtrl = TextEditingController();
    final linesCtrl   = TextEditingController();

    final services = [
      '🍽️ Faire la vaisselle',
      '🧹 Balayer / aspirer',
      '🧺 Plier le linge',
      '🗑️ Sortir les poubelles',
      '🛏️ Faire son lit parfaitement',
      '🌿 Arroser les plantes',
      '🐾 S\'occuper de l\'animal',
      '🧽 Nettoyer la salle de bain',
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setModalState) => DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.5,
          maxChildSize: 0.92,
          expand: false,
          builder: (_, scrollCtrl) => Container(
            decoration: const BoxDecoration(
              color: Color(0xFF0D1B2A),
              borderRadius:
                  BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              children: [
                const SizedBox(height: 12),
                Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                      color: Colors.white38,
                      borderRadius: BorderRadius.circular(2)),
                ),
                const SizedBox(height: 16),
                const Text('🔧 Service rendu',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(
                    'Punition : ${p.text} — ${p.totalLines - p.completedLines} lignes restantes',
                    style: const TextStyle(
                        color: Colors.white54, fontSize: 12)),
                const SizedBox(height: 16),
                Expanded(
                  child: ListView(
                    controller: scrollCtrl,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    children: [
                      // Suggestions rapides
                      const Text('Suggestions rapides :',
                          style: TextStyle(
                              color: Colors.white60,
                              fontSize: 12,
                              fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: services.map((s) {
                          final isSelected =
                              serviceCtrl.text == s;
                          return GestureDetector(
                            onTap: () => setModalState(
                                () => serviceCtrl.text = s),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? Colors.lightBlueAccent
                                        .withOpacity(0.25)
                                    : Colors.white10,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                    color: isSelected
                                        ? Colors.lightBlueAccent
                                        : Colors.white24),
                              ),
                              child: Text(s,
                                  style: TextStyle(
                                      color: isSelected
                                          ? Colors.lightBlueAccent
                                          : Colors.white60,
                                      fontSize: 12)),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 16),

                      // Champ personnalisé
                      TextFormField(
                        controller: serviceCtrl,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: 'Ou décris le service...',
                          labelStyle:
                              const TextStyle(color: Colors.white54),
                          filled: true,
                          fillColor: Colors.white10,
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Nombre de lignes réduites
                      TextFormField(
                        controller: linesCtrl,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText:
                              'Lignes à retirer (max ${p.totalLines - p.completedLines})',
                          labelStyle:
                              const TextStyle(color: Colors.white54),
                          prefixIcon: const Icon(
                              Icons.remove_circle_outline,
                              color: Colors.lightBlueAccent),
                          filled: true,
                          fillColor: Colors.white10,
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none),
                        ),
                      ),
                      const SizedBox(height: 20),

                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              Colors.lightBlueAccent.withOpacity(0.25),
                          foregroundColor: Colors.lightBlueAccent,
                          padding:
                              const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        icon: const Icon(Icons.check),
                        label: const Text('Valider le service',
                            style: TextStyle(fontSize: 15)),
                        onPressed: () {
                          final service = serviceCtrl.text.trim();
                          final lines =
                              int.tryParse(linesCtrl.text.trim()) ?? 0;
                          final maxLines =
                              p.totalLines - p.completedLines;
                          if (service.isEmpty || lines <= 0) return;
                          final actual = lines.clamp(0, maxLines);
                          Navigator.pop(ctx);
                          _confirmServiceReduction(
                              p, child, fp, service, actual);
                        },
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _confirmServiceReduction(PunishmentLines p, ChildModel child,
      FamilyProvider fp, String service, int lines) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Confirmer le service',
            style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.lightBlueAccent.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: Colors.lightBlueAccent.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('🔧 $service',
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  Text(
                      '$lines ligne(s) retirée(s) de la punition "${p.text}"',
                      style: const TextStyle(
                          color: Colors.white60, fontSize: 12)),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annuler',
                  style: TextStyle(color: Colors.white38))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.lightBlueAccent.withOpacity(0.25),
              foregroundColor: Colors.lightBlueAccent,
            ),
            onPressed: () async {
              await fp.updatePunishmentProgress(p.id, lines);
              if (mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content:
                      Text('🔧 Service validé ! $lines ligne(s) retirée(s)'),
                  backgroundColor: Colors.lightBlueAccent.withOpacity(0.8),
                ));
              }
            },
            child: const Text('Confirmer'),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════════
  // ── DIALOG : Note scolaire ───────────────────────────────────────────────────
  // ══════════════════════════════════════════════════════════════════════════════
  void _showSchoolNoteDialog(
      PunishmentLines p, ChildModel child, FamilyProvider fp) {
    double note = 15;
    final noteCtrl = TextEditingController(text: '15');

    // Barème : note >= 18 → -5 lignes, >= 15 → -3, >= 12 → -1
    int _getLinesFromNote(double n) {
      if (n >= 18) return 5;
      if (n >= 15) return 3;
      if (n >= 12) return 1;
      return 0;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setModalState) {
          final reduction = _getLinesFromNote(note);
          final maxLines = p.totalLines - p.completedLines;
          final actual   = reduction.clamp(0, maxLines);

          return DraggableScrollableSheet(
            initialChildSize: 0.55,
            minChildSize: 0.4,
            maxChildSize: 0.85,
            expand: false,
            builder: (_, scrollCtrl) => Container(
              decoration: const BoxDecoration(
                color: Color(0xFF0D1B2A),
                borderRadius:
                    BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                children: [
                  const SizedBox(height: 12),
                  Container(
                    width: 40, height: 4,
                    decoration: BoxDecoration(
                        color: Colors.white38,
                        borderRadius: BorderRadius.circular(2)),
                  ),
                  const SizedBox(height: 16),
                  const Text('📚 Bonne note scolaire',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(
                      'Punition : ${p.text} — $maxLines lignes restantes',
                      style: const TextStyle(
                          color: Colors.white54, fontSize: 12)),
                  const SizedBox(height: 20),
                  Expanded(
                    child: ListView(
                      controller: scrollCtrl,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      children: [
                        // Slider note
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Note obtenue :',
                                style: TextStyle(
                                    color: Colors.white60, fontSize: 13)),
                            Text('${note.toStringAsFixed(1)} / 20',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16)),
                          ],
                        ),
                        Slider(
                          value: note,
                          min: 0,
                          max: 20,
                          divisions: 40,
                          activeColor: Colors.greenAccent,
                          inactiveColor: Colors.white12,
                          onChanged: (v) =>
                              setModalState(() => note = v),
                        ),
                        const SizedBox(height: 16),

                        // Barème affiché
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(12),
                            border:
                                Border.all(color: Colors.white12),
                          ),
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              const Text('📊 Barème de réduction :',
                                  style: TextStyle(
                                      color: Colors.white60,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600)),
                              const SizedBox(height: 8),
                              _baremeRow('18 – 20', '5 lignes retirées',
                                  note >= 18),
                              _baremeRow('15 – 17', '3 lignes retirées',
                                  note >= 15 && note < 18),
                              _baremeRow('12 – 14', '1 ligne retirée',
                                  note >= 12 && note < 15),
                              _baremeRow('< 12', 'Aucune réduction',
                                  note < 12),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Résumé
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: actual > 0
                                ? Colors.greenAccent.withOpacity(0.1)
                                : Colors.white.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: actual > 0
                                    ? Colors.greenAccent
                                        .withOpacity(0.3)
                                    : Colors.white12),
                          ),
                          child: Row(
                            mainAxisAlignment:
                                MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                actual > 0
                                    ? '✅ Réduction accordée'
                                    : '❌ Note insuffisante',
                                style: TextStyle(
                                    color: actual > 0
                                        ? Colors.greenAccent
                                        : Colors.redAccent,
                                    fontWeight: FontWeight.bold),
                              ),
                              Text(
                                actual > 0
                                    ? '-$actual ligne(s)'
                                    : '0 ligne',
                                style: TextStyle(
                                    color: actual > 0
                                        ? Colors.greenAccent
                                        : Colors.white38,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),

                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: actual > 0
                                ? Colors.greenAccent.withOpacity(0.2)
                                : Colors.white10,
                            foregroundColor: actual > 0
                                ? Colors.greenAccent
                                : Colors.white30,
                            padding: const EdgeInsets.symmetric(
                                vertical: 14),
                            shape: RoundedRectangleBorder(
                                borderRadius:
                                    BorderRadius.circular(12)),
                          ),
                          icon: const Icon(Icons.check),
                          label: Text(
                            actual > 0
                                ? 'Valider la réduction (-$actual lignes)'
                                : 'Note insuffisante (< 12)',
                            style:
                                const TextStyle(fontSize: 14),
                          ),
                          onPressed: actual > 0
                              ? () {
                                  Navigator.pop(ctx);
                                  _confirmSchoolNoteReduction(
                                      p, child, fp, note, actual);
                                }
                              : null,
                        ),
                        const SizedBox(height: 16),
                      ],
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

  Widget _baremeRow(String range, String label, bool active) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Row(
      children: [
        Icon(
          active ? Icons.check_circle : Icons.radio_button_unchecked,
          color: active ? Colors.greenAccent : Colors.white24,
          size: 14,
        ),
        const SizedBox(width: 8),
        Text(range,
            style: TextStyle(
                color: active ? Colors.white : Colors.white38,
                fontWeight:
                    active ? FontWeight.bold : FontWeight.normal,
                fontSize: 12)),
        const SizedBox(width: 8),
        Text('→ $label',
            style: TextStyle(
                color: active ? Colors.greenAccent : Colors.white24,
                fontSize: 12)),
      ],
    ),
  );

  void _confirmSchoolNoteReduction(PunishmentLines p, ChildModel child,
      FamilyProvider fp, double note, int lines) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Confirmer la réduction',
            style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.greenAccent.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: Colors.greenAccent.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('📚 Note : ${note.toStringAsFixed(1)} / 20',
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  Text(
                      '$lines ligne(s) retirée(s) de la punition "${p.text}"',
                      style: const TextStyle(
                          color: Colors.white60, fontSize: 12)),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annuler',
                  style: TextStyle(color: Colors.white38))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.greenAccent.withOpacity(0.2),
              foregroundColor: Colors.greenAccent,
            ),
            onPressed: () async {
              await fp.updatePunishmentProgress(p.id, lines);
              if (mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text(
                      '📚 Bonne note ! $lines ligne(s) retirée(s) de la punition'),
                  backgroundColor: Colors.greenAccent.withOpacity(0.8),
                ));
              }
            },
            child: const Text('Confirmer'),
          ),
        ],
      ),
    );
  }

  // ─── Sélecteur d'immunité (inchangé) ────────────────────────────────────────
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
                    width: 40, height: 4,
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
                                style:
                                    TextStyle(color: Colors.white54)),
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
                                margin: const EdgeInsets.only(bottom: 12),
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
                                                      color: Colors.white38,
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
                                        child: Text('-$willUse',
                                            style: const TextStyle(
                                                color: Colors.amberAccent,
                                                fontWeight:
                                                    FontWeight.bold,
                                                fontSize: 13)),
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

  void _confirmImmunityUse(PunishmentLines p, ImmunityLines imm,
      FamilyProvider fp, int willUse) {
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
                  ScaffoldMessenger.of(rootContext).showSnackBar(SnackBar(
                    content: Text(
                        '🛡️ $willUse ligne(s) d\'immunité utilisée(s) !'),
                    backgroundColor:
                        Colors.amberAccent.withOpacity(0.8),
                  ));
                }
              },
              child: const Text('Confirmer'),
            ),
          ],
        ),
      );
    });
  }

  // ─── Helpers ─────────────────────────────────────────────────────────────────
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
