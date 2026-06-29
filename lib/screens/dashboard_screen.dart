// =============================================================================
// SKS Family - Dashboard "Aurora Verre" (disposition 3 : grille enfants)
// =============================================================================
// Fond aurore animé + cartes en verre dépoli + photos des enfants.
// Accueil principal de l'app.
// =============================================================================

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/family_provider.dart';
import '../providers/pin_provider.dart';
import '../models/child_model.dart';
import '../models/trade_model.dart';
import '../widgets/aurora_background.dart';
import '../widgets/aurora_glass_card.dart';
import '../widgets/tv_focus_wrapper.dart';
import '../widgets/animated_page_transition.dart';
import 'punishment_lines_screen.dart';
import 'immunity_lines_screen.dart';
import 'trade_screen.dart';
import 'child_dashboard_screen.dart';
import 'tribunal_screen.dart';
import 'multi_child_evaluation_screen.dart';
import 'pending_requests_screen.dart';

// Palette Aurora (constantes)
class _Aurora {
  static const violet = Color(0xFF7C4DFF);
  static const cyan = Color(0xFF00E5FF);
  static const pink = Color(0xFFEC4899);
  static const gold = Color(0xFFFFD700);
  static const text = Color(0xFFF3F0FF);
  static const textDim = Color(0xFFA59FD5);
  static const textMuted = Color(0xFF6B6890);
}

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});
  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with TickerProviderStateMixin {
  late AnimationController _staggerController;
  late Animation<double> _headerAnim;
  late Animation<double> _gridAnim;
  late Animation<double> _summaryAnim;
  late Animation<double> _actionsAnim;

  @override
  void initState() {
    super.initState();
    _staggerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    _headerAnim = CurvedAnimation(parent: _staggerController, curve: const Interval(0.0, 0.25, curve: Curves.easeOutCubic));
    _gridAnim = CurvedAnimation(parent: _staggerController, curve: const Interval(0.15, 0.55, curve: Curves.easeOutCubic));
    _summaryAnim = CurvedAnimation(parent: _staggerController, curve: const Interval(0.40, 0.75, curve: Curves.easeOutCubic));
    _actionsAnim = CurvedAnimation(parent: _staggerController, curve: const Interval(0.60, 1.0, curve: Curves.easeOutCubic));
    _staggerController.forward();
  }

  @override
  void dispose() {
    _staggerController.dispose();
    super.dispose();
  }

  // ─── Avatar enfant (photo réelle ou emoji) ──────────────────
  Widget _buildChildAvatar(ChildModel child, double radius) {
    if (child.hasPhoto) {
      try {
        final bytes = base64Decode(child.photoBase64);
        return Container(
          width: radius * 2,
          height: radius * 2,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(radius * 0.45),
            border: Border.all(color: _Aurora.cyan.withValues(alpha: 0.5), width: 2),
            image: DecorationImage(image: MemoryImage(bytes), fit: BoxFit.cover),
            boxShadow: [
              BoxShadow(
                color: _Aurora.cyan.withValues(alpha: 0.3),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
            ],
          ),
        );
      } catch (_) {}
    }
    return Container(
      width: radius * 2,
      height: radius * 2,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius * 0.45),
        color: Colors.white.withValues(alpha: 0.08),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2), width: 2),
      ),
      child: Center(
        child: Text(
          child.avatar.isNotEmpty ? child.avatar : '👤',
          style: TextStyle(fontSize: radius * 0.9),
        ),
      ),
    );
  }

  String _getGreeting() {
    final h = DateTime.now().hour;
    if (h < 11) return 'Bonjour';
    if (h < 18) return 'Bon après-midi';
    return 'Bonsoir';
  }

  int _getTodayActionsCount(FamilyProvider fp) {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    return fp.history.where((h) => h.date.isAfter(todayStart)).length;
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<FamilyProvider>(
      builder: (context, fp, _) {
        final sorted = List<ChildModel>.from(fp.children)
          ..sort((a, b) => b.points.compareTo(a.points));
        final totalPoints = fp.children.fold<int>(0, (sum, c) => sum + c.points);
        final activeTrades = fp.trades.where((t) => t.isActive).toList();
        final todayActions = _getTodayActionsCount(fp);

        // Streak max + badges pour l'aperçu
        int maxStreak = 0;
        String streakName = '';
        int totalBadges = 0;
        for (final c in fp.children) {
          final s = c.streakDays ?? 0;
          if (s > maxStreak) { maxStreak = s; streakName = c.name; }
          totalBadges += c.badgeIds.length;
        }

        return AuroraBackground(
          child: Scaffold(
            backgroundColor: Colors.transparent,
            body: SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ─── HEADER ───
                    _AnimatedFade(
                      animation: _headerAnim,
                      child: _buildHeader(fp),
                    ),
                    // ─── GRILLE ENFANTS (dispo 3) ───
                    if (sorted.isNotEmpty)
                      _AnimatedFade(
                        animation: _gridAnim,
                        child: _buildChildrenGrid(fp, sorted),
                      )
                    else
                      _buildEmptyState(),
                    // ─── APERÇU FAMILLE ───
                    if (sorted.isNotEmpty)
                      _AnimatedFade(
                        animation: _summaryAnim,
                        child: _buildFamilySummary(fp, totalPoints, totalBadges, maxStreak, streakName, todayActions),
                      ),
                    // ─── ACTIONS RAPIDES ───
                    _AnimatedFade(
                      animation: _actionsAnim,
                      child: _buildQuickActions(fp),
                    ),
                    // ─── VENTES EN COURS ───
                    if (activeTrades.isNotEmpty)
                      _buildActiveTrades(fp, activeTrades),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // ─── HEADER ──────────────────────────────────────────────────
  Widget _buildHeader(FamilyProvider fp) {
    final isParent = context.watch<PinProvider>().isParentMode;
    final pendingCount = fp.pendingRequestsCount;
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 16),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${_getGreeting()} 👋',
                  style: const TextStyle(
                    fontSize: 26, fontWeight: FontWeight.w800, color: _Aurora.text,
                    shadows: [Shadow(color: _Aurora.cyan, blurRadius: 20)],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${fp.children.length} enfants · ${_formatToday()}',
                  style: const TextStyle(fontSize: 12, color: _Aurora.textDim),
                ),
              ],
            ),
          ),
          // Bouton Demandes (cloche + badge) — visible en mode parent
          if (isParent)
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: AuroraGlassCard(
                radius: 12,
                glow: pendingCount > 0 ? 0.4 : 0,
                accentColor: pendingCount > 0 ? _Aurora.pink : null,
                blurSigma: 8,
                padding: const EdgeInsets.all(10),
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PendingRequestsScreen())),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Icon(
                      pendingCount > 0 ? Icons.notifications_active_rounded : Icons.notifications_none_rounded,
                      color: pendingCount > 0 ? _Aurora.pink : _Aurora.textDim,
                      size: 24,
                    ),
                    if (pendingCount > 0)
                      Positioned(
                        top: -8, right: -10,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                            color: _Aurora.pink,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFF0A0A1F), width: 1.5),
                            boxShadow: [BoxShadow(color: _Aurora.pink.withValues(alpha: 0.6), blurRadius: 8)],
                          ),
                          child: Text(
                            pendingCount > 9 ? '9+' : '$pendingCount',
                            style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          // Bouton Menu (ouvre le drawer)
          Padding(
            padding: const EdgeInsets.only(left: 8),
            child: AuroraGlassCard(
              radius: 12,
              glow: 0,
              blurSigma: 8,
              padding: const EdgeInsets.all(10),
              onTap: () => Scaffold.of(context).openDrawer(),
              child: const Icon(Icons.menu_rounded, color: _Aurora.cyan, size: 24),
            ),
          ),
        ],
      ),
    );
  }

  String _formatToday() {
    const days = ['lun', 'mar', 'mer', 'jeu', 'ven', 'sam', 'dim'];
    const months = ['jan', 'fév', 'mar', 'avr', 'mai', 'jun', 'jul', 'aoû', 'sep', 'oct', 'nov', 'déc'];
    final d = DateTime.now();
    return '${days[d.weekday - 1]} ${d.day} ${months[d.month - 1]}';
  }

  // ─── GRILLE ENFANTS (DISPO 3) ────────────────────────────────
  Widget _buildChildrenGrid(FamilyProvider fp, List<ChildModel> sorted) {
    // Couleur d'accent par enfant (stable)
    final accents = [_Aurora.gold, _Aurora.cyan, _Aurora.violet, _Aurora.pink];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionTitle('Mes enfants 👨\u200d👩\u200d👧\u200d👦'),
        const SizedBox(height: 10),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 0.78,
          children: [
            for (int i = 0; i < sorted.length; i++)
              _buildChildCard(fp, sorted[i], i, accents[i % accents.length], isFirst: i == 0),
          ],
        ),
      ],
    );
  }

  Widget _buildChildCard(FamilyProvider fp, ChildModel child, int index, Color accent, {bool isFirst = false}) {
    return Transform(
      alignment: Alignment.center,
      transform: Matrix4.identity()
        ..setEntry(3, 2, 0.002) // perspective 3D
        ..rotateX(0.06) // inclinaison avant (effet de profondeur)
        ..rotateY(index.isEven ? 0.04 : -0.04), // léger tilt gauche/droite alterné
      child: TvFocusWrapper(
        onTap: () => Navigator.push(context, ZoomPageRoute(page: ChildDashboardScreen(childId: child.id))),
        focusBorderColor: accent,
        borderRadius: 18,
        child: AuroraGlassCard(
          radius: 18,
          accentColor: isFirst ? _Aurora.gold : accent,
          glow: isFirst ? 0.45 : 0.28,
          gold: isFirst,
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: SizedBox(
            width: double.infinity,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Halo lumineux 3D derrière l'avatar
              Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.center,
                children: [
                  // Halo glow (derrière) — carré arrondi pour matcher la photo
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          accent.withValues(alpha: isFirst ? 0.40 : 0.25),
                          accent.withValues(alpha: 0.05),
                        ],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: accent.withValues(alpha: 0.35),
                          blurRadius: 22,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                  ),
                  // Avatar (photo carrée) + couronne
                  _buildChildAvatar(child, 42),
                  if (isFirst)
                    const Positioned(
                      top: -14, right: -12,
                      child: Text('👑', style: TextStyle(fontSize: 26)),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                child.name,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: _Aurora.text),
                maxLines: 1, overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              ShaderMask(
                shaderCallback: (bounds) => LinearGradient(colors: [accent, _Aurora.cyan]).createShader(bounds),
                child: Text(
                  '${child.points}',
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: Colors.white),
                ),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: accent.withValues(alpha: 0.3)),
                ),
                child: Text(
                  '${child.levelTitle} · ${child.currentLevelNumber}',
                  style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: accent),
                ),
              ),
            ],
          ),
        ),
      ),
      ),
    );
  }

  // ─── APERÇU FAMILLE ──────────────────────────────────────────
  Widget _buildFamilySummary(FamilyProvider fp, int totalPoints, int totalBadges, int maxStreak, String streakName, int todayActions) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionTitle('Aperçu famille'),
        const SizedBox(height: 8),
        // KPIs en ligne (mini)
        Row(
          children: [
            Expanded(child: _miniKpi('Total', '$totalPoints', _Aurora.gold, Icons.emoji_events_rounded)),
            const SizedBox(width: 8),
            Expanded(child: _miniKpi('Actions', '$todayActions', _Aurora.cyan, Icons.bolt_rounded)),
            const SizedBox(width: 8),
            Expanded(child: _miniKpi('Badges', '$totalBadges', _Aurora.pink, Icons.military_tech_rounded)),
          ],
        ),
        const SizedBox(height: 8),
        if (maxStreak > 0)
          AuroraGlassCard(
            accentColor: _Aurora.pink,
            glow: 0.15,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                const Text('🔥', style: TextStyle(fontSize: 24)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Meilleur streak', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _Aurora.text)),
                      Text('$streakName · $maxStreak jours sans pénalité', style: const TextStyle(fontSize: 10, color: _Aurora.textMuted)),
                    ],
                  ),
                ),
                Text('$maxStreak j', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: _Aurora.pink)),
              ],
            ),
          ),
      ],
    );
  }

  Widget _miniKpi(String label, String value, Color accent, IconData icon) {
    return AuroraGlassCard(
      radius: 14,
      accentColor: accent,
      glow: 0.15,
      padding: const EdgeInsets.all(10),
      child: Column(
        children: [
          Icon(icon, size: 16, color: accent),
          const SizedBox(height: 4),
          Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: accent)),
          const SizedBox(height: 2),
          Text(label.toUpperCase(), style: const TextStyle(fontSize: 8, fontWeight: FontWeight.w700, color: _Aurora.textDim, letterSpacing: 1)),
        ],
      ),
    );
  }

  // ─── ACTIONS RAPIDES ─────────────────────────────────────────
  Widget _buildQuickActions(FamilyProvider fp) {
    final actions = [
      _Act('Punitions', Icons.menu_book_rounded, const Color(0xFFEF4444), () {
        Navigator.push(context, SlidePageRoute(page: const PunishmentLinesScreen(), direction: SlideDirection.up));
      }),
      _Act('Immunités', Icons.shield_rounded, const Color(0xFFF59E0B), () {
        Navigator.push(context, SpinPageRoute(page: const ImmunityLinesScreen()));
      }),
      _Act('Tribunal', Icons.gavel_rounded, _Aurora.violet, () {
        Navigator.push(context, SlidePageRoute(page: const TribunalScreen()));
      }),
      _Act('Évaluations', Icons.note_alt_rounded, _Aurora.pink, () {
        Navigator.push(context, SlidePageRoute(page: const MultiChildEvaluationScreen()));
      }),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionTitle('Actions rapides'),
        const SizedBox(height: 8),
        GridView.count(
          crossAxisCount: 4,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          childAspectRatio: 0.88,
          children: actions.map((a) => _buildActionTile(a)).toList(),
        ),
      ],
    );
  }

  Widget _buildActionTile(_Act a) {
    return TvFocusWrapper(
      onTap: a.onTap,
      focusBorderColor: a.color,
      borderRadius: 16,
      child: AuroraGlassCard(
        radius: 16,
        accentColor: a.color,
        glow: 0.2,
        padding: const EdgeInsets.all(8),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: RadialGradient(colors: [a.color.withValues(alpha: 0.3), a.color.withValues(alpha: 0.08)]),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: a.color.withValues(alpha: 0.4)),
              ),
              child: Icon(a.icon, color: a.color, size: 20),
            ),
            const SizedBox(height: 6),
            Text(a.label, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: _Aurora.text), textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }

  // ─── VENTES EN COURS ─────────────────────────────────────────
  Widget _buildActiveTrades(FamilyProvider fp, List<TradeModel> active) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionTitle('Ventes en cours'),
        const SizedBox(height: 8),
        ...active.map((trade) {
          final sellerName = fp.getChild(trade.fromChildId)?.name ?? '?';
          final buyerName = fp.getChild(trade.toChildId)?.name ?? '?';
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: TvFocusWrapper(
              onTap: () => Navigator.push(context, DoorPageRoute(page: TradeScreen(childId: trade.fromChildId))),
              child: AuroraGlassCard(
                accentColor: _Aurora.cyan,
                glow: 0.15,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Row(
                  children: [
                    Container(
                      width: 8, height: 8,
                      decoration: BoxDecoration(shape: BoxShape.circle, color: _Aurora.cyan, boxShadow: [BoxShadow(color: _Aurora.cyan.withValues(alpha: 0.6), blurRadius: 6)]),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('$sellerName → $buyerName', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: _Aurora.text)),
                          Text('${trade.immunityLines} lignes · ${trade.serviceDescription}', style: const TextStyle(fontSize: 12, color: _Aurora.textDim), maxLines: 1, overflow: TextOverflow.ellipsis),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(color: _Aurora.cyan.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10)),
                      child: Text(trade.statusLabel, style: const TextStyle(color: _Aurora.cyan, fontSize: 11, fontWeight: FontWeight.w600)),
                    ),
                    const SizedBox(width: 6),
                    const Icon(Icons.chevron_right_rounded, color: _Aurora.textMuted, size: 22),
                  ],
                ),
              ),
            ),
          );
        }),
      ],
    );
  }

  // ─── ÉTAT VIDE ───────────────────────────────────────────────
  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.only(top: 60),
        child: Column(
          children: [
            const Text('👨\u200d👩\u200d👧\u200d👦', style: TextStyle(fontSize: 64)),
            const SizedBox(height: 16),
            const Text('Aucun enfant', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: _Aurora.text)),
            const SizedBox(height: 8),
            const Text('Ajoutez vos enfants pour commencer', style: TextStyle(color: _Aurora.textMuted)),
          ],
        ),
      ),
    );
  }
}

