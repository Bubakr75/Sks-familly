// lib/widgets/quick_shortcut_panel.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/family_provider.dart';
import '../providers/pin_provider.dart';
import '../models/child_model.dart';
import '../utils/pin_guard.dart';
import 'glass_card.dart';
import 'tv_focus_wrapper.dart';

// ══════════════════════════════════════════════════════════════
// BOUTON FLOTTANT FAB MULTI-ACTIONS
// ══════════════════════════════════════════════════════════════
class QuickShortcutFab extends StatefulWidget {
  const QuickShortcutFab({super.key});

  @override
  State<QuickShortcutFab> createState() => _QuickShortcutFabState();
}

class _QuickShortcutFabState extends State<QuickShortcutFab>
    with SingleTickerProviderStateMixin {
  bool _isOpen = false;
  late AnimationController _ctrl;
  late Animation<double> _rotateAnim;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 350));
    _rotateAnim = Tween<double>(begin: 0.0, end: 0.375)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutBack));
    _fadeAnim = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _toggle() {
    HapticFeedback.lightImpact();
    setState(() {
      _isOpen = !_isOpen;
      if (_isOpen) {
        _ctrl.forward();
      } else {
        _ctrl.reverse();
      }
    });
  }

  void _close() {
    if (_isOpen) {
      setState(() => _isOpen = false);
      _ctrl.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        // Panneau de raccourcis
        AnimatedBuilder(
          animation: _fadeAnim,
          builder: (context, child) {
            return Opacity(
              opacity: _fadeAnim.value,
              child: IgnorePointer(
                ignoring: !_isOpen,
                child: child,
              ),
            );
          },
          child: _QuickPanel(onClose: _close),
        ),
        const SizedBox(height: 12),
        // FAB principal
        GestureDetector(
          onTap: _toggle,
          child: AnimatedBuilder(
            animation: _rotateAnim,
            builder: (context, child) {
              return Transform.rotate(
                angle: _rotateAnim.value * 2 * 3.14159,
                child: child,
              );
            },
            child: Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: _isOpen
                      ? [Colors.redAccent.shade400, Colors.red.shade700]
                      : [Colors.cyanAccent.shade400, Colors.cyan.shade700],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: (_isOpen ? Colors.redAccent : Colors.cyanAccent)
                        .withOpacity(0.45),
                    blurRadius: 16,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                child: Icon(
                  _isOpen ? Icons.close_rounded : Icons.flash_on_rounded,
                  key: ValueKey(_isOpen),
                  color: Colors.white,
                  size: 26,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════
// PANNEAU DE RACCOURCIS
// ══════════════════════════════════════════════════════════════
class _QuickPanel extends StatelessWidget {
  final VoidCallback onClose;
  const _QuickPanel({required this.onClose});

  @override
  Widget build(BuildContext context) {
    final fp = context.watch<FamilyProvider>();
    final pin = context.watch<PinProvider>();
    final isParent = pin.canPerformParentAction();

    return Container(
      width: 260,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1B2E).withOpacity(0.97),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.cyanAccent.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.5),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // En-tête
          Row(children: [
            const Icon(Icons.flash_on_rounded,
                color: Colors.cyanAccent, size: 16),
            const SizedBox(width: 6),
            const Text('Raccourcis',
                style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14)),
          ]),
          const SizedBox(height: 10),
          const Divider(color: Colors.white12, height: 1),
          const SizedBox(height: 10),
          _ShortcutTile(
            icon: Icons.add_circle_rounded,
            label: 'Bonus rapide',
            sublabel: 'Points + enfant',
            color: Colors.greenAccent,
            onTap: () {
              onClose();
              _showQuickBonus(context, fp, isParent: true);
            },
          ),
          _ShortcutTile(
            icon: Icons.remove_circle_rounded,
            label: 'Pénalité rapide',
            sublabel: 'Retirer des points',
            color: Colors.redAccent,
            onTap: () {
              onClose();
              _showQuickPenalty(context, fp, isParent: isParent);
            },
          ),
          const Divider(color: Colors.white12, height: 16),
          _ShortcutTile(
            icon: Icons.psychology_rounded,
            label: 'Note du jour',
            sublabel: "Comportement aujourd'hui",
            color: Colors.purpleAccent,
            onTap: () {
              onClose();
              _showQuickDayNote(context, fp, isParent: isParent);
            },
          ),
          _ShortcutTile(
            icon: Icons.menu_book_rounded,
            label: 'Punition rapide',
            sublabel: 'Ajouter des lignes',
            color: Colors.orangeAccent,
            onTap: () {
              onClose();
              if (!isParent) {
                PinGuard.guardAction(context, () {
                  _showQuickPunishment(context, fp);
                });
              } else {
                _showQuickPunishment(context, fp);
              }
            },
          ),
          _ShortcutTile(
            icon: Icons.shield_rounded,
            label: 'Immunité rapide',
            sublabel: 'Ajouter des immunités',
            color: Colors.amberAccent,
            onTap: () {
              onClose();
              if (!isParent) {
                PinGuard.guardAction(context, () {
                  _showQuickImmunity(context, fp);
                });
              } else {
                _showQuickImmunity(context, fp);
              }
            },
          ),
          const Divider(color: Colors.white12, height: 16),
          _ShortcutTile(
            icon: Icons.tv_rounded,
            label: 'Bonus écran',
            sublabel: '+15 / +30 / +60 min',
            color: Colors.lightBlueAccent,
            onTap: () {
              onClose();
              _showQuickScreenTime(context, fp);
            },
          ),
          _ShortcutTile(
            icon: Icons.today_rounded,
            label: 'Bilan du jour',
            sublabel: 'Score de tous les enfants',
            color: Colors.tealAccent,
            onTap: () {
              onClose();
              _showDailyScoreboard(context, fp);
            },
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// TUILE DE RACCOURCI
// ══════════════════════════════════════════════════════════════
class _ShortcutTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String sublabel;
  final Color color;
  final VoidCallback onTap;

  const _ShortcutTile({
    required this.icon,
    required this.label,
    required this.sublabel,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return TvFocusWrapper(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600)),
                Text(sublabel,
                    style: const TextStyle(
                        color: Colors.white38, fontSize: 11)),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded,
              color: Colors.white24, size: 16),
        ]),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// FONCTIONS RACCOURCIS
// ══════════════════════════════════════════════════════════════

Widget _childSelector(
  List<ChildModel> children,
  String selectedId,
  void Function(String) onSelect,
) {
  return SizedBox(
    height: 44,
    child: ListView.separated(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      itemCount: children.length,
      separatorBuilder: (_, __) => const SizedBox(width: 8),
      itemBuilder: (_, i) {
        final child = children[i];
        final isSel = selectedId == child.id;
        return GestureDetector(
          onTap: () => onSelect(child.id),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isSel
                  ? Colors.cyanAccent.withOpacity(0.18)
                  : Colors.white.withOpacity(0.06),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                  color: isSel ? Colors.cyanAccent : Colors.white24),
            ),
            child: Text(child.name,
                style: TextStyle(
                    color: isSel ? Colors.cyanAccent : Colors.white60,
                    fontWeight: FontWeight.bold,
                    fontSize: 13)),
          ),
        );
      },
    ),
  );
}

// ─── BONUS RAPIDE ────────────────────────────────────────────
void _showQuickBonus(BuildContext context, FamilyProvider fp,
    {required bool isParent}) {
  if (fp.children.isEmpty) return;
  const presets = [
    ('Devoirs faits ✏️', 5),
    ('Chambre rangée 🛏️', 3),
    ('Sans dispute 🕊️', 4),
    ('Aide en cuisine 🍳', 3),
    ('Lecture 📚', 4),
    ('Sport 🏃', 3),
    ('Politesse exemplaire 🌟', 5),
    ('Bonne attitude 👍', 3),
  ];
  String selectedId = fp.children.first.id;
  (String, int)? selectedPreset;
  int customPoints = 5;

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) {
      return StatefulBuilder(builder: (ctx, setS) {
        return DraggableScrollableSheet(
          initialChildSize: 0.75,
          maxChildSize: 0.92,
          minChildSize: 0.5,
          builder: (_, scroll) => _bottomSheetContainer(
            child: ListView(
              controller: scroll,
              padding: const EdgeInsets.all(20),
              children: [
                _sheetHandle(),
                _sheetTitle('⭐ Bonus Rapide', Colors.greenAccent),
                const SizedBox(height: 16),
                const Text('Enfant', style: _labelStyle),
                const SizedBox(height: 8),
                _childSelector(fp.children, selectedId,
                    (id) => setS(() => selectedId = id)),
                const SizedBox(height: 16),
                const Text('Raison', style: _labelStyle),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: presets.map((p) {
                    final isSel = selectedPreset == p;
                    return GestureDetector(
                      onTap: () => setS(
                          () => selectedPreset = isSel ? null : p),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: isSel
                              ? Colors.greenAccent.withOpacity(0.18)
                              : Colors.white.withOpacity(0.06),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: isSel
                                  ? Colors.greenAccent
                                  : Colors.white24),
                        ),
                        child: Text(
                          '${p.$1} +${p.$2}pts',
                          style: TextStyle(
                              color: isSel
                                  ? Colors.greenAccent
                                  : Colors.white70,
                              fontSize: 12,
                              fontWeight: FontWeight.w600),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                if (selectedPreset == null) ...[
                  const Text('Points personnalisés',
                      style: _labelStyle),
                  const SizedBox(height: 8),
                  _PointStepper(
                    value: customPoints,
                    color: Colors.greenAccent,
                    onChanged: (v) => setS(() => customPoints = v),
                  ),
                ],
                const SizedBox(height: 24),
                _actionButton(
                  label: 'Attribuer le bonus',
                  color: Colors.green.shade700,
                  icon: Icons.add_circle,
                  onTap: () {
                    final child = fp.children
                        .firstWhere((c) => c.id == selectedId);
                    final pts = selectedPreset != null
                        ? selectedPreset!.$2
                        : customPoints;
                    final reason = selectedPreset != null
                        ? selectedPreset!.$1
                        : 'Bonus rapide';
                    fp.addPoints(selectedId, pts, reason,
                        isBonus: true, category: 'bonus');
                    Navigator.pop(ctx);
                    _showConfirmSnack(context,
                        '✅ +$pts pts à ${child.name}', Colors.green);
                  },
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

// ─── PÉNALITÉ RAPIDE ─────────────────────────────────────────
void _showQuickPenalty(BuildContext context, FamilyProvider fp,
    {required bool isParent}) {
  if (fp.children.isEmpty) return;
  const presets = [
    ('Dispute 😤', 5),
    ('Insolence 🗣️', 5),
    ('Devoirs non faits ✏️', 4),
    ('Chambre non rangée 🛏️', 3),
    ('Jeux vidéo abusifs 🎮', 4),
    ('Mensonge 🤥', 6),
    ('Retard volontaire ⏰', 3),
    ('Manque de respect 😡', 5),
  ];
  String selectedId = fp.children.first.id;
  (String, int)? selectedPreset;
  int customPoints = 3;

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) {
      return StatefulBuilder(builder: (ctx, setS) {
        return DraggableScrollableSheet(
          initialChildSize: 0.75,
          maxChildSize: 0.92,
          minChildSize: 0.5,
          builder: (_, scroll) => _bottomSheetContainer(
            child: ListView(
              controller: scroll,
              padding: const EdgeInsets.all(20),
              children: [
                _sheetHandle(),
                _sheetTitle('⚡ Pénalité Rapide', Colors.redAccent),
                const SizedBox(height: 16),
                const Text('Enfant', style: _labelStyle),
                const SizedBox(height: 8),
                _childSelector(fp.children, selectedId,
                    (id) => setS(() => selectedId = id)),
                const SizedBox(height: 16),
                const Text('Raison', style: _labelStyle),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: presets.map((p) {
                    final isSel = selectedPreset == p;
                    return GestureDetector(
                      onTap: () => setS(
                          () => selectedPreset = isSel ? null : p),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: isSel
                              ? Colors.redAccent.withOpacity(0.18)
                              : Colors.white.withOpacity(0.06),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: isSel
                                  ? Colors.redAccent
                                  : Colors.white24),
                        ),
                        child: Text(
                          '${p.$1} -${p.$2}pts',
                          style: TextStyle(
                              color: isSel
                                  ? Colors.redAccent
                                  : Colors.white70,
                              fontSize: 12,
                              fontWeight: FontWeight.w600),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                if (selectedPreset == null) ...[
                  const Text('Points personnalisés',
                      style: _labelStyle),
                  const SizedBox(height: 8),
                  _PointStepper(
                    value: customPoints,
                    color: Colors.redAccent,
                    onChanged: (v) => setS(() => customPoints = v),
                  ),
                ],
                const SizedBox(height: 24),
                _actionButton(
                  label: 'Appliquer la pénalité',
                  color: Colors.red.shade700,
                  icon: Icons.remove_circle,
                  onTap: () {
                    final child = fp.children
                        .firstWhere((c) => c.id == selectedId);
                    final pts = selectedPreset != null
                        ? selectedPreset!.$2
                        : customPoints;
                    final reason = selectedPreset != null
                        ? selectedPreset!.$1
                        : 'Pénalité rapide';
                    fp.addPoints(selectedId, -pts, reason,
                        isBonus: false, category: 'penalty');
                    Navigator.pop(ctx);
                    _showConfirmSnack(context,
                        '⚡ -$pts pts à ${child.name}', Colors.red);
                  },
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

// ─── NOTE DU JOUR ────────────────────────────────────────────
void _showQuickDayNote(BuildContext context, FamilyProvider fp,
    {required bool isParent}) {
  if (fp.children.isEmpty) return;
  const criteria = [
    'Comportement 😊',
    'Respect 🙏',
    'Travail ✏️',
    'Effort 💪',
    'Politesse 🌸',
    'Coopération 🤝',
  ];
  String selectedId = fp.children.first.id;
  String selectedCriteria = criteria.first;
  int noteValue = 14;
  const maxValue = 20;
  DateTime noteDate = DateTime.now();

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) {
      return StatefulBuilder(builder: (ctx, setS) {
        final color =
            noteValue >= 10 ? Colors.greenAccent : Colors.redAccent;
        return DraggableScrollableSheet(
          initialChildSize: 0.80,
          maxChildSize: 0.95,
          minChildSize: 0.5,
          builder: (_, scroll) => _bottomSheetContainer(
            child: ListView(
              controller: scroll,
              padding: const EdgeInsets.all(20),
              children: [
                _sheetHandle(),
                _sheetTitle('🧠 Note du Jour', Colors.purpleAccent),
                const SizedBox(height: 16),
                GestureDetector(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: ctx,
                      initialDate: noteDate,
                      firstDate: DateTime(2024),
                      lastDate: DateTime.now(),
                      builder: (context, child) => Theme(
                        data: ThemeData.dark().copyWith(
                          colorScheme: const ColorScheme.dark(
                            primary: Colors.purpleAccent,
                            onPrimary: Colors.white,
                            surface: Color(0xFF2A2A3E),
                          ),
                        ),
                        child: child!,
                      ),
                    );
                    if (picked != null) setS(() => noteDate = picked);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.06),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                          color:
                              Colors.purpleAccent.withOpacity(0.4)),
                    ),
                    child: Row(children: [
                      const Icon(Icons.calendar_today_rounded,
                          color: Colors.purpleAccent, size: 18),
                      const SizedBox(width: 10),
                      Text(_formatDate(noteDate),
                          style: const TextStyle(
                              color: Colors.white, fontSize: 15)),
                      const Spacer(),
                      const Icon(Icons.edit_calendar_rounded,
                          color: Colors.white38, size: 16),
                    ]),
                  ),
                ),
                const SizedBox(height: 16),
                const Text('Enfant', style: _labelStyle),
                const SizedBox(height: 8),
                _childSelector(fp.children, selectedId,
                    (id) => setS(() => selectedId = id)),
                const SizedBox(height: 16),
                const Text('Critère', style: _labelStyle),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: criteria.map((c) {
                    final isSel = selectedCriteria == c;
                    return GestureDetector(
                      onTap: () =>
                          setS(() => selectedCriteria = c),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: isSel
                              ? Colors.purpleAccent.withOpacity(0.18)
                              : Colors.white.withOpacity(0.06),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: isSel
                                  ? Colors.purpleAccent
                                  : Colors.white24),
                        ),
                        child: Text(c,
                            style: TextStyle(
                                color: isSel
                                    ? Colors.purpleAccent
                                    : Colors.white70,
                                fontSize: 13,
                                fontWeight: FontWeight.w600)),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 20),
                const Text('Note /20', style: _labelStyle),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      onPressed: () {
                        if (noteValue > 0)
                          setS(() => noteValue--);
                      },
                      icon: const Icon(Icons.remove_circle_outline,
                          color: Colors.white54, size: 28),
                    ),
                    const SizedBox(width: 8),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      child: Text(
                        '$noteValue / $maxValue',
                        style: TextStyle(
                          color: color,
                          fontSize: 36,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: () {
                        if (noteValue < maxValue)
                          setS(() => noteValue++);
                      },
                      icon: const Icon(Icons.add_circle_outline,
                          color: Colors.white54, size: 28),
                    ),
                  ],
                ),
                Slider(
                  value: noteValue.toDouble(),
                  min: 0,
                  max: maxValue.toDouble(),
                  divisions: maxValue,
                  activeColor: color,
                  inactiveColor: Colors.white12,
                  onChanged: (v) => setS(() => noteValue = v.round()),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [5, 10, 12, 14, 16, 18, 20].map((v) {
                    return Padding(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 3),
                      child: GestureDetector(
                        onTap: () => setS(() => noteValue = v),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: noteValue == v
                                ? color.withOpacity(0.2)
                                : Colors.white.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                                color: noteValue == v
                                    ? color
                                    : Colors.white12),
                          ),
                          child: Text(
                            '$v',
                            style: TextStyle(
                                color: noteValue == v
                                    ? color
                                    : Colors.white38,
                                fontSize: 11,
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 24),
                _actionButton(
                  label: 'Enregistrer la note',
                  color: Colors.purple.shade700,
                  icon: Icons.psychology,
                  onTap: () {
                    final child = fp.children
                        .firstWhere((c) => c.id == selectedId);
                    fp.addPoints(
                      selectedId,
                      noteValue,
                      '$selectedCriteria: $noteValue/$maxValue',
                      category: 'school_note',
                      isBonus: true,
                      date: noteDate,
                    );
                    Navigator.pop(ctx);
                    _showConfirmSnack(
                      context,
                      '🧠 Note ${_formatDate(noteDate)} — ${child.name}: $noteValue/$maxValue',
                      Colors.purple,
                    );
                  },
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

// ─── PUNITION RAPIDE ─────────────────────────────────────────
void _showQuickPunishment(BuildContext context, FamilyProvider fp) {
  if (fp.children.isEmpty) return;
  String selectedId = fp.children.first.id;
  int nbLines = 20;
  String desc = '';
  final descCtrl = TextEditingController();
  const descPresets = [
    'Insolence',
    'Désobéissance',
    'Dispute',
    'Mensonge',
    'Manque de respect',
  ];

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) {
      return StatefulBuilder(builder: (ctx, setS) {
        return DraggableScrollableSheet(
          initialChildSize: 0.72,
          maxChildSize: 0.92,
          minChildSize: 0.45,
          builder: (_, scroll) => _bottomSheetContainer(
            child: ListView(
              controller: scroll,
              padding: const EdgeInsets.all(20),
              children: [
                _sheetHandle(),
                _sheetTitle('📏 Punition Rapide', Colors.orangeAccent),
                const SizedBox(height: 16),
                const Text('Enfant', style: _labelStyle),
                const SizedBox(height: 8),
                _childSelector(fp.children, selectedId,
                    (id) => setS(() => selectedId = id)),
                const SizedBox(height: 16),
                const Text('Motif', style: _labelStyle),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: descPresets.map((d) {
                    final isSel = desc == d;
                    return GestureDetector(
                      onTap: () =>
                          setS(() => desc = isSel ? '' : d),
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
                TextField(
                  controller: descCtrl,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Ou motif personnalisé...',
                    hintStyle:
                        const TextStyle(color: Colors.white38),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.06),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none),
                    focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(
                            color: Colors.orangeAccent)),
                  ),
                  onChanged: (v) {
                    if (v.isNotEmpty) setS(() => desc = '');
                  },
                ),
                const SizedBox(height: 16),
                const Text('Nombre de lignes', style: _labelStyle),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [10, 20, 30, 50, 100].map((n) {
                    final isSel = nbLines == n;
                    return Padding(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 4),
                      child: GestureDetector(
                        onTap: () => setS(() => nbLines = n),
                        child: AnimatedContainer(
                          duration:
                              const Duration(milliseconds: 180),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: isSel
                                ? Colors.orangeAccent
                                    .withOpacity(0.18)
                                : Colors.white.withOpacity(0.06),
                            borderRadius:
                                BorderRadius.circular(12),
                            border: Border.all(
                                color: isSel
                                    ? Colors.orangeAccent
                                    : Colors.white24),
                          ),
                          child: Text(
                            '$n',
                            style: TextStyle(
                                color: isSel
                                    ? Colors.orangeAccent
                                    : Colors.white54,
                                fontWeight: FontWeight.bold,
                                fontSize: 14),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 24),
                _actionButton(
                  label: 'Ajouter la punition',
                  color: Colors.orange.shade700,
                  icon: Icons.menu_book,
                  onTap: () {
                    final finalDesc = desc.isNotEmpty
                        ? desc
                        : descCtrl.text.trim();
                    if (finalDesc.isEmpty) {
                      ScaffoldMessenger.of(ctx).showSnackBar(
                        const SnackBar(
                          content: Text('Indiquez un motif'),
                          backgroundColor: Colors.orangeAccent,
                        ),
                      );
                      return;
                    }
                    final child = fp.children
                        .firstWhere((c) => c.id == selectedId);
                    fp.addPunishment(selectedId, finalDesc, nbLines);
                    Navigator.pop(ctx);
                    _showConfirmSnack(
                      context,
                      '📏 $nbLines lignes ajoutées à ${child.name}',
                      Colors.orange,
                    );
                  },
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

// ─── IMMUNITÉ RAPIDE ─────────────────────────────────────────
void _showQuickImmunity(BuildContext context, FamilyProvider fp) {
  if (fp.children.isEmpty) return;
  String selectedId = fp.children.first.id;
  int nbLines = 10;
  String reason = 'Bonne conduite';
  const reasonPresets = [
    'Bonne conduite 🏅',
    'Aide spontanée 🤗',
    'Note excellente ⭐',
    'Semaine parfaite 🌟',
    'Surprise parent 🎁',
  ];

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) {
      return StatefulBuilder(builder: (ctx, setS) {
        return DraggableScrollableSheet(
          initialChildSize: 0.70,
          maxChildSize: 0.92,
          minChildSize: 0.45,
          builder: (_, scroll) => _bottomSheetContainer(
            child: ListView(
              controller: scroll,
              padding: const EdgeInsets.all(20),
              children: [
                _sheetHandle(),
                _sheetTitle('🛡️ Immunité Rapide', Colors.amberAccent),
                const SizedBox(height: 16),
                const Text('Enfant', style: _labelStyle),
                const SizedBox(height: 8),
                _childSelector(fp.children, selectedId,
                    (id) => setS(() => selectedId = id)),
                const SizedBox(height: 16),
                const Text('Raison', style: _labelStyle),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: reasonPresets.map((r) {
                    final isSel = reason == r;
                    return GestureDetector(
                      onTap: () => setS(() => reason = r),
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
                const SizedBox(height: 16),
                const Text("Nombre de lignes d'immunité",
                    style: _labelStyle),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [5, 10, 20, 30, 50].map((n) {
                    final isSel = nbLines == n;
                    return Padding(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 4),
                      child: GestureDetector(
                        onTap: () => setS(() => nbLines = n),
                        child: AnimatedContainer(
                          duration:
                              const Duration(milliseconds: 180),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: isSel
                                ? Colors.amberAccent
                                    .withOpacity(0.18)
                                : Colors.white.withOpacity(0.06),
                            borderRadius:
                                BorderRadius.circular(12),
                            border: Border.all(
                                color: isSel
                                    ? Colors.amberAccent
                                    : Colors.white24),
                          ),
                          child: Text(
                            '$n',
                            style: TextStyle(
                                color: isSel
                                    ? Colors.amberAccent
                                    : Colors.white54,
                                fontWeight: FontWeight.bold,
                                fontSize: 14),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 24),
                _actionButton(
                  label: "Ajouter l'immunité",
                  color: Colors.amber.shade700,
                  icon: Icons.shield,
                  onTap: () {
                    final child = fp.children
                        .firstWhere((c) => c.id == selectedId);
                    // ✅ CORRIGÉ : ordre correct (childId, reason, lines)
                    fp.addImmunity(selectedId, reason, nbLines);
                    Navigator.pop(ctx);
                    _showConfirmSnack(
                      context,
                      "🛡️ $nbLines lignes d'immunité à ${child.name}",
                      Colors.amber,
                    );
                  },
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

// ─── BONUS TEMPS ÉCRAN RAPIDE ────────────────────────────────
void _showQuickScreenTime(BuildContext context, FamilyProvider fp) {
  if (fp.children.isEmpty) return;
  String selectedId = fp.children.first.id;

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) {
      return StatefulBuilder(builder: (ctx, setS) {
        return _bottomSheetContainer(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _sheetHandle(),
                const SizedBox(height: 16),
                _sheetTitle(
                    "⏱️ Bonus Temps d'Écran", Colors.lightBlueAccent),
                const SizedBox(height: 16),
                const Text('Enfant', style: _labelStyle),
                const SizedBox(height: 8),
                _childSelector(fp.children, selectedId,
                    (id) => setS(() => selectedId = id)),
                const SizedBox(height: 24),
                const Text('Durée à ajouter',
                    style: TextStyle(
                        color: Colors.white70, fontSize: 14)),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [15, 30, 45, 60, 90].map((min) {
                    return GestureDetector(
                      onTap: () {
                        final child = fp.children
                            .firstWhere((c) => c.id == selectedId);
                        fp.addScreenTimeBonus(selectedId, min);
                        Navigator.pop(ctx);
                        _showConfirmSnack(
                          context,
                          '⏱️ +$min min écran pour ${child.name}',
                          Colors.lightBlue,
                        );
                      },
                      child: Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: Colors.lightBlueAccent
                              .withOpacity(0.12),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                              color: Colors.lightBlueAccent
                                  .withOpacity(0.4)),
                        ),
                        child: Column(
                          mainAxisAlignment:
                              MainAxisAlignment.center,
                          children: [
                            Text(
                              '+$min',
                              style: const TextStyle(
                                  color: Colors.lightBlueAccent,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14),
                            ),
                            const Text('min',
                                style: TextStyle(
                                    color: Colors.white38,
                                    fontSize: 10)),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
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

// ─── BILAN DU JOUR ───────────────────────────────────────────
void _showDailyScoreboard(BuildContext context, FamilyProvider fp) {
  final today = DateTime.now();

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) {
      return DraggableScrollableSheet(
        initialChildSize: 0.65,
        maxChildSize: 0.92,
        minChildSize: 0.4,
        builder: (_, scroll) => _bottomSheetContainer(
          child: ListView(
            controller: scroll,
            padding: const EdgeInsets.all(20),
            children: [
              _sheetHandle(),
              _sheetTitle(
                  '📊 Bilan du ${_formatDate(today)}', Colors.tealAccent),
              const SizedBox(height: 16),
              if (fp.children.isEmpty)
                const Center(
                  child: Text('Aucun enfant enregistré',
                      style: TextStyle(color: Colors.white38)),
                )
              else
                ...fp.children.map((child) {
                  final todayEntries =
                      fp.getHistoryForChild(child.id).where((h) {
                    return h.date.year == today.year &&
                        h.date.month == today.month &&
                        h.date.day == today.day &&
                        h.category != 'school_note' &&
                        h.category != 'screen_time_bonus';
                  }).toList();
                  final pointsToday =
                      todayEntries.fold(0, (s, h) => s + h.points);
                  final bonuses =
                      todayEntries.where((h) => h.isBonus).length;
                  final penalties =
                      todayEntries.where((h) => !h.isBonus).length;
                  final notesToday =
                      fp.getHistoryForChild(child.id).where((h) {
                    return h.date.year == today.year &&
                        h.date.month == today.month &&
                        h.date.day == today.day &&
                        h.category == 'school_note';
                  }).toList();
                  final avgNote = notesToday.isNotEmpty
                      ? notesToday.fold<double>(0.0, (s, h) {
                          final match =
                              RegExp(r'(\d+)/(\d+)').firstMatch(h.reason);
                          if (match != null) {
                            final v =
                                int.tryParse(match.group(1)!) ?? h.points;
                            final mx =
                                int.tryParse(match.group(2)!) ?? 20;
                            return s + (v / mx * 20);
                          }
                          return s + h.points.toDouble();
                        }) /
                          notesToday.length
                      : null;
                  final color = pointsToday >= 0
                      ? Colors.greenAccent
                      : Colors.redAccent;

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: GlassCard(
                      padding: const EdgeInsets.all(14),
                      borderRadius: 16,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [
                            Text(child.name,
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold)),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: color.withOpacity(0.15),
                                borderRadius:
                                    BorderRadius.circular(10),
                              ),
                              child: Text(
                                '${pointsToday >= 0 ? '+' : ''}$pointsToday pts',
                                style: TextStyle(
                                    color: color,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13),
                              ),
                            ),
                          ]),
                          const SizedBox(height: 8),
                          Row(children: [
                            _statChip(
                                '✅ $bonuses bonus', Colors.greenAccent),
                            const SizedBox(width: 8),
                            _statChip('⚡ $penalties pénalités',
                                Colors.redAccent),
                            if (avgNote != null) ...[
                              const SizedBox(width: 8),
                              _statChip('🧠 ${avgNote.round()}/20',
                                  Colors.purpleAccent),
                            ],
                          ]),
                          if (todayEntries.isNotEmpty) ...[
                            const SizedBox(height: 10),
                            const Divider(
                                color: Colors.white12, height: 1),
                            const SizedBox(height: 8),
                            ...todayEntries.take(3).map((e) => Padding(
                                  padding: const EdgeInsets.only(
                                      bottom: 4),
                                  child: Row(children: [
                                    Icon(
                                        e.isBonus
                                            ? Icons.add_circle
                                            : Icons.remove_circle,
                                        size: 14,
                                        color: e.isBonus
                                            ? Colors.greenAccent
                                            : Colors.redAccent),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(e.reason,
                                          style: const TextStyle(
                                              color: Colors.white60,
                                              fontSize: 12),
                                          maxLines: 1,
                                          overflow:
                                              TextOverflow.ellipsis),
                                    ),
                                    Text(
                                        '${e.isBonus ? '+' : ''}${e.points}',
                                        style: TextStyle(
                                            color: e.isBonus
                                                ? Colors.greenAccent
                                                : Colors.redAccent,
                                            fontSize: 12,
                                            fontWeight:
                                                FontWeight.bold)),
                                  ]),
                                )),
                            if (todayEntries.length > 3)
                              Text(
                                '... et ${todayEntries.length - 3} autre(s)',
                                style: const TextStyle(
                                    color: Colors.white38,
                                    fontSize: 11),
                              ),
                          ] else ...[
                            const SizedBox(height: 8),
                            const Text("Aucune activité aujourd'hui",
                                style: TextStyle(
                                    color: Colors.white38,
                                    fontSize: 12)),
                          ],
                        ],
                      ),
                    ),
                  );
                }),
              const SizedBox(height: 24),
            ],
          ),
        ),
      );
    },
  );
}

// ══════════════════════════════════════════════════════════════
// WIDGETS HELPERS INTERNES
// ══════════════════════════════════════════════════════════════

Widget _statChip(String label, Color color) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: color.withOpacity(0.1),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: color.withOpacity(0.3)),
    ),
    child: Text(label,
        style: TextStyle(
            color: color, fontSize: 11, fontWeight: FontWeight.w600)),
  );
}

Widget _bottomSheetContainer({required Widget child}) {
  return Container(
    decoration: const BoxDecoration(
      color: Color(0xFF0D1B2E),
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    child: child,
  );
}

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

Widget _sheetTitle(String text, Color color) {
  return Center(
    child: Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Text(text,
          style: TextStyle(
              color: color, fontSize: 20, fontWeight: FontWeight.bold)),
    ),
  );
}

Widget _actionButton({
  required String label,
  required Color color,
  required IconData icon,
  required VoidCallback onTap,
}) {
  return SizedBox(
    width: double.infinity,
    height: 52,
    child: ElevatedButton.icon(
      onPressed: onTap,
      icon: Icon(icon),
      label: Text(label,
          style: const TextStyle(
              fontSize: 15, fontWeight: FontWeight.bold)),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
      ),
    ),
  );
}

class _PointStepper extends StatelessWidget {
  final int value;
  final Color color;
  final void Function(int) onChanged;

  const _PointStepper(
      {required this.value,
      required this.color,
      required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        ...[1, 2, 5].map((d) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: GestureDetector(
                onTap: () => onChanged((value - d).clamp(1, 100)),
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.white24),
                  ),
                  child: Center(
                    child: Text('-$d',
                        style: const TextStyle(
                            color: Colors.redAccent,
                            fontWeight: FontWeight.bold)),
                  ),
                ),
              ),
            )),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            '$value',
            style: TextStyle(
                color: color, fontSize: 30, fontWeight: FontWeight.bold),
          ),
        ),
        ...[1, 2, 5].map((d) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: GestureDetector(
                onTap: () => onChanged((value + d).clamp(1, 100)),
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.white24),
                  ),
                  child: Center(
                    child: Text('+$d',
                        style: TextStyle(
                            color: color,
                            fontWeight: FontWeight.bold)),
                  ),
                ),
              ),
            )),
      ],
    );
  }
}

void _showConfirmSnack(BuildContext context, String msg, Color color) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content:
          Text(msg, style: const TextStyle(fontWeight: FontWeight.bold)),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      duration: const Duration(seconds: 3),
    ),
  );
}

String _formatDate(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

const _labelStyle = TextStyle(color: Colors.white70, fontSize: 14);
