import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import '../models/child_model.dart';
import 'glass_card.dart';

class PodiumWidget extends StatefulWidget {
  final List<ChildModel> children;
  const PodiumWidget({super.key, required this.children});

  @override
  State<PodiumWidget> createState() => _PodiumWidgetState();
}

class _PodiumWidgetState extends State<PodiumWidget> with SingleTickerProviderStateMixin {
  late AnimationController _shimmerController;

  @override
  void initState() {
    super.initState();
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
  }

  @override
  void dispose() {
    _shimmerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.children.isEmpty) return const SizedBox.shrink();

    final sorted = List<ChildModel>.from(widget.children);
    sorted.sort((a, b) => b.points.compareTo(a.points));
    final top3 = sorted.take(3).toList();
    final primary = Theme.of(context).colorScheme.primary;

    return GlassCard(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      glowColor: primary,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Title with glow
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              GlowIcon(icon: Icons.emoji_events_rounded, color: const Color(0xFFFFD700), size: 28),
              const SizedBox(width: 10),
              NeonText(
                text: 'CLASSEMENT',
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: Colors.white,
                glowIntensity: 0.3,
              ),
            ],
          ),
          const SizedBox(height: 24),
          // Podium
          if (top3.length >= 3)
            _buildThreePodium(top3, primary)
          else if (top3.length == 2)
            _buildTwoPodium(top3, primary)
          else
            _buildOnePodium(top3[0], primary),
        ],
      ),
    );
  }

  Widget _buildThreePodium(List<ChildModel> top3, Color primary) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(child: _podiumPlace(top3[1], 2, 75, const Color(0xFFC0C0C0), primary)),
        const SizedBox(width: 8),
        Expanded(child: _podiumPlace(top3[0], 1, 105, const Color(0xFFFFD700), primary)),
        const SizedBox(width: 8),
        Expanded(child: _podiumPlace(top3[2], 3, 55, const Color(0xFFCD7F32), primary)),
      ],
    );
  }

  Widget _buildTwoPodium(List<ChildModel> top2, Color primary) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(child: _podiumPlace(top2[1], 2, 75, const Color(0xFFC0C0C0), primary)),
        const SizedBox(width: 16),
        Expanded(child: _podiumPlace(top2[0], 1, 105, const Color(0xFFFFD700), primary)),
      ],
    );
  }

  Widget _buildOnePodium(ChildModel child, Color primary) {
    return _podiumPlace(child, 1, 105, const Color(0xFFFFD700), primary);
  }

  Widget _podiumPlace(ChildModel child, int place, double height, Color medalColor, Color primary) {
    final emoji = child.avatar.isNotEmpty ? child.avatar : '\u{1F466}';
    final isFirst = place == 1;

    return AnimatedBuilder(
      animation: _shimmerController,
      builder: (context, _) {
        final shimmer = sin(_shimmerController.value * 2 * pi) * 0.3 + 0.7;

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Avatar with glow ring
            Stack(
              alignment: Alignment.topRight,
              children: [
                Container(
                  width: isFirst ? 76 : 60,
                  height: isFirst ? 76 : 60,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: medalColor.withValues(alpha: isFirst ? shimmer.clamp(0.0, 1.0) : 0.6),
                      width: isFirst ? 3 : 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: medalColor.withValues(alpha: isFirst ? 0.4 * shimmer.clamp(0.0, 1.0) : 0.2),
                        blurRadius: isFirst ? 16 : 8,
                        spreadRadius: isFirst ? 2 : 0,
                      ),
                    ],
                  ),
                  child: child.hasPhoto
                      ? ClipOval(
                          child: Image.memory(
                            base64Decode(child.photoBase64),
                            width: isFirst ? 68 : 54,
                            height: isFirst ? 68 : 54,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => CircleAvatar(
                              radius: isFirst ? 34 : 27,
                              backgroundColor: Colors.white.withValues(alpha: 0.1),
                              child: Text(emoji, style: TextStyle(fontSize: isFirst ? 36 : 28)),
                            ),
                          ),
                        )
                      : CircleAvatar(
                          radius: isFirst ? 34 : 27,
                          backgroundColor: Colors.white.withValues(alpha: 0.1),
                          child: Text(emoji, style: TextStyle(fontSize: isFirst ? 36 : 28)),
                        ),
                ),
                // Medal badge
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [medalColor, medalColor.withValues(alpha: 0.7)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white.withValues(alpha: 0.8), width: 2),
                    boxShadow: [
                      BoxShadow(color: medalColor.withValues(alpha: 0.4), blurRadius: 6),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      '$place',
                      style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w900),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            // Name
            Text(
              child.name,
              style: TextStyle(
                color: Colors.white,
                fontSize: isFirst ? 15 : 13,
                fontWeight: FontWeight.w700,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            // Points with glow
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: primary.withValues(alpha: 0.15),
                border: Border.all(color: primary.withValues(alpha: 0.3)),
              ),
              child: Text(
                '${child.points} pts',
                style: TextStyle(
                  color: primary,
                  fontSize: isFirst ? 14 : 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(height: 8),
            // Podium bar with gradient
            Container(
              width: isFirst ? 80 : 60,
              height: height,
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(10),
                  topRight: Radius.circular(10),
                ),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    medalColor.withValues(alpha: 0.5),
                    medalColor.withValues(alpha: 0.15),
                  ],
                ),
                border: Border.all(color: medalColor.withValues(alpha: 0.4), width: 1),
                boxShadow: isFirst
                    ? [BoxShadow(color: medalColor.withValues(alpha: 0.2), blurRadius: 12)]
                    : null,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    child.levelTitle,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.9),
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Niv. ${child.level}',
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 9),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
