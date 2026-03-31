// lib/screens/school_notes_screen.dart
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/family_provider.dart';
import '../providers/pin_provider.dart';
import '../utils/pin_guard.dart';
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
  State<_SchoolNotebookOpen> createState() => _SchoolNotebookOpenState();
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
        vsync: this, duration: const Duration(milliseconds: 1200))
      ..forward().then((_) {
        if (mounted) widget.onComplete();
      });
    _coverRotation = Tween<double>(begin: 0.0, end: -pi * 0.45).animate(
        CurvedAnimation(
            parent: _ctrl,
            curve: const Interval(0.0, 0.6, curve: Curves.easeOutBack)));
    _pagesFade = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(0.3, 0.7, curve: Curves.easeIn)));
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
                child: CustomPaint(painter: _SchoolPagePainter()),
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
                      color: const Color(0xFF1565C0),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                          color: const Color(0xFF0D47A1), width: 2),
                      boxShadow: [
                        BoxShadow(
                            color: Colors.black.withOpacity(0.4),
                            blurRadius: 8,
                            offset: const Offset(3, 3))
                      ]),
                  child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.school_rounded,
                            color: Colors.white70, size: 48),
                        const SizedBox(height: 8),
                        Text('NOTES',
                            style: TextStyle(
                                color: Colors.white.withOpacity(0.9),
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 3)),
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
      canvas.drawLine(Offset(20, y), Offset(size.width - 20, y), paint);
    }
    final marginPaint = Paint()
      ..color = Colors.redAccent.withOpacity(0.3)
      ..strokeWidth = 1.5;
    canvas.drawLine(
        const Offset(40, 10), Offset(40, size.height - 10), marginPaint);
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
  const _StarsAnimation({required this.starCount, required this.onComplete});
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
        vsync: this, duration: const Duration(milliseconds: 1600))
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
          Container(color: Colors.amber.withOpacity(0.04 * (1 - t))),
          Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(widget.starCount, (i) {
                final starDelay = i * 0.15;
                final starProgress =
                    ((t - starDelay) / 0.3).clamp(0.0, 1.0);
                final scale = Curves.elasticOut.transform(starProgress);
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Transform.scale(
                    scale: scale,
                    child: Text('⭐',
                        style: TextStyle(fontSize: 36, shadows: [
                          Shadow(
                              color:
                                  Colors.amber.withOpacity(0.6 * starProgress),
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
      child:
          _SchoolNotebookOpen(onComplete: () => Navigator.of(ctx).pop()),
    ),
  );
}

Future<void> showStarsAnimation(BuildContext context, double percent) {
  final stars = _percentToStars(percent);
  return showGeneralDialog(
    context: context,
    barrierDismissible: false,
    barrierColor: Colors.black87,
    transitionDuration: const Duration(milliseconds: 100),
    pageBuilder: (ctx, _, __) => Material(
      color: Colors.transparent,
      child: _StarsAnimation(
          starCount: stars, onComplete: () => Navigator.of(ctx).pop()),
    ),
  );
}

// ═══════════════════════════════════════════════════════════
//  SCHOOL NOTES SCREEN
// ═══════════════════════════════════════════════════════════
class SchoolNotesScreen extends StatefulWidget {
  final String childId;
  const SchoolNotesScreen({super.key, required this.childId});
  @override
  State<SchoolNotesScreen> createState() => _SchoolNotesScreenState();
}

class _SchoolNotesScreenState extends State<SchoolNotesScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // ── Ajouter note scolaire ──────────────────────────────
  void _showAddNote(FamilyProvider provider) async {
    await showSchoolNotebookAnimation(context);
    if (!mounted) return;

    String subject = '';
    int value = 10;
    int maxValue = 20;
    final subjectController = TextEditingController();
    final valueCtrl = TextEditingController(text: '10');
    const quickSubjects = [
      'Mathématiques', 'Français', 'Histoire',
      'Sciences', 'Anglais', 'Sport', 'Arts', 'Musique'
    ];

    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(builder: (context, setModalState) {
          return DraggableScrollableSheet(
            initialChildSize: 0.75,
            minChildSize: 0.5,
            maxChildSize: 0.9,
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
                                borderRadius: BorderRadius.circular(2)))),
                    const SizedBox(height: 16),
                    Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          TweenAnimationBuilder<double>(
                            tween: Tween<double>(begin: 0, end: 1),
                            duration: const Duration(milliseconds: 600),
                            curve: Curves.elasticOut,
                            builder: (context, val, child) =>
                                Transform.scale(scale: val, child: child),
                            child:
                                const Text('📝', style: TextStyle(fontSize: 28)),
                          ),
                          const SizedBox(width: 10),
                          const Text('Nouvelle note scolaire',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold)),
                        ]),
                    const SizedBox(height: 24),
                    const Text('Matière',
                        style: TextStyle(color: Colors.white70, fontSize: 14)),
                    const SizedBox(height: 8),
                    Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: quickSubjects.map((s) {
                          final isSelected = subject == s;
                          return TvFocusWrapper(
                            onTap: () => setModalState(() {
                              subject = isSelected ? '' : s;
                              if (subject.isNotEmpty) subjectController.clear();
                            }),
                            child: GestureDetector(
                              onTap: () => setModalState(() {
                                subject = isSelected ? '' : s;
                                if (subject.isNotEmpty) subjectController.clear();
                              }),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 8),
                                decoration: BoxDecoration(
                                    color: isSelected
                                        ? Colors.orangeAccent.withOpacity(0.2)
                                        : Colors.white.withOpacity(0.06),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                        color: isSelected
                                            ? Colors.orangeAccent
                                            : Colors.white24)),
                                child: Text(s,
                                    style: TextStyle(
                                        color: isSelected
                                            ? Colors.orangeAccent
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
                          hintText: 'Ou saisissez une matière...',
                          hintStyle: const TextStyle(color: Colors.white38),
                          filled: true,
                          fillColor: Colors.white.withOpacity(0.06),
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide.none),
                          focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: const BorderSide(
                                  color: Colors.orangeAccent))),
                      onChanged: (val) {
                        if (val.isNotEmpty) setModalState(() => subject = '');
                      },
                    ),
                    const SizedBox(height: 20),
                    const Text('Note',
                        style: TextStyle(color: Colors.white70, fontSize: 14)),
                    const SizedBox(height: 8),
                    // ── Champ numérique pour la note ──
                    Row(children: [
                      Expanded(
                        child: TextField(
                          controller: valueCtrl,
                          keyboardType: TextInputType.number,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 28,
                              fontWeight: FontWeight.bold),
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          onChanged: (val) {
                            final v = int.tryParse(val) ?? 0;
                            setModalState(() {
                              value = v.clamp(0, maxValue);
                            });
                          },
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: Colors.white.withOpacity(0.08),
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: BorderSide.none),
                            focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: const BorderSide(
                                    color: Colors.orangeAccent)),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Text('/ $maxValue',
                            style: TextStyle(
                                color: (value / maxValue * 100) >= 50
                                    ? Colors.greenAccent
                                    : Colors.redAccent,
                                fontSize: 28,
                                fontWeight: FontWeight.bold)),
                      ),
                    ]),
                    const SizedBox(height: 12),
                    const Text('Barème',
                        style: TextStyle(color: Colors.white70, fontSize: 14)),
                    const SizedBox(height: 8),
                    Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [10, 20, 40, 100].map((val) {
                          return Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 4),
                            child: TvFocusWrapper(
                              onTap: () => setModalState(() {
                                maxValue = val;
                                if (value > maxValue) {
                                  value = maxValue;
                                  valueCtrl.text = '$maxValue';
                                }
                              }),
                              child: OutlinedButton(
                                onPressed: () => setModalState(() {
                                  maxValue = val;
                                  if (value > maxValue) {
                                    value = maxValue;
                                    valueCtrl.text = '$maxValue';
                                  }
                                }),
                                style: OutlinedButton.styleFrom(
                                    foregroundColor: maxValue == val
                                        ? Colors.orangeAccent
                                        : Colors.white54,
                                    side: BorderSide(
                                        color: maxValue == val
                                            ? Colors.orangeAccent
                                            : Colors.white24),
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(20))),
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
                        onTap: () {
                          final v = int.tryParse(valueCtrl.text) ?? value;
                          _submitNote(ctx, provider, subject,
                              subjectController.text, v.clamp(0, maxValue), maxValue);
                        },
                        child: ElevatedButton.icon(
                          onPressed: () {
                            final v = int.tryParse(valueCtrl.text) ?? value;
                            _submitNote(ctx, provider, subject,
                                subjectController.text, v.clamp(0, maxValue), maxValue);
                          },
                          icon: const Icon(Icons.school),
                          label: const Text('Ajouter la note',
                              style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold)),
                          style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orangeAccent.shade700,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16))),
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
      String subject, String customSubject, int value, int maxValue) async {
    final finalSubject =
        subject.isNotEmpty ? subject : customSubject.trim();
    if (finalSubject.isEmpty) {
      ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(
          content: Text('Indiquez une matière'),
          backgroundColor: Colors.orangeAccent));
      return;
    }
    final normalizedScore =
        maxValue > 0 ? (value / maxValue * 20).round() : value;
    final percent = maxValue > 0 ? value / maxValue * 100 : 0.0;

    provider.addPoints(widget.childId, normalizedScore,
        '$finalSubject: $value/$maxValue',
        category: 'school_note', isBonus: true);

    if (ctx.mounted) Navigator.pop(ctx);
    if (!mounted) return;
    await showStarsAnimation(context, percent);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content:
              Text('Note ajoutée : $value/$maxValue en $finalSubject'),
          backgroundColor: Colors.green));
    }
  }

  // ── Ajouter note de comportement ──────────────────────
  void _showAddBehaviorNote(FamilyProvider provider) {
    int rating = 10;
    final ratingCtrl = TextEditingController(text: '10');
    String comment = '';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(builder: (context, setModalState) {
          final percent = rating / 20 * 100;
          return Container(
            decoration: BoxDecoration(
                color: Colors.grey[900]?.withOpacity(0.95),
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(24))),
            padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 20),
            child: SingleChildScrollView(
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
                    const Center(
                      child: Text('📋 Note de comportement',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(height: 8),
                    Center(
                      child: Text(
                          'Définit le temps d\'écran du lendemain',
                          style: TextStyle(
                              color: Colors.white.withOpacity(0.5),
                              fontSize: 13)),
                    ),
                    const SizedBox(height: 24),
                    const Text('Note /20',
                        style:
                            TextStyle(color: Colors.white70, fontSize: 14)),
                    const SizedBox(height: 8),
                    Row(children: [
                      Expanded(
                        child: TextField(
                          controller: ratingCtrl,
                          keyboardType: TextInputType.number,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              color: percent >= 50
                                  ? Colors.greenAccent
                                  : Colors.redAccent,
                              fontSize: 32,
                              fontWeight: FontWeight.bold),
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          onChanged: (val) {
                            setModalState(() {
                              rating = (int.tryParse(val) ?? 0).clamp(0, 20);
                            });
                          },
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: Colors.white.withOpacity(0.08),
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: BorderSide.none),
                            focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: const BorderSide(
                                    color: Colors.cyanAccent)),
                          ),
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 12),
                        child: Text('/ 20',
                            style: TextStyle(
                                color: Colors.white54,
                                fontSize: 28,
                                fontWeight: FontWeight.bold)),
                      ),
                    ]),
                    const SizedBox(height: 8),
                    // Raccourcis rapides
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [5, 10, 12, 15, 18, 20].map((v) {
                        return GestureDetector(
                          onTap: () => setModalState(() {
                            rating = v;
                            ratingCtrl.text = '$v';
                          }),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.cyanAccent.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                  color: Colors.cyanAccent.withOpacity(0.4)),
                            ),
                            child: Text('$v',
                                style: const TextStyle(
                                    color: Colors.cyanAccent,
                                    fontWeight: FontWeight.bold)),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),
                    // Aperçu temps d'écran
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.cyanAccent.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: Colors.cyanAccent.withOpacity(0.3)),
                      ),
                      child: Row(children: [
                        const Icon(Icons.tv, color: Colors.cyanAccent, size: 20),
                        const SizedBox(width: 8),
                        Text(
                            'Temps d\'écran estimé : ${_minutesToString(_minutesFromScore(rating.toDouble()))}',
                            style: const TextStyle(
                                color: Colors.cyanAccent,
                                fontWeight: FontWeight.w600,
                                fontSize: 13)),
                      ]),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      style: const TextStyle(color: Colors.white),
                      maxLines: 2,
                      decoration: InputDecoration(
                        hintText: 'Commentaire (optionnel)',
                        hintStyle: const TextStyle(color: Colors.white30),
                        filled: true,
                        fillColor: Colors.white.withOpacity(0.06),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide.none),
                      ),
                      onChanged: (val) => comment = val,
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          final r =
                              (int.tryParse(ratingCtrl.text) ?? rating)
                                  .clamp(0, 20);
                          final reasonText = comment.trim().isNotEmpty
                              ? 'Comportement: $r/20 – ${comment.trim()}'
                              : 'Comportement: $r/20';
                          provider.addPoints(widget.childId, r, reasonText,
                              category: 'behavior_note', isBonus: true);
                          Navigator.pop(ctx);
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                    content: Text(
                                        '📋 Note comportement : $r/20'),
                                    backgroundColor: Colors.green));
                          }
                        },
                        icon: const Icon(Icons.check),
                        label: const Text('Valider',
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.cyanAccent.shade700,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16))),
                      ),
                    ),
                  ]),
            ),
          );
        });
      },
    );
  }

  // ── Supprimer une note (scolaire ou comportement) ──────
  void _confirmDeleteNote(
      FamilyProvider provider, String entryId, String label) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.grey.shade900,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Supprimer cette note ?',
            style: TextStyle(color: Colors.white)),
        content: Text('« $label » sera supprimée définitivement.',
            style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child:
                  const Text('Annuler', style: TextStyle(color: Colors.white54))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade700),
            onPressed: () {
              // Supprimer de l'historique et inverser les points
              final entry = provider.history.cast<HistoryEntry?>().firstWhere(
                  (h) => h!.id == entryId,
                  orElse: () => null);
              if (entry != null) {
                final child = provider.getChild(entry.childId);
                if (child != null) {
                  // Inverser les points
                  if (entry.isBonus) {
                    provider.addPoints(child.id, entry.points,
                        '🗑️ Annulation: ${entry.reason}',
                        category: 'correction', isBonus: false);
                  }
                }
              }
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: const Text('🗑️ Note supprimée et points corrigés'),
                  backgroundColor: Colors.red.shade700));
            },
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
  }

  // ── Calculateur temps d'écran ──────────────────────────
  void _showScreenTimeCalculator(FamilyProvider provider) {
    final allNotes = _getAllGradedNotes(provider);
    if (allNotes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Aucune note à cumuler'),
          backgroundColor: Colors.orangeAccent));
      return;
    }
    final selected = <String>{};

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(builder: (context, setSheetState) {
          // Calculer moyenne des notes sélectionnées
          double avgScore = 0;
          int screenMinutes = 0;
          if (selected.isNotEmpty) {
            final selectedNotes =
                allNotes.where((n) => selected.contains(n.id)).toList();
            final totalPercent = selectedNotes.fold<double>(
                0, (s, n) => s + (n.maxValue > 0 ? n.value / n.maxValue * 20 : n.value.toDouble()));
            avgScore = totalPercent / selectedNotes.length;
            screenMinutes = _minutesFromScore(avgScore).clamp(0, 180); // max 3h
          }

          return DraggableScrollableSheet(
            initialChildSize: 0.75,
            minChildSize: 0.4,
            maxChildSize: 0.95,
            builder: (context, scrollController) {
              return Container(
                decoration: BoxDecoration(
                    color: Colors.grey[900]?.withOpacity(0.95),
                    borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(24))),
                child: Column(children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(children: [
                      Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                              color: Colors.white24,
                              borderRadius: BorderRadius.circular(2))),
                      const SizedBox(height: 16),
                      const Text('📺 Calculer le temps d\'écran',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text(
                          'Sélectionnez les notes à cumuler (max 3h/jour)',
                          style: TextStyle(
                              color: Colors.white.withOpacity(0.5),
                              fontSize: 12)),
                      const SizedBox(height: 16),
                      // Résultat
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(colors: [
                            Colors.cyanAccent.withOpacity(0.12),
                            Colors.cyanAccent.withOpacity(0.04),
                          ]),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                              color: Colors.cyanAccent.withOpacity(0.3)),
                        ),
                        child: Row(children: [
                          const Icon(Icons.tv,
                              color: Colors.cyanAccent, size: 28),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Text(
                                      selected.isEmpty
                                          ? 'Sélectionnez des notes'
                                          : '${selected.length} note${selected.length > 1 ? 's' : ''} • Moy: ${avgScore.toStringAsFixed(1)}/20',
                                      style: const TextStyle(
                                          color: Colors.white70,
                                          fontSize: 12)),
                                  Text(
                                      selected.isEmpty
                                          ? '—'
                                          : _minutesToString(screenMinutes),
                                      style: const TextStyle(
                                          color: Colors.cyanAccent,
                                          fontSize: 28,
                                          fontWeight: FontWeight.w900)),
                                ]),
                          ),
                        ]),
                      ),
                    ]),
                  ),
                  Expanded(
                    child: ListView.builder(
                      controller: scrollController,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: allNotes.length,
                      itemBuilder: (context, index) {
                        final note = allNotes[index];
                        final isSelected = selected.contains(note.id);
                        final percent = note.maxValue > 0
                            ? note.value / note.maxValue * 100
                            : note.value / 20 * 100;
                        final dayLabel = _dayName(note.date);

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: GestureDetector(
                            onTap: () => setSheetState(() {
                              if (isSelected) {
                                selected.remove(note.id);
                              } else {
                                selected.add(note.id);
                              }
                            }),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? Colors.cyanAccent.withOpacity(0.12)
                                    : Colors.white.withOpacity(0.04),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                    color: isSelected
                                        ? Colors.cyanAccent
                                        : Colors.white.withOpacity(0.1),
                                    width: isSelected ? 2 : 1),
                              ),
                              child: Row(children: [
                                Icon(
                                    isSelected
                                        ? Icons.check_circle
                                        : Icons.circle_outlined,
                                    color: isSelected
                                        ? Colors.cyanAccent
                                        : Colors.white38,
                                    size: 22),
                                const SizedBox(width: 10),
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: (percent >= 50
                                              ? Colors.greenAccent
                                              : Colors.redAccent)
                                          .withOpacity(0.15)),
                                  child: Center(
                                      child: Text('${percent.round()}%',
                                          style: TextStyle(
                                              color: percent >= 50
                                                  ? Colors.greenAccent
                                                  : Colors.redAccent,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 11))),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                    child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                      Text(note.subject,
                                          style: const TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.w600,
                                              fontSize: 14)),
                                      Text(
                                          '$dayLabel • ${note.value}/${note.maxValue}',
                                          style: const TextStyle(
                                              color: Colors.white38,
                                              fontSize: 12)),
                                    ])),
                              ]),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  // Bouton appliquer
                  if (selected.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                      child: SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            provider.addScreenTimeBonus(
                                widget.childId,
                                screenMinutes,
                                'Cumul ${selected.length} notes → ${_minutesToString(screenMinutes)}');
                            Navigator.pop(ctx);
                            ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                    content: Text(
                                        '📺 ${_minutesToString(screenMinutes)} de temps d\'écran attribué'),
                                    backgroundColor: Colors.green));
                          },
                          icon: const Icon(Icons.tv),
                          label: Text(
                              'Attribuer ${_minutesToString(screenMinutes)}',
                              style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold)),
                          style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.cyanAccent.shade700,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16))),
                        ),
                      ),
                    ),
                ]),
              );
            },
          );
        });
      },
    );
  }

  // ── Helpers ────────────────────────────────────────────
  int _minutesFromScore(double score) {
    if (score >= 18) return 180;
    if (score >= 16) return 150;
    if (score >= 14) return 120;
    if (score >= 12) return 90;
    if (score >= 10) return 60;
    if (score >= 8) return 30;
    return 0;
  }

  String _minutesToString(int minutes) {
    if (minutes < 60) return '${minutes}min';
    final h = minutes ~/ 60;
    final m = minutes % 60;
    if (m == 0) return '${h}h';
    return '${h}h${m.toString().padLeft(2, '0')}';
  }

  String _dayName(DateTime dt) {
    const days = ['Lun', 'Mar', 'Mer', 'Jeu', 'Ven', 'Sam', 'Dim'];
    return '${days[dt.weekday - 1]} ${dt.day}/${dt.month}';
  }

  List<_SchoolNoteDisplay> _getSchoolNotes(FamilyProvider provider) {
    final history = provider.getHistoryForChild(widget.childId);
    return history.where((h) => h.category == 'school_note').map((h) {
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

  List<_SchoolNoteDisplay> _getBehaviorNotes(FamilyProvider provider) {
    final history = provider.getHistoryForChild(widget.childId);
    return history.where((h) => h.category == 'behavior_note').map((h) {
      String subject = 'Comportement';
      int noteValue = h.points;
      int noteMax = 20;
      final match =
          RegExp(r'Comportement:\s*(\d+)/(\d+)').firstMatch(h.reason);
      if (match != null) {
        noteValue = int.tryParse(match.group(1)!) ?? h.points;
        noteMax = int.tryParse(match.group(2)!) ?? 20;
      }
      // Extraire commentaire
      final commentMatch =
          RegExp(r'–\s*(.+)$').firstMatch(h.reason);
      if (commentMatch != null) {
        subject = 'Comportement – ${commentMatch.group(1)!.trim()}';
      }
      return _SchoolNoteDisplay(
          id: h.id,
          subject: subject,
          value: noteValue,
          maxValue: noteMax,
          date: h.date);
    }).toList();
  }

  List<_SchoolNoteDisplay> _getAllGradedNotes(FamilyProvider provider) {
    final school = _getSchoolNotes(provider);
    final behavior = _getBehaviorNotes(provider);
    final all = [...school, ...behavior];
    all.sort((a, b) => b.date.compareTo(a.date));
    return all;
  }

  // ── BUILD ──────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Consumer<FamilyProvider>(
      builder: (context, provider, _) {
        final child = provider.getChild(widget.childId);
        final schoolNotes = _getSchoolNotes(provider);
        final behaviorNotes = _getBehaviorNotes(provider);
        final allNotes = _getAllGradedNotes(provider);

        final avgPercent = allNotes.isNotEmpty
            ? allNotes.fold<double>(
                    0,
                    (sum, n) =>
                        sum +
                        (n.maxValue > 0
                            ? n.value / n.maxValue * 100
                            : 0)) /
                allNotes.length
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
                  child: const Text('📚', style: TextStyle(fontSize: 22)),
                ),
                const SizedBox(width: 8),
                Text('Notes – ${child?.name ?? ''}'),
              ]),
              backgroundColor: Colors.transparent,
              elevation: 0,
              bottom: TabBar(
                controller: _tabController,
                indicatorColor: Colors.orangeAccent,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white54,
                tabs: [
                  Tab(
                      child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                        const Text('📝 Scolaire'),
                        if (schoolNotes.isNotEmpty) ...[
                          const SizedBox(width: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                                color: Colors.orangeAccent.withOpacity(0.3),
                                borderRadius: BorderRadius.circular(8)),
                            child: Text('${schoolNotes.length}',
                                style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ])),
                  Tab(
                      child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                        const Text('📋 Comport.'),
                        if (behaviorNotes.isNotEmpty) ...[
                          const SizedBox(width: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                                color: Colors.cyanAccent.withOpacity(0.3),
                                borderRadius: BorderRadius.circular(8)),
                            child: Text('${behaviorNotes.length}',
                                style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ])),
                  const Tab(text: '📺 Écran'),
                ],
              ),
              actions: [
                // Bouton calculateur temps d'écran
                IconButton(
                  icon: const Icon(Icons.calculate_rounded,
                      color: Colors.cyanAccent),
                  onPressed: () => PinGuard.guardAction(
                      context, () => _showScreenTimeCalculator(provider)),
                  tooltip: 'Calculer temps d\'écran',
                ),
              ],
            ),
            body: Column(children: [
              // Moyenne globale
              if (allNotes.isNotEmpty)
                Container(
                  margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [
                      Colors.orangeAccent.withOpacity(0.12),
                      Colors.orangeAccent.withOpacity(0.04)
                    ]),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                        color: Colors.orangeAccent.withOpacity(0.3)),
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
                          const Text('Moyenne générale',
                              style: TextStyle(
                                  color: Colors.white70, fontSize: 12)),
                          TweenAnimationBuilder<double>(
                            tween:
                                Tween<double>(begin: 0, end: avgPercent),
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
                        '${allNotes.length} note${allNotes.length > 1 ? 's' : ''}',
                        style: TextStyle(
                            color: Colors.white.withOpacity(0.4),
                            fontSize: 12)),
                  ]),
                ),
              // Tabs
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildNotesList(provider, schoolNotes, isSchool: true),
                    _buildNotesList(provider, behaviorNotes, isSchool: false),
                    _buildScreenTimeTab(provider),
                  ],
                ),
              ),
            ]),
            // Boutons flottants
            floatingActionButton: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_tabController.index == 0)
                  FloatingActionButton.extended(
                    heroTag: 'school',
                    onPressed: () => PinGuard.guardAction(
                        context, () => _showAddNote(provider)),
                    backgroundColor: Colors.orangeAccent.shade700,
                    icon: const Icon(Icons.add),
                    label: const Text('Note scolaire'),
                  ),
                if (_tabController.index == 1) ...[
                  FloatingActionButton.extended(
                    heroTag: 'behavior',
                    onPressed: () => PinGuard.guardAction(
                        context, () => _showAddBehaviorNote(provider)),
                    backgroundColor: Colors.cyanAccent.shade700,
                    icon: const Icon(Icons.add),
                    label: const Text('Note comportement'),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  // ── Liste de notes (réutilisable) ─────────────────────
  Widget _buildNotesList(
      FamilyProvider provider, List<_SchoolNoteDisplay> notes,
      {required bool isSchool}) {
    if (notes.isEmpty) {
      return Center(
          child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
            TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0, end: 1),
              duration: const Duration(milliseconds: 800),
              curve: Curves.elasticOut,
              builder: (context, val, child) =>
                  Transform.scale(scale: val, child: child),
              child: Icon(isSchool ? Icons.school : Icons.mood,
                  size: 64, color: Colors.white24),
            ),
            const SizedBox(height: 12),
            Text(
                isSchool
                    ? 'Aucune note scolaire'
                    : 'Aucune note de comportement',
                style: const TextStyle(color: Colors.white54)),
          ]));
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
      itemCount: notes.length,
      itemBuilder: (context, index) {
        final note = notes[index];
        final percentage =
            note.maxValue > 0 ? (note.value / note.maxValue * 100) : 0.0;
        final isGood = percentage >= 50;
        final stars = _percentToStars(percentage);
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: TvFocusWrapper(
            onTap: () => _showNoteDetail(note, provider),
            child: Dismissible(
              key: Key(note.id),
              direction: DismissDirection.endToStart,
              confirmDismiss: (_) async {
                final pin = context.read<PinProvider>();
                if (pin.isPinSet && !pin.canPerformParentAction()) {
                  PinGuard.guardAction(context, () {
                    _confirmDeleteNote(provider, note.id, note.subject);
                  });
                  return false;
                }
                _confirmDeleteNote(provider, note.id, note.subject);
                return false;
              },
              background: Container(
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.only(right: 20),
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.delete, color: Colors.red),
              ),
              child: GlassCard(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(children: [
                    TweenAnimationBuilder<double>(
                      tween: Tween<double>(begin: 0, end: percentage),
                      duration:
                          Duration(milliseconds: 600 + index * 100),
                      curve: Curves.easeOutCubic,
                      builder: (context, val, _) => Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: (isGood
                                    ? Colors.greenAccent
                                    : Colors.redAccent)
                                .withOpacity(0.15)),
                        child: Center(
                            child: Text('${val.round()}%',
                                style: TextStyle(
                                    color: isGood
                                        ? Colors.greenAccent
                                        : Colors.redAccent,
                                    fontWeight: FontWeight.bold,
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
                                  fontWeight: FontWeight.w600)),
                          const SizedBox(height: 4),
                          Row(children: [
                            Text('${note.value}/${note.maxValue}',
                                style: const TextStyle(
                                    color: Colors.white54,
                                    fontSize: 13)),
                            const SizedBox(width: 8),
                            ...List.generate(
                                stars,
                                (i) => const Padding(
                                    padding: EdgeInsets.only(right: 1),
                                    child: Text('⭐',
                                        style:
                                            TextStyle(fontSize: 10)))),
                          ]),
                        ])),
                    Text(_dayName(note.date),
                        style: const TextStyle(
                            color: Colors.white38, fontSize: 12)),
                    const SizedBox(width: 4),
                    const Icon(Icons.chevron_right,
                        color: Colors.white24, size: 18),
                  ]),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // ── Onglet temps d'écran ──────────────────────────────
  Widget _buildScreenTimeTab(FamilyProvider provider) {
    final globalScore = provider.getWeeklyGlobalScore(widget.childId);
    final schoolAvg = provider.getWeeklySchoolAverage(widget.childId);
    final behaviorScore = provider.getWeeklyBehaviorScore(widget.childId);
    final satMinutes = provider.getSaturdayMinutes(widget.childId);
    final sunMinutes = provider.getSundayMinutes(widget.childId);
    final bonusMinutes = provider.getParentBonusMinutes(widget.childId);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(children: [
        // Score global
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [
              Colors.cyanAccent.withOpacity(0.12),
              Colors.cyanAccent.withOpacity(0.04),
            ]),
            borderRadius: BorderRadius.circular(20),
            border:
                Border.all(color: Colors.cyanAccent.withOpacity(0.3)),
          ),
          child: Column(children: [
            const Text('Score global de la semaine',
                style: TextStyle(color: Colors.white70, fontSize: 13)),
            const SizedBox(height: 8),
            Text('${globalScore.toStringAsFixed(1)}/20',
                style: TextStyle(
                    color: globalScore >= 10
                        ? Colors.greenAccent
                        : Colors.redAccent,
                    fontSize: 36,
                    fontWeight: FontWeight.w900)),
            const SizedBox(height: 4),
            Text(
                '(Scolaire: ${schoolAvg >= 0 ? schoolAvg.toStringAsFixed(1) : "–"} • Comportement: ${behaviorScore.toStringAsFixed(1)})',
                style: TextStyle(
                    color: Colors.white.withOpacity(0.4), fontSize: 11)),
          ]),
        ),
        const SizedBox(height: 16),
        // Temps d'écran résultant
        Row(children: [
          Expanded(
              child: _timeCard(
                  '📅 Samedi', satMinutes, Colors.deepPurpleAccent)),
          const SizedBox(width: 12),
          Expanded(
              child:
                  _timeCard('☀️ Dimanche', sunMinutes, Colors.amber)),
        ]),
        if (bonusMinutes != 0) ...[
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.greenAccent.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: Colors.greenAccent.withOpacity(0.3)),
            ),
            child: Row(children: [
              const Icon(Icons.card_giftcard,
                  color: Colors.greenAccent, size: 18),
              const SizedBox(width: 8),
              Text('Bonus parent : +${_minutesToString(bonusMinutes)}',
                  style: const TextStyle(
                      color: Colors.greenAccent, fontSize: 13)),
            ]),
          ),
        ],
        const SizedBox(height: 16),
        const Text('💡 Le temps d\'écran est calculé automat<span class="cursor">█</span>
