import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/family_provider.dart';
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
