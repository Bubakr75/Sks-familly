// lib/screens/weekly_report_screen.dart
//
// 📊 Rapport Hebdomadaire — récap des 7 derniers jours par enfant.
// Montre bonus, pénalités, évolution, classement de la semaine.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/family_provider.dart';
import '../models/child_model.dart';
import '../models/history_entry.dart';
import '../config/emerald_theme.dart';

class WeeklyReportScreen extends StatelessWidget {
  const WeeklyReportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final fp = context.watch<FamilyProvider>();
    final children = fp.children;

    // Période : 7 derniers jours
    final now = DateTime.now();
    final weekStart = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 6));
    final weekEnd = DateTime(now.year, now.month, now.day, 23, 59, 59);

    // Filtrer l'historique de la semaine
    final weekHistory = fp.history.where((h) =>
        h.date.isAfter(weekStart.subtract(const Duration(seconds: 1))) &&
        h.date.isBefore(weekEnd.add(const Duration(seconds: 1)))).toList();

    // Calculer par enfant
    final childStats = <_ChildWeekStat>[];
    for (final child in children) {
      final entries = weekHistory.where((h) => h.childId == child.id).toList();
      final bonuses = entries.where((h) => h.isBonus).toList();
      final penalties = entries.where((h) => !h.isBonus).toList();
      final totalBonus = bonuses.fold(0, (s, h) => s + h.points);
      final totalPenalty = penalties.fold(0, (s, h) => s + h.points);
      final net = totalBonus - totalPenalty;
      final bestDay = _findBestDay(entries);

      childStats.add(_ChildWeekStat(
        child: child,
        bonusCount: bonuses.length,
        penaltyCount: penalties.length,
        totalBonus: totalBonus,
        totalPenalty: totalPenalty,
        net: net,
        bestDay: bestDay,
        totalActions: entries.length,
      ));
    }

    // Trier par points nets de la semaine
    childStats.sort((a, b) => b.net.compareTo(a.net));

    return Scaffold(
      backgroundColor: EmeraldPalette.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text('📊 Rapport de la semaine',
            style: TextStyle(color: EmeraldPalette.textPrimary, fontWeight: FontWeight.bold)),
        iconTheme: const IconThemeData(color: EmeraldPalette.textPrimary),
      ),
      body: childStats.isEmpty
          ? const Center(child: Text('Aucun enfant', style: TextStyle(color: Colors.white54)))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // ── Période ──
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: EmeraldPalette.surfaceLow,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: EmeraldPalette.glassBorder),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.date_range_rounded, color: EmeraldPalette.emeraldLight, size: 18),
                      const SizedBox(width: 8),
                      Text(
                        '${_formatDate(weekStart)} → ${_formatDate(weekEnd)}',
                        style: const TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // ── Podium de la semaine ──
                if (childStats.length >= 1)
                  _WeeklyPodium(stats: childStats),

                const SizedBox(height: 16),

                // ── Carte par enfant ──
                ...childStats.map((s) => _ChildWeekCard(stat: s)),

                // ── Résumé famille ──
                if (childStats.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  _FamilySummary(stats: childStats),
                ],
              ],
            ),
    );
  }

  /// Trouve le meilleur jour de la semaine (le plus de points nets)
  _BestDay? _findBestDay(List<HistoryEntry> entries) {
    if (entries.isEmpty) return null;
    final byDay = <String, int>{};
    for (final h in entries) {
      final dayKey = '${h.date.day}/${h.date.month}';
      final pts = h.isBonus ? h.points : -h.points;
      byDay[dayKey] = (byDay[dayKey] ?? 0) + pts;
    }
    final sorted = byDay.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    if (sorted.isEmpty) return null;
    return _BestDay(day: sorted.first.key, points: sorted.first.value);
  }

  String _formatDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}';
}

// ─── Podium de la semaine ──────────────────────────────────────
class _WeeklyPodium extends StatelessWidget {
  final List<_ChildWeekStat> stats;
  const _WeeklyPodium({required this.stats});

  @override
  Widget build(BuildContext context) {
    final colors = [EmeraldPalette.gold, Colors.grey.shade300, Colors.orange.shade700];
    final medals = ['🥇', '🥈', '🥉'];

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        // 2e place
        if (stats.length >= 2) _PodiumColumn(stat: stats[1], medal: medals[1], color: colors[1], height: 90),
        // 1er place (plus grand)
        _PodiumColumn(stat: stats[0], medal: medals[0], color: colors[0], height: 120),
        // 3e place
        if (stats.length >= 3) _PodiumColumn(stat: stats[2], medal: medals[2], color: colors[2], height: 70),
      ],
    );
  }
}

class _PodiumColumn extends StatelessWidget {
  final _ChildWeekStat stat;
  final String medal;
  final Color color;
  final double height;

