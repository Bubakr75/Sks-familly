import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/family_provider.dart';
import '../providers/pin_provider.dart';
import '../widgets/animated_background.dart';
import '../widgets/glass_card.dart';
import 'child_dashboard_screen.dart';
import 'school_notes_screen.dart';
import 'punishment_lines_screen.dart';
import 'settings_screen.dart';
import 'badges_screen.dart';
import 'tribunal_screen.dart';
import 'trade_screen.dart';

// ══════════════════════════════════════════════════════════════════════════════
//  HOME SCREEN
// ══════════════════════════════════════════════════════════════════════════════

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  int _selectedIndex = 0;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  static const List<_TabItem> _tabs = [
    _TabItem(icon: Icons.home_rounded, label: 'Accueil'),
    _TabItem(icon: Icons.settings_rounded, label: 'Réglages', protected: true),
  ];

  Widget _getScreen(int index) {
    switch (index) {
      case 1:
        return const SettingsScreen();
      default:
        return _HomeTab(
          onOpenDrawer: () => _scaffoldKey.currentState?.openDrawer(),
        );
    }
  }

  Future<void> _onTabTapped(int index) async {
    if (_tabs[index].protected) {
      final pin = context.read<PinProvider>();
      final ok = await _checkPin(context, pin);
      if (!ok) return;
    }
    setState(() => _selectedIndex = index);
  }

  // ── vérification PIN avec verifyPin() ─────────────────────────────────────
  Future<bool> _checkPin(BuildContext context, PinProvider pin) async {
    if (pin.isParentMode) return true;
    if (!pin.isPinSet) return true;

    final ctrl = TextEditingController();
    bool obscure = true;
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          backgroundColor: const Color(0xFF1E1E2E),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16)),
          title: const Row(children: [
            Icon(Icons.lock_rounded, color: Colors.amber),
            SizedBox(width: 8),
            Text('Mode parent',
                style: TextStyle(color: Colors.white)),
          ]),
          content: TextField(
            controller: ctrl,
            obscureText: obscure,
            keyboardType: TextInputType.number,
            maxLength: 6,
            autofocus: true,
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontSize: 22, letterSpacing: 8, color: Colors.white),
            decoration: InputDecoration(
              counterText: '',
              hintText: '• • • •',
              hintStyle: const TextStyle(
                  fontSize: 22,
                  letterSpacing: 8,
                  color: Colors.white30),
              enabledBorder: const UnderlineInputBorder(
                  borderSide: BorderSide(color: Colors.white24)),
              focusedBorder: const UnderlineInputBorder(
                  borderSide:
                      BorderSide(color: Colors.purpleAccent)),
              suffixIcon: IconButton(
                icon: Icon(
                    obscure
                        ? Icons.visibility_off_rounded
                        : Icons.visibility_rounded,
                    color: Colors.white54),
                onPressed: () => setS(() => obscure = !obscure),
              ),
            ),
            onSubmitted: (_) =>
                Navigator.pop(ctx, pin.verifyPin(ctrl.text.trim())),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Annuler',
                  style: TextStyle(color: Colors.white54)),
            ),
            TextButton(
              onPressed: () =>
                  Navigator.pop(ctx, pin.verifyPin(ctrl.text.trim())),
              child: const Text('OK',
                  style: TextStyle(color: Colors.purpleAccent)),
            ),
          ],
        ),
      ),
    );
    return result ?? false;
  }

  // ── navigation avec transition fade ──────────────────────────────────────
  void _navigate(BuildContext context, Widget page) {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (_, anim, __) => page,
        transitionsBuilder: (_, anim, __, child) =>
            FadeTransition(opacity: anim, child: child),
        transitionDuration: const Duration(milliseconds: 300),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  DRAWER GAUCHE
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildDrawer(BuildContext context) {
    final fp = context.read<FamilyProvider>();
    final pin = context.read<PinProvider>();

    return Drawer(
      backgroundColor: const Color(0xFF1A1A2E),
      child: SafeArea(
        child: Column(
          children: [
            // ── en-tête ────────────────────────────────────────────────
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF7C3AED), Color(0xFF9F67FA)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: const Row(
                children: [
                  Icon(Icons.menu_book_rounded,
                      color: Colors.white, size: 28),
                  SizedBox(width: 12),
                  Text('Menu parental',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold)),
                ],
              ),
            ),

            // ── items ──────────────────────────────────────────────────
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: [
                  // Notes de comportement
                  _DrawerTile(
                    icon: Icons.school_rounded,
                    label: 'Notes de comportement',
                    onTap: () async {
                      Navigator.pop(context);
                      final ok = await _checkPin(context, pin);
                      if (!ok || !mounted) return;
                      await _showChildPicker(context, fp, (childId) {
                        _navigate(context,
                            SchoolNotesScreen(childId: childId));
                      });
                    },
                  ),

                  // Lignes de punition
                  _DrawerTile(
                    icon: Icons.edit_note_rounded,
                    label: 'Lignes de punition',
                    onTap: () async {
                      Navigator.pop(context);
                      final ok = await _checkPin(context, pin);
                      if (!ok || !mounted) return;
                      _navigate(context, const PunishmentLinesScreen());
                    },
                  ),

                  // Tribunal
                  _DrawerTile(
                    icon: Icons.gavel_rounded,
                    label: 'Tribunal familial',
                    onTap: () async {
                      Navigator.pop(context);
                      final ok = await _checkPin(context, pin);
                      if (!ok || !mounted) return;
                      _navigate(context, const TribunalScreen());
                    },
                  ),

                  // Troc
                  _DrawerTile(
                    icon: Icons.swap_horiz_rounded,
                    label: 'Troc / Échanges',
                    onTap: () async {
                      Navigator.pop(context);
                      final ok = await _checkPin(context, pin);
                      if (!ok || !mounted) return;
                      if (fp.children.isEmpty) return;
                      _navigate(
                        context,
                        TradeScreen(childId: fp.children.first.id),
                      );
                    },
                  ),

                  // Badges
                  _DrawerTile(
                    icon: Icons.military_tech_rounded,
                    label: 'Badges',
                    onTap: () async {
                      Navigator.pop(context);
                      final ok = await _checkPin(context, pin);
                      if (!ok || !mounted) return;
                      _navigate(context, const BadgesScreen());
                    },
                  ),

                  // Synchronisation
                  _DrawerTile(
                    icon: Icons.sync_rounded,
                    label: 'Synchronisation',
                    onTap: () async {
                      Navigator.pop(context);
                      final ok = await _checkPin(context, pin);
                      if (!ok || !mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Synchronisation…'),
                          backgroundColor: Colors.purple,
                        ),
                      );
                    },
                  ),

                  const Divider(color: Colors.white12, height: 24),

                  // Historique complet
                  _DrawerTile(
                    icon: Icons.history_rounded,
                    label: 'Historique complet',
                    onTap: () async {
                      Navigator.pop(context);
                      final ok = await _checkPin(context, pin);
                      if (!ok || !mounted) return;
                      _showFullHistory(context, fp);
                    },
                  ),
                ],
              ),
            ),

            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('v5.0.0',
                  style: TextStyle(color: Colors.white24, fontSize: 12)),
            ),
          ],
        ),
      ),
    );
  }

  // ── sélecteur d'enfant ────────────────────────────────────────────────────
  Future<void> _showChildPicker(
    BuildContext context,
    FamilyProvider fp,
    Function(String childId) onSelected,
  ) async {
    if (fp.children.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Aucun enfant enregistré'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    if (fp.children.length == 1) {
      onSelected(fp.children.first.id);
      return;
    }
    await showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A2E),
      shape: const RoundedRectangleBorder(
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
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
            ...fp.children.map(
              (child) => ListTile(
                leading: CircleAvatar(
                  backgroundColor:
                      Colors.purpleAccent.withOpacity(0.3),
                  child: Text(
                    child.name.isNotEmpty
                        ? child.name[0].toUpperCase()
                        : '?',
                    style: const TextStyle(
                        color: Colors.purpleAccent),
                  ),
                ),
                title: Text(child.name,
                    style:
                        const TextStyle(color: Colors.white)),
                subtitle: Text('${child.points} pts',
                    style: const TextStyle(
                        color: Colors.white54)),
                onTap: () {
                  Navigator.pop(context);
                  onSelected(child.id);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── historique complet ────────────────────────────────────────────────────
  void _showFullHistory(BuildContext context, FamilyProvider fp) {
    List<String> getHistory(dynamic child) {
      try {
        final h = child.history;
        if (h is List) return List<String>.from(h);
      } catch (_) {}
      try {
        final h = child.pointsHistory;
        if (h is List) return List<String>.from(h);
      } catch (_) {}
      return [];
    }

    final allEntries = fp.children
        .expand((c) => getHistory(c).map((e) => '${c.name} — $e'))
        .toList()
        .reversed
        .toList();

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A2E),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        maxChildSize: 0.95,
        builder: (_, ctrl) => Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(height: 12),
            const Text('📜 Historique complet',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Expanded(
              child: allEntries.isEmpty
                  ? const Center(
                      child: Text('Aucun historique',
                          style:
                              TextStyle(color: Colors.white54)))
                  : ListView.builder(
                      controller: ctrl,
                      itemCount: allEntries.length,
                      itemBuilder: (_, i) => Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 4),
                        child: Text(allEntries[i],
                            style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 13)),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  BUILD PRINCIPAL
  // ══════════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: Colors.transparent,
      drawer: _buildDrawer(context),
      body: Stack(
        children: [
          AnimatedBackground(child: const SizedBox.expand()),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 350),
            transitionBuilder: (child, anim) =>
                FadeTransition(opacity: anim, child: child),
            child: KeyedSubtree(
              key: ValueKey(_selectedIndex),
              child: _getScreen(_selectedIndex),
            ),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: Color(0xFF12122A),
          border:
              Border(top: BorderSide(color: Colors.white10)),
        ),
        child: SafeArea(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(_tabs.length, (i) {
              final tab = _tabs[i];
              final selected = _selectedIndex == i;
              return GestureDetector(
                onTap: () => _onTabTapped(i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 10),
                  decoration: BoxDecoration(
                    color: selected
                        ? Colors.purpleAccent.withOpacity(0.15)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        tab.icon,
                        color: selected
                            ? Colors.purpleAccent
                            : Colors.white38,
                        size: 24,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        tab.label,
                        style: TextStyle(
                          color: selected
                              ? Colors.purpleAccent
                              : Colors.white38,
                          fontSize: 11,
                          fontWeight: selected
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
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  ONGLET ACCUEIL
// ══════════════════════════════════════════════════════════════════════════════

class _HomeTab extends StatelessWidget {
  final VoidCallback onOpenDrawer;
  const _HomeTab({required this.onOpenDrawer});

  void _navigate(BuildContext context, Widget page) {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (_, anim, __) => page,
        transitionsBuilder: (_, anim, __, child) =>
            FadeTransition(opacity: anim, child: child),
        transitionDuration: const Duration(milliseconds: 300),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final fp = context.watch<FamilyProvider>();
    final sorted = fp.childrenSorted;

    return SafeArea(
      child: CustomScrollView(
        slivers: [
          // ── AppBar ────────────────────────────────────────────────────
          SliverAppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            floating: true,
            leading: IconButton(
              icon:
                  const Icon(Icons.menu_rounded, color: Colors.white),
              onPressed: onOpenDrawer,
            ),
            title: const Text(
              '🏠 Famille',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold),
            ),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Icon(Icons.family_restroom_rounded,
                    color: Colors.purpleAccent.withOpacity(0.7)),
              ),
            ],
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── PODIUM ─────────────────────────────────────────────
                  if (sorted.length >= 2) ...[
                    const _SectionTitle('🏆 Classement'),
                    const SizedBox(height: 12),
                    _buildPodium(sorted),
                    const SizedBox(height: 24),
                  ],

                  // ── LISTE ENFANTS ──────────────────────────────────────
                  const _SectionTitle('👨‍👩‍👧‍👦 Profils'),
                  const SizedBox(height: 12),
                  if (sorted.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(32),
                      child: Text(
                        'Aucun enfant — ajoutez-en un dans Réglages.',
                        style: TextStyle(
                            color: Colors.white54, fontSize: 14),
                        textAlign: TextAlign.center,
                      ),
                    )
                  else
                    ...sorted.map(
                      (child) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: GestureDetector(
                          onTap: () => _navigate(
                            context,
                            ChildDashboardScreen(childId: child.id),
                          ),
                          child: GlassCard(
                            child: ListTile(
                              leading: CircleAvatar(
                                radius: 24,
                                backgroundColor: Colors.purpleAccent
                                    .withOpacity(0.25),
                                child: Text(
                                  child.name.isNotEmpty
                                      ? child.name[0].toUpperCase()
                                      : '?',
                                  style: const TextStyle(
                                      color: Colors.purpleAccent,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 20),
                                ),
                              ),
                              title: Text(child.name,
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16)),
                              subtitle: Text(
                                  '${child.points} points',
                                  style: const TextStyle(
                                      color: Colors.white54)),
                              trailing: const Icon(
                                  Icons.arrow_forward_ios_rounded,
                                  color: Colors.white24,
                                  size: 16),
                              onTap: () => _navigate(
                                context,
                                ChildDashboardScreen(
                                    childId: child.id),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(height: 80),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── PODIUM AMÉLIORÉ ───────────────────────────────────────────────────────
  Widget _buildPodium(List<dynamic> sorted) {
    final first = sorted.isNotEmpty ? sorted[0] : null;
    final second = sorted.length > 1 ? sorted[1] : null;
    final third = sorted.length > 2 ? sorted[2] : null;

    Widget col({
      required dynamic child,
      required int rank,
      required double barH,
      required Color color,
      required String medal,
    }) {
      if (child == null) return const Expanded(child: SizedBox.shrink());
      return Expanded(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text(medal,
                style: TextStyle(
                    fontSize: rank == 1 ? 30 : 22)),
            const SizedBox(height: 4),
            CircleAvatar(
              radius: rank == 1 ? 28 : 20,
              backgroundColor: color.withOpacity(0.25),
              child: Text(
                child.name.isNotEmpty
                    ? child.name[0].toUpperCase()
                    : '?',
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                  fontSize: rank == 1 ? 20 : 14,
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              child.name,
              style: TextStyle(
                color: Colors.white,
                fontSize: rank == 1 ? 14 : 11,
                fontWeight: rank == 1
                    ? FontWeight.bold
                    : FontWeight.normal,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
            Text(
              '${child.points}pts',
              style: TextStyle(
                  color: color,
                  fontSize: 11,
                  fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            Container(
              height: barH,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    color.withOpacity(0.8),
                    color.withOpacity(0.3),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
                borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(8)),
                border: Border.all(color: color.withOpacity(0.4)),
              ),
              child: Center(
                child: Text(
                  '#$rank',
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w900,
                    fontSize: rank == 1 ? 18 : 14,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(8, 16, 8, 0),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          col(
              child: second,
              rank: 2,
              barH: 75,
              color: Colors.blueGrey,
              medal: '🥈'),
          const SizedBox(width: 6),
          col(
              child: first,
              rank: 1,
              barH: 115,
              color: Colors.amber,
              medal: '🥇'),
          const SizedBox(width: 6),
          col(
              child: third,
              rank: 3,
              barH: 55,
              color: Colors.brown,
              medal: '🥉'),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  HELPERS
// ══════════════════════════════════════════════════════════════════════════════

class _TabItem {
  final IconData icon;
  final String label;
  final bool protected;
  const _TabItem(
      {required this.icon,
      required this.label,
      this.protected = false});
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);
  @override
  Widget build(BuildContext context) => Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.bold,
        ),
      );
}

class _DrawerTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _DrawerTile(
      {required this.icon,
      required this.label,
      required this.onTap});

  @override
  Widget build(BuildContext context) => ListTile(
        leading: Icon(icon,
            color: Colors.purpleAccent.withOpacity(0.85),
            size: 22),
        title: Text(label,
            style: const TextStyle(
                color: Colors.white, fontSize: 14)),
        onTap: onTap,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10)),
        contentPadding: const EdgeInsets.symmetric(
            horizontal: 16, vertical: 2),
      );
}
