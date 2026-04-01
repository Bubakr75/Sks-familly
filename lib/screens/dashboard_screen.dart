// lib/screens/dashboard_screen.dart
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/family_provider.dart';
import '../providers/pin_provider.dart';
import '../models/child_model.dart';
import '../models/trade_model.dart';
import '../utils/pin_guard.dart';
import '../widgets/animated_background.dart';
import '../widgets/glass_card.dart';
import '../widgets/tv_focus_wrapper.dart';
import '../widgets/animated_page_transition.dart';
import '../widgets/celebration_overlay.dart';
import 'punishment_lines_screen.dart';
import 'immunity_lines_screen.dart';
import 'trade_screen.dart';
import 'child_dashboard_screen.dart';
import 'tribunal_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});
  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with TickerProviderStateMixin {
  late AnimationController _podiumController;
  late AnimationController _actionsController;
  late AnimationController _pulseController;
  late AnimationController _floatingController;

  late Animation<double> _podium1Anim;
  late Animation<double> _podium2Anim;
  late Animation<double> _podium3Anim;
  final List<Animation<double>> _actionAnims = [];
  late Animation<double> _pulseAnim;
  late Animation<double> _floatingAnim;

  @override
  void initState() {
    super.initState();
    _podiumController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1800));
    _podium2Anim = CurvedAnimation(
        parent: _podiumController,
        curve: const Interval(0.0, 0.5, curve: Curves.bounceOut));
    _podium1Anim = CurvedAnimation(
        parent: _podiumController,
        curve: const Interval(0.2, 0.7, curve: Curves.bounceOut));
    _podium3Anim = CurvedAnimation(
        parent: _podiumController,
        curve: const Interval(0.4, 0.9, curve: Curves.bounceOut));

    _actionsController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1500));
    for (int i = 0; i < 6; i++) {
      final start = i * 0.10;
      final end = (start + 0.4).clamp(0.0, 1.0);
      _actionAnims.add(CurvedAnimation(
          parent: _actionsController,
          curve: Interval(start, end, curve: Curves.elasticOut)));
    }

    _pulseController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1200))
      ..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 1.0, end: 1.06).animate(
        CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut));

    _floatingController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 3000))
      ..repeat(reverse: true);
    _floatingAnim = Tween<double>(begin: -8, end: 8).animate(
        CurvedAnimation(parent: _floatingController, curve: Curves.easeInOut));

    _podiumController.forward();
    Future.delayed(const Duration(milliseconds: 600), () {
      if (mounted) _actionsController.forward();
    });
  }

  @override
  void dispose() {
    _podiumController.dispose();
    _actionsController.dispose();
    _pulseController.dispose();
    _floatingController.dispose();
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
            border:
                Border.all(color: Colors.amber.withOpacity(0.6), width: 3),
            boxShadow: [
              BoxShadow(
                  color: Colors.amber.withOpacity(0.3),
                  blurRadius: 16,
                  spreadRadius: 2),
            ],
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
            Colors.cyan.withOpacity(0.4),
            Colors.purple.withOpacity(0.3),
          ],
        ),
        border: Border.all(color: Colors.cyan.withOpacity(0.5), width: 2),
        boxShadow: [
          BoxShadow(
              color: Colors.cyan.withOpacity(0.2),
              blurRadius: 12,
              spreadRadius: 2),
        ],
      ),
      child: Center(
        child: Text(
          child.avatar.isNotEmpty
              ? child.avatar
              : (child.name.isNotEmpty ? child.name[0].toUpperCase() : '?'),
          style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: radius * 0.7),
        ),
      ),
    );
  }

  bool _isParentMode() {
    return context.read<PinProvider>().canPerformParentAction();
  }

  // ══ CORRECTION : enterChildMode() appelé avant de naviguer vers un enfant ══
  void _goToChildDashboard(String childId) {
    final pin = context.read<PinProvider>();
    pin.enterChildMode(); // ← bascule en mode enfant
    Navigator.push(
      context,
      ZoomPageRoute(page: ChildDashboardScreen(childId: childId)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<FamilyProvider>(
      builder: (context, fp, _) {
        final sorted = List<ChildModel>.from(fp.children)
          ..sort((a, b) => b.points.compareTo(a.points));

        return AnimatedBackground(
          child: Scaffold(
            backgroundColor: Colors.transparent,
            body: SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeader(fp),
                    const SizedBox(height: 20),
                    if (sorted.isNotEmpty) _buildPodium(sorted),
                    const SizedBox(height: 20),
                    _buildQuickActions(fp),
                    const SizedBox(height: 20),
                    _buildActiveTrades(fp),
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

  Widget _buildHeader(FamilyProvider fp) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 800),
      curve: Curves.easeOutBack,
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(0, -30 * (1 - value)),
          child: Opacity(opacity: value, child: child),
        );
      },
      child: Row(
        children: [
          AnimatedBuilder(
            animation: _floatingAnim,
            builder: (context, child) {
              return Transform.translate(
                offset: Offset(0, _floatingAnim.value),
                child: child,
              );
            },
            child: const Text('🏠', style: TextStyle(fontSize: 28)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ShaderMask(
                  shaderCallback: (bounds) => const LinearGradient(
                    colors: [Colors.white, Colors.cyanAccent],
                  ).createShader(bounds),
                  child: const Text('Tableau de Bord',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold)),
                ),
                Text(
                  '${fp.children.length} enfant${fp.children.length > 1 ? 's' : ''} • ${fp.currentParentName}',
                  style:
                      const TextStyle(color: Colors.white54, fontSize: 13),
                ),
              ],
            ),
          ),
          Consumer<PinProvider>(
            builder: (context, pin, _) {
              final isParent = pin.canPerformParentAction();
              return TvFocusWrapper(
                onTap: () {
                  if (!isParent && pin.isPinSet) {
                    PinGuard.guardAction(context, () => setState(() {}));
                  }
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 5),
                  margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                    color: isParent
                        ? Colors.greenAccent.withOpacity(0.15)
                        : Colors.redAccent.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isParent
                          ? Colors.greenAccent.withOpacity(0.4)
                          : Colors.redAccent.withOpacity(0.4),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: (isParent
                                ? Colors.greenAccent
                                : Colors.redAccent)
                            .withOpacity(0.15),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isParent ? Icons.lock_open : Icons.lock,
                        color: isParent
                            ? Colors.greenAccent
                            : Colors.redAccent,
                        size: 14,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        isParent ? 'Parent' : 'Enfant',
                        style: TextStyle(
                          color: isParent
                              ? Colors.greenAccent
                              : Colors.redAccent,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          TvFocusWrapper(
            onTap: () => Scaffold.of(context).openDrawer(),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child:
                  const Icon(Icons.menu, color: Colors.white, size: 24),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPodium(List<ChildModel> sorted) {
    return GlassCard(
      child: Column(
        children: [
          AnimatedBuilder(
            animation: _floatingAnim,
            builder: (context, child) {
              return Transform.translate(
                offset: Offset(0, _floatingAnim.value * 0.3),
                child: child,
              );
            },
            child: ShaderMask(
              shaderCallback: (bounds) => const LinearGradient(
                colors: [Colors.amber, Colors.orange, Colors.amber],
              ).createShader(bounds),
              child: const Text('🏆 CLASSEMENT',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white)),
            ),
          ),
          const SizedBox(height: 20),
          if (sorted.length >= 2)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                AnimatedBuilder(
                  animation: _podium2Anim,
                  builder: (context, child) {
                    return Transform.translate(
                      offset: Offset(0, 50 * (1 - _podium2Anim.value)),
                      child: Opacity(
                          opacity: _podium2Anim.value,
                          child: _podiumCard(sorted[1], 2)),
                    );
                  },
                ),
                const SizedBox(width: 8),
                AnimatedBuilder(
                  animation: _podium1Anim,
                  builder: (context, child) {
                    return Transform.translate(
                      offset: Offset(0, 60 * (1 - _podium1Anim.value)),
                      child: Opacity(
                        opacity: _podium1Anim.value,
                        child: _podiumCard(sorted[0], 1),
                      ),
                    );
                  },
                ),
                const SizedBox(width: 8),
                if (sorted.length >= 3)
                  AnimatedBuilder(
                    animation: _podium3Anim,
                    builder: (context, child) {
                      return Transform.translate(
                        offset: Offset(0, 40 * (1 - _podium3Anim.value)),
                        child: Opacity(
                            opacity: _podium3Anim.value,
                            child: _podiumCard(sorted[2], 3)),
                      );
                    },
                  ),
              ],
            )
          else
            _podiumCard(sorted[0], 1),
          if (sorted.length > 3) ...[
            const SizedBox(height: 16),
            const Divider(color: Colors.white12),
            ...sorted.skip(3).toList().asMap().entries.map((entry) {
              final child = entry.value;
              final rank = entry.key + 4;
              return TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.0, end: 1.0),
                duration:
                    Duration(milliseconds: 600 + entry.key * 150),
                curve: Curves.easeOutBack,
                builder: (context, value, ch) {
                  return Transform.translate(
                    offset: Offset(30 * (1 - value), 0),
                    child: Opacity(opacity: value, child: ch),
                  );
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: TvFocusWrapper(
                    // ══ CORRECTION : utilise _goToChildDashboard ══
                    onTap: () => _goToChildDashboard(child.id),
                    child: Row(
                      children: [
                        Text('#$rank',
                            style: const TextStyle(
                                color: Colors.white38,
                                fontWeight: FontWeight.bold,
                                fontSize: 14)),
                        const SizedBox(width: 10),
                        _buildChildAvatar(child, 18),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(child.name,
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 14)),
                        ),
                        Text('${child.points} pts',
                            style: const TextStyle(
                                color: Colors.white54,
                                fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ],
        ],
      ),
    );
  }

  Widget _podiumCard(ChildModel child, int rank) {
    final heights = {1: 110.0, 2: 85.0, 3: 65.0};
    final colors = {1: Colors.amber, 2: Colors.grey, 3: Colors.orange};
    final medals = {1: '🥇', 2: '🥈', 3: '🥉'};
    final avatarRadius = rank == 1 ? 40.0 : 28.0;

    return TvFocusWrapper(
      // ══ CORRECTION : utilise _goToChildDashboard ══
      onTap: () => _goToChildDashboard(child.id),
      child: SizedBox(
        width: rank == 1 ? 115 : 90,
        child: Column(
          children: [
            AnimatedBuilder(
              animation: _floatingAnim,
              builder: (context, ch) {
                return Transform.translate(
                  offset: Offset(
                      0, rank == 1 ? _floatingAnim.value * 0.5 : 0),
                  child: ch,
                );
              },
              child: Text(medals[rank]!,
                  style: const TextStyle(fontSize: 24)),
            ),
            const SizedBox(height: 6),
            if (rank == 1)
              NeonPulseRing(
                color: Colors.amber,
                radius: avatarRadius + 4,
                child: Padding(
                  padding: const EdgeInsets.all(6),
                  child: _buildChildAvatar(child, avatarRadius),
                ),
              )
            else
              _buildChildAvatar(child, avatarRadius),
            const SizedBox(height: 6),
            Text(child.name,
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 13),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
            TweenAnimationBuilder<int>(
              tween: IntTween(begin: 0, end: child.points),
              duration: const Duration(milliseconds: 1500),
              builder: (context, val, _) {
                return Text('$val pts',
                    style: TextStyle(
                        color: colors[rank],
                        fontWeight: FontWeight.bold,
                        fontSize: 14));
              },
            ),
            Text(child.levelTitle,
                style: TextStyle(
                    color: colors[rank]!.withOpacity(0.7),
                    fontSize: 10)),
            const SizedBox(height: 4),
            AnimatedBuilder(
              animation: _pulseAnim,
              builder: (context, ch) {
                return Transform.scale(
                  scale: rank == 1 ? _pulseAnim.value : 1.0,
                  child: ch,
                );
              },
              child: Container(
                width: 70,
                height: heights[rank],
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      colors[rank]!.withOpacity(0.8),
                      colors[rank]!.withOpacity(0.3),
                    ],
                  ),
                  borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(8)),
                  boxShadow: [
                    BoxShadow(
                      color: colors[rank]!.withOpacity(0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Center(
                  child: Text('#$rank',
                      style: TextStyle(
                          color: Colors.white.withOpacity(0.9),
                          fontWeight: FontWeight.bold,
                          fontSize: 20)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActions(FamilyProvider fp) {
    final isParent = _isParentMode();

    final actions = [
      _Act('📝 Punition', Icons.menu_book, Colors.red, true, () {
        PinGuard.guardAction(context, () {
          Navigator.push(
              context,
              SlidePageRoute(
                  page: const PunishmentLinesScreen(),
                  direction: SlideDirection.up));
        });
      }),
      _Act('🛡️ Immunité', Icons.shield, Colors.amber, true, () {
        PinGuard.guardAction(context, () {
          Navigator.push(
              context, SpinPageRoute(page: const ImmunityLinesScreen()));
        });
      }),
      _Act('📺 Écran', Icons.tv, Colors.blue, true, () {
        PinGuard.guardAction(context, () {
          _showChildPickerForNav(fp, (childId) {
            // ══ CORRECTION : pas de enterChildMode ici car c'est une
            // action protégée parent (PinGuard déjà vérifié) ══
            Navigator.push(context,
                ZoomPageRoute(page: ChildDashboardScreen(childId: childId)));
          });
        });
      }),
      _Act('⚖️ Tribunal', Icons.gavel, Colors.purple, false, () {
        Navigator.push(
            context, SlidePageRoute(page: const TribunalScreen()));
      }),
      _Act('🏪 Vente', Icons.storefront, Colors.green, false, () {
        _showChildPickerForNav(fp, (childId) {
          Navigator.push(
              context,
              DoorPageRoute(page: TradeScreen(childId: childId)));
        });
      }),
      // ══ CORRECTION : "Profil" bascule en mode enfant ══
      _Act('👤 Profil', Icons.person, Colors.cyan, false, () {
        _showChildPickerForNav(fp, (childId) {
          _goToChildDashboard(childId);
        });
      }),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.0, end: 1.0),
          duration: const Duration(milliseconds: 800),
          curve: Curves.easeOutBack,
          builder: (context, value, child) {
            return Opacity(
              opacity: value,
              child: Transform.translate(
                  offset: Offset(-20 * (1 - value), 0), child: child),
            );
          },
          child: const Text('⚡ Actions Rapides',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold)),
        ),
        const SizedBox(height: 10),
        GridView.count(
          crossAxisCount: 3,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 1.05,
          children: List.generate(actions.length, (i) {
            final action = actions[i];
            final anim =
                i < _actionAnims.length ? _actionAnims[i] : null;
            final tile = _actionTile(action, isParent);
            if (anim == null) return tile;
            return AnimatedBuilder(
              animation: anim,
              builder: (context, child) {
                return Transform.scale(
                  scale: anim.value.clamp(0.0, 1.0),
                  child: Opacity(
                      opacity: anim.value.clamp(0.0, 1.0),
                      child: child),
                );
              },
              child: tile,
            );
          }),
        ),
      ],
    );
  }

  Widget _actionTile(_Act action, bool isParent) {
    return TvFocusWrapper(
      onTap: action.onTap,
      child: GlassCard(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: action.color.withOpacity(0.15),
                boxShadow: [
                  BoxShadow(
                      color: action.color.withOpacity(0.3),
                      blurRadius: 12,
                      spreadRadius: 2),
                ],
              ),
              child: Icon(action.icon, color: action.color, size: 24),
            ),
            const SizedBox(height: 6),
            Text(action.label,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w600),
                textAlign: TextAlign.center),
            if (action.parentOnly && !isParent)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Icon(Icons.lock,
                    color: Colors.white.withOpacity(0.3), size: 12),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveTrades(FamilyProvider fp) {
    final active = fp.trades.where((t) => t.isActive).toList();
    if (active.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.0, end: 1.0),
          duration: const Duration(milliseconds: 800),
          builder: (context, value, child) {
            return Opacity(opacity: value, child: child);
          },
          child: const Text('🏪 Ventes en cours',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold)),
        ),
        const SizedBox(height: 8),
        ...active.asMap().entries.map((entry) {
          final trade = entry.value;
          final sellerName =
              fp.getChild(trade.fromChildId)?.name ?? '?';
          final buyerName = fp.getChild(trade.toChildId)?.name ?? '?';
          return TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: 1.0),
            duration: Duration(milliseconds: 500 + entry.key * 200),
            curve: Curves.easeOutCubic,
            builder: (context, value, child) {
              return Transform.translate(
                offset: Offset(0, 20 * (1 - value)),
                child: Opacity(opacity: value, child: child),
              );
            },
            child: Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: TvFocusWrapper(
                onTap: () {
                  Navigator.push(
                      context,
                      DoorPageRoute(
                          page:
                              TradeScreen(childId: trade.fromChildId)));
                },
                child: GlassCard(
                  child: Row(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.greenAccent,
                          boxShadow: [
                            BoxShadow(
                                color:
                                    Colors.greenAccent.withOpacity(0.5),
                                blurRadius: 6),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('$sellerName → $buyerName',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold)),
                            Text(
                                '${trade.immunityLines} lignes • ${trade.serviceDescription}',
                                style: const TextStyle(
                                    color: Colors.white54,
                                    fontSize: 12),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color:
                              Colors.greenAccent.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(trade.statusLabel,
                            style: const TextStyle(
                                color: Colors.greenAccent,
                                fontSize: 11)),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.chevron_right,
                          color: Colors.white38),
                    ],
                  ),
                ),
              ),
            ),
          );
        }),
      ],
    );
  }

  // ══ CORRECTION scroll : maxChildSize 0.92, initialChildSize 0.55 ══
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
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.55,
          minChildSize: 0.35,
          maxChildSize: 0.92,
          expand: false,
          builder: (_, scrollController) {
            return Container(
              decoration: const BoxDecoration(
                color: Color(0xFF1A1A2E),
                borderRadius:
                    BorderRadius.vertical(top: Radius.circular(20)),
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
                  const Text('Choisir un enfant',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  Expanded(
                    child: ListView.builder(
                      controller: scrollController,
                      padding:
                          const EdgeInsets.fromLTRB(16, 0, 16, 24),
                      itemCount: fp.children.length,
                      itemBuilder: (_, i) {
                        final child = fp.children[i];
                        return TweenAnimationBuilder<double>(
                          tween: Tween(begin: 0.0, end: 1.0),
                          duration:
                              Duration(milliseconds: 300 + i * 100),
                          curve: Curves.easeOutBack,
                          builder: (context, value, ch) {
                            return Transform.translate(
                              offset: Offset(30 * (1 - value), 0),
                              child:
                                  Opacity(opacity: value, child: ch),
                            );
                          },
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: TvFocusWrapper(
                              onTap: () {
                                Navigator.pop(ctx);
                                onSelected(child.id);
                              },
                              child: GlassCard(
                                padding: const EdgeInsets.symmetric(
                                    vertical: 10, horizontal: 14),
                                borderRadius: 14,
                                child: Row(
                                  children: [
                                    _buildChildAvatar(child, 22),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(child.name,
                                              style: const TextStyle(
                                                  color: Colors.white,
                                                  fontWeight:
                                                      FontWeight.bold)),
                                          Text(
                                              '${child.points} pts • ${child.levelTitle}',
                                              style: const TextStyle(
                                                  color: Colors.white54,
                                                  fontSize: 12)),
                                        ],
                                      ),
                                    ),
                                    const Icon(Icons.chevron_right,
                                        color: Colors.white38),
                                  ],
                                ),
                              ),
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
}

class _Act {
  final String label;
  final IconData icon;
  final Color color;
  final bool parentOnly;
  final VoidCallback onTap;
  _Act(this.label, this.icon, this.color, this.parentOnly, this.onTap);
}
