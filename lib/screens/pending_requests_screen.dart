import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/family_provider.dart';
import '../models/pending_request.dart';

class PendingRequestsScreen extends StatelessWidget {
  const PendingRequestsScreen({super.key});

  String _typeLabel(String type) {
    switch (type) {
      case 'punishment': return 'Punition';
      case 'penalty':    return 'Pénalité';
      case 'immunity':   return 'Immunité';
      case 'bonus':      return 'Bonus';
      case 'chore_checklist': return 'Tâches du jour';
      case 'tribunal':   return 'Tribunal';
      default:           return type;
    }
  }

  IconData _typeIcon(String type) {
    switch (type) {
      case 'punishment': return Icons.gavel;
      case 'penalty':    return Icons.warning;
      case 'immunity':   return Icons.shield;
      case 'bonus':      return Icons.star;
      case 'chore_checklist': return Icons.checklist_rounded;
      case 'tribunal':   return Icons.balance;
      default:           return Icons.help_outline;
    }
  }

  Color _typeColor(String type) {
    switch (type) {
      case 'punishment': return Colors.red;
      case 'penalty':    return Colors.orange;
      case 'immunity':   return Colors.blue;
      case 'bonus':      return Colors.green;
      case 'chore_checklist': return Colors.teal;
      case 'tribunal':   return Colors.purple;
      default:           return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Demandes à valider'),
      ),
      body: Consumer<FamilyProvider>(
        builder: (context, fp, _) {
          final requests = fp.pendingRequests;
          if (requests.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle_outline,
                      size: 64, color: Colors.green),
                  SizedBox(height: 16),
                  Text('Aucune demande en attente',
                      style: TextStyle(fontSize: 16)),
                ],
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: requests.length,
            itemBuilder: (context, index) {
              final PendingRequest r = requests[index];
              final child = fp.getChild(r.childId);
              final childName = child?.name ?? 'Enfant';
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            backgroundColor:
                                _typeColor(r.type).withValues(alpha: 0.2),
                            child: Icon(_typeIcon(r.type),
                                color: _typeColor(r.type)),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${_typeLabel(r.type)} • $childName',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15),
                                ),
                                Text(
                                  'Proposé par ${r.requestedBy}',
                                  style: TextStyle(
                                      color: Colors.grey[600], fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(r.text),
                      if (r.amount > 0)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            r.type == 'bonus'
                                ? '${r.amount} points'
                                : '${r.amount} ligne${r.amount > 1 ? 's' : ''}',
                            style: const TextStyle(
                                fontWeight: FontWeight.w600),
                          ),
                        ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton.icon(
                            onPressed: () => _showRejectDialog(context, fp, r),
                            icon: const Icon(Icons.close, color: Colors.red),
                            label: const Text('Refuser',
                                style: TextStyle(color: Colors.red)),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton.icon(
                            onPressed: () => _showApproveDialog(context, fp, r),
                            icon: const Icon(Icons.check),
                            label: const Text('Approuver'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  /// Dialogue d'approbation avec modification des points + commentaire
  void _showApproveDialog(BuildContext context, FamilyProvider fp, PendingRequest r) {
    final amountCtrl = TextEditingController(text: r.amount.toString());
    final commentCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0F2620),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Valider la demande', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Enfant : ${fp.getChild(r.childId)?.name ?? "?"}', style: const TextStyle(color: Colors.white70)),
            const SizedBox(height: 12),
            Row(
              children: [
                const Text('Points : ', style: TextStyle(color: Colors.white70)),
                Expanded(
                  child: TextField(
                    controller: amountCtrl,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.stars_rounded, color: Color(0xFFD4AF37)),
                      filled: true,
                      fillColor: Colors.white.withValues(alpha: 0.06),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: commentCtrl,
              style: const TextStyle(color: Colors.white),
              maxLines: 2,
              decoration: InputDecoration(
                labelText: 'Commentaire (optionnel)',
                labelStyle: const TextStyle(color: Colors.white54),
                hintText: 'Ex: Bravo ! Continue comme ça',
                hintStyle: const TextStyle(color: Colors.white24),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.06),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler', style: TextStyle(color: Colors.white54))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
            onPressed: () async {
              final amount = int.tryParse(amountCtrl.text.trim()) ?? r.amount;
              Navigator.pop(ctx);
              await fp.approveRequest(r.id, customAmount: amount, comment: commentCtrl.text.trim());
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('✅ Validé ! +$amount pts'), backgroundColor: Colors.green),
                );
              }
            },
            child: const Text('Valider', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  /// Dialogue de refus avec message pour l'enfant
  void _showRejectDialog(BuildContext context, FamilyProvider fp, PendingRequest r) {
    final reasonCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0F2620),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Refuser la demande', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Un message sera envoyé à ${fp.getChild(r.childId)?.name ?? "l'enfant"}.', style: const TextStyle(color: Colors.white70, fontSize: 13)),
            const SizedBox(height: 12),
            TextField(
              controller: reasonCtrl,
              style: const TextStyle(color: Colors.white),
              maxLines: 2,
              decoration: InputDecoration(
                labelText: 'Raison du refus',
                labelStyle: const TextStyle(color: Colors.white54),
                hintText: 'Ex: Tu as déjà eu ton bonus aujourd\'hui',
                hintStyle: const TextStyle(color: Colors.white24),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.06),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler', style: TextStyle(color: Colors.white54))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
            onPressed: () async {
              Navigator.pop(ctx);
              await fp.rejectRequest(r.id, reason: reasonCtrl.text.trim());
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('❌ Demande refusée, message envoyé.'), backgroundColor: Colors.redAccent),
                );
              }
            },
            child: const Text('Refuser', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
