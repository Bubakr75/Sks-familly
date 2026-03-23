import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/family_provider.dart';
import '../models/badge_model.dart';
import '../utils/pin_guard.dart';
import '../widgets/glass_card.dart';
import '../widgets/animated_background.dart';

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
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
                          onPressed: () => Navigator.pop(context),
                        ),
                        const Text('\u{26A1}', style: TextStyle(fontSize: 22)),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'Pouvoirs',
                            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.info_outline, size: 20),
                          onPressed: () => _showBadgeInfo(context, allBadges),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: children.isEmpty
                        ? const Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text('\u{1F476}', style: TextStyle(fontSize: 48)),
                                SizedBox(height: 12),
                                Text('Ajoutez des enfants pour commencer',
                                    style: TextStyle(color: Colors.white60)),
                              ],
                            ),
                          )
                        : ListView(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            children: [
                              const Text(
                                'Tous les pouvoirs',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white70),
                              ),
                              const SizedBox(height: 8),
                              GridView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 3,
                                  childAspectRatio: 0.85,
                                  crossAxisSpacing: 8,
                                  mainAxisSpacing: 8,
                                ),
                                itemCount: allBadges.length,
                                itemBuilder: (context, index) {
                                  final badge = allBadges[index];
                                  return GestureDetector(
                                    onLongPress: badge.isCustom
                                        ? () => PinGuard.guardAction(context, () => _showEditBadgeDialog(context, provider, badge))
                                        : null,
                                    child: GlassCard(
                                      child: Padding(
                                        padding: const EdgeInsets.all(8),
                                        child: Column(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Text(badge.powerEmoji, style: const TextStyle(fontSize: 28)),
                                            const SizedBox(height: 4),
                                            Text(
                                              badge.name,
                                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                                              textAlign: TextAlign.center,
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              '${badge.requiredPoints} pts',
                                              style: TextStyle(
                                                fontSize: 10,
                                                color: Theme.of(context).colorScheme.primary,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                            if (badge.isCustom)
                                              const Text(
                                                'personnalise',
                                                style: TextStyle(fontSize: 8, color: Colors.white38),
                                              ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                              const SizedBox(height: 20),
                              const Text(
                                'Progression par enfant',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white70),
                              ),
                              const SizedBox(height: 8),
                              ...children.map((child) {
                                final earned = allBadges.where((b) => child.points >= b.requiredPoints).toList();
                                final progress = allBadges.isEmpty ? 0.0 : earned.length / allBadges.length;

                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: GlassCard(
                                    child: Padding(
                                      padding: const EdgeInsets.all(16),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              CircleAvatar(
                                                radius: 18,
                                                backgroundColor: Colors.white12,
                                                child: Text(child.avatar, style: const TextStyle(fontSize: 18)),
                                              ),
                                              const SizedBox(width: 12),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      child.name,
                                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                                    ),
                                                    Text(
                                                      '${earned.length}/${allBadges.length} pouvoirs - ${child.points} pts',
                                                      style: const TextStyle(color: Colors.white60, fontSize: 12),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 10),
                                          ClipRRect(
                                            borderRadius: BorderRadius.circular(6),
                                            child: LinearProgressIndicator(
                                              value: progress,
                                              backgroundColor: Colors.white12,
                                              minHeight: 6,
                                            ),
                                          ),
                                          const SizedBox(height: 10),
                                          Wrap(
                                            spacing: 6,
                                            runSpacing: 6,
                                            children: allBadges.map((badge) {
                                              final unlocked = child.points >= badge.requiredPoints;
                                              return Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                decoration: BoxDecoration(
                                                  color: unlocked ? Colors.green.withOpacity(0.2) : Colors.white.withOpacity(0.05),
                                                  borderRadius: BorderRadius.circular(12),
                                                  border: Border.all(
                                                    color: unlocked ? Colors.greenAccent.withOpacity(0.5) : Colors.white12,
                                                  ),
                                                ),
                                                child: Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    Text(badge.powerEmoji, style: const TextStyle(fontSize: 14)),
                                                    const SizedBox(width: 4),
                                                    Text(
                                                      badge.name,
                                                      style: TextStyle(
                                                        fontSize: 10,
                                                        color: unlocked ? Colors.greenAccent : Colors.white38,
                                                      ),
                                                    ),
                                                    if (unlocked) ...[
                                                      const SizedBox(width: 4),
                                                      const Icon(Icons.check_circle, size: 12, color: Colors.greenAccent),
                                                    ],
                                                  ],
                                                ),
                                              );
                                            }).toList(),
                                          ),
                                        ],
                                      ),
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
        title: const Row(
          children: [
            Text('\u{26A1}', style: TextStyle(fontSize: 22)),
            SizedBox(width: 8),
            Text('Systeme de pouvoirs', style: TextStyle(color: Colors.white, fontSize: 16)),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView(
            shrinkWrap: true,
            children: [
              const Text(
                'Les enfants debloquent des pouvoirs en accumulant des points. Chaque pouvoir donne un privilege special !',
                style: TextStyle(color: Colors.white70, fontSize: 13),
              ),
              const SizedBox(height: 16),
              ...badges.map((b) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Text(b.powerEmoji, style: const TextStyle(fontSize: 20)),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(b.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                              Text(b.description, style: const TextStyle(color: Colors.white60, fontSize: 11)),
                            ],
                          ),
                        ),
                        Text('${b.requiredPoints} pts',
                            style: TextStyle(color: Theme.of(context).colorScheme.primary, fontSize: 12, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  )),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Compris !'),
          ),
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
      {'type': 'tv', 'emoji': '\u{1F4FA}', 'label': 'Tele'},
      {'type': 'no_chores', 'emoji': '\u{1F9F9}', 'label': 'Corvees'},
      {'type': 'dessert', 'emoji': '\u{1F370}', 'label': 'Dessert'},
      {'type': 'late_bed', 'emoji': '\u{1F319}', 'label': 'Coucher'},
      {'type': 'game', 'emoji': '\u{1F3AE}', 'label': 'Jeu'},
      {'type': 'outing', 'emoji': '\u{1F3E0}', 'label': 'Sortie'},
      {'type': 'custom', 'emoji': '\u{26A1}', 'label': 'Autre'},
    ];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          backgroundColor: const Color(0xFF1A1A2E),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Nouveau pouvoir', style: TextStyle(color: Colors.white)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: powerOptions.map((opt) {
                    final selected = selectedPower == opt['type'];
                    return GestureDetector(
                      onTap: () => setState(() => selectedPower = opt['type'] as String),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: selected ? Colors.white.withOpacity(0.15) : Colors.white.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(12),
                          border: selected ? Border.all(color: Theme.of(context).colorScheme.primary) : null,
                        ),
                        child: Column(
                          children: [
                            Text(opt['emoji'] as String, style: const TextStyle(fontSize: 20)),
                            Text(opt['label'] as String, style: const TextStyle(fontSize: 9, color: Colors.white60)),
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
                    labelStyle: const TextStyle(color: Colors.white60),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.1),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descCtrl,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Description',
                    labelStyle: const TextStyle(color: Colors.white60),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.1),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: pointsCtrl,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Points requis',
                    labelStyle: const TextStyle(color: Colors.white60),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.1),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              onPressed: () {
                if (nameCtrl.text.isNotEmpty) {
                  final provider = context.read<FamilyProvider>();
                  provider.addCustomBadge(
                    nameCtrl.text,
                    descCtrl.text,
                    selectedPower,
                    int.tryParse(pointsCtrl.text) ?? 50,
                  );
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Pouvoir "${nameCtrl.text}" cree !')),
                  );
                }
              },
              child: const Text('Creer'),
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
        title: Row(
          children: [
            Text(badge.powerEmoji, style: const TextStyle(fontSize: 22)),
            const SizedBox(width: 8),
            Expanded(child: Text(badge.name, style: const TextStyle(color: Colors.white, fontSize: 16))),
          ],
        ),
        content: Text(badge.description, style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Fermer'),
          ),
          TextButton(
            onPressed: () {
              provider.removeCustomBadge(badge.id);
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Pouvoir "${badge.name}" supprime')),
              );
            },
            child: const Text('Supprimer', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
  }
}
