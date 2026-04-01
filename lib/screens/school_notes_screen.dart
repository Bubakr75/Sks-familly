// lib/screens/school_notes_screen.dart
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/family_provider.dart';
import '../widgets/animated_background.dart';
import '../widgets/glass_card.dart';
import '../widgets/tv_focus_wrapper.dart';

// ═══════════════════════════════════════════════════════════
//  CAHIER QUI S'OUVRE
// ═══════════════════════════════════════════════════════════
class _SchoolNotebookOpen extends StatefulWidget {
  final VoidCallback onComplete;
  const _SchoolNotebookOpen({required this.onComplete});
  @override
  State<_SchoolNotebookOpen> createState() =>
      _SchoolNotebookOpenState();
}

class _SchoolNotebookOpenState extends State<_SchoolNotebookOpen>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _coverRotation;
  late Animation<double> _pagesFade;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 1200))
      ..forward().then((_) {
        if (mounted) widget.onComplete();
      });
    _coverRotation = Tween<double>(begin: 0.0, end: -pi * 0.45)
        .animate(CurvedAnimation(
            parent: _ctrl,
            curve: const Interval(0.0, 0.6,
                curve: Curves.easeOutBack)));
    _pagesFade = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(
            parent: _ctrl,
            curve: const Interval(0.3, 0.7,
                curve: Curves.easeIn)));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) => Center(
        child: SizedBox(
          width: 260,
          height: 300,
          child: Stack(alignment: Alignment.center, children: [
            Opacity(
              opacity: _pagesFade.value,
              child: Container(
                width: 220,
                height: 270,
                decoration: BoxDecoration(
                    color: const Color(0xFFFFF8E1),
                    borderRadius: BorderRadius.circular(4),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withOpacity(0.3),
                          blurRadius: 10,
                          offset: const Offset(2, 4))
                    ]),
                child: CustomPaint(
                    painter: _SchoolPagePainter()),
              ),
            ),
            Positioned(
              left: 20,
              child: Transform(
                alignment: Alignment.centerLeft,
                transform: Matrix4.identity()
                  ..setEntry(3, 2, 0.002)
                  ..rotateY(_coverRotation.value),
                child: Container(
                  width: 220,
                  height: 270,
                  decoration: BoxDecoration(
                      color: const Color(0xFF6A1B9A),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                          color: const Color(0xFF4A148C),
                          width: 2),
                      boxShadow: [
                        BoxShadow(
                            color: Colors.black.withOpacity(0.4),
                            blurRadius: 8,
                            offset: const Offset(3, 3))
                      ]),
                  child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                    const Icon(Icons.psychology_rounded,
                        color: Colors.white70, size: 48),
                    const SizedBox(height: 8),
                    Text('COMPORTEMENT',
                        style: TextStyle(
                            color: Colors.white.withOpacity(0.9),
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 2)),
                  ]),
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

class _SchoolPagePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFBBDEFB).withOpacity(0.4)
      ..strokeWidth = 0.8;
    for (int i = 1; i <= 10; i++) {
      final y = i * size.height / 11;
      canvas.drawLine(
          Offset(20, y), Offset(size.width - 20, y), paint);
    }
    final marginPaint = Paint()
      ..color = Colors.redAccent.withOpacity(0.3)
      ..strokeWidth = 1.5;
    canvas.drawLine(const Offset(40, 10),
        Offset(40, size.height - 10), marginPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

// ═══════════════════════════════════════════════════════════
//  ÉTOILES SELON LA NOTE
// ═══════════════════════════════════════════════════════════
class _StarsAnimation extends StatefulWidget {
  final int starCount;
  final VoidCallback onComplete;
  const _StarsAnimation(
      {required this.starCount, required this.onComplete});
  @override
  State<_StarsAnimation> createState() => _StarsAnimationState();
}

class _StarsAnimationState extends State<_StarsAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 1600))
      ..forward().then((_) {
        if (mounted) widget.onComplete();
      });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        final t = _ctrl.value;
        return Stack(alignment: Alignment.center, children: [
          Container(
              color: Colors.purple.withOpacity(0.04 * (1 - t))),
          Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(widget.starCount, (i) {
                final starDelay = i * 0.15;
                final starProgress =
                    ((t - starDelay) / 0.3).clamp(0.0, 1.0);
                final scale =
                    Curves.elasticOut.transform(starProgress);
                return Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 4),
                  child: Transform.scale(
                    scale: scale,
                    child: Text('⭐',
                        style: TextStyle(fontSize: 36, shadows: [
                          Shadow(
                              color: Colors.amber
                                  .withOpacity(0.6 * starProgress),
                              blurRadius: 10),
                        ])),
                  ),
                );
              })),
          if (t > 0.5)
            Positioned(
              bottom: MediaQuery.of(context).size.height * 0.32,
              child: Opacity(
                opacity: ((t - 0.5) / 0.3).clamp(0.0, 1.0),
                child: Text(
                  widget.starCount >= 4
                      ? 'EXCELLENT !'
                      : widget.starCount >= 3
                          ? 'BIEN !'
                          : widget.starCount >= 2
                              ? 'CORRECT'
                              : 'PEUT MIEUX FAIRE',
                  style: TextStyle(
                      color: widget.starCount >= 4
                          ? Colors.amber
                          : widget.starCount >= 3
                              ? Colors.greenAccent
                              : widget.starCount >= 2
                                  ? Colors.orangeAccent
                                  : Colors.redAccent,
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 3),
                ),
              ),
            ),
        ]);
      },
    );
  }
}

