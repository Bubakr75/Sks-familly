// lib/screens/goals_screen.dart
import 'package:flutter/material.dart';
import '../widgets/glass_widgets.dart';
import '../widgets/tv_focus_wrapper.dart';
import '../utils/tv_detector.dart';
import 'package:provider/provider.dart';
import '../providers/family_provider.dart';
import '../utils/pin_guard.dart';
import '../widgets/glass_card.dart';
import '../widgets/animated_background.dart';

class GoalsScreen extends StatelessWidget {
  const GoalsScreen({super.key});
  bool get isTV => TvDetector.isTV;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    return Scaffold(
      backgroundColor: const Color(0xFF0A0E21),
      body: AnimatedBackground(
        child: SafeArea(
          child: Consumer<FamilyProvider>(
            builder: (context, provider, _) {
              return Column(children: [
                // Header
                Padding(
                  padding: EdgeInsets.fromLTRB(isTV ? 28 : 20, isTV ? 20 : 16, isTV ? 28 : 20, 8),
                  child: Row(children: [
                    TvFocusWrapper(
                      autofocus: isTV,
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        width: isTV ? 48 : 40, height: isTV ? 48 : 40,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          color: Colors.white.withOpacity(0.06),
                          border: Border.all(color: Colors.white.withOpacity(0.08))),
                        child: Icon(Icons.arrow_back_rounded, color: Colors.white70, size: isTV ? 24 : 20),
                      ),
                    ),
                    SizedBox(width: isTV ? 16 : 14),
                    GlowIcon(icon: Icons.flag_rounded, color: const Color(0xFF00B0FF), size: isTV ? 30 : 26),
                    SizedBox(width: isTV ? 12 : 10),
                    Expanded(child: NeonText(
                      text: 'Objectifs', fontSize: isTV ? 26 : 22,
                      fontWeight: FontWeight.w800, color: Colors.white, glowIntensity: 0.2)),
                    TvFocusWrapper(
                      onTap: () => PinGuard.guardAction(context, () => _showAddGoal(context)),
                      child: Container(
                        padding: EdgeInsets.symmetric(horizontal: isTV ? 20 : 14, vertical: isTV ? 12 : 8),
                        decoration: BoxDecoration(
                          color: primary.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: primary.withOpacity(0.6)),
                          boxShadow: [BoxShadow(color: primary.withOpacity(0.2), blurRadius: 12)]),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(Icons.add, color: Colors.white, size: isTV ? 22 : 18),
                          const SizedBox(width: 4),
                          Text('Objectif', style: TextStyle(
                            color: Colors.white, fontWeight: FontWeight.bold, fontSize: isTV ? 18 : 14)),
                        ]),
                      ),
                    ),
                  ]),
                ),

                // Contenu
                Expanded(
                  child: provider.children.isEmpty
                    ? Center(child: NeonText(text: 'Ajoutez des enfants d\'abord', fontSize: isTV ? 22 : 16, color: Colors.grey))
                    : provider.goals.isEmpty
                      ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                          Icon(Icons.flag_rounded, size: isTV ? 80 : 64, color: Colors.grey[700]),
                          const SizedBox(height: 16),
                          NeonText(text: 'Aucun objectif', fontSize: isTV ? 22 : 18, color: Colors.grey),
                          const SizedBox(height: 8),
                          Text('D\u00E9finissez des objectifs pour vos enfants',
                            style: TextStyle(color: Colors.grey[600], fontSize: isTV ? 18 : 14)),
                        ]))
                      : ListView(
                          padding: EdgeInsets.fromLTRB(isTV ? 24 : 16, 0, isTV ? 24 : 16, 100),
                          children: provider.children.map((child) {
                            final childGoals = provider.getGoalsForChild(child.id);
                            if (childGoals.isEmpty) return const SizedBox.shrink();
                            return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Padding(
                                padding: EdgeInsets.symmetric(horizontal: 4, vertical: isTV ? 12 : 8),
                                child: Row(children: [
                                  Text(child.avatar.isEmpty ? '\u{1F466}' : child.avatar,
                                    style: TextStyle(fontSize: isTV ? 24 : 20)),
                                  const SizedBox(width: 8),
                                  NeonText(text: child.name, fontSize: isTV ? 20 : 16,
                                    fontWeight: FontWeight.w700, color: Colors.white, glowIntensity: 0.15),
                                  const Spacer(),
                                  NeonText(text: '${child.points} pts', fontSize: isTV ? 18 : 14,
                                    color: primary, glowIntensity: 0.3),
                                ]),
                              ),
                              ...childGoals.map((goal) {
                                final progress = goal.targetPoints > 0
                                  ? (child.points / goal.targetPoints).clamp(0.0, 1.0) : 0.0;
                                final isAchieved = child.points >= goal.targetPoints;
                                final goalColor = isAchieved ? const Color(0xFF00E676) : const Color(0xFF00B0FF);
                                return TvFocusWrapper(
                                  onTap: () => _showGoalActions(context, provider, goal.id, goal.completed),
                                  child: GlassCard(
                                    margin: EdgeInsets.symmetric(horizontal: 0, vertical: isTV ? 6 : 4),
                                    padding: EdgeInsets.all(isTV ? 18 : 14),
                                    borderRadius: 16,
                                    glowColor: isAchieved ? const Color(0xFF00E676) : null,
                                    child: Row(children: [
                                      Container(
                                        width: isTV ? 50 : 42, height: isTV ? 50 : 42,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: goalColor.withOpacity(0.12),
                                          border: Border.all(color: goalColor.withOpacity(0.3)),
                                          boxShadow: [BoxShadow(color: goalColor.withOpacity(0.15), blurRadius: 8)]),
                                        child: Icon(isAchieved ? Icons.check_circle_rounded : Icons.flag_rounded,
                                          color: goalColor, size: isTV ? 26 : 22),
                                      ),
                                      SizedBox(width: isTV ? 14 : 12),
                                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                        Text(goal.title, maxLines: 1, overflow: TextOverflow.ellipsis,
                                          style: TextStyle(fontWeight: FontWeight.w600, fontSize: isTV ? 20 : 15,
                                            color: Colors.white,
                                            decoration: goal.completed ? TextDecoration.lineThrough : null)),
                                        SizedBox(height: isTV ? 8 : 6),
                                        TweenAnimationBuilder<double>(
                                          tween: Tween(begin: 0.0, end: progress),
                                          duration: const Duration(milliseconds: 800),
                                          curve: Curves.easeOutCubic,
                                          builder: (_, v, __) => ClipRRect(
                                            borderRadius: BorderRadius.circular(4),
                                            child: LinearProgressIndicator(value: v,
                                              minHeight: isTV ? 8 : 6,
                                              backgroundColor: Colors.white.withOpacity(0.06),
                                              valueColor: AlwaysStoppedAnimation(goalColor)),
                                          ),
                                        ),
                                        SizedBox(height: isTV ? 6 : 4),
                                        Text('${child.points}/${goal.targetPoints} points',
                                          style: TextStyle(fontSize: isTV ? 16 : 11, color: Colors.grey[500])),
                                      ])),
                                      Icon(Icons.chevron_right, color: Colors.white24, size: isTV ? 28 : 20),
                                    ]),
                                  ),
                                );
                              }),
                              SizedBox(height: isTV ? 16 : 12),
                            ]);
                          }).toList(),
                        ),
                ),
              ]);
            },
          ),
        ),
      ),
    );
  }

  void _showGoalActions(BuildContext context, FamilyProvider provider, String goalId, bool completed) {
    final isTV = TvDetector.isTV;
    showDialog(context: context, builder: (ctx) => AlertDialog(
      backgroundColor: const Color(0xFF1E1E2E),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: EdgeInsets.symmetric(horizontal: isTV ? 120 : 40, vertical: isTV ? 60 : 40),
      title: Text('Actions', style: TextStyle(color: Colors.white, fontSize: isTV ? 24 : 18)),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        TvFocusWrapper(
          autofocus: true,
          onTap: () {
            Navigator.pop(ctx);
            PinGuard.guardAction(context, () => provider.toggleGoal(goalId));
          },
          child: Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(vertical: isTV ? 16 : 12),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.15), borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blue.withOpacity(0.3))),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(completed ? Icons.refresh : Icons.check_circle, color: Colors.blue, size: isTV ? 22 : 18),
              const SizedBox(width: 8),
              Text(completed ? 'Rouvrir' : 'Terminer',
                style: TextStyle(color: Colors.blue, fontSize: isTV ? 18 : 14, fontWeight: FontWeight.bold)),
            ]),
          ),
        ),
        SizedBox(height: isTV ? 12 : 8),
        TvFocusWrapper(
          onTap: () {
            Navigator.pop(ctx);
            PinGuard.guardAction(context, () => provider.removeGoal(goalId));
          },
          child: Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(vertical: isTV ? 16 : 12),
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.15), borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.red.withOpacity(0.3))),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.delete_rounded, color: Colors.red, size: isTV ? 22 : 18),
              const SizedBox(width: 8),
              Text('Supprimer', style: TextStyle(color: Colors.red, fontSize: isTV ? 18 : 14, fontWeight: FontWeight.bold)),
            ]),
          ),
        ),
      ]),
      actions: [
        TvFocusWrapper(
          onTap: () => Navigator.pop(ctx),
          child: TextButton(onPressed: () => Navigator.pop(ctx),
            child: Text('Fermer', style: TextStyle(color: Colors.white54, fontSize: isTV ? 18 : 14))),
        ),
      ],
    ));
  }

  void _showAddGoal(BuildContext context) {
    final provider = context.read<FamilyProvider>();
    final titleCtrl = TextEditingController();
    int targetPoints = 100;
    String? selectedChildId = provider.children.isNotEmpty ? provider.children.first.id : null;
    final primary = Theme.of(context).colorScheme.primary;
    final isTV = TvDetector.isTV;

    showDialog(context: context, builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => AlertDialog(
        backgroundColor: const Color(0xFF0D1B2A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        insetPadding: EdgeInsets.symmetric(horizontal: isTV ? 100 : 24, vertical: isTV ? 30 : 24),
        title: NeonText(text: 'Nouvel objectif', fontSize: isTV ? 24 : 18, color: Colors.white),
        content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
          // Selecteur enfant avec TvFocusWrapper
          Text('Enfant :', style: TextStyle(color: Colors.white70, fontSize: isTV ? 18 : 14)),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8, children: provider.children.map((c) {
            final selected = selectedChildId == c.id;
            return TvFocusWrapper(
              onTap: () => setState(() => selectedChildId = c.id),
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: isTV ? 16 : 12, vertical: isTV ? 10 : 6),
                decoration: BoxDecoration(
                  color: selected ? primary.withOpacity(0.2) : Colors.white.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: selected ? primary : Colors.white24, width: selected ? 2 : 1)),
                child: Text('${c.avatar.isEmpty ? "\u{1F466}" : c.avatar} ${c.name}',
                  style: TextStyle(color: selected ? primary : Colors.white70,
                    fontSize: isTV ? 18 : 14, fontWeight: selected ? FontWeight.bold : FontWeight.normal)),
              ),
            );
          }).toList()),
          SizedBox(height: isTV ? 20 : 14),
          TvTextField(
            controller: titleCtrl,
            style: TextStyle(color: Colors.white, fontSize: isTV ? 18 : 14),
            decoration: InputDecoration(
              labelText: 'Titre de l\'objectif',
              labelStyle: TextStyle(color: Colors.white70, fontSize: isTV ? 16 : 14),
              hintText: 'Ex: Devenir champion',
              hintStyle: TextStyle(color: Colors.white30, fontSize: isTV ? 16 : 14),
              prefixIcon: GlowIcon(icon: Icons.flag, size: isTV ? 24 : 20, color: primary),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14))),
          ),
          SizedBox(height: isTV ? 20 : 14),
          Row(children: [
            Text('Points cibles :', style: TextStyle(color: Colors.white70, fontSize: isTV ? 18 : 14)),
            const Spacer(),
            TvFocusWrapper(
              onTap: () { if (targetPoints > 10) setState(() => targetPoints -= 10); },
              child: Icon(Icons.remove_circle_outline, color: Colors.white54, size: isTV ? 32 : 24),
            ),
            Container(
              padding: EdgeInsets.symmetric(horizontal: isTV ? 20 : 16, vertical: isTV ? 8 : 6),
              decoration: BoxDecoration(
                color: primary.withOpacity(0.12), borderRadius: BorderRadius.circular(10),
                border: Border.all(color: primary.withOpacity(0.2))),
              child: NeonText(text: '$targetPoints', fontSize: isTV ? 24 : 18,
                fontWeight: FontWeight.w800, color: primary),
            ),
            TvFocusWrapper(
              onTap: () => setState(() => targetPoints += 10),
              child: Icon(Icons.add_circle_outline, color: Colors.white54, size: isTV ? 32 : 24),
            ),
          ]),
        ])),
        actions: [
          TvFocusWrapper(onTap: () => Navigator.pop(ctx),
            child: TextButton(onPressed: () => Navigator.pop(ctx),
              child: Text('Annuler', style: TextStyle(fontSize: isTV ? 18 : 14)))),
          TvFocusWrapper(
            onTap: () {
              if (titleCtrl.text.trim().isNotEmpty && selectedChildId != null) {
                provider.addGoal(selectedChildId!, titleCtrl.text.trim(), targetPoints);
                Navigator.pop(ctx);
              }
            },
            child: FilledButton(
              onPressed: () {
                if (titleCtrl.text.trim().isNotEmpty && selectedChildId != null) {
                  provider.addGoal(selectedChildId!, titleCtrl.text.trim(), targetPoints);
                  Navigator.pop(ctx);
                }
              },
              style: FilledButton.styleFrom(
                padding: EdgeInsets.symmetric(horizontal: isTV ? 24 : 16, vertical: isTV ? 14 : 10)),
              child: Text('Cr\u00E9er', style: TextStyle(fontSize: isTV ? 18 : 14)),
            ),
          ),
        ],
      ),
    ));
  }
}

