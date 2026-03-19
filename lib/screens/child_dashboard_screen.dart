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
                  child: Column(
                    children: [
                      _buildHeader(child),
                      if (weekNotes.isNotEmpty) _buildWeekNotes(weekNotes),
                      _buildTabBar(),
                      Expanded(
                        child: TabBarView(
                          controller: _tabController,
                          children: [
                            _buildOverviewTab(child, history),
                            _buildBadgesTab(child, provider),
                            _buildHistoryTab(history),
                            _buildPunishmentsTab(punishments),
                          ],
                        ),
                      ),
                    ],
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

  Widget _buildHeader(ChildModel child) {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
              const Spacer(),
              Text(
                'Mode Enfant',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.7),
                  fontSize: 14,
                ),
              ),
              const Spacer(),
              const SizedBox(width: 48),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.amber.withValues(alpha: 0.5),
                width: 3,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.amber.withValues(alpha: 0.3),
                  blurRadius: 20,
                ),
              ],
            ),
            child: ClipOval(
              child: child.hasPhoto
                  ? Image.memory(
                      base64Decode(child.photoBase64),
                      fit: BoxFit.cover,
                      width: 100,
                      height: 100,
                      gaplessPlayback: true,
                      errorBuilder: (_, __, ___) => _avatarFallback(child),
                    )
                  : _avatarFallback(child),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            child.name,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.amber.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: Colors.amber.withValues(alpha: 0.3),
              ),
            ),
            child: Text(
              child.levelTitle,
              style: TextStyle(
                color: Colors.amber.shade300,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildStatBadge(
                Icons.star,
                '${child.points}',
                'Points',
                Colors.amber,
              ),
              const SizedBox(width: 20),
              _buildStatBadge(
                Icons.trending_up,
                child.levelTitle,
                'Niveau',
                Colors.greenAccent,
              ),
              const SizedBox(width: 20),
              _buildStatBadge(
                Icons.emoji_events,
                '${child.badgeIds.length}',
                'Badges',
                Colors.purpleAccent,
              ),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: child.levelProgress,
              minHeight: 8,
              backgroundColor: Colors.white.withValues(alpha: 0.1),
              valueColor: AlwaysStoppedAnimation<Color>(
                Colors.amber.shade400,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            child.isMaxLevel
                ? '\u{1F381} Niveau MAX atteint ! Cadeau debloque !'
                : '${child.points} / ${child.nextLevelPoints} points pour le prochain niveau',
            style: TextStyle(
              color: child.isMaxLevel
                  ? Colors.amber.shade300
                  : Colors.white.withValues(alpha: 0.5),
              fontSize: 12,
              fontWeight: child.isMaxLevel ? FontWeight.w700 : FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }

  Widget _avatarFallback(ChildModel child) {
    return Container(
      width: 100,
      height: 100,
      color: Colors.white.withValues(alpha: 0.2),
      child: Center(
        child: Text(
          child.avatar.isNotEmpty
              ? child.avatar
              : child.name.isNotEmpty
                  ? child.name[0].toUpperCase()
                  : '?',
          style: const TextStyle(fontSize: 45),
        ),
      ),
    );
  }

  Widget _buildWeekNotes(List<Map<String, dynamic>> notes) {
    final notesWithGrades = notes.where((n) => n['hasNote'] == true).toList();
    if (notesWithGrades.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF448AFF).withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.school_rounded, color: Color(0xFF448AFF), size: 18),
              SizedBox(width: 8),
              Text(
                'Notes de la semaine',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: notes.map((n) {
              final hasNote = n['hasNote'] as bool;
              final isToday = n['isToday'] as bool;
              final isFuture = n['isFuture'] as bool;
              final grade = n['grade'] as double?;

              Color color = Colors.grey;
              if (hasNote && grade != null) {
                if (grade >= 16) {
                  color = const Color(0xFF00E676);
                } else if (grade >= 12) {
                  color = const Color(0xFF448AFF);
                } else if (grade >= 10) {
                  color = Colors.orange;
                } else {
                  color = const Color(0xFFFF1744);
                }
              }

              return Expanded(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    color: isToday && hasNote
                        ? color.withValues(alpha: 0.2)
                        : isToday
                            ? const Color(0xFF448AFF).withValues(alpha: 0.1)
                            : Colors.white.withValues(alpha: 0.05),
                    border: isToday
                        ? Border.all(
                            color: const Color(0xFF448AFF).withValues(alpha: 0.5),
                            width: 1.5,
                          )
                        : null,
                  ),
                  child: Column(
                    children: [
                      Text(
                        (n['day'] as String).substring(0, 3),
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.6),
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      if (hasNote && grade != null) ...[
                        Text(
                          grade.toStringAsFixed(
                            grade == grade.roundToDouble() ? 0 : 1,
                          ),
                          style: TextStyle(
                            color: color,
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        Text(
                          '/20',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.3),
                            fontSize: 9,
                          ),
                        ),
                      ] else if (isFuture)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Text(
                            '-',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.white.withValues(alpha: 0.15),
                            ),
                          ),
                        )
                      else if (isToday)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: const Color(0xFF448AFF).withValues(alpha: 0.5),
                            ),
                          ),
                        )
                      else
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Text(
                            '-',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.white.withValues(alpha: 0.2),
                            ),
                          ),
                        ),
                      if (isToday && hasNote)
                        Container(
                          margin: const EdgeInsets.only(top: 4),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'Auj.',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 8,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildStatBadge(
    IconData icon,
    String value,
    String label,
    Color color,
  ) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.2),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.5),
            fontSize: 11,
          ),
        ),
      ],
    );
  }

  Widget _buildTabBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(12),
        ),
        labelColor: Colors.white,
        unselectedLabelColor: Colors.white54,
        labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        dividerHeight: 0,
        tabs: const [
          Tab(text: 'Resume'),
          Tab(text: 'Badges'),
          Tab(text: 'Historique'),
          Tab(text: 'Punitions'),
        ],
      ),
    );
  }

  Widget _buildOverviewTab(ChildModel child, List<HistoryEntry> history) {
    final recentHistory = history.take(10).toList();

    final now = DateTime.now();
    final monday = now.subtract(Duration(days: now.weekday - 1));
    final mondayStart = DateTime(monday.year, monday.month, monday.day);
    final weekHistory = history.where((h) => h.date.isAfter(mondayStart)).toList();
    final weekPoints = weekHistory.fold<int>(0, (s, h) => s + (h.isBonus ? h.points : -h.points));
    final weekBonus = weekHistory
        .where((h) => h.isBonus)
        .fold<int>(0, (s, h) => s + h.points);
    final weekPenalties = weekHistory
        .where((h) => !h.isBonus)
        .fold<int>(0, (s, h) => s + h.points.abs());

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Cette semaine',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _miniStat(
                      'Total',
                      '${weekPoints >= 0 ? '+' : ''}$weekPoints',
                      weekPoints >= 0 ? Colors.greenAccent : Colors.redAccent,
                    ),
                  ),
                  Expanded(
                    child: _miniStat('Bonus', '+$weekBonus', Colors.greenAccent),
                  ),
                  Expanded(
                    child: _miniStat(
                      'Penalites',
                      '-$weekPenalties',
                      Colors.redAccent,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _buildGlassCard(
          title: 'Dernieres activites',
          child: recentHistory.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: Text(
                      'Aucune activite recente',
                      style: TextStyle(color: Colors.white54),
                    ),
                  ),
                )
              : Column(
                  children: recentHistory
                      .map((h) => _buildHistoryTile(h))
                      .toList(),
                ),
        ),
      ],
    );
  }

  Widget _miniStat(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w800,
            fontSize: 18,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.5),
            fontSize: 11,
          ),
        ),
      ],
    );
  }

  Widget _buildBadgesTab(ChildModel child, FamilyProvider provider) {
    final allBadges = provider.allBadges;
    if (allBadges.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.emoji_events_outlined, color: Colors.white24, size: 64),
            SizedBox(height: 16),
            Text(
              'Pas de badges disponibles',
              style: TextStyle(color: Colors.white54, fontSize: 16),
            ),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (child.badgeIds.isNotEmpty) ...[
          const Text(
            '\u{1F3C6} Badges obtenus',
            style: TextStyle(
              color: Colors.amber,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          ...allBadges
              .where((b) => child.badgeIds.contains(b.id))
              .map((b) => Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.amber.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: Colors.amber.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        Text(
                          b.powerEmoji,
                          style: const TextStyle(fontSize: 28),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                b.name,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15,
                                ),
                              ),
                              Text(
                                b.description,
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.6),
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(
                          Icons.check_circle,
                          color: Colors.amber,
                          size: 24,
                        ),
                      ],
                    ),
                  )),
          const SizedBox(height: 20),
        ],
        const Text(
          '\u{1F512} A debloquer',
          style: TextStyle(
            color: Colors.white54,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 10),
        ...allBadges
            .where((b) => !child.badgeIds.contains(b.id))
            .map((b) {
          final progress = (child.points / b.requiredPoints).clamp(0.0, 1.0);
          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.1),
              ),
            ),
            child: Row(
              children
