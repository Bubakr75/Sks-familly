import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/family_provider.dart';
import '../models/badge_model.dart';
import '../utils/pin_guard.dart';
import '../widgets/glass_card.dart';
import '../widgets/animated_background.dart';
import '../widgets/tv_focus_wrapper.dart';

// ═══════════════════════════════════════════════════════════
//  TROPHÉE ROTATIF DORÉ AVEC HALO
// ═══════════════════════════════════════════════════════════
class _RotatingTrophy extends StatefulWidget {
  final String emoji;
  final bool unlocked;
  final double size;
  const _RotatingTrophy({required this.emoji, required this.unlocked, this.size = 32});
  @override
  State<_RotatingTrophy> createState() => _RotatingTrophyState();
}

class _RotatingTrophyState extends State<_RotatingTrophy> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(seconds: 3))
      ..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.unlocked) {
      return Opacity(
        opacity: 0.3,
        child: Text(widget.emoji, style: TextStyle(fontSize: widget.size)),
      );
    }
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        final t = _ctrl.value;
        // Rotation Y simulée via scale X
        final scaleX = cos(t * 2 * pi).abs().clamp(0.3, 1.0);
        final glowOpacity = (0.3 + 0.3 * sin(t * 2 * pi)).clamp(0.0, 1.0);
        return Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(color: Colors.amber.withOpacity(glowOpacity * 0.4), blurRadius: 15, spreadRadius: 2),
            ],
          ),
          child: Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()..scale(scaleX, 1.0),
            child: Text(widget.emoji, style: TextStyle(fontSize: widget.size)),
          ),
        );
      },
    );
  }
}

// ═══════════════════════════════════════════════════════════
//  ANIMATION BADGE DÉBLOQUÉ
// ═══════════════════════════════════════════════════════════
class _BadgeUnlockedAnimation extends StatefulWidget {
  final String emoji;
  final String name;
  final VoidCallback onComplete;
  const _BadgeUnlockedAnimation({required this.emoji, required this.name, required this.onComplete});
  @override
  State<_BadgeUnlockedAnimation> createState() => _BadgeUnlockedAnimationState();
}

class _BadgeUnlockedAnimationState extends State<_BadgeUnlockedAnimation> with TickerProviderStateMixin {
  late AnimationController _mainCtrl;
  late Animation<double> _emojiScale;
  late Animation<double> _textFade;
  late AnimationController _sparkCtrl;
  final _rng = Random();
  late List<_Spark> _sparks;

  @override
  void initState() {
    super.initState();
    _mainCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 2200))
      ..forward().then((_) => widget.onComplete());
    _emojiScale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween<double>(begin: 0.0, end: 1.5).chain(CurveTween(curve: Curves.easeOutBack)), weight: 35),
      TweenSequenceItem(tween: Tween<double>(begin: 1.5, end: 1.0).chain(CurveTween(curve: Curves.easeInOut)), weight: 15),
      TweenSequenceItem(tween: Tween<double>(begin: 1.0, end: 1.0), weight: 50),
    ]).animate(_mainCtrl);
    _textFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _mainCtrl, curve: const Interval(0.35, 0.6, curve: Curves.easeIn)),
    );
    _sparkCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 3))..repeat();
    _sparks = List.generate(20, (i) => _Spark(
      angle: (i / 20) * 2 * pi,
      speed: 50 + _rng.nextDouble() * 100,
      size: 2 + _rng.nextDouble() * 3,
      color: [Colors.amber, Colors.orangeAccent, Colors.yellowAccent, Colors.white][_rng.nextInt(4)],
    ));
  }

  @override
  void dispose() {
    _mainCtrl.dispose();
    _sparkCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_mainCtrl, _sparkCtrl]),
      builder: (context, _) {
        return Stack(alignment: Alignment.center, children: [
          Container(color: Colors.amber.withOpacity(0.05 * (1 - _mainCtrl.value))),
          // Étincelles orbitales
          CustomPaint(size: Size.infinite, painter: _SparkPainter(_sparks, _sparkCtrl.value, _mainCtrl.value)),
          // Halo doré
          Container(
            width: 140, height: 140,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(colors: [
                Colors.amber.withOpacity(0.2 * _emojiScale.value.clamp(0.0, 1.0)),
                Colors.amber.withOpacity(0.0),
              ]),
              boxShadow: [
                BoxShadow(color: Colors.amber.withOpacity(0.2 * _emojiScale.value.clamp(0.0, 1.0)), blurRadius: 40, spreadRadius: 10),
              ],
            ),
          ),
          // Emoji qui rebondit
          Transform.scale(
            scale: _emojiScale.value,
            child: Text(widget.emoji, style: const TextStyle(fontSize: 64)),
          ),
          // Texte
          Positioned(
            bottom: MediaQuery.of(context).size.height * 0.3,
            child: FadeTransition(
              opacity: _textFade,
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Text('POUVOIR DÉBLOQUÉ !', style: TextStyle(color: Colors.amber, fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: 3, shadows: [Shadow(color: Colors.orangeAccent, blurRadius: 15)])),
                const SizedBox(height: 8),
                Text(widget.name, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
              ]),
            ),
          ),
        ]);
      },
    );
  }
}

