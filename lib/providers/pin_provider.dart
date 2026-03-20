import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/family_provider.dart';
import '../providers/pin_provider.dart';
import '../models/child_model.dart';
import '../models/history_entry.dart';
import '../models/punishment_lines.dart';

class ChildDashboardScreen extends StatefulWidget {
  final String childId;
  const ChildDashboardScreen({super.key, required this.childId});
  @override
  State<ChildDashboardScreen> createState() => _ChildDashboardScreenState();
}

class _ChildDashboardScreenState extends State<ChildDashboardScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _parentBonusMinutes = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  static int _getScreenMinutesForGrade(double grade) {
    if (grade >= 18) return 45;
    if (grade >= 16) return 35;
    if (grade >= 14) return 25;
    if (grade >= 12) return 20;
    if (grade >= 10) return 15;
    if (grade >= 8) return 5;
    return 0;
  }

  Map<String, dynamic> _calculateScreenTime(FamilyProvider provider) {
    final now = DateTime.now();
    final monday = now.subtract(Duration(days: now.weekday - 1));
    int totalMinutes = 0;
    final List<Map<String, dynamic>> dailyBreakdown = [];
    final dayNames = ['Lundi', 'Mardi', 'Mercredi', 'Jeudi', 'Vendredi'];

    for (int i = 0; i < 5; i++) {
      final day = DateTime(monday.year, monday.month, monday.day + i);
      final dayHistory = provider.history.where((h) =>
          h.childId == widget.childId &&
          h.category == 'school_note' &&
          h.date.year == day.year &&
          h.date.month == day.month &&
          h.date.day == day.day).toList();

      int dayMinutes = 0;
      double? grade;

      if (dayHistory.isNotEmpty) {
        final reason = dayHistory.last.reason;
        final match = RegExp(r'Note: ([\d.]+)/20').firstMatch(reason);
        if (match != null) {
          grade = double.tryParse(match.group(1)!);
          if (grade != null) dayMinutes = _getScreenMinutesForGrade(grade);
        }
      }

      totalMinutes += dayMinutes;
      dailyBreakdown.add({
        'day': dayNames[i],
        'grade': grade,
        'minutes': dayMinutes,
        'hasNote': grade != null,
      });
    }

    totalMinutes += _parentBonusMinutes;
    const maxWeekendTotal = 360;
    totalMinutes = totalMinutes.clamp(0, maxWeekendTotal);

    final saturdayMinutes = totalMinutes > 180 ? 180 : totalMinutes;
    final sundayMinutes = totalMinutes > 180 ? (totalMinutes - 180).clamp(0, 180) : 0;

    return {
      'totalMinutes': totalMinutes,
      'saturdayMinutes': saturdayMinutes,
      'sundayMinutes': sundayMinutes,
      'maxMinutes': maxWeekendTotal,
      'breakdown': dailyBreakdown,
      'parentBonus': _parentBonusMinutes,
    };
  }

  String _formatMinutes(int minutes) {
    final h = minutes ~/ 60;
    final m = minutes % 60;
    if (h == 0) return '${m}min';
    if (m == 0) return '${h}h';
    return '${h}h${m.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<FamilyProvider>(
      builder: (context, provider, _) {
        final child = provider.children.firstWhere(
          (c) => c.id == widget.childId,
          orElse: () => ChildModel(id: '', name: 'Inconnu'),
        );
        final history = provider.history
            .where((h) => h.childId == widget.childId)
            .toList()
          ..sort((a, b) => b.date.compareTo(a.date));
        final punishments = provider.punishments
            .where((p) => p.childId == widget.childId)
            .toList();
        final weekNotes = _getWeekNotes(provider);
        final screenTime = _calculateScreenTime(provider);

        return Scaffold(
          backgroundColor: const Color(0xFF0A0E21),
          body: Stack(
            children: [
              if (child.hasPhoto)
                Positioned.fill(
                  child: Image.memory(
                    base64Decode(child.photoBase64),
                    fit: BoxFit.cover,
                    gaplessPlayback: true,
                    errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                  ),
                ),
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.5),
                        Colors.black.withValues(alpha: 0.75),
                        Colors.black.withValues(alpha: 0.92),
                      ],
                      stops: const [0.0, 0.3, 0.6],
                    ),
                  ),
                ),
              ),
              SafeArea(
                child: NestedScrollView(
                  headerSliverBuilder: (context, innerBoxIsScrolled) {
                    return [
                      SliverToBoxAdapter(child: _buildCompactHeader(child)),
                      if (weekNotes.isNotEmpty)
                        SliverToBoxAdapter(child: _buildWeekNotes(weekNotes)),
                      SliverToBoxAdapter(child: _buildScreenTimeCard(screenTime, provider)),
                      SliverToBoxAdapter(child: _buildTabBar()),
                    ];
                  },
                  body: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildOverviewTab(child, history),
                      _buildBadgesTab(child, provider),
                      _buildHistoryTab(history),
                      _buildPunishmentsTab(punishments),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
  Widget _buildScreenTimeCard(Map<String, dynamic> screenTime, FamilyProvider provider) {
    final total = screenTime['totalMinutes'] as int;
    final satMin = screenTime['saturdayMinutes'] as int;
    final sunMin = screenTime['sundayMinutes'] as int;
    final maxMin = screenTime['maxMinutes'] as int;
    final breakdown = screenTime['breakdown'] as List<Map<String, dynamic>>;
    final bonus = screenTime['parentBonus'] as int;
    final progress = maxMin > 0 ? (total / maxMin).clamp(0.0, 1.0) : 0.0;
    final isParent = context.watch<PinProvider>().isParentMode;

    Color barColor;
    if (progress >= 0.8) barColor = const Color(0xFF00E676);
    else if (progress >= 0.5) barColor = Colors.orange;
    else barColor = const Color(0xFFFF1744);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E).withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF7C4DFF).withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF7C4DFF).withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.tv_rounded, color: Color(0xFFB388FF), size: 20),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text('Temps d\'ecran week-end',
                  style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: barColor.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: barColor.withValues(alpha: 0.5)),
                ),
                child: Text(_formatMinutes(total),
                  style: TextStyle(color: barColor, fontWeight: FontWeight.w900, fontSize: 16)),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 10,
              backgroundColor: Colors.white.withValues(alpha: 0.1),
              valueColor: AlwaysStoppedAnimation(barColor),
            ),
          ),
          const SizedBox(height: 6),
          Text('${_formatMinutes(total)} / ${_formatMinutes(maxMin)} maximum',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 11)),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(child: _screenTimeDayBox('\u{1F4C5} Samedi', satMin, const Color(0xFF448AFF))),
              const SizedBox(width: 8),
              Expanded(child: _screenTimeDayBox('\u{1F31E} Dimanche', sunMin, const Color(0xFFFF9100))),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Detail par jour :', style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                ...breakdown.map((d) {
                  final hasNote = d['hasNote'] as bool;
                  final grade = d['grade'] as double?;
                  final min = d['minutes'] as int;
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(
                      children: [
                        SizedBox(width: 70, child: Text(d['day'] as String,
                          style: const TextStyle(color: Colors.white60, fontSize: 12))),
                        if (hasNote && grade != null) ...[
                          Text('${grade.toStringAsFixed(grade == grade.roundToDouble() ? 0 : 1)}/20',
                            style: TextStyle(color: _gradeColor(grade), fontSize: 12, fontWeight: FontWeight.w700)),
                          const SizedBox(width: 10),
                          const Icon(Icons.arrow_forward_rounded, size: 12, color: Colors.white30),
                          const SizedBox(width: 10),
                          Text('+${min}min', style: const TextStyle(color: Color(0xFF00E676), fontSize: 12, fontWeight: FontWeight.w700)),
                        ] else
                          const Text('Pas de note', style: TextStyle(color: Colors.white30, fontSize: 12)),
                      ],
                    ),
                  );
                }),
                if (bonus != 0) ...[
                  const SizedBox(height: 6),
                  Divider(color: Colors.white.withValues(alpha: 0.1), height: 1),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const SizedBox(width: 70, child: Text('Parent', style: TextStyle(color: Colors.white60, fontSize: 12))),
                      Text('${bonus >= 0 ? '+' : ''}${bonus}min',
                        style: TextStyle(
                          color: bonus >= 0 ? const Color(0xFF00E676) : const Color(0xFFFF1744),
                          fontSize: 12, fontWeight: FontWeight.w700)),
                    ],
                  ),
                ],
              ],
            ),
          ),
          if (isParent) ...[
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _adjustButton(Icons.remove, const Color(0xFFFF1744), () {
                  setState(() => _parentBonusMinutes -= 15);
                }),
                const SizedBox(width: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    bonus == 0 ? 'Ajuster le temps' : '${bonus >= 0 ? '+' : ''}${bonus}min',
                    style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ),
                const SizedBox(width: 16),
                _adjustButton(Icons.add, const Color(0xFF00E676), () {
                  setState(() => _parentBonusMinutes += 15);
                }),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _screenTimeDayBox(String label, int minutes, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Column(
        children: [
          Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Text(_formatMinutes(minutes), style: TextStyle(color: color, fontSize: 22, fontWeight: FontWeight.w900)),
          const SizedBox(height: 2),
          Text('/ 3h max', style: TextStyle(color: Colors.white.withValues(alpha: 0.35), fontSize: 10)),
        ],
      ),
    );
  }

  Widget _adjustButton(IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          shape: BoxShape.circle,
          border: Border.all(color: color.withValues(alpha: 0.4)),
        ),
        child: Icon(icon, color: color, size: 20),
      ),
    );
  }

  Color _gradeColor(double grade) {
    if (grade >= 16) return const Color(0xFF00E676);
    if (grade >= 12) return const Color(0xFF448AFF);
    if (grade >= 10) return Colors.orange;
    return const Color(0xFFFF1744);
  }

  List<Map<String, dynamic>> _getWeekNotes(FamilyProvider provider) {
    final now = DateTime.now();
    final monday = now.subtract(Duration(days: now.weekday - 1));
    final dayNames = ['Lundi', 'Mardi', 'Mercredi', 'Jeudi', 'Vendredi'];
    final List<Map<String, dynamic>> notes = [];
    for (int i = 0; i < 5; i++) {
      final day = DateTime(monday.year, monday.month, monday.day + i);
      final dayHistory = provider.history.where((h) =>
          h.childId == widget.childId &&
          h.category == 'school_note' &&
          h.date.year == day.year &&
          h.date.month == day.month &&
          h.date.day == day.day).toList();
      final bool isToday = day.year == now.year && day.month == now.month && day.day == now.day;
      final bool isFuture = day.isAfter(now);
      if (dayHistory.isNotEmpty) {
        final reason = dayHistory.last.reason;
        final match = RegExp(r'Note: ([\d.]+)/20').firstMatch(reason);
        if (match != null) {
          final grade = double.tryParse(match.group(1)!);
          if (grade != null) {
            notes.add({'day': dayNames[i], 'grade': grade, 'isToday': isToday, 'hasNote': true, 'isFuture': false});
            continue;
          }
        }
      }
      notes.add({'day': dayNames[i], 'grade': null, 'isToday': isToday, 'hasNote': false, 'isFuture': isFuture});
    }
    return notes;
  }
  Widget _buildCompactHeader(ChildModel child) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Column(
        children: [
          Row(children: [
            IconButton(icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 20), onPressed: () => Navigator.pop(context)),
            const Spacer(),
            Text('Mode Enfant', style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 14, fontWeight: FontWeight.w500)),
            const Spacer(),
            const SizedBox(width: 48),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            Container(
              width: 70, height: 70,
              decoration: BoxDecoration(shape: BoxShape.circle,
                border: Border.all(color: Colors.amber.withValues(alpha: 0.6), width: 2.5),
                boxShadow: [BoxShadow(color: Colors.amber.withValues(alpha: 0.3), blurRadius: 16)]),
              child: ClipOval(
                child: child.hasPhoto
                    ? Image.memory(base64Decode(child.photoBase64), fit: BoxFit.cover, width: 70, height: 70, gaplessPlayback: true,
                        errorBuilder: (_, __, ___) => _avatarFallback(child, 70))
                    : _avatarFallback(child, 70),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(child.name, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold, shadows: [Shadow(color: Colors.black54, blurRadius: 4)])),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: Colors.amber.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.amber.withValues(alpha: 0.4))),
                child: Text(child.levelTitle, style: TextStyle(color: Colors.amber.shade300, fontSize: 12, fontWeight: FontWeight.w700)),
              ),
              const SizedBox(height: 8),
              ClipRRect(borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(value: child.levelProgress, minHeight: 7,
                  backgroundColor: Colors.white.withValues(alpha: 0.15), valueColor: AlwaysStoppedAnimation<Color>(Colors.amber.shade400))),
              const SizedBox(height: 3),
              Text(child.isMaxLevel ? '\u{1F381} Niveau MAX !' : '${child.points} / ${child.nextLevelPoints} pts',
                style: TextStyle(color: child.isMaxLevel ? Colors.amber.shade300 : Colors.white.withValues(alpha: 0.6), fontSize: 11, fontWeight: FontWeight.w500)),
            ])),
          ]),
          const SizedBox(height: 14),
          Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
            _buildMiniStat(Icons.star, '${child.points}', 'Points', Colors.amber),
            _buildMiniStat(Icons.trending_up, child.levelTitle, 'Niveau', Colors.greenAccent),
            _buildMiniStat(Icons.emoji_events, '${child.badgeIds.length}', 'Badges', Colors.purpleAccent),
          ]),
        ],
      ),
    );
  }

  Widget _buildMiniStat(IconData icon, String value, String label, Color color) {
    return Column(children: [
      Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: color.withValues(alpha: 0.2), shape: BoxShape.circle),
        child: Icon(icon, color: color, size: 18)),
      const SizedBox(height: 4),
      Text(value, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 14)),
      Text(label, style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 10)),
    ]);
  }

  Widget _avatarFallback(ChildModel child, double size) {
    return Container(width: size, height: size, color: Colors.white.withValues(alpha: 0.25),
      child: Center(child: Text(child.avatar.isNotEmpty ? child.avatar : child.name.isNotEmpty ? child.name[0].toUpperCase() : '?',
        style: TextStyle(fontSize: size * 0.45))));
  }

  Widget _buildWeekNotes(List<Map<String, dynamic>> notes) {
    final notesWithGrades = notes.where((n) => n['hasNote'] == true).toList();
    if (notesWithGrades.isEmpty) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E).withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF448AFF).withValues(alpha: 0.4)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Row(children: [
          Icon(Icons.school_rounded, color: Color(0xFF64B5F6), size: 16), SizedBox(width: 6),
          Text('Notes de la semaine', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
        ]),
        const SizedBox(height: 8),
        Row(children: notes.map((n) {
          final hasNote = n['hasNote'] as bool;
          final isToday = n['isToday'] as bool;
          final isFuture = n['isFuture'] as bool;
          final grade = n['grade'] as double?;
          Color color = Colors.grey;
          if (hasNote && grade != null) {
            if (grade >= 16) color = const Color(0xFF00E676);
            else if (grade >= 12) color = const Color(0xFF448AFF);
            else if (grade >= 10) color = Colors.orange;
            else color = const Color(0xFFFF1744);
          }
          return Expanded(child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 2), padding: const EdgeInsets.symmetric(vertical: 6),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(8),
              color: isToday && hasNote ? color.withValues(alpha: 0.25) : isToday ? const Color(0xFF448AFF).withValues(alpha: 0.15) : Colors.white.withValues(alpha: 0.06),
              border: isToday ? Border.all(color: const Color(0xFF448AFF).withValues(alpha: 0.6), width: 1.5) : null),
            child: Column(children: [
              Text((n['day'] as String).substring(0, 3), style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 9, fontWeight: FontWeight.w600)),
              const SizedBox(height: 3),
              if (hasNote && grade != null) ...[
                Text(grade.toStringAsFixed(grade == grade.roundToDouble() ? 0 : 1),
                  style: TextStyle(color: color, fontSize: 14, fontWeight: FontWeight.w900)),
                Text('/20', style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 8)),
              ] else if (isFuture)
                Padding(padding: const EdgeInsets.symmetric(vertical: 5),
                  child: Text('-', style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.2))))
              else if (isToday)
                Padding(padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Container(width: 8, height: 8, decoration: BoxDecoration(shape: BoxShape.circle, color: const Color(0xFF448AFF).withValues(alpha: 0.6))))
              else
                Padding(padding: const EdgeInsets.symmetric(vertical: 5),
                  child: Text('-', style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.25)))),
            ]),
          ));
        }).toList()),
      ]),
    );
  }

  Widget _buildTabBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E).withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(12),
      ),
      child: TabBar(controller: _tabController,
        indicator: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(12)),
        labelColor: Colors.white, unselectedLabelColor: Colors.white60,
        labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700), dividerHeight: 0,
        tabs: const [Tab(text: 'Resume'), Tab(text: 'Badges'), Tab(text: 'Historique'), Tab(text: 'Punitions')]),
    );
  }

  Widget _buildOverviewTab(ChildModel child, List<HistoryEntry> history) {
    final recentHistory = history.take(10).toList();
    final now = DateTime.now();
    final monday = now.subtract(Duration(days: now.weekday - 1));
    final mondayStart = DateTime(monday.year, monday.month, monday.day);
    final weekHistory = history.where((h) => h.date.isAfter(mondayStart)).toList();
    final weekPoints = weekHistory.fold<int>(0, (s, h) => s + (h.isBonus ? h.points : -h.points));
    final weekBonus = weekHistory.where((h) => h.isBonus).fold<int>(0, (s, h) => s + h.points);
    final weekPenalties = weekHistory.where((h) => !h.isBonus).fold<int>(0, (s, h) => s + h.points.abs());
    return ListView(padding: const EdgeInsets.all(16), children: [
      Container(padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A2E).withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Cette semaine', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: _miniStatValue('Total', '${weekPoints >= 0 ? '+' : ''}$weekPoints', weekPoints >= 0 ? Colors.greenAccent : Colors.redAccent)),
            Expanded(child: _miniStatValue('Bonus', '+$weekBonus', Colors.greenAccent)),
            Expanded(child: _miniStatValue('Penalites', '-$weekPenalties', Colors.redAccent)),
          ]),
        ])),
      const SizedBox(height: 14),
      _buildGlassCard(title: 'Dernieres activites',
        child: recentHistory.isEmpty
            ? const Center(child: Padding(padding: EdgeInsets.all(20), child: Text('Aucune activite recente', style: TextStyle(color: Colors.white60))))
            : Column(children: recentHistory.map((h) => _buildHistoryTile(h)).toList())),
    ]);
  }

  Widget _miniStatValue(String label, String value, Color color) {
    return Column(children: [
      Text(value, style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 16)),
      const SizedBox(height: 2),
      Text(label, style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 10)),
    ]);
  }

  Widget _buildBadgesTab(ChildModel child, FamilyProvider provider) {
    final allBadges = provider.allBadges;
    if (allBadges.isEmpty) {
      return const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.emoji_events_outlined, color: Colors.white30, size: 64), SizedBox(height: 16),
        Text('Pas de badges disponibles', style: TextStyle(color: Colors.white60, fontSize: 16))]));
    }
    return ListView(padding: const EdgeInsets.all(16), children: [
      if (child.badgeIds.isNotEmpty) ...[
        const Text('\u{1F3C6} Badges obtenus', style: TextStyle(color: Colors.amber, fontSize: 15, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        ...allBadges.where((b) => child.badgeIds.contains(b.id)).map((b) => Container(
          margin: const EdgeInsets.only(bottom: 8), padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: Colors.amber.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.amber.withValues(alpha: 0.35))),
          child: Row(children: [
            Text(b.powerEmoji, style: const TextStyle(fontSize: 26)), const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(b.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14)),
              Text(b.description, style: TextStyle(color: Colors.white.withValues(alpha: 0.65), fontSize: 11))])),
            const Icon(Icons.check_circle, color: Colors.amber, size: 22)]))),
        const SizedBox(height: 16),
      ],
      const Text('\u{1F512} A debloquer', style: TextStyle(color: Colors.white60, fontSize: 15, fontWeight: FontWeight.bold)),
      const SizedBox(height: 8),
      ...allBadges.where((b) => !child.badgeIds.contains(b.id)).map((b) {
        final progress = (child.points / b.requiredPoints).clamp(0.0, 1.0);
        return Container(
          margin: const EdgeInsets.only(bottom: 8), padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A2E).withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
          ),
          child: Row(children: [
            Opacity(opacity: 0.4, child: Text(b.powerEmoji, style: const TextStyle(fontSize: 26))), const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(b.name, style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontWeight: FontWeight.w700, fontSize: 14)),
              Text(b.description, style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 11)),
              const SizedBox(height: 5),
              ClipRRect(borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(value: progress, minHeight: 5,
                  backgroundColor: Colors.white.withValues(alpha: 0.1), valueColor: AlwaysStoppedAnimation(Colors.amber.withValues(alpha: 0.7)))),
              const SizedBox(height: 3),
              Text('${child.points}/${b.requiredPoints} pts', style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 9))])),
            Icon(Icons.lock_outline, color: Colors.white.withValues(alpha: 0.25), size: 18)]));
      }),
    ]);
  }

  Widget _buildHistoryTab(List<HistoryEntry> history) {
    if (history.isEmpty) {
      return const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.history, color: Colors.white30, size: 64), SizedBox(height: 16),
        Text('Aucun historique', style: TextStyle(color: Colors.white60, fontSize: 16))]));
    }
    return ListView.builder(padding: const EdgeInsets.all(16), itemCount: history.length,
      itemBuilder: (context, index) => _buildHistoryTile(history[index]));
  }

  Widget _buildPunishmentsTab(List<PunishmentLines> punishments) {
    final active = punishments.where((p) => !p.isCompleted).toList();
    if (active.isEmpty) {
      return const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.check_circle_outline, color: Colors.greenAccent, size: 64), SizedBox(height: 16),
        Text('Aucune punition en cours', style: TextStyle(color: Colors.white60, fontSize: 16)),
        SizedBox(height: 8), Text('Bravo, continue comme ca !', style: TextStyle(color: Colors.greenAccent, fontSize: 14))]));
    }
    return ListView.builder(padding: const EdgeInsets.all(16), itemCount: active.length,
      itemBuilder: (context, index) {
        final p = active[index];
        final progress = p.totalLines > 0 ? (p.completedLines / p.totalLines).clamp(0.0, 1.0) : 0.0;
        return Container(
          margin: const EdgeInsets.only(bottom: 10), padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A2E).withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.red.withValues(alpha: 0.35)),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Icon(Icons.edit_note_rounded, color: Colors.redAccent, size: 24), const SizedBox(width: 10),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(p.text, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14)),
                const SizedBox(height: 3),
                Text('${p.completedLines} / ${p.totalLines} lignes', style: TextStyle(color: Colors.white.withValues(alpha: 0.65), fontSize: 12))])),
              Text('${(progress * 100).toInt()}%', style: TextStyle(color: progress > 0.5 ? Colors.orange : Colors.redAccent, fontWeight: FontWeight.w800, fontSize: 15))]),
            const SizedBox(height: 8),
            ClipRRect(borderRadius: BorderRadius.circular(5),
              child: LinearProgressIndicator(value: progress, minHeight: 6,
                backgroundColor: Colors.white.withValues(alpha: 0.1),
                valueColor: AlwaysStoppedAnimation(progress > 0.7 ? Colors.greenAccent : progress > 0.4 ? Colors.orange : Colors.redAccent)))]));
      });
  }

  Widget _buildHistoryTile(HistoryEntry entry) {
    final isPositive = entry.isBonus;
    return Container(
      margin: const EdgeInsets.only(bottom: 6), padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.06), borderRadius: BorderRadius.circular(10)),
      child: Row(children: [
        Container(padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(color: (isPositive ? Colors.greenAccent : Colors.redAccent).withValues(alpha: 0.2), shape: BoxShape.circle),
          child: Icon(isPositive ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
            color: isPositive ? Colors.greenAccent : Colors.redAccent, size: 16)),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(entry.reason, style: const TextStyle(color: Colors.white, fontSize: 13), maxLines: 2, overflow: TextOverflow.ellipsis),
          Text(_formatDate(entry.date), style: TextStyle(color: Colors.white.withValues(alpha: 0.45), fontSize: 10))])),
        Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(color: (isPositive ? Colors.greenAccent : Colors.redAccent).withValues(alpha: 0.15), borderRadius: BorderRadius.circular(6)),
          child: Text('${isPositive ? '+' : '-'}${entry.points}',
            style: TextStyle(color: isPositive ? Colors.greenAccent : Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 14)))]));
  }

  Widget _buildGlassCard({required String title, required Widget child}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E).withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(padding: const EdgeInsets.fromLTRB(14, 14, 14, 6),
          child: Text(title, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold))),
        child,
      ]),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inMinutes < 1) return "A l'instant";
    if (diff.inMinutes < 60) return 'Il y a ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'Il y a ${diff.inHours}h';
    if (diff.inDays < 7) return 'Il y a ${diff.inDays} jour${diff.inDays > 1 ? 's' : ''}';
    return '${date.day}/${date.month}/${date.year}';
  }
}
