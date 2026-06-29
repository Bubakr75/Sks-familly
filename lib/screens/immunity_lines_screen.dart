// lib/screens/immunity_lines_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/immunity_lines.dart';
import '../models/history_entry.dart';
import '../providers/family_provider.dart';
import '../widgets/animated_background.dart';
import '../widgets/glass_card.dart';
import '../widgets/tv_focus_wrapper.dart';
import '../widgets/animated_page_transition.dart';
import '../widgets/timeline_widget.dart';   // ✅ ajout
import 'timeline_screen.dart';              // ✅ ajout
import 'trade_screen.dart';

class ImmunityLinesScreen extends StatefulWidget {
  const ImmunityLinesScreen({super.key});
  @override
  State<ImmunityLinesScreen> createState() => _ImmunityLinesScreenState();
}

class _ImmunityLinesScreenState extends State<ImmunityLinesScreen>
    with TickerProviderStateMixin {
  late AnimationController _shieldController;
  late AnimationController _listController;
  late Animation<double> _shieldPulse;
  String? _selectedChildId;

  // ✅ onglet actif : 0 = Immunités, 1 = Historique
  int _tabIndex = 0;

  @override
  void initState() {
    super.initState();
    _shieldController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1500))
      ..repeat(reverse: true);
    _shieldPulse = Tween<double>(begin: 0.95, end: 1.08).animate(
        CurvedAnimation(
            parent: _shieldController, curve: Curves.easeInOut));
    _listController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1200))
      ..forward();

    final provider = context.read<FamilyProvider>();
    if (provider.children.isNotEmpty) {
      _selectedChildId = provider.children.first.id;
    }
  }

  @override
  void dispose() {
    _shieldController.dispose();
    _listController.dispose();
    super.dispose();
  }

  // ─── Helpers ──────────────────────────────────────────────────────────────
  List<ImmunityLines> _getImmunities(FamilyProvider provider) {
    if (_selectedChildId == null) return [];
    return List<ImmunityLines>.from(
        provider.getImmunitiesForChild(_selectedChildId!))
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  // ✅ Historique filtré : uniquement les entrées liées aux immunités
  List<HistoryEntry> _getImmunityHistory(FamilyProvider provider) {
    if (_selectedChildId == null) return [];
    return provider
        .getHistoryForChild(_selectedChildId!)
        .where((h) =>
            h.category.toLowerCase() == 'immunité' ||
            h.category.toLowerCase() == 'punition' ||
            h.reason.toLowerCase().contains('immunité') ||
            h.reason.toLowerCase().contains('bouclier') ||
            h.reason.toLowerCase().contains('shield'))
        .toList();
  }

  Color _statusColor(ImmunityLines imm) {
    if (imm.isFullyUsed) return Colors.grey;
    if (imm.isExpired) return Colors.red.shade300;
    return Colors.greenAccent;
  }

  IconData _statusIcon(ImmunityLines imm) {
    if (imm.isFullyUsed) return Icons.check_circle;
    if (imm.isExpired) return Icons.timer_off;
    return Icons.shield;
  }

  String _statusText(ImmunityLines imm) {
    if (imm.isFullyUsed) return 'Épuisée';
    if (imm.isExpired) return 'Expirée';
    return 'Active';
  }

  // ─── Dialogue ajout immunité ───────────────────────────────────────────────
  void _showAddImmunityDialog() {
    final reasonCtrl = TextEditingController();
    final linesCtrl  = TextEditingController(text: '1');
    DateTime? expiresAt;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: Colors.grey.shade900,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20)),
          title: const Text('🛡️ Nouvelle Immunité',
              style: TextStyle(color: Colors.white)),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(
                controller: reasonCtrl,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Raison',
                  labelStyle: const TextStyle(color: Colors.white70),
                  enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(
                          color: Colors.greenAccent.withOpacity(0.5)),
                      borderRadius: BorderRadius.circular(12)),
                  focusedBorder: OutlineInputBorder(
                      borderSide:
                          const BorderSide(color: Colors.greenAccent),
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 16),
              const Text('Nombre de lignes',
                  style:
                      TextStyle(color: Colors.white70, fontSize: 13)),
              const SizedBox(height: 8),
              SizedBox(
                width: 120,
                child: TextField(
                  controller: linesCtrl,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold),
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly
                  ],
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: Colors.greenAccent.withOpacity(0.2),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [1, 3, 5, 10, 20].map((n) {
                  return GestureDetector(
                    onTap: () =>
                        setDialogState(() => linesCtrl.text = '$n'),
                    child: Chip(
                      label: Text('$n',
                          style: const TextStyle(
                              color: Colors.white70)),
                      backgroundColor: Colors.white.withOpacity(0.1),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              GestureDetector(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: ctx,
                    initialDate:
                        DateTime.now().add(const Duration(days: 7)),
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now()
                        .add(const Duration(days: 365)),
                  );
                  if (picked != null) {
                    setDialogState(() => expiresAt = picked);
                  }
                },
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    border: Border.all(
                        color: Colors.greenAccent.withOpacity(0.5)),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(children: [
                    const Icon(Icons.calendar_today,
                        color: Colors.greenAccent, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      expiresAt != null
                          ? 'Expire le ${expiresAt!.day}/${expiresAt!.month}/${expiresAt!.year}'
                          : 'Date d\'expiration (optionnel)',
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ]),
                ),
              ),
            ]),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Annuler',
                    style: TextStyle(color: Colors.white54))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.greenAccent.shade700),
              onPressed: () {
                final reason = reasonCtrl.text.trim();
                final lines  = int.tryParse(linesCtrl.text) ?? 0;
                if (reason.isEmpty ||
                    _selectedChildId == null ||
                    lines <= 0) return;
                context.read<FamilyProvider>().addImmunity(
                    _selectedChildId!, reason, lines,
                    expiresAt: expiresAt);
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text(
                        '🛡️ $lines immunité${lines > 1 ? 's' : ''} ajoutée${lines > 1 ? 's' : ''}'),
                    backgroundColor: Colors.green.shade700));
              },
              child: const Text('Ajouter'),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Fiche détail immunité ─────────────────────────────────────────────────
  void _showDetailSheet(ImmunityLines imm) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Consumer<FamilyProvider>(
        builder: (ctx, provider, _) {
          final current = provider.immunities.firstWhere(
            (i) => i.id == imm.id,
            orElse: () => imm,
          );

          return Container(
            decoration: BoxDecoration(
              color: Colors.grey.shade900,
              borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(24)),
            ),
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40, height: 4,
                    decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(2)),
                  ),
                ),
                const SizedBox(height: 20),
                Row(children: [
                  Icon(_statusIcon(current),
                      color: _statusColor(current), size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(current.reason,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold)),
                  ),
                ]),
                const SizedBox(height: 16),
                _detailRow(
                    'Statut', _statusText(current), _statusColor(current)),
                _detailRow(
                    'Lignes disponibles',
                    '${current.availableLines}/${current.lines}',
                    Colors.white),
                _detailRow(
                    'Créée le',
                    '${current.createdAt.day}/${current.createdAt.month}/${current.createdAt.year}',
                    Colors.white70),
                if (current.expiresAt != null)
                  _detailRow('Expire le', current.expiresLabel,
                      Colors.orangeAccent),
                const SizedBox(height: 20),
                // ── Barre de progression lignes ──
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: current.lines > 0
                        ? (current.lines - current.usedLines) /
                            current.lines
                        : 0,
                    minHeight: 8,
                    backgroundColor: Colors.white12,
                    valueColor: AlwaysStoppedAnimation(
                        _statusColor(current)),
                  ),
                ),
                const SizedBox(height: 20),
                if (current.isUsable) ...[
                  SizedBox(
                    width: double.infinity,
                    child: GestureDetector(
                      onTap: () {
                        Navigator.pop(ctx);
                        Navigator.push(
                            context,
                            DoorPageRoute(
                                page: TradeScreen(
                                    childId: _selectedChildId!)));
                      },
                      child: Container(
                        padding:
                            const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(colors: [
                            Colors.purple.shade700,
                            Colors.blue.shade700
                          ]),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Center(
                          child: Text('🤝 Proposer un Trade',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                SizedBox(
                  width: double.infinity,
                  child: GestureDetector(
                    onTap: () {
                      context
                          .read<FamilyProvider>()
                          .removeImmunity(current.id);
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                              content:
                                  const Text('🗑️ Immunité supprimée'),
                              backgroundColor: Colors.red.shade700));
                    },
                    child: Container(
                      padding:
                          const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        color: Colors.red.shade900.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                            color: Colors.redAccent.withOpacity(0.5)),
                      ),
                      child: const Center(
                        child: Text('🗑️ Supprimer',
                            style: TextStyle(
                                color: Colors.redAccent,
                                fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _detailRow(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: const TextStyle(
                  color: Colors.white54, fontSize: 14)),
          Text(value,
              style: TextStyle(
                  color: color,
                  fontSize: 14,
                  fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  // ─── Build principal ───────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Consumer<FamilyProvider>(
      builder: (context, provider, _) {
        final children    = provider.children;
        final immunities  = _getImmunities(provider);
        final immHistory  = _getImmunityHistory(provider);
        final activeCount = immunities.where((e) => e.isUsable).length;
        final totalLines  =
            immunities.fold<int>(0, (s, e) => s + e.availableLines);

        return Scaffold(
          backgroundColor: Colors.transparent,
          body: AnimatedBackground(
            child: SafeArea(
              child: Column(children: [

                // ── En-tête ──────────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(children: [
                    TvFocusWrapper(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12)),
                        child: const Icon(Icons.arrow_back,
                            color: Colors.white),
                      ),
                    ),
                    const SizedBox(width: 12),
                    ScaleTransition(
                        scale: _shieldPulse,
                        child: const Text('🛡️',
                            style: TextStyle(fontSize: 32))),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text('Immunités',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.bold)),
                    ),
                    // ✅ Bouton timeline complète
                    if (_selectedChildId != null)
                      TvFocusWrapper(
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => TimelineScreen(
                                initialChildId: _selectedChildId),
                          ),
                        ),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          margin: const EdgeInsets.only(right: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF7C4DFF)
                                .withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: const Color(0xFF7C4DFF)
                                    .withOpacity(0.5)),
                          ),
                          child: const Icon(Icons.timeline_rounded,
                              color: Color(0xFF7C4DFF), size: 20),
                        ),
                      ),
                    TvFocusWrapper(
                      onTap: _showAddImmunityDialog,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(colors: [
                            Colors.greenAccent.shade700,
                            Colors.green.shade700,
                          ]),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.add, color: Colors.white, size: 20),
                            SizedBox(width: 4),
                            Text('Ajouter',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ),
                  ]),
                ),

                // ── Sélecteur enfant ──────────────────────────────────────
                if (children.length > 1)
                  SizedBox(
                    height: 50,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding:
                          const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: children.length,
                      itemBuilder: (ctx, i) {
                        final child    = children[i];
                        final selected = child.id == _selectedChildId;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: TvFocusWrapper(
                            onTap: () => setState(
                                () => _selectedChildId = child.id),
                            child: AnimatedContainer(
                              duration:
                                  const Duration(milliseconds: 300),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 8),
                              decoration: BoxDecoration(
                                color: selected
                                    ? Colors.greenAccent
                                        .withOpacity(0.3)
                                    : Colors.white.withOpacity(0.1),
                                borderRadius:
                                    BorderRadius.circular(20),
                                border: selected
                                    ? Border.all(
                                        color: Colors.greenAccent,
                                        width: 2)
                                    : null,
                              ),
                              child: Center(
                                child: Text(
                                  '${child.avatar.isNotEmpty ? child.avatar : '👤'} ${child.name}',
                                  style: TextStyle(
                                      color: selected
                                          ? Colors.greenAccent
                                          : Colors.white70,
                                      fontWeight: selected
                                          ? FontWeight.bold
                                          : FontWeight.normal),
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                const SizedBox(height: 8),

                // ── Chips stats ───────────────────────────────────────────
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16),
                  child: GlassCard(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _statChip('Actives', '$activeCount',
                            Colors.greenAccent),
                        Container(
                            width: 1,
                            height: 30,
                            color: Colors.white24),
                        _statChip('Total lignes', '$totalLines',
                            Colors.cyanAccent),
                        Container(
                            width: 1,
                            height: 30,
                            color: Colors.white24),
                        _statChip('Total', '${immunities.length}',
                            Colors.white70),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 8),

                // ✅ ── Toggle Immunités / Historique ──────────────────────
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () =>
                              setState(() => _tabIndex = 0),
                          child: AnimatedContainer(
                            duration:
                                const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(
                                vertical: 10),
                            decoration: BoxDecoration(
                              color: _tabIndex == 0
                                  ? Colors.greenAccent
                                      .withOpacity(0.2)
                                  : Colors.white.withOpacity(0.05),
                              borderRadius:
                                  BorderRadius.circular(12),
                              border: Border.all(
                                color: _tabIndex == 0
                                    ? Colors.greenAccent
                                    : Colors.white24,
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment:
                                  MainAxisAlignment.center,
                              children: [
                                Icon(Icons.shield_rounded,
                                    size: 16,
                                    color: _tabIndex == 0
                                        ? Colors.greenAccent
                                        : Colors.white38),
                                const SizedBox(width: 6),
                                Text('Immunités',
                                    style: TextStyle(
                                        color: _tabIndex == 0
                                            ? Colors.greenAccent
                                            : Colors.white38,
                                        fontWeight: _tabIndex == 0
                                            ? FontWeight.bold
                                            : FontWeight.normal,
                                        fontSize: 13)),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: GestureDetector(
                          onTap: () =>
                              setState(() => _tabIndex = 1),
                          child: AnimatedContainer(
                            duration:
                                const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(
                                vertical: 10),
                            decoration: BoxDecoration(
                              color: _tabIndex == 1
                                  ? const Color(0xFF7C4DFF)
                                      .withOpacity(0.2)
                                  : Colors.white.withOpacity(0.05),
                              borderRadius:
                                  BorderRadius.circular(12),
                              border: Border.all(
                                color: _tabIndex == 1
                                    ? const Color(0xFF7C4DFF)
                                    : Colors.white24,
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment:
                                  MainAxisAlignment.center,
                              children: [
                                Icon(Icons.timeline_rounded,
                                    size: 16,
                                    color: _tabIndex == 1
                                        ? const Color(0xFF7C4DFF)
                                        : Colors.white38),
                                const SizedBox(width: 6),
                                Text('Historique',
                                    style: TextStyle(
                                        color: _tabIndex == 1
                                            ? const Color(
                                                0xFF7C4DFF)
                                            : Colors.white38,
                                        fontWeight: _tabIndex == 1
                                            ? FontWeight.bold
                                            : FontWeight.normal,
                                        fontSize: 13)),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 8),

                // ── Contenu selon onglet ──────────────────────────────────
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: _tabIndex == 0
                        ? _buildImmunitiesList(immunities)
                        : _buildHistoryTab(immHistory),
                  ),
                ),

              ]),
            ),
          ),
        );
      },
    );
  }

  // ─── Onglet liste immunités ────────────────────────────────────────────────
  Widget _buildImmunitiesList(List<ImmunityLines> immunities) {
    if (immunities.isEmpty) {
      return Center(
        key: const ValueKey('empty'),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ScaleTransition(
                scale: _shieldPulse,
                child: const Text('🛡️',
                    style: TextStyle(fontSize: 64))),
            const SizedBox(height: 16),
            const Text('Aucune immunité',
                style:
                    TextStyle(color: Colors.white54, fontSize: 18)),
            const SizedBox(height: 8),
            const Text('Appuyez sur + pour en ajouter',
                style: TextStyle(
                    color: Colors.white38, fontSize: 14)),
          ],
        ),
      );
    }

    return ListView.builder(
      key: const ValueKey('list'),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: immunities.length,
      itemBuilder: (ctx, index) {
        final imm   = immunities[index];
        final delay = index * 0.1;
        return AnimatedBuilder(
          animation: _listController,
          builder: (ctx, child) {
            final t = Curves.elasticOut.transform(
                ((_listController.value - delay) / (1 - delay))
                    .clamp(0.0, 1.0));
            return Transform.translate(
                offset: Offset(0, 50 * (1 - t)),
                child: Opacity(opacity: t, child: child));
          },
          child: Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: TvFocusWrapper(
              onTap: () => _showDetailSheet(imm),
              child: GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Container(
                        width: 48, height: 48,
                        decoration: BoxDecoration(
                          color: _statusColor(imm).withOpacity(0.2),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(_statusIcon(imm),
                            color: _statusColor(imm), size: 24),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(imm.reason,
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16)),
                            const SizedBox(height: 4),
                            Row(children: [
                              Text(_statusText(imm),
                                  style: TextStyle(
                                      color: _statusColor(imm),
                                      fontSize: 12)),
                              const SizedBox(width: 8),
                              Text(
                                  '${imm.availableLines}/${imm.lines} lignes',
                                  style: const TextStyle(
                                      color: Colors.white54,
                                      fontSize: 12)),
                            ]),
                          ],
                        ),
                      ),
                      if (imm.isUsable)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.greenAccent.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text('Utilisable',
                              style: TextStyle(
                                  color: Colors.greenAccent,
                                  fontSize: 11)),
                        ),
                      const SizedBox(width: 8),
                      const Icon(Icons.chevron_right,
                          color: Colors.white38, size: 20),
                    ]),
                    const SizedBox(height: 10),
                    // ✅ Barre de progression lignes restantes
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: imm.lines > 0
                            ? imm.availableLines / imm.lines
                            : 0,
                        minHeight: 5,
                        backgroundColor: Colors.white10,
                        valueColor: AlwaysStoppedAnimation(
                            _statusColor(imm)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // ─── Onglet Historique timeline ────────────────────────────────────────────
  Widget _buildHistoryTab(List<HistoryEntry> history) {
    return Column(
      key: const ValueKey('history'),
      children: [
        // ── Résumé + bouton plein écran ──
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: Row(
            children: [
              _summaryChip(
                '${history.where((h) => h.isBonus).length}',
                '✅ Crédits',
                Colors.greenAccent,
              ),
              const SizedBox(width: 8),
              _summaryChip(
                '${history.where((h) => !h.isBonus).length}',
                '🛡️ Utilisées',
                Colors.cyanAccent,
              ),
              const Spacer(),
              if (_selectedChildId != null)
                GestureDetector(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => TimelineScreen(
                          initialChildId: _selectedChildId),
                    ),
                  ),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF7C4DFF).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color:
                              const Color(0xFF7C4DFF).withOpacity(0.5)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.open_in_full_rounded,
                            color: Color(0xFF7C4DFF), size: 14),
                        SizedBox(width: 4),
                        Text('Tout voir',
                            style: TextStyle(
                                color: Color(0xFF7C4DFF),
                                fontSize: 12,
                                fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
        // ── Timeline ──
        Expanded(
          child: history.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.timeline_rounded,
                          color: Colors.white24, size: 56),
                      SizedBox(height: 12),
                      Text('Aucun historique lié aux immunités',
                          style: TextStyle(
                              color: Colors.white54, fontSize: 15)),
                    ],
                  ),
                )
              : TimelineWidget(entries: history),
        ),
      ],
    );
  }

  // ─── Helpers UI ───────────────────────────────────────────────────────────
  Widget _statChip(String label, String value, Color color) =>
      Column(mainAxisSize: MainAxisSize.min, children: [
        Text(value,
            style: TextStyle(
                color: color,
                fontSize: 20,
                fontWeight: FontWeight.bold)),
        const SizedBox(height: 2),
        Text(label,
            style: const TextStyle(
                color: Colors.white54, fontSize: 12)),
      ]);

  Widget _summaryChip(String value, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(value,
              style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                  fontSize: 13)),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(
                  color: color.withOpacity(0.7), fontSize: 11)),
        ],
      ),
    );
  }
}