class _Spark {
  final double angle, speed, size;
  final Color color;
  _Spark({required this.angle, required this.speed, required this.size, required this.color});
}

class _SparkPainter extends CustomPainter {
  final List<_Spark> sparks;
  final double orbit;
  final double mainT;
  _SparkPainter(this.sparks, this.orbit, this.mainT);

  @override
  void paint(Canvas canvas, Size size) {
    if (mainT > 0.8) return;
    final cx = size.width / 2;
    final cy = size.height / 2;
    for (final s in sparks) {
      final angle = s.angle + orbit * 2 * pi;
      final dist = 30 + s.speed * mainT;
      final dx = cx + cos(angle) * dist;
      final dy = cy + sin(angle) * dist;
      final opacity = (1.0 - mainT).clamp(0.0, 1.0);
      final paint = Paint()
        ..color = s.color.withOpacity(opacity * 0.7)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, s.size);
      canvas.drawCircle(Offset(dx, dy), s.size, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _SparkPainter old) => true;
}

Future<void> showBadgeUnlockedAnimation(BuildContext context, String emoji, String name) {
  return showGeneralDialog(
    context: context, barrierDismissible: false, barrierColor: Colors.black87,
    transitionDuration: const Duration(milliseconds: 100),
    pageBuilder: (ctx, _, __) => Material(color: Colors.transparent,
      child: _BadgeUnlockedAnimation(emoji: emoji, name: name, onComplete: () => Navigator.of(ctx).pop())),
  );
}

// ═══════════════════════════════════════════════════════════
//  ANIMATED PROGRESS ARC (progression par enfant)
// ═══════════════════════════════════════════════════════════
class _AnimatedProgressArc extends StatelessWidget {
  final double progress;
  final Color color;
  const _AnimatedProgressArc({required this.progress, required this.color});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: progress),
      duration: const Duration(milliseconds: 1000),
      curve: Curves.easeOutCubic,
      builder: (context, val, _) {
        return Stack(children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: val.clamp(0.0, 1.0),
              backgroundColor: Colors.white12,
              valueColor: AlwaysStoppedAnimation<Color>(color),
              minHeight: 6,
            ),
          ),
          if (val > 0.05)
            Positioned(
              left: 0, right: 0,
              child: FractionallySizedBox(
                widthFactor: val.clamp(0.0, 1.0),
                alignment: Alignment.centerLeft,
                child: Container(
                  height: 6,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(6),
                    boxShadow: [BoxShadow(color: color.withOpacity(0.5), blurRadius: 6)],
                  ),
                ),
              ),
            ),
        ]);
      },
    );
  }
}

