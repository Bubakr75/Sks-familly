import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/family_provider.dart';
import '../models/punishment_lines.dart';
import '../models/immunity_lines.dart';
import '../models/child_model.dart';
import '../widgets/animated_background.dart';
import '../widgets/glass_card.dart';
import '../widgets/tv_focus_wrapper.dart';
import '../utils/tv_detector.dart';
import '../services/gemini_service.dart';

class PunishmentLinesScreen extends StatefulWidget {
  const PunishmentLinesScreen({super.key});
  @override
  State<PunishmentLinesScreen> createState() => _PunishmentLinesScreenState();
}

class _PunishmentLinesScreenState extends State<PunishmentLinesScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _descController = TextEditingController();
  final TextEditingController _linesController = TextEditingController();
  ChildModel? _selectedChild;
  bool _loading = false;
  final Map<String, int> _quizCounts = {};
  late TabController _tabController;

  bool get isTV => TvDetector.isTV;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _descController.dispose();
    _linesController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _savePunishment(FamilyProvider fp, ChildModel? child) async {
    if (child == null) return;
    final desc = _descController.text.trim();
    final lines = int.tryParse(_linesController.text.trim()) ?? 0;
    if (desc.isEmpty || lines <= 0) return;
    setState(() => _loading = true);
    await fp.addPunishment(child.id, desc, lines);
    _descController.clear();
    _linesController.clear();
    setState(() { _loading = false; });
    if (mounted) Navigator.pop(context);
  }

  Future<void> _deletePunishment(FamilyProvider fp, String id) async {
    await fp.removePunishment(id);
  }

  Future<void> _incrementQuizCount(String childId) async {
    setState(() { _quizCounts[childId] = (_quizCounts[childId] ?? 0) + 1; });
  }

  @override
  Widget build(BuildContext context) {
    final fp = context.watch<FamilyProvider>();
    final children = fp.children;
    if (children.isEmpty) {
      return AnimatedBackground(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(backgroundColor: Colors.transparent,
            title: Text('Punitions', style: TextStyle(color: Colors.white, fontSize: isTV ? 28 : 20))),
          body: Center(child: Text('Aucun enfant enregistre',
              style: TextStyle(color: Colors.white54, fontSize: isTV ? 22 : 14))),
        ),
      );
    }
    _selectedChild ??= children.first;
    final child = _selectedChild!;
    final allPunishments = fp.punishments.where((p) => p.childId == child.id).toList();
    final active = allPunishments.where((p) => !p.isCompleted).toList();
    final completed = allPunishments.where((p) => p.isCompleted).toList();
    final immunities = fp.immunities.where((i) => i.childId == child.id && i.isUsable).toList();
    final totalImmunityLines = immunities.fold<int>(0, (sum, i) => sum + i.availableLines);

    return AnimatedBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: Text('Punitions & Immunites',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: isTV ? 28 : 20)),
          actions: [
            IconButton(
              icon: Icon(Icons.add_circle_rounded, color: Colors.redAccent, size: isTV ? 36 : 28),
              onPressed: () => _showAddBottomSheet(context, fp, child),
            ),
          ],
          bottom: TabBar(
            controller: _tabController,
            indicatorColor: Colors.redAccent,
            indicatorWeight: 3,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white38,
            labelStyle: TextStyle(fontSize: isTV ? 18 : 14),
            tabs: [
              Tab(child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.edit_document, size: isTV ? 22 : 16),
                const SizedBox(width: 6),
                Text('Punitions (${active.length})'),
              ])),
              Tab(child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.shield_rounded, size: isTV ? 22 : 16),
                const SizedBox(width: 6),
                Text('Immunites ($totalImmunityLines)'),
              ])),
            ],
          ),
        ),
        body: isTV ? _buildTvBody(children, child, fp, active, completed, immunities, totalImmunityLines)
            : _buildMobileBody(children, child, fp, active, completed, immunities, totalImmunityLines),
      ),
    );
  }

  // ==================== TV BODY ====================
  Widget _buildTvBody(List<ChildModel> children, ChildModel child, FamilyProvider fp,
      List<PunishmentLines> active, List<PunishmentLines> completed,
      List<ImmunityLines> immunities, int totalImmunityLines) {
    return Row(
      children: [
        // Gauche: selecteur + stats
        SizedBox(
          width: 280,
          child: Column(
            children: [
              const SizedBox(height: 12),
              Expanded(child: _buildChildSelectorTV(children, child, fp)),
              Padding(
                padding: const EdgeInsets.all(12),
                child: _buildStatsTV(active, child, totalImmunityLines),
              ),
            ],
          ),
        ),
        // Droite: onglets
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildPunitionsTab(active, completed, child, fp),
              _buildImmunitesTab(immunities, active, child, fp),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildChildSelectorTV(List<ChildModel> children, ChildModel selected, FamilyProvider fp) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      itemCount: children.length,
      itemBuilder: (_, i) {
        final c = children[i];
        final isSelected = c.id == selected.id;
        final activePunishments = fp.punishments.where((p) => p.childId == c.id && !p.isCompleted).length;
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: TvFocusWrapper(
            autofocus: i == 0,
            onTap: () => setState(() => _selectedChild = c),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                gradient: isSelected ? LinearGradient(
                  colors: [Colors.redAccent.withAlpha(80), Colors.redAccent.withAlpha(30)],
                ) : null,
                color: isSelected ? null : Colors.white10,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: isSelected ? Colors.redAccent : Colors.white24, width: 1.5),
              ),
              child: Row(
                children: [
                  Text(c.avatar, style: const TextStyle(fontSize: 24)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(c.name, style: TextStyle(
                        color: isSelected ? Colors.white : Colors.white70,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        fontSize: 18)),
                  ),
                  if (activePunishments > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(color: Colors.redAccent, borderRadius: BorderRadius.circular(12)),
                      child: Text('$activePunishments', style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatsTV(List<PunishmentLines> active, ChildModel child, int immunityLines) {
    final totalLines = active.fold<int>(0, (sum, p) => sum + (p.totalLines - p.completedLines));
    return GlassCard(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
            _statItem('\u{1F4CB}', '${active.length}', 'Punitions', Colors.redAccent),
            _divider(),
            _statItem('\u{270F}', '$totalLines', 'Restantes', Colors.orangeAccent),
          ]),
          const SizedBox(height: 8),
          Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
            _statItem('\u{1F6E1}', '$immunityLines', 'Immunites', Colors.greenAccent),
            _divider(),
            _statItem('\u{1F3AF}', '${_quizCounts[child.id] ?? 0}', 'Quiz', Colors.amberAccent),
          ]),
        ],
      ),
    );
  }

  // ==================== MOBILE BODY ====================
  Widget _buildMobileBody(List<ChildModel> children, ChildModel child, FamilyProvider fp,
      List<PunishmentLines> active, List<PunishmentLines> completed,
      List<ImmunityLines> immunities, int totalImmunityLines) {
    return Column(
      children: [
        _buildChildSelector(children, child, fp),
        _buildStats(active, child, totalImmunityLines),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildPunitionsTab(active, completed, child, fp),
              _buildImmunitesTab(immunities, active, child, fp),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildChildSelector(List<ChildModel> children, ChildModel selected, FamilyProvider fp) {
    return SizedBox(
      height: 70,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        itemCount: children.length,
        itemBuilder: (_, i) {
          final c = children[i];
          final isSelected = c.id == selected.id;
          final activePunishments = fp.punishments.where((p) => p.childId == c.id && !p.isCompleted).length;
          return GestureDetector(
            onTap: () => setState(() => _selectedChild = c),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              margin: const EdgeInsets.only(right: 10),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                gradient: isSelected ? LinearGradient(
                  colors: [Colors.redAccent.withAlpha(80), Colors.redAccent.withAlpha(30)],
                ) : null,
                color: isSelected ? null : Colors.white10,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: isSelected ? Colors.redAccent : Colors.white24, width: 1.5),
              ),
              child: Row(children: [
                Text(c.avatar, style: const TextStyle(fontSize: 18)),
                const SizedBox(width: 6),
                Text(c.name.toUpperCase(), style: TextStyle(
                    color: isSelected ? Colors.white : Colors.white70,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal, fontSize: 12)),
                if (activePunishments > 0) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(color: Colors.redAccent, borderRadius: BorderRadius.circular(10)),
                    child: Text('$activePunishments', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                  ),
                ],
              ]),
            ),
          );
        },
      ),
    );
  }

  Widget _buildStats(List<PunishmentLines> active, ChildModel child, int immunityLines) {
    final totalLines = active.fold<int>(0, (sum, p) => sum + (p.totalLines - p.completedLines));
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: GlassCard(
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
          _statItem('\u{1F4CB}', '${active.length}', 'Punitions', Colors.redAccent),
          _divider(),
          _statItem('\u{270F}', '$totalLines', 'Lignes restantes', Colors.orangeAccent),
          _divider(),
          _statItem('\u{1F6E1}', '$immunityLines', 'Immunites dispo', Colors.greenAccent),
          _divider(),
          _statItem('\u{1F3AF}', '${_quizCounts[child.id] ?? 0}', 'Quiz faits', Colors.amberAccent),
        ]),
      ),
    );
  }

  Widget _divider() => Container(width: 1, height: 40, color: Colors.white12);

  Widget _statItem(String emoji, String value, String label, Color color) {
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Text(emoji, style: TextStyle(fontSize: isTV ? 24 : 18)),
      const SizedBox(height: 2),
      Text(value, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: isTV ? 20 : 16)),
      Text(label, style: TextStyle(color: Colors.white54, fontSize: isTV ? 13 : 10)),
    ]);
  }

  // ── Onglet Punitions ──────────────────────────────────────────────────────
  Widget _buildPunitionsTab(List<PunishmentLines> active, List<PunishmentLines> completed,
      ChildModel child, FamilyProvider fp) {
    if (active.isEmpty && completed.isEmpty) {
      return Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text('\u{1F389}', style: TextStyle(fontSize: isTV ? 64 : 48)),
          const SizedBox(height: 12),
          Text('Aucune punition en cours !', style: TextStyle(color: Colors.white54, fontSize: isTV ? 22 : 16)),
        ]),
      );
    }
    return ListView(
      padding: EdgeInsets.all(isTV ? 20 : 12),
      children: [
        if (active.isNotEmpty) ...[
          _sectionHeader('EN COURS', Colors.redAccent, Icons.edit_document),
          ...active.map((p) => _buildPunishmentCard(p, child, fp)),
        ],
        if (completed.isNotEmpty) ...[
          _sectionHeader('TERMINEES', Colors.green, Icons.check_circle_rounded),
          ...completed.map((p) => _buildPunishmentCard(p, child, fp)),
        ],
      ],
    );
  }

  Widget _sectionHeader(String title, Color color, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(children: [
        Icon(icon, color: color, size: isTV ? 22 : 16),
        const SizedBox(width: 6),
        Text(title, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: isTV ? 16 : 12, letterSpacing: 1.5)),
      ]),
    );
  }

  Widget _buildPunishmentCard(PunishmentLines p, ChildModel child, FamilyProvider fp) {
    final isCompleted = p.isCompleted;
    final remaining = p.totalLines - p.completedLines;
    final progress = p.totalLines > 0 ? p.completedLines / p.totalLines : 0.0;
    final availableImmunities = fp.immunities.where((i) => i.childId == child.id && i.isUsable).toList();
    final totalAvailable = availableImmunities.fold<int>(0, (s, i) => s + i.availableLines);

    return Padding(
      padding: EdgeInsets.only(bottom: isTV ? 16 : 12),
      child: TvFocusWrapper(
        onTap: !isCompleted ? () => _showQuizThemePicker(p, child, fp) : null,
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isCompleted
                  ? [Colors.green.withAlpha(20), Colors.green.withAlpha(10)]
                  : [Colors.redAccent.withAlpha(20), Colors.white.withAlpha(5)],
              begin: Alignment.topLeft, end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: isCompleted ? Colors.green.withAlpha(60) : Colors.redAccent.withAlpha(60)),
          ),
          child: Padding(
            padding: EdgeInsets.all(isTV ? 20 : 14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Icon(isCompleted ? Icons.check_circle_rounded : Icons.edit_document,
                    color: isCompleted ? Colors.green : Colors.redAccent, size: isTV ? 26 : 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(p.text, style: TextStyle(
                      color: isCompleted ? Colors.white54 : Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: isTV ? 18 : 14,
                      decoration: isCompleted ? TextDecoration.lineThrough : null)),
                ),
                if (!isCompleted)
                  IconButton(
                    icon: Icon(Icons.quiz_rounded, color: Colors.amberAccent, size: isTV ? 28 : 20),
                    onPressed: () => _showQuizThemePicker(p, child, fp),
                    tooltip: 'Lancer le quiz',
                  ),
                IconButton(
                  icon: Icon(Icons.delete_outline_rounded, color: Colors.white24, size: isTV ? 24 : 18),
                  onPressed: () => _deletePunishment(fp, p.id),
                ),
              ]),
              if (!isCompleted) ...[
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: progress,
                        backgroundColor: Colors.white12,
                        valueColor: AlwaysStoppedAnimation<Color>(progress > 0.7 ? Colors.orangeAccent : Colors.redAccent),
                        minHeight: isTV ? 8 : 6,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text('$remaining/${p.totalLines}', style: TextStyle(color: Colors.white70, fontSize: isTV ? 16 : 12, fontWeight: FontWeight.bold)),
                ]),
                const SizedBox(height: 10),
                if (totalAvailable > 0)
                  GestureDetector(
                    onTap: () => _showUseImmunityDialog(p, child, fp, availableImmunities),
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: isTV ? 16 : 12, vertical: isTV ? 12 : 8),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: [Colors.green.withAlpha(60), Colors.teal.withAlpha(40)]),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.greenAccent.withAlpha(80)),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.shield_rounded, color: Colors.greenAccent, size: isTV ? 22 : 16),
                        const SizedBox(width: 6),
                        Text('Utiliser immunite ($totalAvailable dispo)',
                            style: TextStyle(color: Colors.greenAccent, fontSize: isTV ? 16 : 12, fontWeight: FontWeight.w600)),
                      ]),
                    ),
                  ),
              ],
              const SizedBox(height: 6),
              Text(_timeAgo(p.createdAt), style: TextStyle(color: Colors.white38, fontSize: isTV ? 14 : 11)),
            ]),
          ),
        ),
      ),
    );
  }

  // ── Onglet Immunites ──────────────────────────────────────────────────────
  Widget _buildImmunitesTab(List<ImmunityLines> immunities, List<PunishmentLines> active,
      ChildModel child, FamilyProvider fp) {
    if (immunities.isEmpty) {
      return Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text('\u{1F6E1}', style: TextStyle(fontSize: isTV ? 64 : 48)),
          const SizedBox(height: 12),
          Text('Aucune immunite disponible', style: TextStyle(color: Colors.white54, fontSize: isTV ? 22 : 16)),
          const SizedBox(height: 6),
          Text('Gagnez des immunites en reussissant les quiz !',
              style: TextStyle(color: Colors.white38, fontSize: isTV ? 16 : 12), textAlign: TextAlign.center),
        ]),
      );
    }
    return ListView(
      padding: EdgeInsets.all(isTV ? 20 : 12),
      children: [
        _sectionHeader('DISPONIBLES', Colors.greenAccent, Icons.shield_rounded),
        ...immunities.map((i) => _buildImmunityCard(i, active, child, fp)),
      ],
    );
  }

  Widget _buildImmunityCard(ImmunityLines immunity, List<PunishmentLines> active,
      ChildModel child, FamilyProvider fp) {
    final progress = immunity.lines > 0 ? immunity.usedLines / immunity.lines : 0.0;
    return Padding(
      padding: EdgeInsets.only(bottom: isTV ? 16 : 12),
      child: TvFocusWrapper(
        onTap: active.isNotEmpty ? () => _showUseSingleImmunityDialog(immunity, active, child, fp) : null,
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.green.withAlpha(30), Colors.teal.withAlpha(15)],
              begin: Alignment.topLeft, end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.greenAccent.withAlpha(60)),
          ),
          child: Padding(
            padding: EdgeInsets.all(isTV ? 20 : 14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Icon(Icons.shield_rounded, color: Colors.greenAccent, size: isTV ? 26 : 20),
                const SizedBox(width: 8),
                Expanded(child: Text(immunity.reason,
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: isTV ? 18 : 14))),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: isTV ? 14 : 10, vertical: isTV ? 6 : 4),
                  decoration: BoxDecoration(
                    color: Colors.greenAccent.withAlpha(30),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.greenAccent.withAlpha(80)),
                  ),
                  child: Text('${immunity.availableLines} dispo',
                      style: TextStyle(color: Colors.greenAccent, fontSize: isTV ? 16 : 12, fontWeight: FontWeight.bold)),
                ),
              ]),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: progress, backgroundColor: Colors.white12,
                      valueColor: const AlwaysStoppedAnimation<Color>(Colors.greenAccent),
                      minHeight: isTV ? 8 : 6,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Text('${immunity.usedLines}/${immunity.lines}',
                    style: TextStyle(color: Colors.white54, fontSize: isTV ? 16 : 12)),
              ]),
              if (active.isNotEmpty) ...[
                const SizedBox(height: 10),
                GestureDetector(
                  onTap: () => _showUseSingleImmunityDialog(immunity, active, child, fp),
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: isTV ? 16 : 12, vertical: isTV ? 12 : 8),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [Colors.redAccent.withAlpha(50), Colors.orange.withAlpha(30)]),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.redAccent.withAlpha(80)),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.edit_document, color: Colors.redAccent, size: isTV ? 22 : 16),
                      const SizedBox(width: 6),
                      Text('Appliquer sur une punition',
                          style: TextStyle(color: Colors.redAccent, fontSize: isTV ? 16 : 12, fontWeight: FontWeight.w600)),
                    ]),
                  ),
                ),
              ],
              const SizedBox(height: 6),
              Text(_timeAgo(immunity.createdAt), style: TextStyle(color: Colors.white38, fontSize: isTV ? 14 : 11)),
            ]),
          ),
        ),
      ),
    );
  }

  // ── Dialog utiliser immunite depuis punition ──────────────────────────────
  void _showUseImmunityDialog(PunishmentLines punishment, ChildModel child,
      FamilyProvider fp, List<ImmunityLines> immunities) {
    int linesToUse = 1;
    ImmunityLines? selectedImmunity = immunities.first;
    final remaining = punishment.totalLines - punishment.completedLines;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => Container(
          padding: EdgeInsets.only(
              left: isTV ? 32 : 20, right: isTV ? 32 : 20, top: isTV ? 32 : 20,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 20),
          decoration: const BoxDecoration(
            color: Color(0xFF1E1E2E),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: Container(width: 40, height: 4,
                  decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 16),
              Text('Utiliser des immunites',
                  style: TextStyle(color: Colors.white, fontSize: isTV ? 24 : 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              Text('Punition : ${punishment.text}',
                  style: TextStyle(color: Colors.white54, fontSize: isTV ? 16 : 13)),
              const SizedBox(height: 16),
              Text('Choisir une immunite :',
                  style: TextStyle(color: Colors.white70, fontSize: isTV ? 16 : 13)),
              const SizedBox(height: 8),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 250),
                child: SingleChildScrollView(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    ...immunities.map((i) => GestureDetector(
                      onTap: () => setState(() => selectedImmunity = i),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: EdgeInsets.all(isTV ? 16 : 12),
                        decoration: BoxDecoration(
                          color: selectedImmunity?.id == i.id ? Colors.greenAccent.withAlpha(30) : Colors.white10,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: selectedImmunity?.id == i.id ? Colors.greenAccent : Colors.transparent),
                        ),
                        child: Row(children: [
                          Icon(Icons.shield_rounded, color: Colors.greenAccent, size: isTV ? 24 : 18),
                          const SizedBox(width: 8),
                          Expanded(child: Text(i.reason, style: TextStyle(color: Colors.white, fontSize: isTV ? 16 : 13))),
                          Text('${i.availableLines} dispo', style: TextStyle(color: Colors.greenAccent, fontSize: isTV ? 15 : 12)),
                        ]),
                      ),
                    )),
                  ]),
                ),
              ),
              const SizedBox(height: 16),
              Row(children: [
                Text('Lignes a utiliser :', style: TextStyle(color: Colors.white70, fontSize: isTV ? 16 : 13)),
                const SizedBox(width: 12),
                SizedBox(
                  width: isTV ? 100 : 80,
                  child: TvTextField(
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: isTV ? 24 : 18),
                    decoration: InputDecoration(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: Colors.greenAccent)),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: Colors.greenAccent, width: 2)),
                      filled: true, fillColor: Colors.greenAccent.withAlpha(30),
                    ),
                    onChanged: (val) {
                      final n = int.tryParse(val) ?? 1;
                      final maxVal = selectedImmunity?.availableLines ?? 1;
                      final maxLine = maxVal < remaining ? maxVal : remaining;
                      setState(() => linesToUse = n.clamp(1, maxLine));
                    },
                  ),
                ),
              ]),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.greenAccent, foregroundColor: Colors.black,
                      padding: EdgeInsets.symmetric(vertical: isTV ? 18 : 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                  icon: const Icon(Icons.shield_rounded),
                  label: Text('Utiliser $linesToUse ligne(s) d immunite',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: isTV ? 18 : 14)),
                  onPressed: selectedImmunity == null ? null : () async {
                    Navigator.pop(ctx);
                    await fp.useImmunityOnPunishment(selectedImmunity!.id, punishment.id, linesToUse);
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text('$linesToUse ligne(s) d immunite utilisee(s) !'),
                        backgroundColor: Colors.greenAccent.withAlpha(200),
                        behavior: SnackBarBehavior.floating,
                      ));
                    }
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Dialog utiliser immunite depuis onglet immunites ──────────────────────
  void _showUseSingleImmunityDialog(ImmunityLines immunity, List<PunishmentLines> active,
      ChildModel child, FamilyProvider fp) {
    PunishmentLines? selectedPunishment = active.first;
    int linesToUse = 1;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => Container(
          padding: EdgeInsets.only(
              left: isTV ? 32 : 20, right: isTV ? 32 : 20, top: isTV ? 32 : 20,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 20),
          decoration: const BoxDecoration(
            color: Color(0xFF1E1E2E),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: Container(width: 40, height: 4,
                  decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 16),
              Text('Appliquer une immunite',
                  style: TextStyle(color: Colors.white, fontSize: isTV ? 24 : 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              Text('Immunite : ${immunity.reason} (${immunity.availableLines} dispo)',
                  style: TextStyle(color: Colors.white54, fontSize: isTV ? 16 : 13)),
              const SizedBox(height: 16),
              Text('Choisir une punition :',
                  style: TextStyle(color: Colors.white70, fontSize: isTV ? 16 : 13)),
              const SizedBox(height: 8),
              ...active.map((p) => GestureDetector(
                onTap: () => setState(() => selectedPunishment = p),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: EdgeInsets.all(isTV ? 16 : 12),
                  decoration: BoxDecoration(
                    color: selectedPunishment?.id == p.id ? Colors.redAccent.withAlpha(30) : Colors.white10,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: selectedPunishment?.id == p.id ? Colors.redAccent : Colors.transparent),
                  ),
                  child: Row(children: [
                    Icon(Icons.edit_document, color: Colors.redAccent, size: isTV ? 24 : 18),
                    const SizedBox(width: 8),
                    Expanded(child: Text(p.text, style: TextStyle(color: Colors.white, fontSize: isTV ? 16 : 13))),
                    Text('${p.totalLines - p.completedLines} restantes',
                        style: TextStyle(color: Colors.white54, fontSize: isTV ? 15 : 12)),
                  ]),
                ),
              )),
              const SizedBox(height: 16),
              Row(children: [
                Text('Lignes a utiliser :', style: TextStyle(color: Colors.white70, fontSize: isTV ? 16 : 13)),
                const SizedBox(width: 12),
                SizedBox(
                  width: isTV ? 100 : 80,
                  child: TvTextField(
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: isTV ? 24 : 18),
                    decoration: InputDecoration(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: Colors.greenAccent)),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: Colors.greenAccent, width: 2)),
                      filled: true, fillColor: Colors.greenAccent.withAlpha(30),
                    ),
                    onChanged: (val) {
                      final n = int.tryParse(val) ?? 1;
                      setState(() => linesToUse = n.clamp(1, immunity.availableLines));
                    },
                  ),
                ),
              ]),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.greenAccent, foregroundColor: Colors.black,
                      padding: EdgeInsets.symmetric(vertical: isTV ? 18 : 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                  icon: const Icon(Icons.shield_rounded),
                  label: Text('Appliquer $linesToUse ligne(s)',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: isTV ? 18 : 14)),
                  onPressed: selectedPunishment == null ? null : () async {
                    Navigator.pop(ctx);
                    await fp.useImmunityOnPunishment(immunity.id, selectedPunishment!.id, linesToUse);
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text('$linesToUse ligne(s) d immunite appliquee(s) !'),
                        backgroundColor: Colors.greenAccent.withAlpha(200),
                        behavior: SnackBarBehavior.floating,
                      ));
                    }
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Bottom sheet ajout punition ───────────────────────────────────────────
  void _showAddBottomSheet(BuildContext context, FamilyProvider fp, ChildModel child) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: Container(
          padding: EdgeInsets.all(isTV ? 32 : 24),
          decoration: const BoxDecoration(
            color: Color(0xFF1E1E2E),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(child: Container(width: 40, height: 4,
                    decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)))),
                const SizedBox(height: 16),
                Text('Nouvelle punition',
                    style: TextStyle(color: Colors.white, fontSize: isTV ? 24 : 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                _buildTextField(_descController, 'Description de la punition', Icons.edit_document),
                const SizedBox(height: 12),
                _buildTextField(_linesController, 'Nombre de lignes', Icons.format_list_numbered, isNumber: true),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.redAccent,
                        padding: EdgeInsets.symmetric(vertical: isTV ? 18 : 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                    icon: _loading
                        ? const SizedBox(width: 18, height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.add_circle_rounded),
                    label: Text('Ajouter la punition',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: isTV ? 18 : 15)),
                    onPressed: _loading ? null : () => _savePunishment(fp, child),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController ctrl, String label, IconData icon, {bool isNumber = false}) {
    return TvTextField(
      controller: ctrl,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      style: TextStyle(color: Colors.white, fontSize: isTV ? 18 : 14),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.white54, fontSize: isTV ? 16 : 14),
        prefixIcon: Icon(icon, color: Colors.redAccent, size: isTV ? 28 : 24),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.white24)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.redAccent)),
      ),
    );
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'A l instant';
    if (diff.inHours < 1) return 'Il y a ${diff.inMinutes} min';
    if (diff.inDays < 1) return 'Il y a ${diff.inHours}h';
    if (diff.inDays < 7) return 'Il y a ${diff.inDays}j';
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  void _showQuizThemePicker(PunishmentLines p, ChildModel child, FamilyProvider fp) {
    int currentStep = 0;
    int selectedAge = 8;
    String selectedDifficulty = 'moyen';
    String? selectedTheme;
    String? selectedHero;
    List<Map<String, dynamic>> customQuestions = [];

    final List<Map<String, dynamic>> themes = [
      {'label': 'Mathematiques', 'emoji': '\u{1F522}', 'color': 0xFF4FC3F7},
      {'label': 'Francais', 'emoji': '\u{1F4DD}', 'color': 0xFFAB47BC},
      {'label': 'Sciences', 'emoji': '\u{1F52C}', 'color': 0xFF66BB6A},
      {'label': 'Histoire', 'emoji': '\u{1F3DB}', 'color': 0xFFFF8A65},
      {'label': 'Geographie', 'emoji': '\u{1F30D}', 'color': 0xFF26C6DA},
      {'label': 'Culture generale', 'emoji': '\u{1F9E0}', 'color': 0xFFFFCA28},
      {'label': 'Personnalise', 'emoji': '\u{2B50}', 'color': 0xFFEC407A},
    ];

    final List<Map<String, dynamic>> heroes = [
      {'label': 'Pat Patrouille', 'emoji': '\u{1F43E}'},
      {'label': 'Miraculous', 'emoji': '\u{1F41E}'},
      {'label': 'Spider-Man', 'emoji': '\u{1F577}'},
      {'label': 'Bluey', 'emoji': '\u{1F415}'},
      {'label': 'Peppa Pig', 'emoji': '\u{1F437}'},
      {'label': 'Minions', 'emoji': '\u{1F49B}'},
      {'label': 'Personnalise', 'emoji': '\u{2728}'},
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => StatefulBuilder(
        builder: (ctx, setSheetState) => DraggableScrollableSheet(
          initialChildSize: 0.85,
          maxChildSize: 0.95,
          minChildSize: 0.5,
          builder: (_, scrollCtrl) => Container(
            decoration: const BoxDecoration(
              color: Color(0xFF1E1E2E),
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              children: [
                const SizedBox(height: 8),
                Container(width: 40, height: 4,
                    decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [0, 1, 2, 3].map((i) {
                    final done = i < currentStep;
                    final act = i == currentStep;
                    return Row(children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        width: act ? 32 : 24, height: act ? 32 : 24,
                        decoration: BoxDecoration(
                          color: done ? Colors.amberAccent : (act ? Colors.amberAccent : Colors.white24),
                          shape: BoxShape.circle,
                        ),
                        child: Center(child: done
                            ? const Icon(Icons.check, size: 14, color: Colors.black)
                            : Text('${i+1}', style: TextStyle(
                                color: act ? Colors.black : Colors.white54,
                                fontSize: 12, fontWeight: FontWeight.bold))),
                      ),
                      if (i < 3) Container(width: 24, height: 2,
                          color: done ? Colors.amberAccent : Colors.white24),
                    ]);
                  }).toList(),
                ),
                const SizedBox(height: 8),
                Text(['Age & Difficulte', 'Theme', 'Heros', 'Questions'][currentStep],
                    style: TextStyle(color: Colors.white70, fontSize: isTV ? 16 : 12)),
                const SizedBox(height: 16),
                Expanded(
                  child: SingleChildScrollView(
                    controller: scrollCtrl,
                    padding: EdgeInsets.symmetric(horizontal: isTV ? 32 : 20),
                    child: currentStep == 0
                        ? _buildStepAgeAndDifficulty(selectedAge, selectedDifficulty,
                            (v) => setSheetState(() => selectedAge = v),
                            (v) => setSheetState(() => selectedDifficulty = v))
                        : currentStep == 1
                            ? _buildStepTheme(themes, selectedTheme,
                                (v) => setSheetState(() => selectedTheme = v))
                            : currentStep == 2
                                ? _buildStepHeroes(heroes, selectedHero,
                                    (v) => setSheetState(() => selectedHero = v))
                                : _buildStepCustomQuestions(
                                    customQuestions, () => setSheetState(() {})),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.all(isTV ? 24 : 20),
                  child: Row(
                    children: [
                      if (currentStep > 0)
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => setSheetState(() => currentStep--),
                            style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.white54,
                                side: const BorderSide(color: Colors.white24),
                                padding: EdgeInsets.symmetric(vertical: isTV ? 16 : 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                            child: Text('Retour', style: TextStyle(fontSize: isTV ? 18 : 14)),
                          ),
                        ),
                      if (currentStep > 0) const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton(
                          onPressed: () async {
                            if (currentStep < 3) {
                              setSheetState(() => currentStep++);
                            } else {
                              Navigator.pop(sheetCtx);
                              await _startQuiz(p, child, fp, selectedAge, selectedDifficulty,
                                  selectedTheme ?? themes[0]['label'] as String,
                                  selectedHero, customQuestions);
                            }
                          },
                          style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.amberAccent, foregroundColor: Colors.black,
                              padding: EdgeInsets.symmetric(vertical: isTV ? 16 : 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                          child: Text(currentStep < 3 ? 'Suivant' : 'Lancer le Quiz !',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: isTV ? 18 : 14)),
                        ),
                      ),
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

  Widget _buildStepAgeAndDifficulty(int age, String diff,
      ValueChanged<int> onAge, ValueChanged<String> onDiff) {
    final diffs = [
      {'value': 'facile', 'emoji': '\u{1F7E2}', 'label': 'Facile', 'desc': 'Questions simples'},
      {'value': 'moyen', 'emoji': '\u{1F7E1}', 'label': 'Moyen', 'desc': 'Questions moderees'},
      {'value': 'difficile', 'emoji': '\u{1F534}', 'label': 'Difficile', 'desc': 'Questions avancees'},
    ];
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Age de l enfant', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: isTV ? 22 : 16)),
      const SizedBox(height: 12),
      Row(children: [
        IconButton(onPressed: age > 3 ? () => onAge(age - 1) : null,
            icon: Icon(Icons.remove_circle, color: Colors.amberAccent, size: isTV ? 36 : 24)),
        Container(
          padding: EdgeInsets.symmetric(horizontal: isTV ? 32 : 24, vertical: isTV ? 12 : 8),
          decoration: BoxDecoration(color: Colors.amberAccent.withAlpha(50), borderRadius: BorderRadius.circular(12)),
          child: Text('$age ans', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: isTV ? 28 : 20)),
        ),
        IconButton(onPressed: age < 18 ? () => onAge(age + 1) : null,
            icon: Icon(Icons.add_circle, color: Colors.amberAccent, size: isTV ? 36 : 24)),
      ]),
      const SizedBox(height: 24),
      Text('Difficulte', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: isTV ? 22 : 16)),
      const SizedBox(height: 12),
      ...diffs.map((d) => _buildDiffCard(d['value']!, d['emoji']!, d['label']!, d['desc']!, diff, onDiff)),
    ]);
  }

  Widget _buildDiffCard(String value, String emoji, String label, String desc,
      String current, ValueChanged<String> onSelect) {
    final isSelected = value == current;
    return GestureDetector(
      onTap: () => onSelect(value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 10),
        padding: EdgeInsets.all(isTV ? 18 : 14),
        decoration: BoxDecoration(
          color: isSelected ? Colors.amberAccent.withAlpha(50) : Colors.white10,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isSelected ? Colors.amberAccent : Colors.transparent, width: 1.5),
        ),
        child: Row(children: [
          Text(emoji, style: TextStyle(fontSize: isTV ? 28 : 22)),
          const SizedBox(width: 12),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: TextStyle(
                color: isSelected ? Colors.amberAccent : Colors.white,
                fontWeight: FontWeight.bold, fontSize: isTV ? 18 : 14)),
            Text(desc, style: TextStyle(color: Colors.white54, fontSize: isTV ? 14 : 12)),
          ]),
          if (isSelected) ...[const Spacer(), Icon(Icons.check_circle, color: Colors.amberAccent, size: isTV ? 24 : 20)],
        ]),
      ),
    );
  }

  Widget _buildStepTheme(List<Map<String, dynamic>> themes, String? selected, ValueChanged<String> onSelect) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Choisir un theme', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: isTV ? 22 : 16)),
      const SizedBox(height: 12),
      GridView.builder(
        shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: isTV ? 3 : 2, childAspectRatio: 1.8, crossAxisSpacing: 10, mainAxisSpacing: 10),
        itemCount: themes.length,
        itemBuilder: (_, i) {
          final t = themes[i];
          final isSel = t['label'] == selected;
          return GestureDetector(
            onTap: () => onSelect(t['label'] as String),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              decoration: BoxDecoration(
                color: isSel ? Color(t['color'] as int).withAlpha(80) : Colors.white10,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: isSel ? Color(t['color'] as int) : Colors.transparent, width: 1.5),
              ),
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Text(t['emoji'] as String, style: TextStyle(fontSize: isTV ? 32 : 24)),
                const SizedBox(height: 4),
                Text(t['label'] as String, style: TextStyle(
                    color: isSel ? Colors.white : Colors.white70, fontSize: isTV ? 15 : 12), textAlign: TextAlign.center),
              ]),
            ),
          );
        },
      ),
    ]);
  }

  Widget _buildStepHeroes(List<Map<String, dynamic>> heroes, String? selected, ValueChanged<String> onSelect) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Heros prefere (optionnel)', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: isTV ? 22 : 16)),
      const SizedBox(height: 12),
      GridView.builder(
        shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: isTV ? 3 : 2, childAspectRatio: 1.8, crossAxisSpacing: 10, mainAxisSpacing: 10),
        itemCount: heroes.length,
        itemBuilder: (_, i) {
          final h = heroes[i];
          final isSel = h['label'] == selected;
          return GestureDetector(
            onTap: () => onSelect(h['label'] as String),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              decoration: BoxDecoration(
                color: isSel ? Colors.purpleAccent.withAlpha(80) : Colors.white10,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: isSel ? Colors.purpleAccent : Colors.transparent, width: 1.5),
              ),
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Text(h['emoji'] as String, style: TextStyle(fontSize: isTV ? 32 : 24)),
                const SizedBox(height: 4),
                Text(h['label'] as String, style: TextStyle(
                    color: isSel ? Colors.white : Colors.white70, fontSize: isTV ? 15 : 12), textAlign: TextAlign.center),
              ]),
            ),
          );
        },
      ),
    ]);
  }

  Widget _buildStepCustomQuestions(List<Map<String, dynamic>> questions, VoidCallback refresh) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text('Questions personnalisees', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: isTV ? 22 : 16)),
        TextButton.icon(
          onPressed: () async { await _showAddCustomQuestion(questions); refresh(); },
          icon: Icon(Icons.add, color: Colors.amberAccent, size: isTV ? 24 : 18),
          label: Text('Ajouter', style: TextStyle(color: Colors.amberAccent, fontSize: isTV ? 16 : 14)),
        ),
      ]),
      const SizedBox(height: 8),
      if (questions.isEmpty)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Center(child: Text('Aucune question\n(le quiz utilisera Gemini AI)',
              textAlign: TextAlign.center, style: TextStyle(color: Colors.white54, fontSize: isTV ? 16 : 14))),
        )
      else
        ...questions.asMap().entries.map((e) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Container(
            padding: EdgeInsets.all(isTV ? 16 : 12),
            decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(12)),
            child: Row(children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Q: ${e.value["question"]}', style: TextStyle(color: Colors.white, fontSize: isTV ? 16 : 13)),
                Text('R: ${e.value["answer"]}', style: TextStyle(color: Colors.amberAccent, fontSize: isTV ? 15 : 12)),
              ])),
              IconButton(icon: Icon(Icons.delete_outline, color: Colors.white38, size: isTV ? 24 : 18),
                  onPressed: () { questions.removeAt(e.key); refresh(); }),
            ]),
          ),
        )),
    ]);
  }

  Future<void> _showAddCustomQuestion(List<Map<String, dynamic>> questions) async {
    final qCtrl = TextEditingController();
    final aCtrl = TextEditingController();
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Nouvelle question', style: TextStyle(color: Colors.white, fontSize: isTV ? 24 : 18)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TvTextField(controller: qCtrl, style: TextStyle(color: Colors.white, fontSize: isTV ? 18 : 14),
            decoration: InputDecoration(labelText: 'Question', labelStyle: TextStyle(color: Colors.white54, fontSize: isTV ? 16 : 14),
                enabledBorder: const OutlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                focusedBorder: const OutlineInputBorder(borderSide: BorderSide(color: Colors.amberAccent)))),
          const SizedBox(height: 12),
          TvTextField(controller: aCtrl, style: TextStyle(color: Colors.white, fontSize: isTV ? 18 : 14),
            decoration: InputDecoration(labelText: 'Reponse', labelStyle: TextStyle(color: Colors.white54, fontSize: isTV ? 16 : 14),
                enabledBorder: const OutlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                focusedBorder: const OutlineInputBorder(borderSide: BorderSide(color: Colors.amberAccent)))),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx),
              child: Text('Annuler', style: TextStyle(color: Colors.white54, fontSize: isTV ? 18 : 14))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.amberAccent, foregroundColor: Colors.black),
            onPressed: () {
              if (qCtrl.text.isNotEmpty && aCtrl.text.isNotEmpty) {
                questions.add({'question': qCtrl.text.trim(), 'answer': aCtrl.text.trim()});
              }
              Navigator.pop(ctx);
            },
            child: Text('Ajouter', style: TextStyle(fontSize: isTV ? 18 : 14)),
          ),
        ],
      ),
    );
    qCtrl.dispose();
    aCtrl.dispose();
  }

  Future<void> _startQuiz(PunishmentLines p, ChildModel child, FamilyProvider fp,
      int age, String difficulty, String theme, String? hero,
      List<Map<String, dynamic>> customQuestions) async {
    List<Map<String, dynamic>> questions = [];
    if (customQuestions.isNotEmpty) {
      questions = customQuestions.asMap().entries.map((e) => {
        'question': e.value['question'], 'choices': [e.value['answer'], 'Faux'], 'correct': 0,
      }).toList();
    } else {
      if (mounted) {
        showDialog(context: context, barrierDismissible: false,
            builder: (_) => const Center(child: CircularProgressIndicator(color: Colors.amberAccent)));
      }
      try {
        final themeWithHero = hero != null && hero != 'Personnalise' ? '$theme avec des references a $hero' : theme;
        questions = GeminiService.generateQuizQuestions(theme: themeWithHero, age: age);
      } catch (e) {
        if (mounted) Navigator.pop(context);
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur Gemini: $e')));
        return;
      }
      if (mounted) Navigator.pop(context);
    }
    if (questions.isEmpty) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Aucune question generee')));
      return;
    }
    if (mounted) _showQuizDialog(p, child, fp, questions);
  }

  void _showQuizDialog(PunishmentLines p, ChildModel child, FamilyProvider fp,
      List<Map<String, dynamic>> questions) {
    int currentQ = 0;
    int score = 0;
    int? selectedIndex;
    bool answered = false;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final q = questions[currentQ];
          final choices = (q['choices'] as List?)?.cast<String>() ?? ['Vrai', 'Faux'];
          final correctIndex = q['correct'] as int? ?? 0;
          return AlertDialog(
            backgroundColor: const Color(0xFF1E1E2E),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            insetPadding: EdgeInsets.symmetric(horizontal: isTV ? 120 : 24, vertical: isTV ? 40 : 24),
            title: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text('Q ${currentQ + 1}/${questions.length}',
                  style: TextStyle(color: Colors.amberAccent, fontSize: isTV ? 20 : 14)),
              Text('Score: $score', style: TextStyle(color: Colors.white70, fontSize: isTV ? 20 : 14)),
            ]),
            content: Column(mainAxisSize: MainAxisSize.min, children: [
              Text(q['question'] as String? ?? '',
                  style: TextStyle(color: Colors.white, fontSize: isTV ? 22 : 16)),
              const SizedBox(height: 16),
              ...choices.asMap().entries.map((e) {
                final idx = e.key;
                final opt = e.value;
                Color color = Colors.white10;
                if (answered) {
                  if (idx == correctIndex) {
                    color = Colors.green.withAlpha(100);
                  } else if (idx == selectedIndex) color = Colors.red.withAlpha(100);
                } else if (idx == selectedIndex) {
                  color = Colors.amberAccent.withAlpha(80);
                }
                return GestureDetector(
                  onTap: answered ? null : () => setDialogState(() => selectedIndex = idx),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: EdgeInsets.all(isTV ? 16 : 12),
                    decoration: BoxDecoration(
                        color: color, borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: selectedIndex == idx && !answered ? Colors.amberAccent : Colors.transparent)),
                    child: Row(children: [
                      Expanded(child: Text(opt, style: TextStyle(color: Colors.white, fontSize: isTV ? 18 : 14))),
                      if (answered && idx == correctIndex) const Icon(Icons.check_circle, color: Colors.green, size: 18),
                      if (answered && idx == selectedIndex && idx != correctIndex) const Icon(Icons.cancel, color: Colors.red, size: 18),
                    ]),
                  ),
                );
              }),
            ]),
            actions: [
              if (!answered && selectedIndex != null)
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.amberAccent, foregroundColor: Colors.black,
                      padding: EdgeInsets.symmetric(horizontal: isTV ? 32 : 16, vertical: isTV ? 14 : 8)),
                  onPressed: () { setDialogState(() { answered = true; if (selectedIndex == correctIndex) score++; }); },
                  child: Text('Valider', style: TextStyle(fontSize: isTV ? 18 : 14)),
                ),
              if (answered)
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.amberAccent, foregroundColor: Colors.black,
                      padding: EdgeInsets.symmetric(horizontal: isTV ? 32 : 16, vertical: isTV ? 14 : 8)),
                  onPressed: () {
                    if (currentQ + 1 < questions.length) {
                      setDialogState(() { currentQ++; selectedIndex = null; answered = false; });
                    } else {
                      Navigator.pop(dialogCtx);
                      _showQuizResult(p, child, fp, score, questions.length);
                    }
                  },
                  child: Text(currentQ + 1 < questions.length ? 'Suivant' : 'Terminer',
                      style: TextStyle(fontSize: isTV ? 18 : 14)),
                ),
            ],
          );
        },
      ),
    );
  }

  void _showQuizResult(PunishmentLines p, ChildModel child, FamilyProvider fp, int score, int total) {
    int parentAdjustment = score;
    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (ctx, setResultState) => AlertDialog(
          backgroundColor: const Color(0xFF1E1E2E),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          insetPadding: EdgeInsets.symmetric(horizontal: isTV ? 150 : 24, vertical: isTV ? 60 : 24),
          title: Column(children: [
            Text(score >= total * 0.8 ? '\u{1F3C6}' : score >= total * 0.5 ? '\u{2B50}' : '\u{1F4AA}',
                style: TextStyle(fontSize: isTV ? 56 : 40)),
            const SizedBox(height: 8),
            Text('$score / $total bonnes reponses',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: isTV ? 24 : 18)),
          ]),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            Text('Lignes d immunite a accorder :',
                style: TextStyle(color: Colors.white70, fontSize: isTV ? 18 : 14)),
            const SizedBox(height: 12),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              IconButton(
                onPressed: parentAdjustment > 0 ? () => setResultState(() => parentAdjustment--) : null,
                icon: Icon(Icons.remove_circle, color: Colors.redAccent, size: isTV ? 40 : 32),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: isTV ? 32 : 24, vertical: isTV ? 12 : 8),
                decoration: BoxDecoration(color: Colors.amberAccent.withAlpha(50), borderRadius: BorderRadius.circular(12)),
                child: Text('$parentAdjustment',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: isTV ? 36 : 28)),
              ),
              IconButton(
                onPressed: () => setResultState(() => parentAdjustment++),
                icon: Icon(Icons.add_circle, color: Colors.green, size: isTV ? 40 : 32),
              ),
            ]),
            const SizedBox(height: 8),
            Text(parentAdjustment > 0 ? '+$parentAdjustment ligne(s) d immunite' : 'Aucune recompense',
                style: TextStyle(
                    color: parentAdjustment > 0 ? Colors.amberAccent : Colors.white38, fontSize: isTV ? 16 : 13)),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext),
                child: Text('Fermer', style: TextStyle(color: Colors.white54, fontSize: isTV ? 18 : 14))),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.amberAccent, foregroundColor: Colors.black,
                  padding: EdgeInsets.symmetric(horizontal: isTV ? 24 : 12, vertical: isTV ? 14 : 8)),
              icon: const Icon(Icons.shield, size: 16),
              label: Text(parentAdjustment > 0 ? 'Accorder +$parentAdjustment immunite(s)' : 'Fermer sans recompense',
                  style: TextStyle(fontSize: isTV ? 16 : 13)),
              onPressed: () async {
                Navigator.pop(dialogContext);
                if (parentAdjustment > 0) {
                  await fp.addImmunity(child.id, 'Quiz - $score/$total bonnes reponses', parentAdjustment);
                }
                await _incrementQuizCount(child.id);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text(parentAdjustment > 0
                        ? 'Quiz valide ! +$parentAdjustment ligne(s) d immunite accordee(s) !'
                        : 'Quiz termine - aucune recompense'),
                    backgroundColor: Colors.purpleAccent.withAlpha(200),
                  ));
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}
