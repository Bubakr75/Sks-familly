import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/family_provider.dart';
import '../providers/pin_provider.dart';
import '../utils/pin_guard.dart';
import '../widgets/glass_card.dart';
import '../screens/dashboard_screen.dart';
import '../screens/add_points_screen.dart';
import '../screens/calendar_screen.dart';
import '../screens/stats_screen.dart';
import '../screens/settings_screen.dart';
import '../screens/pin_verification_screen.dart';
import '../screens/badges_screen.dart';

import '../screens/punishment_lines_screen.dart';
import '../screens/manage_children_screen.dart';
import '../screens/family_screen.dart';
import '../screens/notes_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  int _currentIndex = 0;
  late AnimationController _navAnimController;
  late Animation<double> _navSlideAnim;

  static const _protectedTabs = {1, 4};

  @override
  void initState() {
    super.initState();
    _navAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _navSlideAnim = CurvedAnimation(
      parent: _navAnimController,
      curve: Curves.easeOutCubic,
    );
    _navAnimController.forward();
  }

  @override
  void dispose() {
    _navAnimController.dispose();
    super.dispose();
  }

  void _onTabSelected(int index) {
    final pin = context.read<PinProvider>();
    if (_protectedTabs.contains(index) && pin.isPinSet && !pin.isParentMode) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PinVerificationScreen(
            onVerified: () {
              Navigator.pop(context);
              setState(() => _currentIndex = index);
            },
          ),
        ),
      );
      return;
    }
    if (pin.isParentMode) pin.refreshActivity();
    setState(() => _currentIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    final pin = context.watch<PinProvider>();
    final provider = context.watch<FamilyProvider>();
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;

    return Scaffold(
      backgroundColor: const Color(0xFF0A0E21),
      drawer: _buildDrawer(context, provider, pin, primary),
      body: Stack(
        children: [
          // Main content
          _buildBody(),
          // Glassmorphism bottom nav bar
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 1),
                end: Offset.zero,
              ).animate(_navSlideAnim),
              child: _buildGlassNavBar(pin, primary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGlassNavBar(PinProvider pin, Color primary) {
    final items = [
      _NavItem(Icons.home_outlined, Icons.home_rounded, 'Accueil'),
      _NavItem(Icons.add_circle_outline, Icons.add_circle_rounded, 'Points', locked: pin.isPinSet && !pin.isParentMode),
      _NavItem(Icons.calendar_month_outlined, Icons.calendar_month_rounded, 'Calendrier'),
      _NavItem(Icons.bar_chart_outlined, Icons.bar_chart_rounded, 'Stats'),
      _NavItem(Icons.settings_outlined, Icons.settings_rounded, 'Reglages', locked: pin.isPinSet && !pin.isParentMode),
    ];

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            height: 72,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              color: const Color(0xFF0A0E21).withValues(alpha: 0.85),
              border: Border.all(
                color: primary.withValues(alpha: 0.15),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: primary.withValues(alpha: 0.08),
                  blurRadius: 20,
                  spreadRadius: -5,
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: items.asMap().entries.map((entry) {
                final i = entry.key;
                final item = entry.value;
                final isSelected = _currentIndex == i;

                return Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => _onTabSelected(i),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeOutCubic,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Stack(
                            clipBehavior: Clip.none,
                            children: [
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 250),
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(14),
                                  color: isSelected
                                      ? primary.withValues(alpha: 0.15)
                                      : Colors.transparent,
                                ),
                                child: Icon(
                                  isSelected ? item.activeIcon : item.icon,
                                  size: isSelected ? 26 : 24,
                                  color: isSelected ? primary : Colors.grey[600],
                                  shadows: isSelected
                                      ? [Shadow(color: primary.withValues(alpha: 0.5), blurRadius: 8)]
                                      : null,
                                ),
                              ),
                              if (item.locked)
                                Positioned(
                                  right: 2,
                                  top: 2,
                                  child: Container(
                                    width: 12,
                                    height: 12,
                                    decoration: BoxDecoration(
                                      color: Colors.orange,
                                      shape: BoxShape.circle,
                                      border: Border.all(color: const Color(0xFF0A0E21), width: 1.5),
                                    ),
                                    child: const Icon(Icons.lock, size: 7, color: Colors.white),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            item.label,
                            style: TextStyle(
                              fontSize: isSelected ? 10 : 9,
                              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                              color: isSelected ? primary : Colors.grey[600],
                              shadows: isSelected
                                  ? [Shadow(color: primary.withValues(alpha: 0.4), blurRadius: 6)]
                                  : null,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDrawer(BuildContext context, FamilyProvider provider, PinProvider pin, Color primary) {
    return Drawer(
      backgroundColor: const Color(0xFF0D1B2A),
      child: SafeArea(
        child: Column(
          children: [
            // Header with gradient and glow
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFF0A0E21),
                    primary.withValues(alpha: 0.15),
                    const Color(0xFF0D1B2A),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Logo with neon glow
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [primary, primary.withValues(alpha: 0.6)]),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(color: primary.withValues(alpha: 0.4), blurRadius: 16, spreadRadius: -2),
                      ],
                    ),
                    child: const Text('SKS', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 22, letterSpacing: 2)),
                  ),
                  const SizedBox(height: 16),
                  NeonText(
                    text: 'SKS Family',
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    glowIntensity: 0.3,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${provider.children.length} enfants - ${provider.history.length} activites',
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 13),
                  ),
                  const SizedBox(height: 10),
                  // Sync status chip
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: provider.isSyncEnabled
                          ? const Color(0xFF00E676).withValues(alpha: 0.12)
                          : Colors.grey.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: provider.isSyncEnabled
                            ? const Color(0xFF00E676).withValues(alpha: 0.3)
                            : Colors.grey.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          provider.isSyncEnabled ? Icons.cloud_done : Icons.cloud_off,
                          size: 14,
                          color: provider.isSyncEnabled ? const Color(0xFF00E676) : Colors.grey,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          provider.isSyncEnabled ? 'Synchronise' : 'Mode local',
                          style: TextStyle(
                            color: provider.isSyncEnabled ? const Color(0xFF00E676) : Colors.grey,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Menu items
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: [
                  _DrawerItem(
                    icon: Icons.emoji_events_rounded,
                    label: 'Badges',
                    color: const Color(0xFFFFD740),
                    subtitle: '${provider.children.fold<int>(0, (s, c) => s + c.badgeIds.length)} obtenus',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(context, _glassRoute(const BadgesScreen()));
                    },
                  ),

                  _DrawerItem(
                    icon: Icons.edit_note_rounded,
                    label: 'Lignes de punition',
                    color: const Color(0xFFFF1744),
                    subtitle: '${provider.punishments.where((p) => !p.isCompleted).length} en cours',
                    onTap: () {
                      Navigator.pop(context);
                      PinGuard.guardNavigation(context, const PunishmentLinesScreen());
                    },
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    child: Divider(color: Colors.white.withValues(alpha: 0.06)),
                  ),
                  _DrawerItem(
                    icon: Icons.people_alt_rounded,
                    label: 'Gerer les enfants',
                    color: const Color(0xFF00E5FF),
                    subtitle: '${provider.children.length} enfants',
                    onTap: () {
                      Navigator.pop(context);
                      PinGuard.guardNavigation(context, const ManageChildrenScreen());
                    },
                  ),
                  _DrawerItem(
                    icon: Icons.sticky_note_2_rounded,
                    label: 'Notes',
                    color: const Color(0xFFFFD740),
                    subtitle: '${provider.notes.length} notes',
                    onTap: () {
                      Navigator.pop(context);
                      if (provider.children.isNotEmpty) {
                        _showNotesChildPicker(context, provider);
                      }
                    },
                  ),
                  _DrawerItem(
                    icon: provider.isSyncEnabled ? Icons.cloud_done_rounded : Icons.cloud_off_rounded,
                    label: 'Synchronisation',
                    color: provider.isSyncEnabled ? const Color(0xFF00E676) : Colors.grey,
                    subtitle: provider.isSyncEnabled ? 'Connecte au cloud' : 'Mode local',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(context, _glassRoute(const FamilyScreen()));
                    },
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    child: Divider(color: Colors.white.withValues(alpha: 0.06)),
                  ),
                  _DrawerItem(
                    icon: Icons.history_rounded,
                    label: 'Historique complet',
                    color: const Color(0xFF7C4DFF),
                    subtitle: '${provider.history.length} activites',
                    onTap: () {
                      Navigator.pop(context);
                      _showFullHistoryPage(context, provider);
                    },
                  ),
                ],
              ),
            ),

            // Footer
            Container(
              padding: const EdgeInsets.all(16),
              child: Text(
                'SKS Family v4.2.0',
                style: TextStyle(color: Colors.grey[700], fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  PageRouteBuilder _glassRoute(Widget page) {
    return PageRouteBuilder(
      pageBuilder: (_, __, ___) => page,
      transitionsBuilder: (_, anim, __, child) {
        return FadeTransition(
          opacity: CurvedAnimation(parent: anim, curve: Curves.easeOut),
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0.05, 0),
              end: Offset.zero,
            ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
            child: child,
          ),
        );
      },
      transitionDuration: const Duration(milliseconds: 350),
    );
  }

  void _showFullHistoryPage(BuildContext context, FamilyProvider provider) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF0D1B2A),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.8,
        expand: false,
        builder: (_, sc) => Column(
          children: [
            const SizedBox(height: 12),
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[700], borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 12),
            NeonText(text: 'Historique complet', fontSize: 18, color: Colors.white),
            const SizedBox(height: 8),
            Expanded(
              child: provider.history.isEmpty
                  ? Center(child: Text('Aucune activite', style: TextStyle(color: Colors.grey[600])))
                  : ListView.builder(
                      controller: sc,
                      itemCount: provider.history.length,
                      itemBuilder: (_, i) {
                        final h = provider.history[i];
                        final child = provider.getChild(h.childId);
                        return ListTile(
                          leading: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: h.isBonus
                                  ? const Color(0xFF00E676).withValues(alpha: 0.12)
                                  : const Color(0xFFFF1744).withValues(alpha: 0.12),
                              border: Border.all(
                                color: h.isBonus
                                    ? const Color(0xFF00E676).withValues(alpha: 0.3)
                                    : const Color(0xFFFF1744).withValues(alpha: 0.3),
                              ),
                            ),
                            child: Icon(
                              h.isBonus ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
                              color: h.isBonus ? const Color(0xFF00E676) : const Color(0xFFFF1744),
                              size: 20,
                            ),
                          ),
                          title: Text(child?.name ?? 'Inconnu', style: const TextStyle(color: Colors.white)),
                          subtitle: Text(
                            '${h.reason}\n${h.date.day}/${h.date.month}/${h.date.year} ${h.date.hour}:${h.date.minute.toString().padLeft(2, '0')}',
                            style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                          ),
                          trailing: Container(
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
                          isThreeLine: true,
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  void _showNotesChildPicker(BuildContext context, FamilyProvider provider) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF141833),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[700], borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 16),
            NeonText(text: 'Choisir un enfant', fontSize: 18, color: Colors.white),
            const SizedBox(height: 16),
            ...provider.children.map((child) => ListTile(
              leading: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(child: Text(child.avatar.isEmpty ? '\u{1F466}' : child.avatar, style: const TextStyle(fontSize: 22))),
              ),
              title: Text(child.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
              subtitle: Text(
                '${provider.getNotesForChild(child.id).length} notes',
                style: TextStyle(color: Colors.grey[500], fontSize: 12),
              ),
              trailing: Icon(Icons.chevron_right, color: Colors.grey[600]),
              onTap: () {
                Navigator.pop(ctx);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => NotesScreen(childId: child.id, childName: child.name),
                  ),
                );
              },
            )),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
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
}

class _NavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool locked;
  const _NavItem(this.icon, this.activeIcon, this.label, {this.locked = false});
}

class _DrawerItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _DrawerItem({
    required this.icon,
    required this.label,
    required this.color,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.2)),
          boxShadow: [
            BoxShadow(color: color.withValues(alpha: 0.1), blurRadius: 8, spreadRadius: -2),
          ],
        ),
        child: Icon(icon, color: color, size: 22),
      ),
      title: Text(label, style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.white)),
      subtitle: Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
      trailing: Icon(Icons.chevron_right, size: 20, color: Colors.grey[700]),
      onTap: onTap,
    );
  }
}
