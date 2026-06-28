import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/family_provider.dart';
import '../models/pending_request.dart';

class PendingRequestsScreen extends StatelessWidget {
  const PendingRequestsScreen({super.key});

  String _typeLabel(String type) {
    switch (type) {
      case 'punishment': return 'Pénalité';
      case 'immunity':   return 'Immunité';
      case 'bonus':      return 'Bonus';
      case 'tribunal':   return 'Tribunal';
      default:           return type;
    }
  }

  IconData _typeIcon(String type) {
    switch (type) {
      case 'punishment': return Icons.gavel;
      case 'immunity':   return Icons.shield;
      case 'bonus':      return Icons.star;
      case 'tribunal':   return Icons.balance;
      default:           return Icons.help_outline;
    }
  }

  Color _typeColor(String type) {
    switch (type) {
      case 'punishment': return Colors.red;
      case 'immunity':   return Colors.blue;
      case 'bonus':      return Colors.green;
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
                            onPressed: () async {
                              await fp.rejectRequest(r.id);
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content: Text('Demande refusée')),
                                );
                              }
                            },
                            icon: const Icon(Icons.close, color: Colors.red),
                            label: const Text('Refuser',
                                style: TextStyle(color: Colors.red)),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton.icon(
                            onPressed: () async {
                              await fp.approveRequest(r.id);
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content: Text('Demande approuvée')),
                                );
                              }
                            },
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
}