// ─── Titre de section ─────────────────────────────────────────
class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _Aurora.textDim, letterSpacing: 1.4),
    );
  }
}

// ─── Animation fade + slide ───────────────────────────────────
class _AnimatedFade extends StatelessWidget {
  final Animation<double> animation;
  final Widget child;
  const _AnimatedFade({required this.animation, required this.child});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, c) {
        return Transform.translate(
          offset: Offset(0, 20 * (1 - animation.value)),
          child: Opacity(opacity: animation.value, child: c),
        );
      },
      child: child,
    );
  }
}

// ─── Action rapide ────────────────────────────────────────────
class _Act {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _Act(this.label, this.icon, this.color, this.onTap);
}

// ─── Sélecteur enfant en bottom sheet (verre Aurora) ──────────
class _ChildPickerSheet extends StatefulWidget {
  final List<ChildModel> children;
  final Function(String) onSelected;
  final Widget Function(ChildModel, double) buildAvatar;
  const _ChildPickerSheet({required this.children, required this.onSelected, required this.buildAvatar});
  @override
  State<_ChildPickerSheet> createState() => _ChildPickerSheetState();
}

class _ChildPickerSheetState extends State<_ChildPickerSheet>
    with SingleTickerProviderStateMixin {
  late AnimationController _animCtrl;
  late Animation<double> _slideAnim;
  String _search = '';

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 400));
    _slideAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOutCubic);
    _animCtrl.forward();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = widget.children.where((c) => c.name.toLowerCase().contains(_search.toLowerCase())).toList();

    return AnimatedBuilder(
      animation: _slideAnim,
      builder: (context, _) {
        return Transform.translate(
          offset: Offset(0, 60 * (1 - _slideAnim.value)),
          child: Opacity(
            opacity: _slideAnim.value,
            child: Container(
              margin: const EdgeInsets.all(12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF0F0F28).withValues(alpha: 0.85),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: _Aurora.cyan.withValues(alpha: 0.3)),
                boxShadow: [BoxShadow(color: _Aurora.violet.withValues(alpha: 0.3), blurRadius: 30)],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 16), decoration: BoxDecoration(color: _Aurora.textMuted, borderRadius: BorderRadius.circular(2))),
                  const Text('Choisir un enfant', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: _Aurora.text)),
                  const SizedBox(height: 14),
                  TextField(
                    onChanged: (v) => setState(() => _search = v),
                    style: const TextStyle(color: _Aurora.text),
                    decoration: InputDecoration(
                      hintText: 'Rechercher...',
                      hintStyle: const TextStyle(color: _Aurora.textMuted),
                      prefixIcon: const Icon(Icons.search, color: _Aurora.cyan, size: 20),
                      filled: true,
                      fillColor: Colors.white.withValues(alpha: 0.06),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                    ),
                  ),
                  const SizedBox(height: 12),
                  ...filtered.map((child) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: TvFocusWrapper(
                      onTap: () => widget.onSelected(child.id),
                      borderRadius: 14,
                      child: AuroraGlassCard(
                        radius: 14,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        child: Row(
                          children: [
                            widget.buildAvatar(child, 20),
                            const SizedBox(width: 12),
                            Expanded(child: Text(child.name, style: const TextStyle(color: _Aurora.text, fontWeight: FontWeight.w600))),
                            Text('${child.points} pts', style: const TextStyle(color: _Aurora.cyan, fontWeight: FontWeight.w700)),
                          ],
                        ),
                      ),
                    ),
                  )),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
