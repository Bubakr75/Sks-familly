import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/family_provider.dart';
import '../models/badge_model.dart';
import '../utils/pin_guard.dart';
import '../widgets/glass_card.dart';
import '../widgets/animated_background.dart';

class BadgesScreen extends StatelessWidget {
  const BadgesScreen({super.key});

  static const _powerEmojis = {
    'tv': '\u{1F4FA}',
    'no_chores': '\u{1F9F9}',
    'dessert': '\u{1F370}',
    'late_bed': '\u{1F319}',
    'game': '\u{1F3AE}',
    'outing': '\u{1F3E0}',
    'star': '\u{2B50}',
    'school': '\u{1F393}',
    'thumb_up': '\u{1F44D}',
    'home': '\u{1F3E0}',
    'emoji_events': '\u{1F3C6}',
    'military_tech': '\u{1F396}',
    'custom': '\u{26A1}',
    'music': '\u{1F3B5}',
    'candy': '\u{1F36C}',
    'pet': '\u{1F436}',
    'sleep': '\u{1F634}',
    'shop': '\u{1F6CD}',
    'crown': '\u{1F451}',
  };

  static const _powerTypes = [
    {'type': 'tv', 'label': 'Maitre de la tele'},
    {'type': 'no_chores', 'label': 'Pas de corvees'},
    {'type': 'dessert', 'label': 'Super dessert'},
    {'type': 'late_bed', 'label': 'Couche-tard'},
    {'type': 'game', 'label': 'Jeu video'},
    {'type': 'outing', 'label': 'Sortie speciale'},
    {'type': 'music', 'label': 'Musique'},
    {'type': 'candy', 'label': 'Bonbons'},
    {'type': 'pet', 'label': 'Animal'},
    {'type': 'sleep', 'label': 'Grasse matinee'},
    {'type': 'shop', 'label': 'Shopping'},
    {'type': 'crown', 'label': 'Roi/Reine du jour'},
    {'type': 'custom', 'label': 'Personnalise'},
  ];

