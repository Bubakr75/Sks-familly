import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/family_provider.dart';
import '../models/child_model.dart';
import '../models/trade_model.dart';
import '../widgets/animated_background.dart';
import '../widgets/glass_card.dart';
import '../widgets/tv_focus_wrapper.dart';
import '../widgets/animated_page_transition.dart';
import 'punishment_lines_screen.dart';
import 'immunity_lines_screen.dart';
import 'trade_screen.dart';
import 'child_dashboard_screen.dart';
import 'badges_screen.dart';

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

  late Animation<double> _podium1Anim;
  late Animation<double> _podium2Anim;
  late Animation<double> _podium3Anim;
  final List<Animation<double>> _actionAnims = [];
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();

    _podiumController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );
    _podium2Anim = CurvedAnimation(
      parent: _podiumController,
      curve: const Interval(0.0, 0.5, curve: Curves.bounceOut),
    );
    _podium1Anim = CurvedAnimation(
      parent: _podiumController,
      curve: const Interval(0.2, 0.7, curve: Curves.bounceOut),
    );
    _podium3Anim = CurvedAnimation(
      parent: _podiumController,
      curve: const Interval(0.4, 0.9, curve: Curves.bounceOut),
    );

    _actionsController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    for (int i = 0; i < 6; i++) {
      final start = i * 0.12;
      final end = (start + 0.4).clamp(0.0, 1.0);
      _actionAnims.add(CurvedAnimation(
        parent: _actionsController,
        curve: Interval(start, end, curve: Curves.elasticOut),
      ));
    }

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<FamilyProvider>(
      builder: (context, fp, _) {
        final sorted = List<ChildModel>.from(fp.children)
          ..sort((a, b) => b.totalPoints.compareTo(a.totalPoints));

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
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(0, -20 * (1 - value)),
          child: Opacity(opacity: value, child: child),
        );
      },
      child: Row(
        children: [
          const Text('👨‍👩‍👧‍👦', style: TextStyle(fontSize: 28)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Tableau de Bord',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold)),
                Text(
                  '${fp.children.length} enfant${fp.children.length > 1 ? 's' : ''} • ${fp.activeParent ?? 'Parent'}',
                  style: const TextStyle(color: Colors.white54, fontSize: 13),
                ),
              ],
            ),
          ),
          TvFocusWrapper(
            onTap: () => Scaffold.of(context).openDrawer(),
            child: const Icon(Icons.menu, color: Colors.white, size: 28),
          ),
        ],
      ),
    );
  }

  Widget _buildPodium(List<ChildModel> sorted) {
    return GlassCard(
      child: Column(
        children: [
          ShaderMask(
            shaderCallback: (bounds) => const LinearGradient(
              colors: [Colors.amber, Colors.orange, Colors.amber],
            ).createShader(bounds),
            child: const Text('🏆 CLASSEMENT',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white)),
          ),
          const SizedBox(height: 16),
          if (sorted.length >= 2)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (sorted.length >= 2)
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
                  animation: Listenable.merge([_podium1Anim, _pulseAnim]),
                  builder: (context, child) {
                    return Transform.translate(
                      offset: Offset(0, 60 * (1 - _podium1Anim.value)),
                      child: Opacity(
                        opacity: _podium1Anim.value,
                        child: Transform.scale(
                          scale: _pulseAnim.value,
                          child: _podiumCard(sorted[0], 1),
                        ),
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
        ],
      ),
    );
  }

  Widget _podiumCard(ChildModel child, int rank) {
    final heights = {1: 110.0, 2: 85.0, 3: 65.0};
    final colors = {1: Colors.amber, 2: Colors.grey, 3: Colors.orange};
    final medals = {1: '🥇', 2: '🥈', 3: '🥉'};

    return TvFocusWrapper(
      onTap: () {
        // ★ TRANSITION ZOOM vers le profil enfant
        Navigator.push(context,
            ZoomPageRoute(page: ChildDashboardScreen(childId: child.id)));
      },
      child: Column(
        children: [
          Text(medals[rank]!, style: const TextStyle(fontSize: 22)),
          const SizedBox(height: 4),
          CircleAvatar(
            radius: rank == 1 ? 26 : 20,
            backgroundColor: Colors.cyan.withOpacity(0.3),
            child: Text(
              child.name.isNotEmpty ? child.name[0].toUpperCase() : '?',
              style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: rank == 1 ? 20 : 16),
            ),
          ),
          const SizedBox(height: 4),
          Text(child.name,
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12)),
          TweenAnimationBuilder<int>(
            tween: IntTween(begin: 0, end: child.totalPoints),
            duration: const Duration(milliseconds: 1500),
            builder: (context, val, _) {
              return Text('$val pts',
                  style: TextStyle(
                      color: colors[rank],
                      fontWeight: FontWeight.bold,
                      fontSize: 13));
            },
          ),
          const SizedBox(height: 4),
          Container(
            width: 65,
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
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(8)),
            ),
            child: Center(
              child: Text('#$rank',
                  style: TextStyle(
                      color: Colors.white.withOpacity(0.9),
                      fontWeight: FontWeight.bold,
                      fontSize: 18)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions(FamilyProvider fp) {
    final actions = [
      // ★ Chaque action avec sa transition unique
      _Act('Punition', Icons.menu_book, Colors.red, () {
        Navigator.push(context, SlidePageRoute(
          page: const PunishmentLinesScreen(),
          direction: SlideDirection.up,
        ));
      }),
      _Act('Immunité', Icons.shield, Colors.amber, () {
        Navigator.push(context,
            SpinPageRoute(page: const ImmunityLinesScreen()));
      }),
      _Act('Écran', Icons.tv, Colors.blue, () {
        _showChildPickerForScreen(fp);
      }),
      _Act('Tribunal', Icons.gavel, Colors.purple, () {
        // TODO
      }),
      _Act('Badges', Icons.emoji_events, Colors.orange, () {
        Navigator.push(context,
            ZoomPageRoute(page: const BadgesScreen()));
      }),
      _Act('Ventes', Icons.store, Colors.green, () {
        Navigator.push(context,
            DoorPageRoute(page: const TradeScreen()));
      }),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.0, end: 1.0),
          duration: const Duration(milliseconds: 800),
          builder: (context, value, child) {
            return Opacity(
              opacity: value,
              child: Transform.translate(
                offset: Offset(-20 * (1 - value), 0),
                child: child,
              ),
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
          childAspectRatio: 1.1,
          children: List.generate(actions.length, (i) {
            final action = actions[i];
            final anim =
                i < _actionAnims.length ? _actionAnims[i] : null;
            if (anim == null) {
              return _actionTile(action);
            }
            return AnimatedBuilder(
              animation: anim,
              builder: (context, child) {
                return Transform.scale(
                  scale: anim.value.clamp(0.0, 1.0),
                  child: Opacity(
                      opacity: anim.value.clamp(0.0, 1.0), child: child),
                );
              },
              child: _actionTile(action),
            );
          }),
        ),
      ],
    );
  }

  Widget _actionTile(_Act action) {
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
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Icon(action.icon, color: action.color, size: 26),
            ),
            const SizedBox(height: 8),
            Text(action.label,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w600),
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveTrades(FamilyProvider fp) {
    final active =
        fp.trades.where((t) => t.status == TradeStatus.active).toList();
    if (active.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('🔄 Échanges en cours',
            style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        ...active.asMap().entries.map((entry) {
          final trade = entry.value;
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
                  // ★ TRANSITION PORTE vers TradeScreen
                  Navigator.push(context,
                      DoorPageRoute(page: const TradeScreen()));
                },
                child: GlassCard(
                  child: Row(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.cyan,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.cyan.withOpacity(0.5),
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
                            Text(trade.serviceDescription ?? 'Échange',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold)),
                            Text('${trade.lineCount} lignes',
                                style: const TextStyle(
                                    color: Colors.white54, fontSize: 12)),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right, color: Colors.white38),
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

  void _showChildPickerForScreen(FamilyProvider fp) {
    if (fp.children.isEmpty) return;
    if (fp.children.length == 1) {
      // ★ TRANSITION ZOOM
      Navigator.push(
        context,
        ZoomPageRoute(
            page: ChildDashboardScreen(childId: fp.children.first.id)),
      );
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
                    // ★ TRANSITION ZOOM
                    Navigator.push(
                      context,
                      ZoomPageRoute(
                          page: ChildDashboardScreen(childId: child.id)),
                    );
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
                  ),
                );
              }),
            ],
          ),
        );
      },
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
