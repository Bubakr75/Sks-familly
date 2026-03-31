import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:convert';
import 'dart:math' as math;

import '../providers/family_provider.dart';
import '../providers/pin_provider.dart';
import '../providers/theme_provider.dart';
import '../utils/pin_guard.dart';
import '../widgets/glass_card.dart';
import '../widgets/tv_focus_wrapper.dart';
import '../widgets/animated_background.dart';
import '../widgets/page_transitions.dart';

import '../screens/child_dashboard_screen.dart';
import '../screens/punishment_lines_screen.dart';
import '../screens/immunity_lines_screen.dart';
import '../screens/screen_time_screen.dart';
import '../screens/tribunal_screen.dart';
import '../screens/trade_screen.dart';

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

  @override
  void initState() {
    super.initState();
    _podiumController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..forward();
    _actionsController = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _pulseController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500))..repeat(reverse: true);
    _floatingController = AnimationController(vsync: this, duration: const Duration(milliseconds: 3000))..repeat(reverse: true);
    Future.delayed(const Duration(milliseconds: 400), () { if (mounted) _actionsController.forward(); });
  }

  @override
  void dispose() {
    _podiumController.dispose();
    _actionsController.dispose();
    _pulseController.dispose();
    _floatingController.dispose();
    super.dispose();
  }

  Widget _buildAvatar(dynamic child, {double size = 120, int rank = 0}) {
    final photoBase64 = child.photoBase64 as String?;
    final hasPhoto = photoBase64 != null && photoBase64.isNotEmpty;
    final color = _getRankColor(rank);

    return Container(
      width: size + 8, height: size + 8,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: SweepGradient(colors: [color, color.withOpacity(0.3), color]),
        boxShadow: [BoxShadow(color: color.withOpacity(0.4), blurRadius: 12, spreadRadius: 2)],
      ),
      padding: const EdgeInsets.all(3),
      child: Container(
        decoration: BoxDecoration(shape: BoxShape.circle, color: Theme.of(context).scaffoldBackgroundColor),
        padding: const EdgeInsets.all(2),
        child: hasPhoto
            ? ClipOval(child: Image.memory(base64Decode(photoBase64), width: size, height: size, fit: BoxFit.cover))
            : Container(
                width: size, height: size,
                decoration: BoxDecoration(shape: BoxShape.circle,
                    gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight,
                        colors: [color.withOpacity(0.3), color.withOpacity(0.1)])),
                child: Center(child: Text(
                    child.name.isNotEmpty ? child.name[0].toUpperCase() : '?',
                    style: TextStyle(fontSize: size * 0.4, fontWeight: FontWeight.bold, color: color))),
              ),
      ),
    );
  }

  Color _getRankColor(int rank) {
    switch (rank) {
      case 0: return Colors.amber;
      case 1: return Colors.grey.shade300;
      case 2: return Colors.brown.shade300;
      default: return Colors.blueAccent;
    }
  }

  Widget _buildPodium(List<dynamic> children) {
    final sorted = List<dynamic>.from(children)..sort((a, b) => (b.points as int).compareTo(a.points as int));

    if (sorted.isEmpty) {
      return GlassCard(
        child: const Padding(padding: EdgeInsets.all(32),
            child: Column(children: [
              Text('👨‍👩‍👧‍👦', style: TextStyle(fontSize: 48)),
              SizedBox(height: 12),
              Text('Ajoute des enfants pour commencer !', style: TextStyle(color: Colors.white54)),
            ])),
      );
    }
    if (sorted.length == 1) return _buildSingleChild(sorted[0]);
    return Column(children: [
      if (sorted.length >= 3) _buildTopThreePodium(sorted)
      else if (sorted.length == 2) _buildTwoChildrenPodium(sorted),
      if (sorted.length > 3) ...[
        const SizedBox(height: 12),
        ...sorted.skip(3).toList().asMap().entries.map((entry) =>
            Padding(padding: const EdgeInsets.only(bottom: 6), child: _buildRankRow(entry.value, entry.key + 3))),
      ],
    ]);
  }

  Widget _buildSingleChild(dynamic child) {
    return ScaleTransition(
      scale: CurvedAnimation(parent: _podiumController, curve: Curves.elasticOut),
      child: TvFocusWrapper(
        onTap: () => _navigateToChild(child.id),
        child: GlassCard(
          glowColor: Colors.amber,
          onTap: () => _navigateToChild(child.id),
          child: Padding(padding: const EdgeInsets.all(20),
            child: Column(children: [
              _buildAvatar(child, size: 120, rank: 0),
              const SizedBox(height: 12),
              const Text('🥇', style: TextStyle(fontSize: 28)),
              const SizedBox(height: 6),
              Text(child.name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              Text('${child.points} points', style: const TextStyle(color: Colors.amber, fontSize: 16)),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _buildTwoChildrenPodium(List<dynamic> sorted) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(child: ScaleTransition(
          scale: CurvedAnimation(parent: _podiumController, curve: const Interval(0.1, 0.7, curve: Curves.elasticOut)),
          child: TvFocusWrapper(onTap: () => _navigateToChild(sorted[0].id),
            child: GlassCard(glowColor: Colors.amber, onTap: () => _navigateToChild(sorted[0].id),
              child: Padding(padding: const EdgeInsets.all(12), child: Column(children: [
                const Text('🥇', style: TextStyle(fontSize: 24)),
                const SizedBox(height: 8),
                _buildAvatar(sorted[0], size: 100, rank: 0),
                const SizedBox(height: 8),
                Text(sorted[0].name, style: const TextStyle(fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
                Text('${sorted[0].points} pts', style: const TextStyle(color: Colors.amber, fontSize: 14)),
              ])),
            ),
          ),
        )),
        const SizedBox(width: 8),
        Expanded(child: ScaleTransition(
          scale: CurvedAnimation(parent: _podiumController, curve: const Interval(0.3, 0.9, curve: Curves.elasticOut)),
          child: TvFocusWrapper(onTap: () => _navigateToChild(sorted[1].id),
            child: GlassCard(onTap: () => _navigateToChild(sorted[1].id),
              child: Padding(padding: const EdgeInsets.all(12), child: Column(children: [
                const Text('🥈', style: TextStyle(fontSize: 20)),
                const SizedBox(height: 8),
                _buildAvatar(sorted[1], size: 90, rank: 1),
                const SizedBox(height: 8),
                Text(sorted[1].name, style: const TextStyle(fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
                Text('${sorted[1].points} pts', style: TextStyle(color: Colors.grey.shade300, fontSize: 14)),
              ])),
            ),
          ),
        )),
      ],
    );
  }

  Widget _buildTopThreePodium(List<dynamic> sorted) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(child: ScaleTransition(
          scale: CurvedAnimation(parent: _podiumController, curve: const Interval(0.2, 0.8, curve: Curves.elasticOut)),
          child: TvFocusWrapper(onTap: () => _navigateToChild(sorted[1].id),
            child: GlassCard(onTap: () => _navigateToChild(sorted[1].id),
              child: Padding(padding: const EdgeInsets.all(10), child: Column(children: [
                const Text('🥈', style: TextStyle(fontSize: 18)),
                const SizedBox(height: 6),
                _buildAvatar(sorted[1], size: 80, rank: 1),
                const SizedBox(height: 6),
                Text(sorted[1].name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
                Text('${sorted[1].points} pts', style: TextStyle(color: Colors.grey.shade300, fontSize: 12)),
              ])),
            ),
          ),
        )),
        const SizedBox(width: 6),
        Expanded(flex: 2, child: ScaleTransition(
          scale: CurvedAnimation(parent: _podiumController, curve: const Interval(0.0, 0.7, curve: Curves.elasticOut)),
          child: TvFocusWrapper(onTap: () => _navigateToChild(sorted[0].id),
            child: GlassCard(glowColor: Colors.amber, onTap: () => _navigateToChild(sorted[0].id),
              child: Padding(padding: const EdgeInsets.fromLTRB(8, 16, 8, 12), child: Column(children: [
                const Text('🥇', style: TextStyle(fontSize: 28)),
                const SizedBox(height: 8),
                _buildAvatar(sorted[0], size: 110, rank: 0),
                const SizedBox(height: 8),
                Text(sorted[0].name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16), maxLines: 1, overflow: TextOverflow.ellipsis),
                Text('${sorted[0].points} pts', style: const TextStyle(color: Colors.amber, fontSize: 16, fontWeight: FontWeight.bold)),
              ])),
            ),
          ),
        )),
        const SizedBox(width: 6),
        Expanded(child: ScaleTransition(
          scale: CurvedAnimation(parent: _podiumController, curve: const Interval(0.4, 1.0, curve: Curves.elasticOut)),
          child: TvFocusWrapper(onTap: () => _navigateToChild(sorted[2].id),
            child: GlassCard(onTap: () => _navigateToChild(sorted[2].id),
              child: Padding(padding: const EdgeInsets.all(10), child: Column(children: [
                const Text('🥉', style: TextStyle(fontSize: 18)),
                const SizedBox(height: 6),
                _buildAvatar(sorted[2], size: 70, rank: 2),
                const SizedBox(height: 6),
                Text(sorted[2].name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
                Text('${sorted[2].points} pts', style: TextStyle(color: Colors.brown.shade300, fontSize: 12)),
              ])),
            ),
          ),
        )),
      ],
    );
  }

  Widget _buildRankRow(dynamic child, int rank) {
    return TvFocusWrapper(
      onTap: () => _navigateToChild(child.id),
      child: GlassCard(
        onTap: () => _navigateToChild(child.id),
        child: ListTile(
          leading: Row(mainAxisSize: MainAxisSize.min, children: [
            SizedBox(width: 28, child: Text('${rank + 1}.', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white54))),
            _buildAvatar(child, size: 40, rank: rank),
          ]),
          title: Text(child.name, style: const TextStyle(fontWeight: FontWeight.bold)),
          subtitle: Text('${child.points} pts', style: const TextStyle(fontSize: 11, color: Colors.white54)),
          trailing: Text('${child.points} pts', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        ),
      ),
    );
  }

  void _navigateToChild(String childId) {
    Navigator.push(context, SlidePageRoute(page: ChildDashboardScreen(childId: childId)));
  }

  Widget _buildQuickActions() {
    final pinProvider = context.read<PinProvider>();
    final isParent = pinProvider.canPerformParentAction();
    final provider = context.read<FamilyProvider>();

    final actions = [
      _QuickAction(emoji: '✍️', label: 'Punition', color: Colors.orange,
          onTap: () => Navigator.push(context, SlidePageRoute(page: const PunishmentLinesScreen()))),
      _QuickAction(emoji: '🛡️', label: 'Immunité', color: Colors.cyan,
          onTap: () => Navigator.push(context, SlidePageRoute(page: const ImmunityLinesScreen()))),
      _QuickAction(emoji: '📺', label: 'Écran', color: Colors.purple, parentOnly: true,
          onTap: () => PinGuard.guardAction(context, () => Navigator.push(context, SlidePageRoute(page: const ScreenTimeScreen())))),
      _QuickAction(emoji: '⚖️', label: 'Tribunal', color: Colors.deepOrange,
          onTap: () => Navigator.push(context, SlidePageRoute(page: const TribunalScreen()))),
      _QuickAction(emoji: '🤝', label: 'Vente', color: Colors.teal,
          onTap: () {
            final children = provider.sortedChildren;
            if (children.isEmpty) return;
            if (children.length == 1) {
              Navigator.push(context, SlidePageRoute(page: TradeScreen(childId: children.first.id)));
            } else {
              _showChildPickerForTrade(context);
            }
          }),
      _QuickAction(emoji: '👤', label: 'Profil', color: Colors.indigo,
          onTap: () {
            final children = provider.sortedChildren;
            if (children.isEmpty) return;
            if (children.length == 1) {
              _navigateToChild(children.first.id);
            } else {
              _showChildPicker(context);
            }
          }),
    ];

    return FadeTransition(
      opacity: CurvedAnimation(parent: _actionsController, curve: Curves.easeIn),
      child: SlideTransition(
        position: Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero)
            .animate(CurvedAnimation(parent: _actionsController, curve: Curves.easeOut)),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: GridView.count(
            crossAxisCount: 3, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 8, mainAxisSpacing: 8, childAspectRatio: 1.1,
            children: actions.map((action) => TvFocusWrapper(
              onTap: action.onTap,
              child: GlassCard(
                onTap: action.onTap, glowColor: action.color,
                child: Stack(children: [
                  Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Text(action.emoji, style: const TextStyle(fontSize: 28)),
                    const SizedBox(height: 6),
                    Text(action.label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                  ])),
                  if (action.parentOnly && !isParent)
                    Positioned(top: 6, right: 6,
                        child: Container(width: 18, height: 18,
                            decoration: BoxDecoration(color: Colors.orange.withOpacity(0.8), shape: BoxShape.circle),
                            child: const Center(child: Icon(Icons.lock, size: 10, color: Colors.white)))),
                ]),
              ),
            )).toList(),
          ),
        ),
      ),
    );
  }

  void _showChildPickerForTrade(BuildContext context) {
    final children = context.read<FamilyProvider>().sortedChildren;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(color: Theme.of(context).scaffoldBackgroundColor.withOpacity(0.95),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
        padding: const EdgeInsets.all(20),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 16),
          const Text('Choisir un enfant pour la vente', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          ...children.map((child) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: TvFocusWrapper(
              onTap: () { Navigator.pop(ctx); Navigator.push(context, SlidePageRoute(page: TradeScreen(childId: child.id))); },
              child: GlassCard(
                onTap: () { Navigator.pop(ctx); Navigator.push(context, SlidePageRoute(page: TradeScreen(childId: child.id))); },
                child: ListTile(
                  leading: _buildAvatar(child, size: 40, rank: 0),
                  title: Text(child.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('${child.points} pts', style: const TextStyle(fontSize: 12, color: Colors.white54)),
                ),
              ),
            ),
          )),
          const SizedBox(height: 8),
        ]),
      ),
    );
  }

  void _showChildPicker(BuildContext context) {
    final children = context.read<FamilyProvider>().sortedChildren;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(color: Theme.of(context).scaffoldBackgroundColor.withOpacity(0.95),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
        padding: const EdgeInsets.all(20),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 16),
          const Text('Choisir un enfant', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          ...children.map((child) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: TvFocusWrapper(
              onTap: () { Navigator.pop(ctx); _navigateToChild(child.id); },
              child: GlassCard(
                onTap: () { Navigator.pop(ctx); _navigateToChild(child.id); },
                child: ListTile(
                  leading: _buildAvatar(child, size: 40, rank: 0),
                  title: Text(child.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('${child.points} pts', style: const TextStyle(fontSize: 12, color: Colors.white54)),
                ),
              ),
            ),
          )),
          const SizedBox(height: 8),
        ]),
      ),
    );
  }

  Widget _buildActiveTrades(FamilyProvider provider) {
    final trades = provider.getActiveTrades();
    if (trades.isEmpty) return const SizedBox.shrink();

    return FadeTransition(
      opacity: CurvedAnimation(parent: _actionsController, curve: const Interval(0.5, 1.0)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const SizedBox(height: 16),
          const Text('🤝 Échanges en cours', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 8),
          ...trades.take(3).map((trade) {
            final seller = provider.getChild(trade.fromChildId);
            final buyer = provider.getChild(trade.toChildId);
            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: TvFocusWrapper(
                onTap: () {
                  final childId = seller?.id ?? buyer?.id;
                  if (childId != null) Navigator.push(context, SlidePageRoute(page: TradeScreen(childId: childId)));
                },
                child: GlassCard(
                  onTap: () {
                    final childId = seller?.id ?? buyer?.id;
                    if (childId != null) Navigator.push(context, SlidePageRoute(page: TradeScreen(childId: childId)));
                  },
                  child: ListTile(
                    leading: const Text('🤝', style: TextStyle(fontSize: 24)),
                    title: Text('${seller?.name ?? '?'} → ${buyer?.name ?? '?'}',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    subtitle: Text('${trade.immunityLines} lignes — ${trade.statusLabel}',
                        style: const TextStyle(fontSize: 12, color: Colors.white54)),
                    trailing: Text(trade.statusEmoji, style: const TextStyle(fontSize: 20)),
                  ),
                ),
              ),
            );
          }),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<FamilyProvider>(
      builder: (context, provider, _) {
        final children = provider.sortedChildren;
        final pinProvider = context.watch<PinProvider>();
        final isParent = pinProvider.canPerformParentAction();

        return SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 100),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Row(children: [
                AnimatedBuilder(
                  animation: _floatingController,
                  builder: (_, __) => Transform.translate(
                    offset: Offset(0, -4 + _floatingController.value * 8),
                    child: const Text('🏠', style: TextStyle(fontSize: 32)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Family Points', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                  Row(children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: isParent ? Colors.green.withOpacity(0.2) : Colors.orange.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(isParent ? '👑 Mode Parent' : '👶 Mode Enfant',
                          style: TextStyle(fontSize: 11, color: isParent ? Colors.greenAccent : Colors.orangeAccent, fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(width: 8),
                    Text('${children.length} enfant${children.length > 1 ? 's' : ''}', style: const TextStyle(color: Colors.white38, fontSize: 11)),
                  ]),
                ])),
                Builder(builder: (ctx) => TvFocusWrapper(
                  onTap: () => Scaffold.of(ctx).openDrawer(),
                  child: GlassCard(
                    onTap: () => Scaffold.of(ctx).openDrawer(),
                    padding: const EdgeInsets.all(10),
                    child: const Icon(Icons.menu, size: 22),
                  ),
                )),
              ]),
            ),
            const SizedBox(height: 20),
            Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: _buildPodium(children)),
            const SizedBox(height: 20),
            _buildQuickActions(),
            _buildActiveTrades(provider),
            const SizedBox(height: 16),
          ]),
        );
      },
    );
  }
}

class _QuickAction {
  final String emoji;
  final String label;
  final Color color;
  final VoidCallback onTap;
  final bool parentOnly;
  _QuickAction({required this.emoji, required this.label, required this.color, required this.onTap, this.parentOnly = false});
}
