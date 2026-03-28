import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/punishment_lines.dart';
import '../providers/family_provider.dart';
import '../widgets/animated_background.dart';
import '../widgets/glass_card.dart';
import '../widgets/tv_focus_wrapper.dart';
import '../widgets/animated_page_transition.dart';

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

  void _showAddPunishmentSheet() {
    final textCtrl = TextEditingController();
    int totalLines = 10;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Container(
          decoration: BoxDecoration(
            color: Colors.grey.shade900,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
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
              const Text(
                '📝 Nouvelle Punition',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: textCtrl,
                style: const TextStyle(color: Colors.white),
                maxLines: 2,
                decoration: InputDecoration(
                  labelText: 'Texte à copier',
                  labelStyle: const TextStyle(color: Colors.white70),
                  hintText: 'Ex: Je dois être poli avec mes frères et sœurs.',
                  hintStyle: const TextStyle(color: Colors.white30),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(
                      color: Colors.redAccent.withValues(alpha: 0.5),
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: const BorderSide(color: Colors.redAccent),
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Nombre de lignes',
                style: TextStyle(color: Colors.white70, fontSize: 14),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    onPressed: () {
                      if (totalLines > 1) setSheetState(() => totalLines--);
                    },
                    icon: const Icon(Icons.remove_circle,
                        color: Colors.redAccent, size: 32),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.redAccent.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(
                      '$totalLines',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: () => setSheetState(() => totalLines++),
                    icon: const Icon(Icons.add_circle,
                        color: Colors.greenAccent, size: 32),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [5, 10, 20, 50].map((n) {
                  return TvFocusWrapper(
                    onTap: () => setSheetState(() => totalLines = n),
                    child: Chip(
                      label: Text(
                        '$n',
                        style: TextStyle(
                          color: totalLines == n ? Colors.white : Colors.white70,
                          fontWeight: totalLines == n
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                      backgroundColor: totalLines == n
                          ? Colors.redAccent.withValues(alpha: 0.4)
                          : Colors.white.withValues(alpha: 0.1),
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
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: () {
                    if (textCtrl.text.trim().isEmpty ||
                        _selectedChildId == null) return;
                    final provider = context.read<FamilyProvider>();
                    provider.addPunishment(
                      _selectedChildId!,
                      textCtrl.text.trim(),
                      totalLines,
                    );
                    Navigator.pop(ctx);
                    _listController.forward(from: 0);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content:
                            Text('📝 Punition de $totalLines lignes ajoutée'),
                        backgroundColor: Colors.red.shade700,
                      ),
                    );
                  },
                  child: const Text(
                    'Créer la punition',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showPunishmentDetail(PunishmentLines punishment) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          // Re-read the punishment from provider to get updated state
          final provider = context.read<FamilyProvider>();
          final currentP = provider.punishments.firstWhere(
            (p) => p.id == punishment.id,
            orElse: () => punishment,
          );

          return Container(
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
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Text(
                      currentP.isCompleted ? '✅' : '📝',
                      style: const TextStyle(fontSize: 28),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        currentP.text,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Progress bar
                AnimatedBuilder(
                  animation: _progressController,
                  builder: (ctx, _) {
                    final progress =
                        currentP.progress * _progressController.value;
                    return Column(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: LinearProgressIndicator(
                            value: progress,
                            minHeight: 12,
                            backgroundColor:
                                Colors.white.withValues(alpha: 0.1),
                            valueColor: AlwaysStoppedAnimation(
                              currentP.isCompleted
                                  ? Colors.greenAccent
                                  : Colors.redAccent,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '${currentP.completedLines}/${currentP.totalLines} lignes',
                              style: const TextStyle(color: Colors.white70),
                            ),
                            Text(
                              '${(currentP.progress * 100).toInt()}%',
                              style: TextStyle(
                                color: currentP.isCompleted
                                    ? Colors.greenAccent
                                    : Colors.redAccent,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 20),
                if (!currentP.isCompleted) ...[
                  const Text(
                    'Ajouter des lignes complétées',
                    style: TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [1, 5, 10].map((n) {
                      return TvFocusWrapper(
                        onTap: () {
                          final prov = context.read<FamilyProvider>();
                          prov.updatePunishmentProgress(currentP.id, n);
                          _progressController.forward(from: 0);
                          setSheetState(() {});

                          // Check if completed after update
                          final updated = prov.punishments.firstWhere(
                            (p) => p.id == currentP.id,
                            orElse: () => currentP,
                          );
                          if (updated.isCompleted) {
                            Navigator.pop(ctx);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content:
                                    const Text('🎉 Punition terminée !'),
                                backgroundColor: Colors.green.shade700,
                              ),
                            );
                          }
                        },
                        child: Chip(
                          label: Text(
                            '+$n',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          backgroundColor:
                              Colors.redAccent.withValues(alpha: 0.3),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                ],
                Row(
                  children: [
                    Expanded(
                      child: TvFocusWrapper(
                        onTap: () {
                          context
                              .read<FamilyProvider>()
                              .removePunishment(currentP.id);
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content:
                                  const Text('🗑️ Punition supprimée'),
                              backgroundColor: Colors.red.shade700,
                            ),
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          decoration: BoxDecoration(
                            color:
                                Colors.red.shade900.withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color:
                                  Colors.redAccent.withValues(alpha: 0.5),
                            ),
                          ),
                          child: const Center(
                            child: Text(
                              '🗑️ Supprimer',
                              style: TextStyle(
                                color: Colors.redAccent,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
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
        final activeCount = punishments.where((e) => !e.isCompleted).length;
        final completedCount = punishments.where((e) => e.isCompleted).length;

        return Scaffold(
          backgroundColor: Colors.transparent,
          body: AnimatedBackground(
            child: SafeArea(
              child: Column(
                children: [
                  // ── Header ──
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        TvFocusWrapper(
                          onTap: () => Navigator.pop(context),
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.arrow_back,
                                color: Colors.white),
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Text('📝', style: TextStyle(fontSize: 28)),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'Punitions',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        TvFocusWrapper(
                          onTap: _showAddPunishmentSheet,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 10),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Colors.redAccent.shade700,
                                  Colors.red.shade700,
                                ],
                              ),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.add,
                                    color: Colors.white, size: 20),
                                SizedBox(width: 4),
                                Text(
                                  'Ajouter',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // ── Child selector ──
                  if (children.length > 1)
                    SizedBox(
                      height: 50,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: children.length,
                        itemBuilder: (ctx, i) {
                          final child = children[i];
                          final selected = child.id == _selectedChildId;
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: TvFocusWrapper(
                              onTap: () {
                                setState(
                                    () => _selectedChildId = child.id);
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
                                          .withValues(alpha: 0.3)
                                      : Colors.white
                                          .withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(20),
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

                  // ── Stats bar ──
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: GlassCard(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _statChip(
                              'En cours', '$activeCount', Colors.redAccent),
                          Container(
                              width: 1,
                              height: 30,
                              color: Colors.white24),
                          _statChip('Terminées', '$completedCount',
                              Colors.greenAccent),
                          Container(
                              width: 1,
                              height: 30,
                              color: Colors.white24),
                          _statChip('Total', '${punishments.length}',
                              Colors.white70),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 8),

                  // ── List ──
                  Expanded(
                    child: punishments.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: const [
                                Text('📝',
                                    style: TextStyle(fontSize: 64)),
                                SizedBox(height: 16),
                                Text(
                                  'Aucune punition',
                                  style: TextStyle(
                                      color: Colors.white54,
                                      fontSize: 18),
                                ),
                                SizedBox(height: 8),
                                Text(
                                  'Espérons que ça dure !',
                                  style: TextStyle(
                                      color: Colors.white38,
                                      fontSize: 14),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 16),
                            itemCount: punishments.length,
                            itemBuilder: (ctx, index) {
                              final p = punishments[index];
                              final delay = index * 0.1;
                              return AnimatedBuilder(
                                animation: _listController,
                                builder: (ctx, child) {
                                  final raw =
                                      (_listController.value - delay) /
                                          (1 - delay);
                                  final t = Curves.elasticOut
                                      .transform(raw.clamp(0.0, 1.0));
                                  return Transform.translate(
                                    offset: Offset(0, 50 * (1 - t)),
                                    child:
                                        Opacity(opacity: t, child: child),
                                  );
                                },
                                child: Padding(
                                  padding:
                                      const EdgeInsets.only(bottom: 8),
                                  child: TvFocusWrapper(
                                    onTap: () {
                                      _progressController.forward(
                                          from: 0);
                                      _showPunishmentDetail(p);
                                    },
                                    child: GlassCard(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Text(
                                                p.isCompleted
                                                    ? '✅'
                                                    : '📝',
                                                style: const TextStyle(
                                                    fontSize: 24),
                                              ),
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
                                                      '${p.completedLines}/${p.totalLines} lignes • ${(p.progress * 100).toInt()}%',
                                                      style: TextStyle(
                                                        color: p
                                                                .isCompleted
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
                                                size: 20,
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 8),
                                          ClipRRect(
                                            borderRadius:
                                                BorderRadius.circular(4),
                                            child:
                                                LinearProgressIndicator(
                                              value: p.progress,
                                              minHeight: 6,
                                              backgroundColor: Colors
                                                  .white
                                                  .withValues(
                                                      alpha: 0.1),
                                              valueColor:
                                                  AlwaysStoppedAnimation(
                                                p.isCompleted
                                                    ? Colors.greenAccent
                                                    : Colors.redAccent,
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
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: TextStyle(
              color: color, fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(color: Colors.white54, fontSize: 12),
        ),
      ],
    );
  }
}