  const _PodiumColumn({required this.stat, required this.medal, required this.color, required this.height});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 6),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Text(medal, style: const TextStyle(fontSize: 32)),
          const SizedBox(height: 4),
          Text(stat.child.avatar.isNotEmpty ? stat.child.avatar : '👤', style: const TextStyle(fontSize: 28)),
          const SizedBox(height: 4),
          Text(stat.child.name, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
          Text('+${stat.net}', style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          Container(
            width: 80,
            height: height,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [color.withValues(alpha: 0.25), color.withValues(alpha: 0.05)],
              ),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
              border: Border.all(color: color.withValues(alpha: 0.4)),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Carte détaillée par enfant ────────────────────────────────
class _ChildWeekCard extends StatelessWidget {
  final _ChildWeekStat stat;
  const _ChildWeekCard({required this.stat});

  @override
  Widget build(BuildContext context) {
    final accent = stat.net >= 0 ? EmeraldPalette.emerald : Colors.redAccent;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: EmeraldPalette.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: accent.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Text(stat.child.avatar.isNotEmpty ? stat.child.avatar : '👤', style: const TextStyle(fontSize: 28)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(stat.child.name,
                    style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: accent.withValues(alpha: 0.4)),
                ),
                child: Text(
                  '${stat.net >= 0 ? '+' : ''}${stat.net} pts',
                  style: TextStyle(color: accent, fontSize: 16, fontWeight: FontWeight.w900),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Stats
          Row(
            children: [
              Expanded(
                child: _MiniStat(
                  icon: Icons.add_circle_rounded,
                  label: 'Bonus',
                  value: '${stat.bonusCount}',
                  sub: '+${stat.totalBonus}',
                  color: EmeraldPalette.emeraldLight,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _MiniStat(
                  icon: Icons.remove_circle_rounded,
                  label: 'Pénalités',
                  value: '${stat.penaltyCount}',
                  sub: '-${stat.totalPenalty}',
                  color: Colors.redAccent,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _MiniStat(
                  icon: Icons.event_rounded,
                  label: 'Meilleur jour',
                  value: stat.bestDay?.day ?? '—',
                  sub: stat.bestDay != null ? '${stat.bestDay!.points >= 0 ? '+' : ''}${stat.bestDay!.points}' : '',
                  color: EmeraldPalette.gold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String sub;
  final Color color;

  const _MiniStat({required this.icon, required this.label, required this.value, required this.sub, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        color: EmeraldPalette.surfaceLow,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(height: 4),
          Text(value, style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.w800)),
          if (sub.isNotEmpty) Text(sub, style: TextStyle(color: color.withValues(alpha: 0.7), fontSize: 11)),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(color: Colors.white38, fontSize: 9), textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

// ─── Résumé famille ────────────────────────────────────────────
class _FamilySummary extends StatelessWidget {
  final List<_ChildWeekStat> stats;
  const _FamilySummary({required this.stats});

  @override
  Widget build(BuildContext context) {
    final totalBonus = stats.fold(0, (s, c) => s + c.totalBonus);
    final totalPenalty = stats.fold(0, (s, c) => s + c.totalPenalty);
    final totalActions = stats.fold(0, (s, c) => s + c.totalActions);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [
          EmeraldPalette.emerald.withValues(alpha: 0.15),
          Colors.transparent,
        ]),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: EmeraldPalette.emerald.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          const Text('🏠 Résumé de la famille',
              style: TextStyle(color: EmeraldPalette.emeraldLight, fontSize: 16, fontWeight: FontWeight.w800)),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _BigStat(value: '+$totalBonus', label: 'Total bonus', color: EmeraldPalette.emeraldLight),
              _BigStat(value: '-$totalPenalty', label: 'Total pénalités', color: Colors.redAccent),
              _BigStat(value: '$totalActions', label: 'Actions', color: EmeraldPalette.gold),
            ],
          ),
        ],
      ),
    );
  }
}

class _BigStat extends StatelessWidget {
  final String value;
  final String label;
  final Color color;

  const _BigStat({required this.value, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value, style: TextStyle(color: color, fontSize: 24, fontWeight: FontWeight.w900)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(color: Colors.white54, fontSize: 11)),
      ],
    );
  }
}

// ─── Modèles de données ────────────────────────────────────────
class _ChildWeekStat {
  final ChildModel child;
  final int bonusCount;
  final int penaltyCount;
  final int totalBonus;
  final int totalPenalty;
  final int net;
  final _BestDay? bestDay;
  final int totalActions;

  _ChildWeekStat({
    required this.child,
    required this.bonusCount,
    required this.penaltyCount,
    required this.totalBonus,
    required this.totalPenalty,
    required this.net,
    required this.bestDay,
    required this.totalActions,
  });
}

class _BestDay {
  final String day;
  final int points;
  _BestDay({required this.day, required this.points});
}
