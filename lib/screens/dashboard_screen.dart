import '../utils/image_cache_util.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/family_provider.dart';
import '../models/child_model.dart';
import '../widgets/animated_background.dart';
import '../widgets/glass_card.dart';
import '../widgets/tv_focus_wrapper.dart';
import '../widgets/animated_page_transition.dart';
import '../utils/tv_detector.dart';
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
    _pulseAnim = Tween<double>(begin: 1.0, end: 1.08).animate(
        CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut));

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

  Widget _buildChildAvatar(ChildModel child, double radius) {
    if (child.hasPhoto) {
      try {
        final bytes = ImageCacheUtil.fromBase64(child.photoBase64);
        return Container(
          width: radius * 2, height: radius * 2,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.amber.withOpacity(0.6), width: 3),
            boxShadow: [BoxShadow(color: Colors.amber.withOpacity(0.3), blurRadius: 16, spreadRadius: 2)],
            image: DecorationImage(image: MemoryImage(bytes), fit: BoxFit.cover),
          ),
        );
      } catch (_) {}
    }
    return Container(
      width: radius * 2, height: radius * 2,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(colors: [Colors.cyan.withOpacity(0.4), Colors.purple.withOpacity(0.3)]),
        border: Border.all(color: Colors.cyan.withOpacity(0.5), width: 2),
        boxShadow: [BoxShadow(color: Colors.cyan.withOpacity(0.2), blurRadius: 12, spreadRadius: 2)],
      ),
      child: Center(
        child: Text(
          child.avatar.isNotEmpty ? child.avatar : (child.name.isNotEmpty ? child.name[0].toUpperCase() : '?'),
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: radius * 0.7),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isTV = TvDetector.isTV;
    return Consumer<FamilyProvider>(
      builder: (context, fp, _) {
        final sorted = List<ChildModel>.from(fp.children)
          ..sort((a, b) => b.points.compareTo(a.points));
        if (isTV) return _buildTvLayout(fp, sorted);
        return _buildMobileLayout(fp, sorted);
      },
    );
  }

  // ==================== TV LAYOUT ====================
  Widget _buildTvLayout(FamilyProvider fp, List<ChildModel> sorted) {
    return AnimatedBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // GAUCHE: Header + Podium
                Expanded(
                  flex: 5,
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildHeaderTV(fp),
                        const SizedBox(height: 24),
                        if (sorted.isNotEmpty) _buildPodiumTV(sorted),
                        const SizedBox(height: 24),
                        _buildActiveTradesTV(fp),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 32),
                // DROITE: Actions rapides
                Expanded(
                  flex: 4,
                  child: SingleChildScrollView(
                    child: _buildQuickActionsTV(fp),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderTV(FamilyProvider fp) {
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
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Tableau de Bord',
                    style: TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)),
                Text(
                  '${fp.children.length} enfant${fp.children.length > 1 ? 's' : ''}  ${fp.currentParentName}',
                  style: const TextStyle(color: Colors.white54, fontSize: 18),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPodiumTV(List<ChildModel> sorted) {
    return GlassCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            ShaderMask(
              shaderCallback: (bounds) => const LinearGradient(
                colors: [Colors.amber, Colors.orange, Colors.amber],
              ).createShader(bounds),
              child: const Text('\u{1F3C6} CLASSEMENT',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
            ),
            const SizedBox(height: 24),
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
                        child: Opacity(opacity: _podium2Anim.value, child: _podiumCardTV(sorted[1], 2)),
                      );
                    },
                  ),
                  const SizedBox(width: 20),
                  AnimatedBuilder(
                    animation: _podium1Anim,
                    builder: (context, child) {
                      return Transform.translate(
                        offset: Offset(0, 60 * (1 - _podium1Anim.value)),
                        child: Opacity(opacity: _podium1Anim.value, child: child),
                      );
                    },
                    child: AnimatedBuilder(
                      animation: _pulseAnim,
                      builder: (context, child) => Transform.scale(scale: _pulseAnim.value, child: child),
                      child: _podiumCardTV(sorted[0], 1),
                    ),
                  ),
                  const SizedBox(width: 20),
                  if (sorted.length >= 3)
                    AnimatedBuilder(
                      animation: _podium3Anim,
                      builder: (context, child) {
                        return Transform.translate(
                          offset: Offset(0, 40 * (1 - _podium3Anim.value)),
                          child: Opacity(opacity: _podium3Anim.value, child: _podiumCardTV(sorted[2], 3)),
                        );
                      },
                    ),
                ],
              )
            else
              _podiumCardTV(sorted[0], 1),
            if (sorted.length > 3) ...[
              const SizedBox(height: 20),
              const Divider(color: Colors.white12),
              ...sorted.skip(3).toList().asMap().entries.map((entry) {
                final child = entry.value;
                final rank = entry.key + 4;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: TvFocusWrapper(
                    onTap: () => Navigator.push(context, ZoomPageRoute(page: ChildDashboardScreen(childId: child.id))),
                    child: Row(
                      children: [
                        Text('#$rank', style: const TextStyle(color: Colors.white38, fontWeight: FontWeight.bold, fontSize: 20)),
                        const SizedBox(width: 14),
                        _buildChildAvatar(child, 24),
                        const SizedBox(width: 14),
                        Expanded(child: Text(child.name, style: const TextStyle(color: Colors.white, fontSize: 20))),
                        Text('${child.points} pts', style: const TextStyle(color: Colors.white54, fontWeight: FontWeight.bold, fontSize: 18)),
                      ],
                    ),
                  ),
                );
              }),
            ],
          ],
        ),
      ),
    );
  }

  Widget _podiumCardTV(ChildModel child, int rank) {
    final heights = {1: 130.0, 2: 100.0, 3: 80.0};
    final colors = {1: Colors.amber, 2: Colors.grey, 3: Colors.orange};
    final medals = {1: '\u{1F947}', 2: '\u{1F948}', 3: '\u{1F949}'};
    final avatarRadius = rank == 1 ? 44.0 : 34.0;

    return TvFocusWrapper(
      autofocus: rank == 1,
      onTap: () => Navigator.push(context, ZoomPageRoute(page: ChildDashboardScreen(childId: child.id))),
      child: Column(
        children: [
          Text(medals[rank]!, style: const TextStyle(fontSize: 32)),
          const SizedBox(height: 8),
          _buildChildAvatar(child, avatarRadius),
          const SizedBox(height: 8),
          Text(child.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
          TweenAnimationBuilder<int>(
            tween: IntTween(begin: 0, end: child.points),
            duration: const Duration(milliseconds: 1500),
            builder: (context, val, _) {
              return Text('$val pts', style: TextStyle(color: colors[rank], fontWeight: FontWeight.bold, fontSize: 20));
            },
          ),
          Text(child.levelTitle, style: TextStyle(color: colors[rank]!.withOpacity(0.7), fontSize: 14)),
          const SizedBox(height: 6),
          Container(
            width: 90, height: heights[rank],
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter, end: Alignment.bottomCenter,
                colors: [colors[rank]!.withOpacity(0.8), colors[rank]!.withOpacity(0.3)],
              ),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
            ),
            child: Center(
              child: Text('#$rank', style: TextStyle(color: Colors.white.withOpacity(0.9), fontWeight: FontWeight.bold, fontSize: 28)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionsTV(FamilyProvider fp) {
    final items = [
      {'emoji': '\u{1F4DD}', 'label': 'Punition', 'color': Colors.redAccent, 'onTap': () {
        Navigator.push(context, SlidePageRoute(page: const PunishmentLinesScreen(), direction: SlideDirection.up));
      }},
      {'emoji': '\u{1F6E1}', 'label': 'Immunite', 'color': Colors.amber, 'onTap': () {
        Navigator.push(context, SpinPageRoute(page: const ImmunityLinesScreen()));
      }},
      {'emoji': '\u{1F4FA}', 'label': 'Fiche Enfant', 'color': Colors.lightBlue, 'onTap': () {
        _showChildPickerForNav(fp, (childId) {
          Navigator.push(context, ZoomPageRoute(page: ChildDashboardScreen(childId: childId)));
        });
      }},
      {'emoji': '\u{2696}', 'label': 'Tribunal', 'color': Colors.purpleAccent, 'onTap': () {
        Navigator.push(context, SlidePageRoute(page: const TribunalScreen()));
      }},
      {'emoji': '\u{1FA99}', 'label': 'Ventes', 'color': Colors.greenAccent, 'onTap': () {
        _showChildPickerForNav(fp, (childId) {
          Navigator.push(context, DoorPageRoute(page: TradeScreen(childId: childId)));
        });
      }},
      {'emoji': '\u{1F4DA}', 'label': 'Notes Scolaires', 'color': Colors.deepPurpleAccent, 'onTap': () {
        Navigator.push(context, SlidePageRoute(page: const MultiChildEvaluationScreen()));
      }},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('\u{26A1} Actions Rapides',
            style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        const Text('Choisissez une action', style: TextStyle(color: Colors.white38, fontSize: 16)),
        const SizedBox(height: 24),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 2.8,
          children: List.generate(items.length, (i) {
            final item = items[i];
            final anim = i < _actionAnims.length ? _actionAnims[i] : null;
            final tile = _emojiTileTV(
              item['emoji'] as String,
              item['label'] as String,
              item['color'] as Color,
              item['onTap'] as VoidCallback,
            );
            if (anim == null) return tile;
            return AnimatedBuilder(
              animation: anim,
              builder: (context, child) {
                return Transform.scale(
                  scale: anim.value.clamp(0.0, 1.0),
                  child: Opacity(opacity: anim.value.clamp(0.0, 1.0), child: child),
                );
              },
              child: tile,
            );
          }),
        ),
      ],
    );
  }

  Widget _emojiTileTV(String emoji, String label, Color color, VoidCallback onTap) {
    return TvFocusWrapper(
      onTap: onTap,
      focusBorderColor: color,
      borderRadius: 18,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          color: color.withOpacity(0.10),
          border: Border.all(color: color.withOpacity(0.25), width: 1.5),
        ),
        child: Row(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 28)),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  Widget _buildActiveTradesTV(FamilyProvider fp) {
    final active = fp.trades.where((t) => t.isActive).toList();
    if (active.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('\u{1FA99} Ventes en cours',
            style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        ...active.asMap().entries.map((entry) {
          final trade = entry.value;
          final sellerName = fp.getChild(trade.fromChildId)?.name ?? '?';
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
              padding: const EdgeInsets.only(bottom: 12),
              child: TvFocusWrapper(
                onTap: () => Navigator.push(context, DoorPageRoute(page: TradeScreen(childId: trade.fromChildId))),
                child: GlassCard(
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Row(
                      children: [
                        Container(
                          width: 14, height: 14,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle, color: Colors.greenAccent,
                            boxShadow: [BoxShadow(color: Colors.greenAccent.withOpacity(0.5), blurRadius: 8)],
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('$sellerName \u2192 $buyerName',
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                              Text('${trade.immunityLines} lignes \u2022 ${trade.serviceDescription}',
                                  style: const TextStyle(color: Colors.white54, fontSize: 14),
                                  maxLines: 1, overflow: TextOverflow.ellipsis),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.greenAccent.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(trade.statusLabel,
                              style: const TextStyle(color: Colors.greenAccent, fontSize: 14)),
                        ),
                        const SizedBox(width: 8),
                        const Icon(Icons.chevron_right, color: Colors.white38, size: 28),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        }),
      ],
    );
  }

  // ==================== MOBILE LAYOUT ====================
  Widget _buildMobileLayout(FamilyProvider fp, List<ChildModel> sorted) {
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
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Tableau de Bord',
                    style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                Text(
                  '${fp.children.length} enfant${fp.children.length > 1 ? 's' : ''}  ${fp.currentParentName}',
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
            child: const Text('\u{1F3C6} CLASSEMENT',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
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
                      child: Opacity(opacity: _podium2Anim.value, child: _podiumCard(sorted[1], 2)),
                    );
                  },
                ),
                const SizedBox(width: 12),
                AnimatedBuilder(
                  animation: _podium1Anim,
                  builder: (context, child) {
                    return Transform.translate(
                      offset: Offset(0, 60 * (1 - _podium1Anim.value)),
                      child: Opacity(opacity: _podium1Anim.value, child: child),
                    );
                  },
                  child: AnimatedBuilder(
                    animation: _pulseAnim,
                    builder: (context, child) => Transform.scale(scale: _pulseAnim.value, child: child),
                    child: _podiumCard(sorted[0], 1),
                  ),
                ),
                const SizedBox(width: 12),
                if (sorted.length >= 3)
                  AnimatedBuilder(
                    animation: _podium3Anim,
                    builder: (context, child) {
                      return Transform.translate(
                        offset: Offset(0, 40 * (1 - _podium3Anim.value)),
                        child: Opacity(opacity: _podium3Anim.value, child: _podiumCard(sorted[2], 3)),
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
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: TvFocusWrapper(
                  onTap: () => Navigator.push(context, ZoomPageRoute(page: ChildDashboardScreen(childId: child.id))),
                  child: Row(
                    children: [
                      Text('#$rank', style: const TextStyle(color: Colors.white38, fontWeight: FontWeight.bold, fontSize: 14)),
                      const SizedBox(width: 10),
                      _buildChildAvatar(child, 18),
                      const SizedBox(width: 10),
                      Expanded(child: Text(child.name, style: const TextStyle(color: Colors.white, fontSize: 14))),
                      Text('${child.points} pts', style: const TextStyle(color: Colors.white54, fontWeight: FontWeight.bold)),
                    ],
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
    final medals = {1: '\u{1F947}', 2: '\u{1F948}', 3: '\u{1F949}'};
    final avatarRadius = rank == 1 ? 36.0 : 26.0;

    return TvFocusWrapper(
      onTap: () => Navigator.push(context, ZoomPageRoute(page: ChildDashboardScreen(childId: child.id))),
      child: Column(
        children: [
          Text(medals[rank]!, style: const TextStyle(fontSize: 24)),
          const SizedBox(height: 6),
          _buildChildAvatar(child, avatarRadius),
          const SizedBox(height: 6),
          Text(child.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
          TweenAnimationBuilder<int>(
            tween: IntTween(begin: 0, end: child.points),
            duration: const Duration(milliseconds: 1500),
            builder: (context, val, _) {
              return Text('$val pts', style: TextStyle(color: colors[rank], fontWeight: FontWeight.bold, fontSize: 14));
            },
          ),
          Text(child.levelTitle, style: TextStyle(color: colors[rank]!.withOpacity(0.7), fontSize: 10)),
          const SizedBox(height: 4),
          Container(
            width: 70, height: heights[rank],
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter, end: Alignment.bottomCenter,
                colors: [colors[rank]!.withOpacity(0.8), colors[rank]!.withOpacity(0.3)],
              ),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
            ),
            child: Center(
              child: Text('#$rank', style: TextStyle(color: Colors.white.withOpacity(0.9), fontWeight: FontWeight.bold, fontSize: 20)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions(FamilyProvider fp) {
    final actions = [
      _Act('\u{1F4CB} Punition', Icons.menu_book, Colors.red, () {
        Navigator.push(context, SlidePageRoute(page: const PunishmentLinesScreen(), direction: SlideDirection.up));
      }),
      _Act('\u{1F6E1} Immunite', Icons.shield, Colors.amber, () {
        Navigator.push(context, SpinPageRoute(page: const ImmunityLinesScreen()));
      }),
      _Act('\u{1F4FA} Ecran', Icons.tv, Colors.blue, () {
        _showChildPickerForNav(fp, (childId) {
          Navigator.push(context, ZoomPageRoute(page: ChildDashboardScreen(childId: childId)));
        });
      }),
      _Act('\u{2696} Tribunal', Icons.gavel, Colors.purple, () {
        Navigator.push(context, SlidePageRoute(page: const TribunalScreen()));
      }),
      _Act('\u{1FA99} Ventes', Icons.storefront, Colors.green, () {
        _showChildPickerForNav(fp, (childId) {
          Navigator.push(context, DoorPageRoute(page: TradeScreen(childId: childId)));
        });
      }),
      _Act('\u{1F4DD} Notes', Icons.note_alt, Colors.deepPurple, () {
        Navigator.push(context, SlidePageRoute(page: const MultiChildEvaluationScreen()));
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
              child: Transform.translate(offset: Offset(-20 * (1 - value), 0), child: child),
            );
          },
          child: const Text('\u{26A1} Actions Rapides',
              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
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
            final anim = i < _actionAnims.length ? _actionAnims[i] : null;
            if (anim == null) return _actionTile(action);
            return AnimatedBuilder(
              animation: anim,
              builder: (context, child) {
                return Transform.scale(
                  scale: anim.value.clamp(0.0, 1.0),
                  child: Opacity(opacity: anim.value.clamp(0.0, 1.0), child: child),
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
                boxShadow: [BoxShadow(color: action.color.withOpacity(0.3), blurRadius: 12, spreadRadius: 2)],
              ),
              child: Icon(action.icon, color: action.color, size: 26),
            ),
            const SizedBox(height: 8),
            Text(action.label,
                style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                textAlign: TextAlign.center),
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
        const Text('\u{1FA99} Ventes en cours',
            style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        ...active.asMap().entries.map((entry) {
          final trade = entry.value;
          final sellerName = fp.getChild(trade.fromChildId)?.name ?? '?';
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
                onTap: () => Navigator.push(context, DoorPageRoute(page: TradeScreen(childId: trade.fromChildId))),
                child: GlassCard(
                  child: Row(
                    children: [
                      Container(
                        width: 10, height: 10,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle, color: Colors.greenAccent,
                          boxShadow: [BoxShadow(color: Colors.greenAccent.withOpacity(0.5), blurRadius: 6)],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('$sellerName \u2192 $buyerName',
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                            Text('${trade.immunityLines} lignes \u2022 ${trade.serviceDescription}',
                                style: const TextStyle(color: Colors.white54, fontSize: 12),
                                maxLines: 1, overflow: TextOverflow.ellipsis),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.greenAccent.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(trade.statusLabel,
                            style: const TextStyle(color: Colors.greenAccent, fontSize: 11)),
                      ),
                      const SizedBox(width: 4),
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

  void _showChildPickerForNav(FamilyProvider fp, Function(String) onSelected) {
    if (fp.children.isEmpty) return;
    if (fp.children.length == 1) {
      onSelected(fp.children.first.id);
      return;
    }
    final isTV = TvDetector.isTV;

    if (isTV) {
      showDialog(
        context: context,
        builder: (ctx) => TvFocusScope(
          child: Dialog(
            backgroundColor: const Color(0xFF0D1B2A),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            insetPadding: const EdgeInsets.symmetric(horizontal: 150, vertical: 60),
            child: Padding(
              padding: const EdgeInsets.all(40),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Choisir un enfant',
                      style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 24),
                  Flexible(
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: fp.children.length,
                      itemBuilder: (_, i) {
                        final child = fp.children[i];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: TvFocusWrapper(
                            autofocus: i == 0,
                            onTap: () {
                              Navigator.pop(ctx);
                              onSelected(child.id);
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(16),
                                color: Colors.cyan.withOpacity(0.08),
                                border: Border.all(color: Colors.cyan.withOpacity(0.3)),
                              ),
                              child: Row(children: [
                                _buildChildAvatar(child, 28),
                                const SizedBox(width: 20),
                                Expanded(
                                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                    Text(child.name,
                                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 22)),
                                    const SizedBox(height: 4),
                                    Text('${child.points} pts - Nv.${child.currentLevelNumber}',
                                        style: TextStyle(color: Colors.grey[400], fontSize: 16)),
                                  ]),
                                ),
                                const Icon(Icons.chevron_right, color: Colors.white38, size: 32),
                              ]),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    } else {
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
}

class _ChildPickerSheet extends StatefulWidget {
  final List<ChildModel> children;
  final Function(String) onSelected;
  final Widget Function(ChildModel, double) buildAvatar;
  const _ChildPickerSheet({required this.children, required this.onSelected, required this.buildAvatar});
  @override
  State<_ChildPickerSheet> createState() => _ChildPickerSheetState();
}

class _ChildPickerSheetState extends State<_ChildPickerSheet> with SingleTickerProviderStateMixin {
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
  void dispose() { _animCtrl.dispose(); super.dispose(); }

  List<ChildModel> get _filtered => widget.children
      .where((c) => c.name.toLowerCase().contains(_search.toLowerCase())).toList();

  Color _accentFor(ChildModel c) {
    const palette = [Color(0xFF6C63FF), Color(0xFF00BCD4), Color(0xFF4CAF50), Color(0xFFFF9800), Color(0xFFE91E63), Color(0xFF009688)];
    return palette[c.name.codeUnitAt(0) % palette.length];
  }

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
        decoration: const BoxDecoration(
          color: Color(0xFF12122A),
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [Color(0xFF6C63FF), Color(0xFF00BCD4)]),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.people_alt_rounded, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 12),
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Choisir un enfant',
                      style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                  Text('${widget.children.length} enfants disponibles',
                      style: const TextStyle(color: Colors.white38, fontSize: 12)),
                ]),
              ]),
            ),
            const SizedBox(height: 20),
            if (widget.children.length > 4) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white10, borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: TvTextField(
                    onChanged: (v) => setState(() => _search = v),
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    decoration: const InputDecoration(
                      hintText: 'Rechercher...', hintStyle: TextStyle(color: Colors.white38),
                      prefixIcon: Icon(Icons.search, color: Colors.white38, size: 20),
                      border: InputBorder.none, contentPadding: EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
            Flexible(
              child: filtered.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.all(32),
                      child: Column(children: [
                        Text('\u{1F4CB}', style: TextStyle(fontSize: 36)),
                        SizedBox(height: 8),
                        Text('Aucun resultat', style: TextStyle(color: Colors.white54, fontSize: 14)),
                      ]),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      shrinkWrap: true,
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (_, i) {
                        final child = filtered[i];
                        final accent = _accentFor(child);
                        return _ChildTile(child: child, accent: accent, buildAvatar: widget.buildAvatar, onTap: () => widget.onSelected(child.id));
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
  const _ChildTile({required this.child, required this.accent, required this.buildAvatar, required this.onTap});
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
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: _pressed ? widget.accent.withOpacity(0.18) : Colors.white.withOpacity(0.06),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: _pressed ? widget.accent.withOpacity(0.6) : Colors.white.withOpacity(0.08), width: 1.5,
            ),
          ),
          child: Row(children: [
            widget.buildAvatar(c, 26),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(c.name, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Row(children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(color: widget.accent.withOpacity(0.18), borderRadius: BorderRadius.circular(8)),
                    child: Text(c.levelTitle, style: TextStyle(color: widget.accent, fontSize: 10, fontWeight: FontWeight.w600)),
                  ),
                  const SizedBox(width: 6),
                  Text('${c.points} pts', style: const TextStyle(color: Colors.white54, fontSize: 11)),
                ]),
              ]),
            ),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Icon(Icons.arrow_forward_ios_rounded, color: widget.accent, size: 14),
              const SizedBox(height: 6),
              Container(
                width: 48, height: 4,
                decoration: BoxDecoration(color: Colors.white12, borderRadius: BorderRadius.circular(2)),
                child: FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: c.levelProgress.clamp(0.0, 1.0),
                  child: Container(decoration: BoxDecoration(color: widget.accent, borderRadius: BorderRadius.circular(2))),
                ),
              ),
              const SizedBox(height: 2),
              Text('${(c.levelProgress * 100).toInt()}%', style: const TextStyle(color: Colors.white38, fontSize: 9)),
            ]),
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