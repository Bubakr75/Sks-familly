// lib/screens/shop_screen.dart
//
// Boutique de Récompenses SKS Family (remplace l'écran des badges).
// Les enfants y dépensent leurs points durement gagnés pour des privilèges réels.
// Design premium : cartes dorées, animations, style boutique de luxe.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/family_provider.dart';
import '../models/child_model.dart';
import '../models/reward_model.dart';
import '../config/emerald_theme.dart';

class ShopScreen extends StatefulWidget {
  final String? childId;
  const ShopScreen({super.key, this.childId});

  @override
  State<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends State<ShopScreen> with TickerProviderStateMixin {
  late AnimationController _staggerController;
  late Animation<double> _fadeAnim;
  String? _selectedChildId;
  ChildModel? get _selectedChild {
    final fp = context.read<FamilyProvider>();
    if (_selectedChildId != null) {
      return fp.getChild(_selectedChildId!);
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    _staggerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnim = CurvedAnimation(
      parent: _staggerController,
      curve: const Interval(0.1, 0.6, curve: Curves.easeOutCubic),
    );
    _staggerController.forward();
  }

  @override
  void dispose() {
    _staggerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fp = context.watch<FamilyProvider>();
    final child = _selectedChild ?? (fp.children.isNotEmpty ? fp.children.first : null);

    return Scaffold(
      backgroundColor: const Color(0xFF051410),
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // ─── HEADER PREMIUM ───
            SliverAppBar(
              expandedHeight: 180,
              backgroundColor: Colors.transparent,
              flexibleSpace: FlexibleSpaceBar(
                background: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        EmeraldPalette.gold.withValues(alpha: 0.25),
                        EmeraldPalette.emerald.withValues(alpha: 0.1),
                        Colors.transparent,
                      ],
                    ),
                  ),
                  child: SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          // Sélecteur enfant
                          if (fp.children.length > 1)
                            Row(
                              children: [
                                _buildChildSelector(fp),
                                const Spacer(),
                                // Solde de points
                                if (child != null)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                    decoration: BoxDecoration(
                                      gradient: EmeraldPalette.goldGradient,
                                      borderRadius: BorderRadius.circular(20),
                                      boxShadow: [
                                        BoxShadow(
                                          color: EmeraldPalette.gold.withValues(alpha: 0.4),
                                          blurRadius: 16,
                                        ),
                                      ],
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.stars_rounded, color: Color(0xFF051410), size: 20),
                                        const SizedBox(width: 6),
                                        Text(
                                          '${child.points}',
                                          style: const TextStyle(
                                            color: Color(0xFF051410),
                                            fontSize: 20,
                                            fontWeight: FontWeight.w900,
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        const Text('pts', style: TextStyle(color: Color(0xFF051410), fontSize: 12, fontWeight: FontWeight.w600)),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // ─── TITRE BOUTIQUE ───
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
                child: FadeTransition(
                  opacity: _fadeAnim,
                  child: Row(
                    children: [
                      const Text('🛒', style: TextStyle(fontSize: 28)),
                      const SizedBox(width: 10),
                      const Text(
                        'Boutique',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          color: EmeraldPalette.textPrimary,
                          shadows: [Shadow(color: EmeraldPalette.gold, blurRadius: 20)],
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '${fp.rewards.length} articles',
                        style: const TextStyle(color: EmeraldPalette.textSecondary, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // ─── GRILLE DE RÉCOMPENSES ───
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: fp.rewards.isEmpty
                  ? const SliverToBoxAdapter(child: _EmptyShop())
                  : SliverGrid(
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        mainAxisSpacing: 12,
                        crossAxisSpacing: 12,
                        childAspectRatio: 0.75,
                      ),
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final reward = fp.rewards[index];
                          return _RewardCard(
                            reward: reward,
                            child: child,
                            canAfford: child != null && child.points >= reward.cost,
                            onBuy: () => _showPurchaseDialog(context, fp, child!, reward),
                          );
                        },
                        childCount: fp.rewards.length,
                      ),
                    ),
            ),

            const SliverPadding(padding: EdgeInsets.only(bottom: 100)),
          ],
        ),
      ),
    );
  }

  Widget _buildChildSelector(FamilyProvider fp) {
    return GestureDetector(
      onTap: () => _showChildPicker(fp),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: EmeraldPalette.surface.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: EmeraldPalette.glassBorder),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 14,
              backgroundColor: EmeraldPalette.emerald.withValues(alpha: 0.2),
              child: Text(_selectedChild?.avatar ?? '👤', style: const TextStyle(fontSize: 16)),
            ),
            const SizedBox(width: 8),
            Text(
              _selectedChild?.name ?? 'Choisir',
              style: const TextStyle(color: EmeraldPalette.textPrimary, fontWeight: FontWeight.w600),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.expand_more_rounded, color: EmeraldPalette.textSecondary, size: 18),
          ],
        ),
      ),
    );
  }

  void _showChildPicker(FamilyProvider fp) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        margin: const EdgeInsets.all(12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: EmeraldPalette.surface,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 16), decoration: BoxDecoration(color: EmeraldPalette.textMuted, borderRadius: BorderRadius.circular(2))),
            const Text('Pour qui ?', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: EmeraldPalette.textPrimary)),
            const SizedBox(height: 14),
            ...fp.children.map((c) => ListTile(
              leading: CircleAvatar(child: Text(c.avatar.isNotEmpty ? c.avatar : '👤')),
              title: Text(c.name, style: const TextStyle(color: EmeraldPalette.textPrimary)),
              trailing: Text('${c.points} pts', style: const TextStyle(color: EmeraldPalette.gold, fontWeight: FontWeight.w700)),
              onTap: () {
                setState(() => _selectedChildId = c.id);
                Navigator.pop(ctx);
              },
            )),
          ],
        ),
      ),
    );
  }

  void _showPurchaseDialog(BuildContext context, FamilyProvider fp, ChildModel child, RewardModel reward) {
    if (child.points < reward.cost) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Pas assez de points ! Il te manque ${reward.cost - child.points} pts.'),
          backgroundColor: Colors.red.shade700,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: EmeraldPalette.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(children: [
          Text(reward.icon, style: const TextStyle(fontSize: 32)),
          const SizedBox(width: 10),
          Expanded(child: Text(reward.title, style: const TextStyle(color: EmeraldPalette.textPrimary, fontSize: 20, fontWeight: FontWeight.w700))),
        ]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(reward.description, style: const TextStyle(color: EmeraldPalette.textSecondary)),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  decoration: BoxDecoration(
                    gradient: EmeraldPalette.goldGradient,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.stars_rounded, color: Color(0xFF051410)),
                      const SizedBox(width: 6),
                      Text('${reward.cost} pts', style: const TextStyle(color: Color(0xFF051410), fontWeight: FontWeight.w800, fontSize: 18)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Center(child: Text('Solde après achat : ${child.points - reward.cost} pts', style: const TextStyle(color: EmeraldPalette.textMuted, fontSize: 13))),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler', style: TextStyle(color: EmeraldPalette.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: EmeraldPalette.emerald,
              foregroundColor: const Color(0xFF051410),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              final ok = await fp.purchaseReward(child.id, reward.id);
              if (ok && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('🎉 Achat réussi ! ${reward.title} en attente de validation.'),
                    backgroundColor: EmeraldPalette.success,
                  ),
                );
              }
            },
            child: const Text('Acheter', style: TextStyle(fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }
}

