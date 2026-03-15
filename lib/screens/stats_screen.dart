import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../providers/family_provider.dart';
import '../widgets/glass_card.dart';
import '../widgets/animated_background.dart';

class StatsScreen extends StatelessWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    return Consumer<FamilyProvider>(
      builder: (context, provider, _) {
        if (provider.children.isEmpty) {
          return AnimatedBackground(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  GlowIcon(icon: Icons.bar_chart_rounded, size: 64, color: Colors.grey[600]),
                  const SizedBox(height: 16),
                  NeonText(text: 'Aucune donnee', fontSize: 18, color: Colors.grey),
                ],
              ),
            ),
          );
        }

        return Scaffold(
          backgroundColor: Colors.transparent,
          body: AnimatedBackground(
            child: SafeArea(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        GlowIcon(icon: Icons.bar_chart_rounded, color: primary, size: 26),
                        const SizedBox(width: 10),
                        NeonText(text: 'Statistiques', fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white, glowIntensity: 0.2),
                      ],
                    ),
                    const SizedBox(height: 20),
                    // Score comparison
                    _buildScoreComparison(provider, primary),
                    const SizedBox(height: 20),
                    // Weekly charts
                    ...provider.children.map((child) => _buildWeeklyChart(child, provider, primary)),
                    const SizedBox(height: 16),
                    // Summary
                    _buildSummaryCards(provider, primary),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildScoreComparison(FamilyProvider provider, Color primary) {
    final sorted = provider.childrenSorted;
    final maxPoints = sorted.isNotEmpty ? sorted.first.points.toDouble() : 1.0;

    final neonColors = [
      const Color(0xFF00E676),
      const Color(0xFF00E5FF),
      const Color(0xFF7C4DFF),
      const Color(0xFFFFD740),
      const Color(0xFFFF6D00),
      const Color(0xFFFF1744),
    ];

    return GlassCard(
      padding: const EdgeInsets.all(20),
      glowColor: primary,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          NeonText(text: 'Comparaison des scores', fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white, glowIntensity: 0.15),
          const SizedBox(height: 20),
          SizedBox(
            height: 200,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: maxPoints > 0 ? maxPoints * 1.2 : 10,
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    tooltipRoundedRadius: 12,
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      return BarTooltipItem(
                        '${sorted[group.x].name}\n${rod.toY.toInt()} pts',
                        const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                      );
                    },
                  ),
                ),
                titlesData: FlTitlesData(
                  show: true,
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (v, _) {
                        if (v.toInt() < sorted.length) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              sorted[v.toInt()].name,
                              style: const TextStyle(fontSize: 10, color: Colors.white60),
                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                        }
                        return const Text('');
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 36,
                      getTitlesWidget: (v, _) => Text(
                        v.toInt().toString(),
                        style: const TextStyle(fontSize: 10, color: Colors.white38),
                      ),
                    ),
                  ),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                borderData: FlBorderData(show: false),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (value) => FlLine(
                    color: Colors.white.withValues(alpha: 0.05),
                    strokeWidth: 1,
                  ),
                ),
                barGroups: sorted.asMap().entries.map((e) {
                  final color = neonColors[e.key % neonColors.length];
                  return BarChartGroupData(
                    x: e.key,
                    barRods: [
                      BarChartRodData(
                        toY: e.value.points.toDouble(),
                        gradient: LinearGradient(
                          colors: [color, color.withValues(alpha: 0.5)],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                        width: 22,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                        backDrawRodData: BackgroundBarChartRodData(
                          show: true,
                          toY: maxPoints > 0 ? maxPoints * 1.2 : 10,
                          color: Colors.white.withValues(alpha: 0.03),
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWeeklyChart(child, FamilyProvider provider, Color primary) {
    final weekStats = provider.getWeeklyStats(child.id);
    final maxVal = weekStats.values.fold<int>(0, (a, b) => a > b ? a : b);

    return GlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(child.avatar.isEmpty ? '\u{1F466}' : child.avatar, style: const TextStyle(fontSize: 20)),
              const SizedBox(width: 8),
              NeonText(text: '${child.name} - Semaine', fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white, glowIntensity: 0.15),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 140,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: maxVal > 0 ? maxVal.toDouble() * 1.3 : 10,
                barTouchData: BarTouchData(enabled: true),
                titlesData: FlTitlesData(
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (v, _) {
                        final days = weekStats.keys.toList();
                        if (v.toInt() < days.length) {
                          return Text(days[v.toInt()], style: const TextStyle(fontSize: 10, color: Colors.white54));
                        }
                        return const Text('');
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 28,
                      getTitlesWidget: (v, _) => Text(
                        v.toInt().toString(),
                        style: const TextStyle(fontSize: 9, color: Colors.white30),
                      ),
                    ),
                  ),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                borderData: FlBorderData(show: false),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (value) => FlLine(
                    color: Colors.white.withValues(alpha: 0.04),
                    strokeWidth: 1,
                  ),
                ),
                barGroups: weekStats.entries.toList().asMap().entries.map((e) {
                  return BarChartGroupData(
                    x: e.key,
                    barRods: [
                      BarChartRodData(
                        toY: e.value.value.toDouble(),
                        gradient: LinearGradient(
                          colors: [primary, primary.withValues(alpha: 0.4)],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                        width: 16,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCards(FamilyProvider provider, Color primary) {
    final totalPoints = provider.children.fold<int>(0, (s, c) => s + c.points);
    final totalEntries = provider.history.length;
    final bonusCount = provider.history.where((h) => h.isBonus).length;
    final penalityCount = provider.history.where((h) => !h.isBonus).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        NeonText(text: 'Resume', fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white, glowIntensity: 0.15),
        const SizedBox(height: 12),
        Row(
          children: [
            _NeonStatCard(icon: Icons.star_rounded, label: 'Total points', value: '$totalPoints', color: const Color(0xFFFFD700)),
            const SizedBox(width: 10),
            _NeonStatCard(icon: Icons.history_rounded, label: 'Activites', value: '$totalEntries', color: const Color(0xFF00E5FF)),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            _NeonStatCard(icon: Icons.add_circle_rounded, label: 'Bonus', value: '$bonusCount', color: const Color(0xFF00E676)),
            const SizedBox(width: 10),
            _NeonStatCard(icon: Icons.remove_circle_rounded, label: 'Penalites', value: '$penalityCount', color: const Color(0xFFFF1744)),
          ],
        ),
      ],
    );
  }
}

class _NeonStatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  const _NeonStatCard({required this.icon, required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          color: color.withValues(alpha: 0.06),
          border: Border.all(color: color.withValues(alpha: 0.15)),
          boxShadow: [BoxShadow(color: color.withValues(alpha: 0.08), blurRadius: 12)],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 24, shadows: [Shadow(color: color.withValues(alpha: 0.5), blurRadius: 8)]),
            const SizedBox(height: 8),
            NeonText(text: value, fontSize: 24, fontWeight: FontWeight.w900, color: color, glowIntensity: 0.4),
            Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[500])),
          ],
        ),
      ),
    );
  }
}
