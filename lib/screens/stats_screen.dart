import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/family_provider.dart';
import '../widgets/animated_background.dart';
import '../widgets/glass_card.dart';

class StatsScreen extends StatelessWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<FamilyProvider>(
      builder: (context, provider, _) {
        if (provider.children.isEmpty) {
          return AnimatedBackground(
            child: Scaffold(
              backgroundColor: Colors.transparent,
              body: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.bar_chart_rounded,
                        size: 80, color: Colors.white24),
                    const SizedBox(height: 16),
                    const Text(
                      'Aucun enfant enregistré',
                      style: TextStyle(color: Colors.white54, fontSize: 16),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        return AnimatedBackground(
          child: Scaffold(
            backgroundColor: Colors.transparent,
            appBar: AppBar(
              title: const Text('Statistiques'),
              backgroundColor: Colors.transparent,
              elevation: 0,
            ),
            body: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(context),
                  const SizedBox(height: 20),
                  _buildScoreComparison(context, provider),
                  const SizedBox(height: 20),
                  ...provider.children.map(
                    (child) => Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: _buildWeeklyChart(context, provider, child),
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildSummaryCards(context, provider),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Text(
      'Vue d\'ensemble',
      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
    );
  }

  Widget _buildScoreComparison(BuildContext context, FamilyProvider provider) {
    final children = provider.children;
    final maxPoints = children.fold<int>(
      1,
      (max, c) => c.points > max ? c.points : max,
    );

    return GlassCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Comparaison des scores',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            ...children.map((child) {
              final ratio = maxPoints > 0 ? child.points / maxPoints : 0.0;
              final colors = [
                Colors.cyanAccent,
                Colors.purpleAccent,
                Colors.orangeAccent,
                Colors.greenAccent,
                Colors.pinkAccent,
              ];
              final colorIndex = children.indexOf(child) % colors.length;

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    SizedBox(
                      width: 70,
                      child: Text(
                        child.name,
                        style:
                            const TextStyle(color: Colors.white70, fontSize: 13),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                          value: ratio.clamp(0.0, 1.0),
                          minHeight: 18,
                          backgroundColor: Colors.white10,
                          valueColor:
                              AlwaysStoppedAnimation(colors[colorIndex]),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${child.points}',
                      style: TextStyle(
                        color: colors[colorIndex],
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
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

  Widget _buildWeeklyChart(
      BuildContext context, FamilyProvider provider, dynamic child) {
    final now = DateTime.now();
    final weekStart = now.subtract(Duration(days: now.weekday - 1));
    final dailyPoints = List.generate(7, (i) {
      final day = weekStart.add(Duration(days: i));
      final dayActivities =
          provider.getActivitiesForChildOnDate(child.id, day);
      int total = 0;
      for (final a in dayActivities) {
        total += (a.points as int?) ?? 0;
      }
      return total;
    });

    final maxDaily =
        dailyPoints.fold<int>(1, (m, v) => v.abs() > m ? v.abs() : m);
    final days = ['Lun', 'Mar', 'Mer', 'Jeu', 'Ven', 'Sam', 'Dim'];

    return GlassCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${child.name} – Semaine',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 120,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: List.generate(7, (i) {
                  final val = dailyPoints[i];
                  final height =
                      maxDaily > 0 ? (val.abs() / maxDaily) * 100 : 0.0;
                  final isPositive = val >= 0;

                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text(
                            '$val',
                            style: TextStyle(
                              color: isPositive
                                  ? Colors.greenAccent
                                  : Colors.redAccent,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            height: height.clamp(4.0, 100.0),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(4),
                              gradient: LinearGradient(
                                begin: Alignment.bottomCenter,
                                end: Alignment.topCenter,
                                colors: isPositive
                                    ? [
                                        Colors.cyanAccent.withOpacity(0.4),
                                        Colors.cyanAccent
                                      ]
                                    : [
                                        Colors.redAccent.withOpacity(0.4),
                                        Colors.redAccent
                                      ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            days[i],
                            style: const TextStyle(
                              color: Colors.white54,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCards(BuildContext context, FamilyProvider provider) {
    int totalPoints = 0;
    int totalActivities = 0;
    int bonusCount = 0;
    int penaltyCount = 0;

    for (final child in provider.children) {
      totalPoints += child.points;
      final activities = provider.getActivitiesForChild(child.id);
      totalActivities += activities.length;
      for (final a in activities) {
        if ((a.points as int?) != null && a.points > 0) {
          bonusCount++;
        } else {
          penaltyCount++;
        }
      }
    }

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        _NeonStatCard(
          icon: Icons.star_rounded,
          value: '$totalPoints',
          label: 'Points totaux',
          color: Colors.amberAccent,
        ),
        _NeonStatCard(
          icon: Icons.timeline_rounded,
          value: '$totalActivities',
          label: 'Activités',
          color: Colors.cyanAccent,
        ),
        _NeonStatCard(
          icon: Icons.thumb_up_rounded,
          value: '$bonusCount',
          label: 'Bonus',
          color: Colors.greenAccent,
        ),
        _NeonStatCard(
          icon: Icons.thumb_down_rounded,
          value: '$penaltyCount',
          label: 'Pénalités',
          color: Colors.redAccent,
        ),
      ],
    );
  }
}

class _NeonStatCard extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;

  const _NeonStatCard({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final width = (MediaQuery.of(context).size.width - 44) / 2;
    return GlassCard(
      child: SizedBox(
        width: width,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Icon(icon, color: color, size: 32),
              const SizedBox(height: 8),
              Text(
                value,
                style: TextStyle(
                  color: color,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  shadows: [
                    Shadow(color: color.withOpacity(0.5), blurRadius: 12),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: const TextStyle(color: Colors.white60, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
