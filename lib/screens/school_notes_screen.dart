import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../providers/family_provider.dart';
import '../providers/pin_provider.dart';
import '../widgets/animated_background.dart';
import '../widgets/glass_card.dart';
import '../widgets/tv_focus_wrapper.dart';

class SchoolNotesScreen extends StatefulWidget {
  final String childId;
  final bool isParent;

  const SchoolNotesScreen({
    super.key,
    required this.childId,
    this.isParent = false,
  });

  @override
  State<SchoolNotesScreen> createState() => _SchoolNotesScreenState();
}

class _SchoolNotesScreenState extends State<SchoolNotesScreen>
    with TickerProviderStateMixin {
  late AnimationController _listAnimController;
  late Animation<double> _listAnim;

  @override
  void initState() {
    super.initState();
    _listAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..forward();
    _listAnim = CurvedAnimation(
      parent: _listAnimController,
      curve: Curves.easeOut,
    );
  }

  @override
  void dispose() {
    _listAnimController.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> _getNotes(FamilyProvider provider) {
    final box = provider.schoolNotesBox;
    if (box == null) return [];
    final all = box.values.toList().cast<Map>();
    return all
        .where((n) => n['childId'] == widget.childId)
        .map((n) => Map<String, dynamic>.from(n))
        .toList()
      ..sort((a, b) {
        final da = DateTime.tryParse(a['date'] ?? '') ?? DateTime(2000);
        final db = DateTime.tryParse(b['date'] ?? '') ?? DateTime(2000);
        return db.compareTo(da);
      });
  }

  Color _gradeColor(double value, double maxValue) {
    if (maxValue == 0) return Colors.grey;
    final ratio = value / maxValue;
    if (ratio >= 0.8) return Colors.green;
    if (ratio >= 0.6) return Colors.amber;
    if (ratio >= 0.4) return Colors.orange;
    return Colors.red;
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return '';
    final d = DateTime.tryParse(dateStr);
    if (d == null) return dateStr;
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  }

  Future<String?> _pickPhoto() async {
    final source = await showDialog<ImageSource>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1a1a2e),
          title: const Text('Photo preuve',
              style: TextStyle(color: Colors.white)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt, color: Colors.cyan),
                title: const Text('Caméra',
                    style: TextStyle(color: Colors.white)),
                onTap: () => Navigator.of(ctx).pop(ImageSource.camera),
              ),
              ListTile(
                leading:
                    const Icon(Icons.photo_library, color: Colors.cyan),
                title: const Text('Galerie',
                    style: TextStyle(color: Colors.white)),
                onTap: () => Navigator.of(ctx).pop(ImageSource.gallery),
              ),
            ],
          ),
        );
      },
    );
    if (source == null) return null;
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: source,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 70,
      );
      if (picked == null) return null;
      final bytes = await picked.readAsBytes();
      if (bytes.lengthInBytes > 2 * 1024 * 1024) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Image trop lourde (max 2 Mo)'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return null;
      }
      return base64Encode(bytes);
    } catch (e) {
      return null;
    }
  }

  void _showFullPhoto(String base64) {
    showDialog(
      context: context,
      builder: (ctx) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Image.memory(
              base64Decode(base64),
              fit: BoxFit.contain,
            ),
          ),
        );
      },
    );
  }

  void _showAddNoteDialog() {
    final subjectController = TextEditingController();
    final valueController = TextEditingController();
    final maxValueController = TextEditingController(text: '20');
    final commentController = TextEditingController();
    String? photoBase64;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setDialogState) {
          return AlertDialog(
            backgroundColor: const Color(0xFF1a1a2e),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20)),
            title: const Text('Nouvelle note',
                style: TextStyle(color: Colors.white)),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: subjectController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Matière',
                      labelStyle: const TextStyle(color: Colors.white54),
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.1),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: valueController,
                          keyboardType: TextInputType.number,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            labelText: 'Note',
                            labelStyle:
                                const TextStyle(color: Colors.white54),
                            filled: true,
                            fillColor: Colors.white.withOpacity(0.1),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 8),
                        child: Text('/',
                            style: TextStyle(
                                color: Colors.white, fontSize: 24)),
                      ),
                      Expanded(
                        child: TextField(
                          controller: maxValueController,
                          keyboardType: TextInputType.number,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            labelText: 'Sur',
                            labelStyle:
                                const TextStyle(color: Colors.white54),
                            filled: true,
                            fillColor: Colors.white.withOpacity(0.1),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: commentController,
                    style: const TextStyle(color: Colors.white),
                    maxLines: 2,
                    decoration: InputDecoration(
                      labelText: 'Commentaire (optionnel)',
                      labelStyle: const TextStyle(color: Colors.white54),
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.1),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (photoBase64 != null) ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.memory(
                        base64Decode(photoBase64!),
                        height: 100,
                        width: double.infinity,
                        fit: BoxFit.cover,
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        setDialogState(() => photoBase64 = null);
                      },
                      child: const Text('Supprimer photo',
                          style: TextStyle(color: Colors.redAccent)),
                    ),
                  ] else
                    OutlinedButton.icon(
                      onPressed: () async {
                        final photo = await _pickPhoto();
                        if (photo != null) {
                          setDialogState(() => photoBase64 = photo);
                        }
                      },
                      icon: const Icon(Icons.camera_alt,
                          color: Colors.white54),
                      label: const Text('Ajouter photo',
                          style: TextStyle(color: Colors.white54)),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(
                            color: Colors.white.withOpacity(0.3)),
                      ),
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Annuler',
                    style: TextStyle(color: Colors.white54)),
              ),
              ElevatedButton(
                onPressed: () {
                  final subject = subjectController.text.trim();
                  final value =
                      double.tryParse(valueController.text.trim());
                  final maxValue =
                      double.tryParse(maxValueController.text.trim());

                  if (subject.isEmpty || value == null || maxValue == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Remplir matière et note'),
                        backgroundColor: Colors.orange,
                      ),
                    );
                    return;
                  }

                  final provider = context.read<FamilyProvider>();

                  // Add school note
                  provider.addSchoolNote(
                    widget.childId,
                    subject,
                    value,
                    maxValue,
                    comment: commentController.text.trim(),
                    photoBase64: photoBase64,
                  );

                  // Award bonus points based on grade
                  final ratio = value / maxValue;
                  int bonusPoints = 0;
                  if (ratio >= 0.9) {
                    bonusPoints = 5;
                  } else if (ratio >= 0.8) {
                    bonusPoints = 3;
                  } else if (ratio >= 0.7) {
                    bonusPoints = 2;
                  } else if (ratio >= 0.6) {
                    bonusPoints = 1;
                  }

                  if (bonusPoints > 0) {
                    // CORRECTED: use positional parameters
                    provider.addPoints(
                      widget.childId,
                      bonusPoints,
                      '$subject|${value.toStringAsFixed(1)}|${maxValue.toStringAsFixed(1)}',
                      category: 'school_note',
                      isBonus: true,
                      proofPhotoBase64: photoBase64,
                    );
                  }

                  Navigator.of(ctx).pop();

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(bonusPoints > 0
                          ? 'Note ajoutée (+$bonusPoints points bonus !)'
                          : 'Note ajoutée'),
                      backgroundColor: Colors.green,
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green),
                child: const Text('Ajouter'),
              ),
            ],
          );
        });
      },
    );
  }

  void _showValidateDialog(Map<String, dynamic> note) {
    final pinProvider = context.read<PinProvider>();
    if (!widget.isParent && pinProvider.hasPin) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Seul un parent peut valider'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1a1a2e),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Valider la note',
              style: TextStyle(color: Colors.white)),
          content: Text(
            'Valider ${note['subject']} : ${note['value']}/${note['maxValue']} ?',
            style: const TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () {
                final provider = context.read<FamilyProvider>();
                provider.validateSchoolNote(note['id'], validated: false);
                Navigator.of(ctx).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Note rejetée'),
                    backgroundColor: Colors.red,
                  ),
                );
              },
              child:
                  const Text('Rejeter', style: TextStyle(color: Colors.red)),
            ),
            ElevatedButton(
              onPressed: () {
                final provider = context.read<FamilyProvider>();
                provider.validateSchoolNote(note['id'], validated: true);
                Navigator.of(ctx).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Note validée !'),
                    backgroundColor: Colors.green,
                  ),
                );
              },
              style:
                  ElevatedButton.styleFrom(backgroundColor: Colors.green),
              child: const Text('Valider'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<FamilyProvider>();
    final notes = _getNotes(provider);
    final child = provider.children
        .firstWhere((c) => c['id'] == widget.childId, orElse: () => {});
    final childName = child['name'] ?? 'Enfant';

    // Stats
    double average = 0;
    if (notes.isNotEmpty) {
      double totalRatio = 0;
      int count = 0;
      for (final n in notes) {
        final v = (n['value'] as num?)?.toDouble();
        final m = (n['maxValue'] as num?)?.toDouble();
        if (v != null && m != null && m > 0) {
          totalRatio += v / m;
          count++;
        }
      }
      if (count > 0) average = (totalRatio / count) * 20;
    }

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text('Notes - $childName'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          if (widget.isParent)
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: _showAddNoteDialog,
            ),
        ],
      ),
      body: AnimatedBackground(
        child: SafeArea(
          child: notes.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.school,
                          size: 64,
                          color: Colors.white.withOpacity(0.3)),
                      const SizedBox(height: 16),
                      Text(
                        'Aucune note scolaire',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.5),
                          fontSize: 18,
                        ),
                      ),
                    ],
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      // Stats header
                      GlassCard(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            Column(
                              children: [
                                Text(
                                  '${notes.length}',
                                  style: const TextStyle(
                                    color: Colors.amber,
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const Text('Notes',
                                    style: TextStyle(
                                        color: Colors.white54,
                                        fontSize: 12)),
                              ],
                            ),
                            Column(
                              children: [
                                Text(
                                  average.toStringAsFixed(1),
                                  style: TextStyle(
                                    color: _gradeColor(average, 20),
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const Text('Moyenne /20',
                                    style: TextStyle(
                                        color: Colors.white54,
                                        fontSize: 12)),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Notes list
                      ...notes.asMap().entries.map((entry) {
                        final idx = entry.key;
                        final note = entry.value;
                        final value =
                            (note['value'] as num?)?.toDouble() ?? 0;
                        final maxValue =
                            (note['maxValue'] as num?)?.toDouble() ?? 20;
                        final validated = note['validated'] as bool?;

                        return FadeTransition(
                          opacity: _listAnim,
                          child: SlideTransition(
                            position: Tween<Offset>(
                              begin: Offset(0, 0.1 * (idx + 1)),
                              end: Offset.zero,
                            ).animate(_listAnim),
                            child: Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: GlassCard(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          padding:
                                              const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color: _gradeColor(
                                                    value, maxValue)
                                                .withOpacity(0.2),
                                            borderRadius:
                                                BorderRadius.circular(8),
                                          ),
                                          child: Text(
                                            '${value.toStringAsFixed(1)}/${maxValue.toStringAsFixed(0)}',
                                            style: TextStyle(
                                              color: _gradeColor(
                                                  value, maxValue),
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                note['subject'] ?? '',
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontWeight:
                                                      FontWeight.bold,
                                                ),
                                              ),
                                              Text(
                                                _formatDate(note['date']),
                                                style: const TextStyle(
                                                  color: Colors.white38,
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        if (validated == true)
                                          const Icon(Icons.check_circle,
                                              color: Colors.green)
                                        else if (validated == false)
                                          const Icon(Icons.cancel,
                                              color: Colors.red)
                                        else if (widget.isParent)
                                          IconButton(
                                            icon: const Icon(
                                                Icons.pending_actions,
                                                color: Colors.amber),
                                            onPressed: () =>
                                                _showValidateDialog(note),
                                          ),
                                      ],
                                    ),
                                    if (note['comment'] != null &&
                                        (note['comment'] as String)
                                            .isNotEmpty) ...[
                                      const SizedBox(height: 8),
                                      Text(
                                        note['comment'],
                                        style: const TextStyle(
                                            color: Colors.white54),
                                      ),
                                    ],
                                    if (note['photoBase64'] != null) ...[
                                      const SizedBox(height: 8),
                                      GestureDetector(
                                        onTap: () => _showFullPhoto(
                                            note['photoBase64']),
                                        child: ClipRRect(
                                          borderRadius:
                                              BorderRadius.circular(8),
                                          child: Image.memory(
                                            base64Decode(
                                                note['photoBase64']),
                                            height: 100,
                                            width: double.infinity,
                                            fit: BoxFit.cover,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      }),
                    ],
                  ),
                ),
        ),
      ),
      floatingActionButton: !widget.isParent
          ? FloatingActionButton(
              onPressed: _showAddNoteDialog,
              backgroundColor: Colors.amber,
              child: const Icon(Icons.add),
            )
          : null,
    );
  }
}
