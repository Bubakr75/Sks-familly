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

class _PodiumWidgetState extends State<PodiumWidget>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  late AnimationController _shimmerCtrl;
  late AnimationController _pulseCtrl;
  late AnimationController _crownCtrl;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _shimmerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();

    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _crownCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.hidden) {
      _shimmerCtrl.stop();
      _pulseCtrl.stop();
      _crownCtrl.stop();
    } else if (state == AppLifecycleState.resumed) {
      _shimmerCtrl.repeat();
      _pulseCtrl.repeat(reverse: true);
      _crownCtrl.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _shimmerCtrl.dispose();
    _pulseCtrl.dispose();
    _crownCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.children.isEmpty) return const SizedBox.shrink();

    final sorted = List<ChildModel>.from(widget.children)
      ..sort((a, b) => b.points.compareTo(a.points));
    final top = sorted.take(3).toList();
    final theme = Theme.of(context);

    return GlassCard(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedBuilder(
                animation: _crownCtrl,
                builder: (context, child) {
                  final bounce = sin(_crownCtrl.value * pi) * 4;
                  return Transform.translate(
                    offset: Offset(0, -bounce),
                    child: const Text('👑', style: TextStyle(fontSize: 24)),
                  );
                },
              ),
              const SizedBox(width: 8),
              Text(
                'Podium',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (top.length >= 3)
            _buildThreePodium(top, theme)
          else if (top.length == 2)
            _buildTwoPodium(top, theme)
          else
            _buildOnePodium(top.first, theme),
        ],
      ),
    );
  }

  Widget _buildThreePodium(List<ChildModel> top, ThemeData theme) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(child: _podiumPlace(top[1], 2, theme, 100)),
        Expanded(child: _podiumPlace(top[0], 1, theme, 130)),
        Expanded(child: _podiumPlace(top[2], 3, theme, 80)),
      ],
    );
  }

  Widget _buildTwoPodium(List<ChildModel> top, ThemeData theme) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(child: _podiumPlace(top[0], 1, theme, 130)),
        const SizedBox(width: 16),
        Expanded(child: _podiumPlace(top[1], 2, theme, 100)),
      ],
    );
  }

  Widget _buildOnePodium(ChildModel child, ThemeData theme) {
    return _podiumPlace(child, 1, theme, 130);
  }

  Widget _podiumPlace(ChildModel child, int rank, ThemeData theme, double height) {
    final colors = _rankColors(rank);
    final primaryColor = colors[0];
    final secondaryColor = colors[1];

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (rank == 1)
          AnimatedBuilder(
            animation: _crownCtrl,
            builder: (context, _) {
              final bounce = sin(_crownCtrl.value * pi) * 3;
              return Transform.translate(
                offset: Offset(0, -bounce),
                child: const Text('👑', style: TextStyle(fontSize: 28)),
              );
            },
          ),
        const SizedBox(height: 4),
        AnimatedBuilder(
          animation: _pulseCtrl,
          builder: (context, child) {
            final scale = rank == 1 ? 1.0 + _pulseCtrl.value * 0.05 : 1.0;
            return Transform.scale(
              scale: scale,
              child: child,
            );
          },
          child: _buildAvatar(child, rank, primaryColor, secondaryColor),
        ),
        const SizedBox(height: 6),
        Text(
          child.name,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: primaryColor,
          ),
          overflow: TextOverflow.ellipsis,
          maxLines: 1,
        ),
        Text(
          '${child.points} pts',
          style: theme.textTheme.bodySmall?.copyWith(
            color: secondaryColor,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        AnimatedBuilder(
          animation: _shimmerCtrl,
          builder: (context, _) {
            return Container(
              height: height,
              width: double.infinity,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    primaryColor.withValues(alpha: 0.8),
                    secondaryColor.withValues(alpha: 0.4),
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: primaryColor.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  '$rank',
                  style: TextStyle(
                    fontSize: rank == 1 ? 36 : 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildAvatar(ChildModel child, int rank, Color primary, Color secondary) {
    final size = rank == 1 ? 64.0 : 52.0;

    Widget avatarContent;
    if (_hasValidPhoto(child)) {
      avatarContent = ClipOval(
        child: Image.memory(
          base64Decode(child.photoBase64!),
          width: size,
          height: size,
          fit: BoxFit.cover,
          gaplessPlayback: true,
          errorBuilder: (_, __, ___) => _emojiAvatar(child, size),
        ),
      );
    } else {
      avatarContent = _emojiAvatar(child, size);
    }

    return Container(
      width: size + 6,
      height: size + 6,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: primary, width: 3),
        boxShadow: [
          BoxShadow(
            color: primary.withValues(alpha: 0.4),
            blurRadius: 12,
          ),
        ],
      ),
      child: ClipOval(child: avatarContent),
    );
  }

  Widget _emojiAvatar(ChildModel child, double size) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: Color(0xFF1A1A2E),
      ),
      child: Center(
        child: Text(
          child.avatar.isNotEmpty ? child.avatar : '👤',
          style: TextStyle(fontSize: size * 0.5),
        ),
      ),
    );
  }

  bool _hasValidPhoto(ChildModel child) {
    if (child.photoBase64 == null || child.photoBase64!.isEmpty) return false;
    if (child.photoBase64!.length < 100) return false;
    try {
      base64Decode(child.photoBase64!);
      return true;
    } catch (_) {
      return false;
    }
  }

  List<Color> _rankColors(int rank) {
    switch (rank) {
      case 1:
        return [const Color(0xFFFFD700), const Color(0xFFFFA000)];
      case 2:
        return [const Color(0xFFC0C0C0), const Color(0xFF9E9E9E)];
      case 3:
        return [const Color(0xFFCD7F32), const Color(0xFF8D6E63)];
      default:
        return [Colors.blueGrey, Colors.grey];
    }
  }
}
