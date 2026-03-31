import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/family_provider.dart';
import '../models/child_model.dart';
import '../models/punishment_lines.dart';
import '../widgets/animated_background.dart';
import '../widgets/glass_card.dart';
import '../widgets/glass_widgets.dart';
import '../widgets/tv_focus_wrapper.dart';

class PunishmentLinesScreen extends StatefulWidget {
  final String? initialChildId;
  const PunishmentLinesScreen({super.key, this.initialChildId});

  @override
  State<PunishmentLinesScreen> createState() => _PunishmentLinesScreenState();
}

class _PunishmentLinesScreenState extends State<PunishmentLinesScreen>
    with TickerProviderStateMixin {
  late AnimationController _listCtrl;
  late AnimationController _progressCtrl;
  late Animation<double> _listFade;
  late Animation<double> _progressAnim;

  String? _selectedChildId;

  @override
  void initState() {
    super.initState();
    _listCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _progressCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200));
    _listFade = CurvedAnimation(parent: _listCtrl, curve: Curves.easeOut);
    _progressAnim = CurvedAnimation(parent: _progressCtrl, curve: Curves.easeOutCubic);
    _listCtrl.forward();
    _progressCtrl.forward();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<FamilyProvider>();
      final children = provider.sortedChildren;
      if (widget.initialChildId != null) {
        setState(() => _selectedChildId = widget.initialChildId);
      } else if (children.isNotEmpty) {
        setState(() => _selectedChildId = children.first.id);
      }
    });
  }

  @override
  void dispose() {
    _listCtrl.dispose();
    _progressCtrl.dispose();
    super.dispose();
  }

  List<PunishmentLines> _getPunishments(FamilyProvider provider) {
    if (_selectedChildId == null) return [];
    return provider.getPunishmentsForChild(_selectedChildId!)
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  Color _statusColor(PunishmentLines p) {
    if (p.isCompleted) return const Color(0xFF4CAF50);
    if (p.progress > 0.5) return const Color(0xFFFFD700);
    return const Color(0xFFFF6B6B);
  }

  void _showAddPunishmentSheet() {
    final textCtrl = TextEditingController();
    final linesCtrl = TextEditingController(text: '10');
    int lines = 10;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Container(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
            left: 20,
            right: 20,
            top: 20,
          ),
          decoration: const BoxDecoration(
            color: Color(0xFF0D1B2A),
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(child: Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 16), decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)))),
                const NeonText(text: 'Nouvelle punition', fontSize: 22, color: Color(0xFFFF6B6B)),
                const SizedBox(height: 20),
                const Text('Description', style: TextStyle(color: Colors.white70, fontSize: 13)),
                const SizedBox(height: 8),
                TextField(
                  controller: textCtrl,
                  style: const TextStyle(color: Colors.white),
                  maxLines: 3,
                  decoration: InputDecoration(
                    hintText: 'Ex: Écrire 50 fois "je ne dois pas..."',
                    hintStyle: const TextStyle(color: Colors.white38),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.05),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  ),
                ),
                const SizedBox(height: 20),
                const Text('Nombre de lignes', style: TextStyle(color: Colors.white70, fontSize: 13)),
                const SizedBox(height: 8),
                // Saisie libre + raccourcis
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: linesCtrl,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: Colors.white.withOpacity(0.07),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                          contentPadding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        onChanged: (v) => setSheet(() => lines = int.tryParse(v) ?? lines),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      children: [
                        IconButton(
                          onPressed: () {
                            final v = (int.tryParse(linesCtrl.text) ?? lines) + 1;
                            linesCtrl.text = '$v';
                            setSheet(() => lines = v);
                          },
                          icon: const Icon(Icons.keyboard_arrow_up, color: Colors.white70),
                        ),
                        IconButton(
                          onPressed: () {
                            final v = math.max(1, (int.tryParse(linesCtrl.text) ?? lines) - 1);
                            linesCtrl.text = '$v';
                            setSheet(() => lines = v);
                          },
                          icon: const Icon(Icons.keyboard_arrow_down, color: Colors.white70),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // Raccourcis rapides
                Wrap(
                  spacing: 8,
                  children: [5, 10, 20, 50, 100].map((n) => ActionChip(
                    label: Text('$n', style: const TextStyle(color: Colors.white70)),
                    backgroundColor: Colors.white.withOpacity(0.07),
                    onPressed: () => setSheet(() {
                      lines = n;
                      linesCtrl.text = '$n';
                    }),
                  )).toList(),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: () {
                      if (_selectedChildId == null || textCtrl.text.trim().isEmpty) return;
                      final finalLines = int.tryParse(linesCtrl.text) ?? lines;
                      if (finalLines <= 0) return;
                      context.read<FamilyProvider>().addPunishment(
                        childId: _selectedChildId!,
                        text: textCtrl.text.trim(),
                        totalLines: finalLines,
                      );
                      Navigator.pop(ctx);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF6B6B),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: const Text('Enregistrer', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showPunishmentDetail(PunishmentLines p) {
    final addCtrl = TextEditingController(text: '1');
    int toAdd = 1;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Container(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom + 16, left: 20, right: 20, top: 20),
          decoration: const BoxDecoration(color: Color(0xFF0D1B2A), borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(child: Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 16), decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)))),
                Row(
                  children: [
                    Expanded(child: NeonText(text: p.text, fontSize: 18, color: _statusColor(p))),
                    if (!p.isCompleted)
                      IconButton(
                        onPressed: () {
                          Navigator.pop(ctx);
                          _confirmDelete(p);
                        },
                        icon: const Icon(Icons.delete_outline, color: Color(0xFFFF6B6B)),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('${p.completedLines} / ${p.totalLines} lignes', style: const TextStyle(color: Colors.white70)),
                    Text('${(p.progress * 100).toInt()}%', style: TextStyle(color: _statusColor(p), fontWeight: FontWeight.bold, fontSize: 18)),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: p.progress,
                    backgroundColor: Colors.white12,
                    valueColor: AlwaysStoppedAnimation(_statusColor(p)),
                    minHeight: 12,
                  ),
                ),
                const SizedBox(height: 24),
                if (!p.isCompleted) ...[
                  const Text('Ajouter des lignes complétées', style: TextStyle(color: Colors.white70, fontSize: 13)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: addCtrl,
                          keyboardType: TextInputType.number,
                          style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center,
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: Colors.white.withOpacity(0.07),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                          ),
                          onChanged: (v) => setSheet(() => toAdd = int.tryParse(v) ?? toAdd),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        children: [
                          IconButton(
                            onPressed: () {
                              final v = (int.tryParse(addCtrl.text) ?? toAdd) + 1;
                              addCtrl.text = '$v';
                              setSheet(() => toAdd = v);
                            },
                            icon: const Icon(Icons.keyboard_arrow_up, color: Colors.white70),
                          ),
                          IconButton(
                            onPressed: () {
                              final v = math.max(1, (int.tryParse(addCtrl.text) ?? toAdd) - 1);
                              addCtrl.text = '$v';
                              setSheet(() => toAdd = v);
                            },
                            icon: const Icon(Icons.keyboard_arrow_down, color: Colors.white70),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [1, 5, 10, 20].map((n) => ActionChip(
                      label: Text('+$n', style: const TextStyle(color: Colors.white70)),
                      backgroundColor: Colors.white.withOpacity(0.07),
                      onPressed: () => setSheet(() {
                        toAdd = n;
                        addCtrl.text = '$n';
                      }),
                    )).toList(),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        final finalAdd = int.tryParse(addCtrl.text) ?? toAdd;
                        if (finalAdd <= 0) return;
                        context.read<FamilyProvider>().updatePunishmentProgress(p.id, finalAdd);
                        Navigator.pop(ctx);
                      },
                      icon: const Icon(Icons.check),
                      label: const Text('Valider'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4CAF50),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  ),
                ] else ...[
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      color: const Color(0xFF4CAF50).withOpacity(0.1),
                      border: Border.all(color: const Color(0xFF4CAF50).withOpacity(0.4)),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('✅', style: TextStyle(fontSize: 24)),
                        SizedBox(width: 12),
                        Text('Punition terminée !', style: TextStyle(color: Color(0xFF4CAF50), fontWeight: FontWeight.bold, fontSize: 16)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(ctx);
                        _confirmDelete(p);
                      },
                      icon: const Icon(Icons.delete_outline, color: Color(0xFFFF6B6B)),
                      label: const Text('Supprimer', style: TextStyle(color: Color(0xFFFF6B6B))),
                      style: OutlinedButton.styleFrom(side: const BorderSide(color: Color(0xFFFF6B6B))),
                    ),
                  ),
                ],
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _confirmDelete(PunishmentLines p) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0D1B2A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Supprimer ?', style: TextStyle(color: Colors.white)),
        content: Text('Supprimer "${p.text}" ?', style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler', style: TextStyle(color: Colors.white54))),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.read<FamilyProvider>().removePunishment(p.id);
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF6B6B), foregroundColor: Colors.white),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Consumer<FamilyProvider>(
          builder: (ctx, provider, _) {
            final children = provider.sortedChildren;
            final punishments = _getPunishments(provider);
            final active = punishments.where((p) => !p.isCompleted).toList();
            final completed = punishments.where((p) => p.isCompleted).toList();

            return SafeArea(
              child: FadeTransition(
                opacity: _listFade,
                child: Column(
                  children: [
                    // ── Header ──
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                      child: Row(
                        children: [
                          IconButton(
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white70),
                          ),
                          const Expanded(child: NeonText(text: '📋 Lignes de punition', fontSize: 20, color: Color(0xFFFF6B6B))),
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
                                    color: selected ? const Color(0xFFFF6B6B).withOpacity(0.2) : Colors.white.withOpacity(0.05),
                                    border: Border.all(color: selected ? const Color(0xFFFF6B6B) : Colors.white24),
                                  ),
                                  child: Text(c.name, style: TextStyle(color: selected ? const Color(0xFFFF6B6B) : Colors.white70, fontWeight: selected ? FontWeight.bold : FontWeight.normal)),
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ),

                    // ── Stats chips ──
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      child: Row(
                        children: [
                          _chip('🔴 En cours', '${active.length}', const Color(0xFFFF6B6B)),
                          const SizedBox(width: 8),
                          _chip('✅ Terminées', '${completed.length}', const Color(0xFF4CAF50)),
                          const SizedBox(width: 8),
                          _chip('📋 Total', '${punishments.length}', Colors.white54),
                        ],
                      ),
                    ),

                    // ── Liste ──
                    Expanded(
                      child: punishments.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Text('🎉', style: TextStyle(fontSize: 64)),
                                  const SizedBox(height: 12),
                                  const Text('Aucune punition !', style: TextStyle(color: Colors.white70, fontSize: 18)),
                                  const SizedBox(height: 6),
                                  const Text('Tout va bien 😊', style: TextStyle(color: Colors.white38, fontSize: 14)),
                                ],
                              ),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              itemCount: punishments.length,
                              itemBuilder: (ctx, i) {
                                final p = punishments[i];
                                return _buildPunishmentCard(p);
                              },
                            ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _showAddPunishmentSheet,
          backgroundColor: const Color(0xFFFF6B6B),
          foregroundColor: Colors.white,
          icon: const Icon(Icons.add),
          label: const Text('Ajouter', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
      ),
    );
  }

  Widget _chip(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: color.withOpacity(0.1),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: TextStyle(color: color, fontSize: 12)),
          const SizedBox(width: 4),
          Text(value, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildPunishmentCard(PunishmentLines p) {
    final color = _statusColor(p);
    return GestureDetector(
      onTap: () => _showPunishmentDetail(p),
      child: AnimatedBuilder(
        animation: _progressAnim,
        builder: (_, __) => Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: Colors.white.withOpacity(0.04),
            border: Border.all(color: color.withOpacity(0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: Text(p.text, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15), maxLines: 2, overflow: TextOverflow.ellipsis)),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), color: color.withOpacity(0.15)),
                    child: Text(p.isCompleted ? '✅ Fait' : '🔴 En cours', style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: (p.progress * _progressAnim.value).clamp(0.0, 1.0),
                        backgroundColor: Colors.white12,
                        valueColor: AlwaysStoppedAnimation(color),
                        minHeight: 8,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text('${p.completedLines}/${p.totalLines}', style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13)),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Créé le ${p.createdAt.day}/${p.createdAt.month}/${p.createdAt.year}',
                style: const TextStyle(color: Colors.white38, fontSize: 11),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
