// =============================================================================
// SKS Family - Dashboard Émeraude Premium
// =============================================================================
// Refonte style Apple Fitness + Stripe + palette émeraude
// =============================================================================

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/family_provider.dart';
import '../models/child_model.dart';
import '../models/trade_model.dart';
import '../models/history_entry.dart';
import '../config/emerald_theme.dart';
import '../widgets/tv_focus_wrapper.dart';
import '../widgets/animated_page_transition.dart';
import 'punishment_lines_screen.dart';
import 'immunity_lines_screen.dart';
import 'trade_screen.dart';
import 'child_dashboard_screen.dart';
import 'tribunal_screen.dart';
import 'multi_child_evaluation_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});
  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with TickerProviderStateMixin {
  late AnimationController _staggerController;
  late Animation<double> _headerAnim;
  late Animation<double> _kpiAnim;
  late Animation<double> _podiumAnim;
  late Animation<double> _actionsAnim;
  late Animation<double> _tradesAnim;

  @override
  void initState() {
    super.initState();
    _staggerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );

    _headerAnim = CurvedAnimation(
      parent: _staggerController,
      curve: const Interval(0.0, 0.25, curve: Curves.easeOutCubic),
    );
    _kpiAnim = CurvedAnimation(
      parent: _staggerController,
      curve: const Interval(0.15, 0.45, curve: Curves.easeOutCubic),
    );
    _podiumAnim = CurvedAnimation(
      parent: _staggerController,
      curve: const Interval(0.30, 0.65, curve: Curves.easeOutCubic),
    );
    _actionsAnim = CurvedAnimation(
      parent: _staggerController,
      curve: const Interval(0.50, 0.85, curve: Curves.easeOutCubic),
    );
    _tradesAnim = CurvedAnimation(
      parent: _staggerController,
      curve: const Interval(0.70, 1.0, curve: Curves.easeOutCubic),
    );

    _staggerController.forward();
  }

  @override
  void dispose() {
    _staggerController.dispose();
    super.dispose();
  }

  Widget _buildChildAvatar(ChildModel child, double radius) {
    if (child.hasPhoto) {
      try {
        final bytes = base64Decode(child.photoBase64);
        return Container(
          width: radius * 2,
          height: radius * 2,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
                color: EmeraldPalette.emerald.withValues(alpha: 0.5),
                width: 2),
            image: DecorationImage(
              image: MemoryImage(bytes),
              fit: BoxFit.cover,
            ),
          ),
        );
      } catch (_) {}
    }
    return Container(
      width: radius * 2,
      height: radius * 2,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [
            EmeraldPalette.emerald.withValues(alpha: 0.4),
            EmeraldPalette.emeraldDark.withValues(alpha: 0.3),
          ],
        ),
        border: Border.all(
            color: EmeraldPalette.emerald.withValues(alpha: 0.4), width: 1.5),
      ),
      child: Center(
        child: Text(
          child.avatar.isNotEmpty
              ? child.avatar
              : (child.name.isNotEmpty ? child.name[0].toUpperCase() : '?'),
          style: TextStyle(
            color: EmeraldPalette.textPrimary,
            fontWeight: FontWeight.w700,
            fontSize: radius * 0.7,
          ),
        ),
      ),
    );
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Bonjour';
    if (hour < 18) return 'Bon après-midi';
    return 'Bonsoir';
  }

  /// Récupère les entrées d'historique du jour (depuis le FamilyProvider via context)
  List<HistoryEntry> get _historyForToday {
    // Cette méthode est appelée dans build(), on a donc accès au provider
    // via le Consumer parent. Mais comme on est dans _DashboardScreenState,
    // on doit utiliser un contexte. Plus simple : on le passe en paramètre.
    return _cachedHistory;
  }

  List<HistoryEntry> _cachedHistory = [];

  int _getTodayActionsCount(FamilyProvider fp) {
    final today = DateTime.now();
    final todayStart = DateTime(today.year, today.month, today.day);
    return fp.history.where((h) => h.date.isAfter(todayStart)).length;
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<FamilyProvider>(
      builder: (context, fp, _) {
        final sorted = List<ChildModel>.from(fp.children)
          ..sort((a, b) => b.points.compareTo(a.points));
        final totalPoints =
            fp.children.fold<int>(0, (sum, c) => sum + c.points);
        final activeTrades = fp.trades.where((t) => t.isActive).toList();
        _cachedHistory = fp.history;

        return EmeraldBackground(
          child: Scaffold(
            backgroundColor: Colors.transparent,
            body: SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    _AnimatedFade(
                      animation: _headerAnim,
                      child: EmeraldHeader(
                        title: _getGreeting(),
                        subtitle:
                            '${emeraldFormatDate(DateTime.now())} · ${fp.children.length} enfants',
                        actionIcon: Icons.menu_rounded,
                        onActionTap: () => Scaffold.of(context).openDrawer(),
                      ),
                    ),

                    // KPIs
                    _AnimatedFade(
                      animation: _kpiAnim,
                      child: _buildKpis(fp, totalPoints),
                    ),

                    // Podium (Classement)
                    if (sorted.isNotEmpty)
                      _AnimatedFade(
                        animation: _podiumAnim,
                        child: _buildPodiumSection(sorted),
                      ),

                    // Quick Actions
                    _AnimatedFade(
                      animation: _actionsAnim,
                      child: _buildQuickActions(fp),
                    ),

                    // Activité récente
                    if (fp.history.isNotEmpty)
                      _AnimatedFade(
                        animation: _tradesAnim,
                        child: _buildRecentActivity(fp),
                      ),

                    // Active Trades
                    if (activeTrades.isNotEmpty)
                      _AnimatedFade(
                        animation: _tradesAnim,
                        child: _buildActiveTrades(fp, activeTrades),
                      ),

                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildKpis(FamilyProvider fp, int totalPoints) {
    return Row(
      children: [
        Expanded(
          child: EmeraldKpiCard(
            label: 'Points famille',
            value: '$totalPoints',
            icon: Icons.emoji_events_rounded,
            accentColor: EmeraldPalette.gold,
            animateCountUp: true,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: EmeraldKpiCard(
            label: 'Enfants',
            value: '${fp.children.length}',
            sublabel: 'actifs',
            icon: Icons.groups_rounded,
            accentColor: EmeraldPalette.emerald,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: EmeraldKpiCard(
            label: "Aujourd'hui",
            value: '${_getTodayActionsCount(fp)}',
            sublabel: 'actions',
            icon: Icons.bolt_rounded,
            accentColor: EmeraldPalette.info,
          ),
        ),
      ],
    );
  }

  Widget _buildPodiumSection(List<ChildModel> sorted) {
    // Calcul des points gagnés aujourd'hui par enfant
    final today = DateTime.now();
    final todayStart = DateTime(today.year, today.month, today.day);
    final pointsTodayByChild = <String, int>{};
    for (final entry in _historyForToday) {
      if (entry.isBonus) {
        pointsTodayByChild[entry.childId] =
            (pointsTodayByChild[entry.childId] ?? 0) + entry.points;
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const EmeraldSectionTitle(
          title: 'Nos Étoiles',
          icon: Icons.auto_awesome_rounded,
        ),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 0.62,
          children: sorted.map((child) {
            return EmeraldChildCard(
              name: child.name,
              levelTitle: child.levelTitle,
              levelProgress: child.levelProgress,
              points: child.points,
              pointsToday: pointsTodayByChild[child.id] ?? 0,
              badgeCount: child.badgeIds.length,
              streakDays: child.streakDays,
              avatar: _buildChildAvatar(child, 32),
              onTap: () => Navigator.push(
                context,
                ZoomPageRoute(
                    page: ChildDashboardScreen(childId: child.id)),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildQuickActions(FamilyProvider fp) {
    final actions = [
      _Act('Lignes Punition', Icons.menu_book_rounded, EmeraldPalette.error, () {
        Navigator.push(
            context,
            SlidePageRoute(
                page: const PunishmentLinesScreen(),
                direction: SlideDirection.up));
      }),
      _Act("Lignes d'Immunité", Icons.shield_rounded, EmeraldPalette.warning, () {
        Navigator.push(
            context, SpinPageRoute(page: const ImmunityLinesScreen()));
      }),
      _Act('Temps Écran', Icons.tv_rounded, EmeraldPalette.info, () {
        _showChildPickerForNav(fp, (childId) {
          Navigator.push(context,
              ZoomPageRoute(page: ChildDashboardScreen(childId: childId)));
        });
      }),
      _Act('Tribunal', Icons.gavel_rounded, const Color(0xFF8B5CF6), () {
        Navigator.push(
            context, SlidePageRoute(page: const TribunalScreen()));
      }),
      _Act('Ventes', Icons.storefront_rounded, EmeraldPalette.emerald, () {
        _showChildPickerForNav(fp, (childId) {
          Navigator.push(context,
              DoorPageRoute(page: TradeScreen(childId: childId)));
        });
      }),
      _Act('Notes Scolaires', Icons.note_alt_rounded, const Color(0xFFEC4899), () {
        Navigator.push(
            context, SlidePageRoute(page: const MultiChildEvaluationScreen()));
      }),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const EmeraldSectionTitle(
          title: 'Actions rapides',
          icon: Icons.bolt_outlined,
        ),
        GridView.count(
          crossAxisCount: 3,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 0.95,
          children: actions
              .map((a) => EmeraldActionTile(
                    label: a.label,
                    icon: a.icon,
                    accentColor: a.color,
                    onTap: a.onTap,
                  ))
              .toList(),
        ),
      ],
    );
  }

  Widget _buildRecentActivity(FamilyProvider fp) {
    // Prendre les 3 dernières entrées d'historique
    final recent = List<HistoryEntry>.from(fp.history);
    recent.sort((a, b) => b.date.compareTo(a.date));
    final top3 = recent.take(3).toList();

    if (top3.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        EmeraldSectionTitle(
          title: 'Activité récente',
          icon: Icons.history_rounded,
        ),
        EmeraldCard(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            children: top3.map((entry) {
              final child = fp.getChild(entry.childId);
              return Column(
                children: [
                  EmeraldActivityRow(
                    childName: child?.name ?? 'Enfant',
                    reason: entry.reason,
                    points: entry.points,
                    isBonus: entry.isBonus,
                    date: entry.date,
                    actionBy: entry.actionBy,
                    onTap: () {
                      if (child != null) {
                        Navigator.push(
                          context,
                          ZoomPageRoute(
                              page: ChildDashboardScreen(childId: child.id)),
                        );
                      }
                    },
                  ),
                  if (entry != top3.last)
                    Divider(
                      color: EmeraldPalette.glassBorder,
                      height: 1,
                      indent: 14,
                      endIndent: 14,
                    ),
                ],
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildActiveTrades(FamilyProvider fp, List<TradeModel> active) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        EmeraldSectionTitle(
          title: 'Ventes en cours',
          icon: Icons.storefront_outlined,
          trailing: '${active.length}',
        ),
        ...active.map((trade) {
          final sellerName = fp.getChild(trade.fromChildId)?.name ?? '?';
          final buyerName = fp.getChild(trade.toChildId)?.name ?? '?';
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: TvFocusWrapper(
              onTap: () {
                Navigator.push(
                    context,
                    DoorPageRoute(
                        page: TradeScreen(childId: trade.fromChildId)));
              },
              child: EmeraldCard(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: EmeraldPalette.emerald,
                        boxShadow: [
                          BoxShadow(
                            color: EmeraldPalette.emerald.withValues(alpha: 0.5),
                            blurRadius: 6,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '$sellerName → $buyerName',
                            style: EmeraldTypography.heading.copyWith(
                                fontSize: 14, fontWeight: FontWeight.w600),
                          ),
                          Text(
                            '${trade.immunityLines} lignes · ${trade.serviceDescription}',
                            style: EmeraldTypography.caption
                                .copyWith(fontSize: 12),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: EmeraldPalette.emerald.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        trade.statusLabel,
                        style: EmeraldTypography.caption.copyWith(
                          color: EmeraldPalette.emeraldLight,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Icon(Icons.chevron_right_rounded,
                        color: EmeraldPalette.textMuted, size: 22),
                  ],
                ),
              ),
            ),
          );
        }),
      ],
    );
  }

  // ─── Sélecteur enfant (gardé à l'identique, fonctionne avec le nouveau thème) ───
  void _showChildPickerForNav(
      FamilyProvider fp, Function(String) onSelected) {
    if (fp.children.isEmpty) return;
    if (fp.children.length == 1) {
      onSelected(fp.children.first.id);
      return;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => _ChildPickerSheet(
        children: fp.children,
        onSelected: (id) {
          Navigator.pop(ctx);
          onSelected(id);
        },
        buildAvatar: _buildChildAvatar,
      ),
    );
  }
}

// ─── Widget d'animation fade + slide ───
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

// ─── Sélecteur enfant en bottom sheet (style émeraude) ───
class _ChildPickerSheet extends StatefulWidget {
  final List<ChildModel> children;
  final Function(String) onSelected;
  final Widget Function(ChildModel, double) buildAvatar;

  const _ChildPickerSheet({
    required this.children,
    required this.onSelected,
    required this.buildAvatar,
  });

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
    _animCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 400));
    _slideAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOutCubic);
    _animCtrl.forward();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  List<ChildModel> get _filtered => widget.children
      .where((c) => c.name.toLowerCase().contains(_search.toLowerCase()))
      .toList();

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
    final maxH = MediaQuery.of(context).size.height * 0.85;

    return AnimatedBuilder(
      animation: _slideAnim,
      builder: (_, child) => Transform.translate(
        offset: Offset(0, 60 * (1 - _slideAnim.value)),
        child: Opacity(opacity: _slideAnim.value, child: child),
      ),
      child: Container(
        constraints: BoxConstraints(maxHeight: maxH),
        decoration: BoxDecoration(
          color: EmeraldPalette.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          border: Border.all(color: EmeraldPalette.glassBorder, width: 1),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: EmeraldPalette.textMuted,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: EmeraldPalette.emeraldGradient,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.people_alt_rounded,
                      color: Colors.white, size: 20),
                ),
                const SizedBox(width: 12),
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Choisir un enfant',
                      style: EmeraldTypography.heading.copyWith(fontSize: 18)),
                  Text('${widget.children.length} enfants disponibles',
                      style: EmeraldTypography.caption.copyWith(fontSize: 12)),
                ]),
              ]),
            ),
            const SizedBox(height: 20),
            if (widget.children.length > 4) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Container(
                  decoration: BoxDecoration(
                    color: EmeraldPalette.surfaceLow,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: EmeraldPalette.glassBorder),
                  ),
                  child: TextField(
                    onChanged: (v) => setState(() => _search = v),
                    style: EmeraldTypography.body.copyWith(fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'Rechercher…',
                      hintStyle: TextStyle(color: EmeraldPalette.textMuted),
                      prefixIcon: Icon(Icons.search,
                          color: EmeraldPalette.textMuted, size: 20),
                      border: InputBorder.none,
                      contentPadding:
                          const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
            Flexible(
              child: filtered.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(children: [
                        const Text('📋', style: TextStyle(fontSize: 36)),
                        const SizedBox(height: 8),
                        Text('Aucun résultat',
                            style: EmeraldTypography.caption
                                .copyWith(fontSize: 14)),
                      ]),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 4),
                      shrinkWrap: true,
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (_, i) {
                        final child = filtered[i];
                        return _ChildTile(
                          child: child,
                          accent: EmeraldPalette.emerald,
                          buildAvatar: widget.buildAvatar,
                          onTap: () => widget.onSelected(child.id),
                        );
                      },
                    ),
            ),
            SizedBox(height: MediaQuery.of(context).padding.bottom + 16),
          ],
        ),
      ),
    );
  }
}

class _ChildTile extends StatefulWidget {
  final ChildModel child;
  final Color accent;
  final Widget Function(ChildModel, double) buildAvatar;
  final VoidCallback onTap;

  const _ChildTile({
    required this.child,
    required this.accent,
    required this.buildAvatar,
    required this.onTap,
  });

  @override
  State<_ChildTile> createState() => _ChildTileState();
}

class _ChildTileState extends State<_ChildTile> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final c = widget.child;
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _pressed ? 0.96 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: _pressed
                ? widget.accent.withValues(alpha: 0.15)
                : EmeraldPalette.surfaceLow,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _pressed
                  ? widget.accent.withValues(alpha: 0.5)
                  : EmeraldPalette.glassBorder,
              width: 1,
            ),
          ),
          child: Row(children: [
            widget.buildAvatar(c, 24),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(c.name,
                      style: EmeraldTypography.heading.copyWith(
                          fontSize: 15, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Row(children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: widget.accent.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(c.levelTitle,
                          style: TextStyle(
                              color: widget.accent,
                              fontSize: 10,
                              fontWeight: FontWeight.w600)),
                    ),
                    const SizedBox(width: 6),
                    Text('${c.points} pts',
                        style: EmeraldTypography.caption.copyWith(
                            fontSize: 11)),
                  ]),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios_rounded,
                color: widget.accent, size: 14),
            const SizedBox(width: 6),
            Container(
              width: 48, height: 4,
              decoration: BoxDecoration(
                color: EmeraldPalette.surfaceHigh,
                borderRadius: BorderRadius.circular(2),
              ),
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: c.levelProgress.clamp(0.0, 1.0),
                child: Container(
                  decoration: BoxDecoration(
                    color: widget.accent,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

class _Act {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  _Act(this.label, this.icon, this.color, this.onTap);
}
