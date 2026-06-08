// lib/screens/dashboard_screen.dart

import 'dart:convert';
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
import 'tribunal_screen.dart';
import 'school_notes_screen.dart';
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
            Colors.purple.withOpacity(0.3)
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
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold)),
                Text(
                  '${fp.children.length} enfant${fp.children.length > 1 ? 's' : ''}  ${fp.currentParentName}',
                  style:
                      const TextStyle(color: Colors.white54, fontSize: 13),
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
            child: const Text(' CLASSEMENT',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white)),
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
                    builder: (context, child) => Transform.scale(
                      scale: _pulseAnim.value,
                      child: child,
                    ),
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
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: TvFocusWrapper(
                  onTap: () => Navigator.push(
                      context,
                      ZoomPageRoute(
                          page: ChildDashboardScreen(childId: child.id))),
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
              );
            }),
          ],
        ],
      ),
    );
  }

  Widget _podiumCard(ChildModel child, int rank) {
    final heights = {1: 110.0, 2: 85.0, 3: 65.0};
    final colors = {
      1: Colors.amber,
      2: Colors.grey,
      3: Colors.orange
    };
    final medals = {1: '🥇', 2: '🥈', 3: '🥉'};
    final avatarRadius = rank == 1 ? 36.0 : 26.0;

    return TvFocusWrapper(
      onTap: () {
        Navigator.push(context,
            ZoomPageRoute(page: ChildDashboardScreen(childId: child.id)));
      },
      child: Column(
        children: [
          Text(medals[rank]!, style: const TextStyle(fontSize: 24)),
          const SizedBox(height: 6),
          _buildChildAvatar(child, avatarRadius),
          const SizedBox(height: 6),
          Text(child.name,
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 13)),
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
                  color: colors[rank]!.withOpacity(0.7), fontSize: 10)),
          const SizedBox(height: 4),
          Container(
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
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(8)),
            ),
            child: Center(
              child: Text('#$rank',
                  style: TextStyle(
                      color: Colors.white.withOpacity(0.9),
                      fontWeight: FontWeight.bold,
                      fontSize: 20)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions(FamilyProvider fp) {
    final actions = [
      _Act('📋 Punition', Icons.menu_book, Colors.red, () {
        Navigator.push(
            context,
            SlidePageRoute(
                page: const PunishmentLinesScreen(),
                direction: SlideDirection.up));
      }),
      _Act('🛡️ Immunite', Icons.shield, Colors.amber, () {
        Navigator.push(
            context, SpinPageRoute(page: const ImmunityLinesScreen()));
      }),
      _Act('📺 Ecran', Icons.tv, Colors.blue, () {
        _showChildPickerForNav(fp, (childId) {
          Navigator.push(context,
              ZoomPageRoute(page: ChildDashboardScreen(childId: childId)));
        });
      }),
      _Act('⚖️ Tribunal', Icons.gavel, Colors.purple, () {
        Navigator.push(
            context, SlidePageRoute(page: const TribunalScreen()));
      }),
      _Act('🪙 Ventes', Icons.storefront, Colors.green, () {
        _showChildPickerForNav(fp, (childId) {
          Navigator.push(context,
              DoorPageRoute(page: TradeScreen(childId: childId)));
        });
      }),
      _Act('📝 Notes', Icons.note_alt, Colors.deepPurple, () {
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
          childAspectRatio: 1.1,
          children: List.generate(actions.length, (i) {
            final action = actions[i];
            final anim =
                i < _actionAnims.length ? _actionAnims[i] : null;
            if (anim == null) return _actionTile(action);
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
                      spreadRadius: 2),
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
    final active = fp.trades.where((t) => t.isActive).toList();
    if (active.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('🪙 Ventes en cours',
            style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold)),
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
                onTap: () {
                  Navigator.push(
                      context,
                      DoorPageRoute(
                          page: TradeScreen(
                              childId: trade.fromChildId)));
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
                            Text('$sellerName â†’ $buyerName',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold)),
                            Text(
                                '${trade.immunityLines} lignes â€¢ ${trade.serviceDescription}',
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
                          color: Colors.greenAccent.withOpacity(0.15),
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

  // â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
  //  SELECTEUR ENFANT â€” nouvelle interface moderne
  // â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
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
      isScrollControlled: true,          // â† permet d'occuper jusqu'Ã  90% de l'ecran
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

// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
//  WIDGET SELECTEUR â€” sheet scrollable + recherche
// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
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
  late Animation<double>   _slideAnim;
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
      .where((c) =>
          c.name.toLowerCase().contains(_search.toLowerCase()))
      .toList();

  // Couleur par initiale
  Color _accentFor(ChildModel c) {
    const palette = [
      Color(0xFF6C63FF), Color(0xFF00BCD4), Color(0xFF4CAF50),
      Color(0xFFFF9800), Color(0xFFE91E63), Color(0xFF009688),
    ];
    return palette[c.name.codeUnitAt(0) % palette.length];
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
    // Hauteur max = 85 % de l'ecran
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

            // â”€â”€ Pill â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
            const SizedBox(height: 12),
            Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),

            // â”€â”€ Titre + sous-titre â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF6C63FF), Color(0xFF00BCD4)],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.people_alt_rounded,
                      color: Colors.white, size: 20),
                ),
                const SizedBox(width: 12),
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Choisir un enfant',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold)),
                  Text('${widget.children.length} enfants disponibles',
                      style: const TextStyle(
                          color: Colors.white38, fontSize: 12)),
                ]),
              ]),
            ),
            const SizedBox(height: 20),

            // â”€â”€ Barre de recherche (si > 4 enfants) â”€â”€â”€â”€â”€â”€â”€
            if (widget.children.length > 4) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white10,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: TextField(
                    onChanged: (v) => setState(() => _search = v),
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    decoration: const InputDecoration(
                      hintText:      'Rechercherâ€¦',
                      hintStyle:     TextStyle(color: Colors.white38),
                      prefixIcon:    Icon(Icons.search, color: Colors.white38, size: 20),
                      border:        InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // â”€â”€ Liste scrollable â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
            Flexible(
              child: filtered.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.all(32),
                      child: Column(children: [
                        Text('📋', style: TextStyle(fontSize: 36)),
                        SizedBox(height: 8),
                        Text('Aucun resultat',
                            style: TextStyle(
                                color: Colors.white54, fontSize: 14)),
                      ]),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 4),
                      shrinkWrap: true,
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) =>
                          const SizedBox(height: 8),
                      itemBuilder: (_, i) {
                        final child  = filtered[i];
                        final accent = _accentFor(child);
                        return _ChildTile(
                          child:       child,
                          accent:      accent,
                          buildAvatar: widget.buildAvatar,
                          onTap:       () => widget.onSelected(child.id),
                        );
                      },
                    ),
            ),

            // â”€â”€ Padding bas (safe area) â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
            SizedBox(height: MediaQuery.of(context).padding.bottom + 16),
          ],
        ),
      ),
    );
  }
}