// ═══════════════════════════════════════════════════════════
//  BADGES SCREEN
// ═══════════════════════════════════════════════════════════
class BadgesScreen extends StatelessWidget {
  const BadgesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: () => PinGuard.guardAction(context, () => _showAddBadgeDialog(context)),
        backgroundColor: Theme.of(context).colorScheme.primary,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: AnimatedBackground(
        child: Consumer<FamilyProvider>(
          builder: (context, provider, _) {
            final allBadges = [...BadgeModel.defaultBadges, ...provider.customBadges];
            final children = provider.children;

            return SafeArea(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                    child: Row(children: [
                      IconButton(icon: const Icon(Icons.arrow_back_ios_new, size: 20), onPressed: () => Navigator.pop(context)),
                      // Trophée rotatif dans le titre
                      const _RotatingTrophy(emoji: '⚡', unlocked: true, size: 24),
                      const SizedBox(width: 8),
                      const Expanded(child: Text('Pouvoirs', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis)),
                      TvFocusWrapper(
                        onTap: () => _showBadgeInfo(context, allBadges),
                        child: IconButton(icon: const Icon(Icons.info_outline, size: 20), onPressed: () => _showBadgeInfo(context, allBadges)),
                      ),
                    ]),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: children.isEmpty
                        ? const Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                            Text('👶', style: TextStyle(fontSize: 48)),
                            SizedBox(height: 12),
                            Text('Ajoutez des enfants pour commencer', style: TextStyle(color: Colors.white60)),
                          ]))
                        : ListView(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            children: [
                              const Text('Tous les pouvoirs', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white70)),
                              const SizedBox(height: 8),
                              GridView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 3, childAspectRatio: 0.8, crossAxisSpacing: 8, mainAxisSpacing: 8),
                                itemCount: allBadges.length,
                                itemBuilder: (context, index) {
                                  final badge = allBadges[index];
                                  // Au moins un enfant a ce badge ?
                                  final anyUnlocked = children.any((c) => c.points >= badge.requiredPoints);
                                  return TvFocusWrapper(
                                    onTap: badge.isCustom ? () => PinGuard.guardAction(context, () => _showEditBadgeDialog(context, provider, badge)) : null,
                                    child: GestureDetector(
                                      onLongPress: badge.isCustom ? () => PinGuard.guardAction(context, () => _showEditBadgeDialog(context, provider, badge)) : null,
                                      child: GlassCard(
                                        child: Padding(
                                          padding: const EdgeInsets.all(8),
                                          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                                            _RotatingTrophy(emoji: badge.powerEmoji, unlocked: anyUnlocked, size: 28),
                                            const SizedBox(height: 4),
                                            Text(badge.name, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold), textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis),
                                            const SizedBox(height: 2),
                                            Text('${badge.requiredPoints} pts', style: TextStyle(fontSize: 10, color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.w600)),
                                            if (badge.isCustom)
                                              const Text('personnalisé', style: TextStyle(fontSize: 8, color: Colors.white38)),
                                          ]),
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                              const SizedBox(height: 20),
                              const Text('Progression par enfant', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white70)),
                              const SizedBox(height: 8),
                              ...children.map((child) {
                                final earned = allBadges.where((b) => child.points >= b.requiredPoints).toList();
                                final progress = allBadges.isEmpty ? 0.0 : earned.length / allBadges.length;
                                // Prochain badge
                                final nextBadges = allBadges.where((b) => child.points < b.requiredPoints).toList();
                                nextBadges.sort((a, b) => a.requiredPoints.compareTo(b.requiredPoints));
                                final nextBadge = nextBadges.isNotEmpty ? nextBadges.first : null;
                                final nextProgress = nextBadge != null ? (child.points / nextBadge.requiredPoints).clamp(0.0, 1.0) : 1.0;

                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: GlassCard(
                                    child: Padding(
                                      padding: const EdgeInsets.all(16),
                                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                        Row(children: [
                                          CircleAvatar(radius: 18, backgroundColor: Colors.white12,
                                            child: Text(child.avatar, style: const TextStyle(fontSize: 18))),
                                          const SizedBox(width: 12),
                                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                            Text(child.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                                            Text('${earned.length}/${allBadges.length} pouvoirs — ${child.points} pts', style: const TextStyle(color: Colors.white60, fontSize: 12)),
                                          ])),
                                          // Pourcentage animé
                                          TweenAnimationBuilder<double>(
                                            tween: Tween<double>(begin: 0, end: progress * 100),
                                            duration: const Duration(milliseconds: 800),
                                            builder: (context, val, _) => Text('${val.round()}%', style: TextStyle(color: Colors.amber.withOpacity(0.8), fontWeight: FontWeight.bold, fontSize: 14)),
                                          ),
                                        ]),
                                        const SizedBox(height: 10),
                                        _AnimatedProgressArc(progress: progress, color: Colors.amber),
                                        // Prochain badge
                                        if (nextBadge != null) ...[
                                          const SizedBox(height: 10),
                                          Row(children: [
                                            Text('Prochain: ', style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 11)),
                                            Text(nextBadge.powerEmoji, style: const TextStyle(fontSize: 14)),
                                            const SizedBox(width: 4),
                                            Expanded(child: Text('${nextBadge.name} (${nextBadge.requiredPoints} pts)', style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 11), overflow: TextOverflow.ellipsis)),
                                            SizedBox(width: 50, child: _AnimatedProgressArc(progress: nextProgress, color: Colors.cyanAccent)),
                                          ]),
                                        ],
                                        const SizedBox(height: 10),
                                        Wrap(spacing: 6, runSpacing: 6, children: allBadges.map((badge) {
                                          final unlocked = child.points >= badge.requiredPoints;
                                          return TvFocusWrapper(
                                            onTap: unlocked ? () => showBadgeUnlockedAnimation(context, badge.powerEmoji, badge.name) : null,
                                            child: GestureDetector(
                                              onTap: unlocked ? () => showBadgeUnlockedAnimation(context, badge.powerEmoji, badge.name) : null,
                                              child: AnimatedContainer(
                                                duration: const Duration(milliseconds: 300),
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                decoration: BoxDecoration(
                                                  color: unlocked ? Colors.green.withOpacity(0.2) : Colors.white.withOpacity(0.05),
                                                  borderRadius: BorderRadius.circular(12),
                                                  border: Border.all(color: unlocked ? Colors.greenAccent.withOpacity(0.5) : Colors.white12),
                                                ),
                                                child: Row(mainAxisSize: MainAxisSize.min, children: [
                                                  _RotatingTrophy(emoji: badge.powerEmoji, unlocked: unlocked, size: 14),
                                                  const SizedBox(width: 4),
                                                  Text(badge.name, style: TextStyle(fontSize: 10, color: unlocked ? Colors.greenAccent : Colors.white38)),
                                                  if (unlocked) ...[
                                                    const SizedBox(width: 4),
                                                    const Icon(Icons.check_circle, size: 12, color: Colors.greenAccent),
                                                  ],
                                                ]),
                                              ),
                                            ),
                                          );
                                        }).toList()),
                                      ]),
                                    ),
                                  ),
                                );
                              }),
                              const SizedBox(height: 80),
                            ],
                          ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  void _showBadgeInfo(BuildContext context, List<BadgeModel> badges) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(children: [
          TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0, end: 1),
            duration: const Duration(milliseconds: 600),
            curve: Curves.elasticOut,
            builder: (context, val, child) => Transform.scale(scale: val, child: child),
            child: const Text('⚡', style: TextStyle(fontSize: 22)),
          ),
          const SizedBox(width: 8),
          const Text('Système de pouvoirs', style: TextStyle(color: Colors.white, fontSize: 16)),
        ]),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView(shrinkWrap: true, children: [
            const Text('Les enfants débloquent des pouvoirs en accumulant des points. Chaque pouvoir donne un privilège spécial !', style: TextStyle(color: Colors.white70, fontSize: 13)),
            const SizedBox(height: 16),
            ...badges.map((b) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(children: [
                _RotatingTrophy(emoji: b.powerEmoji, unlocked: true, size: 20),
                const SizedBox(width: 10),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(b.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  Text(b.description, style: const TextStyle(color: Colors.white60, fontSize: 11)),
                ])),
                Text('${b.requiredPoints} pts', style: TextStyle(color: Theme.of(context).colorScheme.primary, fontSize: 12, fontWeight: FontWeight.bold)),
              ]),
            )),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Compris !')),
        ],
      ),
    );
  }

  void _showAddBadgeDialog(BuildContext context) {
    final nameCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final pointsCtrl = TextEditingController(text: '50');
    String selectedPower = 'custom';

    final powerOptions = [
      {'type': 'tv', 'emoji': '📺', 'label': 'Télé'},
      {'type': 'no_chores', 'emoji': '🧹', 'label': 'Corvées'},
      {'type': 'dessert', 'emoji': '🍰', 'label': 'Dessert'},
      {'type': 'late_bed', 'emoji': '🌙', 'label': 'Coucher'},
      {'type': 'game', 'emoji': '🎮', 'label': 'Jeu'},
      {'type': 'outing', 'emoji': '🏠', 'label': 'Sortie'},
      {'type': 'custom', 'emoji': '⚡', 'label': 'Autre'},
    ];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          backgroundColor: const Color(0xFF1A1A2E),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Nouveau pouvoir', style: TextStyle(color: Colors.white)),
          content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
            Wrap(spacing: 8, runSpacing: 8, children: powerOptions.map((opt) {
              final selected = selectedPower == opt['type'];
              return TvFocusWrapper(
                onTap: () => setState(() => selectedPower = opt['type'] as String),
                child: GestureDetector(
                  onTap: () => setState(() => selectedPower = opt['type'] as String),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: selected ? Colors.white.withOpacity(0.15) : Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: selected ? Border.all(color: Theme.of(context).colorScheme.primary) : null,
                    ),
                    child: Column(children: [
                      Text(opt['emoji'] as String, style: const TextStyle(fontSize: 20)),
                      Text(opt['label'] as String, style: const TextStyle(fontSize: 9, color: Colors.white60)),
                    ]),
                  ),
                ),
              );
            }).toList()),
            const SizedBox(height: 16),
            TextField(controller: nameCtrl, style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(labelText: 'Nom du pouvoir', labelStyle: const TextStyle(color: Colors.white60), filled: true, fillColor: Colors.white.withOpacity(0.1),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none))),
            const SizedBox(height: 12),
            TextField(controller: descCtrl, style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(labelText: 'Description', labelStyle: const TextStyle(color: Colors.white60), filled: true, fillColor: Colors.white.withOpacity(0.1),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none))),
            const SizedBox(height: 12),
            TextField(controller: pointsCtrl, keyboardType: TextInputType.number, style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(labelText: 'Points requis', labelStyle: const TextStyle(color: Colors.white60), filled: true, fillColor: Colors.white.withOpacity(0.1),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none))),
          ])),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
            TvFocusWrapper(
              onTap: () {
                if (nameCtrl.text.isNotEmpty) {
                  context.read<FamilyProvider>().addCustomBadge(nameCtrl.text, selectedPower, descCtrl.text, int.tryParse(pointsCtrl.text) ?? 50, powerType: selectedPower);
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Pouvoir "${nameCtrl.text}" créé !')));
                }
              },
              child: ElevatedButton(
                onPressed: () {
                  if (nameCtrl.text.isNotEmpty) {
                    context.read<FamilyProvider>().addCustomBadge(nameCtrl.text, selectedPower, descCtrl.text, int.tryParse(pointsCtrl.text) ?? 50, powerType: selectedPower);
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Pouvoir "${nameCtrl.text}" créé !')));
                  }
                },
                child: const Text('Créer'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditBadgeDialog(BuildContext context, FamilyProvider provider, BadgeModel badge) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(children: [
          _RotatingTrophy(emoji: badge.powerEmoji, unlocked: true, size: 22),
          const SizedBox(width: 8),
          Expanded(child: Text(badge.name, style: const TextStyle(color: Colors.white, fontSize: 16))),
        ]),
        content: Text(badge.description, style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Fermer')),
          TvFocusWrapper(
            onTap: () { provider.removeCustomBadge(badge.id); Navigator.pop(ctx); ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Pouvoir "${badge.name}" supprimé'))); },
            child: TextButton(
              onPressed: () { provider.removeCustomBadge(badge.id); Navigator.pop(ctx); ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Pouvoir "${badge.name}" supprimé'))); },
              child: const Text('Supprimer', style: TextStyle(color: Colors.redAccent)),
            ),
          ),
        ],
      ),
    );
  }
}
