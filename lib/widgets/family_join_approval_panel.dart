import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/family_provider.dart';

class FamilyJoinApprovalPanel extends StatelessWidget {
  const FamilyJoinApprovalPanel({
    required this.familyId,
    super.key,
  });

  final String familyId;

  Future<void> _review({
    required BuildContext context,
    required String requesterUid,
    required bool approve,
    String? childId,
  }) async {
    try {
      final functionName = approve ? 'approveFamilyJoin' : 'rejectFamilyJoin';

      final callable = FirebaseFunctions.instance.httpsCallable(
        functionName,
      );

      await callable.call({
        'familyId': familyId,
        'requesterUid': requesterUid,
        if (childId != null) 'childId': childId,
      });

      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            approve
                ? 'Demande approuvée. L’iPhone peut se connecter.'
                : 'Demande refusée.',
          ),
          backgroundColor: const Color(0xFF00C853),
        ),
      );
    } on FirebaseFunctionsException catch (error) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error.message ?? 'Impossible de traiter cette demande.',
          ),
          backgroundColor: const Color(0xFFFF1744),
        ),
      );
    }
  }

  Future<void> _approveChild(
    BuildContext context,
    String requesterUid,
  ) async {
    final children = context.read<FamilyProvider>().children;
    if (children.isEmpty) return;
    final childId = await showDialog<String>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        title: const Text('Choisir le profil enfant'),
        children: children
            .map((child) => SimpleDialogOption(
                  onPressed: () => Navigator.pop(dialogContext, child.id),
                  child: Text('${child.avatar} ${child.name}'),
                ))
            .toList(),
      ),
    );
    if (childId == null || !context.mounted) return;
    await _review(
      context: context,
      requesterUid: requesterUid,
      approve: true,
      childId: childId,
    );
  }

  @override
  Widget build(BuildContext context) {
    final requests = FirebaseFirestore.instance
        .collection('families')
        .doc(familyId)
        .collection('join_requests')
        .snapshots();

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: requests,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Impossible de charger les demandes.',
                style: TextStyle(color: Colors.orange),
              ),
            ),
          );
        }

        if (!snapshot.hasData) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: CircularProgressIndicator(),
            ),
          );
        }

        const activeStatuses = {'pending', 'sending', 'sent', 'received'};
        final documents = snapshot.data!.docs.where((document) {
          final status =
              (document.data()['status'] as String? ?? 'pending').toLowerCase();
          return activeStatuses.contains(status);
        }).toList();

        if (documents.isEmpty) {
          return const SizedBox.shrink();
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Demandes en attente',
              style: TextStyle(
                color: Colors.orange,
                fontSize: 15,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            ...documents.map((document) {
              final data = document.data();
              final role =
                  (data['requestedRole'] as String? ?? '').toLowerCase();
              final deviceName = (data['deviceName'] as String? ?? '').trim();
              final isParent = role == 'parent';

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        deviceName.isEmpty ? 'Nouvel appareil' : deviceName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        isParent
                            ? 'Demande comme parent'
                            : 'Demande comme enfant',
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => _review(
                                context: context,
                                requesterUid: document.id,
                                approve: false,
                              ),
                              icon: const Icon(Icons.close_rounded),
                              label: const Text('Refuser'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: FilledButton.icon(
                              onPressed: isParent
                                  ? () => _review(
                                        context: context,
                                        requesterUid: document.id,
                                        approve: true,
                                      )
                                  : () => _approveChild(context, document.id),
                              icon: const Icon(Icons.check_rounded),
                              label: const Text('Approuver'),
                            ),
                          ),
                        ],
                      ),
                      if (!isParent) ...[
                        const SizedBox(height: 8),
                        const Text(
                          'Le profil enfant doit être sélectionné '
                          'avant approbation.',
                          style: TextStyle(
                            color: Colors.orange,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            }),
          ],
        );
      },
    );
  }
}
