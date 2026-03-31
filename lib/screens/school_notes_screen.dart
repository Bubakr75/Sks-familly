import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/family_provider.dart';
import '../widgets/animated_background.dart';
import '../widgets/glass_card.dart';
import '../widgets/tv_focus_wrapper.dart';

// ══════════════════════════════════════════════════════════════════════════════
//  ANIMATIONS
// ══════════════════════════════════════════════════════════════════════════════

class _SchoolNotebookOpen extends StatefulWidget {
  const _SchoolNotebookOpen();
  @override
  State<_SchoolNotebookOpen> createState() => _SchoolNotebookOpenState();
}

class _SchoolNotebookOpenState extends State<_SchoolNotebookOpen>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 700));
    _scale = CurvedAnimation(parent: _ctrl, curve: Curves.elasticOut);
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ScaleTransition(
        scale: _scale,
        child: const Text('📓', style: TextStyle(fontSize: 72)),
      );
}

class _StarsAnimation extends StatefulWidget {
  final int stars;
  const _StarsAnimation({required this.stars});
  @override
  State<_StarsAnimation> createState() => _StarsAnimationState();
}

class _StarsAnimationState extends State<_StarsAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900));
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
        opacity: _fade,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(
            5,
            (i) => Icon(
              i < widget.stars ? Icons.star_rounded : Icons.star_outline_rounded,
              color: Colors.amber,
              size: 36,
            ),
          ),
        ),
      );
}

int _percentToStars(double pct) {
  if (pct >= 90) return 5;
  if (pct >= 75) return 4;
  if (pct >= 60) return 3;
  if (pct >= 40) return 2;
  return 1;
}

Future<void> showSchoolNotebookAnimation(BuildContext context) {
  return showDialog(
    context: context,
    barrierDismissible: false,
    builder: (_) => const Center(child: _SchoolNotebookOpen()),
  );
}

Future<void> showStarsAnimation(BuildContext context, int stars) {
  return showDialog(
    context: context,
    barrierDismissible: false,
    builder: (_) => Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E2E),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Résultat 🎉',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              _StarsAnimation(stars: stars),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK',
                    style: TextStyle(color: Colors.purpleAccent)),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

// ══════════════════════════════════════════════════════════════════════════════
//  MODÈLE LOCAL
// ══════════════════════════════════════════════════════════════════════════════

class _SchoolNoteDisplay {
  final String subject;
  final double value;
  final double maxValue;
  final DateTime date;
  final String rawEntry; // clé unique dans l'historique

  const _SchoolNoteDisplay({
    required this.subject,
    required this.value,
    required this.maxValue,
    required this.date,
    required this.rawEntry,
  });

  double get percentage => maxValue > 0 ? (value / maxValue) * 100 : 0;
}

// ══════════════════════════════════════════════════════════════════════════════
//  ÉCRAN PRINCIPAL
// ══════════════════════════════════════════════════════════════════════════════

class SchoolNotesScreen extends StatefulWidget {
  final String childId;
  const SchoolNotesScreen({super.key, required this.childId});

  @override
  State<SchoolNotesScreen> createState() => _SchoolNotesScreenState();
}

