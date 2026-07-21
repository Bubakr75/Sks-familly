// lib/widgets/transfer_points_sheet.dart
//
// Transfert express SKS — bottom sheet premium pour transférer des points
// entre deux enfants sans ouvrir d'affaire au tribunal.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/family_provider.dart';
import '../models/child_model.dart';
import '../config/emerald_theme.dart';
import '../utils/pin_guard.dart';

/// Ouvre la bottom sheet de transfert express SKS.
/// 🔒 Sécurité centrale : PinGuard centralise l'autorisation parent.
/// Si aucun PIN n'est configuré, ouvre directement ; sinon demande le PIN.
void showTransferPointsSheet(BuildContext context) {
  PinGuard.guardAction(context, () => _openSheet(context));
}

void _openSheet(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _TransferSheet(),
  );
}

class _TransferSheet extends StatefulWidget {
  const _TransferSheet();

  @override
  State<_TransferSheet> createState() => _TransferSheetState();
}

class _TransferSheetState extends State<_TransferSheet>
    with SingleTickerProviderStateMixin {
  String? _fromChildId;
  String? _toChildId;
  final _amountCtrl = TextEditingController(text: '10');
  String _reason = '';
  String? _customReason;
  bool _processing = false;

  static const _reasonSuggestions = [
    'Injustice pendant un jeu',
    'Moquerie ou provocation',
    'Objet abîmé',
    'Partage non respecté',
    'Gêne répétée',
    'Promesse non tenue',
    'Autre',
  ];

  int get _amount {
    final v = int.tryParse(_amountCtrl.text);
    return v ?? 0;
  }

  bool get _isValid {
    if (_fromChildId == null || _toChildId == null) return false;
    if (_fromChildId == _toChildId) return false;
    final a = _amount;
    if (a < 1 || a > 999) return false;
    final fp = context.read<FamilyProvider>();
    final from = fp.getChild(_fromChildId!);
    if (from == null || from.points < a) return false;
    if (_reason.isEmpty) return false;
    return true;
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    super.dispose();
  }

  Future<void> _confirm() async {
    if (!_isValid || _processing) return;
    setState(() => _processing = true);
    HapticFeedback.mediumImpact();

    // 🔒 Capturer TOUTES les valeurs avant l'appel async
    final fp = context.read<FamilyProvider>();
    final messenger = ScaffoldMessenger.of(context);
    final capturedFromId = _fromChildId!;
    final capturedToId = _toChildId!;
    final capturedAmount = _amount;
    final capturedFromName = fp.getChild(capturedFromId)?.name ?? '';
    final capturedToName = fp.getChild(capturedToId)?.name ?? '';
    final reason = _reason == 'Autre'
        ? (_customReason?.trim().isNotEmpty == true
            ? _customReason!.trim()
            : 'Transfert')
        : _reason;

    final ok = await fp.transferPointsBetweenChildren(
      fromChildId: capturedFromId,
      toChildId: capturedToId,
      amount: capturedAmount,
      reason: reason,
    );

    if (!mounted) return;
    Navigator.pop(context);

    if (ok) {
      HapticFeedback.heavyImpact();
      messenger.showSnackBar(SnackBar(
        content: Text(
            'Transfert effectué\n$capturedAmount points SKS transférés de $capturedFromName vers $capturedToName'),
        backgroundColor: EmeraldPalette.emerald,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
      ));
    } else {
      messenger.showSnackBar(const SnackBar(
        content: Text('Transfert impossible — vérifiez les soldes'),
        backgroundColor: Colors.redAccent,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final fp = context.watch<FamilyProvider>();
    final children = fp.children;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF0F2620),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.9,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle
              Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Title
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                child: Column(
                  children: [
                    const Text('Transfert express SKS',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold)),
                    const SizedBox(height: 2),
                    Text('Transférer des points entre deux enfants',
                        style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.5),
                            fontSize: 13)),
                  ],
                ),
              ),
              const Divider(color: Colors.white12, height: 1),

              // Content scrollable
              Flexible(
                child: IgnorePointer(
                  ignoring: _processing,
                child: SingleChildScrollView(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Source ──
                      _SectionLabel(
                          'Retirer les points à', Colors.orangeAccent),
                      const SizedBox(height: 8),
                      _ChildSelector(
                        children: children,
                        selectedId: _fromChildId,
                        excludeId: _toChildId,
                        accent: Colors.orangeAccent,
                        onSelect: (id) => setState(() => _fromChildId = id),
                      ),

                      const SizedBox(height: 16),

                      // ── Visualisation centrale ──
                      if (_fromChildId != null && _toChildId != null)
                        _TransferVisual(
                          fromChild: fp.getChild(_fromChildId!),
                          toChild: fp.getChild(_toChildId!),
                          amount: _amount,
                        ),

                      // ── Destination ──
                      const SizedBox(height: 16),
                      _SectionLabel('Attribuer les points à',
                          EmeraldPalette.emeraldLight),
                      const SizedBox(height: 8),
                      _ChildSelector(
                        children: children,
                        selectedId: _toChildId,
                        excludeId: _fromChildId,
                        accent: EmeraldPalette.emeraldLight,
                        onSelect: (id) => setState(() => _toChildId = id),
                      ),

                      const SizedBox(height: 20),

                      // ── Montant ──
                      _SectionLabel('Montant', EmeraldPalette.gold),
                      const SizedBox(height: 8),
                      _AmountEditor(
                        controller: _amountCtrl,
                        maxAmount: _fromChildId != null
                            ? (fp.getChild(_fromChildId!)?.points ?? 0)
                            : 999,
                        onChanged: () => setState(() {}),
                      ),

                      const SizedBox(height: 20),

                      // ── Motif ──
                      _SectionLabel(
                          'Pourquoi effectuer ce transfert ?', Colors.white70),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _reasonSuggestions.map((r) {
                          final isSel = _reason == r;
                          return GestureDetector(
                            onTap: () => setState(() => _reason = r),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: isSel
                                    ? EmeraldPalette.emerald
                                        .withValues(alpha: 0.2)
                                    : Colors.white.withValues(alpha: 0.05),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                    color: isSel
                                        ? EmeraldPalette.emerald
                                        : Colors.white12),
                              ),
                              child: Text(r,
                                  style: TextStyle(
                                      color: isSel
                                          ? EmeraldPalette.emeraldLight
                                          : Colors.white54,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600)),
                            ),
                          );
                        }).toList(),
                      ),
                      if (_reason == 'Autre') ...[
                        const SizedBox(height: 8),
                        TextField(
                          onChanged: (v) => setState(() => _customReason = v),
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            hintText: 'Précisez le motif...',
                            hintStyle: const TextStyle(color: Colors.white24),
                            filled: true,
                            fillColor: Colors.white.withValues(alpha: 0.05),
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide.none),
                          ),
                        ),
                      ],

                      const SizedBox(height: 20),

                      // ── Aperçu ──
                      if (_fromChildId != null && _toChildId != null)
                        _PreviewCard(
                          fromChild: fp.getChild(_fromChildId!),
                          toChild: fp.getChild(_toChildId!),
                          amount: _amount,
                        ),
                    ],
                  ),
                ),
                ), // fin IgnorePointer
              ),

              // ── Bouton confirmer ──
              Padding(
                padding: const EdgeInsets.all(20),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          _isValid ? EmeraldPalette.emerald : Colors.white12,
                      foregroundColor: const Color(0xFF051410),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: _isValid && !_processing ? _confirm : null,
                    icon: _processing
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.swap_horiz_rounded),
                    label: Text(
                      _processing ? 'Transfert...' : 'Confirmer le transfert',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Widgets utilitaires ───────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String text;
  final Color color;
  const _SectionLabel(this.text, this.color);

  @override
  Widget build(BuildContext context) {
    return Text(text,
        style:
            TextStyle(color: color, fontSize: 14, fontWeight: FontWeight.w700));
  }
}

