import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/family_provider.dart';
import '../models/child_model.dart';
import '../models/history_entry.dart';

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
          body: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF0f0c29), Color(0xFF302b63), Color(0xFF24243e)],
              ),
            ),
            child: Stack(
              children: [
                // Photo en fond si disponible
                if (child.hasPhoto)
                  Positioned.fill(
                    child: Opacity(
                      opacity: 0.15,
                      child: Image.memory(
                        base64Decode(child.photoBase64),
                        fit: BoxFit.cover,
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
                            _buildBadgesTab(child),
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
    final dayNames = ['Lundi', 'Mardi', 'Mercredi', 'Jeudi', 'Vendredi', 'Samedi', 'Dimanche'];
    final List<Map<String, dynamic>> notes = [];

    for (int i = 0; i < 7; i++) {
      final day = DateTime(monday.year, monday.month, monday.day + i);
      final dayHistory = provider.history.where((h) =>
          h.childId == widget.childId &&
          h.category == 'school_note' &&
          h.date.year == day.year &&
          h.date.month == day.month &&
          h.date.day == day.day).toList();

      if (dayHistory.isNotEmpty) {
        final reason = dayHistory.last.reason;
        final match = RegExp(r'Note: ([\d.]+)/20').firstMatch(reason);
        if (match != null) {
          final grade = double.tryParse(match.group(1)!);
          if (grade != null) {
            notes.add({
              'day': dayNames[i],
              'grade': grade,
              'isToday': day.year == now.year && day.month == now.month && day.day == now.day,
            });
          }
        }
      }
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
              Text('Mode Enfant', style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 14)),
              const Spacer(),
              const SizedBox(width: 48),
            ],
          ),
          const SizedBox(height: 16),
          // Grande photo ou avatar
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.amber.withValues(alpha: 0.5), width: 3),
              boxShadow: [BoxShadow(color: Colors.amber.withValues(alpha: 0.3), blurRadius: 20)],
            ),
            child: ClipOval(
              child: child.hasPhoto
                  ? Image.memory(base64Decode(child.photoBase64), fit: BoxFit.cover, width: 100, height: 100)
                  : Container(
                      color: Colors.white.withValues(alpha: 0.2),
                      child: Center(
                        child: Text(
                          child.avatar.isNotEmpty ? child.avatar : child.name.isNotEmpty ? child.name[0].toUpperCase() : '?',
                          style: const TextStyle(fontSize: 45),
                        ),
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 12),
          Text(child.name, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(child.levelTitle, style: TextStyle(color: Colors.amber.shade300, fontSize: 16, fontWeight: FontWeight.w500)),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildStatBadge(Icons.star, '${child.points}', 'Points', Colors.amber),
              const SizedBox(width: 20),
              _buildStatBadge(Icons.trending_up, 'Niv. ${child.level}', 'Niveau', Colors.greenAccent),
              const SizedBox(width: 20),
              _buildStatBadge(Icons.emoji_events, '${child.badgeIds.length}', 'Badges', Colors.purpleAccent),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: child.levelProgress,
              minHeight: 8,
              backgroundColor: Colors.white.withValues(alpha: 0.1),
              valueColor: AlwaysStoppedAnimation<Color>(Colors.amber.shade400),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${child.points} / ${child.nextLevelPoints} points pour le prochain niveau',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildWeekNotes(List<Map<String, dynamic>> notes) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF448AFF).withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.school_rounded, color: Color(0xFF448AFF), size: 18),
              const SizedBox(width: 8),
              const Text('Notes de la semaine', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: notes.map((n) {
              final grade = n['grade'] as double;
              final isToday = n['isToday'] as bool;
              Color color;
              if (grade >= 16) {
                color = const Color(0xFF00E676);
              } else if (grade >= 12) {
                color = const Color(0xFF448AFF);
              } else if (grade >= 10) {
                color = Colors.orange;
              } else {
                color = const Color(0xFFFF1744);
              }

              return Expanded(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    color: isToday ? color.withValues(alpha: 0.2) : Colors.white.withValues(alpha: 0.05),
                    border: isToday ? Border.all(color: color.withValues(alpha: 0.5), width: 1.5) : null,
                  ),
                  child: Column(
                    children: [
                      Text(
                        (n['day'] as String).substring(0, 3),
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 10, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${grade.toStringAsFixed(grade == grade.roundToDouble() ? 0 : 1)}',
                        style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.w900),
                      ),
                      Text('/20', style: TextStyle(color: Colors.white.withValues(alpha: 0.3), fontSize: 9)),
                      if (isToday)
                        Container(
                          margin: const EdgeInsets.only(top: 4),
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text('Auj.', style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.w700)),
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

  Widget _buildStatBadge(IconData icon, String value, String label, Color color) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: color.withValues(alpha: 0.2), shape: BoxShape.circle),
          child: Icon(icon, color: color, size: 24),
        ),
        const SizedBox(height: 6),
        Text(value, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 16)),
        Text(label, style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 11)),
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
        indicator: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(12)),
        labelColor: Colors.white,
        unselectedLabelColor: Colors.white54,
        labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        tabs: const [Tab(text: 'Resume'), Tab(text: 'Badges'), Tab(text: 'Historique'), Tab(text: 'Punitions')],
      ),
    );
  }

  Widget _buildOverviewTab(ChildModel child, List<HistoryEntry> history) {
    final recentHistory = history.take(5).toList();
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildGlassCard(
          title: 'Dernieres activites',
          child: recentHistory.isEmpty
              ? const Center(child: Padding(padding: EdgeInsets.all(20), child: Text('Aucune activite recente', style: TextStyle(color: Colors.white54))))
              : Column(children: recentHistory.map((h) => _buildHistoryTile(h)).toList()),
        ),
      ],
    );
  }

  Widget _buildBadgesTab(ChildModel child) {
    if (child.badgeIds.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.emoji_events_outlined, color: Colors.white24, size: 64),
            SizedBox(height: 16),
            Text('Pas encore de badges', style: TextStyle(color: Colors.white54, fontSize: 16)),
            SizedBox(height: 8),
            Text('Continue tes efforts !', style: TextStyle(color: Colors.white38, fontSize: 14)),
          ],
        ),
      );
    }
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, mainAxisSpacing: 12, crossAxisSpacing: 12),
      itemCount: child.badgeIds.length,
      itemBuilder: (context, index) {
        return Container(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.emoji_events, color: Colors.amber, size: 32),
                const SizedBox(height: 8),
                Text(child.badgeIds[index], style: const TextStyle(color: Colors.white, fontSize: 11), textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHistoryTab(List<HistoryEntry> history) {
    if (history.isEmpty) {
      return const Center(child: Text('Aucun historique', style: TextStyle(color: Colors.white54, fontSize: 16)));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: history.length,
      itemBuilder: (context, index) => _buildHistoryTile(history[index]),
    );
  }

  Widget _buildPunishmentsTab(List<dynamic> punishments) {
    if (punishments.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle_outline, color: Colors.greenAccent, size: 64),
            SizedBox(height: 16),
            Text('Aucune punition en cours', style: TextStyle(color: Colors.white54, fontSize: 16)),
            SizedBox(height: 8),
            Text('Bravo, continue comme ca !', style: TextStyle(color: Colors.greenAccent, fontSize: 14)),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: punishments.length,
      itemBuilder: (context, index) {
        final p = punishments[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.red.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(p.reason ?? 'Punition', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 15)),
                    if (p.description != null && p.description!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(p.description!, style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 13)),
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHistoryTile(HistoryEntry entry) {
    final isPositive = entry.points >= 0;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: (isPositive ? Colors.greenAccent : Colors.redAccent).withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(isPositive ? Icons.add : Icons.remove, color: isPositive ? Colors.greenAccent : Colors.redAccent, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(entry.reason, style: const TextStyle(color: Colors.white, fontSize: 14), maxLines: 1, overflow: TextOverflow.ellipsis),
                Text(_formatDate(entry.date), style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 11)),
              ],
            ),
          ),
          Text('${isPositive ? '+' : ''}${entry.points}', style: TextStyle(color: isPositive ? Colors.greenAccent : Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 16)),
        ],
      ),
    );
  }

  Widget _buildGlassCard({required String title, required Widget child}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(padding: const EdgeInsets.fromLTRB(16, 16, 16, 8), child: Text(title, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold))),
          child,
        ],
      ),
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
