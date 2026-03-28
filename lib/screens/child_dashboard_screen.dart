import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/family_provider.dart';
import '../providers/pin_provider.dart';
import '../models/child_model.dart';
import '../widgets/animated_background.dart';
import '../widgets/glass_card.dart';
import '../widgets/tv_focus_wrapper.dart';

class ChildDashboardScreen extends StatefulWidget {
  final String childId;
  const ChildDashboardScreen({super.key, required this.childId});
  @override
  State<ChildDashboardScreen> createState() => _ChildDashboardScreenState();
}

class _ChildDashboardScreenState extends State<ChildDashboardScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  late AnimationController _profileController;
  late AnimationController _contentController;
  late AnimationController _glowController;

  late Animation<double> _profileScale;
  late Animation<double> _profileFade;
  late Animation<double> _glowAnim;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() => setState(() {}));

    _profileController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _profileScale = CurvedAnimation(
      parent: _profileController,
      curve: Curves.elasticOut,
    );
    _profileFade = CurvedAnimation(
      parent: _profileController,
      curve: const Interval(0.0, 0.4, curve: Curves.easeIn),
    );

    _contentController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);
    _glowAnim = Tween<double>(begin: 0.3, end: 0.8).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );

    _profileController.forward();
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) _contentController.forward();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _profileController.dispose();
    _contentController.dispose();
    _glowController.dispose();
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
        final child = fp.children.cast<ChildModel?>().firstWhere(
              (c) => c!.id == widget.childId,
              orElse: () => null,
            );
        if (child == null) {
          return const Scaffold(
            body: Center(child: Text('Enfant introuvable')),
          );
        }

        return AnimatedBackground(
          child: Scaffold(
            backgroundColor: Colors.transparent,
            appBar: AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              title: Text(child.name,
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              bottom: TabBar(
                controller: _tabController,
                indicatorColor: Colors.cyan,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white38,
                tabs: const [
                  Tab(icon: Icon(Icons.person), text: 'Profil'),
                  Tab(icon: Icon(Icons.timer), text: 'Écran'),
                  Tab(icon: Icon(Icons.history), text: 'Historique'),
                  Tab(icon: Icon(Icons.emoji_events), text: 'Badges'),
                ],
              ),
            ),
            body: TabBarView(
              controller: _tabController,
              children: [
                _buildProfileTab(child, fp),
                _buildScreenTimeTab(child, fp),
                _buildHistoryTab(child, fp),
                _buildBadgesTab(child, fp),
              ],
            ),
          ),
        );
      },
    );
  }

  // ─── PROFILE TAB ───
  Widget _buildProfileTab(ChildModel child, FamilyProvider fp) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Animated avatar with glow
          AnimatedBuilder(
            animation: Listenable.merge([_profileScale, _glowAnim]),
            builder: (context, _) {
              return Transform.scale(
                scale: _profileScale.value.clamp(0.0, 1.0),
                child: Opacity(
                  opacity: _profileFade.value,
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.cyan.withOpacity(_glowAnim.value),
                          blurRadius: 30,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                    child: CircleAvatar(
                      radius: 50,
                      backgroundColor: Colors.cyan.withOpacity(0.3),
                      child: Text(
                        child.name.isNotEmpty
                            ? child.name[0].toUpperCase()
                            : '?',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 40,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 16),

          // Animated points counter
          TweenAnimationBuilder<int>(
            tween: IntTween(begin: 0, end: child.totalPoints),
            duration: const Duration(milliseconds: 2000),
            curve: Curves.easeOut,
            builder: (context, value, _) {
              return ShaderMask(
                shaderCallback: (bounds) => LinearGradient(
                  colors: [Colors.cyan, Colors.blue, Colors.purple],
                ).createShader(bounds),
                child: Text(
                  '$value points',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 20),

          // Stats cards with stagger
          ..._buildProfileStats(child, fp),
        ],
      ),
    );
  }

  List<Widget> _buildProfileStats(ChildModel child, FamilyProvider fp) {
    final history = fp.getHistoryForChild(child.id);
    final bonus = history.where((h) => (h['points'] as int? ?? 0) > 0).length;
    final penalty =
        history.where((h) => (h['points'] as int? ?? 0) < 0).length;

    final stats = [
      {'label': 'Total activités', 'value': '${history.length}', 'icon': Icons.timeline, 'color': Colors.cyan},
      {'label': 'Bonus', 'value': '$bonus', 'icon': Icons.thumb_up, 'color': Colors.green},
      {'label': 'Pénalités', 'value': '$penalty', 'icon': Icons.thumb_down, 'color': Colors.red},
      {'label': 'Écran restant', 'value': _formatMinutes(fp.getScreenTimeMinutes(child.id)), 'icon': Icons.tv, 'color': Colors.blue},
    ];

    return stats.asMap().entries.map((entry) {
      final i = entry.key;
      final s = entry.value;
      return TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.0, end: 1.0),
        duration: Duration(milliseconds: 600 + i * 200),
        curve: Curves.easeOutBack,
        builder: (context, value, child) {
          return Transform.translate(
            offset: Offset(40 * (1 - value), 0),
            child: Opacity(opacity: value, child: child),
          );
        },
        child: Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: GlassCard(
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: (s['color'] as Color).withOpacity(0.15),
                  ),
                  child: Icon(s['icon'] as IconData,
                      color: s['color'] as Color, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(s['label'] as String,
                      style: const TextStyle(color: Colors.white54)),
                ),
                Text(
                  s['value'] as String,
                  style: TextStyle(
                    color: s['color'] as Color,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }).toList();
  }

  // ─── SCREEN TIME TAB ───
  Widget _buildScreenTimeTab(ChildModel child, FamilyProvider fp) {
    final minutes = fp.getScreenTimeMinutes(child.id);
    final maxMinutes = 180; // 3h max display
    final ratio = (minutes / maxMinutes).clamp(0.0, 1.0);
    final isParent =
        Provider.of<PinProvider>(context, listen: false).isParentMode;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Animated circular progress
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: ratio),
            duration: const Duration(milliseconds: 2000),
            curve: Curves.easeOutCubic,
            builder: (context, value, _) {
              return SizedBox(
                width: 180,
                height: 180,
                child: CustomPaint(
                  painter: _ScreenTimePainter(value, minutes),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TweenAnimationBuilder<int>(
                          tween: IntTween(begin: 0, end: minutes),
                          duration: const Duration(milliseconds: 2000),
                          builder: (context, val, _) {
                            return Text(
                              _formatMinutes(val),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                              ),
                            );
                          },
                        ),
                        const Text('restant',
                            style: TextStyle(
                                color: Colors.white54, fontSize: 12)),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 24),

          // Quick bonus buttons
          if (isParent) ...[
            const Text('Bonus rapide',
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [15, 30, 60].map((mins) {
                return TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.0, end: 1.0),
                  duration: const Duration(milliseconds: 800),
                  curve: Curves.elasticOut,
                  builder: (context, value, child) {
                    return Transform.scale(
                        scale: value, child: child);
                  },
                  child: TvFocusWrapper(
                    onTap: () {
                      fp.addScreenTimeBonus(child.id, mins);
                      _showBonusAnimation(mins);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 12),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.cyan.withOpacity(0.3),
                            Colors.blue.withOpacity(0.3),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: Colors.cyan.withOpacity(0.5)),
                      ),
                      child: Text(
                        '+${mins}min',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            TvFocusWrapper(
              onTap: () => _showCustomBonusDialog(child, fp),
              child: GlassCard(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.add_circle, color: Colors.cyan[300]),
                    const SizedBox(width: 8),
                    Text('Bonus personnalisé',
                        style: TextStyle(color: Colors.cyan[300])),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _showBonusAnimation(int mins) {
    showDialog(
      context: context,
      barrierColor: Colors.transparent,
      builder: (context) {
        Future.delayed(const Duration(milliseconds: 1200), () {
          if (Navigator.of(context).canPop()) Navigator.pop(context);
        });
        return Center(
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: 1.0),
            duration: const Duration(milliseconds: 800),
            curve: Curves.elasticOut,
            builder: (context, value, child) {
              return Transform.scale(
                scale: value,
                child: Opacity(
                  opacity: value.clamp(0.0, 1.0),
                  child: child,
                ),
              );
            },
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 32, vertical: 20),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.9),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.green.withOpacity(0.5),
                    blurRadius: 30,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: Text(
                '⏰ +${mins}min !',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _showCustomBonusDialog(ChildModel child, FamilyProvider fp) {
    int customMins = 15;
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF1A1A2E),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              title: const Text('Bonus personnalisé',
                  style: TextStyle(color: Colors.white)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('$customMins min',
                      style: TextStyle(
                          color: Colors.cyan[300],
                          fontSize: 32,
                          fontWeight: FontWeight.bold)),
                  Slider(
                    value: customMins.toDouble(),
                    min: 5,
                    max: 240,
                    divisions: 47,
                    activeColor: Colors.cyan,
                    onChanged: (v) =>
                        setDialogState(() => customMins = v.round()),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Annuler',
                      style: TextStyle(color: Colors.white54)),
                ),
                ElevatedButton(
                  onPressed: () {
                    fp.addScreenTimeBonus(child.id, customMins);
                    Navigator.pop(context);
                    _showBonusAnimation(customMins);
                  },
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.cyan),
                  child: const Text('Ajouter'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ─── HISTORY TAB ───
  Widget _buildHistoryTab(ChildModel child, FamilyProvider fp) {
    final history = fp.getHistoryForChild(child.id);
    if (history.isEmpty) {
      return Center(
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.0, end: 1.0),
          duration: const Duration(milliseconds: 800),
          builder: (context, value, child) {
            return Opacity(opacity: value, child: child);
          },
          child: const Text('Aucune activité',
              style: TextStyle(color: Colors.white54, fontSize: 16)),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: history.length,
      itemBuilder: (context, index) {
        final h = history[history.length - 1 - index]; // Most recent first
        final pts = h['points'] as int? ?? 0;
        final isPositive = pts >= 0;

        return TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.0, end: 1.0),
          duration: Duration(milliseconds: 400 + (index.clamp(0, 15) * 50)),
          curve: Curves.easeOutCubic,
          builder: (context, value, child) {
            return Transform.translate(
              offset: Offset(0, 20 * (1 - value)),
              child: Opacity(opacity: value, child: child),
            );
          },
          child: Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: GlassCard(
              child: Row(
                children: [
                  // Animated points badge
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: isPositive
                            ? [Colors.green, Colors.green.shade700]
                            : [Colors.red, Colors.red.shade700],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: (isPositive ? Colors.green : Colors.red)
                              .withOpacity(0.3),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        isPositive ? '+$pts' : '$pts',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          h['reason'] ?? 'Activité',
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold),
                        ),
                        if (h['category'] != null)
                          Container(
                            margin: const EdgeInsets.only(top: 4),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.cyan.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              h['category'] as String,
                              style: TextStyle(
                                  color: Colors.cyan[300], fontSize: 10),
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (h['timestamp'] != null)
                    Text(
                      _formatDate(h['timestamp'] as DateTime),
                      style: const TextStyle(
                          color: Colors.white38, fontSize: 10),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  String _formatDate(DateTime dt) {
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  // ─── BADGES TAB ───
  Widget _buildBadgesTab(ChildModel child, FamilyProvider fp) {
    final badges = fp.getBadgesForChild(child.id);

    if (badges.isEmpty) {
      return Center(
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.0, end: 1.0),
          duration: const Duration(milliseconds: 800),
          builder: (context, value, child) {
            return Opacity(
              opacity: value,
              child: Transform.scale(scale: value, child: child),
            );
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('🏆', style: TextStyle(fontSize: 50)),
              const SizedBox(height: 8),
              const Text('Aucun badge encore',
                  style: TextStyle(color: Colors.white54)),
            ],
          ),
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 0.8,
      ),
      itemCount: badges.length,
      itemBuilder: (context, index) {
        final badge = badges[index];
        final isUnlocked = badge['unlocked'] as bool? ?? false;

        return TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.0, end: 1.0),
          duration: Duration(milliseconds: 500 + index * 120),
          curve: Curves.elasticOut,
          builder: (context, value, child) {
            return Transform.scale(
              scale: value.clamp(0.0, 1.0),
              child: Transform.rotate(
                angle: (1 - value) * 0.3,
                child: Opacity(
                  opacity: value.clamp(0.0, 1.0),
                  child: child,
                ),
              ),
            );
          },
          child: GlassCard(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Badge icon with glow if unlocked
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isUnlocked
                        ? Colors.amber.withOpacity(0.2)
                        : Colors.grey.withOpacity(0.1),
                    boxShadow: isUnlocked
                        ? [
                            BoxShadow(
                              color: Colors.amber.withOpacity(0.4),
                              blurRadius: 12,
                              spreadRadius: 2,
                            ),
                          ]
                        : [],
                  ),
                  child: Icon(
                    isUnlocked ? Icons.emoji_events : Icons.lock,
                    color: isUnlocked ? Colors.amber : Colors.grey,
                    size: 28,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  badge['name'] ?? '',
                  style: TextStyle(
                    color: isUnlocked ? Colors.white : Colors.white38,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// Custom painter for circular screen time
class _ScreenTimePainter extends CustomPainter {
  final double progress;
  final int minutes;
  _ScreenTimePainter(this.progress, this.minutes);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 10;

    // Background circle
    final bgPaint = Paint()
      ..color = Colors.white.withOpacity(0.1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12;
    canvas.drawCircle(center, radius, bgPaint);

    // Progress arc
    final color = progress > 0.5
        ? Colors.cyan
        : progress > 0.2
            ? Colors.orange
            : Colors.red;
    final progressPaint = Paint()
      ..shader = SweepGradient(
        startAngle: -1.5708,
        endAngle: -1.5708 + 6.2832 * progress,
        colors: [color.withOpacity(0.5), color],
      ).createShader(Rect.fromCircle(center: center, radius: radius))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -1.5708, // Start from top
      6.2832 * progress,
      false,
      progressPaint,
    );

    // Glow dot at end
    if (progress > 0.01) {
      final angle = -1.5708 + 6.2832 * progress;
      final dotX = center.dx + radius * _cos(angle);
      final dotY = center.dy + radius * _sin(angle);
      final dotPaint = Paint()
        ..color = color
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
      canvas.drawCircle(Offset(dotX, dotY), 6, dotPaint);
    }
  }

  double _cos(double a) => a == 0 ? 1.0 : _cosImpl(a);
  double _sin(double a) => a == 0 ? 0.0 : _sinImpl(a);
  double _cosImpl(double a) {
    // Simple cos using dart:math would be better, using approximation
    return 1.0 -
        (a * a) / 2 +
        (a * a * a * a) / 24 -
        (a * a * a * a * a * a) / 720;
  }

  double _sinImpl(double a) {
    return a -
        (a * a * a) / 6 +
        (a * a * a * a * a) / 120 -
        (a * a * a * a * a * a * a) / 5040;
  }

  @override
  bool shouldRepaint(covariant _ScreenTimePainter oldDelegate) =>
      progress != oldDelegate.progress;
}
