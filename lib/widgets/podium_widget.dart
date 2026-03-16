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

class _PodiumWidgetState extends State<PodiumWidget> with TickerProviderStateMixin {
  late AnimationController _shimmerController;
  late AnimationController _pulseController;
  late AnimationController _crownController;
  late AnimationController _rotateController;
  late AnimationController _particleController;

  @override
  void initState() {
    super.initState();
    _shimmerController = AnimationController(vsync: this, duration: const Duration(seconds: 3))..repeat();
    _pulseController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500))..repeat(reverse: true);
    _crownController = AnimationController(vsync: this, duration: const Duration(milliseconds: 2000))..repeat(reverse: true);
    _rotateController = AnimationController(vsync: this, duration: const Duration(seconds: 6))..repeat();
    _particleController = AnimationController(vsync: this, duration: const Duration(seconds: 4))..repeat();
  }

  @override
  void dispose() {
    _shimmerController.dispose();
    _pulseController.dispose();
    _crownController.dispose();
    _rotateController.dispose();
    _particleController.dispose();
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
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 12),
      glowColor: primary,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              GlowIcon(icon: Icons.emoji_events_rounded, color: const Color(0xFFFFD700), size: 28),
              const SizedBox(width: 10),
              NeonText(text: 'CLASSEMENT', fontSize: 20, fontWeight: FontWeight.w900, color: Colors.white, glowIntensity: 0.3),
            ],
          ),
          const SizedBox(height: 24),
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
        const SizedBox(width: 6),
        Expanded(child: _podiumPlace(top3[0], 1, 105, const Color(0xFFFFD700), primary)),
        const SizedBox(width: 6),
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
        const SizedBox(width: 12),
        Expanded(child: _podiumPlace(top2[0], 1, 105, const Color(0xFFFFD700), primary)),
      ],
    );
  }

  Widget _buildOnePodium(ChildModel child, Color primary) {
    return _podiumPlace(child, 1, 105, const Color(0xFFFFD700), primary);
  }

  bool _hasValidPhoto(ChildModel child) {
    final p = child.photoBase64;
    return p != null && p.isNotEmpty && p.length > 100;
  }

  Widget _podiumPlace(ChildModel child, int place, double height, Color medalColor, Color primary) {
    final emoji = child.avatar.isNotEmpty ? child.avatar : '\u{1F466}';
    final isFirst = place == 1;
    final avatarSize = isFirst ? 92.0 : 68.0;
    final innerSize = avatarSize - 8;

    return AnimatedBuilder(
      animation: Listenable.merge([_shimmerController, _pulseController, _crownController, _rotateController, _particleController]),
      builder: (context, _) {
        final shimmer = sin(_shimmerController.value * 2 * pi) * 0.3 + 0.7;
        final pulse = _pulseController.value;
        final crownBounce = sin(_crownController.value * pi) * 6;
        final rotateAngle = _rotateController.value * 2 * pi;

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Couronne animee pour le 1er
            if (isFirst) ...[
              Transform.translate(
                offset: Offset(0, crownBounce),
                child: ShaderMask(
                  shaderCallback: (bounds) => LinearGradient(
                    colors: [
                      const Color(0xFFFFD700),
                      const Color(0xFFFFF176),
                      const Color(0xFFFFD700),
                    ],
                    stops: [
                      (_shimmerController.value - 0.3).clamp(0.0, 1.0),
                      _shimmerController.value.clamp(0.0, 1.0),
                      (_shimmerController.value + 0.3).clamp(0.0, 1.0),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ).createShader(bounds),
                  child: const Text('\u{1F451}', style: TextStyle(fontSize: 30)),
                ),
              ),
              const SizedBox(height: 2),
            ],

            // Avatar avec effets 3D
            Stack(
              alignment: Alignment.center,
              children: [
                // Particules dorees pour le 1er
                if (isFirst)
                  ...List.generate(6, (i) {
                    final angle = (rotateAngle + i * pi / 3);
                    final radius = avatarSize / 2 + 12 + sin(_particleController.value * 2 * pi + i) * 6;
                    final particleX = cos(angle) * radius;
                    final particleY = sin(angle) * radius;
                    final opacity = (sin(_particleController.value * 2 * pi + i * 1.5) * 0.5 + 0.5).clamp(0.0, 1.0);
                    return Transform.translate(
                      offset: Offset(particleX, particleY),
                      child: Opacity(
                        opacity: opacity,
                        child: Container(
                          width: 4 + sin(_particleController.value * pi + i) * 2,
                          height: 4 + sin(_particleController.value * pi + i) * 2,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: const Color(0xFFFFD700),
                            boxShadow: [BoxShadow(color: const Color(0xFFFFD700).withValues(alpha: 0.6), blurRadius: 4)],
                          ),
                        ),
                      ),
                    );
                  }),

                // Anneau lumineux rotatif pour le 1er
                if (isFirst)
                  Transform.rotate(
                    angle: rotateAngle,
                    child: Container(
                      width: avatarSize + 16,
                      height: avatarSize + 16,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: SweepGradient(
                          colors: [
                            medalColor.withValues(alpha: 0.0),
                            medalColor.withValues(alpha: 0.6),
                            medalColor.withValues(alpha: 0.0),
                            medalColor.withValues(alpha: 0.3),
                            medalColor.withValues(alpha: 0.0),
                          ],
                        ),
                      ),
                    ),
                  ),

                // Photo/Avatar principal avec effet 3D
                Transform(
                  alignment: Alignment.center,
                  transform: isFirst
                      ? (Matrix4.identity()
                        ..setEntry(3, 2, 0.002)
                        ..rotateY(sin(_shimmerController.value * 2 * pi) * 0.08)
                        ..rotateX(cos(_shimmerController.value * 2 * pi) * 0.05)
                        ..scale(1.0 + pulse * 0.06))
                      : Matrix4.identity(),
                  child: Container(
                    width: avatarSize,
                    height: avatarSize,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: medalColor.withValues(alpha: isFirst ? shimmer.clamp(0.0, 1.0) : 0.6),
                        width: isFirst ? 3.5 : 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: medalColor.withValues(alpha: isFirst ? 0.5 * shimmer.clamp(0.0, 1.0) : 0.2),
                          blurRadius: isFirst ? 24 + pulse * 8 : 8,
                          spreadRadius: isFirst ? 4 + pulse * 2 : 0,
                        ),
                        if (isFirst)
                          BoxShadow(
                            color: const Color(0xFFFFD700).withValues(alpha: 0.15),
                            blurRadius: 40,
                            spreadRadius: 8,
                          ),
                      ],
                    ),
                    child: ClipOval(
                      child: _hasValidPhoto(child)
                          ? Image.memory(
                              base64Decode(child.photoBase64!),
                              width: innerSize,
                              height: innerSize,
                              fit: BoxFit.cover,
                              gaplessPlayback: true,
                              errorBuilder: (_, __, ___) => _buildEmojiAvatar(emoji, innerSize, isFirst),
                            )
                          : _buildEmojiAvatar(emoji, innerSize, isFirst),
                    ),
                  ),
                ),

                // Badge medaille
                Positioned(
                  top: 0,
                  right: isFirst ? 0 : 0,
                  child: Transform.scale(
                    scale: isFirst ? 1.0 + pulse * 0.1 : 1.0,
                    child: Container(
                      width: isFirst ? 28 : 24,
                      height: isFirst ? 28 : 24,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [medalColor, medalColor.withValues(alpha: 0.7)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white.withValues(alpha: 0.9), width: 2),
                        boxShadow: [
                          BoxShadow(color: medalColor.withValues(alpha: 0.5), blurRadius: isFirst ? 10 : 6),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          '$place',
                          style: TextStyle(color: Colors.white, fontSize: isFirst ? 13 : 11, fontWeight: FontWeight.w900),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            // Nom
            SizedBox(
              width: isFirst ? 95 : 70,
              child: Text(
                child.name,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: isFirst ? 14 : 12,
                  fontWeight: FontWeight.w700,
                  shadows: isFirst
                      ? [Shadow(color: medalColor.withValues(alpha: 0.5), blurRadius: 8)]
                      : null,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 4),
            // Points
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: primary.withValues(alpha: isFirst ? 0.2 : 0.15),
                border: Border.all(color: primary.withValues(alpha: isFirst ? 0.5 : 0.3)),
                boxShadow: isFirst
                    ? [BoxShadow(color: primary.withValues(alpha: 0.2), blurRadius: 8)]
                    : null,
              ),
              child: Text(
                '${child.points} pts',
                style: TextStyle(color: primary, fontSize: isFirst ? 13 : 11, fontWeight: FontWeight.w800),
              ),
            ),
            const SizedBox(height: 8),
            // Barre podium
            Container(
              width: isFirst ? 76 : 58,
              height: height,
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.only(topLeft: Radius.circular(10), topRight: Radius.circular(10)),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    medalColor.withValues(alpha: isFirst ? 0.6 + pulse * 0.15 : 0.5),
                    medalColor.withValues(alpha: 0.15),
                  ],
                ),
                border: Border.all(color: medalColor.withValues(alpha: isFirst ? 0.6 : 0.4), width: 1),
                boxShadow: isFirst
                    ? [
                        BoxShadow(color: medalColor.withValues(alpha: 0.3), blurRadius: 16),
                        BoxShadow(color: medalColor.withValues(alpha: 0.1), blurRadius: 30, spreadRadius: 4),
                      ]
                    : null,
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      child.levelTitle,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Nv.${child.level}',
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 9),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildEmojiAvatar(String emoji, double size, bool isFirst) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withValues(alpha: 0.1),
        gradient: isFirst
            ? LinearGradient(
                colors: [
                  const Color(0xFFFFD700).withValues(alpha: 0.15),
                  Colors.white.withValues(alpha: 0.05),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : null,
      ),
      child: Center(child: Text(emoji, style: TextStyle(fontSize: isFirst ? 42 : 30))),
    );
  }
}
