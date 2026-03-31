import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/family_provider.dart';
import '../providers/pin_provider.dart';
import '../models/child_model.dart';
import '../models/immunity_lines.dart';
import '../models/punishment_lines.dart';
import '../widgets/animated_background.dart';
import '../widgets/glass_card.dart';
import '../widgets/glass_widgets.dart';
import '../widgets/pin_guard.dart';
import '../widgets/tv_focus_wrapper.dart';
import 'trade_screen.dart';

class ImmunityLinesScreen extends StatefulWidget {
  final String? initialChildId;
  const ImmunityLinesScreen({super.key, this.initialChildId});

  @override
  State<ImmunityLinesScreen> createState() => _ImmunityLinesScreenState();
}

class _ImmunityLinesScreenState extends State<ImmunityLinesScreen>
    with TickerProviderStateMixin {
  late AnimationController _shieldCtrl;
  late AnimationController _listCtrl;
  late Animation<double> _shieldScale;
  late Animation<double> _shieldGlow;
  late Animation<double> _listFade;

  String? _selectedChildId;

  @override
  void initState() {
    super.initState();
    _shieldCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200));
    _listCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _shieldScale = Tween<double>(begin: 0.5, end: 1.0).animate(CurvedAnimation(parent: _shieldCtrl, curve: Curves.elasticOut));
    _shieldGlow = Tween<double>(begin: 0.3, end: 1.0).animate(CurvedAnimation(parent: _shieldCtrl, curve: Curves.easeOut));
    _listFade = CurvedAnimation(parent: _listCtrl, curve: Curves.easeOut);
    _shieldCtrl.forward();
    _listCtrl.forward();

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
    _shieldCtrl.dispose();
    _listCtrl.dispose();
    super.dispose();
  }

  List<ImmunityLines> _getImmunities(FamilyProvider provider) {
    if (_selectedChildId == null) return [];
    return provider.getImmunitiesForChild(_selectedChildId!)
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  Color _statusColor(ImmunityLines imm) {
    if (imm.isExpired) return Colors.white38;
    if (imm.isFullyUsed) return Colors.white38;
    if (imm.availableLines > 5) return const Color(0xFF9C27B0);
    return const Color(0xFFFFD700);
  }

  String _statusText(ImmunityLines imm) {
    if (imm.isExpired) return '⏰ Expirée';
    if (imm.isFullyUsed) return '✅ Utilisée';
    return '🛡️ Active';
  }

  // ── Utiliser une immunité sur une punition (accessible ENFANT) ──
  void _useImmunityOnPunishment(ImmunityLines imm) {
    final provider = context.read<FamilyProvider>();
    if (_selectedChildId == null) return;
    final punishments = provider.getPunishmentsForChild(_selectedChildId!)
        .where((p) => !p.isCompleted)
        .toList();

    if (punishments.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Aucune punition active à couvrir', style: TextStyle(color: Colors.white)),
          backgroundColor: const Color(0xFF1A2744),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        int linesToUse = math.min(imm.availableLines, punishments.first.totalLines - punishments.first.completedLines);
        final linesCtrl = TextEditingController(text: '$linesToUse');
        PunishmentLines? selectedPunishment = punishments.first;

        return StatefulBuilder(
          builder: (ctx, setSheet) => Container(
            padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom + 16, left: 20, right: 20, top: 20),
            decoration: const BoxDecoration(color: Color(0xFF0D1B2A), borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(child: Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 16), decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)))),
                  const NeonText(text: '🛡️ Utiliser l\'immunité', fontSize: 20, color: Color(0xFF9C27B0)),
                  const SizedBox(height: 6),
                  Text('Immunités disponibles : ${imm.availableLines}', style: const TextStyle(color: Colors.white54, fontSize: 13)),
                  const SizedBox(height: 16),
                  const Text('Choisir la punition', style: TextStyle(color: Colors.white70, fontSize: 13)),
                  const SizedBox(height: 8),
                  ...punishments.map((p) {
                    final isSelected = selectedPunishment?.id == p.id;
                    return GestureDetector(
                      onTap: () {
                        setSheet(() {
                          selectedPunishment = p;
                          linesToUse = math.min(imm.availableLines, p.totalLines - p.completedLines);
                          linesCtrl.text = '$linesToUse';
                        });
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.only(bottom: 6),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          color: isSelected ? const Color(0xFF9C27B0).withOpacity(0.15) : Colors.white.withOpacity(0.04),
                          border: Border.all(color: isSelected ? const Color(0xFF9C27B0) : Colors.white12),
                        ),
                        child: Row(
                          children: [
                            Expanded(child: Text(p.text, style: TextStyle(color: isSelected ? const Color(0xFF9C27B0) : Colors.white70, fontSize: 13))),
                            Text('${p.totalLines - p.completedLines} restantes', style: const TextStyle(color: Colors.white38, fontSize: 11)),
                          ],
                        ),
                      ),
                    );
                  }),
                  const SizedBox(height: 16),
                  const Text('Nombre de lignes à utiliser', style: TextStyle(color: Colors.white70, fontSize: 13)),
                  const SizedBox(height: 8),
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
                          ),
                          onChanged: (v) => setSheet(() => linesToUse = int.tryParse(v) ?? linesToUse),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        children: [
                          IconButton(
                            onPressed: () {
                              final v = math.min(imm.availableLines, (int.tryParse(linesCtrl.text) ?? linesToUse) + 1);
                              linesCtrl.text = '$v';
                              setSheet(() => linesToUse = v);
                            },
                            icon: const Icon(Icons.keyboard_arrow_up, color: Colors.white70),
                          ),
                          IconButton(
                            onPressed: () {
                              final v = math.max(1, (int.tryParse(linesCtrl.text) ?? linesToUse) - 1);
                              linesCtrl.text = '$v';
                              setSheet(() => linesToUse = v);
                            },
                            icon: const Icon(Icons.keyboard_arrow_down, color: Colors.white70),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: () {
                        if (selectedPunishment == null) return;
                        final finalLines = int.tryParse(linesCtrl.text) ?? linesToUse;
                        if (finalLines <= 0 || finalLines > imm.availableLines) return;
                        context.read<FamilyProvider>().useImmunityOnPunishment(
                          immunityId: imm.id,
                          punishmentId: selectedPunishment!.id,
                          linesToUse: finalLines,
                        );
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text('✅ $finalLines ligne(s) d\'immunité utilisées !', style: const TextStyle(color: Colors.white)),
                          backgroundColor: const Color(0xFF9C27B0),
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ));
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF9C27B0),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: const Text('Utiliser', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ── Proposer un trade ──
  void _proposeTrade(ImmunityLines imm) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TradeScreen(
          childId: _selectedChildId!,
          preselectedImmunityId: imm.id,
        ),
      ),
    );
  }

  // ── Ajouter une immunité (parent uniquement) ──
  void _showAddImmunitySheet() {
    final reasonCtrl = TextEditingController();
    final linesCtrl = TextEditingController(text: '5');
    int lines = 5;
    DateTime? expiresAt;

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
                const NeonText(text: '🛡️ Nouvelle immunité', fontSize: 22, color: Color(0xFF9C27B0)),
                const SizedBox(height: 20),
                const Text('Raison', style: TextStyle(color: Colors.white70, fontSize: 13)),
                const SizedBox(height: 8),
                TextField(
                  controller: reasonCtrl,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Ex: Excellent bulletin scolaire',
                    hintStyle: const TextStyle(color: Colors.white38),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.05),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  ),
                ),
                const SizedBox(height: 20),
                const Text('Nombre de lignes d\'immunité', style: TextStyle(color: Colors.white70, fontSize: 13)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: linesCtrl,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: Colors.white.withOpacity(0.07),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
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
                Wrap(
                  spacing: 8,
                  children: [2, 5, 10, 20, 50].map((n) => ActionChip(
                    label: Text('$n', style: const TextStyle(color: Colors.white70)),
                    backgroundColor: Colors.white.withOpacity(0.07),
                    onPressed: () => setSheet(() {
                      lines = n;
                      linesCtrl.text = '$n';
                    }),
                  )).toList(),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    const Text('Date d\'expiration (optionnelle)', style: TextStyle(color: Colors.white70, fontSize: 13)),
                    const Spacer(),
                    if (expiresAt != null)
                      GestureDetector(
                        onTap: () => setSheet(() => expiresAt = null),
                        child: const Icon(Icons.close, color: Colors.white38, size: 18),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: () async {
                    final d = await showDatePicker(
                      context: ctx,
                      initialDate: DateTime.now().add(const Duration(days: 30)),
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                      builder: (ctx, child) => Theme(
                        data: ThemeData.dark().copyWith(colorScheme: const ColorScheme.dark(primary: Color(0xFF9C27B0))),
                        child: child!,
                      ),
                    );
                    if (d != null) setSheet(() => expiresAt = d);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: Colors.white.withOpacity(0.05),
                      border: Border.all(color: expiresAt != null ? const Color(0xFF9C27B0) : Colors.white24),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_today, color: Colors.white38, size: 16),
                        const SizedBox(width: 8),
                        Text(
                          expiresAt != null ? '${expiresAt!.day}/${expiresAt!.month}/${expiresAt!.year}' : 'Sélectionner une date',
                          style: TextStyle(color: expiresAt != null ? Colors.white : Colors.white38),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: () {
                      if (_selectedChildId == null || reasonCtrl.text.trim().isEmpty) return;
                      final finalLines = int.tryParse(linesCtrl.text) ?? lines;
                      if (finalLines <= 0) return;
                      context.read<FamilyProvider>().addImmunity(
                        childId: _selectedChildId!,
                        reason: reasonCtrl.text.trim(),
                        lines: finalLines,
                        expiresAt: expiresAt,
                      );
                      Navigator.pop(ctx);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF9C27B0),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: const Text('Créer l\'immunité', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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

  void _showImmunityDetail(ImmunityLines imm) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(color: Color(0xFF0D1B2A), borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(child: Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 16), decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)))),
            Text('🛡️ ${imm.reason}', style: TextStyle(color: _statusColor(imm), fontWeight: FontWeight.bold, fontSize: 18), textAlign: TextAlign.center),
            const SizedBox(height: 12),
            Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
              _detailStat('Total', '${imm.lines}', const Color(0xFF9C27B0)),
              _detailStat('Utilisées', '${imm.usedLines}', const Color(0xFFFF6B6B)),
              _detailStat('Disponibles', '${imm.availableLines}', const Color(0xFF4CAF50)),
            ]),
            if (imm.expiresAt != null) ...[
              const SizedBox(height: 12),
              Text(imm.expiresLabel, style: const TextStyle(color: Colors.white54, fontSize: 12)),
            ],
            const SizedBox(height: 16),
            if (imm.isUsable) ...[
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(ctx);
                        _useImmunityOnPunishment(imm);
                      },
                      icon: const Icon(Icons.shield, size: 16),
                      label: const Text('Utiliser'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF9C27B0),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(ctx);
                        _proposeTrade(imm);
                      },
                      icon: const Icon(Icons.handshake, size: 16),
                      label: const Text('Vendre'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFFD700),
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
            // Bouton suppression (parent uniquement)
            PinGuard(
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.pop(ctx);
                  context.read<FamilyProvider>().removeImmunity(imm.id);
                },
                icon: const Icon(Icons.delete_outline, color: Color(0xFFFF6B6B), size: 16),
                label: const Text('Supprimer', style: TextStyle(color: Color(0xFFFF6B6B))),
                style: OutlinedButton.styleFrom(side: const BorderSide(color: Color(0xFFFF6B6B))),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _detailStat(String label, String value, Color color) {
    return Column(children: [
      Text(value, style: TextStyle(color: color, fontSize: 24, fontWeight: FontWeight.bold)),
      Text(label, style: const TextStyle(color: Colors.white54, fontSize: 11)),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Consumer<FamilyProvider>(
          builder: (ctx, provider, _) {
            final children = provider.sortedChildren;
            final immunities = _getImmunities(provider);
            final active = immunities.where((i) => i.isUsable).toList();
            final total = immunities.fold<int>(0, (s, i) => s + i.lines);

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
                          IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white70)),
                          Expanded(
                            child: Row(
                              children: [
                                AnimatedBuilder(
                                  animation: _shieldScale,
                                  builder: (_, child) => Transform.scale(scale: _shieldScale.value, child: child),
                                  child: AnimatedBuilder(
                                    animation: _shieldGlow,
                                    builder: (_, __) => Container(
                                      decoration: BoxDecoration(shape: BoxShape.circle, boxShadow: [BoxShadow(color: const Color(0xFF9C27B0).withOpacity(_shieldGlow.value * 0.5), blurRadius: 12, spreadRadius: 2)]),
                                      child: const Text('🛡️', style: TextStyle(fontSize: 28)),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                const NeonText(text: 'Immunités', fontSize: 22, color: Color(0xFF9C27B0)),
                              ],
                            ),
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
                                    color: selected ? const Color(0xFF9C27B0).withOpacity(0.2) : Colors.white.withOpacity(0.05),
                                    border: Border.all(color: selected ? const Color(0xFF9C27B0) : Colors.white24),
                                  ),
                                  child: Text(c.name, style: TextStyle(color: selected ? const Color(0xFF9C27B0) : Colors.white70, fontWeight: selected ? FontWeight.bold : FontWeight.normal)),
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
                          _chip('🛡️ Actives', '${active.length}', const Color(0xFF9C27B0)),
                          const SizedBox(width: 8),
                          _chip('📊 Total lignes', '$total', const Color(0xFF00E5FF)),
                          const SizedBox(width: 8),
                          _chip('🗂️ Toutes', '${immunities.length}', Colors.white54),
                        ],
                      ),
                    ),

                    // ── Liste ──
                    Expanded(
                      child: immunities.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Text('🛡️', style: TextStyle(fontSize: 64)),
                                  const SizedBox(height: 12),
                                  const Text('Aucune immunité', style: TextStyle(color: Colors.white70, fontSize: 18)),
                                  const SizedBox(height: 6),
                                  const Text('Les immunités se gagnent avec de bonnes actions', style: TextStyle(color: Colors.white38, fontSize: 13), textAlign: TextAlign.center),
                                ],
                              ),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              itemCount: immunities.length,
                              itemBuilder: (ctx, i) => _buildImmunityCard(immunities[i]),
                            ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
        floatingActionButton: PinGuard(
          child: FloatingActionButton.extended(
            onPressed: _showAddImmunitySheet,
            backgroundColor: const Color(0xFF9C27B0),
            foregroundColor: Colors.white,
            icon: const Icon(Icons.add),
            label: const Text('Ajouter', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ),
      ),
    );
  }

  Widget _chip(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), color: color.withOpacity(0.1), border: Border.all(color: color.withOpacity(0.3))),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Text(label, style: TextStyle(color: color, fontSize: 12)),
        const SizedBox(width: 4),
        Text(value, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13)),
      ]),
    );
  }

  Widget _buildImmunityCard(ImmunityLines imm) {
    final color = _statusColor(imm);
    return GestureDetector(
      onTap: () => _showImmunityDetail(imm),
      child: Container(
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
                Expanded(child: Text(imm.reason, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15), maxLines: 2, overflow: TextOverflow.ellipsis)),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), color: color.withOpacity(0.15)),
                  child: Text(_statusText(imm), style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _miniStat('Total', '${imm.lines}', const Color(0xFF9C27B0)),
                const SizedBox(width: 12),
                _miniStat('Utilisées', '${imm.usedLines}', const Color(0xFFFF6B6B)),
                const SizedBox(width: 12),
                _miniStat('Disponibles', '${imm.availableLines}', const Color(0xFF4CAF50)),
                const Spacer(),
                if (imm.isUsable) ...[
                  GestureDetector(
                    onTap: () => _useImmunityOnPunishment(imm),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), color: const Color(0xFF9C27B0).withOpacity(0.2)),
                      child: const Text('Utiliser', style: TextStyle(color: Color(0xFF9C27B0), fontSize: 11, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(width: 6),
                  GestureDetector(
                    onTap: () => _proposeTrade(imm),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), color: const Color(0xFFFFD700).withOpacity(0.2)),
                      child: const Text('Vendre', style: TextStyle(color: Color(0xFFFFD700), fontSize: 11, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
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
  }

  Widget _miniStat(String label, String value, Color color) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(value, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 14)),
      Text(label, style: const TextStyle(color: Colors.white38, fontSize: 10)),
    ]);
  }
}
