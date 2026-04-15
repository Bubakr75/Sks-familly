// lib/screens/punishment_lines_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/family_provider.dart';
import '../models/punishment_lines.dart';
import '../models/immunity_lines.dart';
import '../models/child_model.dart';
import '../widgets/glass_card.dart';
import '../widgets/animated_background.dart';
import '../services/gemini_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

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
  bool _showCompleted = false;
  final TextEditingController _descController = TextEditingController();
  final TextEditingController _linesController = TextEditingController();

  // ── Mode multi-sélection ──
  bool _multiSelectMode = false;
  final Set<String> _selectedChildIds = {};

  // ── Quiz IA — compteur journalier par enfant ──
  Map<String, int> _dailyQuizCount = {};
  Map<String, String> _dailyQuizDate = {};

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _fadeAnim = CurvedAnimation(parent: _controller, curve: Curves.easeIn);
    _controller.forward();
    _loadQuizCounts();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final fp = context.read<FamilyProvider>();
      if (fp.children.isNotEmpty && _selectedChildId == null) {
        setState(() => _selectedChildId = fp.children.first.id);
      }
    });
  }

  String _todayKey() {
    final now = DateTime.now();
    return '${now.year}-${now.month}-${now.day}';
  }

  Future<void> _loadQuizCounts() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('quiz_counts_daily') ?? '{}';
    final dateRaw = prefs.getString('quiz_dates_daily') ?? '{}';
    final today = _todayKey();
    final counts = Map<String, dynamic>.from(jsonDecode(raw));
    final dates = Map<String, dynamic>.from(jsonDecode(dateRaw));
    final resetCounts = <String, int>{};
    for (final entry in counts.entries) {
      // Réinitialiser si nouveau jour
      if (dates[entry.key] == today) {
        resetCounts[entry.key] = entry.value as int;
      } else {
        resetCounts[entry.key] = 0;
      }
    }
    setState(() {
      _dailyQuizCount = resetCounts;
      _dailyQuizDate = Map<String, String>.from(dates);
    });
  }

  Future<void> _incrementQuizCount(String childId) async {
    final prefs = await SharedPreferences.getInstance();
    final today = _todayKey();
    setState(() {
      _dailyQuizCount[childId] = (_dailyQuizCount[childId] ?? 0) + 1;
      _dailyQuizDate[childId] = today;
    });
    await prefs.setString('quiz_counts_daily', jsonEncode(_dailyQuizCount));
    await prefs.setString('quiz_dates_daily', jsonEncode(_dailyQuizDate));
  }

  int _getQuizCountForChild(String childId) {
    final today = _todayKey();
    if (_dailyQuizDate[childId] != today) return 0;
    return _dailyQuizCount[childId] ?? 0;
  }

  @override
  void dispose() {
    _controller.dispose();
    _descController.dispose();
    _linesController.dispose();
    super.dispose();
  }

  // ══════════════════════════════════════════════════════════════
  // BUILD PRINCIPAL
  // ══════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    return Consumer<FamilyProvider>(
      builder: (context, fp, _) {
        final children = fp.children;
        if (children.isNotEmpty && _selectedChildId == null) {
          _selectedChildId = children.first.id;
        }
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
                      style: TextStyle(color: Colors.white))),
              body: const Center(
                  child: Text('Aucun enfant enregistré',
                      style: TextStyle(color: Colors.white54))),
            ),
          );
        }

        final allPunishments = _multiSelectMode
            ? <PunishmentLines>[]
            : fp.punishments
                .where((p) => p.childId == child!.id)
                .toList();
        final active = allPunishments.where((p) => !p.isCompleted).toList();
        final completed =
            allPunishments.where((p) => p.isCompleted).toList();

        return AnimatedBackground(
          child: Scaffold(
            backgroundColor: Colors.transparent,
            appBar: AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              title: Text(
                _multiSelectMode
                    ? '👥 ${_selectedChildIds.length} sélectionné(s)'
                    : '📜 Punitions',
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold),
              ),
              actions: [
                // Bouton multi-sélection
                TextButton.icon(
                  onPressed: () {
                    setState(() {
                      _multiSelectMode = !_multiSelectMode;
                      _selectedChildIds.clear();
                      _showAddForm = false;
                    });
                  },
                  icon: Icon(
                    _multiSelectMode
                        ? Icons.close
                        : Icons.group,
                    color: _multiSelectMode
                        ? Colors.redAccent
                        : Colors.purpleAccent,
                    size: 20,
                  ),
                  label: Text(
                    _multiSelectMode ? 'Annuler' : 'Multi',
                    style: TextStyle(
                      color: _multiSelectMode
                          ? Colors.redAccent
                          : Colors.purpleAccent,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (!_multiSelectMode)
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline,
                        color: Colors.white),
                    onPressed: () =>
                        setState(() => _showAddForm = !_showAddForm),
                  ),
              ],
            ),
            body: Stack(
              children: [
                FadeTransition(
                  opacity: _fadeAnim,
                  child: Column(
                    children: [
                      // Sélecteur enfants (normal ou multi)
                      _multiSelectMode
                          ? _buildMultiChildSelector(children)
                          : _buildChildSelector(children, child!),
                      if (!_multiSelectMode && _showAddForm)
                        _buildAddForm(fp, child!),
                      // Mode normal : liste punitions
                      if (!_multiSelectMode)
                        Expanded(
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                _sectionHeader(
                                  '🔴 En cours',
                                  '${active.length} punition${active.length > 1 ? 's' : ''}',
                                  Colors.redAccent,
                                ),
                                const SizedBox(height: 8),
                                if (active.isEmpty)
                                  _emptyState(
                                      '✅', 'Aucune punition en cours !')
                                else
                                  ...active.map((p) =>
                                      _buildPunishmentCard(
                                          p, child!, fp, false)),
                                const SizedBox(height: 20),
                                GestureDetector(
                                  onTap: () => setState(() =>
                                      _showCompleted = !_showCompleted),
                                  child: _sectionHeader(
                                    '✅ Terminées',
                                    '${completed.length} punition${completed.length > 1 ? 's' : ''}',
                                    Colors.greenAccent,
                                    trailing: Icon(
                                      _showCompleted
                                          ? Icons.keyboard_arrow_up
                                          : Icons.keyboard_arrow_down,
                                      color: Colors.white54,
                                    ),
                                  ),
                                ),
                                if (_showCompleted) ...[
                                  const SizedBox(height: 8),
                                  if (completed.isEmpty)
                                    _emptyState('📋',
                                        'Aucune punition terminée')
                                  else
                                    ...completed.map((p) =>
                                        _buildPunishmentCard(
                                            p, child!, fp, true)),
                                ],
                                const SizedBox(height: 100),
                              ],
                            ),
                          ),
                        ),
                      // Mode multi : message d'aide
                      if (_multiSelectMode)
                        Expanded(
                          child: Center(
                            child: Column(
                              mainAxisAlignment:
                                  MainAxisAlignment.center,
                              children: [
                                const Text('👆',
                                    style: TextStyle(fontSize: 48)),
                                const SizedBox(height: 16),
                                const Text(
                                  'Sélectionne les enfants\nen haut pour continuer',
                                  style: TextStyle(
                                      color: Colors.white54,
                                      fontSize: 16),
                                  textAlign: TextAlign.center,
                                ),
                                if (_selectedChildIds.isNotEmpty) ...[
                                  const SizedBox(height: 24),
                                  Text(
                                    '${_selectedChildIds.length} enfant(s) sélectionné(s)',
                                    style: const TextStyle(
                                        color: Colors.purpleAccent,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                // Bandeau d'action multi-sélection en bas
                if (_multiSelectMode && _selectedChildIds.isNotEmpty)
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: _buildMultiActionBanner(fp, children),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ══════════════════════════════════════════════════════════════
  // SÉLECTEUR MULTI-ENFANTS
  // ══════════════════════════════════════════════════════════════

  Widget _buildMultiChildSelector(List<ChildModel> children) {
    return Container(
      color: Colors.black26,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '✅ Sélectionne les enfants :',
            style: TextStyle(
                color: Colors.white60,
                fontSize: 13,
                fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: children.map((c) {
                final isSelected = _selectedChildIds.contains(c.id);
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      if (isSelected) {
                        _selectedChildIds.remove(c.id);
                      } else {
                        _selectedChildIds.add(c.id);
                      }
                    });
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.only(right: 12),
                    child: Stack(
                      children: [
                        // Avatar / photo
                        Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isSelected
                                  ? Colors.purpleAccent
                                  : Colors.white24,
                              width: isSelected ? 3 : 1,
                            ),
                          ),
                          child: ClipOval(
                            child: c.photoBase64.isNotEmpty
                                ? Image.memory(
                                    Uri.parse(
                                            'data:image/jpeg;base64,${c.photoBase64}')
                                        .data!
                                        .contentAsBytes(),
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) =>
                                        _avatarFallback(c),
                                  )
                                : _avatarFallback(c),
                          ),
                        ),
                        // Case à cocher
                        Positioned(
                          top: 0,
                          right: 0,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            width: 22,
                            height: 22,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isSelected
                                  ? Colors.purpleAccent
                                  : Colors.black54,
                              border: Border.all(
                                  color: Colors.white54, width: 1.5),
                            ),
                            child: isSelected
                                ? const Icon(Icons.check,
                                    color: Colors.white, size: 14)
                                : null,
                          ),
                        ),
                        // Nom en dessous
                        Positioned(
                          bottom: -18,
                          left: 0,
                          right: 0,
                          child: Text(
                            c.name,
                            style: TextStyle(
                              color: isSelected
                                  ? Colors.purpleAccent
                                  : Colors.white60,
                              fontSize: 11,
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                            textAlign: TextAlign.center,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _avatarFallback(ChildModel c) {
    return Container(
      color: Colors.purpleAccent.withOpacity(0.2),
      child: Center(
        child: Text(
          c.avatar.isNotEmpty ? c.avatar : c.name[0].toUpperCase(),
          style: const TextStyle(fontSize: 24),
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════
  // BANDEAU D'ACTION MULTI
  // ══════════════════════════════════════════════════════════════

  Widget _buildMultiActionBanner(
      FamilyProvider fp, List<ChildModel> children) {
    final selected =
        children.where((c) => _selectedChildIds.contains(c.id)).toList();
    final names = selected.map((c) => c.name).join(', ');

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            const Color(0xFF0D1B2A).withOpacity(0.95),
            const Color(0xFF0D1B2A),
          ],
        ),
        border: const Border(
            top: BorderSide(color: Colors.white12, width: 1)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Noms des enfants sélectionnés
          Text(
            '👥 $names',
            style: const TextStyle(
                color: Colors.white70,
                fontSize: 13,
                fontWeight: FontWeight.w500),
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              // Bouton Punition groupée
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent.withOpacity(0.25),
                    foregroundColor: Colors.redAccent,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  icon: const Icon(Icons.edit_note, size: 18),
                  label: const Text('Punition groupée',
                      style: TextStyle(fontSize: 13)),
                  onPressed: () =>
                      _showGroupPunishmentDialog(fp, selected),
                ),
              ),
              const SizedBox(width: 10),
              // Bouton Immunité groupée
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        Colors.amberAccent.withOpacity(0.25),
                    foregroundColor: Colors.amberAccent,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  icon: const Icon(Icons.shield, size: 18),
                  label: const Text('Immunité groupée',
                      style: TextStyle(fontSize: 13)),
                  onPressed: () =>
                      _showGroupImmunityDialog(fp, selected),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════
  // DIALOG PUNITION GROUPÉE
  // ══════════════════════════════════════════════════════════════

  void _showGroupPunishmentDialog(
      FamilyProvider fp, List<ChildModel> selected) {
    final descCtrl = TextEditingController();
    final linesCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          backgroundColor: const Color(0xFF0D1B2A),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20)),
          title: const Text('🔴 Punition groupée',
              style: TextStyle(
                  color: Colors.white, fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Enfants sélectionnés
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.redAccent.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: Colors.redAccent.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    const Text('👥 ',
                        style: TextStyle(fontSize: 16)),
                    Expanded(
                      child: Text(
                        selected.map((c) => c.name).join(', '),
                        style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 13,
                            fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // Champ description
              TextFormField(
                controller: descCtrl,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Description de la punition *',
                  labelStyle:
                      const TextStyle(color: Colors.white54),
                  prefixIcon: const Icon(Icons.edit,
                      color: Colors.white38),
                  filled: true,
                  fillColor: Colors.white10,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 12),
              // Champ nombre de lignes
              TextFormField(
                controller: linesCtrl,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Nombre de lignes *',
                  labelStyle:
                      const TextStyle(color: Colors.white54),
                  prefixIcon: const Icon(
                      Icons.format_list_numbered,
                      color: Colors.white38),
                  filled: true,
                  fillColor: Colors.white10,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Annuler',
                  style: TextStyle(color: Colors.white38)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent.withOpacity(0.3),
                foregroundColor: Colors.redAccent,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () {
                final desc = descCtrl.text.trim();
                final lines =
                    int.tryParse(linesCtrl.text.trim()) ?? 0;
                if (desc.isEmpty || lines <= 0) return;
                Navigator.pop(ctx);
                _confirmGroupPunishment(fp, selected, desc, lines);
              },
              child: const Text('Suivant →'),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmGroupPunishment(FamilyProvider fp,
      List<ChildModel> selected, String desc, int lines) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF0D1B2A),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
        title: const Text('✅ Confirmer',
            style: TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.redAccent.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: Colors.redAccent.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('📝 $desc',
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  Text('$lines lignes à copier',
                      style: const TextStyle(
                          color: Colors.white60, fontSize: 13)),
                ],
              ),
            ),
            const SizedBox(height: 12),
            const Text('Sera appliqué à :',
                style:
                    TextStyle(color: Colors.white54, fontSize: 13)),
            const SizedBox(height: 8),
            ...selected.map((c) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    children: [
                      Text(c.avatar.isNotEmpty ? c.avatar : '🧒',
                          style: const TextStyle(fontSize: 16)),
                      const SizedBox(width: 8),
                      Text(c.name,
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w500)),
                    ],
                  ),
                )),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler',
                style: TextStyle(color: Colors.white38)),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent.withOpacity(0.3),
              foregroundColor: Colors.redAccent,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            icon: const Icon(Icons.check, size: 16),
            label: Text(
                'Appliquer à ${selected.length} enfant(s)'),
            onPressed: () async {
              Navigator.pop(context);
              for (final c in selected) {
                await fp.addPunishment(c.id, desc, lines);
              }
              setState(() {
                _multiSelectMode = false;
                _selectedChildIds.clear();
              });
              if (mounted) {
                ScaffoldMessenger.of(context)
                    .showSnackBar(SnackBar(
                  content: Text(
                      '🔴 Punition appliquée à ${selected.length} enfant(s) !'),
                  backgroundColor:
                      Colors.redAccent.withOpacity(0.8),
                ));
              }
            },
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════
  // DIALOG IMMUNITÉ GROUPÉE
  // ══════════════════════════════════════════════════════════════

  void _showGroupImmunityDialog(
      FamilyProvider fp, List<ChildModel> selected) {
    final reasonCtrl = TextEditingController();
    int lines = 5;

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          backgroundColor: const Color(0xFF0D1B2A),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20)),
          title: const Text('🛡️ Immunité groupée',
              style: TextStyle(
                  color: Colors.white, fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Enfants sélectionnés
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.amberAccent.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: Colors.amberAccent.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    const Text('👥 ',
                        style: TextStyle(fontSize: 16)),
                    Expanded(
                      child: Text(
                        selected.map((c) => c.name).join(', '),
                        style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 13,
                            fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // Raison
              TextFormField(
                controller: reasonCtrl,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Raison de l\'immunité *',
                  labelStyle:
                      const TextStyle(color: Colors.white54),
                  prefixIcon: const Icon(Icons.shield,
                      color: Colors.amberAccent),
                  filled: true,
                  fillColor: Colors.white10,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 16),
              // Nombre de lignes
              Text(
                  'Lignes d\'immunité : $lines',
                  style:
                      const TextStyle(color: Colors.white70)),
              Slider(
                value: lines.toDouble(),
                min: 1,
                max: 50,
                divisions: 49,
                label: '$lines',
                activeColor: Colors.amberAccent,
                onChanged: (v) =>
                    setDlgState(() => lines = v.round()),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Annuler',
                  style: TextStyle(color: Colors.white38)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    Colors.amberAccent.withOpacity(0.3),
                foregroundColor: Colors.amberAccent,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () {
                final reason = reasonCtrl.text.trim();
                if (reason.isEmpty) return;
                Navigator.pop(ctx);
                _confirmGroupImmunity(
                    fp, selected, reason, lines);
              },
              child: const Text('Suivant →'),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmGroupImmunity(FamilyProvider fp,
      List<ChildModel> selected, String reason, int lines) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF0D1B2A),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
        title: const Text('✅ Confirmer',
            style: TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.amberAccent.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: Colors.amberAccent.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('🛡️ $reason',
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  Text('$lines ligne(s) d\'immunité chacun',
                      style: const TextStyle(
                          color: Colors.white60, fontSize: 13)),
                ],
              ),
            ),
            const SizedBox(height: 12),
            const Text('Sera accordé à :',
                style:
                    TextStyle(color: Colors.white54, fontSize: 13)),
            const SizedBox(height: 8),
            ...selected.map((c) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    children: [
                      Text(c.avatar.isNotEmpty ? c.avatar : '🧒',
                          style: const TextStyle(fontSize: 16)),
                      const SizedBox(width: 8),
                      Text(c.name,
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w500)),
                    ],
                  ),
                )),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler',
                style: TextStyle(color: Colors.white38)),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor:
                  Colors.amberAccent.withOpacity(0.3),
              foregroundColor: Colors.amberAccent,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            icon: const Icon(Icons.check, size: 16),
            label: Text(
                'Accorder à ${selected.length} enfant(s)'),
            onPressed: () async {
              Navigator.pop(context);
              for (final c in selected) {
                await fp.addImmunity(c.id, reason, lines);
              }
              setState(() {
                _multiSelectMode = false;
                _selectedChildIds.clear();
              });
              if (mounted) {
                ScaffoldMessenger.of(context)
                    .showSnackBar(SnackBar(
                  content: Text(
                      '🛡️ Immunité accordée à ${selected.length} enfant(s) !'),
                  backgroundColor:
                      Colors.amberAccent.withOpacity(0.8),
                ));
              }
            },
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════
  // WIDGETS UTILITAIRES
  // ══════════════════════════════════════════════════════════════

  Widget _sectionHeader(String title, String subtitle, Color color,
      {Widget? trailing}) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 32,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16)),
              Text(subtitle,
                  style: const TextStyle(
                      color: Colors.white38, fontSize: 12)),
            ],
          ),
        ),
        if (trailing != null) trailing,
      ],
    );
  }

  Widget _emptyState(String emoji, String message) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Center(
        child: Column(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 40)),
            const SizedBox(height: 8),
            Text(message,
                style: const TextStyle(
                    color: Colors.white54, fontSize: 14)),
          ],
        ),
      ),
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
    final lines = int.tryParse(_linesController.text.trim()) ?? 0;
    if (desc.isEmpty || lines <= 0) return;
    await fp.addPunishment(child.id, desc, lines);
    _descController.clear();
    _linesController.clear();
    setState(() => _showAddForm = false);
  }

  Widget _buildPunishmentCard(PunishmentLines p, ChildModel child,
      FamilyProvider fp, bool isCompleted) {
    final progress = p.progress;
    final remaining = p.totalLines - p.completedLines;
    final totalImmunity = fp.getTotalAvailableImmunity(child.id);
    final quizCount = _getQuizCountForChild(child.id);
    final quizAvailable = quizCount < 3;

    return GlassCard(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      child: Opacity(
        opacity: isCompleted ? 0.65 : 1.0,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isCompleted
                        ? Colors.greenAccent
                        : Colors.redAccent,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(p.text,
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          decoration: isCompleted
                              ? TextDecoration.lineThrough
                              : null)),
                ),
                IconButton(
                  icon: Icon(Icons.delete_outline,
                      color: isCompleted
                          ? Colors.white24
                          : Colors.redAccent),
                  onPressed: () => _confirmDelete(p, fp),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Text('${p.completedLines} / ${p.totalLines} lignes',
                    style: const TextStyle(
                        color: Colors.white70, fontSize: 13)),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: isCompleted
                        ? Colors.greenAccent.withOpacity(0.15)
                        : Colors.white10,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    isCompleted
                        ? '✅ Terminée'
                        : '${(progress * 100).round()}%',
                    style: TextStyle(
                        color: isCompleted
                            ? Colors.greenAccent
                            : Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress,
                backgroundColor: Colors.white12,
                valueColor: AlwaysStoppedAnimation(isCompleted
                    ? Colors.greenAccent
                    : const Color(0xFF7C4DFF)),
                minHeight: 8,
              ),
            ),
            if (!isCompleted) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(
                            color: Color(0xFF7C4DFF)),
                        foregroundColor: const Color(0xFF7C4DFF),
                        shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(10)),
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
                            borderRadius:
                                BorderRadius.circular(10)),
                      ),
                      icon: const Icon(Icons.check_circle,
                          size: 16),
                      label: const Text('Terminer'),
                      onPressed: () =>
                          _completePunishment(p, fp),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              const Divider(color: Colors.white12),
              const Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: Text('💡 Réduire via :',
                    style: TextStyle(
                        color: Colors.white54,
                        fontSize: 12,
                        fontWeight: FontWeight.w600)),
              ),
              _reductionButton(
                icon: Icons.shield,
                label: totalImmunity > 0
                    ? '🛡️ Immunité ($totalImmunity lignes dispo)'
                    : '🛡️ Aucune immunité disponible',
                color: Colors.amberAccent,
                enabled: totalImmunity > 0 && remaining > 0,
                onTap: () => _showImmunityPicker(p, child, fp),
              ),
              const SizedBox(height: 8),
              _reductionButton(
                icon: Icons.handyman,
                label: '🔧 Proposer un service',
                color: Colors.lightBlueAccent,
                enabled: remaining > 0,
                onTap: () => _showServiceDialog(p, child, fp),
              ),
              const SizedBox(height: 8),
              _reductionButton(
                icon: Icons.school,
                label: '📚 Bonne note scolaire',
                color: Colors.greenAccent,
                enabled: remaining > 0,
                onTap: () => _showSchoolNoteDialog(p, child, fp),
              ),
              const SizedBox(height: 8),
              _reductionButton(
                icon: Icons.psychology,
                label: quizAvailable
                    ? '🧠 Quiz IA Gemini ($quizCount/3 aujourd\'hui)'
                    : '🧠 Quiz IA — Limite atteinte (3/3)',
                color: Colors.purpleAccent,
                enabled: quizAvailable && remaining > 0,
                onTap: () =>
                    _showQuizThemePicker(p, child, fp),
              ),
            ],
          ],
        ),
      ),
    );
  }

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
          backgroundColor:
              enabled ? color.withOpacity(0.15) : Colors.white10,
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

  // ══════════════════════════════════════════════════════════════
  // QUIZ IA GEMINI
  // ══════════════════════════════════════════════════════════════

  void _showQuizThemePicker(
      PunishmentLines p, ChildModel child, FamilyProvider fp) {
    final List<Map<String, String>> defaultThemes = [
      {'emoji': '🏛️', 'label': 'Histoire'},
      {'emoji': '🔬', 'label': 'Science'},
      {'emoji': '🌿', 'label': 'Nature'},
      {'emoji': '⚽', 'label': 'Sport'},
      {'emoji': '🌍', 'label': 'Géographie'},
      {'emoji': '🎬', 'label': 'Cinéma'},
      {'emoji': '🐾', 'label': 'Animaux'},
      {'emoji': '🎯', 'label': 'Culture générale'},
      {'emoji': '➕', 'label': 'Mathématiques'},
      {'emoji': '📺', 'label': 'Dessins animés'},
      {'emoji': '🦸', 'label': 'Marvel / Avengers'},
      {'emoji': '🐉', 'label': 'Pokémon'},
      {'emoji': '🏰', 'label': 'Disney'},
      {'emoji': '🎮', 'label': 'Jeux vidéo'},
      {'emoji': '⛏️', 'label': 'Minecraft'},
      {'emoji': '🟥', 'label': 'Roblox'},
      {'emoji': '🏴‍☠️', 'label': 'One Piece'},
      {'emoji': '🐲', 'label': 'Dragon Ball'},
      {'emoji': '🎯', 'label': 'Fortnite'},
      {'emoji': '🍌', 'label': 'Les Minions'},
      {'emoji': '🐾', 'label': 'Pat\'Patrouille'},
    ];

    // ── Étape 1 : choix de la difficulté PUIS du thème ──
    String? selectedDifficulty;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          Future<List<Map<String, String>>> loadCustomThemes() async {
            final prefs = await SharedPreferences.getInstance();
            final raw =
                prefs.getString('custom_quiz_themes') ?? '[]';
            final List<dynamic> decoded = jsonDecode(raw);
            return decoded
                .map((e) => Map<String, String>.from(e as Map))
                .toList();
          }

          void addCustomTheme() {
            final ctrl = TextEditingController();
            showDialog(
              context: context,
              builder: (_) => AlertDialog(
                backgroundColor: const Color(0xFF1A1A2E),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                title: const Text('➕ Nouveau thème',
                    style: TextStyle(color: Colors.white)),
                content: TextFormField(
                  controller: ctrl,
                  autofocus: true,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Ex : Naruto, SpongeBob...',
                    labelStyle:
                        const TextStyle(color: Colors.white54),
                    filled: true,
                    fillColor: Colors.white10,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none),
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Annuler',
                        style: TextStyle(color: Colors.white38)),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                        backgroundColor:
                            Colors.purpleAccent.withOpacity(0.3),
                        foregroundColor: Colors.purpleAccent),
                    onPressed: () async {
                      final label = ctrl.text.trim();
                      if (label.isEmpty) return;
                      final prefs =
                          await SharedPreferences.getInstance();
                      final raw = prefs
                              .getString('custom_quiz_themes') ??
                          '[]';
                      final List<dynamic> existing =
                          jsonDecode(raw);
                      existing
                          .add({'emoji': '✨', 'label': label});
                      await prefs.setString(
                          'custom_quiz_themes',
                          jsonEncode(existing));
                      if (mounted) {
                        Navigator.pop(context);
                        setSheetState(() {});
                      }
                    },
                    child: const Text('Ajouter'),
                  ),
                ],
              ),
            );
          }

          return FutureBuilder<List<Map<String, String>>>(
            future: loadCustomThemes(),
            builder: (ctx, snapshot) {
              final custom = snapshot.data ?? [];
              final allThemes = [...defaultThemes, ...custom];

              return DraggableScrollableSheet(
                initialChildSize: 0.85,
                minChildSize: 0.5,
                maxChildSize: 0.95,
                expand: false,
                builder: (_, scrollCtrl) => Container(
                  decoration: const BoxDecoration(
                    color: Color(0xFF0D1B2A),
                    borderRadius: BorderRadius.vertical(
                        top: Radius.circular(24)),
                  ),
                  child: ListView(
                    controller: scrollCtrl,
                    padding: const EdgeInsets.all(20),
                    children: [
                      // Handle
                      Center(
                        child: Container(
                            width: 40,
                            height: 4,
                            decoration: BoxDecoration(
                                color: Colors.white38,
                                borderRadius:
                                    BorderRadius.circular(2))),
                      ),
                      const SizedBox(height: 16),
                      const Text('🧠 Quiz IA Gemini',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center),
                      const SizedBox(height: 4),
                      Text(
                        '${child.name} · 3 questions · ${child.effectiveAge} ans',
                        style: const TextStyle(
                            color: Colors.white54, fontSize: 13),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 20),

                      // ── ÉTAPE 1 : Difficulté ──
                      const Text('1️⃣ Choisis la difficulté :',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 15)),
                      const SizedBox(height: 10),
                      ...[
                        {
                          'key': 'facile',
                          'label': '🟢 Facile',
                          'sub': '1 bonne réponse = 10 lignes retirées',
                          'color': Colors.greenAccent,
                        },
                        {
                          'key': 'moyen',
                          'label': '🟡 Moyen',
                          'sub': '1 bonne réponse = 20 lignes retirées',
                          'color': Colors.amberAccent,
                        },
                        {
                          'key': 'difficile',
                          'label': '🔴 Difficile',
                          'sub': '1 bonne réponse = 40 lignes retirées',
                          'color': Colors.redAccent,
                        },
                      ].map((d) {
                        final isSelected =
                            selectedDifficulty == d['key'];
                        final color = d['color'] as Color;
                        return GestureDetector(
                          onTap: () => setSheetState(
                              () => selectedDifficulty =
                                  d['key'] as String),
                          child: AnimatedContainer(
                            duration:
                                const Duration(milliseconds: 200),
                            margin:
                                const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? color.withOpacity(0.2)
                                  : Colors.white10,
                              borderRadius:
                                  BorderRadius.circular(14),
                              border: Border.all(
                                  color: isSelected
                                      ? color
                                      : Colors.white12,
                                  width: isSelected ? 2 : 1),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                          d['label'] as String,
                                          style: TextStyle(
                                              color: isSelected
                                                  ? color
                                                  : Colors.white,
                                              fontWeight:
                                                  FontWeight.bold,
                                              fontSize: 15)),
                                      const SizedBox(height: 2),
                                      Text(d['sub'] as String,
                                          style: TextStyle(
                                              color: isSelected
                                                  ? color
                                                      .withOpacity(
                                                          0.8)
                                                  : Colors.white38,
                                              fontSize: 12)),
                                    ],
                                  ),
                                ),
                                if (isSelected)
                                  Icon(Icons.check_circle,
                                      color: color, size: 22),
                              ],
                            ),
                          ),
                        );
                      }),

                      if (selectedDifficulty != null) ...[
                        const SizedBox(height: 20),
                        const Divider(color: Colors.white12),
                        const SizedBox(height: 16),

                        // ── ÉTAPE 2 : Thème ──
                        Row(
                          mainAxisAlignment:
                              MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('2️⃣ Choisis le thème :',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15)),
                            GestureDetector(
                              onTap: addCustomTheme,
                              child: Container(
                                padding:
                                    const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 5),
                                decoration: BoxDecoration(
                                  color: Colors.purpleAccent
                                      .withOpacity(0.15),
                                  borderRadius:
                                      BorderRadius.circular(20),
                                  border: Border.all(
                                      color: Colors.purpleAccent
                                          .withOpacity(0.4)),
                                ),
                                child: const Row(
                                  children: [
                                    Icon(Icons.add,
                                        color: Colors.purpleAccent,
                                        size: 14),
                                    SizedBox(width: 4),
                                    Text('Mon thème',
                                        style: TextStyle(
                                            color:
                                                Colors.purpleAccent,
                                            fontSize: 12,
                                            fontWeight:
                                                FontWeight.w600)),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        GridView.builder(
                          shrinkWrap: true,
                          physics:
                              const NeverScrollableScrollPhysics(),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            mainAxisSpacing: 10,
                            crossAxisSpacing: 10,
                            childAspectRatio: 2.2,
                          ),
                          itemCount: allThemes.length,
                          itemBuilder: (_, i) {
                            final theme = allThemes[i];
                            final isCustom =
                                i >= defaultThemes.length;
                            return GestureDetector(
                              onTap: () {
                                Navigator.pop(context);
                                _startQuiz(p, child, fp,
                                    theme['label']!,
                                    selectedDifficulty!);
                              },
                              onLongPress: isCustom
                                  ? () async {
                                      final prefs =
                                          await SharedPreferences
                                              .getInstance();
                                      final raw = prefs.getString(
                                              'custom_quiz_themes') ??
                                          '[]';
                                      final List<dynamic>
                                          existing =
                                          jsonDecode(raw);
                                      existing.removeWhere((e) =>
                                          e['label'] ==
                                          theme['label']);
                                      await prefs.setString(
                                          'custom_quiz_themes',
                                          jsonEncode(existing));
                                      setSheetState(() {});
                                    }
                                  : null,
                              child: Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: isCustom
                                        ? [
                                            Colors.purpleAccent
                                                .withOpacity(0.35),
                                            Colors.pinkAccent
                                                .withOpacity(0.2),
                                          ]
                                        : [
                                            Colors.purpleAccent
                                                .withOpacity(0.2),
                                            Colors.blueAccent
                                                .withOpacity(0.15),
                                          ],
                                  ),
                                  borderRadius:
                                      BorderRadius.circular(14),
                                  border: Border.all(
                                      color: isCustom
                                          ? Colors.purpleAccent
                                              .withOpacity(0.5)
                                          : Colors.purpleAccent
                                              .withOpacity(0.3)),
                                ),
                                child: Stack(
                                  children: [
                                    Center(
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment
                                                .center,
                                        children: [
                                          Text(theme['emoji']!,
                                              style: const TextStyle(
                                                  fontSize: 22)),
                                          const SizedBox(width: 6),
                                          Flexible(
                                            child: Text(
                                              theme['label']!,
                                              style: const TextStyle(
                                                  color: Colors.white,
                                                  fontWeight:
                                                      FontWeight.w600,
                                                  fontSize: 13),
                                              overflow: TextOverflow
                                                  .ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (isCustom)
                                      Positioned(
                                        top: 4,
                                        right: 6,
                                        child: Container(
                                          padding: const EdgeInsets
                                              .symmetric(
                                              horizontal: 5,
                                              vertical: 1),
                                          decoration: BoxDecoration(
                                            color: Colors.purpleAccent
                                                .withOpacity(0.4),
                                            borderRadius:
                                                BorderRadius.circular(
                                                    6),
                                          ),
                                          child: const Text(
                                              '✨ perso',
                                              style: TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 8)),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                        if (custom.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              '💡 Appuie longuement sur ✨ perso pour supprimer',
                              style: TextStyle(
                                  color: Colors.white38,
                                  fontSize: 11),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        const SizedBox(height: 20),
                      ],
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _startQuiz(PunishmentLines p, ChildModel child,
      FamilyProvider fp, String theme, String difficulty) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(
                color: Colors.purpleAccent),
            const SizedBox(height: 16),
            const Text('🧠 Gemini prépare le quiz...',
                style: TextStyle(color: Colors.white)),
            const SizedBox(height: 4),
            Text(
              'Niveau $difficulty · ${child.effectiveAge} ans',
              style: const TextStyle(
                  color: Colors.white54, fontSize: 12),
            ),
          ],
        ),
      ),
    );

    try {
      final questions = await GeminiService.generateQuizQuestions(
        theme: theme,
        age: child.effectiveAge,
        difficulty: difficulty,
      );
      if (mounted) Navigator.pop(context);

      if (questions.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('❌ Aucune question reçue de Gemini'),
            backgroundColor: Colors.redAccent,
            duration: Duration(seconds: 10),
          ));
        }
        return;
      }

      if (mounted) {
        _showQuizDialog(p, child, fp, questions, theme, difficulty);
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('❌ Erreur : $e'),
          backgroundColor: Colors.redAccent,
          duration: const Duration(seconds: 15),
        ));
      }
    }
  }

  void _showQuizDialog(
      PunishmentLines p,
      ChildModel child,
      FamilyProvider fp,
      List<Map<String, dynamic>> questions,
      String theme,
      String difficulty) {
    int currentIndex = 0;
    int score = 0;
    int? selectedAnswer;
    bool answered = false;

    // Lignes par bonne réponse selon difficulté
    int linesPerAnswer;
    Color diffColor;
    switch (difficulty) {
      case 'difficile':
        linesPerAnswer = 40;
        diffColor = Colors.redAccent;
        break;
      case 'moyen':
        linesPerAnswer = 20;
        diffColor = Colors.amberAccent;
        break;
      default:
        linesPerAnswer = 10;
        diffColor = Colors.greenAccent;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final q = questions[currentIndex];
          final List<String> choices =
              List<String>.from(q['choices'] as List);
          final int correct = q['correct'] as int;

          return Dialog(
            backgroundColor: const Color(0xFF0D1B2A),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20)),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header
                  Row(
                    mainAxisAlignment:
                        MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: diffColor.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'Q${currentIndex + 1}/${questions.length} · $difficulty',
                          style: TextStyle(
                              color: diffColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 12),
                        ),
                      ),
                      // Indicateur +X lignes par réponse
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.purpleAccent.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '+$linesPerAnswer lignes / bonne rép.',
                          style: const TextStyle(
                              color: Colors.purpleAccent,
                              fontSize: 10,
                              fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Points de progression
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      questions.length,
                      (i) => Container(
                        margin: const EdgeInsets.only(left: 4),
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: i < currentIndex
                              ? Colors.purpleAccent
                              : i == currentIndex
                                  ? Colors.white
                                  : Colors.white24,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(theme,
                      style: const TextStyle(
                          color: Colors.white54, fontSize: 12)),
                  const SizedBox(height: 8),
                  Text(
                    q['question'] as String,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  // Choix
                  ...choices.asMap().entries.map((entry) {
                    final idx = entry.key;
                    final choice = entry.value;
                    Color btnColor = Colors.white10;
                    Color txtColor = Colors.white70;
                    if (answered) {
                      if (idx == correct) {
                        btnColor =
                            Colors.greenAccent.withOpacity(0.25);
                        txtColor = Colors.greenAccent;
                      } else if (idx == selectedAnswer) {
                        btnColor =
                            Colors.redAccent.withOpacity(0.25);
                        txtColor = Colors.redAccent;
                      }
                    } else if (idx == selectedAnswer) {
                      btnColor =
                          Colors.purpleAccent.withOpacity(0.25);
                      txtColor = Colors.purpleAccent;
                    }

                    return GestureDetector(
                      onTap: answered
                          ? null
                          : () {
                              setDialogState(() {
                                selectedAnswer = idx;
                                answered = true;
                                if (idx == correct) score++;
                              });
                            },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: btnColor,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: answered && idx == correct
                                  ? Colors.greenAccent
                                      .withOpacity(0.5)
                                  : Colors.white12),
                        ),
                        child: Row(
                          children: [
                            Text(
                              ['A', 'B', 'C', 'D'][idx],
                              style: TextStyle(
                                  color: txtColor,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(choice,
                                  style: TextStyle(
                                      color: txtColor,
                                      fontSize: 13)),
                            ),
                            if (answered && idx == correct)
                              const Icon(Icons.check_circle,
                                  color: Colors.greenAccent,
                                  size: 16),
                            if (answered &&
                                idx == selectedAnswer &&
                                idx != correct)
                              const Icon(Icons.cancel,
                                  color: Colors.redAccent,
                                  size: 16),
                          ],
                        ),
                      ),
                    );
                  }),
                  const SizedBox(height: 16),
                  if (answered)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              Colors.purpleAccent.withOpacity(0.3),
                          foregroundColor: Colors.purpleAccent,
                          shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(
                              vertical: 12),
                        ),
                        onPressed: () {
                          if (currentIndex <
                              questions.length - 1) {
                            setDialogState(() {
                              currentIndex++;
                              selectedAnswer = null;
                              answered = false;
                            });
                          } else {
                            Navigator.pop(dialogContext);
                            _showQuizResult(p, child, fp, score,
                                questions.length, linesPerAnswer,
                                difficulty);
                          }
                        },
                        child: Text(
                          currentIndex < questions.length - 1
                              ? 'Question suivante →'
                              : 'Voir les résultats 🏆',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold),
                        ),
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

  void _showQuizResult(
      PunishmentLines p,
      ChildModel child,
      FamilyProvider fp,
      int score,
      int total,
      int linesPerAnswer,
      String difficulty) {
    final remaining = p.totalLines - p.completedLines;
    final linesEarned =
        (score * linesPerAnswer).clamp(0, remaining);
    final isPerfect = score == total;

    // Bonus immunité si score parfait
    int bonusImmunity;
    switch (difficulty) {
      case 'difficile':
        bonusImmunity = isPerfect ? 3 : 0;
        break;
      case 'moyen':
        bonusImmunity = isPerfect ? 2 : 0;
        break;
      default:
        bonusImmunity = isPerfect ? 1 : 0;
    }

    String emoji;
    String message;
    if (isPerfect) {
      emoji = '🏆';
      message = 'PARFAIT ! ${child.name} a tout bon !';
    } else if (score >= total - 1) {
      emoji = '😊';
      message = 'Très bien ! Presque parfait !';
    } else if (score > 0) {
      emoji = '👍';
      message = 'Pas mal ! Continue comme ça !';
    } else {
      emoji = '😅';
      message = 'Dommage ! On réessaie demain !';
    }

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF0D1B2A),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
        title: Column(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 52)),
            const SizedBox(height: 8),
            Text('Résultats du Quiz',
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 18),
                textAlign: TextAlign.center),
            if (isPerfect)
              Container(
                margin: const EdgeInsets.only(top: 8),
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [
                    Colors.purpleAccent,
                    Colors.amberAccent
                  ]),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text('⭐ SCORE PARFAIT ⭐',
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12)),
              ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message,
                style: const TextStyle(
                    color: Colors.white70, fontSize: 14),
                textAlign: TextAlign.center),
            const SizedBox(height: 16),
            // Récap score
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.purpleAccent.withOpacity(0.1),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                    color:
                        Colors.purpleAccent.withOpacity(0.3)),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment:
                        MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Score :',
                          style:
                              TextStyle(color: Colors.white60)),
                      Text('$score / $total',
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 20)),
                    ],
                  ),
                  const Divider(
                      color: Colors.white12, height: 16),
                  Row(
                    mainAxisAlignment:
                        MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Lignes retirées :',
                          style:
                              TextStyle(color: Colors.white60)),
                      Text('-$linesEarned lignes',
                          style: const TextStyle(
                              color: Colors.greenAccent,
                              fontWeight: FontWeight.bold,
                              fontSize: 18)),
                    ],
                  ),
                  if (isPerfect && bonusImmunity > 0) ...[
                    const Divider(
                        color: Colors.white12, height: 16),
                    Row(
                      mainAxisAlignment:
                          MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('🛡️ Bonus immunité :',
                            style: TextStyle(
                                color: Colors.amberAccent)),
                        Text(
                            '+$bonusImmunity immunité(s) !',
                            style: const TextStyle(
                                color: Colors.amberAccent,
                                fontWeight: FontWeight.bold,
                                fontSize: 15)),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
        actions: [
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor:
                  Colors.purpleAccent.withOpacity(0.25),
              foregroundColor: Colors.purpleAccent,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            icon: const Icon(Icons.check, size: 16),
            label: Text(linesEarned > 0
                ? 'Valider -$linesEarned ligne(s)'
                : 'Fermer'),
            onPressed: () async {
              Navigator.pop(dialogContext);
              // Retirer les lignes de punition
              if (linesEarned > 0) {
                await fp.updatePunishmentProgress(
                    p.id, linesEarned);
              }
              // Ajouter bonus immunité si score parfait
              if (isPerfect && bonusImmunity > 0) {
                await fp.addImmunity(
                  child.id,
                  '🏆 Quiz parfait ($difficulty) — Bonus',
                  bonusImmunity,
                );
              }
              await _incrementQuizCount(child.id);
              if (mounted) {
                ScaffoldMessenger.of(context)
                    .showSnackBar(SnackBar(
                  content: Text(linesEarned > 0
                      ? isPerfect && bonusImmunity > 0
                          ? '🏆 Parfait ! -$linesEarned lignes + $bonusImmunity immunité(s) bonus !'
                          : '🧠 Quiz validé ! -$linesEarned ligne(s) !'
                      : '🧠 Quiz terminé — courage pour la prochaine fois !'),
                  backgroundColor:
                      Colors.purpleAccent.withOpacity(0.8),
                ));
              }
            },
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════
  // MÉTHODES UTILITAIRES
  // ══════════════════════════════════════════════════════════════

  void _advanceLines(PunishmentLines p, FamilyProvider fp) {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        title: const Text('Avancer les lignes',
            style: TextStyle(color: Colors.white)),
        content: TextFormField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            labelText: 'Nombre de lignes faites',
            labelStyle: const TextStyle(color: Colors.white54),
            filled: true,
            fillColor: Colors.white10,
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annuler',
                  style: TextStyle(color: Colors.white38))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF7C4DFF)),
            onPressed: () async {
              final n = int.tryParse(ctrl.text.trim()) ?? 0;
              if (n > 0) {
                await fp.updatePunishmentProgress(p.id, n);
                if (mounted) Navigator.pop(context);
              }
            },
            child: const Text('Valider'),
          ),
        ],
      ),
    );
  }

  void _completePunishment(PunishmentLines p, FamilyProvider fp) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        title: const Text('Terminer la punition ?',
            style: TextStyle(color: Colors.white)),
        content: Text('Marquer "${p.text}" comme terminée ?',
            style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annuler',
                  style: TextStyle(color: Colors.white38))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor:
                    Colors.greenAccent.withOpacity(0.3),
                foregroundColor: Colors.greenAccent),
            onPressed: () async {
              final remaining =
                  p.totalLines - p.completedLines;
              if (remaining > 0) {
                await fp.updatePunishmentProgress(
                    p.id, remaining);
              }
              if (mounted) Navigator.pop(context);
            },
            child: const Text('Terminer'),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(PunishmentLines p, FamilyProvider fp) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        title: const Text('Supprimer ?',
            style: TextStyle(color: Colors.white)),
        content: Text(
            'Supprimer "${p.text}" définitivement ?',
            style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annuler',
                  style: TextStyle(color: Colors.white38))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor:
                    Colors.redAccent.withOpacity(0.3),
                foregroundColor: Colors.redAccent),
            onPressed: () async {
              await fp.deletePunishment(p.id);
              if (mounted) Navigator.pop(context);
            },
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
  }

  void _showServiceDialog(
      PunishmentLines p, ChildModel child, FamilyProvider fp) {
    final serviceCtrl = TextEditingController();
    final linesCtrl = TextEditingController();
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
                        borderRadius: BorderRadius.circular(2))),
                const SizedBox(height: 16),
                const Text('🔧 Service rendu',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(
                    '${p.totalLines - p.completedLines} lignes restantes',
                    style: const TextStyle(
                        color: Colors.white54, fontSize: 12)),
                const SizedBox(height: 16),
                Expanded(
                  child: ListView(
                    controller: scrollCtrl,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16),
                    children: [
                      const Text('Suggestions :',
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
                              padding:
                                  const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 6),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? Colors.lightBlueAccent
                                        .withOpacity(0.25)
                                    : Colors.white10,
                                borderRadius:
                                    BorderRadius.circular(20),
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
                      TextFormField(
                        controller: serviceCtrl,
                        style:
                            const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: 'Ou décris le service...',
                          labelStyle: const TextStyle(
                              color: Colors.white54),
                          filled: true,
                          fillColor: Colors.white10,
                          border: OutlineInputBorder(
                              borderRadius:
                                  BorderRadius.circular(12),
                              borderSide: BorderSide.none),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: linesCtrl,
                        keyboardType: TextInputType.number,
                        style:
                            const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText:
                              'Lignes à retirer (max ${p.totalLines - p.completedLines})',
                          labelStyle: const TextStyle(
                              color: Colors.white54),
                          prefixIcon: const Icon(
                              Icons.remove_circle_outline,
                              color: Colors.lightBlueAccent),
                          filled: true,
                          fillColor: Colors.white10,
                          border: OutlineInputBorder(
                              borderRadius:
                                  BorderRadius.circular(12),
                              borderSide: BorderSide.none),
                        ),
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.lightBlueAccent
                              .withOpacity(0.25),
                          foregroundColor:
                              Colors.lightBlueAccent,
                          padding: const EdgeInsets.symmetric(
                              vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(12)),
                        ),
                        icon: const Icon(Icons.check),
                        label: const Text('Valider le service'),
                        onPressed: () {
                          final service =
                              serviceCtrl.text.trim();
                          final lines = int.tryParse(
                                  linesCtrl.text.trim()) ??
                              0;
                          final maxLines = p.totalLines -
                              p.completedLines;
                          if (service.isEmpty || lines <= 0)
                            return;
                          final actual =
                              lines.clamp(0, maxLines);
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

  void _confirmServiceReduction(PunishmentLines p,
      ChildModel child, FamilyProvider fp, String service,
      int lines) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        title: const Text('Confirmer le service',
            style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.lightBlueAccent.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: Colors.lightBlueAccent
                        .withOpacity(0.3)),
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
                      '$lines ligne(s) retirée(s) de "${p.text}"',
                      style: const TextStyle(
                          color: Colors.white60,
                          fontSize: 12)),
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
                backgroundColor:
                    Colors.lightBlueAccent.withOpacity(0.25),
                foregroundColor: Colors.lightBlueAccent),
            onPressed: () async {
              await fp.updatePunishmentProgress(p.id, lines);
              if (mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context)
                    .showSnackBar(SnackBar(
                  content: Text(
                      '🔧 Service validé ! $lines ligne(s) retirée(s)'),
                  backgroundColor:
                      Colors.lightBlueAccent.withOpacity(0.8),
                ));
              }
            },
            child: const Text('Confirmer'),
          ),
        ],
      ),
    );
  }

  void _showSchoolNoteDialog(
      PunishmentLines p, ChildModel child, FamilyProvider fp) {
    double note = 15;
    int getLinesFromNote(double n) {
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
          final reduction = getLinesFromNote(note);
          final maxLines = p.totalLines - p.completedLines;
          final actual = reduction.clamp(0, maxLines);
          return DraggableScrollableSheet(
            initialChildSize: 0.55,
            minChildSize: 0.4,
            maxChildSize: 0.85,
            expand: false,
            builder: (_, scrollCtrl) => Container(
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
                          borderRadius:
                              BorderRadius.circular(2))),
                  const SizedBox(height: 16),
                  const Text('📚 Bonne note scolaire',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text('$maxLines lignes restantes',
                      style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 12)),
                  const SizedBox(height: 20),
                  Expanded(
                    child: ListView(
                      controller: scrollCtrl,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20),
                      children: [
                        Row(
                          mainAxisAlignment:
                              MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Note obtenue :',
                                style: TextStyle(
                                    color: Colors.white60,
                                    fontSize: 13)),
                            Text(
                                '${note.toStringAsFixed(1)} / 20',
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
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color:
                                Colors.white.withOpacity(0.05),
                            borderRadius:
                                BorderRadius.circular(12),
                            border: Border.all(
                                color: Colors.white12),
                          ),
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              const Text('📊 Barème :',
                                  style: TextStyle(
                                      color: Colors.white60,
                                      fontSize: 12,
                                      fontWeight:
                                          FontWeight.w600)),
                              const SizedBox(height: 8),
                              _baremeRow('18 – 20', '5 lignes',
                                  note >= 18),
                              _baremeRow('15 – 17', '3 lignes',
                                  note >= 15 && note < 18),
                              _baremeRow('12 – 14', '1 ligne',
                                  note >= 12 && note < 15),
                              _baremeRow(
                                  '< 12',
                                  'Aucune réduction',
                                  note < 12),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: actual > 0
                                ? Colors.greenAccent
                                    .withOpacity(0.1)
                                : Colors.white
                                    .withOpacity(0.05),
                            borderRadius:
                                BorderRadius.circular(12),
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
                                    fontWeight:
                                        FontWeight.bold),
                              ),
                              Text(
                                actual > 0
                                    ? '-$actual ligne(s)'
                                    : '0 ligne',
                                style: TextStyle(
                                    color: actual > 0
                                        ? Colors.greenAccent
                                        : Colors.white38,
                                    fontWeight:
                                        FontWeight.bold,
                                    fontSize: 18),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: actual > 0
                                ? Colors.greenAccent
                                    .withOpacity(0.2)
                                : Colors.white10,
                            foregroundColor: actual > 0
                                ? Colors.greenAccent
                                : Colors.white30,
                            padding:
                                const EdgeInsets.symmetric(
                                    vertical: 14),
                            shape: RoundedRectangleBorder(
                                borderRadius:
                                    BorderRadius.circular(12)),
                          ),
                          icon: const Icon(Icons.check),
                          label: Text(actual > 0
                              ? 'Valider (-$actual lignes)'
                              : 'Note insuffisante (< 12)'),
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

  Widget _baremeRow(String range, String label, bool active) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Row(
          children: [
            Icon(
                active
                    ? Icons.check_circle
                    : Icons.radio_button_unchecked,
                color: active
                    ? Colors.greenAccent
                    : Colors.white24,
                size: 14),
            const SizedBox(width: 8),
            Text(range,
                style: TextStyle(
                    color: active ? Colors.white : Colors.white38,
                    fontWeight: active
                        ? FontWeight.bold
                        : FontWeight.normal,
                    fontSize: 12)),
            const SizedBox(width: 8),
            Text('→ $label',
                style: TextStyle(
                    color: active
                        ? Colors.greenAccent
                        : Colors.white24,
                    fontSize: 12)),
          ],
        ),
      );

  void _confirmSchoolNoteReduction(PunishmentLines p,
      ChildModel child, FamilyProvider fp, double note,
      int lines) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
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
                    color:
                        Colors.greenAccent.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                      '📚 Note : ${note.toStringAsFixed(1)} / 20',
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  Text(
                      '$lines ligne(s) retirée(s) de "${p.text}"',
                      style: const TextStyle(
                          color: Colors.white60,
                          fontSize: 12)),
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
                backgroundColor:
                    Colors.greenAccent.withOpacity(0.2),
                foregroundColor: Colors.greenAccent),
            onPressed: () async {
              await fp.updatePunishmentProgress(p.id, lines);
              if (mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context)
                    .showSnackBar(SnackBar(
                  content:
                      Text('📚 $lines ligne(s) retirée(s) !'),
                  backgroundColor:
                      Colors.greenAccent.withOpacity(0.8),
                ));
              }
            },
            child: const Text('Confirmer'),
          ),
        ],
      ),
    );
  }

  void _showImmunityPicker(
      PunishmentLines p, ChildModel child, FamilyProvider fp) {
    final activeImmunities =
        fp.getUsableImmunitiesForChild(child.id);
    if (activeImmunities.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Aucune immunité disponible'),
        backgroundColor: Colors.redAccent,
      ));
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
                          borderRadius:
                              BorderRadius.circular(2))),
                  const SizedBox(height: 16),
                  const Text('🛡️ Utiliser une immunité',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(
                      '${liveImmunities.length} immunité(s) disponible(s)',
                      style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 12)),
                  const SizedBox(height: 16),
                  Expanded(
                    child: ListView.builder(
                      controller: scrollController,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16),
                      itemCount: liveImmunities.length,
                      itemBuilder: (_, i) {
                        final imm = liveImmunities[i];
                        return Container(
                          margin:
                              const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.amberAccent
                                .withOpacity(0.1),
                            borderRadius:
                                BorderRadius.circular(12),
                            border: Border.all(
                                color: Colors.amberAccent
                                    .withOpacity(0.3)),
                          ),
                          child: Row(
                            children: [
                              const Text('🛡️',
                                  style:
                                      TextStyle(fontSize: 20)),
                              const SizedBox(width: 10),
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
                                            fontSize: 13)),
                                    Text(
                                        '${imm.lines} ligne(s) d\'immunité',
                                        style: const TextStyle(
                                            color:
                                                Colors.white54,
                                            fontSize: 11)),
                                  ],
                                ),
                              ),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor:
                                      Colors.amberAccent
                                          .withOpacity(0.2),
                                  foregroundColor:
                                      Colors.amberAccent,
                                  padding:
                                      const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 6),
                                  shape: RoundedRectangleBorder(
                                      borderRadius:
                                          BorderRadius.circular(
                                              8)),
                                ),
                                onPressed: () async {
                                  final maxLines = p.totalLines -
                                      p.completedLines;
                                  final toUse = imm.lines
                                      .clamp(0, maxLines);
                                  await fp.useImmunity(
                                      imm.id, p.id, toUse);
                                  if (mounted) {
                                    Navigator.pop(context);
                                    ScaffoldMessenger.of(context)
                                        .showSnackBar(SnackBar(
                                      content: Text(
                                          '🛡️ $toUse ligne(s) retirée(s) !'),
                                      backgroundColor:
                                          Colors.amberAccent
                                              .withOpacity(0.8),
                                    ));
                                  }
                                },
                                child: const Text('Utiliser'),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  int _estimateAge(ChildModel child) => child.effectiveAge;
} // ← fermeture de _PunishmentLinesScreenState
