import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../providers/family_provider.dart';
import '../providers/pin_provider.dart';
import '../widgets/animated_background.dart';
import '../widgets/glass_card.dart';
import '../widgets/tv_focus_wrapper.dart';

import 'dashboard_screen.dart';
import 'add_points_screen.dart';
import 'calendar_screen.dart';
import 'stats_screen.dart';
import 'settings_screen.dart';
import 'badge_screen.dart';
import 'school_notes_screen.dart';
import 'punishment_lines_screen.dart';
import 'immunity_lines_screen.dart';
import 'tribunal_screen.dart';
import 'trade_screen.dart';
import 'family_screen.dart';
import 'child_dashboard_screen.dart';
import '../widgets/animated_page_transition.dart';

class HomeScreen extends StatefulWidget {
  final String parentName;
  const HomeScreen({Key? key, this.parentName = 'Parent'}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  int _currentIndex = 0;
  late AnimationController _navBarController;

  // Indices protégés par PIN : 1 (Points), 4 (Réglages)
  final List<int> _protectedIndices = [1, 4];

  @override
  void initState() {
    super.initState();
    _navBarController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..forward();
  }

  @override
  void dispose() {
    _navBarController.dispose();
    super.dispose();
  }

  // ─── Écran selon l'onglet ─────────────────────────────────────
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

  // ─── Gestion du changement d'onglet avec PIN ─────────────────
  void _onTabTapped(int index) {
    if (_protectedIndices.contains(index)) {
      final pinProvider = context.read<PinProvider>();
      if (pinProvider.isPinSet && !pinProvider.isParentMode) {
        _showPinCheck(() {
          setState(() => _currentIndex = index);
        });
        return;
      }
    }
    setState(() => _currentIndex = index);
  }

  // ─── Dialog PIN ───────────────────────────────────────────────
  void _showPinCheck(VoidCallback onSuccess) {
    final pinController = TextEditingController();
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1A1A2E),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text(
            '🔒 Code Parental',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Entrez votre code PIN pour accéder à cette section.',
                style: TextStyle(color: Colors.white70, fontSize: 14),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: pinController,
                obscureText: true,
                keyboardType: TextInputType.number,
                maxLength: 6,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  letterSpacing: 8,
                ),
                textAlign: TextAlign.center,
                decoration: InputDecoration(
                  counterText: '',
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.1),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  hintText: '• • • •',
                  hintStyle: TextStyle(
                    color: Colors.white.withValues(alpha: 0.3),
                    fontSize: 24,
                    letterSpacing: 8,
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Annuler', style: TextStyle(color: Colors.white54)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.cyanAccent,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () {
                final pin = pinController.text.trim();
                final pinProvider = context.read<PinProvider>();
                if (pinProvider.checkPin(pin)) {
                  pinProvider.enterParentMode();
                  Navigator.pop(ctx);
                  onSuccess();
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text('❌ Code PIN incorrect'),
                      backgroundColor: Colors.red.shade700,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  );
                }
              },
              child: const Text('Valider', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  // ─── Child Picker ─────────────────────────────────────────────
  void _showChildPicker(BuildContext context, void Function(dynamic child) onSelected) {
    final provider = context.read<FamilyProvider>();
    final children = provider.children;
    if (children.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Aucun enfant enregistré'),
          backgroundColor: Colors.orange.shade700,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }
    if (children.length == 1) {
      onSelected(children.first);
      return;
    }
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          decoration: const BoxDecoration(
            color: Color(0xFF1A1A2E),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Choisir un enfant',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              ...children.map((child) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: TvFocusWrapper(
                    onTap: () {
                      Navigator.pop(ctx);
                      onSelected(child);
                    },
                    child: GlassCard(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      borderRadius: 14,
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 20,
                            backgroundColor: Colors.cyanAccent.withValues(alpha: 0.2),
                            child: Text(
                              child.name.isNotEmpty ? child.name[0].toUpperCase() : '?',
                              style: const TextStyle(
                                color: Colors.cyanAccent,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              child.name,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          Text(
                            '${child.points} pts',
                            style: const TextStyle(
                              color: Colors.cyanAccent,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  // ─── Historique complet ───────────────────────────────────────
  void _showFullHistory(BuildContext context) {
    final provider = context.read<FamilyProvider>();
    final history = provider.history.reversed.toList();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          maxChildSize: 0.95,
          minChildSize: 0.4,
          builder: (_, scrollController) {
            return Container(
              decoration: const BoxDecoration(
                color: Color(0xFF1A1A2E),
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                children: [
                  const SizedBox(height: 12),
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    '📜 Historique Complet',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${history.length} entrée(s)',
                    style: const TextStyle(color: Colors.white54, fontSize: 13),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: history.isEmpty
                        ? const Center(
                            child: Text(
                              'Aucun historique pour le moment',
                              style: TextStyle(color: Colors.white38),
                            ),
                          )
                        : ListView.builder(
                            controller: scrollController,
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            itemCount: history.length,
                            itemBuilder: (_, i) {
                              final entry = history[i];
                              final isPositive = entry.points >= 0;
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: GlassCard(
                                  padding: const EdgeInsets.all(12),
                                  borderRadius: 12,
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 44,
                                        height: 44,
                                        decoration: BoxDecoration(
                                          color: (isPositive ? Colors.green : Colors.red)
                                              .withValues(alpha: 0.15),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        alignment: Alignment.center,
                                        child: Text(
                                          '${isPositive ? '+' : ''}${entry.points}',
                                          style: TextStyle(
                                            color: isPositive ? Colors.greenAccent : Colors.redAccent,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              entry.reason,
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.w600,
                                                fontSize: 14,
                                              ),
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              _formatDateTime(entry.date),
                                              style: const TextStyle(
                                                color: Colors.white38,
                                                fontSize: 11,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      if (entry.category.isNotEmpty)
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.cyanAccent.withValues(alpha: 0.15),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Text(
                                            entry.category,
                                            style: const TextStyle(
                                              color: Colors.cyanAccent,
                                              fontSize: 10,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
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

  // ─── Format date helper ───────────────────────────────────────
  String _formatDateTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return "À l'instant";
    if (diff.inMinutes < 60) return 'Il y a ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'Il y a ${diff.inHours}h';
    if (diff.inDays < 7) return 'Il y a ${diff.inDays}j';
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
  }

  // ─── BUILD ────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBody: true,
      drawer: _buildDrawer(context),
      body: AnimatedBackground(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 400),
          switchInCurve: Curves.easeOut,
          switchOutCurve: Curves.easeIn,
          transitionBuilder: (child, animation) {
            return FadeTransition(
              opacity: animation,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0.03, 0),
                  end: Offset.zero,
                ).animate(animation),
                child: child,
              ),
            );
          },
          child: KeyedSubtree(
            key: ValueKey<int>(_currentIndex),
            child: _getScreen(),
          ),
        ),
      ),
      bottomNavigationBar: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 1),
          end: Offset.zero,
        ).animate(CurvedAnimation(
          parent: _navBarController,
          curve: Curves.easeOutCubic,
        )),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF0D1B2E).withValues(alpha: 0.95),
            border: Border(
              top: BorderSide(
                color: Colors.cyanAccent.withValues(alpha: 0.15),
                width: 0.5,
              ),
            ),
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: List.generate(5, (i) {
                  final isSelected = _currentIndex == i;
                  final icons = [
                    Icons.home_rounded,
                    Icons.stars_rounded,
                    Icons.calendar_month_rounded,
                    Icons.bar_chart_rounded,
                    Icons.settings_rounded,
                  ];
                  final labels = [
                    'Accueil',
                    'Points',
                    'Calendrier',
                    'Stats',
                    'Réglages',
                  ];
                  return TvFocusWrapper(
                    onTap: () => _onTabTapped(i),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeOut,
                      padding: EdgeInsets.symmetric(
                        horizontal: isSelected ? 16 : 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? Colors.cyanAccent.withValues(alpha: 0.12)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          AnimatedScale(
                            scale: isSelected ? 1.2 : 1.0,
                            duration: const Duration(milliseconds: 200),
                            child: Icon(
                              icons[i],
                              color: isSelected ? Colors.cyanAccent : Colors.white38,
                              size: 24,
                            ),
                          ),
                          const SizedBox(height: 4),
                          AnimatedDefaultTextStyle(
                            duration: const Duration(milliseconds: 200),
                            style: TextStyle(
                              color: isSelected ? Colors.cyanAccent : Colors.white38,
                              fontSize: isSelected ? 11 : 10,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            ),
                            child: Text(labels[i]),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ─── DRAWER ───────────────────────────────────────────────────
  Widget _buildDrawer(BuildContext context) {
    final provider = context.read<FamilyProvider>();
    const drawerBg = Color(0xFF0D1B2E);
    const accentColor = Colors.cyanAccent;

    return Drawer(
      backgroundColor: drawerBg,
      child: SafeArea(
        child: Column(
          children: [
            // ── Header ──
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    accentColor.withValues(alpha: 0.15),
                    Colors.transparent,
                  ],
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          accentColor.withValues(alpha: 0.3),
                          accentColor.withValues(alpha: 0.1),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: accentColor.withValues(alpha: 0.2),
                          blurRadius: 12,
                        ),
                      ],
                    ),
                    alignment: Alignment.center,
                    child: const Icon(
                      Icons.family_restroom_rounded,
                      color: accentColor,
                      size: 28,
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Family Rewards',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.parentName,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.6),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),

            Divider(color: Colors.white.withValues(alpha: 0.08), height: 1),

            // ── Menu items ──
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: [
                  _drawerItem(
                    icon: Icons.school_rounded,
                    label: 'Notes Scolaires',
                    color: Colors.orangeAccent,
                    onTap: () {
                      Navigator.pop(context);
                      _showChildPicker(context, (child) {
                        Navigator.push(
                          context,
                          SlidePageRoute(page: SchoolNotesScreen(child: child)),
                        );
                      });
                    },
                  ),
                  _drawerItem(
                    icon: Icons.edit_document,
                    label: 'Lignes de Punition',
                    color: Colors.redAccent,
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        SlidePageRoute(page: const PunishmentLinesScreen()),
                      );
                    },
                  ),
                  _drawerItem(
                    icon: Icons.shield_rounded,
                    label: "Lignes d'Immunité",
                    color: Colors.amberAccent,
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        SlidePageRoute(page: const ImmunityLinesScreen()),
                      );
                    },
                  ),
                  _drawerItem(
                    icon: Icons.gavel_rounded,
                    label: 'Tribunal',
                    color: Colors.purpleAccent,
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        DoorPageRoute(page: const TribunalScreen()),
                      );
                    },
                  ),
                  _drawerItem(
                    icon: Icons.sell_rounded,
                    label: "Vente d'immunités",
                    color: Colors.tealAccent,
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        DoorPageRoute(page: const TradeScreen()),
                      );
                    },
                  ),
                  _drawerItem(
                    icon: Icons.emoji_events_rounded,
                    label: 'Badges',
                    color: Colors.yellowAccent,
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        ZoomPageRoute(page: const BadgeScreen()),
                      );
                    },
                  ),
                  _drawerItem(
                    icon: Icons.sync_rounded,
                    label: 'Synchronisation',
                    color: Colors.lightBlueAccent,
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        SlidePageRoute(page: const FamilyScreen()),
                      );
                    },
                  ),
                  _drawerItem(
                    icon: Icons.history_rounded,
                    label: 'Historique Complet',
                    color: Colors.white70,
                    onTap: () {
                      Navigator.pop(context);
                      _showFullHistory(context);
                    },
                  ),
                ],
              ),
            ),

            // ── Version footer ──
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'v4.9.0',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.2),
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _drawerItem({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: TvFocusWrapper(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: Colors.white.withValues(alpha: 0.2),
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
