import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:convert';
import 'dart:math' as math;
import 'package:image_picker/image_picker.dart';
import '../providers/family_provider.dart';
import '../providers/pin_provider.dart';
import '../widgets/glass_card.dart';
import '../widgets/tv_focus_wrapper.dart';
import '../widgets/animated_background.dart';

// ════════════════════════════════════════════════
//  ANIMATIONS
// ════════════════════════════════════════════════

class _SchoolNotebookOpen extends StatefulWidget {
  const _SchoolNotebookOpen();
  @override
  State<_SchoolNotebookOpen> createState() => _SchoolNotebookOpenState();
}

class _SchoolNotebookOpenState extends State<_SchoolNotebookOpen>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))
      ..forward().then((_) {
        if (mounted) Future.delayed(const Duration(milliseconds: 400), () {
          if (mounted) Navigator.of(context).pop();
        });
      });
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (_, __) {
          final coverAngle = Tween<double>(begin: 0, end: -math.pi * 0.7)
              .animate(CurvedAnimation(parent: _ctrl, curve: const Interval(0, 0.6, curve: Curves.easeOut)));
          final pageOpacity = Tween<double>(begin: 0, end: 1)
              .animate(CurvedAnimation(parent: _ctrl, curve: const Interval(0.4, 0.8)));
          return SizedBox(
            width: 200, height: 260,
            child: Stack(
              children: [
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 10)],
                    ),
                    child: Opacity(
                      opacity: pageOpacity.value,
                      child: const Center(
                        child: Text('📖', style: TextStyle(fontSize: 60)),
                      ),
                    ),
                  ),
                ),
                Positioned.fill(
                  child: Transform(
                    alignment: Alignment.centerLeft,
                    transform: Matrix4.identity()
                      ..setEntry(3, 2, 0.001)
                      ..rotateY(coverAngle.value),
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF1565C0), Color(0xFF0D47A1)],
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Center(
                        child: Text('📚', style: TextStyle(fontSize: 48)),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
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

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 2000))
      ..forward().then((_) {
        if (mounted) Future.delayed(const Duration(milliseconds: 800), () {
          if (mounted) Navigator.of(context).pop();
        });
      });
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  String get _message {
    if (widget.stars >= 5) return 'EXCELLENT !';
    if (widget.stars >= 4) return 'TRÈS BIEN !';
    if (widget.stars >= 3) return 'BIEN !';
    if (widget.stars >= 2) return 'PEUT MIEUX FAIRE';
    return 'COURAGE !';
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(5, (i) {
              final delay = i * 0.15;
              final starAnim = CurvedAnimation(
                parent: _ctrl,
                curve: Interval(delay, (delay + 0.3).clamp(0, 1), curve: Curves.elasticOut),
              );
              return ScaleTransition(
                scale: starAnim,
                child: Icon(
                  i < widget.stars ? Icons.star : Icons.star_border,
                  color: i < widget.stars ? Colors.amber : Colors.white30,
                  size: 48,
                ),
              );
            }),
          ),
          const SizedBox(height: 16),
          FadeTransition(
            opacity: CurvedAnimation(parent: _ctrl, curve: const Interval(0.6, 1)),
            child: Text(_message,
                style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.amber)),
          ),
        ],
      ),
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
    barrierColor: Colors.black54,
    pageBuilder: (_, __, ___) => const _SchoolNotebookOpen(),
  );
}

Future<void> showStarsAnimation(BuildContext context, int stars) {
  return showGeneralDialog(
    context: context,
    barrierDismissible: false,
    barrierColor: Colors.black54,
    pageBuilder: (_, __, ___) => _StarsAnimation(stars: stars),
  );
}

// ════════════════════════════════════════════════
//  DATA CLASS
// ════════════════════════════════════════════════

class _SchoolNoteDisplay {
  final String id;
  final String subject;
  final double value;
  final double maxValue;
  final DateTime date;
  final String? proofPhotoBase64;
  final String status; // 'pending', 'validated', 'rejected'
  final String? parentNote;