int _percentToStars(double percent) {
  if (percent >= 90) return 5;
  if (percent >= 75) return 4;
  if (percent >= 60) return 3;
  if (percent >= 40) return 2;
  return 1;
}

Future<void> showSchoolNotebookAnimation(BuildContext context) {
  return showGeneralDialog(
    context: context,
    barrierDismissible: false,
    barrierColor: Colors.black87,
    transitionDuration: const Duration(milliseconds: 100),
    pageBuilder: (ctx, _, __) => Material(
      color: Colors.transparent,
      child: _SchoolNotebookOpen(
          onComplete: () => Navigator.of(ctx).pop()),
    ),
  );
}

Future<void> showStarsAnimation(
    BuildContext context, double percent) {
  final stars = _percentToStars(percent);
  return showGeneralDialog(
    context: context,
    barrierDismissible: false,
    barrierColor: Colors.black87,
    transitionDuration: const Duration(milliseconds: 100),
    pageBuilder: (ctx, _, __) => Material(
      color: Colors.transparent,
      child: _StarsAnimation(
          starCount: stars,
          onComplete: () => Navigator.of(ctx).pop()),
    ),
  );
}

// ═══════════════════════════════════════════════════════════
//  NOTES COMPORTEMENTALES SCREEN
// ═══════════════════════════════════════════════════════════
class SchoolNotesScreen extends StatefulWidget {
  final String childId;
  const SchoolNotesScreen({super.key, required this.childId});
  @override
  State<SchoolNotesScreen> createState() =>
      _SchoolNotesScreenState();
}

