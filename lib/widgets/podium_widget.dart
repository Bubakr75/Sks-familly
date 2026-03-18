import 'dart:convert';
import 'package:flutter/material.dart';
import '../models/child_model.dart';
import 'glass_card.dart';

class PodiumWidget extends StatelessWidget {
  final List<ChildModel> children;
  const PodiumWidget({super.key, required this.children});

  @override
  Widget build(BuildContext context) {
    if (children.isEmpty) return const SizedBox.shrink();

    final sorted = List<ChildModel>.from(children)
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
              const Text('\u{1F451}', style: TextStyle(fontSize: 24)),
              const SizedBox(width: 8),
              Text(
                'Classement',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...List.generate(top.length, (i) => _buildRankRow(top[i], i + 1, theme)),
        ],
      ),
    );
  }

  Widget _buildRankRow(ChildModel child, int rank, ThemeData theme) {
    final colors = _rankColors(rank);
    final primaryColor = colors[0];
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: primaryColor.withValues(alpha: isDark ? 0.08 : 0.06),
        border: Border.all(color: primaryColor.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          // Rang
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [primaryColor, colors[1]],
              ),
              boxShadow: [
                BoxShadow(color: primaryColor.withValues(alpha: 0.3), blurRadius: 6),
              ],
            ),
            child: Center(
              child: Text(
                '$rank',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Avatar
          _buildAvatar(child, primaryColor),
          const SizedBox(width: 12),
          // Nom + niveau
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  child.name,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  child.levelTitle,
                  style: TextStyle(
                    fontSize: 11,
                    color: primaryColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          // Points
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              color: primaryColor.withValues(alpha: 0.12),
              border: Border.all(color: primaryColor.withValues(alpha: 0.3)),
            ),
            child: Text(
              '${child.points} pts',
              style: TextStyle(
                color: primaryColor,
                fontWeight: FontWeight.w800,
                fontSize: 14,
              ),
            ),
          ),
          // Medaille emoji
          const SizedBox(width: 8),
          Text(
            rank == 1 ? '\u{1F947}' : rank == 2 ? '\u{1F948}' : '\u{1F949}',
            style: const TextStyle(fontSize: 22),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatar(ChildModel child, Color borderColor) {
    const size = 42.0;

    Widget avatarContent;
    if (_hasValidPhoto(child)) {
      avatarContent = ClipOval(
        child: Image.memory(
          base64Decode(child.photoBase64),
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
      width: size + 4,
      height: size + 4,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: borderColor, width: 2),
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
          child.avatar.isNotEmpty ? child.avatar : '\u{1F464}',
          style: TextStyle(fontSize: size * 0.5),
        ),
      ),
    );
  }

  bool _hasValidPhoto(ChildModel child) {
    if (child.photoBase64.isEmpty) return false;
    if (child.photoBase64.length < 100) return false;
    try {
      base64Decode(child.photoBase64);
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