// ─── Carte de récompense premium ──────────────────────────────
class _RewardCard extends StatefulWidget {
  final RewardModel reward;
  final ChildModel? child;
  final bool canAfford;
  final VoidCallback onBuy;

  const _RewardCard({
    required this.reward,
    required this.child,
    required this.canAfford,
    required this.onBuy,
  });

  @override
  State<_RewardCard> createState() => _RewardCardState();
}

class _RewardCardState extends State<_RewardCard> with SingleTickerProviderStateMixin {
  late AnimationController _shimmerController;

  @override
  void initState() {
    super.initState();
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    );
    if (widget.canAfford) _shimmerController.repeat();
  }

  @override
  void didUpdateWidget(_RewardCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.canAfford && !_shimmerController.isAnimating) {
      _shimmerController.repeat();
    } else if (!widget.canAfford && _shimmerController.isAnimating) {
      _shimmerController.stop();
    }
  }

  @override
  void dispose() {
    _shimmerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accent = widget.canAfford ? EmeraldPalette.gold : EmeraldPalette.textMuted;

    return GestureDetector(
      onTap: widget.onBuy,
      child: AnimatedBuilder(
        animation: _shimmerController,
        builder: (context, child) {
          return Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  EmeraldPalette.surface,
                  Color.lerp(EmeraldPalette.surface, Colors.black, 0.15)!,
                ],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: accent.withValues(alpha: widget.canAfford ? 0.5 : 0.1),
                width: widget.canAfford ? 1.5 : 1,
              ),
              boxShadow: widget.canAfford
                  ? [
                      BoxShadow(
                        color: EmeraldPalette.gold.withValues(alpha: 0.2),
                        blurRadius: 16,
                        spreadRadius: -2,
                      ),
                    ]
                  : null,
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Icône dans un cercle avec halo
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          accent.withValues(alpha: widget.canAfford ? 0.3 : 0.08),
                          Colors.transparent,
                        ],
                      ),
                    ),
                    child: Center(
                      child: Text(
                        widget.reward.icon,
                        style: TextStyle(
                          fontSize: 28,
                          color: widget.canAfford ? null : Colors.grey,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  // Titre
                  Text(
                    widget.reward.title,
                    style: TextStyle(
                      color: widget.canAfford ? EmeraldPalette.textPrimary : EmeraldPalette.textMuted,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  // Description courte
                  if (widget.reward.description.isNotEmpty)
                    Text(
                      widget.reward.description,
                      style: const TextStyle(
                        color: EmeraldPalette.textSecondary,
                        fontSize: 10,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  const Spacer(),
                  // Prix
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: accent.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.stars_rounded, size: 16, color: accent),
                        const SizedBox(width: 4),
                        Text(
                          '${widget.reward.cost}',
                          style: TextStyle(
                            color: accent,
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _EmptyShop extends StatelessWidget {
  const _EmptyShop();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.only(top: 60),
        child: Column(
          children: [
            const Text('🛒', style: TextStyle(fontSize: 64)),
            const SizedBox(height: 16),
            const Text('Boutique vide', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: EmeraldPalette.textPrimary)),
            const SizedBox(height: 8),
            const Text('Le parent n\'a pas encore ajouté de récompenses.', style: TextStyle(color: EmeraldPalette.textMuted)),
          ],
        ),
      ),
    );
  }
}
