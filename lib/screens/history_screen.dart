import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/family_provider.dart';
import '../models/history_entry.dart';
import '../widgets/animated_background.dart';
import '../widgets/glass_card.dart';

class HistoryScreen extends StatefulWidget {
  final String childId;
  const HistoryScreen({super.key, required this.childId});
  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  String _filter = 'tous';

  @override
  Widget build(BuildContext context) {
    return Consumer<FamilyProvider>(
      builder: (context, fp, _) {
        final child = fp.getChild(widget.childId);
        var entries = fp.getHistoryForChild(widget.childId);

        if (_filter == 'bonus') {
          entries = entries.where((e) => e.isBonus).toList();
        } else if (_filter == 'penalite') {
          entries = entries.where((e) => !e.isBonus).toList();
        }

        entries.sort((a, b) => b.date.compareTo(a.date));

        return AnimatedBackground(
          child: Scaffold(
            backgroundColor: Colors.transparent,
            appBar: AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              title: Text(
                '📋 Historique — ${child?.name ?? ''}',
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
            body: Column(
              children: [
                _buildFilterBar(),
                Expanded(
                  child: entries.isEmpty
                      ? const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text('📭', style: TextStyle(fontSize: 48)),
                              SizedBox(height: 12),
                              Text('Aucune entrée',
                                  style: TextStyle(
                                      color: Colors.white54, fontSize: 16)),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: entries.length,
                          itemBuilder: (_, i) => _buildEntryCard(entries[i]),
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildFilterBar() {
    final filters = [
      ('tous', '📋 Tous'),
      ('bonus', '✅ Bonus'),
      ('penalite', '❌ Pénalités'),
    ];
    return Container(
      height: 52,
      color: Colors.black12,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        children: filters.map((f) {
          final isSelected = _filter == f.$1;
          return GestureDetector(
            onTap: () => setState(() => _filter = f.$1),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                gradient: isSelected
                    ? const LinearGradient(
                        colors: [Color(0xFF7C4DFF), Color(0xFF00BCD4)])
                    : null,
                color: isSelected ? null : Colors.white10,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color: isSelected ? Colors.transparent : Colors.white24),
              ),
              child: Text(f.$2,
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: isSelected
                          ? FontWeight.bold
                          : FontWeight.normal,
                      fontSize: 13)),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildEntryCard(HistoryEntry entry) {
    final isBonus = entry.isBonus;
    final color = isBonus ? Colors.greenAccent : Colors.redAccent;
    final sign = isBonus ? '+' : '-';

    return GlassCard(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withOpacity(0.15),
              border: Border.all(color: color.withOpacity(0.4)),
            ),
            child: Center(
              child: Text(
                isBonus ? '⭐' : '⚠️',
                style: const TextStyle(fontSize: 18),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.reason ?? 'Sans raison',
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 14),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.access_time,
                        color: Colors.white38, size: 12),
                    const SizedBox(width: 4),
                    Text(
                      _formatDateTime(entry.date),
                      style: const TextStyle(
                          color: Colors.white38, fontSize: 11),
                    ),
                    if (entry.actionBy != null &&
                        entry.actionBy!.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      const Icon(Icons.person_outline,
                          color: Colors.white24, size: 12),
                      const SizedBox(width: 2),
                      Text(entry.actionBy!,
                          style: const TextStyle(
                              color: Colors.white24, fontSize: 11)),
                    ],
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: color.withOpacity(0.4)),
            ),
            child: Text(
              '$sign${entry.points} pts',
              style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                  fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDateTime(DateTime d) {
    final date =
        '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
    final time =
        '${d.hour.toString().padLeft(2, '0')}h${d.minute.toString().padLeft(2, '0')}';
    return '$date à $time';
  }
}