// â”€â”€ Tuile enfant â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
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
      onTapDown:   (_) => setState(() => _pressed = true),
      onTapUp:     (_) => setState(() => _pressed = false),
      onTapCancel: ()  => setState(() => _pressed = false),
      onTap:       widget.onTap,
      child: AnimatedScale(
        scale:    _pressed ? 0.96 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: _pressed
                ? widget.accent.withOpacity(0.18)
                : Colors.white.withOpacity(0.06),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: _pressed
                  ? widget.accent.withOpacity(0.6)
                  : Colors.white.withOpacity(0.08),
              width: 1.5,
            ),
          ),
          child: Row(children: [

            // Avatar
            widget.buildAvatar(c, 26),
            const SizedBox(width: 14),

            // Infos
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(c.name,
                      style: const TextStyle(
                          color:      Colors.white,
                          fontSize:   15,
                          fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Row(children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color:        widget.accent.withOpacity(0.18),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(c.levelTitle,
                          style: TextStyle(
                              color:    widget.accent,
                              fontSize: 10,
                              fontWeight: FontWeight.w600)),
                    ),
                    const SizedBox(width: 6),
                    Text('${c.points} pts',
                        style: const TextStyle(
                            color: Colors.white54, fontSize: 11)),
                  ]),
                ],
              ),
            ),

            // Barre de progression verticale + fleche
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Icon(Icons.arrow_forward_ios_rounded,
                    color: widget.accent, size: 14),
                const SizedBox(height: 6),
                // Mini progress bar
                Container(
                  width: 48, height: 4,
                  decoration: BoxDecoration(
                    color:        Colors.white12,
                    borderRadius: BorderRadius.circular(2),
                  ),
                  child: FractionallySizedBox(
                    alignment:   Alignment.centerLeft,
                    widthFactor: c.levelProgress.clamp(0.0, 1.0),
                    child: Container(
                      decoration: BoxDecoration(
                        color:        widget.accent,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${(c.levelProgress * 100).toInt()}%',
                  style: const TextStyle(
                      color: Colors.white38, fontSize: 9),
                ),
              ],
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



