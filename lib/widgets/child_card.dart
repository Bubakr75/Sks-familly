import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/child_model.dart';
import 'glass_card.dart';

class ChildCard extends StatefulWidget {
  final ChildModel child;
  final int rank;
  final VoidCallback? onTap;
  final VoidCallback? onAddPoints;
  final VoidCallback? onRemovePoints;
  final VoidCallback? onViewNotes;
  final VoidCallback? onViewBadges;

  const ChildCard({
    super.key,
    required this.child,
    this.rank = 0,
    this.onTap,
    this.onAddPoints,
    this.onRemovePoints,
    this.onViewNotes,
    this.onViewBadges,
  });

  @override
  State<ChildCard> createState() => _ChildCardState();
}

class _ChildCardState extends State<ChildCard> with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _borderController;
  late AnimationController _crownController;
  late AnimationController _tiltController;
  late AnimationController _pressController;

  // Parallaxe 3D
  double _rotateX = 0.0;
  double _rotateY = 0.0;
  bool _isPressed = false;
  bool _showMenu = false;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1800))..repeat(reverse: true);
    _borderController = AnimationController(vsync: this, duration: const Duration(milliseconds: 3000))..repeat();
    _crownController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..repeat(reverse: true);
    _tiltController = AnimationController(vsync: this, duration: const Duration(milliseconds: 150));
    _pressController = AnimationController(vsync: this, duration: const Duration(milliseconds: 200));
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _borderController.dispose();
    _crownController.dispose();
    _tiltController.dispose();
    _pressController.dispose();
    super.dispose();
  }

  Color get _rankPrimary {
    if (widget.rank == 0) return const Color(0xFFFFD700);
    if (widget.rank == 1) return const Color(0xFFC0C0C0);
    if (widget.rank == 2) return const Color(0xFFCD7F32);
    return Theme.of(context).colorScheme.primary;
  }

  Color get _rankSecondary {
    if (widget.rank == 0) return const Color(0xFFFFA000);
    if (widget.rank == 1) return const Color(0xFF9E9E9E);
    if (widget.rank == 2) return const Color(0xFF8D5524);
    return Theme.of(context).colorScheme.primary.withValues(alpha: 0.7);
  }

  bool get _hasValidPhoto {
    final p = widget.child.photoBase64;
    return p != null && p.isNotEmpty && p.length > 100;
  }

  void _onPanUpdate(DragUpdateDetails details) {
    final size = context.size;
    if (size == null) return;
    setState(() {
      _rotateY = ((details.localPosition.dx - size.width / 2) / size.width) * 0.15;
      _rotateX = -((details.localPosition.dy - size.height / 2) / size.height) * 0.15;
    });
  }

  void _onPanEnd(DragEndDetails details) {
    setState(() {
      _rotateX = 0;
      _rotateY = 0;
    });
  }

  void _onLongPress() {
    HapticFeedback.heavyImpact();
    setState(() => _showMenu = true);
  }

  void _hideMenu() {
    setState(() => _showMenu = false);
  }

  void _onMenuAction(VoidCallback? action) {
    HapticFeedback.lightImpact();
    _hideMenu();
    if (action != null) action();
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
            onTap: _showMenu ? _hideMenu : widget.onTap,
            onLongPress: _onLongPress,
            onPanUpdate: _showMenu ? null : _onPanUpdate,
            onPanEnd: _showMenu ? null : _onPanEnd,
            child: AnimatedScale(
              scale: _isPressed ? 0.97 : 1.0,
              duration: const Duration(milliseconds: 150),
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: _rotateX),
                duration: const Duration(milliseconds: 150),
                builder: (context, rx, child) {
                  return TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: _rotateY),
                    duration: const Duration(milliseconds: 150),
                    builder: (context, ry, child) {
                      return Transform(
                        alignment: Alignment.center,
                        transform: Matrix4.identity()
                          ..setEntry(3, 2, 0.001)
                          ..rotateX(rx)
                          ..rotateY(ry),
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            // Carte principale
                            Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(22),
                                gradient: isTop3
                                    ? SweepGradient(
                                        center: Alignment.center,
                                        startAngle: borderAngle,
                                        endAngle: borderAngle + pi * 2,
                                        colors: [
                                          _rankPrimary,
                                          _rankPrimary.withValues(alpha: 0.3),
                                          _rankSecondary,
                                          _rankPrimary.withValues(alpha: 0.3),
                                          _rankPrimary,
                                        ],
                                      )
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
                                    if (widget.onAddPoints != null && !_showMenu) ...[
                                      const SizedBox(width: 8),
                                      _buildAddButton(isDark, primary),
                                    ],
                                  ],
                                ),
                              ),
                            ),

                            // Reflet holographique 3D
                            if (isDark && (_rotateX != 0 || _rotateY != 0))
                              Positioned.fill(
                                child: Container(
                                  margin: EdgeInsets.all(isTop3 ? 2.0 : 0.0),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(20),
                                    gradient: LinearGradient(
                                      begin: Alignment(-_rotateY * 10, -_rotateX * 10),
                                      end: Alignment(_rotateY * 10, _rotateX * 10),
                                      colors: [
                                        Colors.white.withValues(alpha: 0.0),
                                        Colors.white.withValues(alpha: 0.06),
                                        Colors.white.withValues(alpha: 0.0),
                                      ],
                                    ),
                                  ),
                                ),
                              ),

                            // Menu contextuel
                            if (_showMenu)
                              Positioned(
                                top: -60,
                                left: 0,
                                right: 0,
                                child: TweenAnimationBuilder<double>(
                                  tween: Tween(begin: 0.0, end: 1.0),
                                  duration: const Duration(milliseconds: 300),
                                  curve: Curves.elasticOut,
                                  builder: (context, value, child) {
                                    return Transform.scale(
                                      scale: value,
                                      child: child,
                                    );
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(20),
                                      color: isDark ? const Color(0xFF1A1A2E).withValues(alpha: 0.95) : Colors.white.withValues(alpha: 0.95),
                                      border: Border.all(color: primary.withValues(alpha: 0.3)),
                                      boxShadow: [
                                        BoxShadow(color: primary.withValues(alpha: 0.2), blurRadius: 20, spreadRadius: -2),
                                        BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 12, offset: const Offset(0, 4)),
                                      ],
                                    ),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                      children: [
                                        _buildMenuButton(
                                          icon: Icons.add_circle_rounded,
                                          label: 'Bonus',
                                          color: const Color(0xFF00E676),
                                          onTap: () => _onMenuAction(widget.onAddPoints),
                                        ),
                                        _buildMenuButton(
                                          icon: Icons.remove_circle_rounded,
                                          label: 'Retirer',
                                          color: const Color(0xFFFF1744),
                                          onTap: () => _onMenuAction(widget.onRemovePoints),
                                        ),
                                        _buildMenuButton(
                                          icon: Icons.sticky_note_2_rounded,
                                          label: 'Notes',
                                          color: const Color(0xFFFFD740),
                                          onTap: () => _onMenuAction(widget.onViewNotes),
                                        ),
                                        _buildMenuButton(
                                          icon: Icons.emoji_events_rounded,
                                          label: 'Badges',
                                          color: const Color(0xFF448AFF),
                                          onTap: () => _onMenuAction(widget.onViewBadges),
                                        ),
                                        _buildMenuButton(
                                          icon: Icons.person_rounded,
                                          label: 'Profil',
                                          color: primary,
                                          onTap: () => _onMenuAction(widget.onTap),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildMenuButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withValues(alpha: 0.15),
              border: Border.all(color: color.withValues(alpha: 0.4)),
              boxShadow: [BoxShadow(color: color.withValues(alpha: 0.2), blurRadius: 8)],
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: color)),
        ],
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
          width: 62,
          height: 62,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isTop3
                  ? [_rankPrimary.withValues(alpha: 0.5), _rankSecondary.withValues(alpha: 0.3)]
                  : isDark
                      ? [primary.withValues(alpha: 0.3), primary.withValues(alpha: 0.1)]
                      : [primary.withValues(alpha: 0.15), primary.withValues(alpha: 0.05)],
            ),
            border: Border.all(
              color: isTop3 ? _rankPrimary.withValues(alpha: 0.6) : primary.withValues(alpha: 0.2),
              width: isTop3 ? 2.5 : 1.5,
            ),
          ),
          child: ClipOval(
            child: _hasValidPhoto
                ? Image.memory(
                    base64Decode(widget.child.photoBase64!),
                    width: 62,
                    height: 62,
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
                top: -14 + bounce,
                left: 0,
                right: 0,
                child: Center(
                  child: Text('\u{1F451}', style: TextStyle(fontSize: 20, shadows: isDark ? [const Shadow(color: Color(0x80FFD700), blurRadius: 8)] : null)),
                ),
              );
            },
          ),
        if (widget.rank == 1 || widget.rank == 2)
          Positioned(
            top: -6,
            right: -6,
            child: Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(colors: [_rankPrimary, _rankSecondary]),
                boxShadow: isDark
                    ? [BoxShadow(color: _rankPrimary.withValues(alpha: 0.4), blurRadius: 6)]
                    : [BoxShadow(color: _rankPrimary.withValues(alpha: 0.3), blurRadius: 4)],
              ),
              child: Center(
                child: Text('${widget.rank + 1}', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w900)),
              ),
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
          child: Text(
            widget.child.name,
            style: TextStyle(
              fontSize: isTop3 ? 18 : 16,
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.white : Colors.black87,
              shadows: isTop3 && isDark ? [Shadow(color: _rankPrimary.withValues(alpha: 0.3), blurRadius: 8)] : null,
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            gradient: LinearGradient(
              colors: isTop3
                  ? [_rankPrimary.withValues(alpha: 0.2), _rankSecondary.withValues(alpha: 0.1)]
                  : [primary.withValues(alpha: 0.12), primary.withValues(alpha: 0.06)],
            ),
            border: Border.all(
              color: isTop3 ? _rankPrimary.withValues(alpha: 0.3) : primary.withValues(alpha: 0.2),
            ),
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
      case 'Champion':
        return Icons.military_tech_rounded;
      case 'Expert':
        return Icons.workspace_premium_rounded;
      default:
        return Icons.stars_rounded;
    }
  }

  Widget _buildProgressBar(bool isDark, Color primary) {
    final progress = widget.child.levelProgress.clamp(0.0, 1.0);
    final isTop3 = widget.rank < 3;
    return ClipRRect(
      borderRadius: BorderRadius.circular(5),
      child: Stack(
        children: [
          Container(
            height: 8,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(5),
              color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.grey.withValues(alpha: 0.15),
            ),
          ),
          FractionallySizedBox(
            widthFactor: progress,
            child: Container(
              height: 8,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(5),
                gradient: LinearGradient(colors: isTop3 ? [_rankSecondary, _rankPrimary] : [primary.withValues(alpha: 0.7), primary]),
                boxShadow: isDark
                    ? [BoxShadow(color: (isTop3 ? _rankPrimary : primary).withValues(alpha: 0.5), blurRadius: 8, offset: const Offset(0, 1))]
                    : null,
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
    final pts = widget.child.points;
    final nextPts = widget.child.nextLevelPoints;
    final badgeCount = widget.child.badgeIds.length;
    return Row(
      children: [
        Icon(Icons.star_rounded, size: 17, color: const Color(0xFFFFD700), shadows: isDark ? [const Shadow(color: Color(0x80FFD700), blurRadius: 8)] : null),
        const SizedBox(width: 4),
        NeonText(text: '$pts pts', fontSize: 14, fontWeight: FontWeight.w800, color: pointColor, glowIntensity: isDark ? 0.3 : 0.0),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(6), color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.withValues(alpha: 0.08)),
          child: Text('$pts/$nextPts', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey[500])),
        ),
        if (badgeCount > 0) ...[
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(6), color: Colors.amber.withValues(alpha: isDark ? 0.12 : 0.08)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.emoji_events_rounded, size: 13, color: Colors.amber[600]),
              const SizedBox(width: 3),
              Text('$badgeCount', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.amber[600])),
            ]),
          ),
        ],
      ],
    );
  }

  Widget _buildAddButton(bool isDark, Color primary) {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [primary, primary.withValues(alpha: 0.7)],
        ),
        boxShadow: isDark
            ? [BoxShadow(color: primary.withValues(alpha: 0.4), blurRadius: 12)]
            : [BoxShadow(color: primary.withValues(alpha: 0.3), blurRadius: 8)],
      ),
      child: IconButton(
        icon: const Icon(Icons.add_rounded, color: Colors.white, size: 26),
        onPressed: widget.onAddPoints,
        splashRadius: 24,
      ),
    );
  }
}
