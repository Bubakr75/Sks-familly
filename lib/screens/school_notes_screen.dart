import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/family_provider.dart';
import '../models/child_model.dart';
import '../widgets/glass_card.dart';
import '../widgets/animated_background.dart';

class ChildDashboardScreen extends StatefulWidget {
  final String childId;
  const ChildDashboardScreen({super.key, required this.childId});

  @override
  State<ChildDashboardScreen> createState() => _ChildDashboardScreenState();
}

class _ChildDashboardScreenState extends State<ChildDashboardScreen> with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  int _currentTab = 0;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<FamilyProvider>();
    final child = provider.getChild(widget.childId);
    final primary = Theme.of(context).colorScheme.primary;

    if (child == null) {
      return Scaffold(
        backgroundColor: const Color(0xFF0A0E21),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Profil introuvable', style: TextStyle(color: Colors.white, fontSize: 18)),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Retour'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0A0E21),
      body: AnimatedBackground(
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(child, primary, provider),
              Expanded(
                child: IndexedStack(
                  index: _currentTab,
                  children: [
                    _buildOverviewTab(child, provider, primary),
                    _buildBadgesTab(child, provider, primary),
                    _buildHistoryTab(child, provider),
                    _buildPunishmentsTab(child, provider, primary),
                  ],
                ),
              ),
              _buildBottomNav(primary),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(ChildModel child, Color primary, FamilyProvider provider) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
              const Spacer(),
              Text(
                'Mon Espace',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.7),
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Spacer(),
              const SizedBox(width: 48),
            ],
          ),
          const SizedBox(height: 12),
          AnimatedBuilder(
            animation: _animController,
            builder: (context, _) {
              final glow = 0.2 + _animController.value * 0.3;
              return Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(25),
                  boxShadow: [
                    BoxShadow(
                      color: primary.withValues(alpha: glow.clamp(0.0, 1.0)),
                      blurRadius: 20 + _animController.value * 10,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(25),
                  child: child.hasPhoto
                      ? Image.memory(
                          base64Decode(child.photoBase64!),
                          fit: BoxFit.cover,
                          gaplessPlayback: true,
                          errorBuilder: (_, __, ___) => _avatarFallback(child, primary),
                        )
                      : _avatarFallback(child, primary),
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          Text(
            child.name,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: primary.withValues(alpha: 0.3)),
            ),
            child: Text(
              'Niveau ${child.level} - ${child.levelTitle}',
              style: TextStyle(color: primary, fontWeight: FontWeight.w600, fontSize: 13),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildStatBubble(
                '${child.points}',
                'Points',
                primary,
              ),
              const SizedBox(width: 16),
              _buildStatBubble(
                '${child.badgeIds.length}',
                'Badges',
                const Color(0xFFFFD700),
              ),
              const SizedBox(width: 16),
              _buildStatBubble(
                '${provider.getPunishmentsForChild(child.id).where((p) => !p.isCompleted).length}',
                'Punitions',
                const Color(0xFFFF1744),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: child.levelProgress,
              minHeight: 10,
              backgroundColor: Colors.white.withValues(alpha: 0.08),
              valueColor: AlwaysStoppedAnimation(primary),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${child.points}/${child.nextLevelPoints} pts pour le prochain niveau',
            style: TextStyle(fontSize: 11, color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  Widget _buildStatBubble(String value, String label, Color color) {
    return GlassCard(
      margin: EdgeInsets.zero,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      borderRadius: 16,
      borderColor: color.withValues(alpha: 0.2),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 22,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              color: color.withValues(alpha: 0.7),
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _avatarFallback(ChildModel child, Color primary) {
    return Container(
      width: 90,
      height: 90,
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [primary, primary.withValues(alpha: 0.5)]),
        borderRadius: BorderRadius.circular(25),
      ),
      child: Center(
        child: Text(
          child.avatar.isEmpty ? '\u{1F466}' : child.avatar,
          style: const TextStyle(fontSize: 42),
        ),
      ),
    );
  }

  // === TAB 1: Overview ===
  Widget _buildOverviewTab(ChildModel child, FamilyProvider provider, Color primary) {
    final goals = provider.getGoalsForChild(child.id);
    final weeklyStats = provider.getWeeklyStats(child.id);
    final todayHistory = provider.getHistoryForDate(DateTime.now())
        .where((h) => h.childId == child.id)
        .toList();

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (todayHistory.isNotEmpty) ...[
            _sectionTitle("Aujourd'hui"),
            GlassCard(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(14),
              borderRadius: 16,
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: const Color(0xFF00E5FF).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.today_rounded, color: Color(0xFF00E5FF), size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${todayHistory.length} activite${todayHistory.length > 1 ? 's' : ''}',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                        ),
                        Text(
                          '+${todayHistory.where((e) => e.isBonus).fold<int>(0, (s, e) => s + e.points)} pts gagnes',
                          style: TextStyle(color: Colors.grey[500], fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (goals.isNotEmpty) ...[
            _sectionTitle('Mes Objectifs'),
            ...goals.map((g) => GlassCard(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(14),
              borderRadius: 16,
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: g.completed
                          ? const Color(0xFF00E676).withValues(alpha: 0.12)
                          : primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      g.completed ? Icons.check_circle_rounded : Icons.flag_rounded,
                      color: g.completed ? const Color(0xFF00E676) : primary,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          g.title,
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            decoration: g.completed ? TextDecoration.lineThrough : null,
                          ),
                        ),
                        const SizedBox(height: 4),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: (child.points / g.targetPoints).clamp(0.0, 1.0),
                            minHeight: 6,
                            backgroundColor: Colors.white.withValues(alpha: 0.08),
                            valueColor: AlwaysStoppedAnimation(
                              g.completed ? const Color(0xFF00E676) : primary,
                            ),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          g.completed
                              ? 'Objectif atteint !'
                              : '${child.points}/${g.targetPoints} pts',
                          style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            )),
          ],
          _sectionTitle('Ma Semaine'),
          GlassCard(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(14),
            borderRadius: 16,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: weeklyStats.entries.map((e) {
                final isToday = ['Lun', 'Mar', 'Mer', 'Jeu', 'Ven', 'Sam', 'Dim'][DateTime.now().weekday - 1] == e.key;
                return Column(
                  children: [
                    Text(
                      e.key,
                      style: TextStyle(
                        fontSize: 11,
                        color: isToday ? primary : Colors.grey[600],
                        fontWeight: isToday ? FontWeight.w700 : FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        color: e.value > 0
                            ? primary.withValues(alpha: 0.12)
                            : Colors.white.withValues(alpha: 0.04),
                        border: isToday
                            ? Border.all(color: primary.withValues(alpha: 0.5))
                            : null,
                      ),
                      child: Center(
                        child: Text(
                          '${e.value}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: e.value > 0 ? primary : Colors.grey[600],
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  // === TAB 2: Badges ===
  Widget _buildBadgesTab(ChildModel child, FamilyProvider provider, Color primary) {
    final allBadges = provider.allBadges;
    final earnedIds = child.badgeIds.toSet();

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('Mes Badges (${earnedIds.length}/${allBadges.length})'),
          ...allBadges.map((badge) {
            final earned = earnedIds.contains(badge.id);
            return GlassCard(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(14),
              borderRadius: 16,
              borderColor: earned
                  ? const Color(0xFFFFD700).withValues(alpha: 0.3)
                  : Colors.white.withValues(alpha: 0.05),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      color: earned
                          ? const Color(0xFFFFD700).withValues(alpha: 0.15)
                          : Colors.white.withValues(alpha: 0.05),
                      border: Border.all(
                        color: earned
                            ? const Color(0xFFFFD700).withValues(alpha: 0.4)
                            : Colors.white.withValues(alpha: 0.1),
                      ),
                    ),
                    child: Center(
                      child: Icon(
                        Icons.emoji_events_rounded,
                        color: earned ? const Color(0xFFFFD700) : Colors.grey[700],
                        size: 26,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          badge.name,
                          style: TextStyle(
                            color: earned ? Colors.white : Colors.grey[600],
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                        ),
                        Text(
                          badge.description,
                          style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          earned ? 'Obtenu !' : '${badge.requiredPoints} pts requis',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: earned ? const Color(0xFF00E676) : Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (earned)
                    const Icon(Icons.check_circle_rounded, color: Color(0xFF00E676), size: 24),
                ],
              ),
            );
          }),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  // === TAB 3: History ===
  Widget _buildHistoryTab(ChildModel child, FamilyProvider provider) {
    final history = provider.getHistoryForChild(child.id);

    return history.isEmpty
        ? Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.history_rounded, size: 48, color: Colors.grey[700]),
                const SizedBox(height: 12),
                Text('Aucune activite', style: TextStyle(color: Colors.grey[600])),
              ],
            ),
          )
        : ListView.builder(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: history.length,
            itemBuilder: (_, i) {
              final h = history[i];
              return GlassCard(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                borderRadius: 14,
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: h.isBonus
                            ? const Color(0xFF00E676).withValues(alpha: 0.12)
                            : const Color(0xFFFF1744).withValues(alpha: 0.12),
                      ),
                      child: Icon(
                        h.isBonus ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
                        color: h.isBonus ? const Color(0xFF00E676) : const Color(0xFFFF1744),
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            h.reason,
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            '${h.date.day}/${h.date.month}/${h.date.year} a ${h.date.hour}:${h.date.minute.toString().padLeft(2, '0')}',
                            style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        color: h.isBonus
                            ? const Color(0xFF00E676).withValues(alpha: 0.12)
                            : const Color(0xFFFF1744).withValues(alpha: 0.12),
                      ),
                      child: Text(
                        '${h.isBonus ? '+' : ''}${h.points}',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: h.isBonus ? const Color(0xFF00E676) : const Color(0xFFFF1744),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          );
  }

  // === TAB 4: Punishments ===
  Widget _buildPunishmentsTab(ChildModel child, FamilyProvider provider, Color primary) {
    final punishments = provider.getPunishmentsForChild(child.id);
    final active = punishments.where((p) => !p.isCompleted).toList();
    final completed = punishments.where((p) => p.isCompleted).toList();

    if (punishments.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: const Color(0xFF00E676).withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle_rounded, color: Color(0xFF00E676), size: 40),
            ),
            const SizedBox(height: 16),
            const Text('Aucune punition !', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text('Continue comme ca !', style: TextStyle(color: Colors.grey[500])),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (active.isNotEmpty) ...[
            _sectionTitle('En cours (${active.length})'),
            ...active.map((p) => _buildPunishmentCard(p, primary, false)),
          ],
          if (completed.isNotEmpty) ...[
            _sectionTitle('Terminees (${completed.length})'),
            ...completed.map((p) => _buildPunishmentCard(p, primary, true)),
          ],
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _buildPunishmentCard(punishment, Color primary, bool isCompleted) {
    final progress = punishment.completedLines / punishment.totalLines;
    return GlassCard(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      borderRadius: 16,
      borderColor: isCompleted
          ? const Color(0xFF00E676).withValues(alpha: 0.2)
          : const Color(0xFFFF1744).withValues(alpha: 0.2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: isCompleted
                      ? const Color(0xFF00E676).withValues(alpha: 0.12)
                      : const Color(0xFFFF1744).withValues(alpha: 0.12),
                ),
                child: Icon(
                  isCompleted ? Icons.check_circle_rounded : Icons.edit_note_rounded,
                  color: isCompleted ? const Color(0xFF00E676) : const Color(0xFFFF1744),
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '"${punishment.text}"',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        fontStyle: FontStyle.italic,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${punishment.completedLines}/${punishment.totalLines} lignes',
                      style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: Colors.white.withValues(alpha: 0.08),
              valueColor: AlwaysStoppedAnimation(
                isCompleted ? const Color(0xFF00E676) : const Color(0xFFFF1744),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _buildBottomNav(Color primary) {
    final items = [
      _ChildNavItem(Icons.home_outlined, Icons.home_rounded, 'Accueil'),
      _ChildNavItem(Icons.emoji_events_outlined, Icons.emoji_events_rounded, 'Badges'),
      _ChildNavItem(Icons.history_outlined, Icons.history_rounded, 'Historique'),
      _ChildNavItem(Icons.edit_note_outlined, Icons.edit_note_rounded, 'Punitions'),
    ];

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      height: 68,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        color: const Color(0xFF0A0E21).withValues(alpha: 0.9),
        border: Border.all(color: primary.withValues(alpha: 0.15)),
        boxShadow: [BoxShadow(color: primary.withValues(alpha: 0.08), blurRadius: 20)],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: items.asMap().entries.map((entry) {
          final i = entry.key;
          final item = entry.value;
          final isSelected = _currentTab == i;
          return Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => setState(() => _currentTab = i),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: isSelected ? primary.withValues(alpha: 0.15) : Colors.transparent,
                    ),
                    child: Icon(
                      isSelected ? item.activeIcon : item.icon,
                      size: isSelected ? 24 : 22,
                      color: isSelected ? primary : Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    item.label,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                      color: isSelected ? primary : Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _ChildNavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  _ChildNavItem(this.icon, this.activeIcon, this.label);
}
