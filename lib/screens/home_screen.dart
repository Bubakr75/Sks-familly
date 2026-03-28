import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/family_provider.dart';
import '../providers/pin_provider.dart';
import '../widgets/animated_background.dart';
import '../widgets/glass_card.dart';
import '../widgets/tv_focus_wrapper.dart';
import '../widgets/animated_page_transition.dart';
import 'dashboard_screen.dart';
import 'add_points_screen.dart';
import 'calendar_screen.dart';
import 'stats_screen.dart';
import 'settings_screen.dart';
import 'badges_screen.dart';
import 'school_notes_screen.dart';
import 'punishment_lines_screen.dart';
import 'immunity_lines_screen.dart';
import 'trade_screen.dart';
import 'child_dashboard_screen.dart';
import 'family_screen.dart';

class HomeScreen extends StatefulWidget {
  final String? parentName;
  const HomeScreen({super.key, this.parentName});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with TickerProviderStateMixin {
  int _currentIndex = 0;
  late AnimationController _navBarController;
  late Animation<Offset> _navBarSlide;

  final _protectedTabs = [1, 4]; // AddPoints, Settings

  @override
  void initState() {
    super.initState();
    _navBarController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _navBarSlide = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _navBarController,
      curve: Curves.easeOutCubic,
    ));
    _navBarController.forward();
  }

  @override
  void dispose() {
    _navBarController.dispose();
    super.dispose();
  }

  void _onTabSelected(int index) {
    if (_protectedTabs.contains(index)) {
      final pin = Provider.of<PinProvider>(context, listen: false);
      if (pin.hasPin && !pin.isParentMode) {
        _showPinCheck(() {
          pin.enterParentMode();
          setState(() => _currentIndex = index);
        });
        return;
      }
    }
    setState(() => _currentIndex = index);
  }

  void _showPinCheck(VoidCallback onSuccess) {
    final controller = TextEditingController();
    final pin = Provider.of<PinProvider>(context, listen: false);

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1A1A2E),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('🔒 PIN requis',
              style: TextStyle(color: Colors.white)),
          content: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            maxLength: 4,
            obscureText: true,
            autofocus: true,
            style: const TextStyle(
                color: Colors.white, fontSize: 28, letterSpacing: 10),
            textAlign: TextAlign.center,
            decoration: InputDecoration(
              counterText: '',
              hintText: '• • • •',
              hintStyle: const TextStyle(color: Colors.white24),
              enabledBorder: OutlineInputBorder(
                borderSide: BorderSide(color: Colors.cyan.withOpacity(0.3)),
                borderRadius: BorderRadius.circular(10),
              ),
              focusedBorder: OutlineInputBorder(
                borderSide: const BorderSide(color: Colors.cyan),
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annuler',
                  style: TextStyle(color: Colors.white54)),
            ),
            ElevatedButton(
              onPressed: () {
                if (pin.verifyPin(controller.text)) {
                  Navigator.pop(context);
                  onSuccess();
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('❌ PIN incorrect'),
                        backgroundColor: Colors.red),
                  );
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.cyan),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  Widget _getScreen() {
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

  @override
  Widget build(BuildContext context) {
    return Consumer<FamilyProvider>(
      builder: (context, fp, _) {
        return WillPopScope(
          onWillPop: () async {
            if (_currentIndex != 0) {
              setState(() => _currentIndex = 0);
              return false;
            }
            return true;
          },
          child: Scaffold(
            backgroundColor: Colors.transparent,
            drawer: _buildDrawer(fp),
            body: AnimatedSwitcher(
              duration: const Duration(milliseconds: 400),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              transitionBuilder: (child, animation) {
                return FadeTransition(
                  opacity: animation,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0.05, 0),
                      end: Offset.zero,
                    ).animate(animation),
                    child: child,
                  ),
                );
              },
              child: KeyedSubtree(
                key: ValueKey(_currentIndex),
                child: _getScreen(),
              ),
            ),
            bottomNavigationBar: SlideTransition(
              position: _navBarSlide,
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF0D1B2E).withOpacity(0.95),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.cyan.withOpacity(0.1),
                      blurRadius: 20,
                      offset: const Offset(0, -5),
                    ),
                  ],
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildNavItem(0, Icons.dashboard, 'Accueil'),
                        _buildNavItem(1, Icons.add_circle, 'Points'),
                        _buildNavItem(2, Icons.calendar_month, 'Calendrier'),
                        _buildNavItem(3, Icons.bar_chart, 'Stats'),
                        _buildNavItem(4, Icons.settings, 'Réglages'),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label) {
    final isSelected = _currentIndex == index;
    return TvFocusWrapper(
      onTap: () => _onTabSelected(index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
        padding: EdgeInsets.symmetric(
          horizontal: isSelected ? 16 : 10,
          vertical: 8,
        ),
        decoration: BoxDecoration(
          color: isSelected ? Colors.cyan.withOpacity(0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedScale(
              scale: isSelected ? 1.2 : 1.0,
              duration: const Duration(milliseconds: 300),
              child: Icon(
                icon,
                color: isSelected ? Colors.cyan : Colors.white38,
                size: 24,
              ),
            ),
            const SizedBox(height: 4),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 300),
              style: TextStyle(
                color: isSelected ? Colors.cyan : Colors.white38,
                fontSize: isSelected ? 11 : 10,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
              child: Text(label),
            ),
          ],
        ),
      ),
    );
  }

  Drawer _buildDrawer(FamilyProvider fp) {
    return Drawer(
      backgroundColor: const Color(0xFF0D1B2A),
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(20),
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.0, end: 1.0),
                duration: const Duration(milliseconds: 800),
                curve: Curves.elasticOut,
                builder: (context, value, child) {
                  return Transform.scale(scale: value, child: child);
                },
                child: Column(
                  children: [
                    const Text('👨‍👩‍👧‍👦', style: TextStyle(fontSize: 40)),
                    const SizedBox(height: 8),
                    ShaderMask(
                      shaderCallback: (bounds) => const LinearGradient(
                        colors: [Colors.cyan, Colors.purple],
                      ).createShader(bounds),
                      child: const Text(
                        'Family Points',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Text(
                      fp.activeParent ?? '',
                      style: const TextStyle(color: Colors.white38),
                    ),
                  ],
                ),
              ),
            ),
            const Divider(color: Colors.white12),

            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  // ★ Badges → ZoomPageRoute
                  _drawerItem(Icons.emoji_events, Colors.amber, 'Badges', () {
                    Navigator.pop(context);
                    Navigator.push(context, ZoomPageRoute(page: const BadgesScreen()));
                  }),

                  // ★ Notes Scolaires → SlidePageRoute
                  _drawerItem(Icons.school, Colors.blue, 'Notes Scolaires', () {
                    Navigator.pop(context);
                    _showChildPicker(fp, (childId) {
                      Navigator.push(context,
                          SlidePageRoute(page: SchoolNotesScreen(childId: childId)));
                    });
                  }),

                  // ★ Punition → SlidePageRoute UP
                  _drawerItem(Icons.menu_book, Colors.red, 'Lignes de Punition', () {
                    Navigator.pop(context);
                    Navigator.push(context, SlidePageRoute(
                      page: const PunishmentLinesScreen(),
                      direction: SlideDirection.up,
                    ));
                  }),

                  // ★ Immunité → SpinPageRoute
                  _drawerItem(Icons.shield, Colors.amber, 'Lignes d\'Immunité', () {
                    Navigator.pop(context);
                    Navigator.push(context,
                        SpinPageRoute(page: const ImmunityLinesScreen()));
                  }),

                  // ★ Ventes → DoorPageRoute
                  _drawerItem(Icons.store, Colors.green, 'Ventes / Échanges', () {
                    Navigator.pop(context);
                    Navigator.push(context,
                        DoorPageRoute(page: const TradeScreen()));
                  }),

                  // ★ Gérer Enfants → SlidePageRoute
                  _drawerItem(Icons.people, Colors.cyan, 'Gérer les Enfants', () {
                    Navigator.pop(context);
                    Navigator.push(context,
                        SlidePageRoute(page: const FamilyScreen()));
                  }),

                  // ★ Sync
                  _drawerItem(Icons.sync, Colors.teal, 'Synchronisation', () {
                    Navigator.pop(context);
                    fp.syncData();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('🔄 Synchronisation...'),
                        backgroundColor: Colors.teal,
                      ),
                    );
                  }),

                  // ★ Historique
                  _drawerItem(Icons.history, Colors.orange, 'Historique Complet', () {
                    Navigator.pop(context);
                    _showFullHistory(fp);
                  }),
                ],
              ),
            ),

            const Divider(color: Colors.white12),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text('v4.9.0',
                  style: TextStyle(color: Colors.white24, fontSize: 12)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _drawerItem(
      IconData icon, Color color, String label, VoidCallback onTap) {
    return TvFocusWrapper(
      onTap: onTap,
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color.withOpacity(0.15),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        title: Text(label,
            style: const TextStyle(color: Colors.white, fontSize: 14)),
        trailing:
            const Icon(Icons.chevron_right, color: Colors.white24, size: 18),
      ),
    );
  }

  void _showChildPicker(FamilyProvider fp, Function(String) onSelected) {
    if (fp.children.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Aucun enfant enregistré'),
            backgroundColor: Colors.orange),
      );
      return;
    }
    if (fp.children.length == 1) {
      onSelected(fp.children.first.id);
      return;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          decoration: const BoxDecoration(
            color: Color(0xFF1A1A2E),
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Choisir un enfant',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              ...fp.children.map((child) {
                return TvFocusWrapper(
                  onTap: () {
                    Navigator.pop(ctx);
                    onSelected(child.id);
                  },
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.cyan.withOpacity(0.3),
                      child: Text(
                        child.name.isNotEmpty ? child.name[0].toUpperCase() : '?',
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                    title: Text(child.name,
                        style: const TextStyle(color: Colors.white)),
                    subtitle: Text('${child.totalPoints} pts',
                        style: const TextStyle(color: Colors.white54)),
                  ),
                );
              }),
            ],
          ),
        );
      },
    );
  }

  void _showFullHistory(FamilyProvider fp) {
    final allHistory = <Map<String, dynamic>>[];
    for (final child in fp.children) {
      for (final h in fp.getHistoryForChild(child.id)) {
        allHistory.add({...h, 'childName': child.name});
      }
    }
    allHistory.sort((a, b) =>
        (b['timestamp'] as DateTime).compareTo(a['timestamp'] as DateTime));

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.85,
          builder: (context, scrollController) {
            return Container(
              decoration: const BoxDecoration(
                color: Color(0xFF1A1A2E),
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 12),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('📋 Historique Complet',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold)),
                  ),
                  Expanded(
                    child: ListView.builder(
                      controller: scrollController,
                      itemCount: allHistory.length,
                      itemBuilder: (context, index) {
                        final h = allHistory[index];
                        final pts = h['points'] as int? ?? 0;
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: pts >= 0
                                ? Colors.green.withOpacity(0.2)
                                : Colors.red.withOpacity(0.2),
                            child: Text(
                              pts >= 0 ? '+$pts' : '$pts',
                              style: TextStyle(
                                color: pts >= 0 ? Colors.green : Colors.red,
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                              ),
                            ),
                          ),
                          title: Text(h['reason'] ?? '',
                              style: const TextStyle(color: Colors.white)),
                          subtitle: Text(
                            '${h['childName']} • ${h['category'] ?? ''}',
                            style: const TextStyle(
                                color: Colors.white54, fontSize: 11),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
