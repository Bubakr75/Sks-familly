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
import '../widgets/timeline_widget.dart';
import '../utils/tv_detector.dart';
import 'timeline_screen.dart';
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
  int _tabIndex = 0;
  bool get isTV => TvDetector.isTV;

  @override
  void initState() {
    super.initState();
    _shieldController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500))
      ..repeat(reverse: true);
    _shieldPulse = Tween<double>(begin: 0.95, end: 1.08).animate(
      CurvedAnimation(parent: _shieldController, curve: Curves.easeInOut));
    _listController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))
      ..forward();
    final provider = context.read<FamilyProvider>();
    if (provider.children.isNotEmpty) _selectedChildId = provider.children.first.id;
  }

  @override
  void dispose() { _shieldController.dispose(); _listController.dispose(); super.dispose(); }

  List<ImmunityLines> _getImmunities(FamilyProvider provider) {
    if (_selectedChildId == null) return [];
    return List<ImmunityLines>.from(provider.getImmunitiesForChild(_selectedChildId!))
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  List<HistoryEntry> _getImmunityHistory(FamilyProvider provider) {
    if (_selectedChildId == null) return [];
    return provider.getHistoryForChild(_selectedChildId!).where((h) =>
      h.category.toLowerCase() == 'immunit\u00E9' ||
      h.category.toLowerCase() == 'punition' ||
      h.reason.toLowerCase().contains('immunit\u00E9') ||
      h.reason.toLowerCase().contains('bouclier') ||
      h.reason.toLowerCase().contains('shield')).toList();
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
    if (imm.isFullyUsed) return '\u00C9puis\u00E9e';
    if (imm.isExpired) return 'Expir\u00E9e';
    return 'Active';
  }

  // ── Dialogue ajout ──
  void _showAddImmunityDialog() {
    final reasonCtrl = TextEditingController();
    final linesCtrl = TextEditingController(text: '1');
    DateTime? expiresAt;

    showDialog(context: context, builder: (ctx) => StatefulBuilder(
      builder: (ctx, setDialogState) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        insetPadding: EdgeInsets.symmetric(horizontal: isTV ? 100 : 24, vertical: isTV ? 30 : 24),
        title: Text('\u{1F6E1} Nouvelle Immunit\u00E9',
          style: TextStyle(color: Colors.white, fontSize: isTV ? 24 : 18)),
        content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
          TvTextField(
            controller: reasonCtrl,
            style: TextStyle(color: Colors.white, fontSize: isTV ? 18 : 14),
            decoration: InputDecoration(
              labelText: 'Raison',
              labelStyle: TextStyle(color: Colors.white70, fontSize: isTV ? 16 : 14),
              enabledBorder: OutlineInputBorder(
                borderSide: BorderSide(color: Colors.greenAccent.withOpacity(0.5)),
                borderRadius: BorderRadius.circular(12)),
              focusedBorder: OutlineInputBorder(
                borderSide: const BorderSide(color: Colors.greenAccent),
                borderRadius: BorderRadius.circular(12)),
            ),
          ),
          SizedBox(height: isTV ? 20 : 16),
          Text('Nombre de lignes', style: TextStyle(color: Colors.white70, fontSize: isTV ? 18 : 13)),
          const SizedBox(height: 8),
          SizedBox(width: isTV ? 140 : 120, child: TvTextField(
            controller: linesCtrl, keyboardType: TextInputType.number, textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white, fontSize: isTV ? 28 : 22, fontWeight: FontWeight.bold),
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(filled: true, fillColor: Colors.greenAccent.withOpacity(0.2),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none)),
          )),
          const SizedBox(height: 8),
          Wrap(spacing: 8, children: [1, 3, 5, 10, 20].map((n) => TvFocusWrapper(
            onTap: () => setDialogState(() => linesCtrl.text = '$n'),
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: isTV ? 14 : 10, vertical: isTV ? 8 : 6),
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
              child: Text('$n', style: TextStyle(color: Colors.white70, fontSize: isTV ? 16 : 14)),
            ),
          )).toList()),
          SizedBox(height: isTV ? 20 : 16),
          TvFocusWrapper(
            onTap: () async {
              final picked = await showDatePicker(context: ctx,
                initialDate: DateTime.now().add(const Duration(days: 7)),
                firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 365)));
              if (picked != null) setDialogState(() => expiresAt = picked);
            },
            child: Container(
              padding: EdgeInsets.all(isTV ? 16 : 12),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.greenAccent.withOpacity(0.5)),
                borderRadius: BorderRadius.circular(12)),
              child: Row(children: [
                Icon(Icons.calendar_today, color: Colors.greenAccent, size: isTV ? 24 : 20),
                const SizedBox(width: 8),
                Text(expiresAt != null
                  ? 'Expire le ${expiresAt!.day}/${expiresAt!.month}/${expiresAt!.year}'
                  : 'Date d\'expiration (optionnel)',
                  style: TextStyle(color: Colors.white70, fontSize: isTV ? 18 : 14)),
              ]),
            ),
          ),
        ])),
        actions: [
          TvFocusWrapper(onTap: () => Navigator.pop(ctx),
            child: TextButton(onPressed: () => Navigator.pop(ctx),
              child: Text('Annuler', style: TextStyle(color: Colors.white54, fontSize: isTV ? 18 : 14)))),
          TvFocusWrapper(
            onTap: () {
              final reason = reasonCtrl.text.trim();
              final lines = int.tryParse(linesCtrl.text) ?? 0;
              if (reason.isEmpty || _selectedChildId == null || lines <= 0) return;
              context.read<FamilyProvider>().addImmunity(_selectedChildId!, reason, lines, expiresAt: expiresAt);
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text('\u{1F6E1} $lines immunit\u00E9${lines > 1 ? 's' : ''} ajout\u00E9e${lines > 1 ? 's' : ''}'),
                backgroundColor: Colors.green.shade700));
            },
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.greenAccent.shade700,
                padding: EdgeInsets.symmetric(horizontal: isTV ? 24 : 16, vertical: isTV ? 14 : 10)),
              onPressed: () {
                final reason = reasonCtrl.text.trim();
                final lines = int.tryParse(linesCtrl.text) ?? 0;
                if (reason.isEmpty || _selectedChildId == null || lines <= 0) return;
                context.read<FamilyProvider>().addImmunity(_selectedChildId!, reason, lines, expiresAt: expiresAt);
                Navigator.pop(ctx);
              },
              child: Text('Ajouter', style: TextStyle(fontSize: isTV ? 18 : 14)),
            ),
          ),
        ],
      ),
    ));
  }

  // ── Detail dialog (remplace bottom sheet) ──
  void _showDetailDialog(ImmunityLines imm) {
    showDialog(context: context, builder: (ctx) => Consumer<FamilyProvider>(
      builder: (ctx, provider, _) {
        final current = provider.immunities.firstWhere((i) => i.id == imm.id, orElse: () => imm);
        return AlertDialog(
          backgroundColor: const Color(0xFF1E1E2E),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          insetPadding: EdgeInsets.symmetric(horizontal: isTV ? 100 : 24, vertical: isTV ? 40 : 24),
          title: Row(children: [
            Icon(_statusIcon(current), color: _statusColor(current), size: isTV ? 32 : 28),
            const SizedBox(width: 12),
            Expanded(child: Text(current.reason, style: TextStyle(
              color: Colors.white, fontSize: isTV ? 24 : 20, fontWeight: FontWeight.bold))),
          ]),
          content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            _detailRow('Statut', _statusText(current), _statusColor(current)),
            _detailRow('Lignes disponibles', '${current.availableLines}/${current.lines}', Colors.white),
            _detailRow('Cr\u00E9\u00E9e le',
              '${current.createdAt.day}/${current.createdAt.month}/${current.createdAt.year}', Colors.white70),
            if (current.expiresAt != null)
              _detailRow('Expire le', current.expiresLabel, Colors.orangeAccent),
            SizedBox(height: isTV ? 24 : 20),
            if (current.isUsable)
              TvFocusWrapper(
                onTap: () {
                  Navigator.pop(ctx);
                  Navigator.push(context, DoorPageRoute(page: TradeScreen(childId: _selectedChildId!)));
                },
                child: Container(
                  width: double.infinity,
                  padding: EdgeInsets.symmetric(vertical: isTV ? 16 : 14),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [Colors.purple.shade700, Colors.blue.shade700]),
                    borderRadius: BorderRadius.circular(14)),
                  child: Center(child: Text('\u{1F91D} Proposer un Trade', style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold, fontSize: isTV ? 18 : 15))),
                ),
              ),
            if (current.isUsable) SizedBox(height: isTV ? 12 : 8),
            TvFocusWrapper(
              onTap: () {
                context.read<FamilyProvider>().removeImmunity(current.id);
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: const Text('\u{1F5D1} Immunit\u00E9 supprim\u00E9e'),
                  backgroundColor: Colors.red.shade700));
              },
              child: Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(vertical: isTV ? 16 : 14),
                decoration: BoxDecoration(
                  color: Colors.red.shade900.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.redAccent.withOpacity(0.5))),
                child: Center(child: Text('\u{1F5D1} Supprimer', style: TextStyle(
                  color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: isTV ? 18 : 15))),
              ),
            ),
          ]),
          actions: [
            TvFocusWrapper(onTap: () => Navigator.pop(ctx),
              child: TextButton(onPressed: () => Navigator.pop(ctx),
                child: Text('Fermer', style: TextStyle(color: Colors.white54, fontSize: isTV ? 18 : 14)))),
          ],
        );
      },
    ));
  }

  Widget _detailRow(String label, String value, Color color) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: isTV ? 6 : 4),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label, style: TextStyle(color: Colors.white54, fontSize: isTV ? 18 : 14)),
        Text(value, style: TextStyle(color: color, fontSize: isTV ? 18 : 14, fontWeight: FontWeight.bold)),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<FamilyProvider>(builder: (context, provider, _) {
      final children = provider.children;
      final immunities = _getImmunities(provider);
      final immHistory = _getImmunityHistory(provider);
      final activeCount = immunities.where((e) => e.isUsable).length;
      final totalLines = immunities.fold<int>(0, (s, e) => s + e.availableLines);

      return Scaffold(
        backgroundColor: Colors.transparent,
        body: AnimatedBackground(
          backgroundImage: 'assets/images/immunity_bg.png',
          child: SafeArea(child: Column(children: [
            // Header
            Padding(
              padding: EdgeInsets.all(isTV ? 20 : 16),
              child: Row(children: [
                TvFocusWrapper(
                  autofocus: isTV,
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    padding: EdgeInsets.all(isTV ? 10 : 8),
                    decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                    child: Icon(Icons.arrow_back, color: Colors.white, size: isTV ? 28 : 24),
                  ),
                ),
                SizedBox(width: isTV ? 14 : 12),
                ScaleTransition(scale: _shieldPulse,
                  child: Text('\u{1F6E1}', style: TextStyle(fontSize: isTV ? 36 : 32))),
                const SizedBox(width: 8),
                Expanded(child: Text('Immunit\u00E9s', style: TextStyle(
                  color: Colors.white, fontSize: isTV ? 28 : 24, fontWeight: FontWeight.bold))),
                if (_selectedChildId != null)
                  TvFocusWrapper(
                    onTap: () => Navigator.push(context, MaterialPageRoute(
                      builder: (_) => TimelineScreen(initialChildId: _selectedChildId))),
                    child: Container(
                      padding: EdgeInsets.all(isTV ? 10 : 8),
                      margin: EdgeInsets.only(right: isTV ? 12 : 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF7C4DFF).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFF7C4DFF).withOpacity(0.5))),
                      child: Icon(Icons.timeline_rounded, color: const Color(0xFF7C4DFF), size: isTV ? 24 : 20),
                    ),
                  ),
                TvFocusWrapper(
                  onTap: _showAddImmunityDialog,
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: isTV ? 20 : 16, vertical: isTV ? 12 : 10),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [Colors.greenAccent.shade700, Colors.green.shade700]),
                      borderRadius: BorderRadius.circular(14)),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.add, color: Colors.white, size: isTV ? 24 : 20),
                      const SizedBox(width: 4),
                      Text('Ajouter', style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold, fontSize: isTV ? 18 : 14)),
                    ]),
                  ),
                ),
              ]),
            ),

            // Child selector
            if (children.length > 1)
              SizedBox(height: isTV ? 60 : 50,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: EdgeInsets.symmetric(horizontal: isTV ? 20 : 16),
                  itemCount: children.length,
                  itemBuilder: (ctx, i) {
                    final child = children[i];
                    final selected = child.id == _selectedChildId;
                    return Padding(padding: const EdgeInsets.only(right: 8),
                      child: TvFocusWrapper(
                        onTap: () => setState(() => _selectedChildId = child.id),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          padding: EdgeInsets.symmetric(horizontal: isTV ? 20 : 16, vertical: isTV ? 10 : 8),
                          decoration: BoxDecoration(
                            color: selected ? Colors.greenAccent.withOpacity(0.3) : Colors.white.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                            border: selected ? Border.all(color: Colors.greenAccent, width: 2) : null),
                          child: Center(child: Text(
                            '${child.avatar.isNotEmpty ? child.avatar : '\u{1F464}'} ${child.name}',
                            style: TextStyle(
                              color: selected ? Colors.greenAccent : Colors.white70,
                              fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                              fontSize: isTV ? 18 : 14))),
                        ),
                      ),
                    );
                  },
                ),
              ),

            const SizedBox(height: 8),

            // Stats
            Padding(padding: EdgeInsets.symmetric(horizontal: isTV ? 20 : 16),
              child: GlassCard(child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
                _statChip('Actives', '$activeCount', Colors.greenAccent),
                Container(width: 1, height: 30, color: Colors.white24),
                _statChip('Total lignes', '$totalLines', Colors.cyanAccent),
                Container(width: 1, height: 30, color: Colors.white24),
                _statChip('Total', '${immunities.length}', Colors.white70),
              ]))),

            const SizedBox(height: 8),

            // Toggle tabs
            Padding(padding: EdgeInsets.symmetric(horizontal: isTV ? 20 : 16),
              child: Row(children: [
                Expanded(child: TvFocusWrapper(
                  onTap: () => setState(() => _tabIndex = 0),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: EdgeInsets.symmetric(vertical: isTV ? 14 : 10),
                    decoration: BoxDecoration(
                      color: _tabIndex == 0 ? Colors.greenAccent.withOpacity(0.15) : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _tabIndex == 0 ? Colors.greenAccent : Colors.white24)),
                    child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Icon(Icons.shield_rounded, size: isTV ? 20 : 16,
                        color: _tabIndex == 0 ? Colors.greenAccent : Colors.white38),
                      const SizedBox(width: 6),
                      Text('Immunit\u00E9s', style: TextStyle(
                        color: _tabIndex == 0 ? Colors.greenAccent : Colors.white38,
                        fontWeight: _tabIndex == 0 ? FontWeight.bold : FontWeight.normal,
                        fontSize: isTV ? 18 : 13)),
                    ]),
                  ),
                )),
                const SizedBox(width: 8),
                Expanded(child: TvFocusWrapper(
                  onTap: () => setState(() => _tabIndex = 1),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: EdgeInsets.symmetric(vertical: isTV ? 14 : 10),
                    decoration: BoxDecoration(
                      color: _tabIndex == 1 ? const Color(0xFF7C4DFF).withOpacity(0.2) : Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _tabIndex == 1 ? const Color(0xFF7C4DFF) : Colors.white24)),
                    child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Icon(Icons.timeline_rounded, size: isTV ? 20 : 16,
                        color: _tabIndex == 1 ? const Color(0xFF7C4DFF) : Colors.white38),
                      const SizedBox(width: 6),
                      Text('Historique', style: TextStyle(
                        color: _tabIndex == 1 ? const Color(0xFF7C4DFF) : Colors.white38,
                        fontWeight: _tabIndex == 1 ? FontWeight.bold : FontWeight.normal,
                        fontSize: isTV ? 18 : 13)),
                    ]),
                  ),
                )),
              ]),
            ),

            const SizedBox(height: 8),

            // Content
            Expanded(child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: _tabIndex == 0 ? _buildImmunitiesList(immunities) : _buildHistoryTab(immHistory),
            )),
          ])),
        ),
      );
    });
  }

  Widget _buildImmunitiesList(List<ImmunityLines> immunities) {
    if (immunities.isEmpty) {
      return Center(key: const ValueKey('empty'), child: Column(mainAxisSize: MainAxisSize.min, children: [
        ScaleTransition(scale: _shieldPulse, child: Text('\u{1F6E1}', style: TextStyle(fontSize: isTV ? 72 : 64))),
        const SizedBox(height: 16),
        Text('Aucune immunit\u00E9', style: TextStyle(color: Colors.white54, fontSize: isTV ? 22 : 18)),
        const SizedBox(height: 8),
        Text('Appuyez sur + pour en ajouter', style: TextStyle(color: Colors.white38, fontSize: isTV ? 16 : 14)),
      ]));
    }

    return ListView.builder(
      key: const ValueKey('list'),
      padding: EdgeInsets.symmetric(horizontal: isTV ? 20 : 16),
      itemCount: immunities.length,
      itemBuilder: (ctx, index) {
        final imm = immunities[index];
        final delay = index * 0.1;
        return AnimatedBuilder(
          animation: _listController,
          builder: (ctx, child) {
            final t = Curves.elasticOut.transform(
              ((_listController.value - delay) / (1 - delay)).clamp(0.0, 1.0));
            return Transform.translate(offset: Offset(0, 50 * (1 - t)),
              child: Opacity(opacity: t, child: child));
          },
          child: Padding(padding: EdgeInsets.only(bottom: isTV ? 12 : 8),
            child: TvFocusWrapper(
              onTap: () => _showDetailDialog(imm),
              child: GlassCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Container(
                    width: isTV ? 56 : 48, height: isTV ? 56 : 48,
                    decoration: BoxDecoration(
                      color: _statusColor(imm).withOpacity(0.2), borderRadius: BorderRadius.circular(14)),
                    child: Icon(_statusIcon(imm), color: _statusColor(imm), size: isTV ? 28 : 24),
                  ),
                  SizedBox(width: isTV ? 14 : 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(imm.reason, style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold, fontSize: isTV ? 20 : 16)),
                    const SizedBox(height: 4),
                    Row(children: [
                      Text(_statusText(imm), style: TextStyle(color: _statusColor(imm), fontSize: isTV ? 16 : 12)),
                      const SizedBox(width: 8),
                      Text('${imm.availableLines}/${imm.lines} lignes',
                        style: TextStyle(color: Colors.white54, fontSize: isTV ? 16 : 12)),
                    ]),
                  ])),
                  if (imm.isUsable)
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: isTV ? 12 : 8, vertical: isTV ? 6 : 4),
                      decoration: BoxDecoration(
                        color: Colors.greenAccent.withOpacity(0.2), borderRadius: BorderRadius.circular(8)),
                      child: Text('Utilisable', style: TextStyle(
                        color: Colors.greenAccent, fontSize: isTV ? 14 : 11)),
                    ),
                  const SizedBox(width: 8),
                  Icon(Icons.chevron_right, color: Colors.white38, size: isTV ? 24 : 20),
                ]),
                const SizedBox(height: 10),
              ])),
            ),
          ),
        );
      },
    );
  }

  Widget _buildHistoryTab(List<HistoryEntry> history) {
    return Column(key: const ValueKey('history'), children: [
      Padding(padding: EdgeInsets.fromLTRB(isTV ? 20 : 16, 4, isTV ? 20 : 16, 8),
        child: Row(children: [
          _summaryChip('${history.where((h) => h.isBonus).length}', '\u2705 Cr\u00E9dits', Colors.greenAccent),
          const SizedBox(width: 8),
          _summaryChip('${history.where((h) => !h.isBonus).length}', '\u{1F6E1} Utilis\u00E9es', Colors.cyanAccent),
          const Spacer(),
          if (_selectedChildId != null)
            TvFocusWrapper(
              onTap: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => TimelineScreen(initialChildId: _selectedChildId))),
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: isTV ? 14 : 10, vertical: isTV ? 8 : 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF7C4DFF).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFF7C4DFF).withOpacity(0.5))),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.open_in_full_rounded, color: const Color(0xFF7C4DFF), size: isTV ? 18 : 14),
                  const SizedBox(width: 4),
                  Text('Tout voir', style: TextStyle(
                    color: const Color(0xFF7C4DFF), fontSize: isTV ? 16 : 12, fontWeight: FontWeight.bold)),
                ]),
              ),
            ),
        ]),
      ),
      Expanded(child: history.isEmpty
        ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.timeline_rounded, color: Colors.white24, size: isTV ? 64 : 56),
            SizedBox(height: isTV ? 14 : 12),
            Text('Aucun historique li\u00E9 aux immunit\u00E9s',
              style: TextStyle(color: Colors.white54, fontSize: isTV ? 20 : 15)),
          ]))
        : TimelineWidget(entries: history)),
    ]);
  }

  Widget _statChip(String label, String value, Color color) => Column(mainAxisSize: MainAxisSize.min, children: [
    Text(value, style: TextStyle(color: color, fontSize: isTV ? 24 : 20, fontWeight: FontWeight.bold)),
    const SizedBox(height: 2),
    Text(label, style: TextStyle(color: Colors.white54, fontSize: isTV ? 14 : 12)),
  ]);

  Widget _summaryChip(String value, String label, Color color) => Container(
    padding: EdgeInsets.symmetric(horizontal: isTV ? 14 : 10, vertical: isTV ? 7 : 5),
    decoration: BoxDecoration(
      color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(10),
      border: Border.all(color: color.withOpacity(0.3))),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Text(value, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: isTV ? 16 : 13)),
      const SizedBox(width: 4),
      Text(label, style: TextStyle(color: color.withOpacity(0.7), fontSize: isTV ? 14 : 11)),
    ]),
  );
}