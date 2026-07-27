import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../config/emerald_theme.dart';
import '../models/child_model.dart';
import '../models/sks_wallet.dart';
import '../providers/family_provider.dart';
import '../providers/pin_provider.dart';

@visibleForTesting
bool canManageSksWallet({
  required String? memberRole,
  required bool isParentMode,
}) {
  return isParentMode && (memberRole == 'owner' || memberRole == 'parent');
}

class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  String? _selectedChildId;

  @override
  Widget build(BuildContext context) {
    final family = context.watch<FamilyProvider>();
    final pin = context.watch<PinProvider>();
    final visibleChildren = family.memberRole == 'child'
        ? family.children
            .where((child) => child.id == family.memberChildId)
            .toList()
        : family.children;

    if (visibleChildren.isNotEmpty &&
        !visibleChildren.any((child) => child.id == _selectedChildId)) {
      _selectedChildId = visibleChildren.first.id;
    }

    ChildModel? selectedChild;
    for (final child in visibleChildren) {
      if (child.id == _selectedChildId) selectedChild = child;
    }
    final canManage = canManageSksWallet(
      memberRole: family.memberRole,
      isParentMode: pin.isParentMode,
    );

    return Scaffold(
      backgroundColor: EmeraldPalette.background,
      appBar: AppBar(
        title: const Text('💰 Cagnotte SKS'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: selectedChild == null
          ? const Center(
              child: Text('Aucun enfant disponible',
                  style: TextStyle(color: Colors.white54)),
            )
          : Column(
              children: [
                if (visibleChildren.length > 1) _childSelector(visibleChildren),
                _walletHeader(
                  selectedChild,
                  family.getWalletForChild(selectedChild.id),
                  canManage,
                ),
                Expanded(
                  child: _operationHistory(family, selectedChild.id),
                ),
              ],
            ),
    );
  }

  Widget _childSelector(List<ChildModel> children) {
    return SizedBox(
      height: 64,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        scrollDirection: Axis.horizontal,
        itemCount: children.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, index) {
          final child = children[index];
          final selected = child.id == _selectedChildId;
          return ChoiceChip(
            selected: selected,
            label: Text('${child.avatar} ${child.name}'),
            onSelected: (_) => setState(() => _selectedChildId = child.id),
            selectedColor: EmeraldPalette.emerald,
            backgroundColor: Colors.white.withValues(alpha: 0.08),
            labelStyle:
                TextStyle(color: selected ? Colors.white : Colors.white70),
          );
        },
      ),
    );
  }

  Widget _walletHeader(
    ChildModel child,
    SksWallet wallet,
    bool canManage,
  ) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: EmeraldPalette.emerald.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: EmeraldPalette.gold.withValues(alpha: 0.45)),
      ),
      child: Column(
        children: [
          Text(child.name,
              style: const TextStyle(color: Colors.white70, fontSize: 16)),
          const SizedBox(height: 6),
          Text(
            '${wallet.balance} points SKS',
            style: const TextStyle(
              color: EmeraldPalette.gold,
              fontSize: 32,
              fontWeight: FontWeight.w900,
            ),
          ),
          if (canManage) ...[
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _showAdjustmentDialog(child, 'credit'),
                    icon: const Icon(Icons.add_circle_rounded),
                    label: const Text('Ajouter'),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: EmeraldPalette.emerald),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: wallet.balance > 0
                        ? () => _showAdjustmentDialog(child, 'debit')
                        : null,
                    icon: const Icon(Icons.remove_circle_rounded),
                    label: const Text('Retirer'),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red.shade700),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _operationHistory(FamilyProvider family, String childId) {
    return StreamBuilder<List<SksWalletOperation>>(
      stream: family.watchWalletOperations(childId),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Center(
            child: Text('Historique indisponible',
                style: TextStyle(color: Colors.redAccent)),
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final operations = snapshot.data!;
        if (operations.isEmpty) {
          return const Center(
            child: Text('Aucune opération',
                style: TextStyle(color: Colors.white38)),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          itemCount: operations.length,
          separatorBuilder: (_, __) => const Divider(color: Colors.white12),
          itemBuilder: (_, index) {
            final operation = operations[index];
            final isCredit = operation.delta > 0;
            return ListTile(
              leading: Icon(
                isCredit
                    ? Icons.add_circle_rounded
                    : Icons.remove_circle_rounded,
                color: isCredit ? Colors.greenAccent : Colors.redAccent,
              ),
              title: Text(operation.reason,
                  style: const TextStyle(color: Colors.white)),
              subtitle: Text(
                DateFormat('dd/MM/yyyy à HH:mm').format(operation.createdAt),
                style: const TextStyle(color: Colors.white38),
              ),
              trailing: Text(
                '${isCredit ? '+' : ''}${operation.delta}',
                style: TextStyle(
                  color: isCredit ? Colors.greenAccent : Colors.redAccent,
                  fontWeight: FontWeight.bold,
                  fontSize: 17,
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _showAdjustmentDialog(
    ChildModel child,
    String type,
  ) async {
    final reasonController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    var amount = 1;
    var submitting = false;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: EmeraldPalette.surface,
              title: Text(
                type == 'credit'
                    ? 'Ajouter à ${child.name}'
                    : 'Retirer à ${child.name}',
                style: const TextStyle(color: Colors.white),
              ),
              content: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      initialValue: '$amount',
                      enabled: !submitting,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Montant',
                        suffixText: 'points SKS',
                      ),
                      validator: (value) {
                        final parsed = int.tryParse(value?.trim() ?? '');
                        if (parsed == null || parsed < 1 || parsed > 100000) {
                          return 'Entre 1 et 100 000';
                        }
                        return null;
                      },
                      onSaved: (value) => amount = int.parse(value!.trim()),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: reasonController,
                      enabled: !submitting,
                      maxLength: 200,
                      decoration:
                          const InputDecoration(labelText: 'Motif obligatoire'),
                      validator: (value) {
                        if ((value?.trim() ?? '').isEmpty) {
                          return 'Indiquez un motif';
                        }
                        return null;
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed:
                      submitting ? null : () => Navigator.pop(dialogContext),
                  child: const Text('Annuler'),
                ),
                ElevatedButton(
                  onPressed: submitting
                      ? null
                      : () async {
                          if (!formKey.currentState!.validate()) return;
                          formKey.currentState!.save();
                          setDialogState(() => submitting = true);
                          try {
                            await context.read<FamilyProvider>().adjustWallet(
                                  childId: child.id,
                                  type: type,
                                  amount: amount,
                                  reason: reasonController.text,
                                );
                            if (dialogContext.mounted) {
                              Navigator.pop(dialogContext);
                            }
                          } on FirebaseFunctionsException catch (error) {
                            if (!dialogContext.mounted) return;
                            ScaffoldMessenger.of(this.context).showSnackBar(
                              SnackBar(
                                content: Text(error.message ??
                                    'Impossible de modifier la cagnotte'),
                                backgroundColor: Colors.redAccent,
                              ),
                            );
                            setDialogState(() => submitting = false);
                          } catch (_) {
                            if (dialogContext.mounted) {
                              setDialogState(() => submitting = false);
                            }
                          }
                        },
                  child: Text(submitting ? 'Validation...' : 'Valider'),
                ),
              ],
            );
          },
        );
      },
    );
    reasonController.dispose();
  }
}
