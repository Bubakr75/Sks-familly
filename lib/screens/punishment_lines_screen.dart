// lib/screens/punishment_lines_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/punishment_lines.dart';
import '../models/immunity_lines.dart';
import '../providers/family_provider.dart';
import '../providers/pin_provider.dart';
import '../widgets/animated_background.dart';
import '../widgets/glass_card.dart';
import '../widgets/tv_focus_wrapper.dart';

class PunishmentLinesScreen extends StatefulWidget {
  const PunishmentLinesScreen({super.key});

  @override
  State<PunishmentLinesScreen> createState() =>
      _PunishmentLinesScreenState();
}

class _PunishmentLinesScreenState extends State<PunishmentLinesScreen>
    with TickerProviderStateMixin {
  late AnimationController _listController;
  late AnimationController _progressController;
  String? _selectedChildId;

  @override
  void initState() {
    super.initState();
    _listController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..forward();
    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..forward();

    final provider = context.read<FamilyProvider>();
    if (provider.children.isNotEmpty) {
      _selectedChildId = provider.children.first.id;
    }
  }

  @override
  void dispose() {
    _listController.dispose();
    _progressController.dispose();
    super.dispose();
  }

  List<PunishmentLines> _getPunishments(FamilyProvider provider) {
    if (_selectedChildId == null) return [];
    return provider.punishments
        .where((e) => e.childId == _selectedChildId)
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  // ── Méthode pour marquer "J'ai fini" (enfant) ──────────────
  Future<void> _markPendingValidation(
      FamilyProvider provider, PunishmentLines p) async {
    p.pendingValidation = true;
    await provider.updatePunishmentProgress(p.id, 0); // force save
    // On sauvegarde directement via le provider
    final idx = provider.punishments.indexWhere((x) => x.id == p.id);
    if (idx != -1) {
      provider.punishments[idx].pendingValidation = true;
      provider.notifyListeners();
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('✅ Demande de validation envoyée au parent !'),
        backgroundColor: Colors.orange,
      ));
    }
  }

  // ── Dialog utiliser immunité sur une punition ───────────────
  void _showUseImmunityDialog(
      FamilyProvider provider, PunishmentLines p) {
    final immunities = provider
        .getUsableImmunitiesForChild(p.childId);

    if (immunities.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('❌ Aucune immunité disponible'),
        backgroundColor: Colors.red,
      ));
      return;
    }

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
                    borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 16),
            const Row(children: [
              Text('🛡️', style: TextStyle(fontSize: 24)),
              SizedBox(width: 8),
              Text('Utiliser une immunité',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold)),
            ]),
            const SizedBox(height: 8),
            Text(
              'Lignes restantes : ${p.totalLines - p.completedLines}',
              style:
                  const TextStyle(color: Colors.white54, fontSize: 13),
            ),
            const SizedBox(height: 16),
            ...immunities.map((imm) => _buildImmunityOption(
                ctx, provider, p, imm)),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Widget _buildImmunityOption(BuildContext ctx, FamilyProvider provider,
      PunishmentLines p, ImmunityLines imm) {
    final remaining = p.totalLines - p.completedLines;
    final canUse = imm.availableLines > 0 && remaining > 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: canUse
            ? Colors.greenAccent.withOpacity(0.07)
            : Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: canUse
              ? Colors.greenAccent.withOpacity(0.3)
              : Colors.white12,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.shield,
                color:
                    canUse ? Colors.greenAccent : Colors.white24,
                size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(imm.reason,
                  style: TextStyle(
                      color:
                          canUse ? Colors.white : Colors.white38,
                      fontWeight: FontWeight.w600,
                      fontSize: 14)),
            ),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                  color: Colors.greenAccent.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8)),
              child: Text('${imm.availableLines} lignes dispo',
                  style: const TextStyle(
                      color: Colors.greenAccent, fontSize: 11)),
            ),
          ]),
          if (canUse) ...[
            const SizedBox(height: 10),
            // Sélecteur du nombre de lignes à utiliser
            _ImmunityLinePicker(
              max: imm.availableLines < remaining
                  ? imm.availableLines
                  : remaining,
              onConfirm: (lines) async {
                Navigator.pop(ctx);
                await provider.useImmunityOnPunishment(
                    imm.id, p.id, lines);
                if (mounted) {
                  final updated = provider.punishments
                      .firstWhere((x) => x.id == p.id,
                          orElse: () => p);
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text(
                        '🛡️ $lines ligne${lines > 1 ? 's' : ''} annulée${lines > 1 ? 's' : ''} par immunité !'),
                    backgroundColor: Colors.green.shade700,
                  ));
                  if (updated.isCompleted) {
                    ScaffoldMessenger.of(context)
                        .showSnackBar(const SnackBar(
                      content: Text('🎉 Punition terminée grâce à l\'immunité !'),
                      backgroundColor: Colors.green,
                    ));
                  }
                  _listController.forward(from: 0);
                }
              },
            ),
          ],
        ],
      ),
    );
  }

  void _showAddPunishmentSheet() {
    final textCtrl = TextEditingController();
    final linesCtrl = TextEditingController(text: '10');

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Container(
          decoration: BoxDecoration(
            color: Colors.grey.shade900,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 24,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              const Text('📝 Nouvelle Punition',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              TextField(
                controller: textCtrl,
                style: const TextStyle(color: Colors.white),
                maxLines: 2,
                decoration: InputDecoration(
                  labelText: 'Texte à copier',
                  labelStyle:
                      const TextStyle(color: Colors.white70),
                  hintText:
                      'Ex: Je dois être poli avec mes frères et sœurs.',
                  hintStyle:
                      const TextStyle(color: Colors.white30),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(
                        color: Colors.redAccent.withOpacity(0.5)),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide:
                        const BorderSide(color: Colors.redAccent),
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text('Nombre de lignes',
                  style:
                      TextStyle(color: Colors.white70, fontSize: 14)),
              const SizedBox(height: 8),
              SizedBox(
                width: 140,
                child: TextField(
                  controller: linesCtrl,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold),
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly
                  ],
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: Colors.redAccent.withOpacity(0.2),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [5, 10, 20, 50, 100].map((n) {
                  return TvFocusWrapper(
                    onTap: () =>
                        setSheetState(() => linesCtrl.text = '$n'),
                    child: GestureDetector(
                      onTap: () =>
                          setSheetState(() => linesCtrl.text = '$n'),
                      child: Chip(
                        label: Text('$n',
                            style: const TextStyle(
                                color: Colors.white70)),
                        backgroundColor:
                            Colors.white.withOpacity(0.1),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent.shade700,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: () {
                    final totalLines =
                        int.tryParse(linesCtrl.text) ?? 0;
                    if (textCtrl.text.trim().isEmpty ||
                        _selectedChildId == null ||
                        totalLines <= 0) return;
                    context.read<FamilyProvider>().addPunishment(
                          _selectedChildId!,
                          textCtrl.text.trim(),
                          totalLines,
                        );
                    Navigator.pop(ctx);
                    _listController.forward(from: 0);
                    ScaffoldMessenger.of(context)
                        .showSnackBar(SnackBar(
                      content: Text(
                          '📝 Punition de $totalLines lignes ajoutée'),
                      backgroundColor: Colors.red.shade700,
                    ));
                  },
                  child: const Text('Créer la punition',
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showPunishmentDetail(PunishmentLines punishment) {
    final isParent =
        context.read<PinProvider>().isParentMode;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Consumer<FamilyProvider>(
        builder: (ctx, provider, _) {
          final currentP = provider.punishments.firstWhere(
            (p) => p.id == punishment.id,
            orElse: () => punishment,
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
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(2)),
                  ),
                ),
                const SizedBox(height: 20),
                Row(children: [
                  Text(currentP.isCompleted ? '✅' : '📝',
                      style: const TextStyle(fontSize: 28)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(currentP.text,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold)),
                  ),
                ]),

                // Badge "En attente de validation"
                if (currentP.pendingValidation &&
                    !currentP.isCompleted) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: Colors.orange.withOpacity(0.4)),
                    ),
                    child: const Row(children: [
                      Icon(Icons.hourglass_top_rounded,
                          color: Colors.orange, size: 16),
                      SizedBox(width: 6),
                      Text(
                          '⏳ En attente de validation parent',
                          style: TextStyle(
                              color: Colors.orange,
                              fontSize: 12,
                              fontWeight: FontWeight.w600)),
                    ]),
                  ),
                ],

                const SizedBox(height: 16),
                AnimatedBuilder(
                  animation: _progressController,
                  builder: (ctx, _) {
                    final progress =
                        currentP.progress * _progressController.value;
                    return Column(children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: LinearProgressIndicator(
                          value: progress,
                          minHeight: 12,
                          backgroundColor:
                              Colors.white.withOpacity(0.1),
                          valueColor: AlwaysStoppedAnimation(
                            currentP.isCompleted
                                ? Colors.greenAccent
                                : currentP.pendingValidation
                                    ? Colors.orange
                                    : Colors.redAccent,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                          mainAxisAlignment:
                              MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                                '${currentP.completedLines}/${currentP.totalLines} lignes',
                                style: const TextStyle(
                                    color: Colors.white70)),
                            Text(
                                '${(currentP.progress * 100).toInt()}%',
                                style: TextStyle(
                                    color: currentP.isCompleted
                                        ? Colors.greenAccent
                                        : Colors.redAccent,
                                    fontWeight: FontWeight.bold)),
                          ]),
                    ]);
                  },
                ),
                const SizedBox(height: 20),

                if (!currentP.isCompleted) ...[
                  // ── Bouton immunité ──────────────────────
                  SizedBox(
                    width: double.infinity,
                    child: TvFocusWrapper(
                      onTap: () {
                        Navigator.pop(ctx);
                        _showUseImmunityDialog(provider, currentP);
                      },
                      child: Container(
                        padding:
                            const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(colors: [
                            Colors.greenAccent.shade700
                                .withOpacity(0.8),
                            Colors.teal.shade700.withOpacity(0.8),
                          ]),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Center(
                          child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text('🛡️',
                                    style: TextStyle(fontSize: 18)),
                                SizedBox(width: 8),
                                Text('Utiliser une immunité',
                                    style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15)),
                              ]),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // ── Ajouter des lignes (parent) ──────────
                  if (isParent) ...[
                    const Text('Ajouter des lignes complétées',
                        style: TextStyle(
                            color: Colors.white70, fontSize: 14)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: [1, 5, 10].map((n) {
                        return TvFocusWrapper(
                          onTap: () {
                            HapticFeedback.lightImpact();
                            final prov =
                                context.read<FamilyProvider>();
                            prov.updatePunishmentProgress(
                                currentP.id, n);
                            _progressController.forward(from: 0);
                            final updated =
                                prov.punishments.firstWhere(
                              (p) => p.id == currentP.id,
                              orElse: () => currentP,
                            );
                            if (updated.isCompleted) {
                              Navigator.pop(ctx);
                              ScaffoldMessenger.of(context)
                                  .showSnackBar(const SnackBar(
                                content:
                                    Text('🎉 Punition terminée !'),
                                backgroundColor: Colors.green,
                              ));
                            }
                          },
                          child: Chip(
                            label: Text('+$n',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold)),
                            backgroundColor:
                                Colors.redAccent.withOpacity(0.3),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 12),

                    // ── Valider "j'ai fini" (parent) ─────────
                    if (currentP.pendingValidation) ...[
                      SizedBox(
                        width: double.infinity,
                        child: TvFocusWrapper(
                          onTap: () {
                            final prov =
                                context.read<FamilyProvider>();
                            final remaining = currentP.totalLines -
                                currentP.completedLines;
                            prov.updatePunishmentProgress(
                                currentP.id, remaining);
                            Navigator.pop(ctx);
                            ScaffoldMessenger.of(context)
                                .showSnackBar(const SnackBar(
                              content: Text(
                                  '✅ Punition validée par le parent !'),
                              backgroundColor: Colors.green,
                            ));
                            _listController.forward(from: 0);
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                vertical: 14),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(colors: [
                                Colors.green.shade700,
                                Colors.greenAccent.shade700,
                              ]),
                              borderRadius:
                                  BorderRadius.circular(14),
                            ),
                            child: const Center(
                              child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.check_circle,
                                        color: Colors.white,
                                        size: 20),
                                    SizedBox(width: 8),
                                    Text(
                                        '✅ Valider (l\'enfant a fini)',
                                        style: TextStyle(
                                            color: Colors.white,
                                            fontWeight:
                                                FontWeight.bold,
                                            fontSize: 15)),
                                  ]),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                  ],

                  // ── Bouton "J'ai fini !" (enfant) ────────
                  if (!isParent &&
                      !currentP.pendingValidation) ...[
                    SizedBox(
                      width: double.infinity,
                      child: TvFocusWrapper(
                        onTap: () {
                          Navigator.pop(ctx);
                          _markPendingValidation(
                              context.read<FamilyProvider>(),
                              currentP);
                        },
                        child: Container(
                          padding:
                              const EdgeInsets.symmetric(vertical: 14),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(colors: [
                              Colors.orange.shade700,
                              Colors.amber.shade700,
                            ]),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Center(
                            child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text('🙋',
                                      style:
                                          TextStyle(fontSize: 18)),
                                  SizedBox(width: 8),
                                  Text('J\'ai fini mes lignes !',
                                      style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15)),
                                ]),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                ],

                // ── Supprimer (parent seulement) ──────────
                if (isParent) ...[
                  SizedBox(
                    width: double.infinity,
                    child: TvFocusWrapper(
                      onTap: () {
                        context
                            .read<FamilyProvider>()
                            .removePunishment(currentP.id);
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context)
                            .showSnackBar(const SnackBar(
                          content: Text('🗑️ Punition supprimée'),
                          backgroundColor: Colors.red,
                        ));
                      },
                      child: Container(
                        padding:
                            const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          color:
                              Colors.red.shade900.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                              color:
                                  Colors.redAccent.withOpacity(0.5)),
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
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<FamilyProvider>(
      builder: (context, provider, _) {
        final children = provider.children;
        final punishments = _getPunishments(provider);
        final activeCount =
            punishments.where((e) => !e.isCompleted).length;
        final completedCount =
            punishments.where((e) => e.isCompleted).length;
        final pendingCount = punishments
            .where((e) =>
                e.pendingValidation && !e.isCompleted)
            .length;

        return Scaffold(
          backgroundColor: Colors.transparent,
          body: AnimatedBackground(
            child: SafeArea(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(children: [
                      TvFocusWrapper(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.arrow_back,
                              color: Colors.white),
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Text('📝',
                          style: TextStyle(fontSize: 28)),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text('Punitions',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.bold)),
                      ),
                      // Badge validation en attente
                      if (pendingCount > 0)
                        Container(
                          margin: const EdgeInsets.only(right: 8),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.orange.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: Colors.orange.withOpacity(0.5)),
                          ),
                          child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.hourglass_top,
                                    color: Colors.orange, size: 14),
                                const SizedBox(width: 4),
                                Text('$pendingCount',
                                    style: const TextStyle(
                                        color: Colors.orange,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13)),
                              ]),
                        ),
                      TvFocusWrapper(
                        onTap: _showAddPunishmentSheet,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 10),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(colors: [
                              Colors.redAccent.shade700,
                              Colors.red.shade700,
                            ]),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.add,
                                    color: Colors.white, size: 20),
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

                  if (children.length > 1)
                    SizedBox(
                      height: 50,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16),
                        itemCount: children.length,
                        itemBuilder: (ctx, i) {
                          final child = children[i];
                          final selected =
                              child.id == _selectedChildId;
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: TvFocusWrapper(
                              onTap: () {
                                setState(() =>
                                    _selectedChildId = child.id);
                                _listController.forward(from: 0);
                              },
                              child: AnimatedContainer(
                                duration:
                                    const Duration(milliseconds: 300),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 8),
                                decoration: BoxDecoration(
                                  color: selected
                                      ? Colors.redAccent
                                          .withOpacity(0.3)
                                      : Colors.white.withOpacity(0.1),
                                  borderRadius:
                                      BorderRadius.circular(20),
                                  border: selected
                                      ? Border.all(
                                          color: Colors.redAccent,
                                          width: 2)
                                      : null,
                                ),
                                child: Center(
                                  child: Text(
                                    '${child.avatar.isNotEmpty ? child.avatar : '👤'} ${child.name}',
                                    style: TextStyle(
                                      color: selected
                                          ? Colors.redAccent
                                          : Colors.white70,
                                      fontWeight: selected
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),

                  const SizedBox(height: 8),

                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16),
                    child: GlassCard(
                      child: Row(
                        mainAxisAlignment:
                            MainAxisAlignment.spaceEvenly,
                        children: [
                          _statChip('En cours', '$activeCount',
                              Colors.redAccent),
                          Container(
                              width: 1,
                              height: 30,
                              color: Colors.white24),
                          _statChip('En attente', '$pendingCount',
                              Colors.orange),
                          Container(
                              width: 1,
                              height: 30,
                              color: Colors.white24),
                          _statChip('Terminées', '$completedCount',
                              Colors.greenAccent),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 8),

                  Expanded(
                    child: punishments.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text('📝',
                                    style:
                                        TextStyle(fontSize: 64)),
                                const SizedBox(height: 16),
                                const Text('Aucune punition',
                                    style: TextStyle(
                                        color: Colors.white54,
                                        fontSize: 18)),
                                const SizedBox(height: 8),
                                const Text(
                                    'Espérons que ça dure !',
                                    style: TextStyle(
                                        color: Colors.white38,
                                        fontSize: 14)),
                              ],
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16),
                            itemCount: punishments.length,
                            itemBuilder: (ctx, index) {
                              final p = punishments[index];
                              final delay = index * 0.1;
                              return AnimatedBuilder(
                                animation: _listController,
                                builder: (ctx, child) {
                                  final raw =
                                      (_listController.value -
                                              delay) /
                                          (1 - delay);
                                  final t = Curves.elasticOut
                                      .transform(
                                          raw.clamp(0.0, 1.0));
                                  return Transform.translate(
                                    offset:
                                        Offset(0, 50 * (1 - t)),
                                    child: Opacity(
                                        opacity: t, child: child),
                                  );
                                },
                                child: Padding(
                                  padding: const EdgeInsets.only(
                                      bottom: 8),
                                  child: TvFocusWrapper(
                                    onTap: () {
                                      _progressController
                                          .forward(from: 0);
                                      _showPunishmentDetail(p);
                                    },
                                    child: GlassCard(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(children: [
                                            Text(
                                                p.isCompleted
                                                    ? '✅'
                                                    : p.pendingValidation
                                                        ? '⏳'
                                                        : '📝',
                                                style: const TextStyle(
                                                    fontSize: 24)),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment
                                                        .start,
                                                children: [
                                                  Text(
                                                    p.text,
                                                    style: TextStyle(
                                                      color:
                                                          Colors.white,
                                                      fontWeight:
                                                          FontWeight
                                                              .bold,
                                                      fontSize: 15,
                                                      decoration: p
                                                              .isCompleted
                                                          ? TextDecoration
                                                              .lineThrough
                                                          : null,
                                                    ),
                                                    maxLines: 2,
                                                    overflow:
                                                        TextOverflow
                                                            .ellipsis,
                                                  ),
                                                  const SizedBox(
                                                      height: 4),
                                                  Text(
                                                    p.pendingValidation &&
                                                            !p.isCompleted
                                                        ? '⏳ En attente de validation'
                                                        : '${p.completedLines}/${p.totalLines} lignes • ${(p.progress * 100).toInt()}%',
                                                    style: TextStyle(
                                                      color: p
                                                              .pendingValidation
                                                          ? Colors
                                                              .orange
                                                          : p.isCompleted
                                                              ? Colors
                                                                  .greenAccent
                                                              : Colors
                                                                  .white54,
                                                      fontSize: 12,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            const Icon(
                                                Icons.chevron_right,
                                                color: Colors.white38,
                                                size: 20),
                                          ]),
                                          const SizedBox(height: 8),
                                          ClipRRect(
                                            borderRadius:
                                                BorderRadius.circular(
                                                    4),
                                            child:
                                                LinearProgressIndicator(
                                              value: p.progress,
                                              minHeight: 6,
                                              backgroundColor: Colors
                                                  .white
                                                  .withOpacity(0.1),
                                              valueColor:
                                                  AlwaysStoppedAnimation(
                                                p.isCompleted
                                                    ? Colors.greenAccent
                                                    : p.pendingValidation
                                                        ? Colors.orange
                                                        : Colors
                                                            .redAccent,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
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

  Widget _statChip(String label, String value, Color color) {
    return Column(mainAxisSize: MainAxisSize.min, children: [
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
  }
}

// ── Widget sélecteur de lignes pour immunité ────────────────
class _ImmunityLinePicker extends StatefulWidget {
  final int max;
  final void Function(int lines) onConfirm;
  const _ImmunityLinePicker(
      {required this.max, required this.onConfirm});

  @override
  State<_ImmunityLinePicker> createState() =>
      _ImmunityLinePickerState();
}

class _ImmunityLinePickerState extends State<_ImmunityLinePicker> {
  late int _selected;

  @override
  void initState() {
    super.initState();
    _selected = widget.max;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          const Text('Lignes à annuler : ',
              style: TextStyle(color: Colors.white70, fontSize: 13)),
          Text('$_selected',
              style: const TextStyle(
                  color: Colors.greenAccent,
                  fontWeight: FontWeight.bold,
                  fontSize: 16)),
          Text(' / ${widget.max} max',
              style: const TextStyle(
                  color: Colors.white38, fontSize: 12)),
        ]),
        Slider(
          value: _selected.toDouble(),
          min: 1,
          max: widget.max.toDouble(),
          divisions: widget.max > 1 ? widget.max - 1 : 1,
          activeColor: Colors.greenAccent,
          inactiveColor: Colors.white12,
          onChanged: (v) => setState(() => _selected = v.round()),
        ),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () => widget.onConfirm(_selected),
            icon: const Icon(Icons.shield, size: 16),
            label: Text('Utiliser $_selected ligne${_selected > 1 ? 's' : ''} d\'immunité'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.greenAccent.shade700,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
      ],
    );
  }
}
