import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/family_provider.dart';
import '../models/badge_model.dart';
import '../widgets/glass_card.dart';
import '../widgets/animated_background.dart';

class BadgesScreen extends StatelessWidget {
  const BadgesScreen({super.key});

  static const _badgeEmojis = {
    'star': '\u{2B50}',
    'school': '\u{1F393}',
    'thumb_up': '\u{1F44D}',
    'home': '\u{1F3E0}',
    'emoji_events': '\u{1F3C6}',
    'military_tech': '\u{1F396}',
  };

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    return Scaffold(
      backgroundColor: const Color(0xFF0A0E21),
      body: AnimatedBackground(
        child: SafeArea(
          child: Consumer<FamilyProvider>(
            builder: (context, provider, _) {
              return CustomScrollView(
                physics: const BouncingScrollPhysics(),
                slivers: [
                  // App Bar
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                      child: Row(
                        children: [
                          GestureDetector(
                            onTap: () => Navigator.pop(context),
                            child: Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                color: Colors.white.withValues(alpha: 0.06),
                                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                              ),
                              child: const Icon(Icons.arrow_back_rounded, color: Colors.white70, size: 20),
                            ),
                          ),
                          const SizedBox(width: 14),
                          GlowIcon(icon: Icons.emoji_events_rounded, color: const Color(0xFFFFD700), size: 26),
                          const SizedBox(width: 10),
                          NeonText(text: 'Badges & Recompenses', fontSize: 20, fontWeight: FontWeight.w800, color: Colors.white, glowIntensity: 0.2),
                          const Spacer(),
                          GestureDetector(
                            onTap: () => _showBadgeInfo(context),
                            child: Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white.withValues(alpha: 0.06),
                              ),
                              child: Icon(Icons.info_outline_rounded, color: primary, size: 20),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  if (provider.children.isEmpty)
                    SliverFillRemaining(
                      child: Center(child: NeonText(text: 'Ajoutez des enfants pour voir les badges', fontSize: 16, color: Colors.grey)),
                    )
                  else ...[
                    // All badges grid
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                        child: NeonText(text: 'Tous les badges', fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white, glowIntensity: 0.15),
                      ),
                    ),
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      sliver: SliverGrid(
                        delegate: SliverChildBuilderDelegate(
                          (_, i) {
                            final badge = BadgeModel.defaultBadges[i];
                            return TweenAnimationBuilder<double>(
                              tween: Tween(begin: 0.0, end: 1.0),
                              duration: Duration(milliseconds: 400 + i * 100),
                              curve: Curves.easeOutBack,
                              builder: (_, v, child) => Opacity(
                                opacity: v.clamp(0.0, 1.0),
                                child: Transform.scale(scale: 0.8 + 0.2 * v, child: child),
                              ),
                              child: Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      const Color(0xFFFFD700).withValues(alpha: 0.08),
                                      const Color(0xFFFF8F00).withValues(alpha: 0.03),
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(18),
                                  border: Border.all(color: const Color(0xFFFFD700).withValues(alpha: 0.15)),
                                  boxShadow: [BoxShadow(color: const Color(0xFFFFD700).withValues(alpha: 0.05), blurRadius: 8)],
                                ),
                                padding: const EdgeInsets.all(10),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(_badgeEmojis[badge.icon] ?? '\u{2B50}', style: const TextStyle(fontSize: 32)),
                                    const SizedBox(height: 6),
                                    Text(
                                      badge.name,
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 4),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFFFD700).withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: const Color(0xFFFFD700).withValues(alpha: 0.2)),
                                      ),
                                      child: Text(
                                        '${badge.requiredPoints} pts',
                                        style: const TextStyle(fontSize: 10, color: Color(0xFFFFD700), fontWeight: FontWeight.w700),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                          childCount: BadgeModel.defaultBadges.length,
                        ),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          childAspectRatio: 0.75,
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
                        ),
                      ),
                    ),

                    // Per child badges
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
                        child: NeonText(text: 'Progression par enfant', fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white, glowIntensity: 0.15),
                      ),
                    ),
                    SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (_, index) {
                          final child = provider.children[index];
                          final earned = provider.getBadgesForChild(child);
                          return TweenAnimationBuilder<double>(
                            tween: Tween(begin: 0.0, end: 1.0),
                            duration: Duration(milliseconds: 500 + index * 150),
                            curve: Curves.easeOut,
                            builder: (_, v, w) => Opacity(
                              opacity: v.clamp(0.0, 1.0),
                              child: Transform.translate(offset: Offset(0, 20 * (1 - v)), child: w),
                            ),
                            child: GlassCard(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        width: 42,
                                        height: 42,
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(colors: [primary, primary.withValues(alpha: 0.5)]),
                                          borderRadius: BorderRadius.circular(12),
                                          boxShadow: [BoxShadow(color: primary.withValues(alpha: 0.2), blurRadius: 8)],
                                        ),
                                        child: Center(child: Text(child.avatar.isEmpty ? '\u{1F466}' : child.avatar, style: const TextStyle(fontSize: 22))),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(child.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white)),
                                            Text(
                                              '${earned.length}/${BadgeModel.defaultBadges.length} badges - ${child.levelTitle}',
                                              style: TextStyle(color: Colors.grey[500], fontSize: 12),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: primary.withValues(alpha: 0.12),
                                          borderRadius: BorderRadius.circular(10),
                                          border: Border.all(color: primary.withValues(alpha: 0.2)),
                                        ),
                                        child: NeonText(text: '${child.points} pts', fontSize: 13, fontWeight: FontWeight.w700, color: primary, glowIntensity: 0.3),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  TweenAnimationBuilder<double>(
                                    tween: Tween(begin: 0.0, end: earned.length / BadgeModel.defaultBadges.length),
                                    duration: const Duration(milliseconds: 800),
                                    curve: Curves.easeOutCubic,
                                    builder: (_, v, __) => ClipRRect(
                                      borderRadius: BorderRadius.circular(4),
                                      child: Stack(
                                        children: [
                                          LinearProgressIndicator(
                                            value: v,
                                            minHeight: 6,
                                            backgroundColor: Colors.white.withValues(alpha: 0.06),
                                            valueColor: const AlwaysStoppedAnimation(Color(0xFFFFD700)),
                                          ),
                                          Positioned.fill(
                                            child: FractionallySizedBox(
                                              widthFactor: v.clamp(0.0, 1.0),
                                              alignment: Alignment.centerLeft,
                                              child: Container(
                                                decoration: BoxDecoration(
                                                  borderRadius: BorderRadius.circular(4),
                                                  boxShadow: [BoxShadow(color: const Color(0xFFFFD700).withValues(alpha: 0.3), blurRadius: 6)],
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Wrap(
                                    spacing: 6,
                                    runSpacing: 6,
                                    children: BadgeModel.defaultBadges.map((b) {
                                      final has = child.badgeIds.contains(b.id);
                                      return AnimatedContainer(
                                        duration: const Duration(milliseconds: 300),
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: has
                                              ? const Color(0xFFFFD700).withValues(alpha: 0.12)
                                              : Colors.white.withValues(alpha: 0.04),
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(
                                            color: has ? const Color(0xFFFFD700).withValues(alpha: 0.3) : Colors.white.withValues(alpha: 0.06),
                                          ),
                                          boxShadow: has
                                              ? [BoxShadow(color: const Color(0xFFFFD700).withValues(alpha: 0.1), blurRadius: 6)]
                                              : null,
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(_badgeEmojis[b.icon] ?? '\u{2B50}', style: TextStyle(fontSize: has ? 14 : 12)),
                                            const SizedBox(width: 4),
                                            Text(
                                              b.name,
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: has ? const Color(0xFFFFD700) : Colors.grey[600],
                                                fontWeight: has ? FontWeight.bold : FontWeight.normal,
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                        childCount: provider.children.length,
                      ),
                    ),
                    const SliverToBoxAdapter(child: SizedBox(height: 40)),
                  ],
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  void _showBadgeInfo(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0D1B2A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            const GlowIcon(icon: Icons.emoji_events_rounded, color: Color(0xFFFFD700)),
            const SizedBox(width: 8),
            const NeonText(text: 'Systeme de badges', fontSize: 18, color: Colors.white),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Les badges sont debloques automatiquement.', style: TextStyle(color: Colors.white70)),
              const SizedBox(height: 16),
              ...BadgeModel.defaultBadges.map((b) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    Text(_badgeEmojis[b.icon] ?? '\u{2B50}', style: const TextStyle(fontSize: 20)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(b.name, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                          Text(b.description, style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                        ],
                      ),
                    ),
                    NeonText(text: '${b.requiredPoints} pts', fontSize: 12, fontWeight: FontWeight.w700, color: const Color(0xFFFFD700)),
                  ],
                ),
              )),
            ],
          ),
        ),
        actions: [
          FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('Compris !')),
        ],
      ),
    );
  }
}