class _ChildSelector extends StatelessWidget {
  final List<ChildModel> children;
  final String? selectedId;
  final String? excludeId;
  final Color accent;
  final ValueChanged<String> onSelect;

  const _ChildSelector({
    required this.children,
    required this.selectedId,
    required this.excludeId,
    required this.accent,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final fp = context.read<FamilyProvider>();
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: children.where((c) => c.id != excludeId).map((c) {
        final isSel = c.id == selectedId;
        return GestureDetector(
          onTap: () => onSelect(c.id),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isSel
                  ? accent.withValues(alpha: 0.15)
                  : Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: isSel ? accent : Colors.white12,
                  width: isSel ? 1.5 : 1),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Text(c.avatar.isNotEmpty ? c.avatar : '👤',
                  style: const TextStyle(fontSize: 18)),
              const SizedBox(width: 6),
              Text(c.name,
                  style: TextStyle(
                      color: isSel ? accent : Colors.white70,
                      fontSize: 13,
                      fontWeight: FontWeight.w600)),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text('${fp.getChild(c.id)?.points ?? 0} pts',
                    style: TextStyle(
                        color: accent,
                        fontSize: 10,
                        fontWeight: FontWeight.w600)),
              ),
            ]),
          ),
        );
      }).toList(),
    );
  }
}

class _TransferVisual extends StatelessWidget {
  final ChildModel? fromChild;
  final ChildModel? toChild;
  final int amount;
  const _TransferVisual(
      {required this.fromChild, required this.toChild, required this.amount});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _MiniAvatar(fromChild, Colors.orangeAccent),
          const SizedBox(width: 12),
          Icon(Icons.arrow_forward_rounded,
              color: EmeraldPalette.gold.withValues(alpha: 0.6), size: 28),
          const SizedBox(width: 12),
          _MiniAvatar(toChild, EmeraldPalette.emeraldLight),
        ],
      ),
    );
  }
}