class _SchoolNotesScreenState extends State<SchoolNotesScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _listCtrl;

  // ── sujets rapides ────────────────────────────────────────────────────────
  static const List<String> _quickSubjects = [
    'Comportement',
    'Respect',
    'Effort',
    'Politesse',
    'Travail',
    'Participation',
    'Rangement',
    'Autonomie',
  ];

  @override
  void initState() {
    super.initState();
    _listCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _listCtrl.forward();
  }

  @override
  void dispose() {
    _listCtrl.dispose();
    super.dispose();
  }

  // ── récupère les notes depuis l'historique ───────────────────────────────
  List<_SchoolNoteDisplay> _getNotes(FamilyProvider fp) {
    final child = fp.children.firstWhere((c) => c.id == widget.childId,
        orElse: () => fp.children.first);
    final notes = <_SchoolNoteDisplay>[];

    for (final entry in child.history.reversed) {
      // Format stocké : "📝 Note comportement — Sujet: valeur/max (date)"
      if (!entry.contains('📝') && !entry.contains('Note comportement')) {
        continue;
      }
      try {
        // Extraction du sujet et de la note
        final dashIdx = entry.indexOf('—');
        if (dashIdx < 0) continue;
        final afterDash = entry.substring(dashIdx + 1).trim();
        // afterDash = "Sujet: valeur/max (date)"
        final colonIdx = afterDash.indexOf(':');
        if (colonIdx < 0) continue;
        final subject = afterDash.substring(0, colonIdx).trim();
        final rest = afterDash.substring(colonIdx + 1).trim();
        // rest = "valeur/max (date)"
        final parenIdx = rest.indexOf('(');
        final scoreStr =
            parenIdx >= 0 ? rest.substring(0, parenIdx).trim() : rest.trim();
        final slashIdx = scoreStr.indexOf('/');
        if (slashIdx < 0) continue;
        final value = double.tryParse(scoreStr.substring(0, slashIdx).trim());
        final maxVal =
            double.tryParse(scoreStr.substring(slashIdx + 1).trim());
        if (value == null || maxVal == null) continue;

        // Date
        DateTime date = DateTime.now();
        if (parenIdx >= 0) {
          final dateStr = rest
              .substring(parenIdx + 1, rest.lastIndexOf(')'))
              .trim();
          date = DateTime.tryParse(dateStr) ?? DateTime.now();
        }

        notes.add(_SchoolNoteDisplay(
          subject: subject,
          value: value,
          maxValue: maxVal,
          date: date,
          rawEntry: entry,
        ));
      } catch (_) {
        continue;
      }
    }
    return notes;
  }

  // ── suppression d'une note ───────────────────────────────────────────────
  Future<void> _deleteNote(
      BuildContext context, FamilyProvider fp, _SchoolNoteDisplay note) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Supprimer la note ?',
            style: TextStyle(color: Colors.white)),
        content: Text(
          '${note.subject} : ${note.value.toStringAsFixed(0)}/${note.maxValue.toStringAsFixed(0)}',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler',
                style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child:
                const Text('Supprimer', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
    if (confirm == true && mounted) {
      final child = fp.children
          .firstWhere((c) => c.id == widget.childId);
      // Supprime l'entrée de l'historique
      child.history.remove(note.rawEntry);
      fp.notifyListeners();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Note supprimée'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  // ── ajouter une note ─────────────────────────────────────────────────────
  Future<void> _showAddNote(BuildContext context) async {
    final fp = context.read<FamilyProvider>();
    String selectedSubject = _quickSubjects[0];
    final customCtrl = TextEditingController();
    bool useCustom = false;
    double value = 10;
    int maxScore = 20; // Barème : 10 ou 20 uniquement
    DateTime selectedDate = DateTime.now();

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1A1A2E),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx2, setModal) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx2).viewInsets.bottom + 24,
            left: 20,
            right: 20,
            top: 20,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── titre ──────────────────────────────────────────────────
                const Center(
                  child: Text('📝 Nouvelle note',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold)),
                ),
                const SizedBox(height: 20),

                // ── sélecteur de date ───────────────────────────────────────
                const Text('📅 Date de la note',
                    style: TextStyle(
                        color: Colors.white70, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                TvFocusWrapper(
                  onActivate: () async {
                    final picked = await showDatePicker(
                      context: ctx2,
                      initialDate: selectedDate,
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now(),
                      locale: const Locale('fr'),
                      builder: (context, child) => Theme(
                        data: ThemeData.dark().copyWith(
                          colorScheme: const ColorScheme.dark(
                            primary: Colors.purpleAccent,
                            onPrimary: Colors.white,
                            surface: Color(0xFF2A2A3E),
                          ),
                          dialogBackgroundColor: const Color(0xFF1E1E2E),
                        ),
                        child: child!,
                      ),
                    );
                    if (picked != null) {
                      setModal(() => selectedDate = picked);
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.purpleAccent.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: Colors.purpleAccent.withOpacity(0.35)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_today_rounded,
                            color: Colors.purpleAccent, size: 18),
                        const SizedBox(width: 10),
                        Text(
                          '${selectedDate.day.toString().padLeft(2, '0')}/'
                          '${selectedDate.month.toString().padLeft(2, '0')}/'
                          '${selectedDate.year}',
                          style: const TextStyle(
                              color: Colors.white, fontSize: 15),
                        ),
                        const Spacer(),
                        const Icon(Icons.edit_calendar_rounded,
                            color: Colors.white38, size: 16),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // ── sujets rapides ──────────────────────────────────────────
                const Text('📌 Sujet',
                    style: TextStyle(
                        color: Colors.white70, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: _quickSubjects
                      .map((s) => GestureDetector(
                            onTap: () => setModal(() {
                              selectedSubject = s;
                              useCustom = false;
                            }),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 7),
                              decoration: BoxDecoration(
                                gradient: (!useCustom &&
                                        selectedSubject == s)
                                    ? const LinearGradient(colors: [
                                        Color(0xFF7C3AED),
                                        Color(0xFF9F67FA)
                                      ])
                                    : null,
                                color: (!useCustom && selectedSubject == s)
                                    ? null
                                    : Colors.white12,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(s,
                                  style: TextStyle(
                                      color: (!useCustom &&
                                              selectedSubject == s)
                                          ? Colors.white
                                          : Colors.white70,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600)),
                            ),
                          ))
                      .toList(),
                ),
                const SizedBox(height: 12),

                // ── sujet personnalisé ──────────────────────────────────────
                TextField(
                  controller: customCtrl,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Sujet personnalisé (optionnel)…',
                    hintStyle: const TextStyle(color: Colors.white38),
                    filled: true,
                    fillColor: Colors.white10,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none),
                  ),
                  onChanged: (v) => setModal(() => useCustom = v.isNotEmpty),
                ),
                const SizedBox(height: 20),

                // ── barème : /10 ou /20 ─────────────────────────────────────
                const Text('🎯 Barème',
                    style: TextStyle(
                        color: Colors.white70, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Row(
                  children: [10, 20].map((m) {
                    final selected = maxScore == m;
                    return Expanded(
                      child: GestureDetector(
                        onTap: () => setModal(() {
                          maxScore = m;
                          // Réinitialise la valeur si elle dépasse le nouveau max
                          if (value > m) value = m.toDouble();
                        }),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          margin: EdgeInsets.only(
                              right: m == 10 ? 8 : 0),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          decoration: BoxDecoration(
                            gradient: selected
                                ? const LinearGradient(colors: [
                                    Color(0xFF7C3AED),
                                    Color(0xFF9F67FA)
                                  ])
                                : null,
                            color:
                                selected ? null : Colors.white12,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: selected
                                  ? Colors.purpleAccent
                                  : Colors.transparent,
                            ),
                          ),
                          child: Center(
                            child: Text(
                              '/$m',
                              style: TextStyle(
                                color: selected
                                    ? Colors.white
                                    : Colors.white54,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 20),

                // ── curseur de valeur ────────────────────────────────────────
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('✏️ Note obtenue',
                        style: TextStyle(
                            color: Colors.white70,
                            fontWeight: FontWeight.w600)),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.purpleAccent.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${value.toStringAsFixed(value.truncateToDouble() == value ? 0 : 1)} / $maxScore',
                        style: const TextStyle(
                            color: Colors.purpleAccent,
                            fontWeight: FontWeight.bold,
                            fontSize: 16),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                SliderTheme(
                  data: SliderTheme.of(ctx2).copyWith(
                    activeTrackColor: Colors.purpleAccent,
                    thumbColor: Colors.purpleAccent,
                    inactiveTrackColor: Colors.white12,
                    overlayColor: Colors.purpleAccent.withOpacity(0.15),
                  ),
                  child: Slider(
                    value: value,
                    min: 0,
                    max: maxScore.toDouble(),
                    divisions: maxScore,
                    onChanged: (v) => setModal(() => value = v),
                  ),
                ),
                const SizedBox(height: 24),

                // ── bouton valider ────────────────────────────────────────────
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF7C3AED),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    icon: const Icon(Icons.check_circle_outline_rounded,
                        color: Colors.white),
                    label: const Text('Enregistrer la note',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold)),
                    onPressed: () async {
                      final subject = useCustom && customCtrl.text.isNotEmpty
                          ? customCtrl.text.trim()
                          : selectedSubject;
                      Navigator.pop(ctx2);
                      await _submitNote(
                          context, fp, subject, value, maxScore, selectedDate);
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── soumettre la note ─────────────────────────────────────────────────────
  Future<void> _submitNote(
    BuildContext context,
    FamilyProvider fp,
    String subject,
    double value,
    int maxScore,
    DateTime date,
  ) async {
    final pct = (value / maxScore) * 100;
    final stars = _percentToStars(pct);

    // Format de stockage :
    // "📝 Note comportement — Sujet: valeur/max (YYYY-MM-DD)"
    final dateStr =
        '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    final noteStr =
        '📝 Note comportement — $subject: ${value.toStringAsFixed(value.truncateToDouble() == value ? 0 : 1)}/$maxScore ($dateStr)';

    final child = fp.children.firstWhere((c) => c.id == widget.childId);
    child.history.add(noteStr);
    fp.notifyListeners();

    if (!mounted) return;
    await showSchoolNotebookAnimation(context);
    if (!mounted) return;
    Navigator.pop(context); // ferme l'anim cahier
    await showStarsAnimation(context, stars);
  }

  // ── affichage détail note ─────────────────────────────────────────────────
  void _showNoteDetail(BuildContext context, _SchoolNoteDisplay note) {
    final stars = _percentToStars(note.percentage);
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A2E),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(note.subject,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Text(
              '${note.value.toStringAsFixed(note.value.truncateToDouble() == note.value ? 0 : 1)} / ${note.maxValue.toStringAsFixed(0)}',
              style: const TextStyle(
                  color: Colors.purpleAccent,
                  fontSize: 32,
                  fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            Text(
              '${note.percentage.toStringAsFixed(1)} %',
              style: const TextStyle(color: Colors.white54, fontSize: 16),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                5,
                (i) => Icon(
                  i < stars
                      ? Icons.star_rounded
                      : Icons.star_outline_rounded,
                  color: Colors.amber,
                  size: 28,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              '${note.date.day.toString().padLeft(2, '0')}/'
              '${note.date.month.toString().padLeft(2, '0')}/'
              '${note.date.year}',
              style: const TextStyle(color: Colors.white38, fontSize: 14),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  BUILD
  // ══════════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    final fp = context.watch<FamilyProvider>();
    final notes = _getNotes(fp);
    final avgPct = notes.isEmpty
        ? 0.0
        : notes.fold<double>(0, (s, n) => s + n.percentage) / notes.length;
    final avgStars = notes.isEmpty ? 0 : _percentToStars(avgPct);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          const AnimatedBackground(),
          SafeArea(
            child: Column(
              children: [
                // ── AppBar ────────────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back_ios_new_rounded,
                            color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                      ),
                      const Expanded(
                        child: Text('📓 Notes de comportement',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold)),
                      ),
                      TvFocusWrapper(
                        onActivate: () => _showAddNote(context),
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(colors: [
                              Color(0xFF7C3AED),
                              Color(0xFF9F67FA),
                            ]),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: IconButton(
                            icon: const Icon(Icons.add_rounded,
                                color: Colors.white),
                            onPressed: () => _showAddNote(context),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // ── moyenne globale ──────────────────────────────────────
                if (notes.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: GlassCard(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 14),
                        child: Row(
                          children: [
                            CircularPercentWidget(
                                percent: avgPct / 100, size: 56),
                            const SizedBox(width: 16),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Moyenne générale',
                                    style: TextStyle(
                                        color: Colors.white70,
                                        fontSize: 13)),
                                Text(
                                  '${avgPct.toStringAsFixed(1)} %',
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 22,
                                      fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                            const Spacer(),
                            Row(
                              children: List.generate(
                                5,
                                (i) => Icon(
                                  i < avgStars
                                      ? Icons.star_rounded
                                      : Icons.star_outline_rounded,
                                  color: Colors.amber,
                                  size: 22,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: 8),

                // ── liste des notes ──────────────────────────────────────
                Expanded(
                  child: notes.isEmpty
                      ? const Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('📭',
                                  style: TextStyle(fontSize: 48)),
                              SizedBox(height: 12),
                              Text('Aucune note pour le moment',
                                  style: TextStyle(
                                      color: Colors.white54,
                                      fontSize: 16)),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 4),
                          itemCount: notes.length,
                          itemBuilder: (ctx, i) {
                            final note = notes[i];
                            final stars = _percentToStars(note.percentage);
                            final delay =
                                Duration(milliseconds: i * 60);

                            return FutureBuilder(
                              future: Future.delayed(delay),
                              builder: (_, snap) {
                                return AnimatedOpacity(
                                  opacity: snap.connectionState ==
                                          ConnectionState.done
                                      ? 1.0
                                      : 0.0,
                                  duration:
                                      const Duration(milliseconds: 300),
                                  child: Padding(
                                    padding: const EdgeInsets.only(
                                        bottom: 10),
                                    // ── Swipe pour supprimer ────────────
                                    child: Dismissible(
                                      key: Key(note.rawEntry),
                                      direction:
                                          DismissDirection.endToStart,
                                      background: Container(
                                        alignment: Alignment.centerRight,
                                        padding: const EdgeInsets.only(
                                            right: 20),
                                        decoration: BoxDecoration(
                                          color: Colors.red.withOpacity(
                                              0.25),
                                          borderRadius:
                                              BorderRadius.circular(16),
                                        ),
                                        child: const Icon(
                                            Icons.delete_rounded,
                                            color: Colors.redAccent,
                                            size: 28),
                                      ),
                                      confirmDismiss: (_) async {
                                        return await showDialog<bool>(
                                          context: context,
                                          builder: (_) => AlertDialog(
                                            backgroundColor:
                                                const Color(0xFF1E1E2E),
                                            shape:
                                                RoundedRectangleBorder(
                                                    borderRadius:
                                                        BorderRadius
                                                            .circular(
                                                                16)),
                                            title: const Text(
                                                'Supprimer ?',
                                                style: TextStyle(
                                                    color:
                                                        Colors.white)),
                                            content: Text(
                                              '${note.subject} : ${note.value.toStringAsFixed(0)}/${note.maxValue.toStringAsFixed(0)}',
                                              style: const TextStyle(
                                                  color: Colors
                                                      .white70),
                                            ),
                                            actions: [
                                              TextButton(
                                                onPressed: () =>
                                                    Navigator.pop(
                                                        context, false),
                                                child: const Text(
                                                    'Annuler',
                                                    style: TextStyle(
                                                        color: Colors
                                                            .white54)),
                                              ),
                                              TextButton(
                                                onPressed: () =>
                                                    Navigator.pop(
                                                        context, true),
                                                child: const Text(
                                                    'Supprimer',
                                                    style: TextStyle(
                                                        color: Colors
                                                            .redAccent)),
                                              ),
                                            ],
                                          ),
                                        );
                                      },
                                      onDismissed: (_) => _deleteNote(
                                          context, fp, note),
                                      child: TvFocusWrapper(
                                        onActivate: () =>
                                            _showNoteDetail(
                                                context, note),
                                        child: GlassCard(
                                          child: Padding(
                                            padding:
                                                const EdgeInsets.all(14),
                                            child: Row(
                                              children: [
                                                // ── % cercle ──────────
                                                CircularPercentWidget(
                                                  percent:
                                                      note.percentage /
                                                          100,
                                                  size: 52,
                                                ),
                                                const SizedBox(width: 14),
                                                // ── infos ─────────────
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      Text(
                                                        note.subject,
                                                        style: const TextStyle(
                                                            color: Colors
                                                                .white,
                                                            fontSize: 15,
                                                            fontWeight:
                                                                FontWeight
                                                                    .w700),
                                                      ),
                                                      const SizedBox(
                                                          height: 4),
                                                      Text(
                                                        '${note.value.toStringAsFixed(note.value.truncateToDouble() == note.value ? 0 : 1)} / ${note.maxValue.toStringAsFixed(0)}',
                                                        style: const TextStyle(
                                                            color: Colors
                                                                .purpleAccent,
                                                            fontWeight:
                                                                FontWeight
                                                                    .bold,
                                                            fontSize:
                                                                16),
                                                      ),
                                                      const SizedBox(
                                                          height: 4),
                                                      Text(
                                                        '${note.date.day.toString().padLeft(2, '0')}/'
                                                        '${note.date.month.toString().padLeft(2, '0')}/'
                                                        '${note.date.year}',
                                                        style: const TextStyle(
                                                            color: Colors
                                                                .white38,
                                                            fontSize:
                                                                12),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                                // ── étoiles ───────────
                                                Column(
                                                  children: [
                                                    Row(
                                                      children: List
                                                          .generate(
                                                        5,
                                                        (si) => Icon(
                                                          si < stars
                                                              ? Icons
                                                                  .star_rounded
                                                              : Icons
                                                                  .star_outline_rounded,
                                                          color: Colors
                                                              .amber,
                                                          size: 16,
                                                        ),
                                                      ),
                                                    ),
                                                    const SizedBox(
                                                        height: 6),
                                                    // bouton supprimer
                                                    GestureDetector(
                                                      onTap: () =>
                                                          _deleteNote(
                                                              context,
                                                              fp,
                                                              note),
                                                      child: Container(
                                                        padding:
                                                            const EdgeInsets
                                                                .all(6),
                                                        decoration:
                                                            BoxDecoration(
                                                          color: Colors
                                                              .red
                                                              .withOpacity(
                                                                  0.15),
                                                          borderRadius:
                                                              BorderRadius
                                                                  .circular(
                                                                      8),
                                                        ),
                                                        child: const Icon(
                                                            Icons
                                                                .delete_outline_rounded,
                                                            color: Colors
                                                                .redAccent,
                                                            size: 16),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  WIDGET CERCLE POURCENTAGE
// ══════════════════════════════════════════════════════════════════════════════

class CircularPercentWidget extends StatelessWidget {
  final double percent; // 0.0 → 1.0
  final double size;

  const CircularPercentWidget(
      {super.key, required this.percent, this.size = 52});

  Color _color() {
    if (percent >= 0.8) return Colors.greenAccent;
    if (percent >= 0.6) return Colors.lightGreen;
    if (percent >= 0.4) return Colors.orange;
    return Colors.redAccent;
  }

  @override
  Widget build(BuildContext context) => SizedBox(
        width: size,
        height: size,
        child: Stack(
          alignment: Alignment.center,
          children: [
            CustomPaint(
              size: Size(size, size),
              painter: _CirclePainter(percent: percent, color: _color()),
            ),
            Text(
              '${(percent * 100).toStringAsFixed(0)}%',
              style: TextStyle(
                color: Colors.white,
                fontSize: size * 0.2,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      );
}

class _CirclePainter extends CustomPainter {
  final double percent;
  final Color color;

  const _CirclePainter({required this.percent, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final bg = Paint()
      ..color = Colors.white12
      ..strokeWidth = 5
      ..style = PaintingStyle.stroke;
    final fg = Paint()
      ..color = color
      ..strokeWidth = 5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final rect = Rect.fromCircle(
        center: Offset(size.width / 2, size.height / 2),
        radius: size.width / 2 - 3);

    canvas.drawArc(rect, -pi / 2, 2 * pi, false, bg);
    canvas.drawArc(rect, -pi / 2, 2 * pi * percent, false, fg);
  }

  @override
  bool shouldRepaint(_CirclePainter old) =>
      old.percent != percent || old.color != color;
}
