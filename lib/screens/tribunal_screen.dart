import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/family_provider.dart';
import '../providers/pin_provider.dart';
import '../models/tribunal_model.dart';
import '../widgets/animated_background.dart';
import '../widgets/glass_card.dart';
import '../widgets/tv_focus_wrapper.dart';

class TribunalScreen extends StatefulWidget {
  const TribunalScreen({super.key});
  @override
  State<TribunalScreen> createState() => _TribunalScreenState();
}

class _TribunalScreenState extends State<TribunalScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<FamilyProvider>(
      builder: (context, fp, _) {
        final activeCases = fp.activeTribunalCases;
        final closedCases = fp.closedTribunalCases;

        return AnimatedBackground(
          child: Scaffold(
            backgroundColor: Colors.transparent,
            appBar: AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              title: ShaderMask(
                shaderCallback: (bounds) => const LinearGradient(
                  colors: [Colors.purple, Colors.amber],
                ).createShader(bounds),
                child: const Text('⚖️ Tribunal Familial',
                    style: TextStyle(
                        fontWeight: FontWeight.bold, color: Colors.white)),
              ),
              bottom: TabBar(
                controller: _tabController,
                indicatorColor: Colors.purple,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white38,
                tabs: [
                  Tab(
                      child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                        const Text('En cours'),
                        if (activeCases.isNotEmpty) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                                color: Colors.red,
                                borderRadius: BorderRadius.circular(10)),
                            child: Text('${activeCases.length}',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ])),
                  const Tab(text: 'Classées'),
                ],
              ),
            ),
            body: TabBarView(
              controller: _tabController,
              children: [
                _buildActiveTab(fp, activeCases),
                _buildClosedTab(fp, closedCases),
              ],
            ),
            floatingActionButton: FloatingActionButton.extended(
              onPressed: () => _showFileCase(fp),
              backgroundColor: Colors.purple,
              icon: const Icon(Icons.add, color: Colors.white),
              label: const Text('Nouvelle affaire',
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ),
        );
      },
    );
  }

  Widget _buildActiveTab(FamilyProvider fp, List<TribunalCase> cases) {
    if (cases.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.gavel, size: 70, color: Colors.white.withOpacity(0.1)),
            const SizedBox(height: 16),
            Text('Aucune affaire en cours',
                style: TextStyle(
                    color: Colors.white.withOpacity(0.4), fontSize: 16)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: cases.length,
      itemBuilder: (context, index) {
        final tc = cases[index];
        return _buildCaseCard(fp, tc);
      },
    );
  }

  Widget _buildClosedTab(FamilyProvider fp, List<TribunalCase> cases) {
    if (cases.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.archive, size: 70, color: Colors.white.withOpacity(0.1)),
            const SizedBox(height: 16),
            Text('Aucune affaire classée',
                style: TextStyle(
                    color: Colors.white.withOpacity(0.4), fontSize: 16)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: cases.length,
      itemBuilder: (context, index) {
        final tc = cases[index];
        return _buildCaseCard(fp, tc);
      },
    );
  }

  Widget _buildCaseCard(FamilyProvider fp, TribunalCase tc) {
    final plaintiff = fp.getChild(tc.plaintiffId)?.name ?? '?';
    final accused = fp.getChild(tc.accusedId)?.name ?? '?';

    // Utiliser les getters du modèle directement
    final statusColor = tc.statusColor;
    final statusText = tc.statusLabel;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TvFocusWrapper(
        onTap: () => _showCaseDetail(fp, tc),
        child: GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(statusText,
                        style: TextStyle(
                            color: statusColor,
                            fontSize: 12,
                            fontWeight: FontWeight.w600)),
                  ),
                  const Spacer(),
                  if (tc.verdict != null)
                    Text(
                        '${tc.verdictEmoji} ${tc.verdictLabel}',
                        style: TextStyle(
                            color: statusColor,
                            fontSize: 12,
                            fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 10),
              Text(tc.title,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(tc.description,
                  style: const TextStyle(color: Colors.white54, fontSize: 13),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis),
              const SizedBox(height: 10),
              Row(
                children: [
                  const Icon(Icons.person, color: Colors.amber, size: 16),
                  const SizedBox(width: 4),
                  Text('Plaignant: $plaintiff',
                      style: const TextStyle(
                          color: Colors.white70, fontSize: 12)),
                  const SizedBox(width: 16),
                  const Icon(Icons.person_outline,
                      color: Colors.redAccent, size: 16),
                  const SizedBox(width: 4),
                  Text('Accusé: $accused',
                      style: const TextStyle(
                          color: Colors.white70, fontSize: 12)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showCaseDetail(FamilyProvider fp, TribunalCase tc) {
    final plaintiff = fp.getChild(tc.plaintiffId)?.name ?? '?';
    final accused = fp.getChild(tc.accusedId)?.name ?? '?';
    final isParent =
        Provider.of<PinProvider>(context, listen: false).isParentMode;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: Colors.grey.shade900,
          borderRadius:
              const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(2))),
            ),
            const SizedBox(height: 20),
            Text('⚖️ ${tc.title}',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Text(tc.description,
                style: const TextStyle(color: Colors.white70)),
            const SizedBox(height: 16),
            _infoRow('Plaignant', plaintiff, Colors.amber),
            _infoRow('Accusé', accused, Colors.redAccent),
            _infoRow('Statut', '${tc.statusEmoji} ${tc.statusLabel}', tc.statusColor),
            if (tc.verdict != null)
              _infoRow('Verdict', '${tc.verdictEmoji} ${tc.verdictLabel}', Colors.purple),
            if (tc.verdictReason != null && tc.verdictReason!.isNotEmpty)
              _infoRow('Raison', tc.verdictReason!, Colors.purple),
            const SizedBox(height: 20),
            if (isParent && !tc.isClosed) ...[
              if (tc.status == TribunalStatus.filed)
                _actionButton('▶️ Ouvrir l\'audience', Colors.blue, () {
                  fp.startTribunalHearing(tc.id);
                  Navigator.pop(ctx);
                }),
              if (tc.status == TribunalStatus.inProgress)
                _actionButton('🤔 Passer en délibération', Colors.purple,
                    () {
                  fp.startTribunalDeliberation(tc.id);
                  Navigator.pop(ctx);
                }),
              if (tc.status == TribunalStatus.deliberation) ...[
                _actionButton('⚠️ Coupable', Colors.red, () {
                  Navigator.pop(ctx);
                  _showVerdictDialog(fp, tc, TribunalVerdict.guilty);
                }),
                const SizedBox(height: 8),
                _actionButton('✅ Innocent', Colors.green, () {
                  Navigator.pop(ctx);
                  _showVerdictDialog(fp, tc, TribunalVerdict.innocent);
                }),
              ],
              const SizedBox(height: 8),
              _actionButton('🗑️ Classer sans suite', Colors.grey, () {
                fp.dismissTribunalCase(tc.id);
                Navigator.pop(ctx);
              }),
            ],
            if (!isParent && !tc.isClosed)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Center(
                  child: Text(
                    '🔒 Mode parent requis pour agir',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.4),
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text('$label: ',
              style: const TextStyle(color: Colors.white54, fontSize: 14)),
          Expanded(
            child: Text(value,
                style: TextStyle(
                    color: color,
                    fontSize: 14,
                    fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _actionButton(String label, Color color, VoidCallback onTap) {
    return SizedBox(
      width: double.infinity,
      child: TvFocusWrapper(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: color.withOpacity(0.15),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color.withOpacity(0.4)),
          ),
          child: Center(
            child: Text(label,
                style: TextStyle(
                    color: color, fontWeight: FontWeight.bold, fontSize: 15)),
          ),
        ),
      ),
    );
  }

  void _showVerdictDialog(
      FamilyProvider fp, TribunalCase tc, TribunalVerdict verdict) {
    final reasonCtrl = TextEditingController();
    final pointsCtrl = TextEditingController(text: '0');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.grey.shade900,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          verdict == TribunalVerdict.guilty
              ? '⚠️ Verdict: Coupable'
              : '✅ Verdict: Innocent',
          style: const TextStyle(color: Colors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: reasonCtrl,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Raison du verdict',
                labelStyle: const TextStyle(color: Colors.white70),
                enabledBorder: OutlineInputBorder(
                  borderSide:
                      BorderSide(color: Colors.purple.withOpacity(0.5)),
                  borderRadius: BorderRadius.circular(12),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: const BorderSide(color: Colors.purple),
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: pointsCtrl,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Points pour l\'accusé (négatif = pénalité)',
                labelStyle: const TextStyle(color: Colors.white70),
                enabledBorder: OutlineInputBorder(
                  borderSide:
                      BorderSide(color: Colors.purple.withOpacity(0.5)),
                  borderRadius: BorderRadius.circular(12),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: const BorderSide(color: Colors.purple),
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child:
                const Text('Annuler', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.purple),
            onPressed: () {
              final pts = int.tryParse(pointsCtrl.text) ?? 0;
              fp.renderVerdict(
                caseId: tc.id,
                verdict: verdict,
                reason: reasonCtrl.text.trim().isNotEmpty
                    ? reasonCtrl.text.trim()
                    : (verdict == TribunalVerdict.guilty
                        ? 'Coupable'
                        : 'Innocent'),
                accusedPoints: pts,
              );
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('⚖️ Verdict rendu !'),
                  backgroundColor: Colors.purple.shade700,
                ),
              );
            },
            child: const Text('Rendre le verdict'),
          ),
        ],
      ),
    );
  }

  void _showFileCase(FamilyProvider fp) {
    if (fp.children.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Il faut au moins 2 enfants pour le tribunal'),
            backgroundColor: Colors.orange),
      );
      return;
    }

    final titleCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    String? plaintiffId;
    String? accusedId;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: Colors.grey.shade900,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('⚖️ Nouvelle Affaire',
              style: TextStyle(color: Colors.white)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: titleCtrl,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Titre de l\'affaire',
                    labelStyle: const TextStyle(color: Colors.white70),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(
                          color: Colors.purple.withOpacity(0.5)),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: const BorderSide(color: Colors.purple),
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descCtrl,
                  style: const TextStyle(color: Colors.white),
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: 'Description des faits',
                    labelStyle: const TextStyle(color: Colors.white70),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(
                          color: Colors.purple.withOpacity(0.5)),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: const BorderSide(color: Colors.purple),
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text('Plaignant :',
                    style: TextStyle(color: Colors.white70, fontSize: 13)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: fp.children.map((c) {
                    final selected = plaintiffId == c.id;
                    return GestureDetector(
                      onTap: () =>
                          setDialogState(() => plaintiffId = c.id),
                      child: Chip(
                        label: Text(c.name,
                            style: TextStyle(
                                color: selected
                                    ? Colors.amber
                                    : Colors.white70)),
                        backgroundColor: selected
                            ? Colors.amber.withOpacity(0.2)
                            : Colors.white.withOpacity(0.1),
                        side: selected
                            ? const BorderSide(color: Colors.amber)
                            : BorderSide.none,
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 12),
                const Text('Accusé :',
                    style: TextStyle(color: Colors.white70, fontSize: 13)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: fp.children
                      .where((c) => c.id != plaintiffId)
                      .map((c) {
                    final selected = accusedId == c.id;
                    return GestureDetector(
                      onTap: () =>
                          setDialogState(() => accusedId = c.id),
                      child: Chip(
                        label: Text(c.name,
                            style: TextStyle(
                                color: selected
                                    ? Colors.redAccent
                                    : Colors.white70)),
                        backgroundColor: selected
                            ? Colors.redAccent.withOpacity(0.2)
                            : Colors.white.withOpacity(0.1),
                        side: selected
                            ? const BorderSide(color: Colors.redAccent)
                            : BorderSide.none,
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Annuler',
                  style: TextStyle(color: Colors.white54)),
            ),
            ElevatedButton(
              style:
                  ElevatedButton.styleFrom(backgroundColor: Colors.purple),
              onPressed: () {
                if (titleCtrl.text.trim().isEmpty ||
                    plaintiffId == null ||
                    accusedId == null) return;
                fp.fileTribunalCase(
                  title: titleCtrl.text.trim(),
                  description: descCtrl.text.trim(),
                  plaintiffId: plaintiffId!,
                  accusedId: accusedId!,
                );
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('⚖️ Affaire déposée !'),
                    backgroundColor: Colors.purple.shade700,
                  ),
                );
              },
              child: const Text('Déposer l\'affaire'),
            ),
          ],
        ),
      ),
    );
  }
}
