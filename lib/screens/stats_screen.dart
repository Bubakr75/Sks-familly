import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/family_provider.dart';
import '../models/child_model.dart';
import '../models/history_entry.dart';
import '../widgets/animated_background.dart';
import '../widgets/glass_card.dart';
import '../widgets/tv_focus_wrapper.dart';

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

  @override
  void initState() {
    super.initState();
    _barController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500));
    _cardController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200));
    _chartController = AnimationController(vsync: this, duration: const Duration(milliseconds: 2000));

    _barController.forward();
    Future.delayed(const Duration(milliseconds: 400), () { if (mounted) _chartController.forward(); });
    Future.delayed(const Duration(milliseconds: 800), () { if (mounted) _cardController.forward(); });
  }

  @override
  void dispose() {
    _barController.dispose();
    _cardController.dispose();
    _chartController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<FamilyProvider>(
      builder: (context, fp, _) {
        final children = fp.children;

        if (children.isEmpty) {
          return AnimatedBackground(
            child: Scaffold(
              backgroundColor: Colors.transparent,
              appBar: AppBar(title: const Text('Statistiques'), backgroundColor: Colors.transparent, elevation: 0),
              body: Center(
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.0, end: 1.0),
                  duration: const Duration(milliseconds: 800),
                  builder: (context, value, child) {
                    return Opacity(opacity: value, child: Transform.scale(scale: value, child: child));
                  },
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('📊', style: TextStyle(fontSize: 60)),
                      const SizedBox(height: 12),
                      Text('Aucun enfant enregistré', style: TextStyle(color: Colors.white54, fontSize: 16)),
                    ],
                  ),
                ),
              ),
            ),
          );
        }

        // Use .points instead of .totalPoints
        final sorted = List<ChildModel>.from(children)
          ..sort((a, b) => b.points.compareTo(a.points));
        final maxPoints = sorted.isNotEmpty ? sorted.first.points : 1;

        int totalActivities = 0;
        int totalBonus = 0;
        int totalPenalty = 0;
        int totalPoints = 0;
        for (final child in children) {
          final history = fp.getHistoryForChild(child.id);
          totalActivities += history.length;
          for (final h in history) {
            final pts = h.isBonus ? h.points : -h.points;
            if (pts > 0) { totalBonus++; } else if (pts < 0) { totalPenalty++; }
            totalPoints += pts;
          }
        }

        return AnimatedBackground(
          child: Scaffold(
            backgroundColor: Colors.transparent,
            appBar: AppBar(
              title: ShaderMask(
                shaderCallback: (bounds) => const LinearGradient(colors: [Colors.cyan, Colors.blue, Colors.purple]).createShader(bounds),
                child: const Text('📊 Statistiques', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
              ),
              backgroundColor: Colors.transparent,
              elevation: 0,
            ),
            body: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildScoreComparison(sorted, maxPoints),
                  const SizedBox(height: 20),
                  ...children.asMap().entries.map((entry) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: _buildWeeklyChart(fp, entry.value, entry.key),
                    );
                  }),
                  const SizedBox(height: 10),
                  _buildSummaryCards(totalPoints, totalActivities, totalBonus, totalPenalty),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildScoreComparison(List<ChildModel> sorted, int maxPoints) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOutBack,
      builder: (context, value, child) {
        return Transform.scale(scale: 0.8 + 0.2 * value, child: Opacity(opacity: value, child: child));
      },
      child: GlassCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              const Text('🏅', style: TextStyle(fontSize: 20)),
              const SizedBox(width: 8),
              const Text('Comparaison des scores', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
            ]),
            const SizedBox(height: 16),
            ...sorted.asMap().entries.map((entry) {
              final index = entry.key;
              final child = entry.value;
              final ratio = maxPoints > 0 ? child.points / maxPoints : 0.0;
              final colors = [Colors.cyan, Colors.purple, Colors.orange, Colors.green, Colors.pink];
              final color = colors[index % colors.length];

              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(child.name, style: const TextStyle(color: Colors.white, fontSize: 13)),
                        AnimatedBuilder(
                          animation: _barController,
                          builder: (context, _) {
                            final val = (child.points * _barController.value).round();
                            return Text('$val pts', style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13));
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
                            Container(height: 14, decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), borderRadius: BorderRadius.circular(6))),
                            FractionallySizedBox(
                              widthFactor: (ratio * _barController.value).clamp(0.0, 1.0),
                              child: Container(
                                height: 14,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(colors: [color, color.withOpacity(0.6)]),
                                  borderRadius: BorderRadius.circular(6),
                                  boxShadow: [BoxShadow(color: color.withOpacity(0.4), blurRadius: 6)],
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

  Widget _buildWeeklyChart(FamilyProvider fp, ChildModel child, int childIndex) {
    final history = fp.getHistoryForChild(child.id);
    final now = DateTime.now();
    final weekDays = ['Lun', 'Mar', 'Mer', 'Jeu', 'Ven', 'Sam', 'Dim'];
    final dailyPoints = List<int>.filled(7, 0);

    for (final h in history) {
      final diff = now.difference(h.date).inDays;
      if (diff < 7 && diff >= 0) {
        final dayIndex = h.date.weekday - 1;
        dailyPoints[dayIndex] += h.isBonus ? h.points : -h.points;
      }
    }

    final maxVal = dailyPoints.map((e) => e.abs()).fold<int>(1, (a, b) => a > b ? a : b);
    final colors = [Colors.cyan, Colors.purple, Colors.orange, Colors.green, Colors.pink];
    final color = colors[childIndex % colors.length];

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 800 + childIndex * 200),
      curve: Curves.easeOutBack,
      builder: (context, value, ch) {
        return Transform.translate(offset: Offset(0, 30 * (1 - value)), child: Opacity(opacity: value, child: ch));
      },
      child: GlassCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('📅 ${child.name} - Cette semaine', style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
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
                      final barRatio = maxVal > 0 ? (pts.abs() / maxVal * _chartController.value) : 0.0;
                      final barHeight = (barRatio * 80).clamp(4.0, 80.0);
                      final isPositive = pts >= 0;
                      return Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text(pts != 0 ? '${(pts * _chartController.value).round()}' : '',
                              style: TextStyle(color: isPositive ? Colors.green[300] : Colors.red[300], fontSize: 10, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            width: 28,
                            height: barHeight,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(begin: Alignment.bottomCenter, end: Alignment.topCenter,
                                  colors: isPositive ? [color.withOpacity(0.4), color] : [Colors.red.withOpacity(0.4), Colors.red]),
                              borderRadius: BorderRadius.circular(4),
                              boxShadow: [BoxShadow(color: (isPositive ? color : Colors.red).withOpacity(0.3), blurRadius: 4)],
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(weekDays[i],
                              style: TextStyle(color: i == now.weekday - 1 ? Colors.white : Colors.white38, fontSize: 10,
                                  fontWeight: i == now.weekday - 1 ? FontWeight.bold : FontWeight.normal)),
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

  Widget _buildSummaryCards(int totalPts, int totalAct, int totalBonus, int totalPenalty) {
    final cards = [
      _SummaryData('Total Points', '$totalPts', Icons.stars, Colors.amber),
      _SummaryData('Activités', '$totalAct', Icons.timeline, Colors.cyan),
      _SummaryData('Bonus', '$totalBonus', Icons.thumb_up, Colors.green),
      _SummaryData('Pénalités', '$totalPenalty', Icons.thumb_down, Colors.red),
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
            final card = cards[i];
            final delay = i * 0.2;
            final progress = ((_cardController.value - delay) / (1.0 - delay)).clamp(0.0, 1.0);
            final curved = Curves.elasticOut.transform(progress.toDouble());
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
                        decoration: BoxDecoration(shape: BoxShape.circle, color: card.color.withOpacity(0.15),
                            boxShadow: [BoxShadow(color: card.color.withOpacity(0.3), blurRadius: 8)]),
                        child: Icon(card.icon, color: card.color, size: 22),
                      ),
                      const SizedBox(height: 6),
                      TweenAnimationBuilder<int>(
                        tween: IntTween(begin: 0, end: int.tryParse(card.value) ?? 0),
                        duration: const Duration(milliseconds: 1500),
                        builder: (context, value, _) {
                          return Text('$value', style: TextStyle(color: card.color, fontSize: 20, fontWeight: FontWeight.bold));
                        },
                      ),
                      Text(card.label, style: const TextStyle(color: Colors.white54, fontSize: 11)),
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

class _SummaryData {
  final String label, value;
  final IconData icon;
  final Color color;
  _SummaryData(this.label, this.value, this.icon, this.color);
}
