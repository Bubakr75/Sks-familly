import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/family_provider.dart';
import '../providers/pin_provider.dart';
import '../providers/theme_provider.dart';
import '../utils/pin_guard.dart';
import '../widgets/glass_card.dart';
import '../widgets/tv_focus_wrapper.dart';
import '../widgets/animated_background.dart';
import '../widgets/page_transitions.dart';
import '../models/child_model.dart';
import '../models/history_entry.dart';

import '../screens/dashboard_screen.dart';
import '../screens/add_points_screen.dart';
import '../screens/calendar_screen.dart';
import '../screens/stats_screen.dart';
import '../screens/settings_screen.dart';
import '../screens/school_notes_screen.dart';
import '../screens/punishment_lines_screen.dart';
import '../screens/immunity_lines_screen.dart';
import '../screens/tribunal_screen.dart';
import '../screens/trade_screen.dart';
import '../screens/badges_screen.dart';
import '../screens/family_screen.dart';
import '../screens/screen_time_screen.dart';
import '../screens/child_dashboard_screen.dart';
import '../screens/parent_admin_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  int _currentIndex = 0;
  late AnimationController _fabController;
  late AnimationController _transitionController;

  @override
  void initState() {
    super.initState();
    _fabController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..repeat(reverse: true);
    _transitionController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    )..forward();
  }

  @override
  void dispose() {
    _fabController.dispose();
    _transitionController.dispose();
    super.dispose();
  }

  static const List<int> _protectedIndices = [1, 4];

  Widget _getScreen(int index) {
    switch (index) {
      case 0: return const DashboardScreen();
      case 1: return const AddPointsScreen();
      case 2: return const CalendarScreen();
      case 3: return const StatsScreen();
      case 4: return const SettingsScreen();
      default: return const DashboardScreen();
    }
  }

  void _onTabTapped(int index) {
    if (_protectedIndices.contains(index)) {
      final pinProvider = context.read<PinProvider>();
      if (!pinProvider.canPerformParentAction()) {
        PinGuard.guardAction(context, () {
          _transitionController.forward(from: 0);
          setState(() => _currentIndex = index);
        });
        return;
      }
    }
    _transitionController.forward(from: 0);
    setState(() => _currentIndex = index);
  }

  void _showChildPicker(BuildContext context, {required Function(String childId) onSelected}) {
    final familyProvider = context.read<FamilyProvider>();
    final children = familyProvider.sortedChildren;

    if (children.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text('Aucun enfant enregistré !'),
        backgroundColor: Colors.orange.withOpacity(0.8),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ));
      return;
    }

    if (children.length == 1) {
      onSelected(children.first.id);
      return;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor.withOpacity(0.95),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 16),
            const Text('Choisir un enfant', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            ...children.map((child) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: TvFocusWrapper(
                onTap: () { Navigator.pop(ctx); onSelected(child.id); },
                child: GlassCard(
                  onTap: () { Navigator.pop(ctx); onSelected(child.id); },
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.white12,
                      child: Text(child.name.isNotEmpty ? child.name[0].toUpperCase() : '?',
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                    ),
                    title: Text(child.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text('${child.points} points', style: const TextStyle(fontSize: 12, color: Colors.white54)),
                    trailing: const Icon(Icons.chevron_right, color: Colors.white38),
                  ),
                ),
              ),
            )),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _showFullHistory(BuildContext context) {
    final familyProvider = context.read<FamilyProvider>();
    final children = familyProvider.sortedChildren;
    final pinProvider = context.read<PinProvider>();
    final isParent = pinProvider.canPerformParentAction();

    final allHistory = <Map<String, dynamic>>[];
    for (final child in children) {
      final historyList = familyProvider.getHistoryForChild(child.id);
      for (final entry in historyList) {
        allHistory.add({
          'entry': entry,
          'childName': child.name,
          'childId': child.id,
        });
      }
    }
    allHistory.sort((a, b) {
      final dateA = (a['entry'] as HistoryEntry).date;
      final dateB = (b['entry'] as HistoryEntry).date;
      return dateB.compareTo(dateA);
    });

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Container(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor.withOpacity(0.95),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    const Text('📜 Historique complet', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    const Spacer(),
                    Text('${allHistory.length} entrées', style: const TextStyle(color: Colors.white54, fontSize: 12)),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: allHistory.isEmpty
                    ? const Center(child: Text('Aucun historique', style: TextStyle(color: Colors.white54)))
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: allHistory.length,
                        itemBuilder: (_, index) {
                          final item = allHistory[index];
                          final entry = item['entry'] as HistoryEntry;
                          final childName = item['childName'] as String;
                          final isBonus = entry.isBonus;
                          final pts = entry.points;
                          final description = entry.description;
                          final date = entry.date;
                          final category = entry.category;

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: isParent
                                ? Dismissible(
                                    key: Key(entry.id),
                                    direction: DismissDirection.endToStart,
                                    background: Container(
                                      alignment: Alignment.centerRight,
                                      padding: const EdgeInsets.only(right: 20),
                                      decoration: BoxDecoration(
                                          color: Colors.red.withOpacity(0.3),
                                          borderRadius: BorderRadius.circular(12)),
                                      child: const Icon(Icons.delete, color: Colors.redAccent, size: 28),
                                    ),
                                    confirmDismiss: (_) async {
                                      return await showDialog<bool>(
                                        context: context,
                                        builder: (dCtx) => AlertDialog(
                                          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                          title: const Text('🗑️ Supprimer ?'),
                                          content: Text('"$description"\n${isBonus ? '+' : ''}$pts pts — $childName'),
                                          actions: [
                                            TextButton(onPressed: () => Navigator.pop(dCtx, false), child: const Text('Annuler')),
                                            ElevatedButton(
                                              onPressed: () => Navigator.pop(dCtx, true),
                                              style: ElevatedButton.styleFrom(backgroundColor: Colors.red.withOpacity(0.3)),
                                              child: const Text('Supprimer', style: TextStyle(color: Colors.redAccent)),
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                                    onDismissed: (_) {
                                      context.read<FamilyProvider>().deleteHistoryEntry(entry.id);
                                      allHistory.removeAt(index);
                                      setSheetState(() {});
                                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                        content: Text('🗑️ Supprimé : "$description"'),
                                        backgroundColor: Colors.green.withOpacity(0.8),
                                        behavior: SnackBarBehavior.floating,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                      ));
                                    },
                                    child: _buildHistoryTile(
                                      context,
                                      entry: entry,
                                      childName: childName,
                                      isBonus: isBonus,
                                      pts: pts,
                                      description: description,
                                      date: date,
                                      category: category,
                                      isParent: isParent,
                                    ),
                                  )
                                : _buildHistoryTile(
                                    context,
                                    entry: entry,
                                    childName: childName,
                                    isBonus: isBonus,
                                    pts: pts,
                                    description: description,
                                    date: date,
                                    category: category,
                                    isParent: isParent,
                                  ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHistoryTile(BuildContext context, {
    required HistoryEntry entry,
    required String childName,
    required bool isBonus,
    required int pts,
    required String description,
    required DateTime date,
    required String category,
    required bool isParent,
  }) {
    return GlassCard(
      child: ListTile(
        leading: Container(
          width: 42, height: 42,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isBonus ? Colors.green.withOpacity(0.2) : Colors.red.withOpacity(0.2),
          ),
          child: Center(
            child: Text('${isBonus ? '+' : ''}$pts',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14,
                    color: isBonus ? Colors.greenAccent : Colors.redAccent)),
          ),
        ),
        title: Text(description, style: const TextStyle(fontSize: 14), maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Row(children: [
          Text(childName, style: const TextStyle(fontSize: 11, color: Colors.white54)),
          const SizedBox(width: 6),
          Text(_formatHistoryDate(date), style: const TextStyle(fontSize: 10, color: Colors.white38)),
          if (category != 'Bonus') ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.08), borderRadius: BorderRadius.circular(4)),
              child: Text(category, style: const TextStyle(fontSize: 9, color: Colors.white38)),
            ),
          ],
        ]),
        trailing: isParent ? const Icon(Icons.swipe_left, size: 14, color: Colors.white24) : null,
      ),
    );
  }

  String _formatHistoryDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dateDay = DateTime(date.year, date.month, date.day);
    final diff = today.difference(dateDay).inDays;
    final time = '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    if (diff == 0) return 'Aujourd\'hui $time';
    if (diff == 1) return 'Hier $time';
    if (diff < 7) return 'Il y a $diff jours';
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  Widget _buildDrawer(BuildContext context) {
    final pinProvider = context.watch<PinProvider>();
    final familyProvider = context.watch<FamilyProvider>();
    final themeProvider = context.watch<ThemeProvider>();
    final isParent = pinProvider.canPerformParentAction();

    return Drawer(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor.withOpacity(0.95),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      width: 48, height: 48,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(colors: [themeProvider.primaryColor, themeProvider.primaryColor.withOpacity(0.5)]),
                      ),
                      child: const Center(child: Text('👨‍👩‍👧‍👦', style: TextStyle(fontSize: 24))),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Family Points', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          Row(children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: isParent ? Colors.green.withOpacity(0.2) : Colors.orange.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(isParent ? '👑 Parent' : '👶 Enfant',
                                  style: TextStyle(fontSize: 11, color: isParent ? Colors.greenAccent : Colors.orangeAccent)),
                            ),
                          ]),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(color: Colors.white12, height: 1),
              _drawerSectionTitle('ACTIVITÉS'),
              _drawerItem(context, emoji: '📚', title: 'Notes scolaires', subtitle: 'Gérer les notes',
                  onTap: () { Navigator.pop(context); _showChildPicker(context, onSelected: (id) => Navigator.push(context, SlidePageRoute(page: SchoolNotesScreen(childId: id)))); }),
              _drawerItem(context, emoji: '✍️', title: 'Lignes de punition', subtitle: 'Punitions et progrès',
                  onTap: () { Navigator.pop(context); Navigator.push(context, SlidePageRoute(page: const PunishmentLinesScreen())); }),
              _drawerItem(context, emoji: '🛡️', title: 'Lignes d\'immunité', subtitle: 'Protections actives',
                  onTap: () { Navigator.pop(context); Navigator.push(context, SlidePageRoute(page: const ImmunityLinesScreen())); }),
              _drawerItem(context, emoji: '⚖️', title: 'Tribunal', subtitle: 'Affaires en cours',
                  onTap: () { Navigator.pop(context); Navigator.push(context, SlidePageRoute(page: const TribunalScreen())); }),
              _drawerItem(context, emoji: '🤝', title: 'Ventes d\'immunité', subtitle: 'Commerce entre enfants',
                  onTap: () { Navigator.pop(context); _showChildPicker(context, onSelected: (id) => Navigator.push(context, SlidePageRoute(page: TradeScreen(childId: id)))); }),
              _drawerItem(context, emoji: '🏆', title: 'Badges', subtitle: 'Récompenses et pouvoirs',
                  onTap: () { Navigator.pop(context); Navigator.push(context, SlidePageRoute(page: const BadgesScreen())); }),
              _drawerItem(context, emoji: '📺', title: 'Temps d\'écran', subtitle: 'Suivi samedi & dimanche',
                  onTap: () { Navigator.pop(context); PinGuard.guardAction(context, () => Navigator.push(context, SlidePageRoute(page: const ScreenTimeScreen()))); }),
              const Divider(color: Colors.white12, height: 1),
              _drawerSectionTitle('GESTION'),
              _drawerItem(context, emoji: '🔄', title: 'Synchronisation', subtitle: 'Gestion de la famille',
                  onTap: () { Navigator.pop(context); PinGuard.guardAction(context, () => Navigator.push(context, SlidePageRoute(page: const FamilyScreen()))); }),
              _drawerItem(context, emoji: '📜', title: 'Historique complet',
                  subtitle: '${_getTotalHistoryCount(familyProvider)} entrées',
                  onTap: () { Navigator.pop(context); _showFullHistory(context); }),
              if (isParent) ...[
                const Divider(color: Colors.white12, height: 1),
                _drawerSectionTitle('ADMINISTRATION', color: Colors.redAccent),
                _drawerItem(context, emoji: '👑', title: 'Panneau d\'administration',
                    subtitle: 'Gérer points, historique, données', titleColor: Colors.redAccent,
                    onTap: () { Navigator.pop(context); Navigator.push(context, SlidePageRoute(page: const ParentAdminScreen())); }),
              ],
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _drawerSectionTitle(String title, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(title, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold,
          color: color?.withOpacity(0.7) ?? Colors.white38, letterSpacing: 1.5)),
    );
  }

  Widget _drawerItem(BuildContext context, {
    required String emoji, required String title, required String subtitle, required VoidCallback onTap, Color? titleColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: TvFocusWrapper(
        onTap: onTap,
        child: GlassCard(
          onTap: onTap,
          child: ListTile(
            dense: true,
            leading: Text(emoji, style: const TextStyle(fontSize: 24)),
            title: Text(title, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: titleColor)),
            subtitle: Text(subtitle, style: const TextStyle(fontSize: 11, color: Colors.white54)),
            trailing: Icon(Icons.chevron_right, size: 18, color: titleColor?.withOpacity(0.5) ?? Colors.white24),
          ),
        ),
      ),
    );
  }

  int _getTotalHistoryCount(FamilyProvider provider) {
    int count = 0;
    for (final child in provider.sortedChildren) {
      count += provider.getHistoryForChild(child.id).length;
    }
    return count;
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final pinProvider = context.watch<PinProvider>();
    final isParent = pinProvider.canPerformParentAction();

    return AnimatedBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        drawer: _buildDrawer(context),
        body: FadeTransition(
          opacity: CurvedAnimation(parent: _transitionController, curve: Curves.easeInOut),
          child: _getScreen(_currentIndex),
        ),
        floatingActionButton: _currentIndex == 0
            ? ScaleTransition(
                scale: Tween<double>(begin: 0.95, end: 1.05).animate(
                    CurvedAnimation(parent: _fabController, curve: Curves.easeInOut)),
                child: FloatingActionButton.extended(
                  onPressed: () => _onTabTapped(1),
                  backgroundColor: themeProvider.primaryColor.withOpacity(0.8),
                  icon: const Icon(Icons.add, size: 28),
                  label: const Text('Points', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              )
            : null,
        floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
        bottomNavigationBar: _buildBottomBar(context, themeProvider, isParent),
      ),
    );
  }

  Widget _buildBottomBar(BuildContext context, ThemeProvider themeProvider, bool isParent) {
    final items = [
      _BottomNavItem(icon: Icons.home_rounded, label: 'Accueil', emoji: '🏠'),
      _BottomNavItem(icon: Icons.add_circle_outline, label: 'Points', emoji: '⭐'),
      _BottomNavItem(icon: Icons.calendar_month, label: 'Calendrier', emoji: '📅'),
      _BottomNavItem(icon: Icons.bar_chart_rounded, label: 'Stats', emoji: '📊'),
      _BottomNavItem(icon: Icons.settings, label: 'Réglages', emoji: '⚙️'),
    ];

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor.withOpacity(0.8),
        border: Border(top: BorderSide(color: Colors.white.withOpacity(0.05))),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(items.length, (index) {
              final item = items[index];
              final isSelected = _currentIndex == index;
              final isProtected = _protectedIndices.contains(index);
              return Expanded(
                child: TvFocusWrapper(
                  onTap: () => _onTabTapped(index),
                  child: InkWell(
                    onTap: () => _onTabTapped(index),
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Stack(
                            clipBehavior: Clip.none,
                            children: [
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 300),
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: isSelected ? themeProvider.primaryColor.withOpacity(0.2) : Colors.transparent,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(item.icon, size: 24,
                                    color: isSelected ? themeProvider.primaryColor : Colors.white38),
                              ),
                              if (isProtected && !isParent)
                                Positioned(
                                  right: -2, top: -2,
                                  child: Container(
                                    width: 14, height: 14,
                                    decoration: BoxDecoration(color: Colors.orange.withOpacity(0.8), shape: BoxShape.circle),
                                    child: const Center(child: Icon(Icons.lock, size: 8, color: Colors.white)),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(item.label,
                              style: TextStyle(fontSize: 10,
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                  color: isSelected ? themeProvider.primaryColor : Colors.white38)),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

class _BottomNavItem {
  final IconData icon;
  final String label;
  final String emoji;
  _BottomNavItem({required this.icon, required this.label, required this.emoji});
}
