// lib/screens/immunity_lines_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/immunity_lines.dart';
import '../models/punishment_lines.dart';
import '../providers/family_provider.dart';
import '../providers/pin_provider.dart';
import '../utils/pin_guard.dart';
import '../widgets/animated_background.dart';
import '../widgets/glass_card.dart';
import '../widgets/tv_focus_wrapper.dart';
import '../widgets/animated_page_transition.dart';
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

  // ── Mode : 'immunities' | 'use_on_punishment' | 'trade'
  String _mode = 'immunities';

  @override
  void initState() {
    super.initState();
    _shieldController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1500))
      ..repeat(reverse: true);
    _shieldPulse = Tween<double>(begin: 0.95, end: 1.08).animate(
        CurvedAnimation(parent: _shieldController, curve: Curves.easeInOut));
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

  // ── Helpers ──────────────────────────────────────────────
  List<ImmunityLines> _getImmunities(FamilyProvider provider) {
    if (_selectedChildId == null) return [];
    return List<ImmunityLines>.from(
        provider.getImmunitiesForChild(_selectedChildId!))
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
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

  // ── Dialog ajout immunité (parent uniquement) ─────────────
  void _showAddImmunityDialog() {
    final reasonCtrl = TextEditingController();
    final linesCtrl = TextEditingController(text: '1');
    DateTime? expiresAt;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: Colors.grey.shade900,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('🛡️ Nouvelle Immunité',
              style: TextStyle(color: Colors.white)),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              // Raison
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
                        borderRadius: BorderRadius.circular(12))),
              ),
              const SizedBox(height: 16),

              // Nombre de lignes — champ libre
              const Align(
                alignment: Alignment.centerLeft,
                child: Text('Nombre de lignes',
                    style: TextStyle(color: Colors.white70, fontSize: 13)),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: linesCtrl,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.bold),
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.08),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none),
                  suffixText: 'ligne(s)',
                  suffixStyle:
                      const TextStyle(color: Colors.white38, fontSize: 13),
                ),
              ),
              const SizedBox(height: 8),

              // Raccourcis rapides
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [1, 3, 5, 10, 20, 50].map((v) {
                  return GestureDetector(
                    onTap: () =>
                        setDialogState(() => linesCtrl.text = '$v'),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.greenAccent.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: Colors.greenAccent.withOpacity(0.4)),
                      ),
                      child: Text('$v',
                          style: const TextStyle(
                              color: Colors.greenAccent,
                              fontWeight: FontWeight.bold,
                              fontSize: 14)),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),

              // Date d'expiration optionnelle
              GestureDetector(
                onTap: () async {
                  final picked = await showDatePicker(
                      context: ctx,
                      initialDate:
                          DateTime.now().add(const Duration(days: 7)),
                      firstDate: DateTime.now(),
                      lastDate:
                          DateTime.now().add(const Duration(days: 365)));
                  if (picked != null)
                    setDialogState(() => expiresAt = picked);
                },
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                      border: Border.all(
                          color: Colors.greenAccent.withOpacity(0.5)),
                      borderRadius: BorderRadius.circular(12)),
                  child: Row(children: [
                    const Icon(Icons.calendar_today,
                        color: Colors.greenAccent, size: 20),
                    const SizedBox(width: 8),
                    Text(
                        expiresAt != null
                            ? 'Expire le ${expiresAt!.day}/${expiresAt!.month}/${expiresAt!.year}'
                            : 'Date d\'expiration (optionnel)',
                        style: const TextStyle(color: Colors.white70)),
                    if (expiresAt != null) ...[
                      const Spacer(),
                      GestureDetector(
                        onTap: () => setDialogState(() => expiresAt = null),
                        child: const Icon(Icons.close,
                            color: Colors.white38, size: 18),
                      ),
                    ]
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
                final lines = int.tryParse(linesCtrl.text.trim()) ?? 0;
                if (reason.isEmpty || _selectedChildId == null || lines < 1)
                  return;
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

  // ── Proposer d'utiliser ses immunités sur une punition ──────
  void _showUseOnPunishmentDialog(ImmunityLines imm) {
    final provider = context.read<FamilyProvider>();
    if (_selectedChildId == null) return;

    final punishments = provider.punishments
        .where((p) => p.childId == _selectedChildId && !p.isCompleted)
        .toList();

    if (punishments.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Aucune punition active à couvrir 🎉'),
          backgroundColor: Colors.green));
      return;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Consumer<FamilyProvider>(
        builder: (ctx, prov, _) {
          final currentImm =
              prov.immunities.firstWhere((i) => i.id == imm.id, orElse: () => imm);
          final activePunishments = prov.punishments
              .where((p) => p.childId == _selectedChildId && !p.isCompleted)
              .toList();

          return Container(
            padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 20),
            decoration: BoxDecoration(
                color: Colors.grey.shade900,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(24))),
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
                            borderRadius: BorderRadius.circular(2)))),
                const SizedBox(height: 16),
                Row(children: [
                  const Icon(Icons.shield, color: Colors.greenAccent, size: 24),
                  const SizedBox(width: 10),
                  Text(
                      'Utiliser immunité sur punition',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold)),
                ]),
                const SizedBox(height: 4),
                Text('${currentImm.availableLines} ligne(s) disponible(s)',
                    style: const TextStyle(
                        color: Colors.greenAccent, fontSize: 13)),
                const SizedBox(height: 16),

                // Liste des punitions actives
                ...activePunishments.map((p) {
                  final remaining = p.totalLines - p.completedLines;
                  return _PunishmentImmunityRow(
                    punishment: p,
                    availableImmunity: currentImm.availableLines,
                    onUse: (lines) async {
                      await prov.useImmunityOnPunishment(
                          currentImm.id, p.id, lines);
                      if (ctx.mounted) Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text(
                              '🛡️ $lines ligne(s) couverte(s) sur "${p.text}"'),
                          backgroundColor: Colors.green.shade700));
                    },
                  );
                }).toList(),
                const SizedBox(height: 8),
              ],
            ),
          );
        },
      ),
    );
  }

  // ── Proposer un trade depuis une immunité ───────────────────
  void _proposeTrade(ImmunityLines imm) {
    if (_selectedChildId == null) return;
    Navigator.push(
        context,
        DoorPageRoute(
            page: TradeScreen(
                childId: _selectedChildId!,
                preselectedImmunityId: imm.id)));
  }

  // ── Sheet de détail d'une immunité ──────────────────────────
  void _showDetailSheet(ImmunityLines imm) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Consumer<FamilyProvider>(
        builder: (ctx, provider, _) {
          final current = provider.immunities
              .firstWhere((i) => i.id == imm.id, orElse: () => imm);

          return Container(
            decoration: BoxDecoration(
                color: Colors.grey.shade900,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(24))),
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
                              borderRadius: BorderRadius.circular(2)))),
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
                                fontWeight: FontWeight.bold))),
                  ]),
                  const SizedBox(height: 16),
                  _detailRow(
                      'Statut', _statusText(current), _statusColor(current)),
                  _detailRow('Lignes disponibles',
                      '${current.availableLines}/${current.lines}', Colors.white),
                  _detailRow(
                      'Créée le',
                      '${current.createdAt.day}/${current.createdAt.month}/${current.createdAt.year}',
                      Colors.white70),
                  if (current.expiresAt != null)
                    _detailRow('Expire le', current.expiresLabel,
                        Colors.orangeAccent),
                  const SizedBox(height: 20),

                  if (current.isUsable) ...[
                    // Bouton : utiliser sur punition (accessible aux enfants)
                    SizedBox(
                      width: double.infinity,
                      child: GestureDetector(
                        onTap: () {
                          Navigator.pop(ctx);
                          _showUseOnPunishmentDialog(current);
                        },
                        child: Container(
                          padding:
                              const EdgeInsets.symmetric(vertical: 14),
                          decoration: BoxDecoration(
                              gradient: LinearGradient(colors: [
                                Colors.greenAccent.shade700,
                                Colors.teal.shade700
                              ]),
                              borderRadius: BorderRadius.circular(14)),
                          child: const Center(
                              child: Text(
                                  '🛡️ Utiliser sur une punition',
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15))),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Bouton : proposer un trade
                    SizedBox(
                      width: double.infinity,
                      child: GestureDetector(
                        onTap: () {
                          Navigator.pop(ctx);
                          _proposeTrade(current);
                        },
                        child: Container(
                          padding:
                              const EdgeInsets.symmetric(vertical: 14),
                          decoration: BoxDecoration(
                              gradient: LinearGradient(colors: [
                                Colors.purple.shade700,
                                Colors.blue.shade700
                              ]),
                              borderRadius: BorderRadius.circular(14)),
                          child: const Center(
                              child: Text('🤝 Vendre / Échanger',
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15))),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],

                  // Supprimer (parent uniquement via PinGuard)
                  SizedBox(
                    width: double.infinity,
                    child: GestureDetector(
                      onTap: () {
                        PinGuard.guardAction(context, () {
                          context
                              .read<FamilyProvider>()
                              .removeImmunity(current.id);
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                              content: const Text('🗑️ Immunité supprimée'),
                              backgroundColor: Colors.red.shade700));
                        });
                      },
                      child: Container(
                        padding:
                            const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                            color: Colors.red.shade900.withOpacity(0.5),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                                color:
                                    Colors.redAccent.withOpacity(0.5))),
                        child: const Center(
                            child: Text('🗑️ Supprimer',
                                style: TextStyle(
                                    color: Colors.redAccent,
                                    fontWeight: FontWeight.bold))),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ]),
          );
        },
      ),
    );
  }

  Widget _detailRow(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label,
            style: const TextStyle(color: Colors.white54, fontSize: 14)),
        Text(value,
            style: TextStyle(
                color: color, fontSize: 14, fontWeight: FontWeight.bold)),
      ]),
    );
  }

  // ── BUILD ────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Consumer<FamilyProvider>(
      builder: (context, provider, _) {
        final children = provider.children;
        final immunities = _getImmunities(provider);
        final activeCount = immunities.where((e) => e.isUsable).length;
        final totalLines =
            immunities.fold<int>(0, (s, e) => s + e.availableLines);

        return Scaffold(
          backgroundColor: Colors.transparent,
          body: AnimatedBackground(
            child: SafeArea(
              child: Column(children: [
                // ── Header
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
                              color: Colors.white)),
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
                                fontWeight: FontWeight.bold))),
                    // Bouton ajouter (parent uniquement)
                    TvFocusWrapper(
                      onTap: () => PinGuard.guardAction(
                          context, _showAddImmunityDialog),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                            gradient: LinearGradient(colors: [
                              Colors.greenAccent.shade700,
                              Colors.green.shade700
                            ]),
                            borderRadius: BorderRadius.circular(14)),
                        child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.add, color: Colors.white, size: 20),
                              SizedBox(width: 4),
                              Text('Ajouter',
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold)),
                            ]),
                      ),
                    ),
                  ]),
                ),

                // ── Sélecteur d'enfant
                if (children.length > 1)
                  SizedBox(
                    height: 50,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding:
                          const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: children.length,
                      itemBuilder: (ctx, i) {
                        final child = children[i];
                        final selected = child.id == _selectedChildId;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: TvFocusWrapper(
                            onTap: () => setState(
                                () => _selectedChildId = child.id),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 300),
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
                                      : null),
                              child: Center(
                                child: Text(
                                    '${child.avatar.isNotEmpty ? child.avatar : '👤'} ${child.name}',
                                    style: TextStyle(
                                        color: selected
                                            ? Colors.greenAccent
                                            : Colors.white70,
                                        fontWeight: selected
                                            ? FontWeight.bold
                                            : FontWeight.normal)),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                const SizedBox(height: 8),

                // ── Stats
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16),
                  child: GlassCard(
                    child: Row(
                        mainAxisAlignment:
                            MainAxisAlignment.spaceEvenly,
                        children: [
                          _statChip('Actives', '$activeCount',
                              Colors.greenAccent),
                          Container(
                              width: 1,
                              height: 30,
                              color: Colors.white24),
                          _statChip('Lignes dispo', '$totalLines',
                              Colors.cyanAccent),
                          Container(
                              width: 1,
                              height: 30,
                              color: Colors.white24),
                          _statChip('Total', '${immunities.length}',
                              Colors.white70),
                        ]),
                  ),
                ),
                const SizedBox(height: 8),

                // ── Info pour les enfants
                if (_selectedChildId != null &&
                    provider.getChild(_selectedChildId!) != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 4),
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.greenAccent.withOpacity(0.07),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color:
                                Colors.greenAccent.withOpacity(0.2)),
                      ),
                      child: const Row(children: [
                        Icon(Icons.info_outline,
                            color: Colors.greenAccent, size: 16),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Appuie sur une immunité pour l\'utiliser sur une punition ou la vendre à un autre enfant.',
                            style: TextStyle(
                                color: Colors.white60,
                                fontSize: 11),
                          ),
                        ),
                      ]),
                    ),
                  ),
                const SizedBox(height: 4),

                // ── Liste
                Expanded(
                  child: immunities.isEmpty
                      ? Center(
                          child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ScaleTransition(
                                scale: _shieldPulse,
                                child: const Text('🛡️',
                                    style: TextStyle(fontSize: 64))),
                            const SizedBox(height: 16),
                            const Text('Aucune immunité',
                                style: TextStyle(
                                    color: Colors.white54,
                                    fontSize: 18)),
                            const SizedBox(height: 8),
                            const Text(
                                'Le parent peut en ajouter avec le bouton +',
                                style: TextStyle(
                                    color: Colors.white38,
                                    fontSize: 14)),
                          ],
                        ))
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16),
                          itemCount: immunities.length,
                          itemBuilder: (ctx, index) {
                            final imm = immunities[index];
                            final delay = index * 0.1;
                            return AnimatedBuilder(
                              animation: _listController,
                              builder: (ctx, child) {
                                final t = Curves.elasticOut.transform(
                                    ((_listController.value - delay) /
                                            (1 - delay))
                                        .clamp(0.0, 1.0));
                                return Transform.translate(
                                    offset: Offset(0, 50 * (1 - t)),
                                    child: Opacity(
                                        opacity: t, child: child));
                              },
                              child: Padding(
                                padding:
                                    const EdgeInsets.only(bottom: 8),
                                child: TvFocusWrapper(
                                  onTap: () =>
                                      _showDetailSheet(imm),
                                  child: GlassCard(
                                    glowColor: imm.isUsable
                                        ? Colors.greenAccent
                                        : Colors.grey,
                                    child: Row(children: [
                                      // Icône statut
                                      Container(
                                          width: 48,
                                          height: 48,
                                          decoration: BoxDecoration(
                                              color: _statusColor(imm)
                                                  .withOpacity(0.2),
                                              borderRadius:
                                                  BorderRadius.circular(
                                                      14)),
                                          child: Icon(
                                              _statusIcon(imm),
                                              color:
                                                  _statusColor(imm),
                                              size: 24)),
                                      const SizedBox(width: 12),

                                      // Infos
                                      Expanded(
                                          child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment
                                                      .start,
                                              children: [
                                            Text(imm.reason,
                                                style: const TextStyle(
                                                    color: Colors.white,
                                                    fontWeight:
                                                        FontWeight.bold,
                                                    fontSize: 16)),
                                            const SizedBox(height: 4),
                                            Row(children: [
                                              Text(_statusText(imm),
                                                  style: TextStyle(
                                                      color:
                                                          _statusColor(
                                                              imm),
                                                      fontSize: 12)),
                                              const SizedBox(width: 8),
                                              Text(
                                                  '${imm.availableLines}/${imm.lines} lignes',
                                                  style: const TextStyle(
                                                      color:
                                                          Colors.white54,
                                                      fontSize: 12)),
                                            ]),
                                          ])),

                                      // Actions rapides
                                      if (imm.isUsable)
                                        Column(
                                          mainAxisSize:
                                              MainAxisSize.min,
                                          children: [
                                            // Utiliser sur punition
                                            GestureDetector(
                                              onTap: () =>
                                                  _showUseOnPunishmentDialog(
                                                      imm),
                                              child: Container(
                                                padding: const EdgeInsets
                                                    .all(6),
                                                margin:
                                                    const EdgeInsets.only(
                                                        bottom: 4),
                                                decoration: BoxDecoration(
                                                  color: Colors.greenAccent
                                                      .withOpacity(0.15),
                                                  borderRadius:
                                                      BorderRadius
                                                          .circular(8),
                                                ),
                                                child: const Icon(
                                                    Icons.shield_rounded,
                                                    color:
                                                        Colors.greenAccent,
                                                    size: 18),
                                              ),
                                            ),
                                            // Vendre
                                            GestureDetector(
                                              onTap: () =>
                                                  _proposeTrade(imm),
                                              child: Container(
                                                padding: const EdgeInsets
                                                    .all(6),
                                                decoration: BoxDecoration(
                                                  color: Colors.purple
                                                      .withOpacity(0.15),
                                                  borderRadius:
                                                      BorderRadius
                                                          .circular(8),
                                                ),
                                                child: const Icon(
                                                    Icons
                                                        .storefront_rounded,
                                                    color: Colors.purple,
                                                    size: 18),
                                              ),
                                            ),
                                          ],
                                        ),
                                      const SizedBox(width: 6),
                                      const Icon(Icons.chevron_right,
                                          color: Colors.white38,
                                          size: 20),
                                    ]),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ]),
            ),
          ),
        );
      },
    );
  }

  Widget _statChip(String label, String value, Color color) =>
      Column(mainAxisSize: MainAxisSize.min, children: [
        Text(value,
            style: TextStyle(
                color: color,
                fontSize: 20,
                fontWeight: FontWeight.bold)),
        const SizedBox(height: 2),
        Text(label,
            style: const TextStyle(color: Colors.white54, fontSize: 12)),
      ]);
}