  _SchoolNoteDisplay({
    required this.id,
    required this.subject,
    required this.value,
    required this.maxValue,
    required this.date,
    this.proofPhotoBase64,
    this.status = 'validated',
    this.parentNote,
  });

  double get percent => maxValue > 0 ? (value / maxValue) * 100 : 0;
  int get stars => _percentToStars(percent);
}

// ════════════════════════════════════════════════
//  MAIN SCREEN
// ════════════════════════════════════════════════

class SchoolNotesScreen extends StatefulWidget {
  final String childId;
  const SchoolNotesScreen({super.key, required this.childId});

  @override
  State<SchoolNotesScreen> createState() => _SchoolNotesScreenState();
}

class _SchoolNotesScreenState extends State<SchoolNotesScreen>
    with TickerProviderStateMixin {
  late AnimationController _listController;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _listController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..forward();
  }

  @override
  void dispose() { _listController.dispose(); super.dispose(); }

  // ──────────────────────────────────────────────
  //  RÉCUPÉRER LES NOTES
  // ──────────────────────────────────────────────
  List<_SchoolNoteDisplay> _getSchoolNotes(FamilyProvider provider) {
    // Notes validées (dans l'historique)
    final history = provider.getHistory(widget.childId);
    final validated = history
        .where((e) => e.category == 'school_note')
        .map((e) {
      final parts = e.reason.split('|');
      final subject = parts.length > 0 ? parts[0].trim() : 'Note';
      final value = parts.length > 1 ? double.tryParse(parts[1]) ?? 0 : 0.0;
      final maxValue = parts.length > 2 ? double.tryParse(parts[2]) ?? 20 : 20.0;
      return _SchoolNoteDisplay(
        id: e.id,
        subject: subject,
        value: value,
        maxValue: maxValue,
        date: e.date,
        proofPhotoBase64: e.proofPhotoBase64,
        status: 'validated',
      );
    }).toList();

    // Notes en attente de validation
    final pending = provider.getPendingSchoolNotes(widget.childId);
    final pendingNotes = pending.map((p) {
      return _SchoolNoteDisplay(
        id: p['id'] as String,
        subject: p['subject'] as String? ?? 'Note',
        value: (p['value'] as num?)?.toDouble() ?? 0,
        maxValue: (p['maxValue'] as num?)?.toDouble() ?? 20,
        date: DateTime.tryParse(p['submittedAt'] ?? '') ?? DateTime.now(),
        proofPhotoBase64: p['proofPhotoBase64'] as String?,
        status: 'pending',
        parentNote: p['parentNote'] as String?,
      );
    }).toList();

    // Notes rejetées (récentes)
    final rejected = provider.getRejectedSchoolNotes(widget.childId);
    final rejectedNotes = rejected.map((r) {
      return _SchoolNoteDisplay(
        id: r['id'] as String,
        subject: r['subject'] as String? ?? 'Note',
        value: (r['value'] as num?)?.toDouble() ?? 0,
        maxValue: (r['maxValue'] as num?)?.toDouble() ?? 20,
        date: DateTime.tryParse(r['submittedAt'] ?? '') ?? DateTime.now(),
        proofPhotoBase64: r['proofPhotoBase64'] as String?,
        status: 'rejected',
        parentNote: r['parentNote'] as String?,
      );
    }).toList();

    final all = [...pendingNotes, ...rejectedNotes, ...validated];
    all.sort((a, b) => b.date.compareTo(a.date));
    return all;
  }

  // ──────────────────────────────────────────────
  //  PHOTO DE PREUVE
  // ──────────────────────────────────────────────
  Future<String?> _pickProofPhoto() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor.withOpacity(0.95),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('📸 Photo du bulletin / devoir',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text('Prends en photo ta note pour prouver ton résultat',
                style: TextStyle(color: Colors.white70), textAlign: TextAlign.center),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: TvFocusWrapper(
                    onTap: () => Navigator.pop(ctx, ImageSource.camera),
                    child: GlassCard(
                      onTap: () => Navigator.pop(ctx, ImageSource.camera),
                      child: const Padding(
                        padding: EdgeInsets.symmetric(vertical: 20),
                        child: Column(children: [
                          Text('📷', style: TextStyle(fontSize: 32)),
                          SizedBox(height: 8),
                          Text('Appareil photo', style: TextStyle(fontWeight: FontWeight.bold)),
                        ]),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TvFocusWrapper(
                    onTap: () => Navigator.pop(ctx, ImageSource.gallery),
                    child: GlassCard(
                      onTap: () => Navigator.pop(ctx, ImageSource.gallery),
                      child: const Padding(
                        padding: EdgeInsets.symmetric(vertical: 20),
                        child: Column(children: [
                          Text('🖼️', style: TextStyle(fontSize: 32)),
                          SizedBox(height: 8),
                          Text('Galerie', style: TextStyle(fontWeight: FontWeight.bold)),
                        ]),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
    if (source == null) return null;

    final XFile? image = await _picker.pickImage(
      source: source, maxWidth: 1200, maxHeight: 1200, imageQuality: 70,
    );
    if (image == null) return null;

    final bytes = await image.readAsBytes();
    if (bytes.length > 2 * 1024 * 1024) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: const Text('⚠️ Photo trop lourde (max 2 Mo)'),
              backgroundColor: Colors.orange.withOpacity(0.8),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
        );
      }
      return null;
    }
    return base64Encode(bytes);
  }

  // ──────────────────────────────────────────────
  //  ENFANT : SOUMETTRE UNE NOTE
  // ──────────────────────────────────────────────
  void _showAddNote(BuildContext context) async {
    await showSchoolNotebookAnimation(context);
    if (!mounted) return;

    final pinProvider = context.read<PinProvider>();
    final isParent = pinProvider.canPerformParentAction();

    String subject = '';
    double noteValue = 10;
    double maxValue = 20;
    String? proofPhoto;

    final subjects = [
      'Mathématiques', 'Français', 'Histoire', 'Géographie', 'Sciences',
      'Anglais', 'Espagnol', 'Musique', 'Arts plastiques', 'EPS',
      'Physique', 'SVT', 'Technologie',
    ];

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return Container(
              padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
              constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.9),
              decoration: BoxDecoration(
                color: Theme.of(context).scaffoldBackgroundColor.withOpacity(0.95),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(width: 40, height: 4,
                          decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
                    ),
                    const SizedBox(height: 16),
                    const Text('📝 Nouvelle note scolaire',
                        style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center),
                    if (!isParent)
                      const Padding(
                        padding: EdgeInsets.only(top: 4),
                        child: Text('Ta soumission sera vérifiée par ton parent',
                            style: TextStyle(color: Colors.white54, fontSize: 12),
                            textAlign: TextAlign.center),
                      ),
                    const SizedBox(height: 20),

                    // Matière
                    const Text('Matière :', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8, runSpacing: 8,
                      children: subjects.map((s) {
                        final isSelected = subject == s;
                        return TvFocusWrapper(
                          onTap: () => setModalState(() => subject = s),
                          child: ChoiceChip(
                            label: Text(s, style: const TextStyle(fontSize: 12)),
                            selected: isSelected,
                            selectedColor: Colors.blue.withOpacity(0.3),
                            onSelected: (_) => setModalState(() => subject = s),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),

                    // Barème
                    const Text('Barème :', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [10.0, 20.0, 40.0, 100.0].map((m) {
                        final isSelected = maxValue == m;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: TvFocusWrapper(
                            onTap: () => setModalState(() {
                              maxValue = m;
                              if (noteValue > m) noteValue = m;
                            }),
                            child: ChoiceChip(
                              label: Text('/ ${m.toInt()}'),
                              selected: isSelected,
                              selectedColor: Colors.blue.withOpacity(0.3),
                              onSelected: (_) => setModalState(() {
                                maxValue = m;
                                if (noteValue > m) noteValue = m;
                              }),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),

                    // Note
                    Center(
                      child: GlassCard(
                        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                        child: Column(
                          children: [
                            Text('${noteValue.toStringAsFixed(noteValue == noteValue.roundToDouble() ? 0 : 1)} / ${maxValue.toInt()}',
                                style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 4),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: List.generate(5, (i) => Icon(
                                i < _percentToStars((noteValue / maxValue) * 100) ? Icons.star : Icons.star_border,
                                color: Colors.amber, size: 20,
                              )),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Slider(
                      value: noteValue,
                      min: 0, max: maxValue,
                      divisions: (maxValue * 2).toInt(),
                      activeColor: Colors.blue,
                      label: noteValue.toStringAsFixed(1),
                      onChanged: (v) => setModalState(() => noteValue = v),
                    ),
                    const SizedBox(height: 16),

                    // Photo de preuve
                    Text(isParent ? '📸 Photo (optionnelle) :' : '📸 Photo de preuve (obligatoire) :',
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    if (!isParent)
                      const Text('Photographie ton bulletin ou ton devoir corrigé',
                          style: TextStyle(color: Colors.white54, fontSize: 12)),
                    const SizedBox(height: 8),

                    if (proofPhoto != null) ...[
                      Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.memory(base64Decode(proofPhoto!),
                                height: 180, width: double.infinity, fit: BoxFit.cover),
                          ),
                          Positioned(
                            top: 8, right: 8,
                            child: GestureDetector(
                              onTap: () => setModalState(() => proofPhoto = null),
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                                child: const Icon(Icons.close, size: 20),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      TextButton.icon(
                        onPressed: () async {
                          final photo = await _pickProofPhoto();
                          if (photo != null) setModalState(() => proofPhoto = photo);
                        },
                        icon: const Icon(Icons.refresh),
                        label: const Text('Reprendre'),
                      ),
                    ] else
                      TvFocusWrapper(
                        onTap: () async {
                          final photo = await _pickProofPhoto();
                          if (photo != null) setModalState(() => proofPhoto = photo);
                        },
                        child: GlassCard(
                          onTap: () async {
                            final photo = await _pickProofPhoto();
                            if (photo != null) setModalState(() => proofPhoto = photo);
                          },
                          glowColor: Colors.blue,
                          child: const Padding(
                            padding: EdgeInsets.symmetric(vertical: 24),
                            child: Column(children: [
                              Icon(Icons.add_a_photo, size: 40, color: Colors.lightBlueAccent),
                              SizedBox(height: 8),
                              Text('Ajouter une photo', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.lightBlueAccent)),
                            ]),
                          ),
                        ),
                      ),
                    const SizedBox(height: 24),

                    // Soumettre
                    TvFocusWrapper(
                      onTap: () {
                        if (subject.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: const Text('Choisis une matière !'),
                                backgroundColor: Colors.orange.withOpacity(0.8),
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                          );
                          return;
                        }
                        if (!isParent && proofPhoto == null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: const Text('📸 Tu dois prendre une photo de ta note !'),
                                backgroundColor: Colors.orange.withOpacity(0.8),
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                          );
                          return;
                        }

                        final familyProvider = context.read<FamilyProvider>();

                        if (isParent) {
                          // Le parent peut ajouter directement
                          _directSubmitNote(familyProvider, subject, noteValue, maxValue, proofPhoto);
                          Navigator.pop(ctx);
                        } else {
                          // L'enfant soumet pour validation
                          familyProvider.submitSchoolNote(
                            childId: widget.childId,
                            subject: subject,
                            value: noteValue,
                            maxValue: maxValue,
                            proofPhotoBase64: proofPhoto!,
                          );
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: const Text('📝 Note soumise ! En attente de validation du parent...'),
                              backgroundColor: Colors.blue.withOpacity(0.8),
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          );
                        }
                        setState(() {});
                      },
                      child: ElevatedButton.icon(
                        onPressed: () {},  // Handled by TvFocusWrapper
                        icon: Icon(isParent ? Icons.check : Icons.send),
                        label: Text(isParent ? 'Ajouter la note' : 'Soumettre pour validation'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          backgroundColor: Colors.blue.withOpacity(0.4),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _directSubmitNote(FamilyProvider provider, String subject, double value, double maxValue, String? photo) {
    // Convertir en note sur 20
    final normalizedNote = maxValue > 0 ? (value / maxValue) * 20 : 0;
    int bonusPoints = 0;
    if (normalizedNote >= 18) bonusPoints = 5;
    else if (normalizedNote >= 15) bonusPoints = 3;
    else if (normalizedNote >= 12) bonusPoints = 2;
    else if (normalizedNote >= 10) bonusPoints = 1;

    provider.addPoints(
      childId: widget.childId,
      points: bonusPoints,
      reason: '$subject|$value|$maxValue',
      category: 'school_note',
      isBonus: true,
      proofPhotoBase64: photo,
    );

    final stars = _percentToStars((value / maxValue) * 100);
    showStarsAnimation(context, stars);
  }

  // ──────────────────────────────────────────────
  //  PARENT : VALIDER UNE NOTE
  // ──────────────────────────────────────────────
  void _showParentNoteValidation(BuildContext context, _SchoolNoteDisplay note) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        String parentNote = '';
        double adjustedValue = note.value;

        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return Container(
              constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.9),
              decoration: BoxDecoration(
                color: Theme.of(context).scaffoldBackgroundColor.withOpacity(0.95),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(width: 40, height: 4,
                        decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
                    const SizedBox(height: 16),
                    const Text('👨‍👩‍👧‍👦', style: TextStyle(fontSize: 48)),
                    const SizedBox(height: 8),
                    const Text('Validation de note scolaire',
                        style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),

                    // Info note
                    GlassCard(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            Text(note.subject,
                                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 8),
                            Text('${note.value.toStringAsFixed(1)} / ${note.maxValue.toInt()}',
                                style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.lightBlueAccent)),
                            const SizedBox(height: 4),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: List.generate(5, (i) => Icon(
                                i < note.stars ? Icons.star : Icons.star_border,
                                color: Colors.amber, size: 24,
                              )),
                            ),
                            const SizedBox(height: 8),
                            Text('Soumis le ${_formatDate(note.date)}',
                                style: const TextStyle(color: Colors.white38, fontSize: 12)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Photo
                    const Text('📸 Photo de preuve :', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    if (note.proofPhotoBase64 != null && note.proofPhotoBase64!.isNotEmpty)
                      GestureDetector(
                        onTap: () => _showFullPhoto(context, note.proofPhotoBase64!),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.memory(base64Decode(note.proofPhotoBase64!),
                              height: 250, width: double.infinity, fit: BoxFit.cover),
                        ),
                      )
                    else
                      GlassCard(
                        child: const Padding(
                          padding: EdgeInsets.all(20),
                          child: Text('⚠️ Aucune photo', style: TextStyle(color: Colors.redAccent)),
                        ),
                      ),
                    if (note.proofPhotoBase64 != null)
                      const Text('Tape sur la photo pour agrandir',
                          style: TextStyle(color: Colors.white38, fontSize: 11)),
                    const SizedBox(height: 16),

                    // Ajustement de la note
                    const Text('Ajuster la note si besoin :',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text('${adjustedValue.toStringAsFixed(1)} / ${note.maxValue.toInt()}',
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    Slider(
                      value: adjustedValue,
                      min: 0, max: note.maxValue,
                      divisions: (note.maxValue * 2).toInt(),
                      activeColor: Colors.blue,
                      label: adjustedValue.toStringAsFixed(1),
                      onChanged: (v) => setModalState(() => adjustedValue = v),
                    ),
                    const SizedBox(height: 12),

                    // Note parent
                    TextField(
                      onChanged: (v) => parentNote = v,
                      decoration: InputDecoration(
                        labelText: 'Commentaire (optionnel)',
                        hintText: 'Ex: Bravo continue ! / La photo ne correspond pas...',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        prefixIcon: const Icon(Icons.note),
                      ),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 20),

                    // Boutons
                    Row(
                      children: [
                        Expanded(
                          child: TvFocusWrapper(
                            onTap: () {
                              final provider = context.read<FamilyProvider>();
                              provider.rejectSchoolNote(
                                childId: widget.childId,
                                noteId: note.id,
                                parentNote: parentNote.isNotEmpty ? parentNote : null,
                              );
                              Navigator.pop(ctx);
                              setState(() {});
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: const Text('❌ Note refusée'),
                                    backgroundColor: Colors.red.withOpacity(0.8),
                                    behavior: SnackBarBehavior.floating,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                              );
                            },
                            child: ElevatedButton.icon(
                              onPressed: () {
                                final provider = context.read<FamilyProvider>();
                                provider.rejectSchoolNote(
                                  childId: widget.childId, noteId: note.id,
                                  parentNote: parentNote.isNotEmpty ? parentNote : null,
                                );
                                Navigator.pop(ctx);
                                setState(() {});
                              },
                              icon: const Icon(Icons.close, color: Colors.redAccent),
                              label: const Text('Refuser', style: TextStyle(color: Colors.redAccent)),
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                backgroundColor: Colors.red.withOpacity(0.15),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TvFocusWrapper(
                            onTap: () {
                              final provider = context.read<FamilyProvider>();
                              provider.validateSchoolNote(
                                childId: widget.childId,
                                noteId: note.id,
                                adjustedValue: adjustedValue,
                                maxValue: note.maxValue,
                                subject: note.subject,
                                proofPhotoBase64: note.proofPhotoBase64,
                                parentNote: parentNote.isNotEmpty ? parentNote : null,
                              );
                              Navigator.pop(ctx);
                              setState(() {});

                              final stars = _percentToStars((adjustedValue / note.maxValue) * 100);
                              showStarsAnimation(context, stars);

                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('✅ Note validée : ${adjustedValue.toStringAsFixed(1)}/${note.maxValue.toInt()}'),
                                    backgroundColor: Colors.green.withOpacity(0.8),
                                    behavior: SnackBarBehavior.floating,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                              );
                            },
                            child: ElevatedButton.icon(
                              onPressed: () {},
                              icon: const Icon(Icons.check, color: Colors.greenAccent),
                              label: const Text('Valider ✅', style: TextStyle(color: Colors.greenAccent)),
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                backgroundColor: Colors.green.withOpacity(0.15),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showFullPhoto(BuildContext context, String base64Photo) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: const EdgeInsets.all(8),
        child: Stack(children: [
          InteractiveViewer(child: Image.memory(base64Decode(base64Photo), fit: BoxFit.contain)),
          Positioned(top: 8, right: 8,
            child: IconButton(onPressed: () => Navigator.pop(ctx),
                icon: const Icon(Icons.close, color: Colors.white, size: 32))),
        ]),
      ),
    );
  }

  void _showNoteDetail(BuildContext context, _SchoolNoteDisplay note) {
    final isParent = context.read<PinProvider>().canPerformParentAction();

    if (note.status == 'pending' && isParent) {
      _showParentNoteValidation(context, note);
      return;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor.withOpacity(0.95),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 4,
                decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 16),
            Text(note.subject, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Text('${note.value.toStringAsFixed(1)} / ${note.maxValue.toInt()}',
                style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(5, (i) => Icon(
                i < note.stars ? Icons.star : Icons.star_border, color: Colors.amber, size: 32,
              )),
            ),
            const SizedBox(height: 12),
            if (note.status == 'pending')
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.amber.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text('⏳ En attente de validation',
                    style: TextStyle(color: Colors.amberAccent, fontWeight: FontWeight.bold)),
              ),
            if (note.status == 'rejected') ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text('❌ Refusée par le parent',
                    style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
              ),
              if (note.parentNote != null) ...[
                const SizedBox(height: 8),
                Text('Message : "${note.parentNote}"',
                    style: const TextStyle(fontStyle: FontStyle.italic, color: Colors.white70)),
              ],
            ],
            if (note.proofPhotoBase64 != null) ...[
              const SizedBox(height: 12),
              GestureDetector(
                onTap: () => _showFullPhoto(context, note.proofPhotoBase64!),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.memory(base64Decode(note.proofPhotoBase64!),
                      height: 150, width: double.infinity, fit: BoxFit.cover),
                ),
              ),
            ],
            const SizedBox(height: 8),
            _detailRow('Date', _formatDate(note.date)),
            _detailRow('Pourcentage', '${note.percent.toStringAsFixed(0)}%'),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.white54)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  String _formatDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  // ──────────────────────────────────────────────
  //  BUILD
  // ──────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Consumer<FamilyProvider>(
      builder: (context, provider, _) {
        final isParent = context.watch<PinProvider>().canPerformParentAction();
        final notes = _getSchoolNotes(provider);
        final validatedNotes = notes.where((n) => n.status == 'validated').toList();
        final pendingNotes = notes.where((n) => n.status == 'pending').toList();

        final avgPercent = validatedNotes.isNotEmpty
            ? validatedNotes.map((n) => n.percent).reduce((a, b) => a + b) / validatedNotes.length
            : 0.0;
        final avgStars = _percentToStars(avgPercent);

        return AnimatedBackground(
          child: Scaffold(
            backgroundColor: Colors.transparent,
            floatingActionButton: TvFocusWrapper(
              onTap: () => _showAddNote(context),
              child: FloatingActionButton.extended(
                onPressed: () => _showAddNote(context),
                backgroundColor: Colors.blue.withOpacity(0.8),
                icon: const Icon(Icons.add),
                label: Text(isParent ? 'Ajouter une note' : 'Soumettre une note'),
              ),
            ),
            body: SafeArea(
              child: Column(
                children: [
                  // Header
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        TvFocusWrapper(
                          onTap: () => Navigator.pop(context),
                          child: IconButton(
                              onPressed: () => Navigator.pop(context),
                              icon: const Icon(Icons.arrow_back)),
                        ),
                        const Expanded(
                          child: Text('📚 Notes scolaires',
                              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                        ),
                        if (pendingNotes.isNotEmpty && isParent)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.amber.withOpacity(0.3),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.amberAccent.withOpacity(0.5)),
                            ),
                            child: Text('${pendingNotes.length} en attente',
                                style: const TextStyle(color: Colors.amberAccent, fontSize: 12, fontWeight: FontWeight.bold)),
                          ),
                      ],
                    ),
                  ),

                  // Moyenne
                  if (validatedNotes.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: GlassCard(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            children: [
                              Text('${avgPercent.toStringAsFixed(0)}%',
                                  style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 4),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: List.generate(5, (i) => Icon(
                                  i < avgStars ? Icons.star : Icons.star_border,
                                  color: Colors.amber, size: 24,
                                )),
                              ),
                              const SizedBox(height: 4),
                              Text('Moyenne sur ${validatedNotes.length} notes validées',
                                  style: const TextStyle(color: Colors.white54, fontSize: 12)),
                            ],
                          ),
                        ),
                      ),
                    ),

                  const SizedBox(height: 8),

                  // Liste
                  Expanded(
                    child: notes.isEmpty
                        ? const Center(
                            child: Column(mainAxisSize: MainAxisSize.min, children: [
                              Text('📚', style: TextStyle(fontSize: 64)),
                              SizedBox(height: 16),
                              Text('Aucune note scolaire', style: TextStyle(fontSize: 18, color: Colors.white54)),
                            ]),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: notes.length,
                            itemBuilder: (_, index) {
                              final note = notes[index];
                              final isPending = note.status == 'pending';
                              final isRejected = note.status == 'rejected';

                              return SlideTransition(
                                position: Tween<Offset>(
                                  begin: const Offset(1, 0), end: Offset.zero,
                                ).animate(CurvedAnimation(
                                  parent: _listController,
                                  curve: Interval(
                                    (index * 0.08).clamp(0.0, 1.0),
                                    ((index * 0.08) + 0.4).clamp(0.0, 1.0),
                                    curve: Curves.easeOutCubic,
                                  ),
                                )),
                                child: Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: TvFocusWrapper(
                                    onTap: () => _showNoteDetail(context, note),
                                    child: GlassCard(
                                      onTap: () => _showNoteDetail(context, note),
                                      glowColor: isPending ? Colors.amber : isRejected ? Colors.red : null,
                                      child: Padding(
                                        padding: const EdgeInsets.all(12),
                                        child: Row(
                                          children: [
                                            // Circular indicator
                                            SizedBox(
                                              width: 50, height: 50,
                                              child: Stack(
                                                children: [
                                                  CircularProgressIndicator(
                                                    value: note.percent / 100,
                                                    backgroundColor: Colors.white12,
                                                    valueColor: AlwaysStoppedAnimation(
                                                      note.percent >= 75 ? Colors.greenAccent
                                                          : note.percent >= 50 ? Colors.orangeAccent
                                                          : Colors.redAccent,
                                                    ),
                                                    strokeWidth: 4,
                                                  ),
                                                  Center(
                                                    child: Text('${note.percent.toInt()}%',
                                                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Row(
                                                    children: [
                                                      Expanded(
                                                        child: Text(note.subject,
                                                            style: const TextStyle(fontWeight: FontWeight.bold)),
                                                      ),
                                                      if (isPending)
                                                        Container(
                                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                          decoration: BoxDecoration(
                                                            color: Colors.amber.withOpacity(0.2),
                                                            borderRadius: BorderRadius.circular(6),
                                                          ),
                                                          child: const Text('⏳', style: TextStyle(fontSize: 12)),
                                                        ),
                                                      if (isRejected)
                                                        Container(
                                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                          decoration: BoxDecoration(
                                                            color: Colors.red.withOpacity(0.2),
                                                            borderRadius: BorderRadius.circular(6),
                                                          ),
                                                          child: const Text('❌', style: TextStyle(fontSize: 12)),
                                                        ),
                                                    ],
                                                  ),
                                                  Text('${note.value.toStringAsFixed(1)} / ${note.maxValue.toInt()}',
                                                      style: const TextStyle(color: Colors.white70, fontSize: 13)),
                                                  Row(
                                                    children: [
                                                      ...List.generate(5, (i) => Icon(
                                                        i < note.stars ? Icons.star : Icons.star_border,
                                                        color: Colors.amber, size: 14,
                                                      )),
                                                      const Spacer(),
                                                      Text(_formatDate(note.date),
                                                          style: const TextStyle(color: Colors.white38, fontSize: 11)),
                                                    ],
                                                  ),
                                                ],
                                              ),
                                            ),
                                            if (isPending && isParent)
                                              const Icon(Icons.gavel, color: Colors.amberAccent, size: 20),
                                            if (note.proofPhotoBase64 != null)
                                              const Padding(
                                                padding: EdgeInsets.only(left: 4),
                                                child: Icon(Icons.photo, color: Colors.white38, size: 16),
                                              ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
