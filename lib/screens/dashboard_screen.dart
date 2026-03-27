import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/family_provider.dart';
import '../providers/pin_provider.dart';
import '../models/child_model.dart';
import '../utils/pin_guard.dart';
import '../widgets/animated_background.dart';
import '../widgets/glass_card.dart';
import '../widgets/tv_focus_wrapper.dart';
import 'manage_children_screen.dart';
import 'punishment_lines_screen.dart';
import 'immunity_lines_screen.dart';
import 'screen_time_screen.dart';
import 'school_notes_screen.dart';
import 'child_dashboard_screen.dart';
import 'tribunal_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    )..forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  String _formatMinutes(int minutes) {
    final h = minutes ~/ 60;
    final m = minutes % 60;
    if (h > 0 && m > 0) return '${h}h${m.toString().padLeft(2, '0')}';
    if (h > 0) return '${h}h';
    return '${m}min';
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<FamilyProvider>(
      builder: (context, provider, _) {
        final children = provider.children;
        final pendingTrades = provider.trades.where((t) => t.status == 'pending').toList();

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildQuickActions(context),
              const SizedBox(height: 20),
              if (pendingTrades.isNotEmpty) ...[
                const Text('Echanges en cours', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                SizedBox(
                  height: 120,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: pendingTrades.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 12),
                    itemBuilder: (context, index) => _buildInteractiveTradeCard(pendingTrades[index], provider),
                  ),
                ),
                const SizedBox(height: 20),
              ],
              if (children.isEmpty)
                GlassCard(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(children: [
                      const Icon(Icons.family_restroom, size: 64, color: Colors.white24),
                      const SizedBox(height: 16),
                      const Text('Aucun enfant enregistre', style: TextStyle(color: Colors.white54, fontSize: 16)),
                      const SizedBox(height: 16),
                      TvFocusWrapper(
                        onTap: () => PinGuard.guardNavigation(context, const ManageChildrenScreen()),
                        child: ElevatedButton.icon(
                          onPressed: () => PinGuard.guardNavigation(context, const ManageChildrenScreen()),
                          icon: const Icon(Icons.add),
                          label: const Text('Ajouter un enfant'),
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.cyanAccent.shade700, foregroundColor: Colors.white),
                        ),
                      ),
                    ]),
                  ),
                )
              else
                ...children.map((child) => _buildChildCard(child, provider)),
              const SizedBox(height: 24),
              TvFocusWrapper(
                onTap: () => _showFullHistory(provider),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(color: Colors.white.withOpacity(0.06), borderRadius: BorderRadius.circular(14), border: Border.all(color: Colors.white12)),
                  child: const Center(child: Text('Voir l\'historique complet', style: TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.w600))),
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        );
      },
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    final actions = [
      _QuickAction('Enfants', Icons.people, Colors.cyanAccent, () => PinGuard.guardNavigation(context, const ManageChildrenScreen())),
      _QuickAction('Punitions', Icons.gavel, Colors.redAccent, () => PinGuard.guardNavigation(context, const PunishmentLinesScreen())),
      _QuickAction('Immunites', Icons.shield, Colors.greenAccent, () => PinGuard.guardNavigation(context, const ImmunityLinesScreen())),
      _QuickAction('Ecran', Icons.tv, Colors.purpleAccent, () => PinGuard.guardNavigation(context, const ScreenTimeScreen())),
      _QuickAction('Notes', Icons.school, Colors.orangeAccent, () => _showSchoolNotesChildPicker()),
      _QuickAction('Tribunal', Icons.balance, Colors.amberAccent, () => PinGuard.guardNavigation(context, const TribunalScreen())),
    ];

    return SizedBox(
      height: 90,
      child: ListView.separated(
        scrollDirection: Axis.horizontal, itemCount: actions.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final action = actions[index];
          return TvFocusWrapper(
            autofocus: index == 0, onTap: action.onTap,
            child: Container(
              width: 90, padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(color: action.color.withOpacity(0.1), borderRadius: BorderRadius.circular(16), border: Border.all(color: action.color.withOpacity(0.3))),
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(action.icon, color: action.color, size: 28), const SizedBox(height: 6),
                Text(action.label, style: TextStyle(color: action.color, fontSize: 11, fontWeight: FontWeight.w600), textAlign: TextAlign.center),
              ]),
            ),
          );
        },
      ),
    );
  }

  Widget _buildInteractiveTradeCard(dynamic trade, FamilyProvider provider) {
    final fromChild = provider.getChild(trade.fromChildId);
    final fromName = fromChild?.name ?? 'Inconnu';
    return TvFocusWrapper(
      onTap: () => _showTradeDetail(trade, provider),
      child: Container(
        width: 200, padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(gradient: LinearGradient(colors: [Colors.orangeAccent.withOpacity(0.15), Colors.amber.withOpacity(0.05)]), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.orangeAccent.withOpacity(0.3))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Row(children: [const Icon(Icons.swap_horiz, color: Colors.orangeAccent, size: 18), const SizedBox(width: 6),
            Expanded(child: Text(trade.serviceDescription ?? 'Echange', style: const TextStyle(color: Colors.orangeAccent, fontWeight: FontWeight.w600, fontSize: 13), overflow: TextOverflow.ellipsis))]),
          Text('De: $fromName', style: const TextStyle(color: Colors.white70, fontSize: 12)),
          Text(trade.status ?? 'En attente', style: const TextStyle(color: Colors.white38, fontSize: 11)),
        ]),
      ),
    );
  }

  void _showTradeDetail(dynamic trade, FamilyProvider provider) {
    final fromChild = provider.getChild(trade.fromChildId);
    final fromName = fromChild?.name ?? 'Inconnu';
    showModalBottomSheet(
      context: context, backgroundColor: Colors.grey[900],
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('Detail de l\'echange', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          _infoRow('Service', trade.serviceDescription ?? 'N/A'),
          _infoRow('De', fromName),
          _infoRow('Lignes', '${trade.immunityLines ?? 0}'),
          _infoRow('Statut', trade.status ?? 'En attente'),
          const SizedBox(height: 20),
          Row(children: [
            Expanded(child: TvFocusWrapper(onTap: () { provider.cancelTrade(trade.id); Navigator.pop(ctx); },
              child: OutlinedButton(onPressed: () { provider.cancelTrade(trade.id); Navigator.pop(ctx); },
                style: OutlinedButton.styleFrom(foregroundColor: Colors.redAccent, side: const BorderSide(color: Colors.redAccent)), child: const Text('Annuler')))),
            const SizedBox(width: 12),
            Expanded(child: TvFocusWrapper(onTap: () { provider.acceptTrade(trade.id); Navigator.pop(ctx); },
              child: ElevatedButton(onPressed: () { provider.acceptTrade(trade.id); Navigator.pop(ctx); },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.greenAccent.shade700), child: const Text('Accepter')))),
          ]),
        ]),
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label, style: const TextStyle(color: Colors.white54)),
        Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
      ]),
    );
  }

  Widget _buildChildCard(ChildModel child, FamilyProvider provider) {
    final satMinutes = provider.getSaturdayMinutes(child.id);
    final schoolAvg = provider.getWeeklySchoolAverage(child.id);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TvFocusWrapper(
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ChildDashboardScreen(childId: child.id))),
        child: GlassCard(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(children: [
              Row(children: [
                CircleAvatar(radius: 24, backgroundColor: Colors.cyanAccent.withOpacity(0.3),
                  child: Text(child.avatar.isNotEmpty ? child.avatar : (child.name.isNotEmpty ? child.name[0].toUpperCase() : '?'),
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20))),
                const SizedBox(width: 14),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(child.name, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
                  Text(child.levelTitle, style: const TextStyle(color: Colors.white54, fontSize: 13)),
                ])),
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Text('${child.points}', style: const TextStyle(color: Colors.cyanAccent, fontSize: 24, fontWeight: FontWeight.bold)),
                  const Text('points', style: TextStyle(color: Colors.white38, fontSize: 11)),
                ]),
              ]),
              const SizedBox(height: 12),
              const Divider(color: Colors.white12, height: 1),
              const SizedBox(height: 12),
              Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
                _buildScreenTimeMini(satMinutes),
                _buildWeekNotesMini(schoolAvg),
              ]),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _buildScreenTimeMini(int minutes) {
    return Column(children: [
      const Icon(Icons.tv, color: Colors.purpleAccent, size: 20), const SizedBox(height: 4),
      Text(_formatMinutes(minutes), style: const TextStyle(color: Colors.purpleAccent, fontWeight: FontWeight.bold, fontSize: 13)),
      const Text('Ecran sam.', style: TextStyle(color: Colors.white38, fontSize: 10)),
    ]);
  }

  Widget _buildWeekNotesMini(double avg) {
    final displayText = avg < 0 ? '--' : '${avg.toStringAsFixed(1)}/20';
    return Column(children: [
      const Icon(Icons.school, color: Colors.orangeAccent, size: 20), const SizedBox(height: 4),
      Text(displayText, style: const TextStyle(color: Colors.orangeAccent, fontWeight: FontWeight.bold, fontSize: 13)),
      const Text('Moy. sem.', style: TextStyle(color: Colors.white38, fontSize: 10)),
    ]);
  }

  void _showSchoolNotesChildPicker() {
    final provider = context.read<FamilyProvider>();
    final children = provider.children;
    if (children.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Aucun enfant enregistre'), backgroundColor: Colors.orangeAccent));
      return;
    }
    if (children.length == 1) {
      PinGuard.guardNavigation(context, SchoolNotesScreen(childId: children.first.id));
      return;
    }
    showModalBottomSheet(
      context: context, backgroundColor: Colors.transparent, isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.45, minChildSize: 0.3, maxChildSize: 0.7,
        builder: (context, scrollController) => Container(
          decoration: BoxDecoration(color: Colors.grey[900]?.withOpacity(0.95), borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
          child: Column(children: [
            const SizedBox(height: 12),
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 16),
            const Text('Notes scolaires - Choisir un enfant', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Expanded(child: ListView.builder(
              controller: scrollController, itemCount: children.length, padding: const EdgeInsets.symmetric(horizontal: 16),
              itemBuilder: (context, index) {
                final child = children[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: TvFocusWrapper(autofocus: index == 0,
                    onTap: () { Navigator.pop(context); PinGuard.guardNavigation(this.context, SchoolNotesScreen(childId: child.id)); },
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(color: Colors.white.withOpacity(0.06), borderRadius: BorderRadius.circular(14), border: Border.all(color: Colors.white12)),
                      child: Row(children: [
                        CircleAvatar(radius: 20, backgroundColor: Colors.orangeAccent.withOpacity(0.3),
                          child: Text(child.avatar.isNotEmpty ? child.avatar : (child.name.isNotEmpty ? child.name[0].toUpperCase() : '?'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                        const SizedBox(width: 12),
                        Expanded(child: Text(child.name, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600))),
                        const Icon(Icons.chevron_right, color: Colors.white38),
                      ]),
                    ),
                  ),
                );
              },
            )),
          ]),
        ),
      ),
    );
  }

  void _showFullHistory(FamilyProvider provider) {
    final allHistory = provider.history;
    showModalBottomSheet(
      context: context, backgroundColor: Colors.transparent, isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.7, minChildSize: 0.4, maxChildSize: 0.95,
        builder: (context, scrollController) => Container(
          decoration: BoxDecoration(color: Colors.grey[900]?.withOpacity(0.95), borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
          child: Column(children: [
            const SizedBox(height: 12),
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 16),
            const Text('Historique complet', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Expanded(child: allHistory.isEmpty
              ? const Center(child: Text('Aucune activite', style: TextStyle(color: Colors.white38)))
              : ListView.builder(
                  controller: scrollController, itemCount: allHistory.length, padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemBuilder: (context, index) {
                    final h = allHistory[index];
                    final child = provider.getChild(h.childId);
                    final childName = child?.name ?? 'Inconnu';
                    return TvFocusWrapper(onTap: () => _showHistoryDetail(h, provider),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 8), padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(color: Colors.white.withOpacity(0.04), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white10)),
                        child: Row(children: [
                          Icon(h.isBonus ? Icons.add_circle_outline : Icons.remove_circle_outline, color: h.isBonus ? Colors.greenAccent : Colors.redAccent, size: 20),
                          const SizedBox(width: 10),
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(h.reason, style: const TextStyle(color: Colors.white, fontSize: 14), maxLines: 1, overflow: TextOverflow.ellipsis),
                            Text(childName, style: const TextStyle(color: Colors.white38, fontSize: 11)),
                          ])),
                          Text('${h.isBonus ? '+' : '-'}${h.points}', style: TextStyle(color: h.isBonus ? Colors.greenAccent : Colors.redAccent, fontWeight: FontWeight.bold)),
                        ]),
                      ),
                    );
                  },
                )),
          ]),
        ),
      ),
    );
  }

  void _showHistoryDetail(dynamic h, FamilyProvider provider) {
    final child = provider.getChild(h.childId);
    final childName = child?.name ?? 'Inconnu';
    showDialog(context: context, builder: (ctx) => AlertDialog(
      backgroundColor: Colors.grey[900],
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(children: [
        Icon(h.isBonus ? Icons.thumb_up_rounded : Icons.thumb_down_rounded, color: h.isBonus ? Colors.greenAccent : Colors.redAccent, size: 22),
        const SizedBox(width: 10),
        Expanded(child: Text(h.reason, style: const TextStyle(color: Colors.white, fontSize: 16))),
      ]),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        _infoRow('Enfant', childName),
        _infoRow('Points', '${h.isBonus ? '+' : '-'}${h.points}'),
        _infoRow('Categorie', h.category),
        _infoRow('Date', '${h.date.day.toString().padLeft(2, '0')}/${h.date.month.toString().padLeft(2, '0')}/${h.date.year}'),
        if (h.actionBy != null && h.actionBy!.isNotEmpty) _infoRow('Par', h.actionBy!),
      ]),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Fermer', style: TextStyle(color: Colors.cyanAccent)))],
    ));
  }
}

class _QuickAction {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  _QuickAction(this.label, this.icon, this.color, this.onTap);
}