class _MiniAvatar extends StatelessWidget {
  final ChildModel? child;
  final Color color;
  const _MiniAvatar(this.child, this.color);

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color.withValues(alpha: 0.15),
            border: Border.all(color: color.withValues(alpha: 0.4), width: 2),
          ),
          child: Center(
            child: Text(child?.avatar.isNotEmpty == true ? child!.avatar : '👤',
                style: const TextStyle(fontSize: 20)),
          ),
        ),
        const SizedBox(height: 2),
        Text(child?.name ?? '',
            style: TextStyle(
                color: color, fontSize: 11, fontWeight: FontWeight.w600)),
      ],
    );
  }
}

class _AmountEditor extends StatelessWidget {
  final TextEditingController controller;
  final int maxAmount;
  final VoidCallback onChanged;
  const _AmountEditor(
      {required this.controller,
      required this.maxAmount,
      required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              onPressed: () {
                final cur = int.tryParse(controller.text) ?? 1;
                if (cur > 1) {
                  controller.text = '${cur - 1}';
                  onChanged();
                }
              },
              icon: const Icon(Icons.remove_circle_outline,
                  color: Colors.white54),
            ),
            SizedBox(
              width: 100,
              child: TextField(
                controller: controller,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: EmeraldPalette.gold,
                    fontSize: 24,
                    fontWeight: FontWeight.w900),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: EmeraldPalette.gold.withValues(alpha: 0.1),
                  contentPadding: const EdgeInsets.symmetric(vertical: 8),
                  isDense: true,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(
                          color: EmeraldPalette.gold.withValues(alpha: 0.4))),
                ),
                onChanged: (_) => onChanged(),
              ),
            ),
            IconButton(
              onPressed: () {
                final cur = int.tryParse(controller.text) ?? 1;
                if (cur < 999 && cur < maxAmount) {
                  controller.text = '${cur + 1}';
                  onChanged();
                }
              },
              icon: const Icon(Icons.add_circle_outline, color: Colors.white54),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          children: [5, 10, 15, 20, 25, 50].map((v) {
            return GestureDetector(
              onTap: () {
                if (v <= maxAmount) {
                  controller.text = '$v';
                  onChanged();
                }
              },
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: EmeraldPalette.gold.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: EmeraldPalette.gold.withValues(alpha: 0.2)),
                ),
                child: Text('$v',
                    style: TextStyle(
                        color: EmeraldPalette.gold.withValues(alpha: 0.8),
                        fontSize: 12,
                        fontWeight: FontWeight.w600)),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

class _PreviewCard extends StatelessWidget {
  final ChildModel? fromChild;
  final ChildModel? toChild;
  final int amount;
  const _PreviewCard(
      {required this.fromChild, required this.toChild, required this.amount});

  @override
  Widget build(BuildContext context) {
    if (fromChild == null || toChild == null) return const SizedBox.shrink();
    final fromNew = fromChild!.points - amount;
    final toNew = toChild!.points + amount;
    final insufficient = fromChild!.points < amount;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: insufficient
                ? Colors.redAccent.withValues(alpha: 0.4)
                : EmeraldPalette.glassBorder),
      ),
      child: Column(
        children: [
          _PreviewRow(
            emoji: fromChild!.avatar.isNotEmpty ? fromChild!.avatar : '👤',
            name: fromChild!.name,
            oldPoints: fromChild!.points,
            newPoints: fromNew,
            color: Colors.orangeAccent,
          ),
          const SizedBox(height: 8),
          _PreviewRow(
            emoji: toChild!.avatar.isNotEmpty ? toChild!.avatar : '👤',
            name: toChild!.name,
            oldPoints: toChild!.points,
            newPoints: toNew,
            color: EmeraldPalette.emeraldLight,
          ),
          if (insufficient) ...[
            const SizedBox(height: 8),
            const Text('⚠️ Solde insuffisant',
                style: TextStyle(
                    color: Colors.redAccent,
                    fontSize: 12,
                    fontWeight: FontWeight.w600),
                textAlign: TextAlign.center),
          ],
        ],
      ),
    );
  }
}

class _PreviewRow extends StatelessWidget {
  final String emoji;
  final String name;
  final int oldPoints;
  final int newPoints;
  final Color color;
  const _PreviewRow(
      {required this.emoji,
      required this.name,
      required this.oldPoints,
      required this.newPoints,
      required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 18)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(name,
              style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                  fontWeight: FontWeight.w600)),
        ),
        Text('$oldPoints',
            style: TextStyle(color: Colors.white38, fontSize: 14)),
        const SizedBox(width: 6),
        Icon(Icons.arrow_forward_rounded,
            color: color.withValues(alpha: 0.5), size: 14),
        const SizedBox(width: 6),
        Text('$newPoints',
            style: TextStyle(
                color: color, fontSize: 16, fontWeight: FontWeight.w800)),
      ],
    );
  }
}
