import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/family_provider.dart';
import '../widgets/animated_background.dart';
import '../widgets/glass_card.dart';
import '../widgets/tv_focus_wrapper.dart';

class PunishmentLinesScreen extends StatefulWidget {
  const PunishmentLinesScreen({super.key});

  @override
  State<PunishmentLinesScreen> createState() => _PunishmentLinesScreenState();
}

class _PunishmentLinesScreenState extends State<PunishmentLinesScreen> {
  void _showAddPunishment() {
    final provider = context.read<FamilyProvider>();
    final children = provider.children;
    String? selectedChildId;
    String reason = '';
    int lines = 10;
    final reasonController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return DraggableScrollableSheet(
              initialChildSize: 0.7,
              minChildSize: 0.5,
              maxChildSize: 0.9,
              builder: (context, scrollController) {
                return Container(
                  decoration: BoxDecoration(
                    color: Colors.grey[900]?.withOpacity(0.95),
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                  ),
                  child: ListView(
                    controller: scrollController,
                    padding: const EdgeInsets.all(20),
                    children: [
                      Center(
                        child: Container(
                          width: 40, height: 4,
                          decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text('Nouvelle punition',
                          style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center),
                      const SizedBox(height: 24),
                      const Text('Enfant', style: TextStyle(color: Colors.white70, fontSize: 14)),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8, runSpacing: 8,
                        children: children.map((child) {
                          final isSelected = selectedChildId == child.id;
                          return TvFocusWrapper(
                            autofocus: children.first.id == child.id,
                            onTap: () => setModalState(() => selectedChildId = child.id),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                              decoration: BoxDecoration(
                                color: isSelected ? Colors.redAccent.withOpacity(0.2) : Colors.white.withOpacity(0.06),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: isSelected ? Colors.redAccent : Colors.white24),
                              ),
                              child: Text(child.name,
                                  style: TextStyle(
                                      color: isSelected ? Colors.redAccent : Colors.white70,
                                      fontWeight: FontWeight.w600)),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 20),
                      const Text('Raison', style: TextStyle(color: Colors.white70, fontSize: 14)),
                      const SizedBox(height: 8),
                      TextField(
                        controller: reasonController,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: 'Ex: Insolence, bagarre...',
                          hintStyle: const TextStyle(color: Colors.white38),
                          filled: true, fillColor: Colors.white.withOpacity(0.06),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                          focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: const BorderSide(color: Colors.redAccent)),
                        ),
                        onChanged: (val) => reason = val,
                      ),
                      const SizedBox(height: 20),
                      const Text('Nombre de lignes', style: TextStyle(color: Colors.white70, fontSize: 14)),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          TvFocusWrapper(
                            onTap: () { if (lines > 1) setModalState(() => lines--); },
                            child: Container(
                              width: 44, height: 44,
                              decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withOpacity(0.1), border: Border.all(color: Colors.white24)),
                              child: const Icon(Icons.remove, color: Colors.white70),
                            ),
                          ),
                          const SizedBox(width: 24),
                          Text('$lines', style: const TextStyle(color: Colors.redAccent, fontSize: 36, fontWeight: FontWeight.bold)),
                          const SizedBox(width: 24),
                          TvFocusWrapper(
                            onTap: () { if (lines < 100) setModalState(() => lines++); },
                            child: Container(
                              width: 44, height: 44,
                              decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withOpacity(0.1), border: Border.all(color: Colors.white24)),
                              child: const Icon(Icons.add, color: Colors.white70),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [5, 10, 20, 50].map((val) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: OutlinedButton(
                              onPressed: () => setModalState(() => lines = val),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: lines == val ? Colors.redAccent : Colors.white54,
                                side: BorderSide(color: lines == val ? Colors.redAccent : Colors.white24),
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                              ),
                              child: Text('$val'),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 28),
                      SizedBox(
                        width: double.infinity, height: 52,
                        child: TvFocusWrapper(
                          onTap: () {
                            if (selectedChildId == null || reason.isEmpty) {
                              ScaffoldMessenger.of(ctx).showSnackBar(
                                const SnackBar(content: Text('Selectionnez un enfant et une raison'), backgroundColor: Colors.orangeAccent),
                              );
                              return;
                            }
                            provider.addPunishment(selectedChildId!, reason, lines);
                            Navigator.pop(ctx);
                            ScaffoldMessenger.of(this.context).showSnackBar(
                              SnackBar(content: Text('$lines ligne(s) de punition ajoutee(s)'), backgroundColor: Colors.redAccent),
                            );
                          },
                          child: ElevatedButton.icon(
                            onPressed: () {
                              if (selectedChildId == null || reason.isEmpty) {
                                ScaffoldMessenger.of(ctx).showSnackBar(
                                  const SnackBar(content: Text('Selectionnez un enfant et une raison'), backgroundColor: Colors.orangeAccent),
                                );
                                return;
                              }
                              provider.addPunishment(selectedChildId!, reason, lines);
                              Navigator.pop(ctx);
                              ScaffoldMessenger.of(this.context).showSnackBar(
                                SnackBar(content: Text('$lines ligne(s) de punition ajoutee(s)'), backgroundColor: Colors.redAccent),
                              );
                            },
                            icon: const Icon(Icons.gavel),
                            label: const Text('Creer la punition', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.redAccent.shade700,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(title: const Text('Lignes de punition'), backgroundColor: Colors.transparent, elevation: 0),
        floatingActionButton: TvFocusWrapper(
          onTap: _showAddPunishment,
          child: FloatingActionButton.extended(
            onPressed: _showAddPunishment,
            backgroundColor: Colors.redAccent.shade700,
            icon: const Icon(Icons.add),
            label: const Text('Ajouter'),
          ),
        ),
        body: Consumer<FamilyProvider>(
          builder: (context, provider, _) {
            final children = provider.children;
            if (children.isEmpty) {
              return const Center(child: Text('Aucun enfant enregistre', style: TextStyle(color: Colors.white54)));
            }
            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: children.length,
              itemBuilder: (context, index) {
                final child = children[index];
                final punishments = provider.punishments.where((p) => p.childId == child.id).toList();
                return GlassCard(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          CircleAvatar(radius: 20, backgroundColor: Colors.redAccent.withOpacity(0.3),
                            child: Text(child.name.isNotEmpty ? child.name[0].toUpperCase() : '?',
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                          const SizedBox(width: 12),
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(child.name, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
                            Text('${punishments.length} punition(s)', style: const TextStyle(color: Colors.white54, fontSize: 13)),
                          ])),
                        ]),
                        if (punishments.isEmpty)
                          const Padding(padding: EdgeInsets.only(top: 12), child: Text('Aucune punition', style: TextStyle(color: Colors.white38)))
                        else ...[
                          const SizedBox(height: 12),
                          ...punishments.map((p) {
                            final isDone = p.isCompleted;
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 6),
                              child: TvFocusWrapper(
                                onTap: () => _showPunishmentDetail(p, child, provider),
                                child: Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: (isDone ? Colors.greenAccent : Colors.redAccent).withOpacity(0.06),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: (isDone ? Colors.greenAccent : Colors.redAccent).withOpacity(0.2)),
                                  ),
                                  child: Row(children: [
                                    Icon(isDone ? Icons.check_circle : Icons.pending,
                                        color: isDone ? Colors.greenAccent : Colors.redAccent, size: 20),
                                    const SizedBox(width: 10),
                                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                      Text(p.text, style: const TextStyle(color: Colors.white, fontSize: 14), maxLines: 1, overflow: TextOverflow.ellipsis),
                                      Text(isDone ? 'Termine' : '${p.completedLines}/${p.totalLines} lignes',
                                          style: TextStyle(color: isDone ? Colors.greenAccent : Colors.white38, fontSize: 11)),
                                    ])),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(color: Colors.redAccent.withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
                                      child: Text('${p.totalLines}L',
                                          style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 12)),
                                    ),
                                    const SizedBox(width: 4),
                                    const Icon(Icons.chevron_right, color: Colors.white24, size: 18),
                                  ]),
                                ),
                              ),
                            );
                          }),
                        ],
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  void _showPunishmentDetail(dynamic punishment, dynamic child, FamilyProvider provider) {
    final isDone = punishment.isCompleted;
    showModalBottomSheet(
      context: context, backgroundColor: Colors.transparent, isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.45, minChildSize: 0.3, maxChildSize: 0.7,
        builder: (context, scrollController) => Container(
          decoration: BoxDecoration(
            color: Colors.grey[900]?.withOpacity(0.95),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.all(20),
            children: [
              Center(child: Container(width: 40, height: 4,
                  decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 16),
              Text(punishment.text, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              _detailRow('Enfant', child.name),
              _detailRow('Lignes', '${punishment.completedLines}/${punishment.totalLines}'),
              _detailRow('Statut', isDone ? 'Termine' : 'En cours',
                  valueColor: isDone ? Colors.greenAccent : Colors.redAccent),
              if (punishment.createdAt != null)
                _detailRow('Date',
                    '${punishment.createdAt.day.toString().padLeft(2, '0')}/${punishment.createdAt.month.toString().padLeft(2, '0')}/${punishment.createdAt.year}'),
              const SizedBox(height: 24),
              if (!isDone)
                Row(children: [
                  Expanded(
                    child: TvFocusWrapper(
                      onTap: () { provider.removePunishment(punishment.id); Navigator.pop(ctx); setState(() {}); },
                      child: OutlinedButton.icon(
                        onPressed: () { provider.removePunishment(punishment.id); Navigator.pop(ctx); setState(() {}); },
                        icon: const Icon(Icons.delete_outline, size: 18),
                        label: const Text('Supprimer'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.redAccent,
                          side: const BorderSide(color: Colors.redAccent),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TvFocusWrapper(
                      onTap: () {
                        final remaining = punishment.totalLines - punishment.completedLines;
                        provider.updatePunishmentProgress(punishment.id, remaining);
                        Navigator.pop(ctx);
                        setState(() {});
                      },
                      child: ElevatedButton.icon(
                        onPressed: () {
                          final remaining = punishment.totalLines - punishment.completedLines;
                          provider.updatePunishmentProgress(punishment.id, remaining);
                          Navigator.pop(ctx);
                          setState(() {});
                        },
                        icon: const Icon(Icons.check_circle, size: 18),
                        label: const Text('Terminer'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.greenAccent.shade700,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ),
                ]),
            ],
          ),
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label, style: const TextStyle(color: Colors.white54, fontSize: 14)),
        Text(value, style: TextStyle(color: valueColor ?? Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
      ]),
    );
  }
}
