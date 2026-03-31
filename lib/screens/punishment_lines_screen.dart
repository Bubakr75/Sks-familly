// lib/screens/punishment_lines_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/family_provider.dart';
import '../widgets/animated_background.dart';
import '../widgets/glass_card.dart';
import '../widgets/tv_focus_wrapper.dart';

class PunishmentLinesScreen extends StatefulWidget {
  const PunishmentLinesScreen({super.key});
  @override
  State<PunishmentLinesScreen> createState() => _PunishmentLinesScreenState();
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
        vsync: this, duration: const Duration(milliseconds: 1200))
      ..forward();
    _progressController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 800));

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

  List<dynamic> _getPunishments(FamilyProvider provider) {
    if (_selectedChildId == null) return [];
    final list = provider.punishments
        .where((p) => p.childId == _selectedChildId)
        .toList();
    list.sort((a, b) {
      if (a.isCompleted && !b.isCompleted) return 1;
      if (!a.isCompleted && b.isCompleted) return -1;
      return b.createdAt.compareTo(a.createdAt);
    });
    return list;
  }

  void _showAddPunishmentSheet(FamilyProvider provider) {
    final textCtrl = TextEditingController();
    final linesCtrl = TextEditingController(text: '10');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setSheetState) {
          return Container(
            decoration: BoxDecoration(
              color: Colors.grey.shade900.withOpacity(0.95),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 20,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
            ),
            child: SingleChildScrollView(
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
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Center(
                    child: Text('📝 Nouvelle Punition',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(height: 20),
                  const Text('Texte à recopier',
                      style:
                          TextStyle(color: Colors.white70, fontSize: 14)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: textCtrl,
                    style: const TextStyle(color: Colors.white),
                    maxLines: 2,
                    decoration: InputDecoration(
                      hintText:
                          'Ex: Je ne dois pas taper mon frère...',
                      hintStyle:
                          const TextStyle(color: Colors.white30),
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.08),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide:
                            const BorderSide(color: Colors.redAccent),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text('Nombre de lignes',
                      style:
                          TextStyle(color: Colors.white70, fontSize: 14)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: linesCtrl,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold),
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                    ],
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.08),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide:
                            const BorderSide(color: Colors.redAccent),
                      ),
                      suffixText: 'lignes',
                      suffixStyle: const TextStyle(
                          color: Colors.white38, fontSize: 14),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [5, 10, 20, 50, 100].map((v) {
                      return GestureDetector(
                        onTap: () => setSheetState(
                            () => linesCtrl.text = v.toString()),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.redAccent.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                                color:
                                    Colors.redAccent.withOpacity(0.4)),
                          ),
                          child: Text('$v',
                              style: const TextStyle(
                                  color: Colors.redAccent,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14)),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        final text = textCtrl.text.trim();
                        final totalLines =
                            int.tryParse(linesCtrl.text.trim()) ?? 0;
                        if (text.isEmpty ||
                            _selectedChildId == null ||
                            totalLines < 1) return;
                        provider.addPunishment(
                            _selectedChildId!, text, totalLines);
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context)
                            .showSnackBar(SnackBar(
                          content: Text(
                              '📝 Punition ajoutée : $totalLines lignes'),
                          backgroundColor: Colors.red.shade700,
                        ));
                      },
                      icon: const Icon(Icons.add),
                      label: const Text('Ajouter la punition',
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.redAccent.shade700,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        });
      },
    );
  }

  void _showPunishmentDetail(dynamic punishment, FamilyProvider provider) {
    final linesAddCtrl = TextEditingController(text: '1');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setSheetState) {
          // Re-read from provider for reactivity
          final current = provider.punishments.firstWhere(
            (p) => p.id == punishment.id,
            orElse: () => punishment,
          );
          final remaining = current.totalLines - current.completedLines;

          return Container(
            decoration: BoxDecoration(
              color: Colors.grey.shade900.withOpacity(0.95),
              borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(24)),
            ),
            padding: const EdgeInsets.all(24),
            child: SingleChildScrollView(
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
                              borderRadius:
                                  BorderRadius.circular(2)))),
                  const SizedBox(height: 20),
                  Text(current.text,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  // Progress bar
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: TweenAnimationBuilder<double>(
                      tween: Tween<double>(
                          begin: 0, end: current.progress),
                      duration:
                          const Duration(milliseconds: 800),
                      curve: Curves.easeOutCubic,
                      builder: (context, val, _) =>
                          LinearProgressIndicator(
                        value: val,
                        minHeight: 12,
                        backgroundColor:
                            Colors.white.withOpacity(0.1),
                        valueColor: AlwaysStoppedAnimation(
                            current.isCompleted
                                ? Colors.greenAccent
                                : Colors.redAccent),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                      mainAxisAlignment:
                          MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                            '${current.completedLines}/${current.totalLines} lignes',
                            style: const TextStyle(
                                color: Colors.white54,
                                fontSize: 13)),
                        Text(
                            current.isCompleted
                                ? '✅ Terminé'
                                : '$remaining restante${remaining > 1 ? 's' : ''}',
                            style: TextStyle(
                                color: current.isCompleted
                                    ? Colors.greenAccent
                                    : Colors.orangeAccent,
                                fontSize: 13,
                                fontWeight: FontWeight.w600)),
                      ]),
                  if (!current.isCompleted) ...[
                    const SizedBox(height: 20),
                    const Text('Ajouter des lignes complétées',
                        style: TextStyle(
                            color: Colors.white70, fontSize: 14)),
                    const SizedBox(height: 8),
                    Row(children: [
                      Expanded(
                        child: TextField(
                          controller: linesAddCtrl,
                          keyboardType: TextInputType.number,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.bold),
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          decoration: InputDecoration(
                            filled: true,
                            fillColor:
                                Colors.white.withOpacity(0.08),
                            border: OutlineInputBorder(
                              borderRadius:
                                  BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                            suffixText: '/ $remaining',
                            suffixStyle: const TextStyle(
                                color: Colors.white38,
                                fontSize: 14),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton(
                        onPressed: () {
                          final toAdd = (int.tryParse(
                                      linesAddCtrl.text.trim()) ??
                                  0)
                              .clamp(0, remaining);
                          if (toAdd < 1) return;
                          provider.updatePunishmentProgress(
                              current.id, toAdd);
                          linesAddCtrl.text = '1';
                          setSheetState(() {});
                          _progressController.forward(from: 0);
                        },
                        style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.greenAccent
                                .shade700,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 20, vertical: 14),
                            shape: RoundedRectangleBorder(
                                borderRadius:
                                    BorderRadius.circular(12))),
                        child: const Text('Valider'),
                      ),
                    ]),
                    const SizedBox(height: 8),
                    // Raccourcis
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [1, 5, 10, 20, remaining]
                          .toSet()
                          .where((v) => v > 0 && v <= remaining)
                          .map((v) {
                        return GestureDetector(
                          onTap: () => setSheetState(
                              () => linesAddCtrl.text = '$v'),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.greenAccent
                                  .withOpacity(0.15),
                              borderRadius:
                                  BorderRadius.circular(8),
                              border: Border.all(
                                  color: Colors.greenAccent
                                      .withOpacity(0.4)),
                            ),
                            child: Text(
                                v == remaining ? 'Tout ($v)' : '$v',
                                style: const TextStyle(
                                    color: Colors.greenAccent,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13)),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                  const SizedBox(height: 20),
                  // Delete
                  SizedBox(
                    width: double.infinity,
                    child: TextButton.icon(
                      onPressed: () {
                        provider.removePunishment(current.id);
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                                content: const Text(
                                    '🗑️ Punition supprimée'),
                                backgroundColor:
                                    Colors.red.shade700));
                      },
                      icon: const Icon(Icons.delete_outline,
                          color: Colors.redAccent, size: 18),
                      label: const Text('Supprimer',
                          style:
                              TextStyle(color: Colors.redAccent)),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          );
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<FamilyProvider>(
      builder: (context, provider, _) {
        final children = provider.children;
        final punishments = _getPunishments(provider);
        final activeCount =
            punishments.where((p) => !p.isCompleted).length;
        final completedCount =
            punishments.where((p) => p.isCompleted).length;

        return Scaffold(
          backgroundColor: Colors.transparent,
          body: AnimatedBackground(
            child: SafeArea(
              child: Column(children: [
                // Header
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(children: [
                    TvFocusWrapper(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.1),
                              borderRadius:
                                  BorderRadius.circular(12)),
                          child: const Icon(Icons.arrow_back,
                              color: Colors.white)),
                    ),
                    const SizedBox(width: 12),
                    const Text('📝',
                        style: TextStyle(fontSize: 32)),
                    const SizedBox(width: 8),
                    const Expanded(
                        child: Text('Punitions',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.bold))),
                    TvFocusWrapper(
                      onTap: () =>
                          _showAddPunishmentSheet(provider),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                            gradient: LinearGradient(colors: [
                              Colors.redAccent.shade700,
                              Colors.red.shade700
                            ]),
                            borderRadius:
                                BorderRadius.circular(14)),
                        child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.add,
                                  color: Colors.white, size: 20),
                              SizedBox(width: 4),
                              Text('Ajouter',
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontWeight:
                                          FontWeight.bold)),
                            ]),
                      ),
                    ),
                  ]),
                ),

                // Child selector
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
                          padding:
                              const EdgeInsets.only(right: 8),
                          child: TvFocusWrapper(
                            onTap: () => setState(() =>
                                _selectedChildId = child.id),
                            child: AnimatedContainer(
                              duration: const Duration(
                                  milliseconds: 300),
                              padding:
                                  const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 8),
                              decoration: BoxDecoration(
                                  color: selected
                                      ? Colors.redAccent
                                          .withOpacity(0.3)
                                      : Colors.white
                                          .withOpacity(0.1),
                                  borderRadius:
                                      BorderRadius.circular(20),
                                  border: selected
                                      ? Border.all(
                                          color:
                                              Colors.redAccent,
                                          width: 2)
                                      : null),
                              child: Center(
                                child: Text(
                                    '${child.avatar.isNotEmpty ? child.avatar : '👤'} ${child.name}',
                                    style: TextStyle(
                                        color: selected
                                            ? Colors.redAccent
                                            : Colors.white70,
                                        fontWeight: selected
                                            ? FontWeight.bold
                                            : FontWeight
                                                .normal)),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                const SizedBox(height: 8),

                // Stats chips
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(children: [
                    _statChip('Actives', '$activeCount',
                        Colors.redAccent),
                    const SizedBox(width: 8),
                    _statChip('Terminées', '$completedCount',
                        Colors.greenAccent),
                    const SizedBox(width: 8),
                    _statChip('Total', '${punishments.length}',
                        Colors.white70),
                  ]),
                ),

                const SizedBox(height: 8),

                // List
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
                              const Text(
                                  'Aucune punition',
                                  style: TextStyle(
                                      color: Colors.white54,
                                      fontSize: 18)),
                              const SizedBox(height: 8),
                              const Text(
                                  'Appuyez sur + pour en ajouter',
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
                                final t = Curves.elasticOut
                                    .transform(
                                        ((_listController
                                                        .value -
                                                    delay) /
                                                (1 - delay))
                                            .clamp(0.0, 1.0));
                                return Transform.translate(
                                    offset:
                                        Offset(0, 50 * (1 - t)),
                                    child: Opacity(
                                        opacity: t,
                                        child: child));
                              },
                              child: Padding(
                                padding:
                                    const EdgeInsets.only(
                                        bottom: 8),
                                child: TvFocusWrapper(
                                  onTap: () =>
                                      _showPunishmentDetail(
                                          p, provider),
                                  child: GlassCard(
                                    child: Row(children: [
                                      Container(
                                          width: 48,
                                          height: 48,
                                          decoration:
                                              BoxDecoration(
                                                  color: (p.isCompleted
                                                          ? Colors
                                                              .greenAccent
                                                          : Colors
                                                              .redAccent)
                                                      .withOpacity(
                                                          0.2),
                                                  borderRadius:
                                                      BorderRadius
                                                          .circular(
                                                              14)),
                                          child: Icon(
                                              p.isCompleted
                                                  ? Icons
                                                      .check_circle
                                                  : Icons
                                                      .edit_document,
                                              color: p.isCompleted
                                                  ? Colors
                                                      .greenAccent
                                                  : Colors
                                                      .redAccent,
                                              size: 24)),
                                      const SizedBox(width: 12),
                                      Expanded(
                                          child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment
                                                      .start,
                                              children: [
                                            Text(p.text,
                                                style: const TextStyle(
                                                    color: Colors
                                                        .white,
                                                    fontWeight:
                                                        FontWeight
                                                            .bold,
                                                    fontSize:
                                                        14),
                                                maxLines: 1,
                                                overflow:
                                                    TextOverflow
                                                        .ellipsis),
                                            const SizedBox(
                                                height: 4),
                                            Row(children: [
                                              Text(
                                                  '${p.completedLines}/${p.totalLines}',
                                                  style: const TextStyle(
                                                      color: Colors
                                                          .white54,
                                                      fontSize:
                                                          12)),
                                              const SizedBox(
                                                  width: 8),
                                              Expanded(
                                                child:
                                                    ClipRRect(
                                                  borderRadius:
                                                      BorderRadius
                                                          .circular(
                                                              4),
                                                  child:
                                                      LinearProgressIndicator(
                                                    value: p
                                                        .progress,
                                                    minHeight:
                                                        4,
                                                    backgroundColor: Colors
                                                        .white
                                                        .withOpacity(
                                                            0.1),
                                                    valueColor: AlwaysStoppedAnimation(p
                                                            .isCompleted
                                                        ? Colors
                                                            .greenAccent
                                                        : Colors
                                                            .redAccent),
                                                  ),
                                                ),
                                              ),
                                            ]),
                                          ])),
                                      const SizedBox(width: 8),
                                      const Icon(
                                          Icons.chevron_right,
                                          color:
                                              Colors.white38,
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
      Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withOpacity(0.3)),
          ),
          child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(value,
                    style: TextStyle(
                        color: color,
                        fontSize: 18,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 2),
                Text(label,
                    style: const TextStyle(
                        color: Colors.white54, fontSize: 11)),
              ]),
        ),
      );
}
