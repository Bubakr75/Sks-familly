// lib/screens/balance_screen.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/family_provider.dart';
import '../models/child_model.dart';
import '../models/punishment_lines.dart';
import '../models/immunity_lines.dart';
import '../widgets/animated_background.dart';
import '../widgets/glass_card.dart';
import '../widgets/tv_focus_wrapper.dart';

class BalanceScreen extends StatefulWidget {
  const BalanceScreen({super.key});

  @override
  State<BalanceScreen> createState() => _BalanceScreenState();
}

class _BalanceScreenState extends State<BalanceScreen>
    with SingleTickerProviderStateMixin {
  final Set<String> _selectedIds = {};
  late AnimationController _fabCtrl;
  late Animation<double> _fabScale;

  @override
  void initState() {
    super.initState();
    _fabCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 250));
    _fabScale = CurvedAnimation(parent: _fabCtrl, curve: Curves.easeOutBack);
  }

  @override
  void dispose() {
    _fabCtrl.dispose();
    super.dispose();
  }

  void _toggleSelect(String id) {
    HapticFeedback.selectionClick();
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else {
        _selectedIds.add(id);
      }
      if (_selectedIds.isNotEmpty) {
        _fabCtrl.forward();
      } else {
        _fabCtrl.reverse();
      }
    });
  }

  void _selectAll(List<ChildModel> children) {
    HapticFeedback.mediumImpact();
    setState(() {
      if (_selectedIds.length == children.length) {
        _selectedIds.clear();
        _fabCtrl.reverse();
      } else {
        _selectedIds.addAll(children.map((c) => c.id));
        _fabCtrl.forward();
      }
    });
  }

  // ─────────────────────────────────────────────────────────
  // DIALOGUE PUNITION MULTI-ENFANTS
  // ─────────────────────────────────────────────────────────
  void _showAddPunishmentDialog(BuildContext context, FamilyProvider fp) {
    final selectedChildren =
        fp.children.where((c) => _selectedIds.contains(c.id)).toList();
    if (selectedChildren.isEmpty) return;

    int nbLines = 20;
    String desc = '';
    final descCtrl = TextEditingController();

    const descPresets = [
      'Insolence 😤',
      'Désobéissance 🙉',
      'Dispute 👊',
      'Mensonge 🤥',
      'Manque de respect 😡',
      'Bêtise 😈',
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setS) {
          return DraggableScrollableSheet(
            initialChildSize: 0.75,
            maxChildSize: 0.95,
            minChildSize: 0.5,
            builder: (_, scroll) => Container(
              decoration: const BoxDecoration(
                color: Color(0xFF0D1B2E),
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: ListView(
                controller: scroll,
                padding: const EdgeInsets.all(20),
                children: [
                  _sheetHandle(),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('📏', style: TextStyle(fontSize: 24)),
                      const SizedBox(width: 8),
                      Text(
                        selectedChildren.length == 1
                            ? 'Punition — ${selectedChildren.first.name}'
                            : 'Punition — ${selectedChildren.length} enfants',
                        style: const TextStyle(
                            color: Colors.orangeAccent,
                            fontSize: 18,
                            fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  if (selectedChildren.length > 1) ...[
                    const SizedBox(height: 8),
                    Center(
                      child: Wrap(
                        spacing: 8,
                        children: selectedChildren.map(_miniAvatar).toList(),
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  const Text('Motif',
                      style: TextStyle(color: Colors.white70, fontSize: 14)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: descPresets.map((d) {
                      final isSel = desc == d;
                      return GestureDetector(
                        onTap: () => setS(() => desc = isSel ? '' : d),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: isSel
                                ? Colors.orangeAccent.withOpacity(0.18)
                                : Colors.white.withOpacity(0.06),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                                color: isSel
                                    ? Colors.orangeAccent
                                    : Colors.white24),
                          ),
                          child: Text(d,
                              style: TextStyle(
                                  color: isSel
                                      ? Colors.orangeAccent
                                      : Colors.white70,
                                  fontSize: 13)),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 10),
                  TvTextField(
                    controller: descCtrl,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Ou motif personnalisé...',
                      hintStyle: const TextStyle(color: Colors.white38),
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.06),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none),
                      focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide:
                              const BorderSide(color: Colors.orangeAccent)),
                    ),
                    onChanged: (v) {
                      if (v.isNotEmpty) setS(() => desc = '');
                    },
                  ),
                  const SizedBox(height: 20),
                  const Text('Nombre de lignes',
                      style: TextStyle(color: Colors.white70, fontSize: 14)),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [10, 20, 30, 50, 100, 200].map((n) {
                      final isSel = nbLines == n;
                      return GestureDetector(
                        onTap: () => setS(() => nbLines = n),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: isSel
                                ? Colors.orangeAccent.withOpacity(0.18)
                                : Colors.white.withOpacity(0.06),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: isSel
                                    ? Colors.orangeAccent
                                    : Colors.white24),
                          ),
                          child: Text('$n',
                              style: TextStyle(
                                  color: isSel
                                      ? Colors.orangeAccent
                                      : Colors.white54,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15)),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        onPressed: () {
                          if (nbLines > 1) setS(() => nbLines--);
                        },
                        icon: const Icon(Icons.remove_circle_outline,
                            color: Colors.white54),
                      ),
                      Text('$nbLines lignes',
                          style: const TextStyle(
                              color: Colors.orangeAccent,
                              fontSize: 22,
                              fontWeight: FontWeight.bold)),
                      IconButton(
                        onPressed: () => setS(() => nbLines++),
                        icon: const Icon(Icons.add_circle_outline,
                            color: Colors.white54),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (selectedChildren.length > 1)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.orangeAccent.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: Colors.orangeAccent.withOpacity(0.3)),
                      ),
                      child: Text(
                        '⚠️ ${selectedChildren.length} punitions de $nbLines lignes seront créées',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            color: Colors.orangeAccent, fontSize: 13),
                      ),
                    ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        final finalDesc =
                            desc.isNotEmpty ? desc : descCtrl.text.trim();
                        if (finalDesc.isEmpty) {
                          ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(
                            content: Text('Indiquez un motif'),
                            backgroundColor: Colors.orangeAccent,
                          ));
                          return;
                        }
                        for (final id in _selectedIds) {
                          fp.addPunishment(id, finalDesc, nbLines);
                        }
                        Navigator.pop(ctx);
                        setState(() {
                          _selectedIds.clear();
                          _fabCtrl.reverse();
                        });
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text(selectedChildren.length == 1
                              ? '📏 $nbLines lignes ajoutées à ${selectedChildren.first.name}'
                              : '📏 $nbLines lignes ajoutées à ${selectedChildren.length} enfants'),
                          backgroundColor: Colors.orange.shade700,
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ));
                      },
                      icon: const Icon(Icons.menu_book_rounded),
                      label: Text(
                        selectedChildren.length == 1
                            ? 'Punir ${selectedChildren.first.name}'
                            : 'Punir ${selectedChildren.length} enfants',
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.bold),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange.shade700,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          );
        });
      },
    );
  }

  // ─────────────────────────────────────────────────────────
  // DIALOGUE IMMUNITÉ MULTI-ENFANTS
  // ─────────────────────────────────────────────────────────
  void _showAddImmunityDialog(BuildContext context, FamilyProvider fp) {
    final selectedChildren =
        fp.children.where((c) => _selectedIds.contains(c.id)).toList();
    if (selectedChildren.isEmpty) return;

    int nbLines = 10;
    String reason = '';
    DateTime? expiresAt;

    const reasonPresets = [
      'Bonne conduite 🏅',
      'Aide spontanée 🤗',
      'Note excellente ⭐',
      'Semaine parfaite 🌟',
      'Surprise parent 🎁',
      'Effort exceptionnel 💪',
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setS) {
          return DraggableScrollableSheet(
            initialChildSize: 0.78,
            maxChildSize: 0.95,
            minChildSize: 0.5,
            builder: (_, scroll) => Container(
              decoration: const BoxDecoration(
                color: Color(0xFF0D1B2E),
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: ListView(
                controller: scroll,
                padding: const EdgeInsets.all(20),
                children: [
                  _sheetHandle(),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('🛡️', style: TextStyle(fontSize: 24)),
                      const SizedBox(width: 8),
                      Text(
                        selectedChildren.length == 1
                            ? 'Immunité — ${selectedChildren.first.name}'
                            : 'Immunité — ${selectedChildren.length} enfants',
                        style: const TextStyle(
                            color: Colors.amberAccent,
                            fontSize: 18,
                            fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  if (selectedChildren.length > 1) ...[
                    const SizedBox(height: 8),
                    Center(
                      child: Wrap(
                        spacing: 8,
                        children: selectedChildren.map(_miniAvatar).toList(),
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  const Text('Raison',
                      style: TextStyle(color: Colors.white70, fontSize: 14)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: reasonPresets.map((r) {
                      final isSel = reason == r;
                      return GestureDetector(
                        onTap: () => setS(() => reason = isSel ? '' : r),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: isSel
                                ? Colors.amberAccent.withOpacity(0.18)
                                : Colors.white.withOpacity(0.06),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                                color: isSel
                                    ? Colors.amberAccent
                                    : Colors.white24),
                          ),
                          child: Text(r,
                              style: TextStyle(
                                  color: isSel
                                      ? Colors.amberAccent
                                      : Colors.white70,
                                  fontSize: 13)),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 20),
                  const Text('Lignes d\'immunité',
                      style: TextStyle(color: Colors.white70, fontSize: 14)),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [5, 10, 20, 30, 50, 100].map((n) {
                      final isSel = nbLines == n;
                      return GestureDetector(
                        onTap: () => setS(() => nbLines = n),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: isSel
                                ? Colors.amberAccent.withOpacity(0.18)
                                : Colors.white.withOpacity(0.06),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: isSel
                                    ? Colors.amberAccent
                                    : Colors.white24),
                          ),
                          child: Text('$n',
                              style: TextStyle(
                                  color: isSel
                                      ? Colors.amberAccent
                                      : Colors.white54,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15)),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        onPressed: () {
                          if (nbLines > 1) setS(() => nbLines--);
                        },
                        icon: const Icon(Icons.remove_circle_outline,
                            color: Colors.white54),
                      ),
                      Text('$nbLines lignes',
                          style: const TextStyle(
                              color: Colors.amberAccent,
                              fontSize: 22,
                              fontWeight: FontWeight.bold)),
                      IconButton(
                        onPressed: () => setS(() => nbLines++),
                        icon: const Icon(Icons.add_circle_outline,
                            color: Colors.white54),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Date expiration optionnelle
                  GestureDetector(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: ctx,
                        initialDate:
                            DateTime.now().add(const Duration(days: 7)),
                        firstDate: DateTime.now(),
                        lastDate:
                            DateTime.now().add(const Duration(days: 365)),
                        builder: (context, child) => Theme(
                          data: ThemeData.dark().copyWith(
                            colorScheme: const ColorScheme.dark(
                              primary: Colors.amberAccent,
                              onPrimary: Colors.black,
                              surface: Color(0xFF1E2E42),
                            ),
                          ),
                          child: child!,
                        ),
                      );
                      if (picked != null) setS(() => expiresAt = picked);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                            color: expiresAt != null
                                ? Colors.amberAccent
                                : Colors.white24),
                      ),
                      child: Row(children: [
                        Icon(Icons.event_rounded,
                            color: expiresAt != null
                                ? Colors.amberAccent
                                : Colors.white38,
                            size: 18),
                        const SizedBox(width: 10),
                        Text(
                          expiresAt != null
                              ? 'Expire le ${_fmtDate(expiresAt!)}'
                              : 'Date d\'expiration (optionnel)',
                          style: TextStyle(
                              color: expiresAt != null
                                  ? Colors.amberAccent
                                  : Colors.white38,
                              fontSize: 14),
                        ),
                        const Spacer(),
                        if (expiresAt != null)
                          GestureDetector(
                            onTap: () => setS(() => expiresAt = null),
                            child: const Icon(Icons.close,
                                color: Colors.white38, size: 16),
                          ),
                      ]),
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (selectedChildren.length > 1)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.amberAccent.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: Colors.amberAccent.withOpacity(0.3)),
                      ),
                      child: Text(
                        '🛡️ ${selectedChildren.length} immunités de $nbLines lignes seront créées',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            color: Colors.amberAccent, fontSize: 13),
                      ),
                    ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        if (reason.isEmpty) {
                          ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(
                            content: Text('Choisissez une raison'),
                            backgroundColor: Colors.amberAccent,
                          ));
                          return;
                        }
                        for (final id in _selectedIds) {
                          fp.addImmunity(id, reason, nbLines,
                              expiresAt: expiresAt);
                        }
                        Navigator.pop(ctx);
                        setState(() {
                          _selectedIds.clear();
                          _fabCtrl.reverse();
                        });
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text(selectedChildren.length == 1
                              ? '🛡️ $nbLines lignes d\'immunité à ${selectedChildren.first.name}'
                              : '🛡️ $nbLines lignes d\'immunité à ${selectedChildren.length} enfants'),
                          backgroundColor: Colors.amber.shade700,
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ));
                      },
                      icon: const Icon(Icons.shield_rounded),
                      label: Text(
                        selectedChildren.length == 1
                            ? 'Immuniser ${selectedChildren.first.name}'
                            : 'Immuniser ${selectedChildren.length} enfants',
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.bold),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.amber.shade700,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          );
        });
      },
    );
  }

  // ─────────────────────────────────────────────────────────
  // DIALOGUE UTILISER IMMUNITÉ SUR PUNITION (1 enfant)
  // ─────────────────────────────────────────────────────────
  void _showUseImmunityDialog(
      BuildContext context, FamilyProvider fp, String childId) {
    final punishments = fp.punishments
        .where((p) => p.childId == childId && !p.isCompleted)
        .toList();
    final immunities = fp.getUsableImmunitiesForChild(childId);
    if (punishments.isEmpty || immunities.isEmpty) return;

    PunishmentLines? selPunishment = punishments.first;
    ImmunityLines? selImmunity = immunities.first;
    int linesToUse = 10;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setS) {
          final maxLines = [
            selImmunity?.availableLines ?? 0,
            (selPunishment?.totalLines ?? 0) -
                (selPunishment?.completedLines ?? 0),
          ].reduce((a, b) => a < b ? a : b);

          return DraggableScrollableSheet(
            initialChildSize: 0.70,
            maxChildSize: 0.95,
            minChildSize: 0.45,
            builder: (_, scroll) => Container(
              decoration: const BoxDecoration(
                color: Color(0xFF0D1B2E),
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: ListView(
                controller: scroll,
                padding: const EdgeInsets.all(20),
                children: [
                  _sheetHandle(),
                  const SizedBox(height: 16),
                  const Center(
                    child: Text('⚔️ Utiliser une immunité',
                        style: TextStyle(
                            color: Colors.tealAccent,
                            fontSize: 18,
                            fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(height: 20),
                  const Text('Punition cible',
                      style: TextStyle(color: Colors.white70, fontSize: 13)),
                  const SizedBox(height: 8),
                  ...punishments.map((p) {
                    final isSel = selPunishment?.id == p.id;
                    final remaining = p.totalLines - p.completedLines;
                    return GestureDetector(
                      onTap: () => setS(() => selPunishment = p),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isSel
                              ? Colors.redAccent.withOpacity(0.15)
                              : Colors.white.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color:
                                  isSel ? Colors.redAccent : Colors.white24),
                        ),
                        child: Row(children: [
                          const Icon(Icons.menu_book_rounded,
                              color: Colors.redAccent, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(p.text,
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600)),
                                Text(
                                    '$remaining lignes restantes / ${p.totalLines}',
                                    style: const TextStyle(
                                        color: Colors.white38,
                                        fontSize: 11)),
                              ],
                            ),
                          ),
                          if (isSel)
                            const Icon(Icons.check_circle,
                                color: Colors.redAccent, size: 18),
                        ]),
                      ),
                    );
                  }),
                  const SizedBox(height: 16),
                  const Text('Immunité à utiliser',
                      style: TextStyle(color: Colors.white70, fontSize: 13)),
                  const SizedBox(height: 8),
                  ...immunities.map((im) {
                    final isSel = selImmunity?.id == im.id;
                    return GestureDetector(
                      onTap: () => setS(() => selImmunity = im),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isSel
                              ? Colors.amberAccent.withOpacity(0.15)
                              : Colors.white.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: isSel
                                  ? Colors.amberAccent
                                  : Colors.white24),
                        ),
                        child: Row(children: [
                          const Icon(Icons.shield_rounded,
                              color: Colors.amberAccent, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(im.reason,
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600)),
                                Text('${im.availableLines} lignes disponibles',
                                    style: const TextStyle(
                                        color: Colors.white38,
                                        fontSize: 11)),
                              ],
                            ),
                          ),
                          if (isSel)
                            const Icon(Icons.check_circle,
                                color: Colors.amberAccent, size: 18),
                        ]),
                      ),
                    );
                  }),
                  const SizedBox(height: 16),
                  const Text('Lignes à effacer',
                      style: TextStyle(color: Colors.white70, fontSize: 13)),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        onPressed: () {
                          if (linesToUse > 1) setS(() => linesToUse--);
                        },
                        icon: const Icon(Icons.remove_circle_outline,
                            color: Colors.white54),
                      ),
                      Text('$linesToUse',
                          style: const TextStyle(
                              color: Colors.tealAccent,
                              fontSize: 32,
                              fontWeight: FontWeight.bold)),
                      IconButton(
                        onPressed: () {
                          if (linesToUse < maxLines) setS(() => linesToUse++);
                        },
                        icon: const Icon(Icons.add_circle_outline,
                            color: Colors.white54),
                      ),
                    ],
                  ),
                  if (maxLines > 0)
                    Slider(
                      value: linesToUse.clamp(1, maxLines).toDouble(),
                      min: 1,
                      max: maxLines.toDouble(),
                      divisions: maxLines > 1 ? maxLines - 1 : 1,
                      activeColor: Colors.tealAccent,
                      inactiveColor: Colors.white12,
                      onChanged: (v) => setS(() => linesToUse = v.round()),
                    ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed: (selPunishment != null &&
                              selImmunity != null &&
                              maxLines > 0)
                          ? () {
                              fp.useImmunityOnPunishment(selImmunity!.id,
                                  selPunishment!.id, linesToUse);
                              Navigator.pop(ctx);
                              ScaffoldMessenger.of(context)
                                  .showSnackBar(SnackBar(
                                content: Text(
                                    '⚔️ $linesToUse lignes effacées avec l\'immunité'),
                                backgroundColor: Colors.teal.shade700,
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12)),
                              ));
                            }
                          : null,
                      icon: const Icon(Icons.shield_rounded),
                      label: const Text('Appliquer l\'immunité',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.teal.shade700,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          );
        });
      },
    );
  }

  // ─────────────────────────────────────────────────────────
  // BUILD PRINCIPAL
  // ─────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Consumer<FamilyProvider>(
      builder: (context, fp, _) {
        final children = fp.children;
        final allSelected =
            children.isNotEmpty && _selectedIds.length == children.length;

        return AnimatedBackground(
          child: Scaffold(
            backgroundColor: Colors.transparent,
            appBar: AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              title: const Text('⚖️ Punitions & Immunités',
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold)),
              actions: [
                if (children.isNotEmpty)
                  TextButton(
                    onPressed: () => _selectAll(children),
                    child: Text(
                      allSelected ? 'Désélect.' : 'Tout',
                      style: const TextStyle(color: Colors.cyanAccent),
                    ),
                  ),
              ],
            ),
            body: children.isEmpty
                ? const Center(
                    child: Text('Aucun enfant enregistré',
                        style: TextStyle(color: Colors.white38)))
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
                    itemCount: children.length,
                    itemBuilder: (_, i) =>
                        _buildChildCard(context, fp, children[i]),
                  ),
            bottomNavigationBar:
                _selectedIds.isEmpty ? null : _buildActionBar(context, fp),
          ),
        );
      },
    );
  }

  // ─────────────────────────────────────────────────────────
  // BARRE D'ACTION MULTI-SÉLECTION
  // ─────────────────────────────────────────────────────────
  Widget _buildActionBar(BuildContext context, FamilyProvider fp) {
    final count = _selectedIds.length;
    return ScaleTransition(
      scale: _fabScale,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFF0D1B2E).withOpacity(0.97),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          border: Border(
              top: BorderSide(color: Colors.cyanAccent.withOpacity(0.2))),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.5),
                blurRadius: 16,
                offset: const Offset(0, -4)),
          ],
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$count enfant${count > 1 ? 's' : ''} sélectionné${count > 1 ? 's' : ''}',
                style: const TextStyle(color: Colors.white54, fontSize: 12),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () =>
                          _showAddPunishmentDialog(context, fp),
                      icon: const Icon(Icons.menu_book_rounded, size: 18),
                      label: const Text('Punir',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange.shade700,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () =>
                          _showAddImmunityDialog(context, fp),
                      icon: const Icon(Icons.shield_rounded, size: 18),
                      label: const Text('Immunité',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.amber.shade700,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: () {
                      setState(() {
                        _selectedIds.clear();
                        _fabCtrl.reverse();
                      });
                    },
                    icon: const Icon(Icons.close, color: Colors.white38),
                    tooltip: 'Annuler la sélection',
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────
  // CARD ENFANT
  // ─────────────────────────────────────────────────────────
  Widget _buildChildCard(
      BuildContext context, FamilyProvider fp, ChildModel child) {
    final isSelected = _selectedIds.contains(child.id);
    final punishments = fp.punishments
        .where((p) => p.childId == child.id && !p.isCompleted)
        .toList();
    final allPunishments =
        fp.punishments.where((p) => p.childId == child.id).toList();
    final immunities = fp.getImmunitiesForChild(child.id);
    final usableImmunity = fp.getTotalAvailableImmunity(child.id);
    final completedCount =
        allPunishments.where((p) => p.isCompleted).length;

    return GestureDetector(
      onTap: () => _toggleSelect(child.id),
      onLongPress: () => _toggleSelect(child.id),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isSelected
                ? Colors.cyanAccent
                : Colors.white.withOpacity(0.08),
            width: isSelected ? 2 : 1,
          ),
          color: isSelected
              ? Colors.cyanAccent.withOpacity(0.07)
              : Colors.white.withOpacity(0.04),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                      color: Colors.cyanAccent.withOpacity(0.15),
                      blurRadius: 12,
                      spreadRadius: 1)
                ]
              : [],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // En-tête
              Row(
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 24,
                    height: 24,
                    margin: const EdgeInsets.only(right: 10),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isSelected
                          ? Colors.cyanAccent
                          : Colors.transparent,
                      border: Border.all(
                          color: isSelected
                              ? Colors.cyanAccent
                              : Colors.white38,
                          width: 2),
                    ),
                    child: isSelected
                        ? const Icon(Icons.check,
                            color: Colors.black, size: 14)
                        : null,
                  ),
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: Colors.cyanAccent.withOpacity(0.2),
                    backgroundImage: child.hasPhoto
                        ? MemoryImage(base64Decode(child.photoBase64!))
                        : null,
                    child: !child.hasPhoto
                        ? Text(
                            child.avatar.isNotEmpty
                                ? child.avatar
                                : child.name[0].toUpperCase(),
                            style: const TextStyle(fontSize: 18))
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(child.name,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold)),
                        Text(
                            '${child.points} pts · Niv. ${child.currentLevelNumber}',
                            style: const TextStyle(
                                color: Colors.white38, fontSize: 12)),
                      ],
                    ),
                  ),
                  if (usableImmunity > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.amberAccent.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: Colors.amberAccent.withOpacity(0.4)),
                      ),
                      child: Text('🛡️ $usableImmunity',
                          style: const TextStyle(
                              color: Colors.amberAccent,
                              fontSize: 12,
                              fontWeight: FontWeight.bold)),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              // Stats
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  _statBadge(
                      '📏 ${punishments.length} en cours',
                      punishments.isEmpty
                          ? Colors.white24
                          : Colors.redAccent),
                  _statBadge('✅ $completedCount terminées',
                      Colors.greenAccent.withOpacity(0.5)),
                  _statBadge(
                      '🛡️ ${immunities.length} immunités',
                      immunities.isEmpty
                          ? Colors.white24
                          : Colors.amberAccent),
                ],
              ),
              // Punitions actives
              if (punishments.isNotEmpty) ...[
                const SizedBox(height: 12),
                ...punishments.take(3).map((p) {
                  final progress = p.completedLines / p.totalLines;
                  final remaining = p.totalLines - p.completedLines;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Expanded(
                            child: Text(p.text,
                                style: const TextStyle(
                                    color: Colors.white70, fontSize: 12),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis),
                          ),
                          Text('$remaining/${p.totalLines}',
                              style: const TextStyle(
                                  color: Colors.redAccent,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold)),
                        ]),
                        const SizedBox(height: 4),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: progress,
                            minHeight: 5,
                            backgroundColor: Colors.white.withOpacity(0.08),
                            valueColor: AlwaysStoppedAnimation(
                              progress >= 0.75
                                  ? Colors.greenAccent
                                  : progress >= 0.4
                                      ? Colors.orangeAccent
                                      : Colors.redAccent,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
                if (punishments.length > 3)
                  Text(
                      '… et ${punishments.length - 3} autre(s) punition(s)',
                      style: const TextStyle(
                          color: Colors.white38, fontSize: 11)),
              ],
              // Bouton utiliser immunité
              if (punishments.isNotEmpty &&
                  fp.getUsableImmunitiesForChild(child.id).isNotEmpty) ...[
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () =>
                        _showUseImmunityDialog(context, fp, child.id),
                    icon: const Icon(Icons.shield_rounded,
                        color: Colors.tealAccent, size: 16),
                    label: const Text('Utiliser une immunité',
                        style: TextStyle(color: Colors.tealAccent, fontSize: 13)),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(
                          color: Colors.tealAccent, width: 1),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────
  // HELPERS
  // ─────────────────────────────────────────────────────────
  Widget _sheetHandle() {
    return Center(
      child: Container(
        width: 40,
        height: 4,
        decoration: BoxDecoration(
            color: Colors.white24, borderRadius: BorderRadius.circular(2)),
      ),
    );
  }

  Widget _miniAvatar(ChildModel child) {
    return Column(
      children: [
        CircleAvatar(
          radius: 16,
          backgroundColor: Colors.cyanAccent.withOpacity(0.2),
          backgroundImage: child.hasPhoto
              ? MemoryImage(base64Decode(child.photoBase64!))
              : null,
          child: !child.hasPhoto
              ? Text(
                  child.avatar.isNotEmpty
                      ? child.avatar
                      : child.name[0].toUpperCase(),
                  style: const TextStyle(fontSize: 12))
              : null,
        ),
        const SizedBox(height: 2),
        Text(child.name,
            style: const TextStyle(color: Colors.white60, fontSize: 10)),
      ],
    );
  }

  Widget _statBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Text(label,
          style: TextStyle(
              color: color, fontSize: 11, fontWeight: FontWeight.w600)),
    );
  }

  String _fmtDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
}
