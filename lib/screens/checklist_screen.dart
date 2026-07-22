// lib/screens/checklist_screen.dart
//
// Checklist du jour — refonte v2 :
// • Sélection multiple d'enfants (clique les avatars)
// • Chaque tâche a 3 boutons : ✅ Fait · ➖ Non noté · ❌ Pas fait
// • "Non noté" = aucune pénalité, aucun bonus (peut-être fait par un autre)
// • Un seul bouton "Valider" pour tous les enfants sélectionnés

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/family_provider.dart';
import '../providers/pin_provider.dart';
import '../models/child_model.dart';
import '../models/chore_model.dart';
import '../config/emerald_theme.dart';
import '../utils/checklist_helpers.dart';

class ChecklistScreen extends StatefulWidget {
  const ChecklistScreen({super.key});

  @override
  State<ChecklistScreen> createState() => _ChecklistScreenState();
}

/// État d'une tâche pour la session en cours.
enum _ChoreState { pending, done, skipped, missed }

/// Résultat de validation par enfant (mode enfant uniquement).
enum _ChildValidationResult { created, duplicate, failed, noTasks }

class _ChecklistScreenState extends State<ChecklistScreen> {
  /// Enfants sélectionnés pour la notation (multiples)
  final Set<String> _selectedChildIds = {};

  /// Enfant actuellement affiché (celui dont on voit les tâches)
  String? _focusedChildId;

  /// (childId, choreId) -> état
  /// Clé combinée pour gérer plusieurs enfants indépendamment
  final Map<String, _ChoreState> _states = {};

  /// childId -> validé aujourd'hui
  final Set<String> _validatedToday = {};

  /// 🔒 Verrou anti-double-traitement pour la validation
  bool _isSubmittingChecklist = false;

  /// Vérifie si une demande chore_checklist pending existe déjà pour
  /// cet enfant et ce jour (persistance après redémarrage).
  bool _hasPendingChecklistRequest(FamilyProvider fp, String childId) {
    final today = DateTime.now();
    final todayStr =
        '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
    return fp.pendingRequests.any((r) =>
        r.type == 'chore_checklist' &&
        r.status == 'pending' &&
        r.childId == childId &&
        (r.extra['requestDate'] as String?) == todayStr);
  }

  /// Vérifie si l'enfant focalisé a une demande pending aujourd'hui.
  bool _hasPendingForFocusedChild(FamilyProvider fp) {
    if (_focusedChildId == null) return false;
    return _hasPendingChecklistRequest(fp, _focusedChildId!);
  }

  /// Calcule la requestKey pour un enfant donné à partir de ses tâches done.
  String? _computeKeyForChild(FamilyProvider fp, String childId) {
    final chores = fp.chores.where((c) => c.isActive).toList();
    final doneStates = <String, String>{};
    const allSlots = ['matin', 'midi', 'soir'];
    for (final c in chores) {
      final slots = c.timeSlots ?? allSlots;
      for (final slot in slots) {
        final state = _getState(childId, c.id, slot);
        if (state == _ChoreState.done) {
          doneStates['$childId|${c.id}|$slot'] = 'done';
        }
      }
    }
    if (doneStates.isEmpty) return null;
    return buildChecklistRequestKey(
      childId: childId,
      dateStr: todayDateStr(),
      chores: chores,
      doneStates: doneStates,
    );
  }

  /// Vérifie si la requestKey exacte de l'enfant focalisé est déjà pending.
  bool _isExactKeyPending(FamilyProvider fp) {
    if (_focusedChildId == null) return false;
    final key = _computeKeyForChild(fp, _focusedChildId!);
    if (key == null) return false;
    return fp.pendingRequests.any((r) =>
        r.status == 'pending' &&
        (r.extra['requestKey'] as String?)?.trim() == key);
  }

  /// 🔒 Multi-enfants : le bouton Valider reste visible si au moins un enfant
  /// sélectionné avec des tâches done n'a pas sa clé exacte déjà pending.
  bool _allSelectedKeysPending(FamilyProvider fp) {
    for (final cid in _selectedChildIds) {
      final key = _computeKeyForChild(fp, cid);
      if (key == null) continue; // pas de tâche done → ignore
      final isPending = fp.pendingRequests.any((r) =>
          r.status == 'pending' &&
          (r.extra['requestKey'] as String?)?.trim() == key);
      if (!isPending) return false; // au moins un peut encore envoyer
    }
    return true;
  }

  /// Clé combinée : childId|choreId|slot (pour dissocier matin/midi/soir)
  String _key(String childId, String choreId, String slot) =>
      '$childId|$choreId|$slot';