  String _getEmoji(String type) => _powerEmojis[type] ?? '\u{26A1}';

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    return Scaffold(
      backgroundColor: const Color(0xFF0A0E21),
      floatingActionButton: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: const Color(0xFFFFD700).withValues(alpha: 0.3), blurRadius: 16)],
        ),
        child: FloatingActionButton.extended(
          heroTag: 'add_power',
          backgroundColor: const Color(0xFFFFD700),
          foregroundColor: Colors.black,
          onPressed: () => PinGuard.guardAction(context, () => _showAddBadge(context)),
          icon: const Icon(Icons.add_rounded),
          label: const Text('Creer un pouvoir', style: TextStyle(fontWeight: FontWeight.w700)),
        ),
      ),
      body: AnimatedBackground(
        child: SafeArea(
          child: Consumer<FamilyProvider>(
            builder: (context, provider, _) {
              final badges = provider.allBadges;
              return CustomScrollView(
                physics: const BouncingScrollPhysics(),
                slivers: [
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
                          const Text('\u{26A1}', style: TextStyle(fontSize: 24)),
                          const SizedBox(width: 10),
                          const Flexible(
                            child: NeonText(
                              text: 'Pouvoirs & Recompenses',
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              glowIntensity: 0.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Tous les pouvoirs
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                      child: NeonText(text: 'Tous les pouvoirs', fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white, glowIntensity: 0.15),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    sliver: SliverGrid(
                      delegate: SliverChildBuilderDelegate(
                        (_, i) {
                          final badge = badges[i];
                          return TweenAnimationBuilder<double>(
                            tween: Tween(begin: 0.0, end: 1.0),
                            duration: Duration(milliseconds: 400 + i * 80),
                            curve: Curves.easeOutBack,
                            builder: (_, v, child) => Opacity(
                              opacity: v.clamp(0.0, 1.0),
                              child: Transform.scale(scale: 0.8 + 0.2 * v, child: child),
                            ),
                            child: GestureDetector(
                              onLongPress: badge.isCustom
                                  ? () => PinGuard.guardAction(context, () => _showBadgeOptions(context, badge, provider))
                                  : null,
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
                                  border: Border.all(color: badge.isCustom
                                      ? const Color(0xFF00E5FF).withValues(alpha: 0.25)
                                      : const Color(0xFFFFD700).withValues(alpha: 0.15)),
                                  boxShadow: [BoxShadow(color: const Color(0xFFFFD700).withValues(alpha: 0.05), blurRadius: 8)],
                                ),
                                padding: const EdgeInsets.all(8),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(_getEmoji(badge.powerType), style: const TextStyle(fontSize: 28)),
                                    const SizedBox(height: 4),
                                    Flexible(
                                      child: Text(
                                        badge.name,
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFFFD700).withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: const Color(0xFFFFD700).withValues(alpha: 0.2)),
                                      ),
                                      child: Text(
                                        '${badge.requiredPoints} pts',
                                        style: const TextStyle(fontSize: 9, color: Color(0xFFFFD700), fontWeight: FontWeight.w700),
                                      ),
                                    ),
                                    if (badge.isCustom)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 2),
                                        child: Text('Perso', style: TextStyle(fontSize: 8, color: Colors.cyan[300], fontWeight: FontWeight.w600)),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                        childCount: badges.length,
                      ),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        childAspectRatio: 0.75,
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                      ),
                    ),
                  ),

                  // Progression par enfant
                  if (provider.children.isNotEmpty) ...[
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
                          final primary = Theme.of(context).colorScheme.primary;
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
                                              '${earned.length}/${badges.length} pouvoirs - ${child.levelTitle}',
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
                                        ),
                                        child: NeonText(text: '${child.points} pts', fontSize: 13, fontWeight: FontWeight.w700, color: primary),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(4),
                                    child: LinearProgressIndicator(
                                      value: badges.isNotEmpty ? earned.length / badges.length : 0,
                                      minHeight: 6,
                                      backgroundColor: Colors.white.withValues(alpha: 0.06),
                                      valueColor: const AlwaysStoppedAnimation(Color(0xFFFFD700)),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Wrap(
                                    spacing: 6,
                                    runSpacing: 6,
                                    children: badges.map((b) {
                                      final has = child.badgeIds.contains(b.id);
                                      return Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: has
                                              ? const Color(0xFFFFD700).withValues(alpha: 0.12)
                                              : Colors.white.withValues(alpha: 0.04),
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(
                                            color: has ? const Color(0xFFFFD700).withValues(alpha: 0.3) : Colors.white.withValues(alpha: 0.06),
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(_getEmoji(b.powerType), style: TextStyle(fontSize: has ? 14 : 12)),
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
                  ],
                  const SliverToBoxAdapter(child: SizedBox(height: 100)),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  void _showBadgeOptions(BuildContext context, BadgeModel badge, FamilyProvider provider) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0D1B2A),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[700], borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 16),
            Text(_getEmoji(badge.powerType), style: const TextStyle(fontSize: 40)),
            const SizedBox(height: 8),
            Text(badge.name, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            Text(badge.description, style: TextStyle(color: Colors.grey[500], fontSize: 13)),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.blue,
                      side: const BorderSide(color: Colors.blue),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: () {
                      Navigator.pop(ctx);
                      _showEditBadge(context, badge);
                    },
                    icon: const Icon(Icons.edit_rounded, size: 18),
                    label: const Text('Modifier'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFFF1744),
                      side: const BorderSide(color: Color(0xFFFF1744)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: () {
                      provider.removeCustomBadge(badge.id);
                      Navigator.pop(ctx);
                    },
                    icon: const Icon(Icons.delete_rounded, size: 18),
                    label: const Text('Supprimer'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  void _showAddBadge(BuildContext context) {
    _showBadgeForm(context, null);
  }

  void _showEditBadge(BuildContext context, BadgeModel badge) {
    _showBadgeForm(context, badge);
  }

  void _showBadgeForm(BuildContext context, BadgeModel? existing) {
    final provider = context.read<FamilyProvider>();
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final descCtrl = TextEditingController(text: existing?.description ?? '');
    final pointsCtrl = TextEditingController(text: existing != null ? '${existing.requiredPoints}' : '');
    String selectedType = existing?.powerType ?? 'custom';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF0D1B2A),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => Padding(
          padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[700], borderRadius: BorderRadius.circular(2)))),
                const SizedBox(height: 16),
                Row(children: [
                  const Text('\u{26A1}', style: TextStyle(fontSize: 24)),
                  const SizedBox(width: 10),
                  NeonText(text: existing != null ? 'Modifier le pouvoir' : 'Nouveau pouvoir', fontSize: 18, color: Colors.white),
                ]),
                const SizedBox(height: 20),
                const Text('Type de pouvoir', style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _powerTypes.map((pt) {
                    final isSelected = selectedType == pt['type'];
                    return GestureDetector(
                      onTap: () => setState(() => selectedType = pt['type']!),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          color: isSelected ? const Color(0xFFFFD700).withValues(alpha: 0.15) : Colors.white.withValues(alpha: 0.04),
                          border: Border.all(color: isSelected ? const Color(0xFFFFD700).withValues(alpha: 0.5) : Colors.white.withValues(alpha: 0.08)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(_powerEmojis[pt['type']] ?? '\u{26A1}', style: const TextStyle(fontSize: 16)),
                            const SizedBox(width: 4),
                            Text(pt['label']!, style: TextStyle(color: isSelected ? const Color(0xFFFFD700) : Colors.grey[500], fontSize: 12, fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500)),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: nameCtrl,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Nom du pouvoir',
                    labelStyle: TextStyle(color: Colors.grey[500]),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1))),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descCtrl,
                  style: const TextStyle(color: Colors.white),
                  maxLines: 2,
                  decoration: InputDecoration(
                    labelText: 'Description',
                    labelStyle: TextStyle(color: Colors.grey[500]),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1))),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: pointsCtrl,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800),
                  textAlign: TextAlign.center,
                  decoration: InputDecoration(
                    labelText: 'Points necessaires',
                    labelStyle: TextStyle(color: Colors.grey[500]),
                    suffixText: 'pts',
                    suffixStyle: TextStyle(color: Colors.grey[600]),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1))),
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFFFD700),
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: () {
                      final points = int.tryParse(pointsCtrl.text) ?? 0;
                      if (nameCtrl.text.isNotEmpty && points > 0) {
                        if (existing != null) {
                          provider.updateCustomBadge(existing.id, nameCtrl.text, descCtrl.text, points, selectedType);
                        } else {
                          provider.addCustomBadge(nameCtrl.text, descCtrl.text, points, selectedType);
                        }
                        Navigator.pop(ctx);
                      }
                    },
                    icon: Icon(existing != null ? Icons.save_rounded : Icons.add_rounded),
                    label: Text(existing != null ? 'Enregistrer' : 'Creer le pouvoir', style: const TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
