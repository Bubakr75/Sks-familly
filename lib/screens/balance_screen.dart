import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/family_provider.dart';
import '../widgets/glass_card.dart';

class BalanceScreen extends StatelessWidget {
  const BalanceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final fp = context.watch<FamilyProvider>();
    final children = fp.children;

    return Scaffold(
      backgroundColor: const Color(0xFF0D1B2A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('⚖️ Punitions vs Immunités',
            style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: children.isEmpty
          ? const Center(child: Text('Aucun enfant enregistré', style: TextStyle(color: Colors.white54)))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: children.length,
              itemBuilder: (_, i) => _buildChildCard(context, fp, children[i]),
            ),
    );
  }

  Widget _buildChildCard(BuildContext context, FamilyProvider fp, dynamic child) {
    // Punitions actives
    final punishments = fp.punishments
        .where((p) => p.childId == child.id && !p.isCompleted)
        .toList();
    final totalPunishLines = punishments.fold<int>(0, (sum, p) => sum + (p.totalLines - p.completedLines));

    // Immunités disponibles
    final immunities = fp.immunities
        .where((im) => im.childId == child.id && !im.isUsed)
        .toList();
    final totalImmunityLines = immunities.fold<int>(0, (sum, im) => sum + im.lines);

    // Balance
    final balance = totalImmunityLines - totalPunishLines;
    final isPositive = balance >= 0;

    return GlassCard(
      margin: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // En-tête enfant
          Row(
            children: [
              CircleAvatar(
                backgroundColor: Colors.purpleAccent.withOpacity(0.3),
                radius: 22,
                child: Text(child.name[0].toUpperCase(),
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(child.name,
                    style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: isPositive ? Colors.green.withOpacity(0.2) : Colors.red.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isPositive ? Colors.green.withOpacity(0.5) : Colors.red.withOpacity(0.5),
                  ),
                ),
                child: Text(
                  isPositive ? '+$balance' : '$balance',
                  style: TextStyle(
                    color: isPositive ? Colors.greenAccent : Colors.redAccent,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Comparaison côte à côte
          Row(
            children: [
              // Punitions
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.redAccent.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.redAccent.withOpacity(0.3)),
                  ),
                  child: Column(
                    children: [
                      const Text('📋', style: TextStyle(fontSize: 28)),
                      const SizedBox(height: 6),
                      const Text('Punitions',
                          style: TextStyle(color: Colors.white60, fontSize: 12, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      Text('$totalPunishLines',
                          style: const TextStyle(
                              color: Colors.redAccent, fontSize: 32, fontWeight: FontWeight.bold)),
                      const Text('lignes restantes',
                          style: TextStyle(color: Colors.white38, fontSize: 11)),
                      const SizedBox(height: 8),
                      const Divider(color: Colors.white12),
                      Text('${punishments.length} punition(s) active(s)',
                          style: const TextStyle(color: Colors.white38, fontSize: 11),
                          textAlign: TextAlign.center),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // VS
              Column(
                children: [
                  const Text('VS', style: TextStyle(color: Colors.white38, fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 8),
                  Icon(
                    isPositive ? Icons.sentiment_satisfied_alt : Icons.sentiment_dissatisfied,
                    color: isPositive ? Colors.greenAccent : Colors.redAccent,
                    size: 28,
                  ),
                ],
              ),
              const SizedBox(width: 12),
              // Immunités
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.greenAccent.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.greenAccent.withOpacity(0.3)),
                  ),
                  child: Column(
                    children: [
                      const Text('🛡️', style: TextStyle(fontSize: 28)),
                      const SizedBox(height: 6),
                      const Text('Immunités',
                          style: TextStyle(color: Colors.white60, fontSize: 12, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      Text('$totalImmunityLines',
                          style: const TextStyle(
                              color: Colors.greenAccent, fontSize: 32, fontWeight: FontWeight.bold)),
                      const Text('lignes dispo',
                          style: TextStyle(color: Colors.white38, fontSize: 11)),
                      const SizedBox(height: 8),
                      const Divider(color: Colors.white12),
                      Text('${immunities.length} immunité(s)',
                          style: const TextStyle(color: Colors.white38, fontSize: 11),
                          textAlign: TextAlign.center),
                    ],
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Barre de progression
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: totalPunishLines == 0 && totalImmunityLines == 0
                  ? 0.5
                  : totalImmunityLines / (totalPunishLines + totalImmunityLines + 1),
              backgroundColor: Colors.redAccent.withOpacity(0.3),
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.greenAccent),
              minHeight: 10,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Punitions', style: TextStyle(color: Colors.redAccent, fontSize: 11)),
              Text(
                isPositive
                    ? '✅ ${child.name} est en avance !'
                    : '⚠️ ${child.name} doit encore travailler',
                style: TextStyle(
                    color: isPositive ? Colors.greenAccent : Colors.orangeAccent,
                    fontSize: 11,
                    fontWeight: FontWeight.w600),
              ),
              const Text('Immunités', style: TextStyle(color: Colors.greenAccent, fontSize: 11)),
            ],
          ),
        ],
      ),
    );
  }
}