class _SchoolNotesScreenState extends State<SchoolNotesScreen> {
  void _showAddNote(FamilyProvider provider) async {
    await showSchoolNotebookAnimation(context);
    if (!mounted) return;

    String subject = '';
    int value = 10;
    int maxValue = 20;
    DateTime selectedDate = DateTime.now();
    final subjectController = TextEditingController();
    const quickSubjects = [
      'Comportement', 'Respect', 'Travail en classe',
      'Effort', 'Politesse', 'Coopération', 'Autonomie', 'Ponctualité'
    ];

    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(builder: (context, setModalState) {
          return DraggableScrollableSheet(
            initialChildSize: 0.85,
            minChildSize: 0.5,
            maxChildSize: 0.95,
            builder: (context, scrollController) {
              return Container(
                decoration: BoxDecoration(
                    color: Colors.grey[900]?.withOpacity(0.95),
                    borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(24))),
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(20),
                  children: [
                    Center(
                        child: Container(
                            width: 40,
                            height: 4,
                            decoration: BoxDecoration(
                                color: Colors.white24,
                                borderRadius:
                                    BorderRadius.circular(2)))),
                    const SizedBox(height: 16),
                    Row(
                        mainAxisAlignment:
                            MainAxisAlignment.center,
                        children: [
                      TweenAnimationBuilder<double>(
                        tween: Tween<double>(begin: 0, end: 1),
                        duration:
                            const Duration(milliseconds: 600),
                        curve: Curves.elasticOut,
                        builder: (context, val, child) =>
                            Transform.scale(
                                scale: val, child: child),
                        child: const Text('🧠',
                            style: TextStyle(fontSize: 28)),
                      ),
                      const SizedBox(width: 10),
                      const Text('Nouvelle note comportementale',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold)),
                    ]),
                    const SizedBox(height: 24),

                    const Text('Date',
                        style: TextStyle(
                            color: Colors.white70, fontSize: 14)),
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: selectedDate,
                          firstDate: DateTime(2020),
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
                        if (picked != null) {
                          setModalState(() => selectedDate = picked);
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.06),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                              color: Colors.purpleAccent
                                  .withOpacity(0.4)),
                        ),
                        child: Row(children: [
                          const Icon(Icons.calendar_today_rounded,
                              color: Colors.purpleAccent, size: 18),
                          const SizedBox(width: 10),
                          Text(
                            '${selectedDate.day.toString().padLeft(2, '0')}/${selectedDate.month.toString().padLeft(2, '0')}/${selectedDate.year}',
                            style: const TextStyle(
                                color: Colors.white, fontSize: 15),
                          ),
                          const Spacer(),
                          const Icon(Icons.edit_calendar_rounded,
                              color: Colors.white38, size: 16),
                        ]),
                      ),
                    ),
                    const SizedBox(height: 20),

                    const Text('Critère',
                        style: TextStyle(
                            color: Colors.white70, fontSize: 14)),
                    const SizedBox(height: 8),
                    Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: quickSubjects.map((s) {
                          final isSelected = subject == s;
                          return TvFocusWrapper(
                            onTap: () => setModalState(() {
                              subject = isSelected ? '' : s;
                              if (subject.isNotEmpty)
                                subjectController.clear();
                            }),
                            child: GestureDetector(
                              onTap: () => setModalState(() {
                                subject = isSelected ? '' : s;
                                if (subject.isNotEmpty)
                                  subjectController.clear();
                              }),
                              child: AnimatedContainer(
                                duration: const Duration(
                                    milliseconds: 200),
                                padding:
                                    const EdgeInsets.symmetric(
                                        horizontal: 14,
                                        vertical: 8),
                                decoration: BoxDecoration(
                                    color: isSelected
                                        ? Colors.purpleAccent
                                            .withOpacity(0.2)
                                        : Colors.white
                                            .withOpacity(0.06),
                                    borderRadius:
                                        BorderRadius.circular(20),
                                    border: Border.all(
                                        color: isSelected
                                            ? Colors.purpleAccent
                                            : Colors.white24)),
                                child: Text(s,
                                    style: TextStyle(
                                        color: isSelected
                                            ? Colors.purpleAccent
                                            : Colors.white70,
                                        fontSize: 13)),
                              ),
                            ),
                          );
                        }).toList()),
                    const SizedBox(height: 12),
                    TextField(
                      controller: subjectController,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                          hintText: 'Ou saisissez un critère...',
                          hintStyle: const TextStyle(
                              color: Colors.white38),
                          filled: true,
                          fillColor:
                              Colors.white.withOpacity(0.06),
                          border: OutlineInputBorder(
                              borderRadius:
                                  BorderRadius.circular(14),
                              borderSide: BorderSide.none),
                          focusedBorder: OutlineInputBorder(
                              borderRadius:
                                  BorderRadius.circular(14),
                              borderSide: const BorderSide(
                                  color: Colors.purpleAccent))),
                      onChanged: (val) {
                        if (val.isNotEmpty)
                          setModalState(() => subject = '');
                      },
                    ),
                    const SizedBox(height: 20),
                    const Text('Note',
                        style: TextStyle(
                            color: Colors.white70, fontSize: 14)),
                    const SizedBox(height: 8),
                    Row(
                        mainAxisAlignment:
                            MainAxisAlignment.center,
                        children: [
                      TvFocusWrapper(
                        onTap: () {
                          if (value > 0)
                            setModalState(() => value--);
                        },
                        child: GestureDetector(
                          onTap: () {
                            if (value > 0)
                              setModalState(() => value--);
                          },
                          child: Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.white
                                      .withOpacity(0.1),
                                  border: Border.all(
                                      color: Colors.white24)),
                              child: const Icon(Icons.remove,
                                  color: Colors.white70)),
                        ),
                      ),
                      const SizedBox(width: 16),
                      TweenAnimationBuilder<double>(
                        key: ValueKey(value),
                        tween: Tween<double>(
                            begin: (value - 1).toDouble(),
                            end: value.toDouble()),
                        duration:
                            const Duration(milliseconds: 200),
                        builder: (context, val, _) {
                          final percent = maxValue > 0
                              ? val / maxValue * 100
                              : 0.0;
                          return Text(
                              '${val.round()} / $maxValue',
                              style: TextStyle(
                                  color: percent >= 50
                                      ? Colors.greenAccent
                                      : Colors.redAccent,
                                  fontSize: 32,
                                  fontWeight: FontWeight.bold));
                        },
                      ),
                      const SizedBox(width: 16),
                      TvFocusWrapper(
                        onTap: () {
                          if (value < maxValue)
                            setModalState(() => value++);
                        },
                        child: GestureDetector(
                          onTap: () {
                            if (value < maxValue)
                              setModalState(() => value++);
                          },
                          child: Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.white
                                      .withOpacity(0.1),
                                  border: Border.all(
                                      color: Colors.white24)),
                              child: const Icon(Icons.add,
                                  color: Colors.white70)),
                        ),
                      ),
                    ]),
                    const SizedBox(height: 12),

                    const Text('Barème',
                        style: TextStyle(
                            color: Colors.white70, fontSize: 14)),
                    const SizedBox(height: 8),
                    Row(
                        mainAxisAlignment:
                            MainAxisAlignment.center,
                        children: [10, 20].map((val) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 4),
                            child: TvFocusWrapper(
                              onTap: () => setModalState(() {
                                maxValue = val;
                                if (value > maxValue)
                                  value = maxValue;
                              }),
                              child: OutlinedButton(
                                onPressed: () =>
                                    setModalState(() {
                                  maxValue = val;
                                  if (value > maxValue)
                                    value = maxValue;
                                }),
                                style: OutlinedButton.styleFrom(
                                    foregroundColor:
                                        maxValue == val
                                            ? Colors.purpleAccent
                                            : Colors.white54,
                                    side: BorderSide(
                                        color: maxValue == val
                                            ? Colors.purpleAccent
                                            : Colors.white24),
                                    shape:
                                        RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius
                                                    .circular(20))),
                                child: Text('/$val'),
                              ),
                            ),
                          );
                        }).toList()),

                    const SizedBox(height: 28),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: TvFocusWrapper(
                        onTap: () => _submitNote(ctx, provider,
                            subject, subjectController.text,
                            value, maxValue, selectedDate),
                        child: ElevatedButton.icon(
                          onPressed: () => _submitNote(
                              ctx,
                              provider,
                              subject,
                              subjectController.text,
                              value,
                              maxValue,
                              selectedDate),
                          icon: const Icon(Icons.psychology),
                          label: const Text('Ajouter la note',
                              style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold)),
                          style: ElevatedButton.styleFrom(
                              backgroundColor:
                                  Colors.purple.shade700,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                  borderRadius:
                                      BorderRadius.circular(16))),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        });
      },
    );
  }

  void _submitNote(BuildContext ctx, FamilyProvider provider,
      String subject, String customSubject, int value,
      int maxValue, DateTime date) async {
    final finalSubject =
        subject.isNotEmpty ? subject : customSubject.trim();
    if (finalSubject.isEmpty) {
      ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(
          content: Text('Indiquez un critère'),
          backgroundColor: Colors.purpleAccent));
      return;
    }
    final normalizedScore =
        maxValue > 0 ? (value / maxValue * 20).round() : value;
    final percent =
        maxValue > 0 ? value / maxValue * 100 : 0.0;

    provider.addPoints(widget.childId, normalizedScore,
        '$finalSubject: $value/$maxValue',
        category: 'school_note', isBonus: true, date: date);

    if (ctx.mounted) Navigator.pop(ctx);

    if (!mounted) return;
    await showStarsAnimation(context, percent);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              'Note ajoutée : $value/$maxValue – $finalSubject'),
          backgroundColor: Colors.purple));
    }
  }

  List<_SchoolNoteDisplay> _getSchoolNotes(FamilyProvider provider) {
    final history = provider.getHistoryForChild(widget.childId);
    return history
        .where((h) => h.category == 'school_note')
        .map((h) {
      String subject = h.reason;
      int noteValue = h.points;
      int noteMax = 20;
      final match =
          RegExp(r'^(.+):\s*(\d+)/(\d+)$').firstMatch(h.reason);
      if (match != null) {
        subject = match.group(1)!.trim();
        noteValue = int.tryParse(match.group(2)!) ?? h.points;
        noteMax = int.tryParse(match.group(3)!) ?? 20;
      }
      return _SchoolNoteDisplay(
          id: h.id,
          subject: subject,
          value: noteValue,
          maxValue: noteMax,
          date: h.date);
    }).toList();
  }

  Future<void> _deleteNote(
      _SchoolNoteDisplay note, FamilyProvider provider) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E2E),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        title: const Text('Supprimer la note ?',
            style: TextStyle(color: Colors.white)),
        content: Text(
          '${note.subject} : ${note.value}/${note.maxValue}',
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
            child: const Text('Supprimer',
                style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
    if (confirm == true && mounted) {
      provider.deleteHistoryEntry(note.id);
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

  @override
  Widget build(BuildContext context) {
    return Consumer<FamilyProvider>(
      builder: (context, provider, _) {
        final child = provider.getChild(widget.childId);
        final notes = _getSchoolNotes(provider);
        final avgPercent = notes.isNotEmpty
            ? notes.fold<double>(
                    0,
                    (sum, n) => sum +
                        (n.maxValue > 0
                            ? n.value / n.maxValue * 100
                            : 0)) /
                notes.length
            : 0.0;

        return AnimatedBackground(
          child: Scaffold(
            backgroundColor: Colors.transparent,
            appBar: AppBar(
              title: Row(mainAxisSize: MainAxisSize.min, children: [
                TweenAnimationBuilder<double>(
                  tween: Tween<double>(begin: 0, end: 1),
                  duration: const Duration(milliseconds: 800),
                  curve: Curves.elasticOut,
                  builder: (context, val, child) =>
                      Transform.scale(scale: val, child: child),
                  child: const Text('🧠',
                      style: TextStyle(fontSize: 22)),
                ),
                const SizedBox(width: 8),
                Text('Notes comportementales – ${child?.name ?? ''}'),
              ]),
              backgroundColor: Colors.transparent,
              elevation: 0,
            ),
            body: Column(children: [
              if (notes.isNotEmpty)
                Container(
                  margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [
                      Colors.purpleAccent.withOpacity(0.12),
                      Colors.purpleAccent.withOpacity(0.04)
                    ]),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                        color: Colors.purpleAccent.withOpacity(0.3)),
                  ),
                  child: Row(children: [
                    Row(
                        children: List.generate(
                            _percentToStars(avgPercent),
                            (i) => const Padding(
                                padding: EdgeInsets.only(right: 2),
                                child: Text('⭐',
                                    style: TextStyle(fontSize: 14))))),
                    const SizedBox(width: 10),
                    Expanded(
                        child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                          const Text('Moyenne comportementale',
                              style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12)),
                          TweenAnimationBuilder<double>(
                            tween: Tween<double>(
                                begin: 0, end: avgPercent),
                            duration:
                                const Duration(milliseconds: 800),
                            builder: (context, val, _) => Text(
                                '${val.round()}%',
                                style: TextStyle(
                                    color: val >= 50
                                        ? Colors.greenAccent
                                        : Colors.redAccent,
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold)),
                          ),
                        ])),
                    Text(
                        '${notes.length} note${notes.length > 1 ? 's' : ''}',
                        style: TextStyle(
                            color: Colors.white.withOpacity(0.4),
                            fontSize: 12)),
                  ]),
                ),
              Expanded(
                child: notes.isEmpty
                    ? Center(
                        child: Column(
                            mainAxisAlignment:
                                MainAxisAlignment.center,
                            children: [
                          TweenAnimationBuilder<double>(
                            tween: Tween<double>(begin: 0, end: 1),
                            duration:
                                const Duration(milliseconds: 800),
                            curve: Curves.elasticOut,
                            builder: (context, val, child) =>
                                Transform.scale(
                                    scale: val, child: child),
                            child: const Icon(Icons.psychology,
                                size: 64, color: Colors.white24),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                              'Aucune note comportementale',
                              style:
                                  TextStyle(color: Colors.white54)),
                        ]))
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(
                            16, 16, 16, 16),
                        itemCount: notes.length,
                        itemBuilder: (context, index) {
                          final note = notes[index];
                          final percentage = note.maxValue > 0
                              ? (note.value / note.maxValue * 100)
                              : 0.0;
                          final isGood = percentage >= 50;
                          final stars = _percentToStars(percentage);
                          return Padding(
                            padding:
                                const EdgeInsets.only(bottom: 8),
                            child: Dismissible(
                              key: Key(note.id),
                              direction: DismissDirection.endToStart,
                              background: Container(
                                alignment: Alignment.centerRight,
                                padding:
                                    const EdgeInsets.only(right: 20),
                                decoration: BoxDecoration(
                                  color:
                                      Colors.red.withOpacity(0.25),
                                  borderRadius:
                                      BorderRadius.circular(16),
                                ),
                                child: const Icon(
                                    Icons.delete_rounded,
                                    color: Colors.redAccent,
                                    size: 28),
                              ),
                              confirmDismiss: (_) =>
                                  _confirmDelete(note),
                              // ══ CORRECTION : suppression directe sans re-confirmation ══
                              onDismissed: (_) async {
                                provider.deleteHistoryEntry(note.id);
                                if (mounted) {
                                  ScaffoldMessenger.of(context)
                                      .showSnackBar(
                                    const SnackBar(
                                      content: Text('Note supprimée'),
                                      backgroundColor: Colors.redAccent,
                                    ),
                                  );
                                }
                              },
                              child: TvFocusWrapper(
                                onTap: () => _showNoteDetail(
                                    note, provider),
                                child: GestureDetector(
                                  onTap: () => _showNoteDetail(
                                      note, provider),
                                  child: GlassCard(
                                    child: Padding(
                                      padding:
                                          const EdgeInsets.all(16),
                                      child: Row(children: [
                                        TweenAnimationBuilder<double>(
                                          tween: Tween<double>(
                                              begin: 0,
                                              end: percentage),
                                          duration: Duration(
                                              milliseconds:
                                                  600 + index * 100),
                                          curve: Curves.easeOutCubic,
                                          builder: (context, val, _) =>
                                              Container(
                                                width: 48,
                                                height: 48,
                                                decoration: BoxDecoration(
                                                    shape: BoxShape.circle,
                                                    color: (isGood
                                                            ? Colors.greenAccent
                                                            : Colors.redAccent)
                                                        .withOpacity(0.15)),
                                                child: Center(
                                                    child: Text(
                                                        '${val.round()}%',
                                                        style: TextStyle(
                                                            color: isGood
                                                                ? Colors.greenAccent
                                                                : Colors.redAccent,
                                                            fontWeight:
                                                                FontWeight.bold,
                                                            fontSize: 13))),
                                              ),
                                        ),
                                        const SizedBox(width: 14),
                                        Expanded(
                                            child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                              Text(note.subject,
                                                  style: const TextStyle(
                                                      color: Colors.white,
                                                      fontSize: 15,
                                                      fontWeight:
                                                          FontWeight.w600)),
                                              const SizedBox(height: 4),
                                              Row(children: [
                                                Text(
                                                    '${note.value}/${note.maxValue}',
                                                    style: const TextStyle(
                                                        color: Colors.white54,
                                                        fontSize: 13)),
                                                const SizedBox(width: 8),
                                                ...List.generate(
                                                    stars,
                                                    (i) => const Padding(
                                                        padding: EdgeInsets.only(
                                                            right: 1),
                                                        child: Text('⭐',
                                                            style: TextStyle(
                                                                fontSize: 10)))),
                                              ]),
                                            ])),
                                        Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.end,
                                          children: [
                                            Text(
                                                '${note.date.day.toString().padLeft(2, '0')}/${note.date.month.toString().padLeft(2, '0')}/${note.date.year}',
                                                style: const TextStyle(
                                                    color: Colors.white38,
                                                    fontSize: 11)),
                                            const SizedBox(height: 4),
                                            GestureDetector(
                                              onTap: () => _deleteNote(
                                                  note, provider),
                                              child: const Icon(
                                                  Icons
                                                      .delete_outline_rounded,
                                                  color: Colors.redAccent,
                                                  size: 18),
                                            ),
                                          ],
                                        ),
                                      ]),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                child: SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: TvFocusWrapper(
                    onTap: () => _showAddNote(provider),
                    child: ElevatedButton.icon(
                      onPressed: () => _showAddNote(provider),
                      icon: const Icon(Icons.add),
                      label: const Text(
                          'Ajouter une note comportementale',
                          style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.purple.shade700,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(16))),
                    ),
                  ),
                ),
              ),
            ]),
          ),
        );
      },
    );
  }

  Future<bool> _confirmDelete(_SchoolNoteDisplay note) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E2E),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        title: const Text('Supprimer la note ?',
            style: TextStyle(color: Colors.white)),
        content: Text(
          '${note.subject} : ${note.value}/${note.maxValue}',
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
            child: const Text('Supprimer',
                style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  void _showNoteDetail(
      _SchoolNoteDisplay note, FamilyProvider provider) {
    final percent = note.maxValue > 0
        ? note.value / note.maxValue * 100
        : 0.0;
    final stars = _percentToStars(percent);
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
            color: Colors.grey[900]?.withOpacity(0.95),
            borderRadius: const BorderRadius.vertical(
                top: Radius.circular(24))),
        child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
          Center(
              child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 16),
          Row(children: [
            TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0, end: 1),
              duration: const Duration(milliseconds: 600),
              curve: Curves.elasticOut,
              builder: (context, val, child) =>
                  Transform.scale(scale: val, child: child),
              child: const Text('🧠',
                  style: TextStyle(fontSize: 28)),
            ),
            const SizedBox(width: 10),
            Expanded(
                child: Text(note.subject,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold))),
          ]),
          const SizedBox(height: 16),
          Center(
            child: Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(stars, (i) {
                  return TweenAnimationBuilder<double>(
                    tween: Tween<double>(begin: 0, end: 1),
                    duration:
                        Duration(milliseconds: 400 + i * 150),
                    curve: Curves.elasticOut,
                    builder: (context, val, child) =>
                        Transform.scale(scale: val, child: child),
                    child: const Padding(
                        padding: EdgeInsets.symmetric(
                            horizontal: 4),
                        child: Text('⭐',
                            style: TextStyle(fontSize: 28))),
                  );
                })),
          ),
          const SizedBox(height: 16),
          _detailRow('Note', '${note.value}/${note.maxValue}'),
          _detailRow('Pourcentage', '${percent.round()}%'),
          _detailRow(
              'Date',
              '${note.date.day.toString().padLeft(2, '0')}/${note.date.month.toString().padLeft(2, '0')}/${note.date.year}'),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () {
                Navigator.pop(ctx);
                _deleteNote(note, provider);
              },
              icon: const Icon(Icons.delete_outline_rounded,
                  color: Colors.redAccent),
              label: const Text('Supprimer cette note',
                  style: TextStyle(color: Colors.redAccent)),
              style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.redAccent),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12))),
            ),
          ),
          const SizedBox(height: 24),
        ]),
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
        Text(label,
            style: const TextStyle(
                color: Colors.white54, fontSize: 14)),
        Text(value,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w600)),
      ]),
    );
  }
}

class _SchoolNoteDisplay {
  final String id;
  final String subject;
  final int value;
  final int maxValue;
  final DateTime date;
  const _SchoolNoteDisplay(
      {required this.id,
      required this.subject,
      required this.value,
      required this.maxValue,
      required this.date});
}
