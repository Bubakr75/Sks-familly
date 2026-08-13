import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/family_provider.dart';
import '../models/pending_request.dart';
import '../widgets/family_join_approval_panel.dart';

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
      case 'boutique':   return 'Achat boutique';
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
      case 'boutique':   return Icons.shopping_bag_rounded;
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
      case 'boutique':   return Colors.amber;
      default:           return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Demandes à valider'),
      ),
      body: SafeArea(
        top: false,
        left: kIsWeb,
        right: kIsWeb,
        bottom: kIsWeb,
        child: Consumer<FamilyProvider>(
          builder: (context, fp, _) {
            // 🔒 Trier par createdAt décroissant sans modifier la liste du provider
            final requests = List<PendingRequest>.from(fp.pendingRequests)
              ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
            final joinPanel =
                (fp.memberRole == 'owner' || fp.memberRole == 'parent') &&
                        fp.familyId != null
                    ? FamilyJoinApprovalPanel(familyId: fp.familyId!)
                    : null;
            return Column(
              children: [
                if (joinPanel != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                    child: joinPanel,
                  ),
                Expanded(
                  child: requests.isEmpty
                      ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle_outline,
                      size: 64, color: Colors.green),
                  const SizedBox(height: 16),
                  Text('Aucune demande en attente',
                      style: TextStyle(fontSize: 16)),
                ],
              ),
                        )
                      : ListView.builder(
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
                                const SizedBox(height: 2),
                                // 📅 Date exacte + ancienneté
                                Text(
                                  '${_formatDate(r.createdAt)} · ${_formatRelative(r.createdAt)}',
                                  style: TextStyle(
                                      color: Colors.grey[500], fontSize: 11),
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
                                : r.type == 'boutique'
                                    ? '${r.amount} points'
                                    : r.type == 'chore_checklist'
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
                            onPressed: () =>
                                _showRequestDetails(context, fp, r),
                            icon: const Icon(Icons.visibility_outlined),
                            label: const Text('Voir le motif'),
                          ),
                          const SizedBox(width: 8),
                          TextButton.icon(
                            onPressed: () => _showRejectDialog(context, fp, r),
                            icon: const Icon(Icons.close, color: Colors.red),
                            label: const Text('Refuser',
                                style: TextStyle(color: Colors.red)),
                          ),
                          const SizedBox(width: 8),
                          // 📺 Bouton spécial : Démarrer le chrono (temps d'écran)
                          if (r.type == 'boutique' &&
                              _isScreenTimeReward(r))
                            ElevatedButton.icon(
                              onPressed: () =>
                                  _startScreenTimeNow(context, fp, r),
                              icon: const Icon(Icons.play_circle_fill),
                              label: const Text('Démarrer chrono'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.teal,
                                foregroundColor: Colors.white,
                              ),
                            )
                          else
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
                        ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  /// Dialogue d'approbation avec modification des points + commentaire
  void _showRequestDetails(
    BuildContext context,
    FamilyProvider provider,
    PendingRequest request,
  ) {
    final childName =
        provider.getChild(request.childId)?.name ?? 'Enfant';

    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('${_typeLabel(request.type)} ? $childName'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Motif',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              SelectableText(
                request.text.trim().isEmpty
                    ? 'Aucun motif indiqu?.'
                    : request.text,
              ),
              if (request.amount > 0) ...[
                const SizedBox(height: 16),
                Text(
                  'Montant : ${request.amount}',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ],
              const SizedBox(height: 12),
              Text('Propos? par ${request.requestedBy}'),
              const SizedBox(height: 4),
              Text(_formatDate(request.createdAt)),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Fermer'),
          ),
        ],
      ),
    );
  }

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

  /// Détecte si une demande boutique concerne du temps d'écran.
  /// Format JJ/MM/AAAA HH:mm
  String _formatDate(DateTime d) {
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year} '
        '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }

  /// Ancienneté lisible : « il y a 5 min », « il y a 2 h », « il y a 3 j »
  String _formatRelative(DateTime d) {
    final diff = DateTime.now().difference(d);
    if (diff.inMinutes < 1) return 'à l\'instant';
    if (diff.inMinutes < 60) return 'il y a ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'il y a ${diff.inHours} h';
    if (diff.inDays == 1) return 'hier';
    return 'il y a ${diff.inDays} j';
  }

  bool _isScreenTimeReward(PendingRequest r) {
    if (r.type != 'boutique') return false;
    final title = (r.extra['rewardTitle'] as String? ?? '').toLowerCase();
    final icon = r.extra['icon'] as String? ?? '';
    return title.contains('écran') ||
        title.contains('ecran') ||
        title.contains('min') ||
        icon == '🎮';
  }

  /// Extrait le nombre de minutes d'un titre de récompense.
  int _extractMinutes(PendingRequest r) {
    final title = r.extra['rewardTitle'] as String? ?? '';
    final match = RegExp(r'(\d+)').firstMatch(title);
    return match != null ? int.tryParse(match.group(1)!) ?? 15 : 15;
  }

  /// Démarre le chrono immédiatement après approbation d'un achat temps d'écran.
  void _startScreenTimeNow(
      BuildContext context, FamilyProvider fp, PendingRequest r) {
    final minutes = _extractMinutes(r);
    final childName = fp.getChild(r.childId)?.name ?? 'l\'enfant';
    final account = fp.getScreenTimeAccount(r.childId);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0F2620),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('📺 Démarrer le chrono',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('$childName veut commencer son temps d\'écran.',
                style: const TextStyle(color: Colors.white70),
                textAlign: TextAlign.center),
            const SizedBox(height: 16),
            // Infos solde
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.teal.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.teal.withValues(alpha: 0.4)),
              ),
              child: Column(children: [
                Text('Solde : ${account.balanceMinutes} min',
                    style: const TextStyle(
                        color: Colors.tealAccent,
                        fontSize: 16,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text('Cette session : $minutes min',
                    style: const TextStyle(color: Colors.white54, fontSize: 13)),
              ]),
            ),
            const SizedBox(height: 12),
            const Text(
                '⚠️ Quand le temps sera écoulé, l\'enfant perdra\n'
                '-10 pts toutes les 5 min jusqu\'à ce qu\'il vienne te voir.',
                style: TextStyle(color: Colors.orangeAccent, fontSize: 11),
                textAlign: TextAlign.center),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler',
                style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal, foregroundColor: Colors.white),
            icon: const Icon(Icons.play_arrow_rounded),
            label: const Text('Démarrer',
                style: TextStyle(fontWeight: FontWeight.bold)),
            onPressed: () async {
              Navigator.pop(ctx);
              // 1. Valider la demande (confirme l'achat)
              await fp.approveRequest(r.id);
              // 2. Démarrer le chrono avec les minutes
              if (!context.mounted) return;
              await fp.startScreenTimeSession(r.childId, minutes);
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                      '📺 Chrono démarré pour $childName ($minutes min).\n'
                      'Pense à vérifier quand le temps est écoulé !'),
                  backgroundColor: Colors.teal,
                  behavior: SnackBarBehavior.floating,
                  duration: const Duration(seconds: 4),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
