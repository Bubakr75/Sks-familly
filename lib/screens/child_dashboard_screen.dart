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

        return Scaffold(
          backgroundColor: Colors.transparent,
          body: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF0f0c29),
                  Color(0xFF302b63),
                  Color(0xFF24243e),
                ],
              ),
            ),
            child: Stack(
              children: [
                if (child.hasPhoto)
                  Positioned.fill(
                    child: Opacity(
                      opacity: 0.15,
                      child: Image.memory(
                        base64Decode(child.photoBase64),
                        fit: BoxFit.cover,
                        gaplessPlayback: true,
                        errorBuilder: (_, __, ___) => const SizedBox.shrink(),
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
          ),
        );
      },
    );
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

      final bool isToday = day.year == now.year &&
          day.month == now.month &&
          day.day == now.day;
      final bool isFuture = day.isAfter(now);

      if (dayHistory.isNotEmpty) {
        final reason = dayHistory.last.reason;
        final match = RegExp(r'Note: ([\d.]+)/20').firstMatch(reason);
        if (match != null) {
          final grade = double.tryParse(match.group(1)!);
          if (grade != null) {
            notes.add({
              'day': dayNames[i],
              'grade': grade,
              'isToday': isToday,
              'hasNote': true,
              'isFuture': false,
            });
            continue;
          }
        }
      }
      notes.add({
        'day': dayNames[i],
        'grade': null,
        'isToday': isToday,
        'hasNote': false,
        'isFuture': isFuture,
      });
    }
    return notes;
  }

  Widget _buildCompactHeader(ChildModel child) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 20),
                onPressed: () => Navigator.pop(context),
              ),
              const Spacer(),
              Text(
                'Mode Enfant',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.7),
                  fontSize: 13,
                ),
              ),
              const Spacer(),
              const SizedBox(width: 48),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.amber.withValues(alpha: 0.5),
                    width: 2.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.amber.withValues(alpha: 0.3),
                      blurRadius: 16,
                    ),
                  ],
                ),
                child: ClipOval(
                  child: child.hasPhoto
                      ? Image.memory(
                          base64Decode(child.photoBase64),
                          fit: BoxFit.cover,
                          width: 70,
                          height: 70,
                          gaplessPlayback: true,
                          errorBuilder: (_, __, ___) => _avatarFallback(child, 70),
                        )
                      : _avatarFallback(child, 70),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      child.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.amber.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
                      ),
                      child: Text(
                        child.levelTitle,
                        style: TextStyle(
                          color: Colors.amber.shade300,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: child.levelProgress,
                        minHeight: 6,
                        backgroundColor: Colors.white.withValues(alpha: 0.1),
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.amber.shade400),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      child.isMaxLevel
                          ? '\u{1F381} Niveau MAX !'
                          : '${child.points} / ${child.nextLevelPoints} pts',
                      style: TextStyle(
                        color: child.isMaxLevel
                            ? Colors.amber.shade300
                            : Colors.white.withValues(alpha: 0.5),
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildMiniStat(Icons.star, '${child.points}', 'Points', Colors.amber),
              _buildMiniStat(Icons.trending_up, child.levelTitle, 'Niveau', Colors.greenAccent),
              _buildMiniStat(Icons.emoji_events, '${child.badgeIds.length}', 'Badges', Colors.purpleAccent),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMiniStat(IconData icon, String value, String label, Color color) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 18),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 14),
        ),
        Text(
          label,
          style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 10),
        ),
      ],
    );
  }

  Widget _avatarFallback(ChildModel child, double size) {
    return Container(
      width: size,
      height: size,
      color: Colors.white.withValues(alpha: 0.2),
      child: Center(
        child: Text(
          child.avatar.isNotEmpty
              ? child.avatar
              : child.name.isNotEmpty
                  ? child.name[0].toUpperCase()
                  : '?',
          style: TextStyle(fontSize: size * 0.45),
        ),
      ),
    );
  }
