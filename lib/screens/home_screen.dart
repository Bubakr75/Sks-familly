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
                  fillColor: Colors.white.withOpacity(0.1),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  hintText: '• • • •',
                  hintStyle: TextStyle(
                    color: Colors.white.withOpacity(0.3),
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
                if (pinProvider.verifyPin(pin)) {
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

  void _showInteractiveHelp() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        title: const Text('❔ Aide - Onglets', style: TextStyle(color: Colors.white, fontSize: 20)),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              ListTile(
                leading: Icon(Icons.home_rounded, color: Colors.cyan),
                title: Text('Accueil', style: TextStyle(color: Colors.white)),
                subtitle: Text('Tableau de bord général et résumé', style: TextStyle(color: Colors.white70)),
              ),
              ListTile(
                leading: Icon(Icons.stars_rounded, color: Colors.amber),
                title: Text('Points', style: TextStyle(color: Colors.white)),
                subtitle: Text('Ajouter ou retirer des points aux enfants', style: TextStyle(color: Colors.white70)),
              ),
              ListTile(
                leading: Icon(Icons.calendar_month_rounded, color: Colors.green),
                title: Text('Calendrier', style: TextStyle(color: Colors.white)),
                subtitle: Text('Événements, anniversaires et planning', style: TextStyle(color: Colors.white70)),
              ),
              ListTile(
                leading: Icon(Icons.bar_chart_rounded, color: Colors.purple),
                title: Text('Stats', style: TextStyle(color: Colors.white)),
                subtitle: Text('Statistiques détaillées et progrès', style: TextStyle(color: Colors.white70)),
              ),
              ListTile(
                leading: Icon(Icons.settings_rounded, color: Colors.grey),
                title: Text('Réglages', style: TextStyle(color: Colors.white)),
                subtitle: Text('Paramètres, PIN, famille et compte', style: TextStyle(color: Colors.white70)),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Fermer', style: TextStyle(color: Colors.white70)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBody: true,
      drawer: _buildDrawer(context),
      body: AnimatedBackground(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 400),
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
            color: const Color(0xFF0D1B2E).withOpacity(0.95),
            border: Border(
              top: BorderSide(
                color: Colors.cyanAccent.withOpacity(0.15),
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
                      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
                      decoration: BoxDecoration(
                        color: isSelected ? Colors.cyan.withOpacity(0.2) : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            icons[i],
                            color: isSelected ? Colors.cyanAccent : Colors.white70,
                            size: 26,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            labels[i],
                            style: TextStyle(
                              color: isSelected ? Colors.cyanAccent : Colors.white70,
                              fontSize: 11,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            ),
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
      floatingActionButton: FloatingActionButton(
        mini: true,
        backgroundColor: Colors.cyan.withOpacity(0.9),
        onPressed: _showInteractiveHelp,
        child: const Icon(Icons.help_outline, color: Colors.white, size: 22),
      ),
    );
  }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        title: const Text('❔ Aide - Onglets', style: TextStyle(color: Colors.white, fontSize: 20)),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ListTile(
                leading: Icon(Icons.home_rounded, color: Colors.cyan),
                title: Text('Accueil', style: TextStyle(color: Colors.white)),
                subtitle: Text('Tableau de bord général et résumé de la famille', style: TextStyle(color: Colors.white70)),
              ),
              ListTile(
                leading: Icon(Icons.stars_rounded, color: Colors.amber),
                title: Text('Points', style: TextStyle(color: Colors.white)),
                subtitle: Text('Ajouter ou retirer des points aux enfants', style: TextStyle(color: Colors.white70)),
              ),
              ListTile(
                leading: Icon(Icons.calendar_month_rounded, color: Colors.green),
                title: Text('Calendrier', style: TextStyle(color: Colors.white)),
                subtitle: Text('Événements, anniversaires et planning familial', style: TextStyle(color: Colors.white70)),
              ),
              ListTile(
                leading: Icon(Icons.bar_chart_rounded, color: Colors.purple),
                title: Text('Stats', style: TextStyle(color: Colors.white)),
                subtitle: Text('Statistiques détaillées et progrès des enfants', style: TextStyle(color: Colors.white70)),
              ),
              ListTile(
                leading: Icon(Icons.settings_rounded, color: Colors.grey),
                title: Text('Réglages', style: TextStyle(color: Colors.white)),
                subtitle: Text('PIN, paramètres, famille et compte', style: TextStyle(color: Colors.white70)),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Fermer', style: TextStyle(color: Colors.white70)),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawer(BuildContext context) {
    // ... (si tu as un drawer, garde-le tel quel ou dis-le moi)
    return const Drawer();
  }
}
