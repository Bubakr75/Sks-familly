// lib/screens/goals_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/family_provider.dart';
import '../utils/pin_guard.dart';
import '../widgets/glass_card.dart';
import '../widgets/animated_background.dart';

class GoalsScreen extends StatelessWidget {
  const GoalsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    return Scaffold(
      backgroundColor: const Color(0xFF0A0E21),
      floatingActionButton: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
                color: primary.withOpacity(0.3), blurRadius: 16)
          ],
        ),
        child: FloatingActionButton.extended(
          heroTag: 'add_goal',
          onPressed: () =>
              PinGuard.guardAction(context, () => _showAddGoal(context)),
          icon: const Icon(Icons.add),
          label: const Text('Objectif'),
        ),
      ),
      body: AnimatedBackground(
        child: SafeArea(
          child: Consumer<FamilyProvider>(
            builder: (context, provider, _) {
              return Column(
                children: [
                  // Header
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                    child: Row(children: [
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            color: Colors.white.withOpacity(0.06),
                            border: Border.all(
                                color: Colors.white.withOpacity(0.08)),
                          ),
                          child: const Icon(Icons.arrow_back_rounded,
                              color: Colors.white70, size: 20),
                        ),
                      ),
                      const SizedBox(width: 14),
                      GlowIcon(
                          icon: Icons.flag_rounded,
                          color: const Color(0xFF00B0FF),
                          size: 26),
                      const SizedBox(width: 10),
                      NeonText(
                          text: 'Objectifs',
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          glowIntensity: 0.2),
                    ]),
                  ),

                  // Contenu
                  Expanded(
                    child: provider.children.isEmpty
                        ? Center(
                            child: NeonText(
                                text: 'Ajoutez des enfants d\'abord',
                                fontSize: 16,
                                color: Colors.grey))
                        : provider.goals.isEmpty
                            ? Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.flag_rounded,
                                        size: 64, color: Colors.grey[700]),
                                    const SizedBox(height: 16),
                                    NeonText(
                                        text: 'Aucun objectif',
                                        fontSize: 18,
                                        color: Colors.grey),
                                    const SizedBox(height: 8),
                                    Text(
                                        'Définissez des objectifs pour vos enfants',
                                        style: TextStyle(
                                            color: Colors.grey[600])),
                                  ],
                                ),
                              )
                            : ListView(
                                padding: const EdgeInsets.fromLTRB(
                                    16, 0, 16, 100),
                                children:
                                    provider.children.map((child) {
                                  final childGoals =
                                      provider.getGoalsForChild(child.id);
                                  if (childGoals.isEmpty)
                                    return const SizedBox.shrink();
                                  return Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Padding(
                                        padding: const EdgeInsets
                                            .symmetric(
                                            horizontal: 4, vertical: 8),
                                        child: Row(children: [
                                          Text(
                                              child.avatar.isEmpty
                                                  ? '👦'
                                                  : child.avatar,
                                              style: const TextStyle(
                                                  fontSize: 20)),
                                          const SizedBox(width: 8),
                                          NeonText(
                                              text: child.name,
                                              fontSize: 16,
                                              fontWeight: FontWeight.w700,
                                              color: Colors.white,
                                              glowIntensity: 0.15),
                                          const Spacer(),
                                          NeonText(
                                              text: '${child.points} pts',
                                              fontSize: 14,
                                              color: primary,
                                              glowIntensity: 0.3),
                                        ]),
                                      ),
                                      ...childGoals.map((goal) {
                                        final progress = goal.targetPoints >
                                                0
                                            ? (child.points /
                                                    goal.targetPoints)
                                                .clamp(0.0, 1.0)
                                            : 0.0;
                                        final isAchieved =
                                            child.points >= goal.targetPoints;
                                        final goalColor = isAchieved
                                            ? const Color(0xFF00E676)
                                            : const Color(0xFF00B0FF);
                                        return GlassCard(
                                          margin: const EdgeInsets
                                              .symmetric(
                                              horizontal: 0, vertical: 4),
                                          padding: const EdgeInsets.all(14),
                                          borderRadius: 16,
                                          glowColor: isAchieved
                                              ? const Color(0xFF00E676)
                                              : null,
                                          child: Row(children: [
                                            Container(
                                              width: 42,
                                              height: 42,
                                              decoration: BoxDecoration(
                                                shape: BoxShape.circle,
                                                color: goalColor
                                                    .withOpacity(0.12),
                                                border: Border.all(
                                                    color: goalColor
                                                        .withOpacity(0.3)),
                                                boxShadow: [
                                                  BoxShadow(
                                                      color: goalColor
                                                          .withOpacity(0.15),
                                                      blurRadius: 8)
                                                ],
                                              ),
                                              child: Icon(
                                                isAchieved
                                                    ? Icons.check_circle_rounded
                                                    : Icons.flag_rounded,
                                                color: goalColor,
                                                size: 22,
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    goal.title,
                                                    maxLines: 1,
                                                    overflow: TextOverflow
                                                        .ellipsis,
                                                    style: TextStyle(
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      fontSize: 15,
                                                      color: Colors.white,
                                                      decoration: goal
                                                              .completed
                                                          ? TextDecoration
                                                              .lineThrough
                                                          : null,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 6),
                                                  TweenAnimationBuilder<
                                                      double>(
                                                    tween: Tween(
                                                        begin: 0.0,
                                                        end: progress),
                                                    duration: const Duration(
                                                        milliseconds: 800),
                                                    curve: Curves.easeOutCubic,
                                                    builder: (_, v, __) =>
                                                        ClipRRect(
                                                      borderRadius:
                                                          BorderRadius
                                                              .circular(4),
                                                      child:
                                                          LinearProgressIndicator(
                                                        value: v,
                                                        minHeight: 6,
                                                        backgroundColor:
                                                            Colors.white
                                                                .withOpacity(
                                                                    0.06),
                                                        valueColor:
                                                            AlwaysStoppedAnimation(
                                                                goalColor),
                                                      ),
                                                    ),
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Text(
                                                      '${child.points}/${goal.targetPoints} points',
                                                      style: TextStyle(
                                                          fontSize: 11,
                                                          color:
                                                              Colors.grey[500])),
                                                ],
                                              ),
                                            ),
                                            PopupMenuButton(
                                              icon: Icon(Icons.more_vert,
                                                  color: Colors.grey[600],
                                                  size: 20),
                                              color:
                                                  const Color(0xFF162033),
                                              shape:
                                                  RoundedRectangleBorder(
                                                      borderRadius:
                                                          BorderRadius
                                                              .circular(14)),
                                              itemBuilder: (_) => [
                                                PopupMenuItem(
                                                  value: 'toggle',
                                                  child: Text(
                                                      goal.completed
                                                          ? 'Rouvrir'
                                                          : 'Terminer',
                                                      style: const TextStyle(
                                                          color:
                                                              Colors.white)),
                                                ),
                                                const PopupMenuItem(
                                                  value: 'delete',
                                                  child: Text('Supprimer',
                                                      style: TextStyle(
                                                          color: Color(
                                                              0xFFFF1744))),
                                                ),
                                              ],
                                              onSelected: (v) {
                                                PinGuard.guardAction(
                                                    context, () {
                                                  if (v == 'toggle')
                                                    provider.toggleGoal(
                                                        goal.id);
                                                  if (v == 'delete')
                                                    provider.removeGoal(
                                                        goal.id);
                                                });
                                              },
                                            ),
                                          ]),
                                        );
                                      }),
                                      const SizedBox(height: 12),
                                    ],
                                  );
                                }).toList(),
                              ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  void _showAddGoal(BuildContext context) {
    final provider = context.read<FamilyProvider>();
    final titleCtrl = TextEditingController();
    int targetPoints = 100;
    String? selectedChildId =
        provider.children.isNotEmpty ? provider.children.first.id : null;
    final primary = Theme.of(context).colorScheme.primary;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          backgroundColor: const Color(0xFF0D1B2A),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24)),
          title: const NeonText(
              text: 'Nouvel objectif',
              fontSize: 18,
              color: Colors.white),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              // Correction : value: au lieu de initialValue:
              DropdownButtonFormField<String>(
                value: selectedChildId,
                dropdownColor: const Color(0xFF162033),
                decoration: InputDecoration(
                  labelText: 'Enfant',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                items: provider.children
                    .map((c) => DropdownMenuItem(
                          value: c.id,
                          child: Text(
                              '${c.avatar.isEmpty ? "👦" : c.avatar} ${c.name}'),
                        ))
                    .toList(),
                onChanged: (v) => setState(() => selectedChildId = v),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: titleCtrl,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Titre de l\'objectif',
                  hintText: 'Ex: Devenir champion',
                  prefixIcon:
                      GlowIcon(icon: Icons.flag, size: 20, color: primary),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
              ),
              const SizedBox(height: 14),
              Row(children: [
                const Text('Points cibles :',
                    style: TextStyle(color: Colors.white70)),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.remove_circle_outline,
                      color: Colors.white54),
                  onPressed: () {
                    if (targetPoints > 10)
                      setState(() => targetPoints -= 10);
                  },
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 6),
                  decoration: BoxDecoration(
                    color: primary.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                    border:
                        Border.all(color: primary.withOpacity(0.2)),
                  ),
                  child: NeonText(
                      text: '$targetPoints',
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: primary),
                ),
                IconButton(
                  icon: const Icon(Icons.add_circle_outline,
                      color: Colors.white54),
                  onPressed: () =>
                      setState(() => targetPoints += 10),
                ),
              ]),
            ]),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Annuler')),
            FilledButton(
              onPressed: () {
                if (titleCtrl.text.trim().isNotEmpty &&
                    selectedChildId != null) {
                  provider.addGoal(selectedChildId!,
                      titleCtrl.text.trim(), targetPoints);
                  Navigator.pop(ctx);
                }
              },
              child: const Text('Créer'),
            ),
          ],
        ),
      ),
    );
  }
}