  _ChoreState _getState(String childId, String choreId, String slot) {
    return _states[_key(childId, choreId, slot)] ?? _ChoreState.pending;
  }

  void _setState(String childId, String choreId, String slot, _ChoreState s) {
    final k = _key(childId, choreId, slot);
    // Toggle : re-cliquer sur le même état → revient à pending
    if (_states[k] == s) {
      _states[k] = _ChoreState.pending;
    } else {
      _states[k] = s;
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final fp = context.watch<FamilyProvider>();
    final pin = context.watch<PinProvider>();
    final isParent = pin.isParentMode;
    final children = fp.children;
    final chores = fp.chores.where((c) => c.isActive).toList();

    chores.sort((a, b) => (a.order ?? 0).compareTo(b.order ?? 0));

    // Initialise les sélections
    if (children.isNotEmpty) {
      _selectedChildIds.removeWhere((id) => !children.any((c) => c.id == id));
      if (_selectedChildIds.isEmpty) {
        _selectedChildIds.add(children.first.id);
      }
      if (_focusedChildId == null ||
          !children.any((c) => c.id == _focusedChildId)) {
        _focusedChildId = children.first.id;
      }
    }

    final focusedChild = fp.getChild(_focusedChildId ?? '');

    return Scaffold(
      backgroundColor: EmeraldPalette.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text('Checklist du jour',
            style: TextStyle(
                color: EmeraldPalette.textPrimary,
                fontWeight: FontWeight.bold)),
        iconTheme: const IconThemeData(color: EmeraldPalette.textPrimary),
        actions: [
          if (isParent)
            IconButton(
              icon: const Icon(Icons.add_circle_rounded,
                  color: EmeraldPalette.emerald, size: 28),
              onPressed: () => _showAddChoreDialog(context, fp),
            ),
        ],
      ),
      body: children.isEmpty
          ? const Center(
              child: Text('Aucun enfant enregistré',
                  style: TextStyle(color: Colors.white54)))
          : IgnorePointer(
              ignoring: _isSubmittingChecklist,
              child: Column(
              children: [
                // ── Sélecteur d'enfants (avatars, sélection multiple) ──
                if (children.length >= 1)
                  SizedBox(
                    height: 84,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      itemCount: children.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 10),
                      itemBuilder: (_, i) {
                        final c = children[i];
                        final isSel = _selectedChildIds.contains(c.id);
                        final isFocused = c.id == _focusedChildId;
                        return GestureDetector(
                          // Tap court = sélectionner ce enfant (multi)
                          onTap: () {
                            setState(() {
                              if (_selectedChildIds.contains(c.id)) {
                                if (_selectedChildIds.length > 1) {
                                  _selectedChildIds.remove(c.id);
                                }
                              } else {
                                _selectedChildIds.add(c.id);
                              }
                              _focusedChildId = c.id;
                            });
                          },
                          // Long press = focus seul cet enfant
                          onLongPress: () {
                            setState(() {
                              _selectedChildIds
                                ..clear()
                                ..add(c.id);
                              _focusedChildId = c.id;
                              HapticFeedback.selectionClick();
                            });
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: isFocused
                                  ? EmeraldPalette.emerald
                                      .withValues(alpha: 0.22)
                                  : isSel
                                      ? EmeraldPalette.emerald
                                          .withValues(alpha: 0.10)
                                      : Colors.white.withValues(alpha: 0.04),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isFocused
                                    ? EmeraldPalette.emerald
                                    : isSel
                                        ? EmeraldPalette.emerald
                                            .withValues(alpha: 0.5)
                                        : Colors.white12,
                                width: isFocused ? 2.5 : (isSel ? 1.5 : 1),
                              ),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Stack(
                                  clipBehavior: Clip.none,
                                  children: [
                                    Text(
                                      c.avatar.isNotEmpty ? c.avatar : '👤',
                                      style: const TextStyle(fontSize: 24),
                                    ),
                                    if (isSel)
                                      Positioned(
                                        right: -4,
                                        top: -4,
                                        child: Container(
                                          padding: const EdgeInsets.all(2),
                                          decoration: const BoxDecoration(
                                            color: EmeraldPalette.emerald,
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(Icons.check,
                                              color: Color(0xFF051410),
                                              size: 10),
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(c.name,
                                    style: TextStyle(
                                      color: isSel
                                          ? EmeraldPalette.emeraldLight
                                          : Colors.white70,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    )),
                                Text('${c.points} pts',
                                    style: const TextStyle(
                                        color: EmeraldPalette.gold,
                                        fontSize: 10)),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                // ── Bandeau info sélection ──
                if (_selectedChildIds.length > 1)
                  Container(
                    margin: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 2),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: EmeraldPalette.emerald.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.group_rounded,
                            color: EmeraldPalette.emeraldLight, size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '${_selectedChildIds.length} enfants sélectionnés — notation groupée',
                            style: const TextStyle(
                                color: EmeraldPalette.emeraldLight,
                                fontSize: 12,
                                fontWeight: FontWeight.w600),
                          ),
                        ),
                        GestureDetector(
                          onTap: () => setState(() {
                            // Sélectionner RÉELLEMENT tous les enfants
                            _selectedChildIds.clear();
                            _selectedChildIds.addAll(children.map((c) => c.id));
                            _focusedChildId = children.isNotEmpty ? children.first.id : null;
                          }),
                          child: const Text('Tous',
                              style: TextStyle(
                                  color: EmeraldPalette.emerald,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  ),

                // ── Compteur résumé (enfant focus) ──
                if (focusedChild != null)
                  _buildSummary(focusedChild, chores),

                // ── Légende des 3 états ──
                if (chores.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _legendDot(EmeraldPalette.emerald, 'Fait (+pts)'),
                        const SizedBox(width: 12),
                        _legendDot(Colors.grey, 'Non noté'),
                        const SizedBox(width: 12),
                        _legendDot(Colors.redAccent, 'Pas fait (−pts)'),
                      ],
                    ),
                  ),

                // ── Liste des tâches ──
                Expanded(
                  child: chores.isEmpty
                      ? const Center(
                          child: Padding(
                            padding: EdgeInsets.all(24),
                            child: Text(
                              'Aucune tâche. Le parent peut en ajouter avec le bouton +',
                              style: TextStyle(
                                  color: Colors.white38, fontSize: 13),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        )
                      : _buildChoreGroups(
                          focusedChild!, chores, isParent, fp),
                ),

                // ── Bouton Valider ──
                // 🔒 Masqué uniquement si la requestKey exacte est déjà pending
                if (_anyDecision() && !_allValidated() && !_allSelectedKeysPending(fp))
                  _buildValidateButton(children, chores),
                if (_allValidated() && _selectedChildIds.isNotEmpty)
                  _buildValidatedBanner(),
                // 🔒 Bandeau informatif si une demande du jour est pending
                if (_hasPendingForFocusedChild(fp))
                  Container(
                    margin: const EdgeInsets.all(16),
                    padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF7C4DFF).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFF7C4DFF).withValues(alpha: 0.4), width: 1.5),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.hourglass_top_rounded, color: Color(0xFF7C4DFF), size: 20),
                        SizedBox(width: 8),
                        Text('Validation demandée — en attente du parent',
                            style: TextStyle(color: Color(0xFFB39DDB), fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ),
              ],
            ), // fin Column
            ), // fin IgnorePointer global
    );
  }

  bool _anyDecision() {
    return _selectedChildIds.any((cid) => _states.entries
        .where((e) => e.key.startsWith('$cid|'))
        .any((e) => e.value != _ChoreState.pending));
  }

  bool _allValidated() {
    if (_selectedChildIds.isEmpty) return false;
    return _selectedChildIds.every((cid) => _validatedToday.contains(cid));
  }

  // ─── Carte résumé ──────────────────────────────────────────────
  Widget _legendDot(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8, height: 8,
          decoration: BoxDecoration(shape: BoxShape.circle, color: color),
        ),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(color: Colors.white38, fontSize: 10)),
      ],
    );
  }

  Widget _buildSummary(ChildModel child, List<ChoreModel> chores) {
    int donePts = 0, missedPts = 0;
    int doneCount = 0, missedCount = 0, skippedCount = 0;
    const allSlots = ['matin', 'midi', 'soir'];
    for (final c in chores) {
      // Scanner chaque slot où la tâche est prévue
      final slots = c.timeSlots ?? allSlots;
      for (final slot in slots) {
        final s = _getState(child.id, c.id, slot);
        switch (s) {
          case _ChoreState.done:
            donePts += c.points;
            doneCount++;
            break;
          case _ChoreState.missed:
            missedPts += (c.points ~/ 2).clamp(1, 10);
            missedCount++;
            break;
          case _ChoreState.skipped:
            skippedCount++;
            break;
          case _ChoreState.pending:
            break;
        }
      }
    }
    final net = donePts - missedPts;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [
          net >= 0
              ? const Color(0xFFD4AF37)
              : Colors.redAccent.withValues(alpha: 0.6),
          net >= 0
              ? const Color(0xFFB8860B)
              : Colors.redAccent.withValues(alpha: 0.3),
        ]),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _summaryChip('✅', '$doneCount', '+$donePts', Colors.green.shade900),
          Container(width: 1, height: 26, color: Colors.black26),
          _summaryChip('➖', '$skippedCount', 'skip', Colors.black54),
          Container(width: 1, height: 26, color: Colors.black26),
          _summaryChip(
              '❌', '$missedCount', '-$missedPts', Colors.red.shade900),
          Container(width: 1, height: 26, color: Colors.black26),
          _summaryChip(
              '⚖️', '', '${net >= 0 ? '+' : ''}$net', Colors.black87),
        ],
      ),
    );
  }

  Widget _summaryChip(String emoji, String count, String value, Color c) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(emoji, style: const TextStyle(fontSize: 16)),
        const SizedBox(height: 2),
        if (count.isNotEmpty)
          Text(count,
              style: TextStyle(
                  color: c.withValues(alpha: 0.7), fontSize: 10)),
        Text(value,
            style:
                TextStyle(color: c, fontSize: 14, fontWeight: FontWeight.w900)),
      ],
    );
  }

  // ─── Tâches regroupées par moment ──────────────────────────────
  Widget _buildChoreGroups(
      ChildModel child, List<ChoreModel> chores, bool isParent, FamilyProvider fp) {
    final groups = <String, List<ChoreModel>>{};
    for (final c in chores) {
      final slots = c.timeSlots ?? ['matin', 'midi', 'soir'];
      for (final s in slots) {
        groups.putIfAbsent(s, () => []).add(c);
      }
    }
    const order = ['matin', 'midi', 'soir'];
    final keys = groups.keys.toList()
      ..sort((a, b) => order.indexOf(a).compareTo(order.indexOf(b)));

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      children: [
        for (final slot in keys) ...[
          _buildSlotHeader(slot),
          const SizedBox(height: 6),
          for (final chore in groups[slot]!)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _ChoreDecisionCard(
                chore: chore,
                state: _getState(child.id, chore.id, slot),
                isParent: isParent,
                onDone: () {
                  HapticFeedback.selectionClick();
                  _setState(child.id, chore.id, slot, _ChoreState.done);
                  _propagate(child.id, chore.id, slot, _ChoreState.done);
                },
                onSkipped: () {
                  HapticFeedback.selectionClick();
                  _setState(child.id, chore.id, slot, _ChoreState.skipped);
                  _propagate(child.id, chore.id, slot, _ChoreState.skipped);
                },
                onMissed: () {
                  HapticFeedback.selectionClick();
                  _setState(child.id, chore.id, slot, _ChoreState.missed);
                  _propagate(child.id, chore.id, slot, _ChoreState.missed);
                },
                onDelete: isParent
                    ? () => _confirmDeleteChore(context, fp, chore)
                    : null,
              ),
            ),
          const SizedBox(height: 8),
        ],
      ],
    );
  }

  /// Propage l'état aux autres enfants sélectionnés (notation groupée).
  void _propagate(String focusChildId, String choreId, String slot, _ChoreState s) {
    if (_selectedChildIds.length <= 1) return;
    for (final cid in _selectedChildIds) {
      if (cid == focusChildId) continue;
      _states[_key(cid, choreId, slot)] = s;
    }
    setState(() {});
  }

  Widget _buildSlotHeader(String slot) {
    final map = {
      'matin': ('🌅', 'Matin', Colors.orange.shade300),
      'midi': ('☀️', 'Midi', Colors.amber.shade300),
      'soir': ('🌙', 'Soir', Colors.indigo.shade300),
    };
    final e = map[slot] ?? ('📋', slot, Colors.white70);
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 2),
      child: Row(children: [
        Text(e.$1, style: const TextStyle(fontSize: 18)),
        const SizedBox(width: 8),
        Text(e.$2,
            style: TextStyle(
                color: e.$3,
                fontSize: 15,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5)),
        const SizedBox(width: 8),
        Expanded(
            child: Container(
                height: 1, color: Colors.white.withValues(alpha: 0.08))),
      ]),
    );
  }

  // ─── Bouton Valider (tous les enfants sélectionnés) ────────────
  Widget _buildValidateButton(List<ChildModel> children, List<ChoreModel> chores) {
    int totalDone = 0, totalMissed = 0;
    const allSlots = ['matin', 'midi', 'soir'];
    for (final cid in _selectedChildIds) {
      for (final c in chores) {
        final slots = c.timeSlots ?? allSlots;
        for (final slot in slots) {
          final s = _getState(cid, c.id, slot);
          if (s == _ChoreState.done) totalDone++;
          if (s == _ChoreState.missed) totalMissed++;
        }
      }
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: SizedBox(
        width: double.infinity,
        height: 54,
        child: ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: _isSubmittingChecklist
                ? Colors.white12
                : EmeraldPalette.emerald,
            foregroundColor: const Color(0xFF051410),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16)),
            elevation: _isSubmittingChecklist ? 0 : 6,
          ),
          onPressed: _isSubmittingChecklist ? null : () => _validateAll(children, chores),
          icon: _isSubmittingChecklist
              ? const SizedBox(width: 20, height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF051410)))
              : const Icon(Icons.check_circle_rounded, size: 24),
          label: Text(
            _isSubmittingChecklist
                ? 'Envoi de la demande…'
                : 'Valider '
                    '($totalDone ✅'
                    '${totalMissed > 0 ? ', $totalMissed ❌' : ''}'
                    '${_selectedChildIds.length > 1 ? ', ${_selectedChildIds.length} enfants' : ''})',
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
          ),
        ),
      ),
    );
  }

  Widget _buildValidatedBanner() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
      decoration: BoxDecoration(
        color: EmeraldPalette.emerald.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: EmeraldPalette.emerald.withValues(alpha: 0.4), width: 1.5),
      ),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.check_circle, color: EmeraldPalette.emerald, size: 22),
          SizedBox(width: 8),
          Text("Checklist validée pour aujourd'hui ✓",
              style: TextStyle(
                  color: EmeraldPalette.emeraldLight,
                  fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  // ─── Validation pour tous les enfants sélectionnés ─────────────
  Future<void> _validateAll(
      List<ChildModel> children, List<ChoreModel> chores) async {
    // 🔒 Verrou anti-double-traitement
    if (_isSubmittingChecklist) return;

    final fp = context.read<FamilyProvider>();
    final isParent = context.read<PinProvider>().isParentMode;
    final messenger = ScaffoldMessenger.of(context);

    // Capturer les données AVANT le premier await
    final selectedChildren =
        children.where((c) => _selectedChildIds.contains(c.id)).toList();

    int grandBonus = 0;
    int grandPenalty = 0;
    final today = DateTime.now();
    final todayStr = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
    final childResults = <String, _ChildValidationResult>{};

    setState(() => _isSubmittingChecklist = true);
    HapticFeedback.mediumImpact();

    try {
      const allSlots = ['matin', 'midi', 'soir'];

      for (final child in selectedChildren) {
        // Collecter les tâches done/missed par slot
        final doneList = <String>[];
        final missedList = <String>[];
        int donePts = 0;
        int missedPts = 0;

        for (final c in chores) {
          final slots = c.timeSlots ?? allSlots;
          for (final slot in slots) {
            final s = _getState(child.id, c.id, slot);
            final slotLabel =
                slot == 'matin' ? '🌅' : (slot == 'midi' ? '☀️' : '🌙');
            if (s == _ChoreState.done) {
              doneList.add('$slotLabel ${c.label}');
              donePts += c.points;
            } else if (s == _ChoreState.missed) {
              missedList.add('$slotLabel ${c.label}');
              missedPts += (c.points ~/ 2).clamp(1, 10);
            }
          }
        }

        if (isParent) {
          if (doneList.isNotEmpty) {
            await fp.addPoints(child.id, donePts,
                '✅ Tâches du jour : ${doneList.join(', ')}',
                category: 'ménage', isBonus: true);
            grandBonus += donePts;
          }
          if (missedList.isNotEmpty) {
            await fp.addPoints(child.id, missedPts,
                '⚠️ Tâches non faites : ${missedList.join(', ')}',
                category: 'ménage', isBonus: false);
            grandPenalty += missedPts;
          }
          _validatedToday.add(child.id);
          // Nettoie les états de cet enfant
          _states.removeWhere((k, _) => k.startsWith('${child.id}|'));
        } else {
          // Mode enfant : demande avec requestKey précis anti-doublon
          if (doneList.isEmpty) {
            // Pas de tâche terminée → ne pas appeler createRequest
            childResults[child.id] = _ChildValidationResult.noTasks;
          } else {
            // 🔒 Construire une clé stable et précise
            final doneKeys = <String>[];
            for (final c in chores) {
              final slots = c.timeSlots ?? allSlots;
              for (final slot in slots) {
                if (_getState(child.id, c.id, slot) == _ChoreState.done) {
                  doneKeys.add('${c.id}:$slot');
                }
              }
            }
            doneKeys.sort(); // Ordre stable
            final requestKey =
                'chore_checklist|${child.id}|$todayStr|${doneKeys.join(',')}|$donePts';

            final result = await fp.createRequest(
              type: 'chore_checklist',
              childId: child.id,
              requestedBy: child.name,
              text: '✅ Tâches du jour : ${doneList.join(', ')}',
              amount: donePts,
              extra: {
                'requestKey': requestKey,
                'requestDate': todayStr,
                'choreKeys': doneKeys,
                'source': 'checklist_child',
                'amount': donePts,
              },
            );

            if (result == RequestResult.created) {
              childResults[child.id] = _ChildValidationResult.created;
              _validatedToday.add(child.id);
              // Nettoie les états de cet enfant
              _states.removeWhere((k, _) => k.startsWith('${child.id}|'));
            } else if (result == RequestResult.duplicate) {
              childResults[child.id] = _ChildValidationResult.duplicate;
              _validatedToday.add(child.id);
              _states.removeWhere((k, _) => k.startsWith('${child.id}|'));
            } else {
              // failed : ne pas nettoyer, ne pas valider
              childResults[child.id] = _ChildValidationResult.failed;
            }
          }
        }
      }

      if (!mounted) return;
      HapticFeedback.heavyImpact();
      final net = grandBonus - grandPenalty;

      if (isParent) {
        messenger.showSnackBar(SnackBar(
          content: Text(selectedChildren.length == 1
              ? (net >= 0
                  ? '🎉 ${selectedChildren.first.name} : +$grandBonus'
                      '${grandPenalty > 0 ? ', -$grandPenalty' : ''}'
                      ' = +$net pts'
                  : '⚠️ ${selectedChildren.first.name} : +$grandBonus, -$grandPenalty = $net pts')
              : '🎉 ${selectedChildren.length} enfants notés : '
                  '+$grandBonus bonus${grandPenalty > 0 ? ', -$grandPenalty pénalité' : ''}'),
          backgroundColor:
              net >= 0 ? EmeraldPalette.emerald : Colors.redAccent,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
        ));
      } else {
        // Mode enfant : messages différenciés par enfant
        final messages = <String>[];
        bool allFailed = true;
        for (final child in selectedChildren) {
          final res = childResults[child.id];
          if (res == _ChildValidationResult.created) {
            messages.add('✅ ${child.name} : Demande envoyée au parent');
            allFailed = false;
          } else if (res == _ChildValidationResult.duplicate) {
            messages.add('ℹ️ ${child.name} : Cette demande a déjà été envoyée');
            allFailed = false;
          } else if (res == _ChildValidationResult.failed) {
            messages.add('❌ ${child.name} : Envoi impossible — réessaie dans un instant');
          } else if (res == _ChildValidationResult.noTasks) {
            messages.add('⚠️ ${child.name} : Sélectionne au moins une tâche terminée');
          }
        }
        if (messages.isNotEmpty) {
          messenger.showSnackBar(SnackBar(
            content: Text(messages.join('\n')),
            backgroundColor: allFailed ? Colors.redAccent : const Color(0xFF7C4DFF),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 5),
          ));
        }
      }
    } finally {
      if (mounted) setState(() => _isSubmittingChecklist = false);
    }
    if (mounted) setState(() {});
  }

  // ─── Ajout de tâche (parent) ───────────────────────────────────
  void _showAddChoreDialog(BuildContext context, FamilyProvider fp) {
    final labelCtrl = TextEditingController();
    final pointsCtrl = TextEditingController(text: '5');
    final allEmojis = [
      '✅', '🛏️', '🛌', '🍽️', '🪥', '📚', '🧸', '🗑️',
      '🐕', '🧹', '🚗', '👕', '🪴', '🍳', '🧽', '📦'
    ];
    String selectedEmoji = '✅';
    bool isIndividual = true;
    final timeSlots = <String>['matin', 'midi', 'soir'];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return AlertDialog(
            backgroundColor: EmeraldPalette.surface,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24)),
            title: const Text('Nouvelle tâche',
                style: TextStyle(
                    color: EmeraldPalette.textPrimary,
                    fontWeight: FontWeight.bold)),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Wrap(
                    spacing: 6,
                    children: allEmojis
                        .map((e) => GestureDetector(
                              onTap: () => setDialogState(
                                  () => selectedEmoji = e),
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: selectedEmoji == e
                                      ? EmeraldPalette.emerald
                                          .withValues(alpha: 0.2)
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                      color: selectedEmoji == e
                                          ? EmeraldPalette.emerald
                                          : Colors.transparent),
                                ),
                                child: Text(e,
                                    style: const TextStyle(fontSize: 22)),
                              ),
                            ))
                        .toList(),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: labelCtrl,
                    style: const TextStyle(color: EmeraldPalette.textPrimary),
                    decoration: InputDecoration(
                      labelText: 'Nom de la tâche',
                      labelStyle: const TextStyle(
                          color: EmeraldPalette.textSecondary),
                      filled: true,
                      fillColor: EmeraldPalette.surfaceLow,
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: pointsCtrl,
                    style: const TextStyle(color: EmeraldPalette.textPrimary),
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Points',
                      labelStyle: const TextStyle(
                          color: EmeraldPalette.textSecondary),
                      filled: true,
                      fillColor: EmeraldPalette.surfaceLow,
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none),
                    ),
                  ),
                  const SizedBox(height: 12),
                  StatefulBuilder(
                    builder: (ctx, setInner) => Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () =>
                                setInner(() => isIndividual = true),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  vertical: 10),
                              decoration: BoxDecoration(
                                color: isIndividual
                                    ? Colors.blue.withValues(alpha: 0.2)
                                    : Colors.white.withValues(alpha: 0.05),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                    color: isIndividual
                                        ? Colors.blue
                                        : Colors.white12),
                              ),
                              child: const Column(children: [
                                Text('🔵', style: TextStyle(fontSize: 18)),
                                SizedBox(height: 2),
                                Text('Individuel',
                                    style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600)),
                                Text('Pénalité si pas fait',
                                    style: TextStyle(
                                        color: Colors.white38, fontSize: 9)),
                              ]),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: GestureDetector(
                            onTap: () =>
                                setInner(() => isIndividual = false),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  vertical: 10),
                              decoration: BoxDecoration(
                                color: !isIndividual
                                    ? Colors.amber.withValues(alpha: 0.2)
                                    : Colors.white.withValues(alpha: 0.05),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                    color: !isIndividual
                                        ? Colors.amber
                                        : Colors.white12),
                              ),
                              child: const Column(children: [
                                Text('🟡', style: TextStyle(fontSize: 18)),
                                SizedBox(height: 2),
                                Text('Partagée',
                                    style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600)),
                                Text("Pas de pénalité si un autre l'a fait",
                                    style: TextStyle(
                                        color: Colors.white38, fontSize: 9)),
                              ]),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text('Moments :',
                      style: TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  StatefulBuilder(
                    builder: (ctx, setSlots) => Row(
                      children: [
                        _TimeSlotChip(
                            label: '🌅 Matin',
                            value: 'matin',
                            slots: timeSlots,
                            onTap: setSlots),
                        const SizedBox(width: 6),
                        _TimeSlotChip(
                            label: '☀️ Midi',
                            value: 'midi',
                            slots: timeSlots,
                            onTap: setSlots),
                        const SizedBox(width: 6),
                        _TimeSlotChip(
                            label: '🌙 Soir',
                            value: 'soir',
                            slots: timeSlots,
                            onTap: setSlots),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Annuler',
                      style: TextStyle(color: Colors.white54))),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                    backgroundColor: EmeraldPalette.emerald,
                    foregroundColor: const Color(0xFF051410)),
                onPressed: timeSlots.isEmpty
                    ? null
                    : () {
                        final label = labelCtrl.text.trim();
                        final points =
                            int.tryParse(pointsCtrl.text.trim()) ?? 5;
                        if (label.isEmpty) return;
                        fp.addChore(
                            label: label,
                            points: points,
                            emoji: selectedEmoji,
                            isIndividual: isIndividual,
                            timeSlots: timeSlots);
                        Navigator.pop(ctx);
                      },
                child: const Text('Ajouter',
                    style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          );
        },
      ),
    );
  }

  void _confirmDeleteChore(
      BuildContext context, FamilyProvider fp, ChoreModel chore) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: EmeraldPalette.surface,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Supprimer ?',
            style: TextStyle(color: EmeraldPalette.textPrimary)),
        content: Text('Supprimer "${chore.label}" ?',
            style: const TextStyle(color: EmeraldPalette.textSecondary)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Annuler',
                  style: TextStyle(color: Colors.white54))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white),
            onPressed: () {
              Navigator.pop(ctx);
              fp.deleteChore(chore.id);
            },
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
  }
}

