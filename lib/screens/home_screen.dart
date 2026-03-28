import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'dashboard_screen.dart';
import 'add_points_screen.dart';
import 'calendar_screen.dart';
import 'stats_screen.dart';
import 'settings_screen.dart';
import 'welcome_screen.dart';
import 'pin_verification_screen.dart';
import 'school_notes_screen.dart';
import 'tribunal_screen.dart';
import 'punishment_lines_screen.dart';
import 'immunity_lines_screen.dart';
import 'manage_children_screen.dart';
import 'badges_screen.dart';
import 'notes_screen.dart';
import '../providers/family_provider.dart';
import '../providers/pin_provider.dart';
import '../models/history_entry.dart';
import '../widgets/animated_background.dart';
import '../widgets/glass_card.dart';
import '../widgets/tv_focus_wrapper.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  int _currentIndex = 0;
  late AnimationController _animController;
  late Animation<Offset> _slideAnim;
  final Set<int> _protectedTabs = {1, 4};

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animController, curve: Curves.easeOut));
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _onTabSelected(int index) {
    final pinProvider = Provider.of<PinProvider>(context, listen: false);
    if (_protectedTabs.contains(index) && pinProvider.pin != null && pinProvider.pin!.isNotEmpty && !pinProvider.isParentMode) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const PinVerificationScreen()),
      ).then((success) {
        if (success == true) {
          setState(() => _currentIndex = index);
          _refreshActivity();
        }
      });
    } else {
      setState(() => _currentIndex = index);
      _refreshActivity();
    }
  }

  void _refreshActivity() {
    Provider.of<FamilyProvider>(context, listen: false).notifyListeners();
  }

  Future<bool> _onWillPop() async {
    if (_currentIndex != 0) {
      setState(() => _currentIndex = 0);
      return false;
    }
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const WelcomeScreen()),
    );
    return false;
  }

  Widget _buildBody() {
    switch (_currentIndex) {
      case 0:
        return const DashboardScreen();
      case 1:
        return const AddPointsScreen();
      case 2:
        return const CalendarScreen();
      case 3:
        return const StatsScreen();
      case 4:
        return const SettingsScreen();
      default:
        return const DashboardScreen();
    }
  }

  void _showChildPickerForSchoolNotes() {
    final provider = Provider.of<FamilyProvider>(context, listen: false);
    final children = provider.children;
    if (children.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Aucun enfant enregistré')),
      );
      return;
    }
    if (children.length == 1) {
      Navigator.push(context, MaterialPageRoute(
        builder: (_) => SchoolNotesScreen(childId: children.first.id),
      ));
      return;
    }
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.grey[900]!.withOpacity(0.95),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Choisir un enfant', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            ...children.map((child) => TvFocusWrapper(
              autofocus: child == children.first,
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.blue,
                  child: Text(child.name[0], style: const TextStyle(color: Colors.white)),
                ),
                title: Text(child.name, style: const TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(ctx);
                  Navigator.push(context, MaterialPageRoute(
                    builder: (_) => SchoolNotesScreen(childId: child.id),
                  ));
                },
              ),
            )),
          ],
        ),
      ),
    );
  }

  void _showChildPickerForNotes() {
    final provider = Provider.of<FamilyProvider>(context, listen: false);
    final children = provider.children;
    if (children.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Aucun enfant enregistré')),
      );
      return;
    }
    if (children.length == 1) {
      Navigator.push(context, MaterialPageRoute(
        builder: (_) => NotesScreen(childId: children.first.id, childName: children.first.name),
      ));
      return;
    }
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.grey[900]!.withOpacity(0.95),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Choisir un enfant', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            ...children.map((child) => TvFocusWrapper(
              autofocus: child == children.first,
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.purple,
                  child: Text(child.name[0], style: const TextStyle(color: Colors.white)),
                ),
                title: Text(child.name, style: const TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(ctx);
                  Navigator.push(context, MaterialPageRoute(
                    builder: (_) => NotesScreen(childId: child.id, childName: child.name),
                  ));
                },
              ),
            )),
          ],
        ),
      ),
    );
  }

  void _showFullHistory() {
    final provider = Provider.of<FamilyProvider>(context, listen: false);
    final allHistory = provider.history;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        height: MediaQuery.of(ctx).size.height * 0.8,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.grey[900]!.withOpacity(0.95),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Historique complet', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                TvFocusWrapper(
                  autofocus: true,
                  child: IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: allHistory.isEmpty
                  ? const Center(child: Text('Aucun historique', style: TextStyle(color: Colors.white54)))
                  : ListView.builder(
                      itemCount: allHistory.length,
                      itemBuilder: (_, i) {
                        final HistoryEntry activity = allHistory[i];
                        final childName = provider.children
                            .where((c) => c.id == activity.childId)
                            .map((c) => c.name)
                            .firstOrNull ?? 'Inconnu';
                        final points = activity.points;
                        final reason = activity.reason;
                        final date = activity.date;
                        final isPositive = activity.isBonus;
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                isPositive ? Icons.arrow_upward : Icons.arrow_downward,
                                color: isPositive ? Colors.green : Colors.red,
                                size: 20,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(childName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                                    const SizedBox(height: 2),
                                    Text(reason, style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 12)),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}',
                                      style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 10),
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                '${isPositive ? '+' : '-'}$points',
                                style: TextStyle(
                                  color: isPositive ? Colors.green : Colors.red,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  void _navigateToScreen(Widget screen) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
  }

  void _navigateWithPinGuard(Widget screen) {
    final pinProvider = Provider.of<PinProvider>(context, listen: false);
    if (pinProvider.pin != null && pinProvider.pin!.isNotEmpty && !pinProvider.isParentMode) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const PinVerificationScreen()),
      ).then((success) {
        if (success == true) {
          _navigateToScreen(screen);
        }
      });
    } else {
      _navigateToScreen(screen);
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        drawer: _buildDrawer(),
        body: _buildBody(),
        bottomNavigationBar: SlideTransition(
          position: _slideAnim,
          child: Container(
            margin: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.6),
              borderRadius: BorderRadius.circular(25),
              border: Border.all(color: Colors.white.withOpacity(0.1)),
              boxShadow: [
                BoxShadow(
                  color: Colors.blue.withOpacity(0.1),
                  blurRadius: 20,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildNavItem(0, Icons.home_rounded, 'Accueil'),
                  _buildNavItem(1, Icons.add_circle_rounded, 'Points'),
                  _buildNavItem(2, Icons.calendar_month_rounded, 'Calendrier'),
                  _buildNavItem(3, Icons.bar_chart_rounded, 'Stats'),
                  _buildNavItem(4, Icons.settings_rounded, 'Réglages'),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label) {
    final isSelected = _currentIndex == index;
    return TvFocusWrapper(
      autofocus: index == 0,
      child: GestureDetector(
        onTap: () => _onTabSelected(index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? Colors.blue.withOpacity(0.3) : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
            border: isSelected
                ? Border.all(color: Colors.blue.withOpacity(0.5), width: 1)
                : null,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                color: isSelected ? Colors.blue[300] : Colors.white54,
                size: isSelected ? 26 : 22,
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? Colors.blue[300] : Colors.white54,
                  fontSize: 10,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDrawer() {
    return Drawer(
      backgroundColor: Colors.grey[900]!.withOpacity(0.95),
      child: SafeArea(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  const Icon(Icons.family_restroom, color: Colors.blue, size: 48),
                  const SizedBox(height: 8),
                  const Text(
                    'SKS Family',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Consumer<FamilyProvider>(
                    builder: (_, provider, __) => Text(
                      provider.isSyncEnabled ? 'Connecté' : 'Hors ligne',
                      style: TextStyle(
                        color: provider.isSyncEnabled ? Colors.green[300] : Colors.orange[300],
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(color: Colors.white24),
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  _buildDrawerItem(
                    icon: Icons.emoji_events_rounded,
                    title: 'Badges',
                    subtitle: 'Gérer les badges',
                    onTap: () {
                      Navigator.pop(context);
                      _navigateWithPinGuard(const BadgesScreen());
                    },
                  ),
                  _buildDrawerItem(
                    icon: Icons.school_rounded,
                    title: 'Notes scolaires',
                    subtitle: 'Ajouter des notes',
                    onTap: () {
                      Navigator.pop(context);
                      _showChildPickerForSchoolNotes();
                    },
                  ),
                  _buildDrawerItem(
                    icon: Icons.gavel_rounded,
                    title: 'Tribunal',
                    subtitle: 'Gestion des cas',
                    onTap: () {
                      Navigator.pop(context);
                      _navigateWithPinGuard(const TribunalScreen());
                    },
                  ),
                  _buildDrawerItem(
                    icon: Icons.edit_document,
                    title: 'Lignes de punition',
                    subtitle: 'Punitions à copier',
                    onTap: () {
                      Navigator.pop(context);
                      _navigateWithPinGuard(const PunishmentLinesScreen());
                    },
                  ),
                  _buildDrawerItem(
                    icon: Icons.shield_rounded,
                    title: "Lignes d'immunité",
                    subtitle: 'Boucliers protecteurs',
                    onTap: () {
                      Navigator.pop(context);
                      _navigateWithPinGuard(const ImmunityLinesScreen());
                    },
                  ),
                  _buildDrawerItem(
                    icon: Icons.people_rounded,
                    title: 'Gérer les enfants',
                    subtitle: 'Ajouter / modifier',
                    onTap: () {
                      Navigator.pop(context);
                      _navigateWithPinGuard(const ManageChildrenScreen());
                    },
                  ),
                  _buildDrawerItem(
                    icon: Icons.note_alt_rounded,
                    title: 'Notes',
                    subtitle: 'Notes personnelles',
                    onTap: () {
                      Navigator.pop(context);
                      _showChildPickerForNotes();
                    },
                  ),
                  _buildDrawerItem(
                    icon: Icons.sync_rounded,
                    title: 'Synchronisation',
                    subtitle: 'Reconnecter Firestore',
                    onTap: () {
                      Navigator.pop(context);
                      final provider = Provider.of<FamilyProvider>(context, listen: false);
                      provider.reconnectFirestore();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Reconnexion Firestore lancée...')),
                      );
                    },
                  ),
                  _buildDrawerItem(
                    icon: Icons.history_rounded,
                    title: 'Historique complet',
                    subtitle: 'Toutes les activités',
                    onTap: () {
                      Navigator.pop(context);
                      _showFullHistory();
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawerItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return TvFocusWrapper(
      child: ListTile(
        leading: Icon(icon, color: Colors.blue[300], size: 24),
        title: Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle, style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12)),
        trailing: Icon(Icons.chevron_right, color: Colors.white.withOpacity(0.3)),
        onTap: onTap,
      ),
    );
  }
}