// ════════════════════════════════════════════════════════════════
// Widget interne : ligne punition avec sélecteur de lignes libre
// ════════════════════════════════════════════════════════════════
class _PunishmentImmunityRow extends StatefulWidget {
  final PunishmentLines punishment;
  final int availableImmunity;
  final Future<void> Function(int lines) onUse;

  const _PunishmentImmunityRow({
    required this.punishment,
    required this.availableImmunity,
    required this.onUse,
  });

  @override
  State<_PunishmentImmunityRow> createState() =>
      _PunishmentImmunityRowState();
}

class _PunishmentImmunityRowState
    extends State<_PunishmentImmunityRow> {
  late TextEditingController _ctrl;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    final remaining =
        widget.punishment.totalLines - widget.punishment.completedLines;
    final maxUsable =
        remaining.clamp(0, widget.availableImmunity);
    _ctrl = TextEditingController(text: '$maxUsable');
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.punishment;
    final remaining = p.totalLines - p.completedLines;
    final maxUsable = remaining.clamp(0, widget.availableImmunity);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(16),
        border:
            Border.all(color: Colors.greenAccent.withOpacity(0.2)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(p.text,
            style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14),
            maxLines: 2,
            overflow: TextOverflow.ellipsis),
        const SizedBox(height: 6),
        Row(children: [
          Text('$remaining lignes restantes',
              style:
                  const TextStyle(color: Colors.white54, fontSize: 12)),
          const Spacer(),
          // Barre de progression mini
          SizedBox(
            width: 80,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: p.completedLines / p.totalLines,
                minHeight: 5,
                backgroundColor: Colors.white.withOpacity(0.1),
                valueColor:
                    const AlwaysStoppedAnimation(Colors.redAccent),
              ),
            ),
          ),
        ]),
        const SizedBox(height: 10),

        // Sélecteur de lignes — champ libre
        Row(children: [
          Expanded(
            child: TextField(
              controller: _ctrl,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: Colors.greenAccent,
                  fontSize: 20,
                  fontWeight: FontWeight.bold),
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                filled: true,
                fillColor: Colors.white.withOpacity(0.07),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none),
                suffixText: '/ $maxUsable max',
                suffixStyle:
                    const TextStyle(color: Colors.white30, fontSize: 12),
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Raccourcis
          Column(
            children: [1, maxUsable ~/ 2, maxUsable]
                .toSet()
                .where((v) => v > 0 && v <= maxUsable)
                .map((v) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: GestureDetector(
                        onTap: () => setState(() => _ctrl.text = '$v'),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color:
                                Colors.greenAccent.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                                color:
                                    Colors.greenAccent.withOpacity(0.3)),
                          ),
                          child: Text(
                              v == maxUsable ? 'Tout' : '$v',
                              style: const TextStyle(
                                  color: Colors.greenAccent,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ))
                .toList(),
          ),
          const SizedBox(width: 8),
          // Bouton valider
          ElevatedButton(
            onPressed: _loading
                ? null
                : () async {
                    final lines =
                        (int.tryParse(_ctrl.text.trim()) ?? 0)
                            .clamp(1, maxUsable);
                    if (lines < 1) return;
                    setState(() => _loading = true);
                    await widget.onUse(lines);
                    if (mounted) setState(() => _loading = false);
                  },
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.greenAccent.shade700,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10))),
            child: _loading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.black))
                : const Text('Utiliser',
                    style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ]),
      ]),
    );
  }
}
