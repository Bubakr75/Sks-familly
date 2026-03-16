import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import '../models/child_model.dart';
import 'glass_card.dart';

class ChildCard extends StatefulWidget {
  final ChildModel child;
  final int rank;
  final VoidCallback? onTap;
  final VoidCallback? onAddPoints;

  const ChildCard({
    super.key,
    required this.child,
    this.rank = 0,
    this.onTap,
    this.onAddPoints,
  });

  @override
  State<ChildCard> createState() => _ChildCardState();
}

class _ChildCardState extends State<ChildCard> with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _borderController;
  late AnimationController _crownController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1800))..repeat(reverse: true);
    _borderController = AnimationController(vsync: this, duration: const Duration(milliseconds: 3000))..repeat();
    _crownController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _borderController.dispose();
    _crownController.dispose();
    super.dispose();
  }

  static const _rankData = [
    {'icon': '\u{1F451}', 'label': '1er', 'colors': [Color(0xFFFFD700), Color(0xFFFFA000)]},
    {'icon': '\u{1F948}', 'label': '2e', 'colors': [Color(0xFFC0C0C0), Color(0xFF9E9E9E)]},
    {'icon': '\u{1F949}', 'label': '3e', 'colors': [Color(0xFFCD7F32), Color(0xFF8D5524)]},
  ];

  Color get _rankPrimary {
    if (widget.rank < 3) return (_rankData[widget.rank]['colors'] as List<Color>)[0];
    return Theme.of(context).colorScheme.primary;
  }

  Color get _rankSecondary {
    if (widget.rank < 3) return (_rankData[widget.rank]['colors'] as List<Color>)[1];
    return Theme.of(context).colorScheme.primary.withValues(alpha: 0.7);
  }

  bool get _hasValidPhoto {
    return widget.child.photoBase64 != null && widget.child.photoBase64!.isNotEmpty && widget.child.photoBase64!.length > 100;
  }

  @override
  Widget build(BuildContext context) {
    final emoji = widget.child.avatar.isNotEmpty ? widget.child.avatar : '\u{1F466}';
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    final isDark = theme.brightness == Brightness.dark;
    final isTop3 = widget.rank < 3;
    final isFirst = widget.rank == 0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      child: AnimatedBuilder(
        animation: Listenable.merge([_pulseController, _borderController]),
        builder: (context, _) {
          final pulseVal = _pulseController.value;
          final borderAngle = _borderController.value * 2 * pi;

          return GestureDetector(
            onTap: widget.onTap,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(22),
                gradient: isTop3
                    ? SweepGradient(center: Alignment.center, startAngle: borderAngle, endAngle: borderAngle + pi * 2,
                        colors: [_rankPrimary, _rankPrimary.withValues(alpha: 0.3), _rankSecondary, _rankPrimary.withValues(alpha: 0.3), _rankPrimary])
                    : null,
                boxShadow: isFirst && isDark
                    ? [BoxShadow(color: _rankPrimary.withValues(alpha: 0.15 + pulseVal * 0.15), blurRadius: 20 + pulseVal * 10, spreadRadius: -2)]
                    : isTop3 && isDark
                        ? [BoxShadow(color: _rankPrimary.withValues(alpha: 0.12), blurRadius: 12, spreadRadius: -2)]
                        : null,
              ),
              child: Container(
                margin: EdgeInsets.all(isTop3 ? 2.0 : 0.0),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  color: isDark ? Colors.black.withValues(alpha: 0.6) : Colors.white.withValues(alpha: 0.92),
                  border: isTop3 ? null : Border.all(color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.grey.withValues(alpha: 0.15)),
                ),
                child: Row(
                  children: [
                    _buildAvatar(emoji, isDark, primary, pulseVal),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildNameRow(isDark, primary),
                          const SizedBox(height: 10),
                          _buildProgressBar(isDark, primary),
                          const SizedBox(height: 8),
                          _buildPointsRow(isDark, primary),
                        ],
                      ),
                    ),
                    if (widget.onAddPoints != null) ...[
                      const SizedBox(width: 8),
                      _buildAddButton(isDark, primary),
                    ],
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildAvatar(String emoji, bool isDark, Color primary, double pulseVal) {
    final isFirst = widget.rank == 0;
    final isTop3 = widget.rank < 3;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        if (isFirst && isDark)
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [BoxShadow(color: _rankPrimary.withValues(alpha: 0.2 + pulseVal * 0.2), blurRadius: 16 + pulseVal * 8, spreadRadius: 2)],
              ),
            ),
          ),
        Container(
          width: 62, height: 62,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topLeft, end: Alignment.bottomRight,
              colors: isTop3
                  ? [_rankPrimary.withValues(alpha: 0.5), _rankSecondary.withValues(alpha: 0.3)]
                  : isDark
                      ? [primary.withValues(alpha: 0.3), primary.withValues(alpha: 0.1)]
                      : [primary.withValues(alpha: 0.15), primary.withValues(alpha: 0.05)],
            ),
            border: Border.all(color: isTop3 ? _rankPrimary.withValues(alpha: 0.6) : primary.withValues(alpha: 0.2), width: isTop3 ? 2.5 : 1.5),
          ),
          child: ClipOval(
            child: _hasValidPhoto
                ? Image.memory(
                    base64Decode(widget.child.photoBase64!),
                    width: 62, height: 62,
                    fit: BoxFit.cover,
                    gaplessPlayback: true,
                    errorBuilder: (_, __, ___) => Center(child: Text(emoji, style: const TextStyle(fontSize: 30))),
                  )
                : Center(child: Text(emoji, style: const TextStyle(fontSize: 30))),
          ),
        ),
        if (isFirst)
          AnimatedBuilder(
            animation: _crownController,
            builder: (_, __) {
              final bounce = sin(_crownController.value * pi) * 3;
              return Positioned(
                top: -14 + bounce, left: 0, right: 0,
                child: Center(child: Text('\u{1F451}', style: TextStyle(fontSize: 20, shadows: isDark ? [const Shadow(color: Color(0x80FFD700), blurRadius: 8)] : null))),
              );
            },
          ),
        if (widget.rank == 1 || widget.rank == 2)
          Positioned(
            top: -6, right: -6,
            child: Container(
              width: 24, height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(colors: [_rankPrimary, _rankSecondary]),
                boxShadow: isDark ? [BoxShadow(color: _rankPrimary.withValues(alpha: 0.4), blurRadius: 6)] : [BoxShadow(color: _rankPrimary.withValues(alpha: 0.3), blurRadius: 4)],
              ),
              child: Center(child: Text('${widget.rank + 1}', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w900))),
            ),
          ),
      ],
    );
  }

  Widget _buildNameRow(bool isDark, Color primary) {
    final isTop3 = widget.rank < 3;
    return Row(
      children: [
        Expanded(
          child: Text(widget.child.name, style: TextStyle(fontSize: isTop3 ? 18 : 16, fontWeight: FontWeight.w800, color: isDark ? Colors.white : Colors.black87,
            shadows: isTop3 && isDark ? [Shadow(color: _rankPrimary.withValues(alpha: 0.3), blurRadius: 8)] : null)),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            gradient: LinearGradient(colors: isTop3 ? [_rankPrimary.withValues(alpha: 0.2), _rankSecondary.withValues(alpha: 0.1)] : [primary.withValues(alpha: 0.12), primary.withValues(alpha: 0.06)]),
            border: Border.all(color: isTop3 ? _rankPrimary.withValues(alpha: 0.3) : primary.withValues(alpha: 0.2)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(_getLevelIcon(), size: 12, color: isTop3 ? _rankPrimary : primary),
              const SizedBox(width: 4),
              Text(widget.child.levelTitle, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: isTop3 ? _rankPrimary : primary)),
            ],
          ),
        ),
      ],
    );
  }

  IconData _getLevelIcon() {
    switch (widget.child.levelTitle) {
      case 'Champion': return Icons.military_tech_rounded;
      case 'Expert': return Icons.workspace_premium_rounded;
      default: return Icons.stars_rounded;
    }
  }

  Widget _buildProgressBar(bool isDark, Color primary) {
    final progress = widget.child.levelProgress.clamp(0.0, 1.0);
    final isTop3 = widget.rank < 3;
    return ClipRRect(
      borderRadius: BorderRadius.circular(5),
      child: Stack(
        children: [
          Container(height: 8, decoration: BoxDecoration(borderRadius: BorderRadius.circular(5), color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.grey.withValues(alpha: 0.15))),
          FractionallySizedBox(
            widthFactor: progress,
            child: Container(
              height: 8,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(5),
                gradient: LinearGradient(colors: isTop3 ? [_rankSecondary, _rankPrimary] : [primary.withValues(alpha: 0.7), primary]),
                boxShadow: isDark ? [BoxShadow(color: (isTop3 ? _rankPrimary : primary).withValues(alpha: 0.5), blurRadius: 8, offset: const Offset(0, 1))] : null,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPointsRow(bool isDark, Color primary) {
    final isTop3 = widget.rank < 3;
    final pointColor = isTop3 ? _rankPrimary : primary;
    return Row(
      children: [
        Icon(Icons.star_rounded, size: 17, color: const Color(0xFFFFD700), shadows: isDark ? [const Shadow(color: Color(0x80FFD700), blurRadius: 8)] : null),
        const SizedBox(width: 4),
        NeonText(text: '${widget.child.points} pts', fontSize: 14, fontWeight: FontWeight.w800, color: pointColor, glowIntensity: isDark ? 0.3 : 0.0),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(6), color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.withValues(alpha: 0.08)),
          child: Text('${widget.child.points}/${<span class="cursor">█</span>
