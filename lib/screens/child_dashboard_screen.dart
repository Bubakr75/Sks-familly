import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/family_provider.dart';
import '../providers/pin_provider.dart';
import '../widgets/animated_background.dart';
import '../widgets/glass_card.dart';
import '../widgets/tv_focus_wrapper.dart';
import 'tribunal_screen.dart';
import 'school_notes_screen.dart';
import 'trade_screen.dart';

class ChildDashboardScreen extends StatefulWidget {
  final String childId;

  const ChildDashboardScreen({super.key, required this.childId});

  @override
  State<ChildDashboardScreen> createState() =>
      _ChildDashboardScreenState();
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

  String _formatMinutes(int minutes) {
    final h = minutes ~/ 60;
    final m = minutes % 60;
    if (h > 0 && m > 0) return '${h}h${m.toString().padLeft(2, '0')}';
    if (h > 0) return '${h}h';
    return '${m}min';
  }

  @override
  Widget build(BuildContext context) {
    final pinProvider = context.watch<PinProvider>();
    final isParentMode = pinProvider.isParentMode;

    return Consumer<FamilyProvider>(
      builder: (context, provider, _) {
        final child = provider.getChild(widget.childId);
        if (child == null) {
          return AnimatedBackground(
            child: Scaffold(
              backgroundColor: Colors.transparent,
              body: const Center(
                child: Text('Enfant introuvable',
                    style: TextStyle(color: Colors.white54)),
              ),
            ),
          );
        }

        final weekendMinutes = provider.getSaturdayMinutes(child.id);
        final history = provider.getHistoryForChild(child.id);
        final badges = provider.getBadgesForChild(child.id);

        return AnimatedBackground(
          child: Scaffold(
            backgroundColor: Colors.transparent,
            appBar: AppBar(
              title: Text(child.name),
              backgroundColor: Colors.transparent,
              elevation: 0,
              bottom: TabBar(
                controller: _tabController,
                indicatorColor: Colors.cyanAccent,
                labelColor: Colors.cyanAccent,
                unselectedLabelColor: Colors.white54,
                tabs: const [
                  Tab(icon: Icon(Icons.person), text: 'Profil'),
                  Tab(icon: Icon(Icons.tv), text: 'Écran'),
                  Tab(icon: Icon(Icons.history), text: 'Historique'),
                  Tab(icon: Icon(Icons.emoji_events), text: 'Badges'),
                ],
              ),
            ),
            body: TabBarView(
              controller: _tabController,
              children: [
                _buildProfileTab(child, provider, isParentMode),
                _buildScreenTimeTab(child, provider, weekendMinutes, isParentMode),
                _buildHistoryTab(history, provider),
                _buildBadgesTab(badges),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildProfileTab(
      dynamic child, FamilyProvider provider, bool isParentMode) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          GlassCard(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 40,
                    backgroundColor: Colors.cyanAccent.withOpacity(0.3),
                    child: Text(
                      child.name.isNotEmpty ? child.name[0].toUpperCase() : '?',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    child.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Niveau ${child.level}',
                    style: const TextStyle(color: Colors.white54, fontSize: 14),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _statChip(Icons.star, '${child.points}', 'Points', Colors.amberAccent),
                      const SizedBox(width: 24),
                      _statChip(Icons.emoji_events,
                          '${provider.getBadgesForChild(child.id).length}', 'Badges', Colors.purpleAccent),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TvFocusWrapper(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => SchoolNotesScreen(childId: child.id),
                      ),
                    );
                  },
                  child: _actionCard(Icons.school, 'Notes scolaires', Colors.orangeAccent),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TvFocusWrapper(
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Échanges bientôt disponibles'),
                        backgroundColor: Colors.greenAccent,
                      ),
                    );
                  },
                  child: _actionCard(Icons.swap_horiz, 'Échanges', Colors.greenAccent),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TvFocusWrapper(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const TribunalScreen()),
              );
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.amberAccent.withOpacity(0.15),
                    Colors.orangeAccent.withOpacity(0.05),
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.amberAccent.withOpacity(0.3)),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.balance, color: Colors.amberAccent, size: 24),
                  SizedBox(width: 10),
                  Text(
                    'Demander un tribunal',
                    style: TextStyle(
                      color: Colors.amberAccent,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          _buildWeeklyStats(child, provider),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _statChip(IconData icon, String value, String label, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(color: color, fontSize: 20, fontWeight: FontWeight.bold),
        ),
        Text(label, style: const TextStyle(color: Colors.white38, fontSize: 11)),
      ],
    );
  }

  Widget _actionCard(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w600),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildWeeklyStats(dynamic child, FamilyProvider provider) {
    final now = DateTime.now();
    final weekStart = now.subtract(Duration(days: now.weekday - 1));
    final weekActivities = provider
        .getHistoryForChild(child.id)
        .where((a) => a.date.isAfter(weekStart))
        .toList();

    int bonusCount = 0;
    int penaltyCount = 0;
    for (final a in weekActivities) {
      if (a.isBonus) {
        bonusCount++;
      } else {
        penaltyCount++;
      }
    }

    return GlassCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Cette semaine',
              style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _weekStatItem(Icons.thumb_up, '$bonusCount', 'Bonus', Colors.greenAccent),
                _weekStatItem(Icons.thumb_down, '$penaltyCount', 'Pénalités', Colors.redAccent),
                _weekStatItem(Icons.timeline, '${weekActivities.length}', 'Total', Colors.cyanAccent),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _weekStatItem(IconData icon, String value, String label, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.bold),
        ),
        Text(label, style: const TextStyle(color: Colors.white38, fontSize: 10)),
      ],
    );
  }

  Widget _buildScreenTimeTab(
      dynamic child, FamilyProvider provider, int weekendMinutes, bool isParentMode) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          GlassCard(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  const Icon(Icons.tv, color: Colors.purpleAccent, size: 48),
                  const SizedBox(height: 12),
                  Text(
                    _formatMinutes(weekendMinutes),
                    style: const TextStyle(
                      color: Colors.purpleAccent,
                      fontSize: 40,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Text(
                    'Temps d\'écran weekend',
                    style: TextStyle(color: Colors.white54, fontSize: 14),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          GlassCard(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Détail du calcul',
                    style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 12),
                  _calcRow('Base weekend', '120 min'),
                  _calcRow('Points (${child.points})', '+${child.points} min'),
                  const Divider(color: Colors.white12),
                  _calcRow('Total', _formatMinutes(weekendMinutes), bold: true),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (isParentMode) ...[
            const Text(
              'Bonus de temps',
              style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [15, 30, 60].map((val) {
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: TvFocusWrapper(
                    onTap: () {
                      provider.addScreenTimeBonus(child.id, val, 'Bonus rapide +${val}min');
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('+${val}min ajoutées'),
                          backgroundColor: Colors.purpleAccent,
                        ),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.purpleAccent.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.purpleAccent.withOpacity(0.4)),
                      ),
                      child: Text(
                        '+${val}min',
                        style: const TextStyle(color: Colors.purpleAccent, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 12),
            TvFocusWrapper(
              onTap: () => _showCustomBonusDialog(child, provider),
              child: OutlinedButton.icon(
                onPressed: () => _showCustomBonusDialog(child, provider),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Bonus personnalisé'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.purpleAccent,
                  side: const BorderSide(color: Colors.purpleAccent),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
          ],
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _calcRow(String label, String value, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(
                color: Colors.white54,
                fontSize: 13,
                fontWeight: bold ? FontWeight.bold : FontWeight.normal,
              )),
          Text(value,
              style: TextStyle(
                color: bold ? Colors.purpleAccent : Colors.white,
                fontSize: 13,
                fontWeight: bold ? FontWeight.bold : FontWeight.w600,
              )),
        ],
      ),
    );
  }

  void _showCustomBonusDialog(dynamic child, FamilyProvider provider) {
    int customMinutes = 30;
    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: Colors.grey[900],
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: const Text('Bonus personnalisé', style: TextStyle(color: Colors.white)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      TvFocusWrapper(
                        onTap: () {
                          if (customMinutes > 5) {
                            setDialogState(() => customMinutes -= 5);
                          }
                        },
                        child: const Icon(Icons.remove_circle_outline, color: Colors.white54, size: 32),
                      ),
                      const SizedBox(width: 20),
                      Text(
                        '${customMinutes}min',
                        style: const TextStyle(
                          color: Colors.purpleAccent,
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 20),
                      TvFocusWrapper(
                        onTap: () {
                          if (customMinutes < 240) {
                            setDialogState(() => customMinutes += 5);
                          }
                        },
                        child: const Icon(Icons.add_circle_outline, color: Colors.white54, size: 32),
                      ),
                    ],
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Annuler', style: TextStyle(color: Colors.white54)),
                ),
                ElevatedButton(
                  onPressed: () {
                    provider.addScreenTimeBonus(
                        child.id, customMinutes, 'Bonus personnalisé +${customMinutes}min');
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(this.context).showSnackBar(
                      SnackBar(
                        content: Text('+${customMinutes}min ajoutées'),
                        backgroundColor: Colors.purpleAccent,
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.purpleAccent),
                  child: const Text('Ajouter'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildHistoryTab(List<dynamic> history, FamilyProvider provider) {
    if (history.isEmpty) {
      return const Center(
        child: Text('Aucun historique', style: TextStyle(color: Colors.white38)),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: history.length,
      itemBuilder: (context, index) {
        final activity = history[index];
        final isPositive = activity.isBonus;

        return TvFocusWrapper(
          onTap: () {},
          child: Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.04),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white10),
            ),
            child: Row(
              children: [
                Icon(
                  isPositive ? Icons.add_circle_outline : Icons.remove_circle_outline,
                  color: isPositive ? Colors.greenAccent : Colors.redAccent,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        activity.reason ?? '',
                        style: const TextStyle(color: Colors.white, fontSize: 14),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        '${activity.date.day.toString().padLeft(2, '0')}/${activity.date.month.toString().padLeft(2, '0')}',
                        style: const TextStyle(color: Colors.white38, fontSize: 11),
                      ),
                    ],
                  ),
                ),
                Text(
                  '${isPositive ? '+' : '-'}${activity.points}',
                  style: TextStyle(
                    color: isPositive ? Colors.greenAccent : Colors.redAccent,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildBadgesTab(List<dynamic> badges) {
    if (badges.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.emoji_events, size: 64, color: Colors.white24),
            const SizedBox(height: 12),
            const Text('Aucun badge gagné', style: TextStyle(color: Colors.white38)),
          ],
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: badges.length,
      itemBuilder: (context, index) {
        final badge = badges[index];

        return TvFocusWrapper(
          onTap: () => _showBadgeDetail(badge),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.amberAccent.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.amberAccent.withOpacity(0.3)),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.emoji_events, color: Colors.amberAccent, size: 32),
                const SizedBox(height: 6),
                Text(
                  badge.name ?? 'Badge',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showBadgeDetail(dynamic badge) {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: Colors.grey[900],
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              const Icon(Icons.emoji_events, color: Colors.amberAccent),
              const SizedBox(width: 8),
              Expanded(
                child: Text(badge.name ?? 'Badge',
                    style: const TextStyle(color: Colors.white)),
              ),
            ],
          ),
          content: Text(
            badge.description ?? 'Aucune description',
            style: const TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Fermer', style: TextStyle(color: Colors.cyanAccent)),
            ),
          ],
        );
      },
    );
  }
}
