import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/family_provider.dart';
import '../providers/pin_provider.dart';
import '../models/child_model.dart';
import '../models/trade_model.dart';
import '../widgets/animated_background.dart';
import '../widgets/glass_card.dart';
import '../widgets/tv_focus_wrapper.dart';
import '../screens/punishment_lines_screen.dart';
import '../screens/immunity_lines_screen.dart';
import '../screens/trade_screen.dart';
import '../screens/child_dashboard_screen.dart';
import '../screens/badges_screen.dart';
import '../utils/pin_guard.dart';

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
  late AnimationController _counterController;

  // Podium animations
  late Animation<double> _podium1Anim;
  late Animation<double> _podium2Anim;
  late Animation<double> _podium3Anim;

  // Quick actions stagger
  final List<Animation<double>> _actionAnims = [];

  // Pulse for #1
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();

    // Podium rise with bounce
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

    // Quick actions stagger
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

    // Pulse for rank 1
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Counter
    _counterController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    // Start
    _podiumController.forward();
    Future.delayed(const Duration(milliseconds: 600), () {
      if (mounted) _actionsController.forward();
    });
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) _counterController.forward();
    });
  }

  @override
  void dispose() {
    _podiumController.dispose();
    _actionsController.dispose();
    _pulseController.dispose();
    _counterController.dispose();
    super.dispose();
  }

  String _formatMinutes(int m) {
    if (m < 60) return '${m}min';
    final h = m ~/ 60;
    final r = m % 60;
    return r == 0 ? '${h}h' : '${h}h${r.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<FamilyProvider>(
      builder: (context, fp, _) {
        final children = fp.children;
        final sorted = List<ChildModel>.from(children)
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
                    // Header with animated title
                    _buildAnimatedHeader(fp),
                    const SizedBox(height: 20),

                    // Podium
                    if (sorted.isNotEmpty) _buildPodium(sorted),
                    const SizedBox(height: 20),

                    // Quick actions
                    _buildQuickActionsGrid(fp),
                    const SizedBox(height: 20),

                    // Active trades
                    _buildActiveTrades(fp),
                    const SizedBox(height: 20),

                    // History link
                    TvFocusWrapper(
                      onTap: () => _showFullHistory(fp),
                      child: GlassCard(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.history, color: Colors.cyan[200]),
                            const SizedBox(width: 8),
                            Text('Voir l\'historique complet',
                                style: TextStyle(
                                    color: Colors.cyan[200],
                                    fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildAnimatedHeader(FamilyProvider fp) {
    return AnimatedBuilder(
      animation: _counterController,
      builder: (context, child) {
        return Row(
          children: [
            // App icon with rotation
            TweenAnimationBuilder<double>(
              tween: Tween(begin: -0.5, end: 0.0),
              duration: const Duration(milliseconds: 800),
              curve: Curves.elasticOut,
              builder: (context, value, child) {
                return Transform.rotate(
                  angle: value,
                  child: const Text('👨‍👩‍👧‍👦', style: TextStyle(fontSize: 28)),
                );
              },
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Tableau de Bord',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    '${fp.children.length} enfant${fp.children.length > 1 ? 's' : ''} • ${fp.activeParent ?? 'Parent'}',
                    style: TextStyle(color: Colors.white54, fontSize: 13),
                  ),
                ],
              ),
            ),
            // Sync button with spin
            TvFocusWrapper(
              onTap: () => fp.syncData(),
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.0, end: 1.0),
                duration: const Duration(milliseconds: 1000),
                builder: (context, value, child) {
                  return Transform.rotate(
                    angle: value * 2 * 3.14159,
                    child: Icon(Icons.sync, color: Colors.cyan[300], size: 28),
                  );
                },
              ),
            ),
          ],
        );
      },
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
            child: const Text(
              '🏆 CLASSEMENT',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Top 3 podium
          if (sorted.length >= 2)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // 2nd place
                if (sorted.length >= 2)
                  AnimatedBuilder(
                    animation: _podium2Anim,
                    builder: (context, child) {
                      return Transform.translate(
                        offset: Offset(0, 50 * (1 - _podium2Anim.value)),
                        child: Opacity(
                          opacity: _podium2Anim.value,
                          child: _buildPodiumCard(sorted[1], 2),
                        ),
                      );
                    },
                  ),
                const SizedBox(width: 8),
                // 1st place with pulse
                AnimatedBuilder(
                  animation: Listenable.merge([_podium1Anim, _pulseAnim]),
                  builder: (context, child) {
                    return Transform.translate(
                      offset: Offset(0, 60 * (1 - _podium1Anim.value)),
                      child: Opacity(
                        opacity: _podium1Anim.value,
                        child: Transform.scale(
                          scale: _pulseAnim.value,
                          child: _buildPodiumCard(sorted[0], 1),
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(width: 8),
                // 3rd place
                if (sorted.length >= 3)
                  AnimatedBuilder(
                    animation: _podium3Anim,
                    builder: (context, child) {
                      return Transform.translate(
                        offset: Offset(0, 40 * (1 - _podium3Anim.value)),
                        child: Opacity(
                          opacity: _podium3Anim.value,
                          child: _buildPodiumCard(sorted[2], 3),
                        ),
                      );
                    },
                  ),
              ],
            ),

          // Rest of the list
          if (sorted.length > 3) ...[
            const SizedBox(height: 12),
            ...sorted.skip(3).toList().asMap().entries.map((entry) {
              final index = entry.key;
              final child = entry.value;
              return TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.0, end: 1.0),
                duration: Duration(milliseconds: 600 + index * 150),
                curve: Curves.easeOutBack,
                builder: (context, value, _) {
                  return Transform.translate(
                    offset: Offset(30 * (1 - value), 0),
                    child: Opacity(
                      opacity: value,
                      child: _buildListRankCard(child, index + 4),
                    ),
                  );
                },
              );
            }),
          ],
        ],
      ),
    );
  }

  Widget _buildPodiumCard(ChildModel child, int rank) {
    final heights = {1: 120.0, 2: 90.0, 3: 70.0};
    final colors = {
      1: Colors.amber,
      2: Colors.grey[400]!,
      3: Colors.orange[700]!,
    };
    final medals = {1: '🥇', 2: '🥈', 3: '🥉'};

    return Column(
      children: [
        // Medal
        Text(medals[rank]!, style: const TextStyle(fontSize: 24)),
        const SizedBox(height: 4),
        // Avatar
        _buildChildAvatar(child, rank == 1 ? 28 : 22),
        const SizedBox(height: 4),
        Text(
          child.name,
          style: const TextStyle(
              color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 2),
        // Animated counter
        TweenAnimationBuilder<int>(
          tween: IntTween(begin: 0, end: child.totalPoints),
          duration: const Duration(milliseconds: 1500),
          curve: Curves.easeOut,
          builder: (context, value, _) {
            return Text(
              '$value pts',
              style: TextStyle(
                color: colors[rank],
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            );
          },
        ),
        const SizedBox(height: 4),
        // Podium bar
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
            border: Border.all(color: colors[rank]!.withOpacity(0.5)),
          ),
          child: Center(
            child: Text(
              '#$rank',
              style: TextStyle(
                color: Colors.white.withOpacity(0.9),
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildListRankCard(ChildModel child, int rank) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Text('#$rank',
                style: const TextStyle(
                    color: Colors.white54,
                    fontWeight: FontWeight.bold,
                    fontSize: 16)),
            const SizedBox(width: 12),
            _buildChildAvatar(child, 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(child.name,
                  style: const TextStyle(color: Colors.white, fontSize: 14)),
            ),
            TweenAnimationBuilder<int>(
              tween: IntTween(begin: 0, end: child.totalPoints),
              duration: const Duration(milliseconds: 1500),
              builder: (context, value, _) {
                return Text('$value pts',
                    style: TextStyle(
                        color: Colors.cyan[300],
                        fontWeight: FontWeight.bold));
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChildAvatar(ChildModel child, double radius) {
    return CircleAvatar(
      radius: radius,
      backgroundColor: Colors.cyan.withOpacity(0.3),
      child: Text(
        child.name.isNotEmpty ? child.name[0].toUpperCase() : '?',
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: radius * 0.8,
        ),
      ),
    );
  }

  Widget _buildQuickActionsGrid(FamilyProvider fp) {
    final actions = [
      _ActionData('Punition', Icons.menu_book, Colors.red[400]!, () {
        Navigator.push(context,
            MaterialPageRoute(builder: (_) => const PunishmentLinesScreen()));
      }),
      _ActionData('Immunité', Icons.shield, Colors.amber[400]!, () {
        Navigator.push(context,
            MaterialPageRoute(builder: (_) => const ImmunityLinesScreen()));
      }),
      _ActionData('Écran', Icons.tv, Colors.blue[400]!, () {
        if (fp.children.isEmpty) return;
        _showTradeChildPicker(fp, 'screen');
      }),
      _ActionData('Tribunal', Icons.gavel, Colors.purple[400]!, () {
        // Navigate to tribunal
      }),
      _ActionData('Badges', Icons.emoji_events, Colors.orange[400]!, () {
        Navigator.push(context,
            MaterialPageRoute(builder: (_) => const BadgesScreen()));
      }),
      _ActionData('Ventes', Icons.store, Colors.green[400]!, () {
        Navigator.push(
            context, MaterialPageRoute(builder: (_) => const TradeScreen()));
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
          child: const Text(
            '⚡ Actions Rapides',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
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
            final anim = i < _actionAnims.length
                ? _actionAnims[i]
                : _actionsController;
            return AnimatedBuilder(
              animation: anim,
              builder: (context, child) {
                final value =
                    anim is Animation<double> ? anim.value : 1.0;
                return Transform.scale(
                  scale: value.clamp(0.0, 1.0),
                  child: Opacity(
                    opacity: value.clamp(0.0, 1.0),
                    child: _buildActionTile(action),
                  ),
                );
              },
            );
          }),
        ),
      ],
    );
  }

  Widget _buildActionTile(_ActionData action) {
    return TvFocusWrapper(
      onTap: action.onTap,
      child: GlassCard(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Icon with glow
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
            Text(
              action.label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveTrades(FamilyProvider fp) {
    final activeTrades =
        fp.trades.where((t) => t.status == TradeStatus.active).toList();
    if (activeTrades.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '🔄 Échanges en cours',
          style: TextStyle(
              color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        ...activeTrades.asMap().entries.map((entry) {
          final index = entry.key;
          final trade = entry.value;
          return TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: 1.0),
            duration: Duration(milliseconds: 500 + index * 200),
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
                onTap: () => _showTradeDetail(trade, fp),
                child: GlassCard(
                  child: Row(
                    children: [
                      // Animated status indicator
                      _AnimatedStatusDot(
                          color: _tradeStatusColor(trade.status)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              trade.serviceDescription ?? 'Échange',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold),
                            ),
                            Text(
                              '${trade.lineCount} lignes',
                              style: const TextStyle(
                                  color: Colors.white54, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      Icon(Icons.chevron_right, color: Colors.white38),
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

  Color _tradeStatusColor(TradeStatus status) {
    switch (status) {
      case TradeStatus.pending:
        return Colors.orange;
      case TradeStatus.active:
        return Colors.cyan;
      case TradeStatus.completed:
        return Colors.green;
      case TradeStatus.rejected:
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  void _showTradeChildPicker(FamilyProvider fp, String type) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A2E),
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(20)),
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
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            ChildDashboardScreen(childId: child.id),
                      ),
                    );
                  },
                  child: ListTile(
                    leading: _buildChildAvatar(child, 20),
                    title: Text(child.name,
                        style: const TextStyle(color: Colors.white)),
                    subtitle: Text('${child.totalPoints} pts',
                        style: const TextStyle(color: Colors.white54)),
                    trailing: Icon(Icons.chevron_right,
                        color: Colors.white38),
                  ),
                );
              }),
            ],
          ),
        );
      },
    );
  }

  void _showTradeDetail(Trade trade, FamilyProvider fp) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A2E),
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(trade.serviceDescription ?? 'Échange',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              _infoRow('Lignes', '${trade.lineCount}'),
              _infoRow('Statut', trade.status.name),
              const SizedBox(height: 16),
              if (trade.status == TradeStatus.active) ...[
                Row(
                  children: [
                    Expanded(
                      child: TvFocusWrapper(
                        onTap: () {
                          fp.completeTrade(trade.id);
                          Navigator.pop(context);
                        },
                        child: ElevatedButton.icon(
                          onPressed: null,
                          icon: const Icon(Icons.check),
                          label: const Text('Valider'),
                          style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TvFocusWrapper(
                        onTap: () {
                          fp.cancelTrade(trade.id);
                          Navigator.pop(context);
                        },
                        child: ElevatedButton.icon(
                          onPressed: null,
                          icon: const Icon(Icons.close),
                          label: const Text('Annuler'),
                          style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.white54)),
          Text(value,
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  void _showFullHistory(FamilyProvider fp) {
    final allHistory = <Map<String, dynamic>>[];
    for (final child in fp.children) {
      for (final h in fp.getHistoryForChild(child.id)) {
        allHistory.add({...h, 'childName': child.name});
      }
    }
    allHistory.sort((a, b) =>
        (b['timestamp'] as DateTime).compareTo(a['timestamp'] as DateTime));

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.85,
          builder: (context, scrollController) {
            return Container(
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A2E),
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 12),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('📋 Historique Complet',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold)),
                  ),
                  Expanded(
                    child: ListView.builder(
                      controller: scrollController,
                      itemCount: allHistory.length,
                      itemBuilder: (context, index) {
                        final h = allHistory[index];
                        final pts = h['points'] as int? ?? 0;
                        return TweenAnimationBuilder<double>(
                          tween: Tween(begin: 0.0, end: 1.0),
                          duration: Duration(
                              milliseconds:
                                  300 + (index.clamp(0, 20) * 30)),
                          builder: (context, value, child) {
                            return Opacity(
                              opacity: value,
                              child: Transform.translate(
                                offset: Offset(20 * (1 - value), 0),
                                child: child,
                              ),
                            );
                          },
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: pts >= 0
                                  ? Colors.green.withOpacity(0.2)
                                  : Colors.red.withOpacity(0.2),
                              child: Text(
                                pts >= 0 ? '+$pts' : '$pts',
                                style: TextStyle(
                                  color:
                                      pts >= 0 ? Colors.green : Colors.red,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                            title: Text(
                              h['reason'] ?? '',
                              style:
                                  const TextStyle(color: Colors.white),
                            ),
                            subtitle: Text(
                              '${h['childName']} • ${h['category'] ?? ''}',
                              style: const TextStyle(
                                  color: Colors.white54, fontSize: 11),
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

// Animated pulsing status dot
class _AnimatedStatusDot extends StatefulWidget {
  final Color color;
  const _AnimatedStatusDot({required this.color});
  @override
  State<_AnimatedStatusDot> createState() => _AnimatedStatusDotState();
}

class _AnimatedStatusDotState extends State<_AnimatedStatusDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, child) {
        return Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: widget.color,
            boxShadow: [
              BoxShadow(
                color: widget.color.withOpacity(0.3 + 0.4 * _ctrl.value),
                blurRadius: 6 + 6 * _ctrl.value,
                spreadRadius: 1 + 2 * _ctrl.value,
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ActionData {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  _ActionData(this.label, this.icon, this.color, this.onTap);
}