// ─── Carte tâche avec 3 décisions : ✅ ➖ ❌ ──────────────────────
class _ChoreDecisionCard extends StatelessWidget {
  final ChoreModel chore;
  final _ChoreState state;
  final bool isParent;
  final VoidCallback onDone;
  final VoidCallback onSkipped;
  final VoidCallback onMissed;
  final VoidCallback? onDelete;

  const _ChoreDecisionCard({
    required this.chore,
    required this.state,
    required this.isParent,
    required this.onDone,
    required this.onSkipped,
    required this.onMissed,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final isDone = state == _ChoreState.done;
    final isSkipped = state == _ChoreState.skipped;
    final isMissed = state == _ChoreState.missed;

    return Container(
      decoration: BoxDecoration(
        color: isDone
            ? EmeraldPalette.emerald.withValues(alpha: 0.12)
            : isMissed
                ? Colors.redAccent.withValues(alpha: 0.10)
                : isSkipped
                    ? Colors.grey.withValues(alpha: 0.08)
                    : EmeraldPalette.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDone
              ? EmeraldPalette.emerald.withValues(alpha: 0.5)
              : isMissed
                  ? Colors.redAccent.withValues(alpha: 0.4)
                  : isSkipped
                      ? Colors.white24
                      : EmeraldPalette.glassBorder,
          width: (isDone || isMissed) ? 1.5 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            // Emoji + label + badges
            Text(chore.emoji, style: const TextStyle(fontSize: 22)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    chore.label,
                    style: TextStyle(
                      color: isDone
                          ? EmeraldPalette.emeraldLight
                          : isMissed
                              ? Colors.redAccent
                              : isSkipped
                                  ? Colors.white38
                                  : EmeraldPalette.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      decoration: isMissed
                          ? TextDecoration.lineThrough
                          : null,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Row(children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: (chore.isIndividual
                                ? Colors.blue
                                : Colors.amber)
                            .withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        chore.isIndividual ? '🔵 Individuel' : '🟡 Partagée',
                        style: TextStyle(
                          color: chore.isIndividual
                              ? Colors.blue.shade300
                              : Colors.amber.shade300,
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text('+${chore.points} pts',
                        style: const TextStyle(
                            color: EmeraldPalette.gold,
                            fontSize: 11,
                            fontWeight: FontWeight.w700)),
                    if (isParent && onDelete != null) ...[
                      const SizedBox(width: 6),
                      GestureDetector(
                        onTap: onDelete,
                        child: const Icon(Icons.close,
                            color: Colors.white24, size: 14),
                      ),
                    ],
                  ]),
                ],
              ),
            ),

            // ── 3 boutons de décision ──
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ❌ Pas fait (pénalité)
                _DecisionButton(
                  icon: Icons.close_rounded,
                  color: Colors.redAccent,
                  selected: isMissed,
                  onTap: onMissed,
                ),
                const SizedBox(width: 10),
                // ➖ Non noté (skip, ni bonus ni pénalité)
                _DecisionButton(
                  icon: Icons.remove_rounded,
                  color: Colors.grey,
                  selected: isSkipped,
                  onTap: onSkipped,
                ),
                const SizedBox(width: 10),
                // ✅ Fait (bonus)
                _DecisionButton(
                  icon: Icons.check_rounded,
                  color: EmeraldPalette.emerald,
                  selected: isDone,
                  onTap: onDone,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Bouton de décision rond ────────────────────────────────────
class _DecisionButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  const _DecisionButton({
    required this.icon,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: selected ? color : Colors.transparent,
          border: Border.all(
            color: selected ? color : Colors.white24,
            width: selected ? 0 : 2,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                      color: color.withValues(alpha: 0.4),
                      blurRadius: 8,
                      spreadRadius: 1)
                ]
              : null,
        ),
        child: Icon(
          icon,
          color: selected ? const Color(0xFF051410) : Colors.white54,
          size: 24,
        ),
      ),
    );
  }
}

class _TimeSlotChip extends StatelessWidget {
  final String label;
  final String value;
  final List<String> slots;
  final void Function(void Function()) onTap;

  const _TimeSlotChip({
    required this.label,
    required this.value,
    required this.slots,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isSelected = slots.contains(value);
    return Expanded(
      child: GestureDetector(
        onTap: () => onTap(() {
          if (isSelected) {
            slots.remove(value);
          } else {
            slots.add(value);
          }
        }),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected
                ? EmeraldPalette.emerald.withValues(alpha: 0.2)
                : Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
                color:
                    isSelected ? EmeraldPalette.emerald : Colors.white12),
          ),
          child: Center(
            child: Text(label,
                style: TextStyle(
                  color: isSelected
                      ? EmeraldPalette.emeraldLight
                      : Colors.white54,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                )),
          ),
        ),
      ),
    );
  }
}
