import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/family_provider.dart';
import '../models/punishment_model.dart';
import '../models/child_model.dart';
import '../models/immunity_model.dart';
import '../widgets/glass_card.dart';
import '../widgets/animated_background.dart';
import '../widgets/animated_page_transition.dart';

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
  final TextEditingController _subjectController = TextEditingController();
  String _selectedPriority = 'normal';

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _fadeAnim = CurvedAnimation(parent: _controller, curve: Curves.easeIn);
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    _descController.dispose();
    _linesController.dispose();
    _subjectController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<FamilyProvider>(
      builder: (context, fp, _) {
        final children = fp.children;
        final child = _selectedChildId != null
            ? fp.children.firstWhere((c) => c.id == _selectedChildId,
                orElse: () => children.first)
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

        final punishments = fp.getPunishmentsForChild(child!.id);

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
                  _buildChildSelector(children, child),
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

  Widget _buildChildSelector(
      List<ChildModel> children, ChildModel selected) {
    return Container(
      height: 80,
      color: Colors.black12,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
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
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                gradient: isSelected
                    ? const LinearGradient(colors: [
                        Color(0xFF7C4DFF),
                        Color(0xFF00BCD4)
                      ])
                    : null,
                color: isSelected ? null : Colors.white10,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color: isSelected
                        ? Colors.transparent
                        : Colors.white24),
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
          _buildTextField(
              _subjectController, 'Matière (optionnel)', Icons.book),
          const SizedBox(height: 8),
          _buildTextField(_linesController, 'Nombre de lignes *',
              Icons.format_list_numbered,
              isNumber: true),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: _selectedPriority,
            dropdownColor: const Color(0xFF1A1A2E),
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              labelText: 'Priorité',
              labelStyle: const TextStyle(color: Colors.white60),
              filled: true,
              fillColor: Colors.white10,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
            items: const [
              DropdownMenuItem(value: 'low', child: Text('Faible')),
              DropdownMenuItem(value: 'normal', child: Text('Normale')),
              DropdownMenuItem(value: 'high', child: Text('Haute')),
              DropdownMenuItem(
                  value: 'critical', child: Text('Critique')),
            ],
            onChanged: (v) =>
                setState(() => _selectedPriority = v ?? 'normal'),
          ),
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
      keyboardType:
          isNumber ? TextInputType.number : TextInputType.text,
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

  Future<void> _savePunishment(
      FamilyProvider fp, ChildModel child) async {
    final desc = _descController.text.trim();
    final lines =
        int.tryParse(_linesController.text.trim()) ?? 0;
    if (desc.isEmpty || lines <= 0) return;

    final p = PunishmentLines(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      childId: child.id,
      description: desc,
      totalLines: lines,
      subject: _subjectController.text.trim(),
      priority: _selectedPriority,
      createdAt: DateTime.now(),
    );

    await fp.addPunishment(p);
    _descController.clear();
    _linesController.clear();
    _subjectController.clear();
    setState(() => _showAddForm = false);
  }

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

  Widget _buildPunishmentCard(
      PunishmentLines p, ChildModel child, FamilyProvider fp) {
    final progress = p.linesCompleted / p.totalLines;
    final priorityColor = _priorityColor(p.priority);

    return GlassCard(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: priorityColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: priorityColor.withOpacity(0.5)),
                ),
                child: Text(p.priority.toUpperCase(),
                    style: TextStyle(
                        color: priorityColor,
                        fontSize: 10,
                        fontWeight: FontWeight.bold)),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(p.description,
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
          if (p.subject.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text('📚 ${p.subject}',
                style: const TextStyle(
                    color: Colors.white54, fontSize: 12)),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Text(
                  '${p.linesCompleted} / ${p.totalLines} lignes',
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
          const SizedBox(height: 12),
          // Ligne 1 : Avancer + Terminer
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(
                        color: Color(0xFF7C4DFF)),
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
                    backgroundColor:
                        Colors.greenAccent.withOpacity(0.2),
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
          // Ligne 2 : Immunité (pleine largeur)
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    Colors.amberAccent.withOpacity(0.2),
                foregroundColor: Colors.amberAccent,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              icon: const Icon(Icons.shield, size: 16),
              label: const Text('🛡️ Utiliser une immunité'),
              onPressed: () => _showImmunityPicker(p, child, fp),
            ),
          ),
        ],
      ),
    );
  }

  void _showImmunityPicker(
      PunishmentLines p, ChildModel child, FamilyProvider fp) {
    final activeImmunities = fp
        .getImmunitiesForChild(child.id)
        .where((i) => i.isActive)
        .toList();

    if (activeImmunities.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:
              Text('Aucune immunité active pour cet enfant'),
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
          final liveImmunities = liveFp
              .getImmunitiesForChild(child.id)
              .where((i) => i.isActive)
              .toList();

          return DraggableScrollableSheet(
            initialChildSize: 0.55,
            minChildSize: 0.35,
            maxChildSize: 0.85,
            expand: false,
            builder: (_, scrollController) => Container(
              decoration: const BoxDecoration(
                color: Color(0xFF0D1B2A),
                borderRadius: BorderRadius.vertical(
                    top: Radius.circular(24)),
              ),
              child: Column(
                children: [
                  const SizedBox(height: 12),
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white38,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text('🛡️ Choisir une immunité',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(
                      'Punition : ${p.description} (${p.totalLines} lignes)',
                      style: const TextStyle(
                          color: Colors.white54, fontSize: 13)),
                  const SizedBox(height: 12),
                  liveImmunities.isEmpty
                      ? const Expanded(
                          child: Center(
                            child: Text(
                                'Toutes les immunités ont été utilisées',
                                style: TextStyle(
                                    color: Colors.white54)),
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
                              return GlassCard(
                                margin: const EdgeInsets.only(
                                    bottom: 12),
                                padding:
                                    const EdgeInsets.all(14),
                                child: InkWell(
                                  onTap: () =>
                                      _confirmImmunityUse(
                                          p, imm, liveFp),
                                  borderRadius:
                                      BorderRadius.circular(12),
                                  child: Row(
                                    children: [
                                      Container(
                                        padding:
                                            const EdgeInsets.all(
                                                10),
                                        decoration: BoxDecoration(
                                          color: imm.typeColor
                                              .withOpacity(0.15),
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(imm.typeIcon,
                                            color: imm.typeColor,
                                            size: 24),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment
                                                  .start,
                                          children: [
                                            Text(imm.name,
                                                style: const TextStyle(
                                                    color: Colors
                                                        .white,
                                                    fontWeight:
                                                        FontWeight
                                                            .bold,
                                                    fontSize: 15)),
                                            const SizedBox(
                                                height: 4),
                                            Text(imm.typeLabel,
                                                style: TextStyle(
                                                    color: imm
                                                        .typeColor,
                                                    fontSize: 12,
                                                    fontWeight:
                                                        FontWeight
                                                            .w600)),
                                            const SizedBox(
                                                height: 2),
                                            Text(
                                                '${imm.linesGranted} lignes couvertes',
                                                style: const TextStyle(
                                                    color: Colors
                                                        .white54,
                                                    fontSize: 12)),
                                            Text(
                                                'Expire le ${_formatDate(imm.expiresAt)}',
                                                style: const TextStyle(
                                                    color: Colors
                                                        .white38,
                                                    fontSize: 11)),
                                          ],
                                        ),
                                      ),
                                      const Icon(
                                          Icons.chevron_right,
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

  void _confirmImmunityUse(
      PunishmentLines p, ImmunityLines imm, FamilyProvider fp) {
    final rootContext = context;
    Navigator.of(rootContext).pop();
    Future.microtask(() {
      showDialog(
        context: rootContext,
        builder: (_) => AlertDialog(
          backgroundColor: const Color(0xFF1A1A2E),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16)),
          title: const Text('Confirmer l\'immunité',
              style: TextStyle(color: Colors.white)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                  'Tu es sur le point d\'autoriser l\'utilisation de :',
                  style: TextStyle(color: Colors.white70)),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: imm.typeColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: imm.typeColor.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Icon(imm.typeIcon,
                        color: imm.typeColor, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          Text(imm.name,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold)),
                          Text(imm.typeLabel,
                              style: TextStyle(
                                  color: imm.typeColor,
                                  fontSize: 12)),
                          Text(
                              '${imm.linesGranted} lignes couvertes',
                              style: const TextStyle(
                                  color: Colors.white54,
                                  fontSize: 12)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Text('Sur la punition : ${p.description}',
                  style: const TextStyle(
                      color: Colors.white54, fontSize: 13)),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(rootContext),
                child: const Text('Annuler',
                    style: TextStyle(color: Colors.white38))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    Colors.amberAccent.withOpacity(0.2),
                foregroundColor: Colors.amberAccent,
              ),
              onPressed: () async {
                await fp.useImmunityOnPunishment(p.id, imm.id);
                if (mounted) {
                  Navigator.pop(rootContext);
                  ScaffoldMessenger.of(rootContext).showSnackBar(
                    SnackBar(
                      content: Text(
                          '🛡️ Immunité "${imm.name}" utilisée avec succès !'),
                      backgroundColor:
                          Colors.amberAccent.withOpacity(0.8),
                    ),
                  );
                }
              },
              child: const Text('Autoriser'),
            ),
          ],
        ),
      );
    });
  }

  String _formatDate(DateTime d) {
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  }

  Color _priorityColor(String priority) {
    switch (priority) {
      case 'low':
        return Colors.greenAccent;
      case 'high':
        return Colors.orangeAccent;
      case 'critical':
        return Colors.redAccent;
      default:
        return Colors.blueAccent;
    }
  }

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
                fp.deletePunishment(p.id);
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
                if (n > 0) fp.advancePunishmentLines(p.id, n);
                Navigator.pop(context);
              },
              child: const Text('Valider',
                  style: TextStyle(color: Colors.greenAccent))),
        ],
      ),
    );
  }

  void _completePunishment(PunishmentLines p, FamilyProvider fp) {
    fp.advancePunishmentLines(
        p.id, p.totalLines - p.linesCompleted);
  }
}
