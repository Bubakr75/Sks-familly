// lib/screens/stats_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/family_provider.dart';
import '../models/child_model.dart';
import '../widgets/animated_background.dart';
import '../widgets/glass_card.dart';
import '../widgets/tv_focus_wrapper.dart';
import '../widgets/timeline_widget.dart';   // ✅ ajout
import 'timeline_screen.dart';              // ✅ ajout pour "Tout voir"

class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});
  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen>
    with TickerProviderStateMixin {
  late AnimationController _barController;
  late AnimationController _cardController;
  late AnimationController _chartController;

  // ✅ enfant sélectionné pour le panneau timeline
  String? _selectedChildIdForTimeline;

  @override
  void initState() {
    super.initState();
    _barController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1500));
    _cardController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1200));
    _chartController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 2000));

    _barController.forward();
    Future.delayed(const Duration(milliseconds: 400), () {
      if (mounted) _chartController.forward();
    });
    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted) _cardController.forward();
    });
  }

  @override
  void dispose() {
    _barController.dispose();
    _cardController.dispose();
    _chartController.dispose();
    super.dispose();
  }

  // ─────────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Consumer<FamilyProvider>(
      builder: (context, fp, _) {
        final children = fp.children;

        if (children.isEmpty) {
          return AnimatedBackground(
            child: Scaffold(
              backgroundColor: Colors.transparent,
              appBar: AppBar(
                  title: const Text('Statistiques'),
                  backgroundColor: Colors.transparent,
                  elevation: 0),
              body: Center(
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.0, end: 1.0),
                  duration: const Duration(milliseconds: 800),
                  builder: (context, value, child) => Opacity(
                      opacity: value,
                      child: Transform.scale(scale: value, child: child)),
                  child: const Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('📊', style: TextStyle(fontSize: 60)),
                      SizedBox(height: 12),
                      Text('Aucun enfant enregistré',
                          style: TextStyle(
                              color: Colors.white54, fontSize: 16)),
                    ],
                  ),
                ),
              ),
            ),
          );
        }

        final sorted = List<ChildModel>.from(children)
          ..sort((a, b) => b.points.compareTo(a.points));
        final maxPoints = sorted.isNotEmpty && sorted.first.points > 0
            ? sorted.first.points
            : 1;

        int totalBonus     = 0;
        int totalPenalty   = 0;
        int totalPoints    = 0;
        int totalActivities = 0;

        for (final child in children) {
          final history = fp.getHistoryForChild(child.id);
          totalActivities += history.length;
          for (final h in history) {
            if (h.isBonus) {
              totalBonus++;
              totalPoints += h.points;
            } else {
              totalPenalty++;
              totalPoints -= h.points;
            }
          }
        }

        // ✅ enfant par défaut pour la timeline = premier de la liste
        _selectedChildIdForTimeline ??= children.first.id;

        return AnimatedBackground(
          child: Scaffold(
            backgroundColor: Colors.transparent,
            appBar: AppBar(
              title: ShaderMask(
                shaderCallback: (bounds) => const LinearGradient(
                  colors: [Colors.cyan, Colors.blue, Colors.purple],
                ).createShader(bounds),
                child: const Text('📊 Statistiques',
                    style: TextStyle(
                        fontWeight: FontWeight.bold, color: Colors.white)),
              ),
              backgroundColor: Colors.transparent,
              elevation: 0,
            ),
            body: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Comparaison scores ──
                  _buildScoreComparison(sorted, maxPoints),
                  const SizedBox(height: 20),

                  // ── Graphique semaine par enfant ──
                  ...children.asMap().entries.map((entry) => Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: _buildWeeklyChart(
                            fp, entry.value, entry.key),
                      )),
                  const SizedBox(height: 10),

                  // ── Cartes résumé global ──
                  _buildSummaryCards(totalPoints, totalActivities,
                      totalBonus, totalPenalty),
                  const SizedBox(height: 24),

                  // ✅ ── Section Timeline par enfant ──
                  _buildTimelineSection(fp, children),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ─── Section Timeline ─────────────────────────────────────────────────────
  Widget _buildTimelineSection(
      FamilyProvider fp, List<ChildModel> children) {
    final selectedChild = children.firstWhere(
      (c) => c.id == _selectedChildIdForTimeline,
      orElse: () => children.first,
    );
    final history = fp.getHistoryForChild(selectedChild.id);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── En-tête ──
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF7C4DFF).withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.timeline_rounded,
                  color: Color(0xFF7C4DFF), size: 18),
            ),
            const SizedBox(width: 10),
            const Text(
              'Historique détaillé',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold),
            ),
            const Spacer(),
            // ── Bouton plein écran ──
            GestureDetector(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => TimelineScreen(
                      initialChildId: selectedChild.id),
                ),
              ),
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF7C4DFF).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: const Color(0xFF7C4DFF).withOpacity(0.5)),
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
        const SizedBox(height: 12),

        // ── Sélecteur d'enfant ──
        if (children.length > 1) ...[
          SizedBox(
            height: 44,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: children.length,
              itemBuilder: (_, i) {
                final child    = children[i];
                final selected = child.id == _selectedChildIdForTimeline;
                return GestureDetector(
                  onTap: () => setState(
                      () => _selectedChildIdForTimeline = child.id),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.only(right: 8, top: 2, bottom: 2),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: selected
                          ? const Color(0xFF7C4DFF)
                          : Colors.white.withOpacity(0.07),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: selected
                            ? Colors.transparent
                            : Colors.white24,
                      ),
                    ),
                    child: Row(
                      children: [
                        Text(
                          child.avatar.isNotEmpty ? child.avatar : '🧒',
                          style: const TextStyle(fontSize: 16),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          child.name,
                          style: TextStyle(
                            color: selected
                                ? Colors.white
                                : Colors.white70,
                            fontWeight: selected
                                ? FontWeight.bold
                                : FontWeight.normal,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 10),
        ],

        // ── Chips résumé ──
        Row(
          children: [
            _summaryChip(
              '${history.where((h) => h.isBonus).length}',
              '✅ Bonus',
              Colors.greenAccent,
            ),
            const SizedBox(width: 8),
            _summaryChip(
              '${history.where((h) => !h.isBonus).length}',
              '❌ Pénalités',
              Colors.redAccent,
            ),
            const SizedBox(width: 8),
            _summaryChip(
              '${history.length}',
              '📋 Total',
              Colors.cyanAccent,
            ),
          ],
        ),
        const SizedBox(height: 12),

        // ── Timeline en hauteur fixe avec scroll interne ──
        Container(
          height: 420,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.03),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.08)),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: history.isEmpty
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.timeline_rounded,
                            color: Colors.white24, size: 48),
                        SizedBox(height: 12),
                        Text('Aucun événement',
                            style: TextStyle(
                                color: Colors.white54, fontSize: 15)),
                      ],
                    ),
                  )
                : TimelineWidget(entries: history),
          ),
        ),
      ],
    );
  }

  // ─── Chip résumé ──────────────────────────────────────────────────────────
  Widget _summaryChip(String value, String label, Color color) {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
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

  // ─── Comparaison scores ───────────────────────────────────────────────────
  Widget _buildScoreComparison(List<ChildModel> sorted, int maxPoints) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOutBack,
      builder: (context, value, child) => Transform.scale(
          scale: 0.8 + 0.2 * value,
          child: Opacity(opacity: value, child: child)),
      child: GlassCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(children: [
              Text('🏅', style: TextStyle(fontSize: 20)),
              SizedBox(width: 8),
              Text('Comparaison des scores',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold)),
            ]),
            const SizedBox(height: 16),
            ...sorted.asMap().entries.map((entry) {
              final index = entry.key;
              final child = entry.value;
              final ratio =
                  maxPoints > 0 ? child.points / maxPoints : 0.0;
              const colors = [
                Colors.cyan,
                Colors.purple,
                Colors.orange,
                Colors.green,
                Colors.pink
              ];
              final color = colors[index % colors.length];

              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment:
                          MainAxisAlignment.spaceBetween,
                      children: [
                        Row(children: [
                          Text(
                            child.avatar.isNotEmpty
                                ? child.avatar
                                : '🧒',
                            style: const TextStyle(fontSize: 16),
                          ),
                          const SizedBox(width: 6),
                          Text(child.name,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 13)),
                        ]),
                        AnimatedBuilder(
                          animation: _barController,
                          builder: (context, _) {
                            final val = (child.points *
                                    _barController.value)
                                .round();
                            return Text('$val pts',
                                style: TextStyle(
                                    color: color,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13));
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    AnimatedBuilder(
                      animation: _barController,
                      builder: (context, _) {
                        return ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: Stack(children: [
                            Container(
                                height: 14,
                                decoration: BoxDecoration(
                                    color:
                                        Colors.white.withOpacity(0.1),
                                    borderRadius:
                                        BorderRadius.circular(6))),
                            FractionallySizedBox(
                              widthFactor: (ratio *
                                      _barController.value)
                                  .clamp(0.0, 1.0),
                              child: Container(
                                height: 14,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(colors: [
                                    color,
                                    color.withOpacity(0.6)
                                  ]),
                                  borderRadius:
                                      BorderRadius.circular(6),
                                  boxShadow: [
                                    BoxShadow(
                                        color:
                                            color.withOpacity(0.4),
                                        blurRadius: 6)
                                  ],
                                ),
                              ),
                            ),
                          ]),
                        );
                      },
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  // ─── Graphique hebdomadaire ───────────────────────────────────────────────
  Widget _buildWeeklyChart(
      FamilyProvider fp, ChildModel child, int childIndex) {
    final history  = fp.getHistoryForChild(child.id);
    final now      = DateTime.now();
    const weekDays = ['Lun', 'Mar', 'Mer', 'Jeu', 'Ven', 'Sam', 'Dim'];
    final dailyPoints = List<int>.filled(7, 0);

    for (final h in history) {
      final diff = now.difference(h.date).inDays;
      if (diff >= 0 && diff < 7) {
        final dayIndex = (h.date.weekday - 1).clamp(0, 6);
        dailyPoints[dayIndex] += h.isBonus ? h.points : -h.points;
      }
    }

    final maxVal = dailyPoints
        .map((e) => e.abs())
        .fold<int>(1, (a, b) => a > b ? a : b);

    const colors = [
      Colors.cyan,
      Colors.purple,
      Colors.orange,
      Colors.green,
      Colors.pink
    ];
    final color = colors[childIndex % colors.length];

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 800 + childIndex * 200),
      curve: Curves.easeOutBack,
      builder: (context, value, ch) => Transform.translate(
          offset: Offset(0, 30 * (1 - value)),
          child: Opacity(opacity: value, child: ch)),
      child: GlassCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  child.avatar.isNotEmpty ? child.avatar : '🧒',
                  style: const TextStyle(fontSize: 18),
                ),
                const SizedBox(width: 6),
                Text('${child.name} – Cette semaine',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold)),
                const Spacer(),
                // ✅ Bouton timeline rapide par enfant
                GestureDetector(
                  onTap: () {
                    setState(() =>
                        _selectedChildIdForTimeline = child.id);
                    // Scroll vers le bas (la section timeline)
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: color.withOpacity(0.4)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.timeline_rounded,
                            color: color, size: 12),
                        const SizedBox(width: 4),
                        Text('Timeline',
                            style: TextStyle(
                                color: color,
                                fontSize: 10,
                                fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 130,
              child: AnimatedBuilder(
                animation: _chartController,
                builder: (context, _) {
                  return Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: List.generate(7, (i) {
                      final pts = dailyPoints[i];
                      final barRatio = maxVal > 0
                          ? (pts.abs() /
                              maxVal *
                              _chartController.value)
                          : 0.0;
                      final barHeight =
                          (barRatio * 80).clamp(4.0, 80.0);
                      final isPositive = pts >= 0;
                      return Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text(
                            pts != 0
                                ? '${(pts * _chartController.value).round()}'
                                : '',
                            style: TextStyle(
                                color: isPositive
                                    ? Colors.green[300]
                                    : Colors.red[300],
                                fontSize: 10,
                                fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          AnimatedContainer(
                            duration:
                                const Duration(milliseconds: 300),
                            width: 28,
                            height: barHeight,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.bottomCenter,
                                end: Alignment.topCenter,
                                colors: isPositive
                                    ? [color.withOpacity(0.4), color]
                                    : [
                                        Colors.red.withOpacity(0.4),
                                        Colors.red
                                      ],
                              ),
                              borderRadius: BorderRadius.circular(4),
                              boxShadow: [
                                BoxShadow(
                                    color: (isPositive
                                            ? color
                                            : Colors.red)
                                        .withOpacity(0.3),
                                    blurRadius: 4)
                              ],
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            weekDays[i],
                            style: TextStyle(
                              color: i == now.weekday - 1
                                  ? Colors.white
                                  : Colors.white38,
                              fontSize: 10,
                              fontWeight: i == now.weekday - 1
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          ),
                        ],
                      );
                    }),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Cartes résumé global ─────────────────────────────────────────────────
  Widget _buildSummaryCards(
      int totalPts, int totalAct, int totalBonus, int totalPenalty) {
    final cards = [
      _SummaryData('Total Points', totalPts,    Icons.stars,      Colors.amber),
      _SummaryData('Activités',    totalAct,    Icons.timeline,   Colors.cyan),
      _SummaryData('Bonus',        totalBonus,  Icons.thumb_up,   Colors.green),
      _SummaryData('Pénalités',    totalPenalty,Icons.thumb_down, Colors.red),
    ];

    return AnimatedBuilder(
      animation: _cardController,
      builder: (context, _) {
        return GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 1.6,
          children: List.generate(cards.length, (i) {
            final card    = cards[i];
            final delay   = i * 0.2;
            final progress = ((_cardController.value - delay) /
                    (1.0 - delay))
                .clamp(0.0, 1.0);
            final curved =
                Curves.elasticOut.transform(progress.toDouble());
            return Transform.scale(
              scale: curved.clamp(0.0, 1.2),
              child: Opacity(
                opacity: progress,
                child: GlassCard(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: card.color.withOpacity(0.15),
                            boxShadow: [
                              BoxShadow(
                                  color: card.color.withOpacity(0.3),
                                  blurRadius: 8)
                            ]),
                        child: Icon(card.icon,
                            color: card.color, size: 22),
                      ),
                      const SizedBox(height: 6),
                      TweenAnimationBuilder<int>(
                        tween: IntTween(
                            begin: 0, end: card.value.abs()),
                        duration:
                            const Duration(milliseconds: 1500),
                        builder: (context, value, _) {
                          final display = card.value < 0
                              ? '-$value'
                              : '$value';
                          return Text(display,
                              style: TextStyle(
                                  color: card.color,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold));
                        },
                      ),
                      Text(card.label,
                          style: const TextStyle(
                              color: Colors.white54, fontSize: 11)),
                    ],
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
class _SummaryData {
  final String  label;
  final int     value;
  final IconData icon;
  final Color   color;
  const _SummaryData(this.label, this.value, this.icon, this.color);
}
