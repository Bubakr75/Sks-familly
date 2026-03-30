import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../providers/family_provider.dart';
import '../providers/pin_provider.dart';
import '../providers/theme_provider.dart';
import '../widgets/animated_background.dart';
import '../widgets/glass_card.dart';
import '../widgets/tv_focus_wrapper.dart';
import '../widgets/animated_page_transition.dart';

import 'dashboard_screen.dart';
import 'add_points_screen.dart';
import 'calendar_screen.dart';
import 'stats_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  final String parentName;
  const HomeScreen({super.key, this.parentName = 'Parent'});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  int _currentIndex = 0;
  late AnimationController _navBarController;

  // Indices protégés par le PIN parental
  static const List<int> _protectedIndices = [1, 4];

  // Icônes et labels de la barre de navigation
  static const _navIcons = [
    Icons.home_rounded,
    Icons.stars_rounded,
    Icons.calendar_month_rounded,
    Icons.bar_chart_rounded,
    Icons.settings_rounded,
  ];
  static const _navLabels = [
    'Accueil',
    'Points',
    'Calendrier',
    'Stats',
    'Réglages',
  ];

  @override
  void initState() {
    super.initState();
    _navBarController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..forward();

    // Définir le nom du parent courant
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.parentName.isNotEmpty && mounted) {
        context.read<FamilyProvider>().setCurrentParent(widget.parentName);
      }
    });
  }

  @override
  void dispose() {
    _navBarController.dispose();
    super.dispose();
  }

  // ─── Écran courant ─────────────────────────────────────────
  Widget _getScreen() {
    switch (_currentIndex) {
      case 0: return const DashboardScreen();
      case 1: return const AddPointsScreen();
      case 2: return const CalendarScreen();
      case 3: return const StatsScreen();
      case 4: return const SettingsScreen();
      default: return const DashboardScreen();
    }
  }

  // ─── Navigation avec protection PIN ─────────────────────────
  void _onTabTapped(int index) {
    if (index == _currentIndex) return; // évite les rebuilds inutiles

    if (_protectedIndices.contains(index)) {
      final pin = context.read<PinProvider>();
      if (pin.isPinSet && !pin.canPerformParentAction()) {
        _showPinCheck(() => setState(() => _currentIndex = index));
        return;
      }
    }
    setState(() => _currentIndex = index);
  }

  // ─── Dialog PIN ─────────────────────────────────────────────
  void _showPinCheck(VoidCallback onSuccess) {
    final pinController = TextEditingController();
    bool _obscure = true;

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        final primary = Theme.of(ctx).colorScheme.primary;
        return StatefulBuilder(
          builder: (ctx, setStateDialog) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.lock_rounded, color: Colors.amber),
                SizedBox(width: 8),
                Text('Code Parental'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Entrez votre code PIN pour accéder à cette section.',
                  style: TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: pinController,
                  obscureText: _obscure,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  autofocus: true,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 24, letterSpacing: 8),
                  decoration: InputDecoration(
                    counterText: '',
                    hintText: '• • • •',
                    hintStyle: const TextStyle(fontSize: 24, letterSpacing: 8),
                    suffixIcon: IconButton(
                      icon: Icon(_obscure
                          ? Icons.visibility_off_rounded
                          : Icons.visibility_rounded),
                      onPressed: () =>
                          setStateDialog(() => _obscure = !_obscure),
                    ),
                  ),
                  // ✅ Validation au clavier Enter/Done
                  onSubmitted: (_) {
                    _validatePin(ctx, pinController, onSuccess);
                  },
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  pinController.dispose();
                  Navigator.pop(ctx);
                },
                child: const Text('Annuler'),
              ),
              FilledButton(
                onPressed: () => _validatePin(ctx, pinController, onSuccess),
                child: const Text('Valider', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );
      },
    ).then((_) => pinController.dispose());
  }

  void _validatePin(
    BuildContext ctx,
    TextEditingController controller,
    VoidCallback onSuccess,
  ) {
    final rawPin = controller.text.trim();
    final pin = context.read<PinProvider>();
    if (pin.verifyPin(rawPin)) {
      Navigator.pop(ctx);
      onSuccess();
    } else {
      // Vide le champ et vibre
      controller.clear();
      HapticFeedback.heavyImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.error_rounded, color: Colors.white),
              SizedBox(width: 8),
              Text('Code PIN incorrect'),
            ],
          ),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  // ─── Aide interactive ───────────────────────────────────────
  void _showInteractiveHelp() {
    showDialog(
      context: context,
      builder: (context) {
        final primary = Theme.of(context).colorScheme.primary;
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.help_outline_rounded, color: Colors.amber),
              SizedBox(width: 8),
              Text('Aide — Onglets'),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: const [
                _HelpTile(
                  icon: Icons.home_rounded,
                  color: Colors.cyan,
                  title: 'Accueil',
                  subtitle: 'Tableau de bord général et résumé de la famille',
                ),
                _HelpTile(
                  icon: Icons.stars_rounded,
                  color: Colors.amber,
                  title: 'Points',
                  subtitle: 'Ajouter ou retirer des points aux enfants',
                ),
                _HelpTile(
                  icon: Icons.calendar_month_rounded,
                  color: Colors.green,
                  title: 'Calendrier',
                  subtitle: 'Événements, anniversaires et planning',
                ),
                _HelpTile(
                  icon: Icons.bar_chart_rounded,
                  color: Colors.purple,
                  title: 'Stats',
                  subtitle: 'Statistiques détaillées et progrès des enfants',
                ),
                _HelpTile(
                  icon: Icons.settings_rounded,
                  color: Colors.grey,
                  title: 'Réglages',
                  subtitle: 'Paramètres, PIN, famille et compte',
                ),
              ],
            ),
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Compris !'),
            ),
          ],
        );
      },
    );
  }

  // ─── Drawer latéral ─────────────────────────────────────────
  Widget _buildDrawer(BuildContext context) {
    final primary  = Theme.of(context).colorScheme.primary;
    final fp       = context.watch<FamilyProvider>();
    final pin      = context.watch<PinProvider>();

    return Drawer(
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // En-tête
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: primary.withValues(alpha: 0.15),
                    radius: 28,
                    child: Icon(Icons.family_restroom_rounded, color: primary, size: 28),
                  ),
                  const SizedBox(width: 14),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'SKS Family',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        fp.currentParentName,
                        style: TextStyle(fontSize: 13, color: Colors.grey[500]),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Divider(),

            // Sync status
            ListTile(
              leading: Icon(
                fp.isSyncEnabled ? Icons.cloud_done_rounded : Icons.cloud_off_rounded,
                color: fp.isSyncEnabled ? Colors.green : Colors.grey,
              ),
              title: Text(fp.isSyncEnabled ? 'Synchronisé' : 'Mode local'),
              subtitle: Text(
                fp.isSyncEnabled
                    ? 'Code : ${fp.familyCode ?? '—'}'
                    : 'Non connecté à une famille',
                style: TextStyle(fontSize: 12, color: Colors.grey[500]),
              ),
            ),
            const Divider(),

            // Liens rapides
            ListTile(
              leading: const Icon(Icons.people_rounded),
              title: const Text('Gérer les enfants'),
              onTap: () {
                Navigator.pop(context);
                // Navigation vers manage_children_screen si souhaité
              },
            ),
            ListTile(
              leading: const Icon(Icons.emoji_events_rounded),
              title: const Text('Badges'),
              onTap: () => Navigator.pop(context),
            ),

            const Spacer(),

            // Verrou parental
            ListTile(
              leading: Icon(
                pin.isParentMode
                    ? Icons.lock_open_rounded
                    : Icons.lock_rounded,
                color: pin.isParentMode ? Colors.green : Colors.orange,
              ),
              title: Text(pin.isParentMode ? 'Mode parent actif' : 'Mode enfant'),
              subtitle: Text(
                pin.isParentMode ? 'Appuyez pour verrouiller' : 'Appuyez pour déverrouiller',
                style: TextStyle(fontSize: 12, color: Colors.grey[500]),
              ),
              onTap: () {
                if (pin.isParentMode) {
                  pin.lockParentMode();
                  Navigator.pop(context);
                } else {
                  Navigator.pop(context);
                  _showPinCheck(() {});
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  // ─── Build principal ────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final bgColor = Theme.of(context).scaffoldBackgroundColor;

    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBody: true,
      drawer: _buildDrawer(context),
      body: AnimatedBackground(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 350),
          transitionBuilder: (child, animation) => FadeTransition(
            opacity: animation,
            child: child,
          ),
          child: KeyedSubtree(
            key: ValueKey<int>(_currentIndex),
            child: _getScreen(),
          ),
        ),
      ),

      // ─── Barre de navigation ─────────────────────────────────
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
            color: bgColor.withValues(alpha: 0.95),
            border: Border(
              top: BorderSide(
                color: primary.withValues(alpha: 0.15),
                width: 0.5,
              ),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 12,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: List.generate(5, (i) {
                  final isSelected = _currentIndex == i;
                  final isProtected = _protectedIndices.contains(i);
                  return TvFocusWrapper(
                    onTap: () => _onTabTapped(i),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      padding: const EdgeInsets.symmetric(
                          vertical: 6, horizontal: 12),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? primary.withValues(alpha: 0.2)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Stack(
                            clipBehavior: Clip.none,
                            children: [
                              Icon(
                                _navIcons[i],
                                color: isSelected ? primary : Colors.grey,
                                size: 26,
                              ),
                              // ✅ Indicateur de protection PIN
                              if (isProtected)
                                Positioned(
                                  right: -4,
                                  top: -4,
                                  child: Icon(
                                    Icons.lock_rounded,
                                    size: 10,
                                    color: primary.withValues(alpha: 0.7),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _navLabels[i],
                            style: TextStyle(
                              color: isSelected ? primary : Colors.grey,
                              fontSize: 11,
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.normal,
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

      // ─── Bouton aide ─────────────────────────────────────────
      floatingActionButton: FloatingActionButton.small(
        backgroundColor: primary.withValues(alpha: 0.9),
        onPressed: _showInteractiveHelp,
        tooltip: 'Aide',
        child: const Icon(Icons.help_outline_rounded, color: Colors.white),
      ),
    );
  }
}

// ─── Widget helper pour l'aide ──────────────────────────────────
class _HelpTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;

  const _HelpTile({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor: color.withValues(alpha: 0.15),
        child: Icon(icon, color: color, size: 20),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
    );
  }
}
