// lib/screens/screen_time_screen.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../providers/family_provider.dart';
import '../widgets/animated_background.dart';
import '../widgets/glass_card.dart';

class ScreenTimeScreen extends StatefulWidget {
  const ScreenTimeScreen({super.key});
  @override
  State<ScreenTimeScreen> createState() => _ScreenTimeScreenState();
}

class _ScreenTimeScreenState extends State<ScreenTimeScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String? _selectedChildId;

  // Jours de la semaine pour le sélecteur de calcul
  static const _jours = ['Lundi', 'Mardi', 'Mercredi', 'Jeudi', 'Vendredi', 'Samedi', 'Dimanche'];
  int _jourCible = 5; // Samedi par défaut (index 5)
  // Jours sources sélectionnés pour le calcul
  final Set<int> _joursSources = {0, 1, 2, 3, 4}; // Lun-Ven par défaut

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  String _formatMinutes(int minutes) {
    final h = minutes ~/ 60;
    final m = minutes % 60;
    if (h == 0) return '${m}min';
    if (m == 0) return '${h}h';
    return '${h}h${m.toString().padLeft(2, '0')}';
  }

  Color _getProgressColor(double progress) {
    if (progress <= 0.25) return const Color(0xFF00E676);
    if (progress <= 0.5) return const Color(0xFF448AFF);
    if (progress <= 0.75) return Colors.orange;
    return const Color(0xFFFF1744);
  }

  // ─── Helpers notes ──────────────────────────────────────────
  List<Map<String, dynamic>> _getSchoolNotes(FamilyProvider provider, String childId) {
    final history = provider.getHistoryForChild(childId);
    return history.where((h) => h.category == 'school_note').map((h) {
      String subject = h.reason;
      int noteValue = h.points;
      int noteMax = 20;
      final match = RegExp(r'^(.+):\s*(\d+)/(\d+)$').firstMatch(h.reason);
      if (match != null) {
        subject = match.group(1)!.trim();
        noteValue = int.tryParse(match.group(2)!) ?? h.points;
        noteMax = int.tryParse(match.group(3)!) ?? 20;
      }
      return {
        'subject': subject,
        'value': noteValue,
        'max': noteMax,
        'percent': noteMax > 0 ? noteValue / noteMax * 100 : 0.0,
        'date': h.date,
        'type': 'scolaire',
      };
    }).toList();
  }

  List<Map<String, dynamic>> _getBehaviorNotes(FamilyProvider provider, String childId) {
    final history = provider.getHistoryForChild(childId);
    return history
        .where((h) =>
            h.category != 'school_note' &&
            h.category != 'screen_time_bonus' &&
            h.category != 'saturday_rating' &&
            h.category != 'tribunal_vote' &&
            h.category != 'tribunal_verdict')
        .take(10)
        .map((h) => {
              'subject': h.reason,
              'points': h.isBonus ? h.points : -h.points,
              'date': h.date,
              'isBonus': h.isBonus,
              'type': 'comportement',
            })
        .toList();
  }

  int _percentToStars(double percent) {
    if (percent >= 90) return 5;
    if (percent >= 75) return 4;
    if (percent >= 60) return 3;
    if (percent >= 40) return 2;
    return 1;
  }

  /// Calcule le temps d'écran pour le jour cible
  /// basé sur les notes des jours sources sélectionnés cette semaine
  int _calculerTempsEcranPourJour(FamilyProvider provider, String childId) {
    if (_joursSources.isEmpty) return 0;

    final now = DateTime.now();
    final debutSemaine = now.subtract(Duration(days: now.weekday - 1));

    // Collecter les notes des jours sources
    final notesJoursSources = <Map<String, dynamic>>[];
    final history = provider.getHistoryForChild(childId);

    for (final jourIdx in _joursSources) {
      final jourDate = DateTime(
        debutSemaine.year,
        debutSemaine.month,
        debutSemaine.day + jourIdx,
      );
      final notesJour = history.where((h) {
        return h.category == 'school_note' &&
            h.date.year == jourDate.year &&
            h.date.month == jourDate.month &&
            h.date.day == jourDate.day;
      }).toList();

      for (final n in notesJour) {
        String subject = n.reason;
        int noteValue = n.points;
        int noteMax = 20;
        final match = RegExp(r'^(.+):\s*(\d+)/(\d+)$').firstMatch(n.reason);
        if (match != null) {
          noteValue = int.tryParse(match.group(2)!) ?? n.points;
          noteMax = int.tryParse(match.group(3)!) ?? 20;
        }
        notesJoursSources.add({
          'percent': noteMax > 0 ? noteValue / noteMax * 100 : 0.0,
        });
      }
    }

    if (notesJoursSources.isEmpty) {
      // Pas de notes scolaires → utiliser le score global
      final globalScore = provider.getWeeklyGlobalScore(childId);
      final baseMinutes = (globalScore / 20 * 180).round();
      final bonus = provider.getParentBonusMinutes(childId);
      return (baseMinutes + bonus).clamp(0, 180);
    }

    // Moyenne des notes sources
    final avgPercent = notesJoursSources.fold<double>(
            0, (s, n) => s + (n['percent'] as double)) /
        notesJoursSources.length;

    // Formule Option A : (moyenne en %) × 180 min
    final baseMinutes = (avgPercent / 100 * 180).round();
    final bonus = provider.getParentBonusMinutes(childId);
    return (baseMinutes + bonus).clamp(0, 180);
  }

  // ───────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<FamilyProvider>();
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AnimatedBackground(
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new_rounded,
                          color: Colors.white, size: 20),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const SizedBox(width: 4),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [
                          Color(0xFF7C4DFF),
                          Color(0xFFB388FF),
                        ]),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(Icons.tv_rounded,
                          color: Colors.white, size: 20),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("Temps d'écran",
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800)),
                          Text('Suivi & calcul automatique',
                              style: TextStyle(
                                  color: Colors.white54, fontSize: 12)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: TabBar(
                    controller: _tabController,
                    indicator: BoxDecoration(
                      color: const Color(0xFF7C4DFF),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    indicatorSize: TabBarIndicatorSize.tab,
                    dividerColor: Colors.transparent,
                    labelColor: Colors.white,
                    unselectedLabelColor: Colors.white54,
                    labelStyle: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 14),
                    tabs: const [
                      Tab(text: 'Vue globale'),
                      Tab(text: 'Par enfant'),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildGlobalView(provider, isDark),
                    _buildPerChildView(provider, isDark),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════
  //  VUE GLOBALE (inchangée)
  // ══════════════════════════════════════════════════════════════
  Widget _buildGlobalView(FamilyProvider provider, bool isDark) {
    if (provider.children.isEmpty) {
      return const Center(
          child: Text('Aucun enfant', style: TextStyle(color: Colors.white54)));
    }

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: provider.children.map((child) {
              final satMin = provider.getSaturdayMinutes(child.id);
              final sunMin = provider.getSundayMinutes(child.id);
              final totalMin = satMin + sunMin;
              const maxMin = 720;
              final progress = (totalMin / maxMin).clamp(0.0, 1.0);
              final color = _getProgressColor(progress);

              return Expanded(
                child: Column(
                  children: [
                    SizedBox(
                      width: 90,
                      height: 90,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          SizedBox(
                            width: 80,
                            height: 80,
                            child: CircularProgressIndicator(
                              value: progress,
                              strokeWidth: 8,
                              backgroundColor:
                                  Colors.white.withValues(alpha: 0.08),
                              valueColor: AlwaysStoppedAnimation(color),
                              strokeCap: StrokeCap.round,
                            ),
                          ),
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(_formatMinutes(totalMin),
                                  style: TextStyle(
                                      color: color,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 16)),
                              Text('/ ${_formatMinutes(maxMin)}',
                                  style: TextStyle(
                                      color:
                                          Colors.white.withValues(alpha: 0.3),
                                      fontSize: 9)),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(child.name,
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 13),
                        overflow: TextOverflow.ellipsis),
                  ],
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 24),
          const Text('Samedi vs Dimanche',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text('Comparaison par enfant',
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.4), fontSize: 12)),
          const SizedBox(height: 16),
          SizedBox(
            height: 220,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: 360,
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    tooltipPadding: const EdgeInsets.all(8),
                    tooltipMargin: 8,
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      final child = provider.children[groupIndex];
                      final label = rodIndex == 0 ? 'Sam' : 'Dim';
                      return BarTooltipItem(
                        '${child.name}\n$label: ${_formatMinutes(rod.toY.toInt())}',
                        const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 12),
                      );
                    },
                  ),
                ),
                titlesData: FlTitlesData(
                  show: true,
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        final idx = value.toInt();
                        if (idx >= 0 && idx < provider.children.length) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              provider.children[idx].name.length > 6
                                  ? '${provider.children[idx].name.substring(0, 6)}.'
                                  : provider.children[idx].name,
                              style: const TextStyle(
                                  color: Colors.white54, fontSize: 11),
                            ),
                          );
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 40,
                      getTitlesWidget: (value, meta) => Text(
                        _formatMinutes(value.toInt()),
                        style: const TextStyle(
                            color: Colors.white38, fontSize: 10),
                      ),
                      interval: 60,
                    ),
                  ),
                  topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                ),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: 60,
                  getDrawingHorizontalLine: (value) => FlLine(
                    color: Colors.white.withValues(alpha: 0.05),
                    strokeWidth: 1,
                  ),
                ),
                borderData: FlBorderData(show: false),
                barGroups: List.generate(provider.children.length, (i) {
                  final child = provider.children[i];
                  return BarChartGroupData(
                    x: i,
                    barRods: [
                      BarChartRodData(
                        toY: provider.getSaturdayMinutes(child.id).toDouble(),
                        color: const Color(0xFF7C4DFF),
                        width: 14,
                        borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(6)),
                      ),
                      BarChartRodData(
                        toY: provider.getSundayMinutes(child.id).toDouble(),
                        color: const Color(0xFFB388FF),
                        width: 14,
                        borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(6)),
                      ),
                    ],
                    barsSpace: 4,
                  );
                }),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                        color: const Color(0xFF7C4DFF),
                        borderRadius: BorderRadius.circular(3))),
                const SizedBox(width: 6),
                const Text('Samedi',
                    style: TextStyle(color: Colors.white54, fontSize: 12)),
                const SizedBox(width: 20),
                Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                        color: const Color(0xFFB388FF),
                        borderRadius: BorderRadius.circular(3))),
                const SizedBox(width: 6),
                const Text('Dimanche',
                    style: TextStyle(color: Colors.white54, fontSize: 12)),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Text('Classement',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          ...List.generate(provider.children.length, (i) {
            final sorted = List.of(provider.children)
              ..sort((a, b) {
                final totalA = provider.getSaturdayMinutes(a.id) +
                    provider.getSundayMinutes(a.id);
                final totalB = provider.getSaturdayMinutes(b.id) +
                    provider.getSundayMinutes(b.id);
                return totalA.compareTo(totalB);
              });
            final child = sorted[i];
            final total = provider.getSaturdayMinutes(child.id) +
                provider.getSundayMinutes(child.id);
            final progress = (total / 720).clamp(0.0, 1.0);
            final color = _getProgressColor(progress);
            final medal =
                i == 0 ? '🥇' : i == 1 ? '🥈' : i == 2 ? '🥉' : '${i + 1}';

            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: color.withValues(alpha: 0.2)),
              ),
              child: Row(
                children: [
                  Text(medal, style: const TextStyle(fontSize: 22)),
                  const SizedBox(width: 12),
                  if (child.hasPhoto)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.memory(base64Decode(child.photoBase64!),
                          width: 36, height: 36, fit: BoxFit.cover),
                    )
                  else
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10)),
                      child: Center(
                          child: Text(
                              child.avatar.isEmpty ? '👦' : child.avatar,
                              style: const TextStyle(fontSize: 18))),
                    ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(child.name,
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700)),
                        const SizedBox(height: 4),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: progress,
                            minHeight: 5,
                            backgroundColor:
                                Colors.white.withValues(alpha: 0.08),
                            valueColor: AlwaysStoppedAnimation(color),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(_formatMinutes(total),
                      style: TextStyle(
                          color: color,
                          fontWeight: FontWeight.w900,
                          fontSize: 15)),
                ],
              ),
            );
          }),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════
  //  VUE PAR ENFANT — enrichie
  // ══════════════════════════════════════════════════════════════
  Widget _buildPerChildView(FamilyProvider provider, bool isDark) {
    if (provider.children.isEmpty) {
      return const Center(
          child: Text('Aucun enfant', style: TextStyle(color: Colors.white54)));
    }

    _selectedChildId ??= provider.children.first.id;
    final child = provider.children.firstWhere(
      (c) => c.id == _selectedChildId,
      orElse: () => provider.children.first,
    );

    final satMin = provider.getSaturdayMinutes(child.id);
    final sunMin = provider.getSundayMinutes(child.id);
    final totalMin = satMin + sunMin;
    const maxMin = 720;
    final progress = (totalMin / maxMin).clamp(0.0, 1.0);
    final color = _getProgressColor(progress);

    // Scores semaine
    final schoolAvg = provider.getWeeklySchoolAverage(child.id);
    final behaviorScore = provider.getWeeklyBehaviorScore(child.id);
    final globalScore = provider.getWeeklyGlobalScore(child.id);
    final bonusMinutes = provider.getParentBonusMinutes(child.id);

    // Calcul temps d'écran pour le jour cible
    final tempsCalcule = _calculerTempsEcranPourJour(provider, child.id);

    // Notes
    final schoolNotes = _getSchoolNotes(provider, child.id);
    final behaviorNotes = _getBehaviorNotes(provider, child.id);

    // Immunités & punitions comme bonus
    final immunities = provider.getImmunitiesForChild(child.id);
    final immunityBonus = immunities
        .where((im) => im.isUsable)
        .fold<int>(0, (s, im) => s + im.availableLines);

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          // ── Sélecteur d'enfant ─────────────────────────
          SizedBox(
            height: 56,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: provider.children.map((c) {
                final isSelected = c.id == _selectedChildId;
                return GestureDetector(
                  onTap: () => setState(() => _selectedChildId = c.id),
                  child: Container(
                    margin: const EdgeInsets.only(right: 10),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? const Color(0xFF7C4DFF)
                          : Colors.white.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                          color: isSelected
                              ? const Color(0xFF7C4DFF)
                              : Colors.white.withValues(alpha: 0.1)),
                    ),
                    child: Row(
                      children: [
                        Text(c.avatar.isEmpty ? '👦' : c.avatar,
                            style: const TextStyle(fontSize: 20)),
                        const SizedBox(width: 8),
                        Text(c.name,
                            style: TextStyle(
                                color: isSelected
                                    ? Colors.white
                                    : Colors.white54,
                                fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 20),

          // ══════════════════════════════════════════════
          //  RÉSUMÉ DE LA SEMAINE
          // ══════════════════════════════════════════════
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF7C4DFF).withValues(alpha: 0.15),
                  const Color(0xFF00E676).withValues(alpha: 0.08),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                  color: const Color(0xFF7C4DFF).withValues(alpha: 0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF7C4DFF).withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.bar_chart_rounded,
                          color: Color(0xFFB388FF), size: 18),
                    ),
                    const SizedBox(width: 10),
                    const Text('Résumé de la semaine',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w700)),
                  ],
                ),
                const SizedBox(height: 16),
                // 3 scores en ligne
                Row(
                  children: [
                    Expanded(
                        child: _buildScoreCard(
                      '📚',
                      'Scolaire',
                      schoolAvg < 0
                          ? '--'
                          : '${schoolAvg.toStringAsFixed(1)}/20',
                      schoolAvg < 0
                          ? Colors.white38
                          : schoolAvg >= 10
                              ? Colors.greenAccent
                              : Colors.redAccent,
                    )),
                    const SizedBox(width: 8),
                    Expanded(
                        child: _buildScoreCard(
                      '🧠',
                      'Comportement',
                      '${behaviorScore.toStringAsFixed(1)}/20',
                      behaviorScore >= 10
                          ? Colors.greenAccent
                          : Colors.redAccent,
                    )),
                    const SizedBox(width: 8),
                    Expanded(
                        child: _buildScoreCard(
                      '⭐',
                      'Global',
                      '${globalScore.toStringAsFixed(1)}/20',
                      globalScore >= 10
                          ? Colors.amber
                          : Colors.orangeAccent,
                    )),
                  ],
                ),
                const SizedBox(height: 12),
                // Détail global
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.04),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      _buildDetailRow('📚 Moyenne scolaire',
                          schoolAvg < 0 ? 'Aucune note' : '${schoolAvg.toStringAsFixed(1)}/20',
                          schoolAvg < 0 ? Colors.white38 : schoolAvg >= 10 ? Colors.greenAccent : Colors.redAccent),
                      _buildDetailRow('🧠 Score comportement',
                          '${behaviorScore.toStringAsFixed(1)}/20',
                          behaviorScore >= 10 ? Colors.greenAccent : Colors.redAccent),
                      _buildDetailRow('🛡️ Lignes immunité dispo',
                          '$immunityBonus lignes',
                          Colors.cyanAccent),
                      _buildDetailRow('⏰ Bonus parent',
                          '+${_formatMinutes(bonusMinutes)}',
                          Colors.purpleAccent),
                      const Divider(color: Colors.white12, height: 16),
                      _buildDetailRow('⭐ Score global',
                          '${globalScore.toStringAsFixed(1)}/20',
                          Colors.amber,
                          bold: true),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ══════════════════════════════════════════════
          //  CALCULATEUR DE TEMPS D'ÉCRAN
          // ══════════════════════════════════════════════
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                  color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.orange.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.calculate_rounded,
                          color: Colors.orange, size: 18),
                    ),
                    const SizedBox(width: 10),
                    const Text('Calculer le temps d\'écran',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w700)),
                  ],
                ),
                const SizedBox(height: 16),

                // Sélecteur du jour CIBLE
                const Text('Jour à calculer :',
                    style: TextStyle(color: Colors.white70, fontSize: 13)),
                const SizedBox(height: 8),
                SizedBox(
                  height: 38,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _jours.length,
                    itemBuilder: (context, i) {
                      final isSelected = _jourCible == i;
                      // On ne peut cibler que des jours APRÈS les sources
                      final minSource = _joursSources.isNotEmpty
                          ? _joursSources.reduce((a, b) => a > b ? a : b)
                          : -1;
                      final isAvailable = i > minSource;
                      return GestureDetector(
                        onTap: isAvailable
                            ? () => setState(() {
                                  _jourCible = i;
                                  // Retirer les sources >= jour cible
                                  _joursSources
                                      .removeWhere((s) => s >= i);
                                })
                            : null,
                        child: Container(
                          margin: const EdgeInsets.only(right: 8),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? Colors.orange
                                : isAvailable
                                    ? Colors.white.withValues(alpha: 0.06)
                                    : Colors.white.withValues(alpha: 0.02),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                                color: isSelected
                                    ? Colors.orange
                                    : Colors.white.withValues(
                                        alpha: isAvailable ? 0.15 : 0.05)),
                          ),
                          child: Text(
                            _jours[i],
                            style: TextStyle(
                                color: isSelected
                                    ? Colors.white
                                    : isAvailable
                                        ? Colors.white70
                                        : Colors.white24,
                                fontSize: 12,
                                fontWeight: isSelected
                                    ? FontWeight.w700
                                    : FontWeight.w500),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 14),

                // Sélecteur des jours SOURCES
                const Text('Basé sur les notes de :',
                    style: TextStyle(color: Colors.white70, fontSize: 13)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: List.generate(_jourCible, (i) {
                    final isSelected = _joursSources.contains(i);
                    return GestureDetector(
                      onTap: () => setState(() {
                        if (isSelected) {
                          _joursSources.remove(i);
                        } else {
                          _joursSources.add(i);
                        }
                      }),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? const Color(0xFF7C4DFF).withValues(alpha: 0.25)
                              : Colors.white.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: isSelected
                                  ? const Color(0xFF7C4DFF)
                                  : Colors.white.withValues(alpha: 0.15)),
                        ),
                        child: Text(
                          _jours[i],
                          style: TextStyle(
                              color: isSelected
                                  ? Colors.white
                                  : Colors.white54,
                              fontSize: 12,
                              fontWeight: isSelected
                                  ? FontWeight.w700
                                  : FontWeight.w400),
                        ),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 16),

                // Résultat du calcul
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [
                      Colors.orange.withValues(alpha: 0.15),
                      Colors.deepOrange.withValues(alpha: 0.08),
                    ]),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                        color: Colors.orange.withValues(alpha: 0.3)),
                  ),
                  child: Column(
                    children: [
                      Text(
                        '${_jours[_jourCible]} :',
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 13),
                      ),
                      const SizedBox(height: 4),
                      TweenAnimationBuilder<int>(
                        key: ValueKey(tempsCalcule),
                        tween: IntTween(begin: 0, end: tempsCalcule),
                        duration: const Duration(milliseconds: 800),
                        curve: Curves.easeOutCubic,
                        builder: (context, val, _) => Text(
                          _formatMinutes(val),
                          style: TextStyle(
                              color: tempsCalcule >= 120
                                  ? Colors.greenAccent
                                  : tempsCalcule >= 60
                                      ? Colors.orange
                                      : Colors.redAccent,
                              fontSize: 42,
                              fontWeight: FontWeight.w900),
                        ),
                      ),
                      Text(
                        'sur 3h maximum',
                        style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.4),
                            fontSize: 12),
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                          value: (tempsCalcule / 180).clamp(0.0, 1.0),
                          minHeight: 8,
                          backgroundColor:
                              Colors.white.withValues(alpha: 0.08),
                          valueColor: AlwaysStoppedAnimation(
                            tempsCalcule >= 120
                                ? Colors.greenAccent
                                : tempsCalcule >= 60
                                    ? Colors.orange
                                    : Colors.redAccent,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      // Détail du calcul
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.04),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Détail du calcul :',
                                style: TextStyle(
                                    color:
                                        Colors.white.withValues(alpha: 0.5),
                                    fontSize: 11)),
                            const SizedBox(height: 6),
                            Text(
                              '(Moy. notes ${_joursSources.isEmpty ? "semaine" : _joursSources.map((i) => _jours[i]).join(" + ")} ÷ 100) × 180 min'
                              '${bonusMinutes > 0 ? " + ${_formatMinutes(bonusMinutes)} bonus" : ""}',
                              style: const TextStyle(
                                  color: Colors.white54, fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ── Cercle temps d'écran semaine (inchangé) ────
          SizedBox(
            width: 180,
            height: 180,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 170,
                  height: 170,
                  child: CircularProgressIndicator(
                    value: progress,
                    strokeWidth: 14,
                    backgroundColor: Colors.white.withValues(alpha: 0.06),
                    valueColor: AlwaysStoppedAnimation(color),
                    strokeCap: StrokeCap.round,
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(child.avatar.isEmpty ? '👦' : child.avatar,
                        style: const TextStyle(fontSize: 28)),
                    const SizedBox(height: 4),
                    Text(_formatMinutes(totalMin),
                        style: TextStyle(
                            color: color,
                            fontWeight: FontWeight.w900,
                            fontSize: 28)),
                    Text('sur ${_formatMinutes(maxMin)}',
                        style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.4),
                            fontSize: 12)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // ── Samedi / Dimanche (inchangé) ───────────────
          Row(
            children: [
              Expanded(
                child: _buildDayCard(
                    '📅', 'Samedi', satMin, 360, const Color(0xFF7C4DFF)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildDayCard(
                    '🌞', 'Dimanche', sunMin, 360, const Color(0xFFB388FF)),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // ── Statistiques (inchangé) ────────────────────
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(16),
              border:
                  Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Statistiques week-end',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 16),
                _buildStatRow('Temps total', _formatMinutes(totalMin), color),
                _buildStatRow('Moyenne par jour',
                    _formatMinutes(totalMin ~/ 2), const Color(0xFF448AFF)),
                _buildStatRow('Jour le plus élevé',
                    satMin >= sunMin ? 'Samedi' : 'Dimanche', Colors.orange),
                _buildStatRow('Temps restant',
                    _formatMinutes((maxMin - totalMin).clamp(0, maxMin)),
                    const Color(0xFF00E676)),
                _buildStatRow('Utilisation',
                    '${(progress * 100).toStringAsFixed(0)}%', color),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // ── Message bilan (inchangé) ───────────────────
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: color.withValues(alpha: 0.2)),
            ),
            child: Column(
              children: [
                Icon(
                  progress <= 0.5
                      ? Icons.sentiment_satisfied_alt_rounded
                      : progress <= 0.75
                          ? Icons.sentiment_neutral_rounded
                          : Icons.sentiment_dissatisfied_rounded,
                  color: color,
                  size: 40,
                ),
                const SizedBox(height: 8),
                Text(
                  progress <= 0.25
                      ? 'Très bien ! Peu de temps d\'écran.'
                      : progress <= 0.5
                          ? 'Correct, dans la moyenne.'
                          : progress <= 0.75
                              ? 'Attention, beaucoup de temps d\'écran.'
                              : 'Limite presque atteinte !',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.w600,
                      fontSize: 14),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // ══════════════════════════════════════════════
          //  NOTES RÉCENTES — comportementales EN AVANT
          // ══════════════════════════════════════════════
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(18),
              border:
                  Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.purple.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.psychology_rounded,
                          color: Colors.purpleAccent, size: 18),
                    ),
                    const SizedBox(width: 10),
                    const Text('Notes comportementales récentes',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w700)),
                  ],
                ),
                const SizedBox(height: 12),
                if (behaviorNotes.isEmpty)
                  _emptyNotesWidget('Aucune note comportementale',
                      Icons.psychology_outlined)
                else
                  ...behaviorNotes.take(5).map((n) {
                    final pts = n['points'] as int;
                    final isPos = pts >= 0;
                    final c = isPos ? Colors.greenAccent : Colors.redAccent;
                    final date = n['date'] as DateTime;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: c.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: c.withValues(alpha: 0.2)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: c.withValues(alpha: 0.15)),
                            child: Center(
                                child: Text(
                                    isPos ? '+$pts' : '$pts',
                                    style: TextStyle(
                                        color: c,
                                        fontWeight: FontWeight.w900,
                                        fontSize: 12))),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                              child: Text(n['subject'] as String,
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500),
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 2)),
                          Text(
                              '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}',
                              style: const TextStyle(
                                  color: Colors.white38, fontSize: 11)),
                        ],
                      ),
                    );
                  }),

                const SizedBox(height: 16),
                // Notes scolaires — en dessous, plus petites
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.orange.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.menu_book_rounded,
                          color: Colors.orangeAccent, size: 18),
                    ),
                    const SizedBox(width: 10),
                    const Text('Notes scolaires récentes',
                        style: TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                            fontWeight: FontWeight.w600)),
                    const Spacer(),
                    if (schoolNotes.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.orange.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'Moy. ${(schoolNotes.fold<double>(0, (s, n) => s + (n['percent'] as double)) / schoolNotes.length).round()}%',
                          style: const TextStyle(
                              color: Colors.orangeAccent,
                              fontSize: 11,
                              fontWeight: FontWeight.w700),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                if (schoolNotes.isEmpty)
                  _emptyNotesWidget(
                      'Aucune note scolaire', Icons.school_outlined)
                else
                  ...schoolNotes.take(4).map((note) {
                    final percent = note['percent'] as double;
                    final isGood = percent >= 50;
                    final nc = isGood ? Colors.greenAccent : Colors.redAccent;
                    final stars = _percentToStars(percent);
                    final date = note['date'] as DateTime;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: nc.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: nc.withValues(alpha: 0.15)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: nc.withValues(alpha: 0.1)),
                            child: Center(
                                child: Text('${percent.round()}%',
                                    style: TextStyle(
                                        color: nc,
                                        fontWeight: FontWeight.w900,
                                        fontSize: 10))),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(note['subject'] as String,
                                    style: const TextStyle(
                                        color: Colors.white70,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500),
                                    overflow: TextOverflow.ellipsis),
                                Row(
                                    children: List.generate(
                                        stars,
                                        (i) => const Text('⭐',
                                            style:
                                                TextStyle(fontSize: 9)))),
                              ],
                            ),
                          ),
                          Text(
                              '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}',
                              style: const TextStyle(
                                  color: Colors.white38, fontSize: 11)),
                        ],
                      ),
                    );
                  }),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  // ── Widgets helpers ─────────────────────────────────────────

  Widget _buildScoreCard(
      String emoji, String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 20)),
          const SizedBox(height: 4),
          Text(value,
              style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w900,
                  fontSize: 14)),
          const SizedBox(height: 2),
          Text(label,
              style: const TextStyle(color: Colors.white54, fontSize: 10),
              textAlign: TextAlign.center),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, Color color,
      {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
              child: Text(label,
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.6),
                      fontSize: 12))),
          Text(value,
              style: TextStyle(
                  color: color,
                  fontWeight: bold ? FontWeight.w900 : FontWeight.w600,
                  fontSize: bold ? 14 : 12)),
        ],
      ),
    );
  }

  Widget _emptyNotesWidget(String text, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: Colors.white24, size: 20),
          const SizedBox(width: 8),
          Text(text,
              style: const TextStyle(color: Colors.white38, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildDayCard(
      String emoji, String label, int minutes, int max, Color color) {
    final progress = (minutes / max).clamp(0.0, 1.0);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 28)),
          const SizedBox(height: 8),
          Text(label,
              style: const TextStyle(
                  color: Colors.white70,
                  fontWeight: FontWeight.w600,
                  fontSize: 13)),
          const SizedBox(height: 8),
          Text(_formatMinutes(minutes),
              style: TextStyle(
                  color: color, fontWeight: FontWeight.w900, fontSize: 22)),
          const SizedBox(height: 4),
          Text('/ ${_formatMinutes(max)}',
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.3), fontSize: 11)),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              backgroundColor: Colors.white.withValues(alpha: 0.08),
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatRow(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
              width: 8,
              height: 8,
              decoration:
                  BoxDecoration(shape: BoxShape.circle, color: color)),
          const SizedBox(width: 10),
          Text(label,
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.6), fontSize: 13)),
          const Spacer(),
          Text(value,
              style: TextStyle(
                  color: color, fontWeight: FontWeight.w700, fontSize: 14)),
        ],
      ),
    );
  }
}
