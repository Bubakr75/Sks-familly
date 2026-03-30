import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../providers/family_provider.dart';
import '../widgets/animated_background.dart';
import '../widgets/glass_card.dart';
import '../widgets/tv_focus_wrapper.dart';

class PunishmentLinesScreen extends StatefulWidget {
  final String childId;
  final bool isParent;

  const PunishmentLinesScreen({
    super.key,
    required this.childId,
    this.isParent = false,
  });

  @override
  State<PunishmentLinesScreen> createState() => _PunishmentLinesScreenState();
}

class _PunishmentLinesScreenState extends State<PunishmentLinesScreen>
    with TickerProviderStateMixin {
  late AnimationController _listAnimController;
  late Animation<double> _listAnim;
  late AnimationController _progressAnimController;
  late Animation<double> _progressAnim;

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

    _progressAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..forward();
    _progressAnim = CurvedAnimation(
      parent: _progressAnimController,
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _listAnimController.dispose();
    _progressAnimController.dispose();
    super.dispose();
  }

  // ==================== PHOTO CAPTURE ====================

  Future<String?> _captureProofPhoto() async {
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
          child: GestureDetector(
            onTap: () => Navigator.of(ctx).pop(),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.memory(
                base64Decode(base64),
                fit: BoxFit.contain,
              ),
            ),
          ),
        );
      },
    );
  }

  // ==================== CHILD: SUBMIT LINES ====================

  void _showSubmitDialog(Map<String, dynamic> punishment) {
    int lineCount = 5;
    String? photoBase64;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setDialogState) {
          return AlertDialog(
            backgroundColor: const Color(0xFF1a1a2e),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20)),
            title: const Text('Soumettre des lignes',
                style: TextStyle(color: Colors.white)),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '« ${punishment['phrase']} »',
                    style: const TextStyle(
                      color: Colors.amber,
                      fontStyle: FontStyle.italic,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  // Line count selector
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        onPressed: () {
                          if (lineCount > 1) {
                            setDialogState(() => lineCount--);
                          }
                        },
                        icon: const Icon(Icons.remove_circle,
                            color: Colors.white54),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '$lineCount lignes',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () {
                          final remaining =
                              ((punishment['totalLines'] as int?) ?? 0) -
                                  ((punishment['completedLines'] as int?) ?? 0);
                          if (lineCount < remaining) {
                            setDialogState(() => lineCount++);
                          }
                        },
                        icon: const Icon(Icons.add_circle,
                            color: Colors.white54),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Photo
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
                        final photo = await _captureProofPhoto();
                        if (photo != null) {
                          setDialogState(() => photoBase64 = photo);
                        }
                      },
                      icon: const Icon(Icons.camera_alt,
                          color: Colors.white54),
                      label: const Text('Photo preuve',
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
                  final provider = context.read<FamilyProvider>();
                  provider.submitPunishmentLines(
                    punishment['id'],
                    lineCount,
                    photoBase64: photoBase64,
                  );
                  Navigator.of(ctx).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('$lineCount lignes soumises !'),
                      backgroundColor: Colors.green,
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green),
                child: const Text('Soumettre'),
              ),
            ],
          );
        });
      },
    );
  }

  // ==================== PARENT: VALIDATE SUBMISSION ====================

  void _showValidateSubmissionDialog(
      Map<String, dynamic> punishment, Map<String, dynamic> submission) {
    final noteController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1a1a2e),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Valider la soumission',
              style: TextStyle(color: Colors.white)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${submission['lineCount']} lignes soumises',
                  style: const TextStyle(
                    color: Colors.amber,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (submission['photoBase64'] != null) ...[
                  const SizedBox(height: 12),
                  GestureDetector(
                    onTap: () =>
                        _showFullPhoto(submission['photoBase64']),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.memory(
                        base64Decode(submission['photoBase64']),
                        height: 120,
                        width: double.infinity,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                TextField(
                  controller: noteController,
                  style: const TextStyle(color: Colors.white),
                  maxLines: 2,
                  decoration: InputDecoration(
                    hintText: 'Note (optionnel)',
                    hintStyle:
                        TextStyle(color: Colors.white.withOpacity(0.4)),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.1),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                final provider = context.read<FamilyProvider>();
                provider.validatePunishmentSubmission(
                  punishment['id'],
                  submission['id'],
                  approved: false,
                  note: noteController.text.trim(),
                );
                Navigator.of(ctx).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Soumission rejetée'),
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
                provider.validatePunishmentSubmission(
                  punishment['id'],
                  submission['id'],
                  approved: true,
                  note: noteController.text.trim(),
                );
                Navigator.of(ctx).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Soumission validée !'),
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

  // ==================== PARENT: PARTIAL VALIDATION ====================

  void _showPartialValidationDialog(
      Map<String, dynamic> punishment, Map<String, dynamic> submission) {
    int approvedLines = (submission['lineCount'] as int?) ?? 0;
    final noteController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setDialogState) {
          return AlertDialog(
            backgroundColor: const Color(0xFF1a1a2e),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20)),
            title: const Text('Validation partielle',
                style: TextStyle(color: Colors.white)),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Combien de lignes acceptez-vous ?',
                    style:
                        TextStyle(color: Colors.white.withOpacity(0.7)),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        onPressed: () {
                          if (approvedLines > 0) {
                            setDialogState(() => approvedLines--);
                          }
                        },
                        icon: const Icon(Icons.remove_circle,
                            color: Colors.white54),
                      ),
                      Text(
                        '$approvedLines / ${submission['lineCount']}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        onPressed: () {
                          if (approvedLines <
                              (submission['lineCount'] as int? ?? 0)) {
                            setDialogState(() => approvedLines++);
                          }
                        },
                        icon: const Icon(Icons.add_circle,
                            color: Colors.white54),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: noteController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Raison',
                      hintStyle:
                          TextStyle(color: Colors.white.withOpacity(0.4)),
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.1),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
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
                  final provider = context.read<FamilyProvider>();
                  provider.validatePunishmentSubmission(
                    punishment['id'],
                    submission['id'],
                    approved: true,
                    note: noteController.text.trim(),
                    approvedLines: approvedLines,
                  );
                  Navigator.of(ctx).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                          '$approvedLines lignes validées sur ${submission['lineCount']}'),
                      backgroundColor: Colors.amber,
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.amber),
                child: const Text('Valider partiellement'),
              ),
            ],
          );
        });
      },
    );
  }

  // ==================== IMMUNITY DIALOG ====================

  void _showImmunityDialog(Map<String, dynamic> punishment) {
    final provider = context.read<FamilyProvider>();
    final activeImmunities = provider
        .getImmunities(widget.childId)
        .where((i) => i['status'] == 'active')
        .toList();

    if (activeImmunities.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Aucune immunité disponible'),
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
          title: const Text('Utiliser une immunité',
              style: TextStyle(color: Colors.white)),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: activeImmunities.length,
              itemBuilder: (ctx, i) {
                final immunity = activeImmunities[i];
                return ListTile(
                  leading: const Icon(Icons.shield, color: Colors.cyan),
                  title: Text(
                    immunity['name'] ?? 'Immunité',
                    style: const TextStyle(color: Colors.white),
                  ),
                  subtitle: Text(
                    immunity['description'] ?? '',
                    style: const TextStyle(color: Colors.white38),
                  ),
                  trailing: Text(
                    '${immunity['usedCount'] ?? 0}/${immunity['maxUses'] ?? 1}',
                    style: const TextStyle(color: Colors.white54),
                  ),
                  onTap: () {
                    // CORRECTED: use named-parameter wrapper
                    provider.useImmunityOnPunishmentNamed(
                      immunityId: immunity['id'],
                      punishmentId: punishment['id'],
                      childId: widget.childId,
                    );
                    Navigator.of(ctx).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Immunité utilisée !'),
                        backgroundColor: Colors.cyan,
                      ),
                    );
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Annuler',
                  style: TextStyle(color: Colors.white54)),
            ),
          ],
        );
      },
    );
  }

  // ==================== ADD PUNISHMENT (parent) ====================

  void _showAddPunishmentDialog() {
    final provider = context.read<FamilyProvider>();
    final children = provider.children;
    String? selectedChildId =
        children.length == 1 ? children.first['id'] : null;
    String phrase = '';
    int lineCount = 10;
    final phraseController = TextEditingController();

    final quickPhrases = [
      'Je ne dois pas mentir.',
      'Je dois respecter les règles.',
      'Je ne dois pas frapper.',
      'Je dois écouter mes parents.',
      'Je dois faire mes devoirs.',
      'Je ne dois pas crier.',
    ];

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setDialogState) {
          return AlertDialog(
            backgroundColor: const Color(0xFF1a1a2e),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20)),
            title: const Text('Nouvelle punition',
                style: TextStyle(color: Colors.white)),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Child selector
                  if (children.length > 1) ...[
                    const Text('Enfant :',
                        style: TextStyle(color: Colors.white54)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: children.map((child) {
                        final isSelected = child['id'] == selectedChildId;
                        return ChoiceChip(
                          label: Text(child['name'] ?? '?'),
                          selected: isSelected,
                          selectedColor: Colors.red.withOpacity(0.5),
                          backgroundColor: Colors.white.withOpacity(0.1),
                          labelStyle: TextStyle(
                            color:
                                isSelected ? Colors.white : Colors.white70,
                          ),
                          onSelected: (_) {
                            setDialogState(() {
                              selectedChildId = child['id'];
                            });
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Quick phrases
                  const Text('Phrases rapides :',
                      style: TextStyle(color: Colors.white54)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: quickPhrases.map((p) {
                      final isSelected = phrase == p;
                      return ChoiceChip(
                        label: Text(p, style: const TextStyle(fontSize: 12)),
                        selected: isSelected,
                        selectedColor: Colors.red.withOpacity(0.5),
                        backgroundColor: Colors.white.withOpacity(0.1),
                        labelStyle: TextStyle(
                          color:
                              isSelected ? Colors.white : Colors.white70,
                        ),
                        onSelected: (selected) {
                          setDialogState(() {
                            phrase = selected ? p : '';
                            if (selected) phraseController.clear();
                          });
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 12),

                  // Custom phrase
                  TextField(
                    controller: phraseController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Ou phrase personnalisée…',
                      hintStyle:
                          TextStyle(color: Colors.white.withOpacity(0.4)),
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.1),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onChanged: (val) {
                      setDialogState(() {
                        phrase = val;
                      });
                    },
                  ),
                  const SizedBox(height: 16),

                  // Line count
                  const Text('Nombre de lignes :',
                      style: TextStyle(color: Colors.white54)),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        onPressed: () {
                          if (lineCount > 1) {
                            setDialogState(() => lineCount--);
                          }
                        },
                        icon: const Icon(Icons.remove_circle,
                            color: Colors.white54),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '$lineCount',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () {
                          setDialogState(() => lineCount++);
                        },
                        icon: const Icon(Icons.add_circle,
                            color: Colors.white54),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Quick line counts
                  Wrap(
                    spacing: 8,
                    alignment: WrapAlignment.center,
                    children: [5, 10, 20, 50, 100].map((v) {
                      return ActionChip(
                        label: Text('$v'),
                        backgroundColor: Colors.white.withOpacity(0.1),
                        labelStyle:
                            const TextStyle(color: Colors.white70),
                        onPressed: () {
                          setDialogState(() => lineCount = v);
                        },
                      );
                    }).toList(),
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
                  final finalPhrase = phrase.trim();
                  if (finalPhrase.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Veuillez saisir une phrase'),
                        backgroundColor: Colors.orange,
                      ),
                    );
                    return;
                  }
                  final targetChild = selectedChildId ?? widget.childId;

                  // CORRECTED: positional parameters
                  provider.addPunishment(
                    targetChild,
                    finalPhrase,
                    lineCount,
                  );

                  Navigator.of(ctx).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                          'Punition ajoutée : $lineCount lignes'),
                      backgroundColor: Colors.red,
                    ),
                  );
                },
                style:
                    ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: const Text('Punir'),
              ),
            ],
          );
        });
      },
    );
  }

  // ==================== DETAIL VIEW ====================

  void _showPunishmentDetail(Map<String, dynamic> punishment) {
    final totalLines = (punishment['totalLines'] as int?) ?? 0;
    final completedLines = (punishment['completedLines'] as int?) ?? 0;
    final progress = totalLines > 0 ? completedLines / totalLines : 0.0;
    final submissions =
        List<Map<String, dynamic>>.from(punishment['submissions'] ?? []);
    final pendingSubmissions =
        submissions.where((s) => s['status'] == 'pending').toList();
    final status = punishment['status'] ?? 'active';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1a1a2e),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          maxChildSize: 0.95,
          minChildSize: 0.4,
          expand: false,
          builder: (ctx, scrollController) {
            return SingleChildScrollView(
              controller: scrollController,
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Handle
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Phrase
                  Text(
                    '« ${punishment['phrase']} »',
                    style: const TextStyle(
                      color: Colors.amber,
                      fontSize: 18,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Progress
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '$completedLines / $totalLines lignes',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: LinearProgressIndicator(
                                value: progress,
                                minHeight: 12,
                                backgroundColor: Colors.white12,
                                valueColor: AlwaysStoppedAnimation(
                                  status == 'completed'
                                      ? Colors.green
                                      : status == 'immunized'
                                          ? Colors.cyan
                                          : Colors.red,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: status == 'completed'
                              ? Colors.green.withOpacity(0.2)
                              : status == 'immunized'
                                  ? Colors.cyan.withOpacity(0.2)
                                  : Colors.red.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          status == 'completed'
                              ? 'Terminé'
                              : status == 'immunized'
                                  ? 'Immunisé'
                                  : 'En cours',
                          style: TextStyle(
                            color: status == 'completed'
                                ? Colors.green
                                : status == 'immunized'
                                    ? Colors.cyan
                                    : Colors.red,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Pending submissions (parent view)
                  if (widget.isParent && pendingSubmissions.isNotEmpty) ...[
                    const Text(
                      'Soumissions en attente',
                      style: TextStyle(
                        color: Colors.amber,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...pendingSubmissions.map((sub) {
                      return Card(
                        color: Colors.amber.withOpacity(0.1),
                        child: ListTile(
                          leading: const Icon(Icons.pending,
                              color: Colors.amber),
                          title: Text(
                            '${sub['lineCount']} lignes',
                            style: const TextStyle(color: Colors.white),
                          ),
                          subtitle: Text(
                            _formatDate(sub['date']),
                            style:
                                const TextStyle(color: Colors.white38),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.check,
                                    color: Colors.green),
                                onPressed: () {
                                  Navigator.of(ctx).pop();
                                  _showValidateSubmissionDialog(
                                      punishment, sub);
                                },
                              ),
                              IconButton(
                                icon: const Icon(Icons.tune,
                                    color: Colors.amber),
                                onPressed: () {
                                  Navigator.of(ctx).pop();
                                  _showPartialValidationDialog(
                                      punishment, sub);
                                },
                              ),
                            ],
                          ),
                          onTap: sub['photoBase64'] != null
                              ? () =>
                                  _showFullPhoto(sub['photoBase64'])
                              : null,
                        ),
                      );
                    }),
                    const SizedBox(height: 16),
                  ],

                  // Actions
                  if (status == 'active') ...[
                    if (!widget.isParent) ...[
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.of(ctx).pop();
                            _showSubmitDialog(punishment);
                          },
                          icon: const Icon(Icons.edit),
                          label: const Text('Soumettre des lignes'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            padding:
                                const EdgeInsets.symmetric(vertical: 14),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () {
                            Navigator.of(ctx).pop();
                            _showImmunityDialog(punishment);
                          },
                          icon: const Icon(Icons.shield,
                              color: Colors.cyan),
                          label: const Text('Utiliser une immunité',
                              style: TextStyle(color: Colors.cyan)),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Colors.cyan),
                            padding:
                                const EdgeInsets.symmetric(vertical: 14),
                          ),
                        ),
                      ),
                    ],
                  ],

                  // All submissions history
                  if (submissions.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    const Text(
                      'Historique des soumissions',
                      style: TextStyle(
                        color: Colors.white54,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...submissions.map((sub) {
                      final subStatus = sub['status'] ?? 'pending';
                      return Card(
                        color: Colors.white.withOpacity(0.05),
                        child: ListTile(
                          leading: Icon(
                            subStatus == 'approved'
                                ? Icons.check_circle
                                : subStatus == 'rejected'
                                    ? Icons.cancel
                                    : Icons.hourglass_bottom,
                            color: subStatus == 'approved'
                                ? Colors.green
                                : subStatus == 'rejected'
                                    ? Colors.red
                                    : Colors.amber,
                          ),
                          title: Text(
                            '${sub['lineCount']} lignes',
                            style: const TextStyle(color: Colors.white),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _formatDate(sub['date']),
                                style: const TextStyle(
                                    color: Colors.white38,
                                    fontSize: 12),
                              ),
                              if (sub['note'] != null &&
                                  (sub['note'] as String).isNotEmpty)
                                Text(
                                  sub['note'],
                                  style: const TextStyle(
                                    color: Colors.white54,
                                    fontStyle: FontStyle.italic,
                                    fontSize: 12,
                                  ),
                                ),
                            ],
                          ),
                          trailing: sub['photoBase64'] != null
                              ? IconButton(
                                  icon: const Icon(Icons.photo,
                                      color: Colors.white38),
                                  onPressed: () =>
                                      _showFullPhoto(sub['photoBase64']),
                                )
                              : null,
                        ),
                      );
                    }),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return '';
    final d = DateTime.tryParse(dateStr);
    if (d == null) return dateStr;
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }

  // ==================== BUILD ====================

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<FamilyProvider>();
    final punishmentsList = provider.getPunishments(widget.childId);
    final child = provider.children
        .firstWhere((c) => c['id'] == widget.childId, orElse: () => {});
    final childName = child['name'] ?? 'Enfant';

    // Sort: active first, then by date
    punishmentsList.sort((a, b) {
      final aActive = a['status'] == 'active' ? 0 : 1;
      final bActive = b['status'] == 'active' ? 0 : 1;
      if (aActive != bActive) return aActive.compareTo(bActive);
      final da = DateTime.tryParse(a['createdAt'] ?? '') ?? DateTime(2000);
      final db = DateTime.tryParse(b['createdAt'] ?? '') ?? DateTime(2000);
      return db.compareTo(da);
    });

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text('Punitions - $childName'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: AnimatedBackground(
        child: SafeArea(
          child: punishmentsList.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.sentiment_satisfied_alt,
                          size: 64,
                          color: Colors.white.withOpacity(0.3)),
                      const SizedBox(height: 16),
                      Text(
                        'Aucune punition',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.5),
                          fontSize: 18,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Bravo, continue comme ça !',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.3),
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: punishmentsList.length,
                  itemBuilder: (ctx, index) {
                    final punishment = punishmentsList[index];
                    final totalLines =
                        (punishment['totalLines'] as int?) ?? 0;
                    final completedLines =
                        (punishment['completedLines'] as int?) ?? 0;
                    final progress =
                        totalLines > 0 ? completedLines / totalLines : 0.0;
                    final status = punishment['status'] ?? 'active';
                    final pendingCount =
                        (List.from(punishment['submissions'] ?? []))
                            .where((s) => s['status'] == 'pending')
                            .length;

                    return FadeTransition(
                      opacity: _listAnim,
                      child: SlideTransition(
                        position: Tween<Offset>(
                          begin: Offset(0, 0.05 * (index + 1)),
                          end: Offset.zero,
                        ).animate(_listAnim),
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: TvFocusWrapper(
                            child: GestureDetector(
                              onTap: () =>
                                  _showPunishmentDetail(punishment),
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
                                            color: status == 'completed'
                                                ? Colors.green
                                                    .withOpacity(0.2)
                                                : status == 'immunized'
                                                    ? Colors.cyan
                                                        .withOpacity(0.2)
                                                    : Colors.red
                                                        .withOpacity(0.2),
                                            borderRadius:
                                                BorderRadius.circular(8),
                                          ),
                                          child: Icon(
                                            status == 'completed'
                                                ? Icons.check_circle
                                                : status == 'immunized'
                                                    ? Icons.shield
                                                    : Icons.edit_note,
                                            color: status == 'completed'
                                                ? Colors.green
                                                : status == 'immunized'
                                                    ? Colors.cyan
                                                    : Colors.red,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                punishment['phrase'] ?? '',
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontWeight:
                                                      FontWeight.bold,
                                                ),
                                                maxLines: 2,
                                                overflow:
                                                    TextOverflow.ellipsis,
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                '$completedLines / $totalLines lignes',
                                                style: const TextStyle(
                                                  color: Colors.white54,
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        if (pendingCount > 0)
                                          Container(
                                            padding:
                                                const EdgeInsets.all(6),
                                            decoration: BoxDecoration(
                                              color: Colors.amber
                                                  .withOpacity(0.2),
                                              shape: BoxShape.circle,
                                            ),
                                            child: Text(
                                              '$pendingCount',
                                              style: const TextStyle(
                                                color: Colors.amber,
                                                fontWeight:
                                                    FontWeight.bold,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ),
                                        const Icon(
                                            Icons.chevron_right,
                                            color: Colors.white24),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    ClipRRect(
                                      borderRadius:
                                          BorderRadius.circular(4),
                                      child: AnimatedBuilder(
                                        animation: _progressAnim,
                                        builder: (ctx, child) {
                                          return LinearProgressIndicator(
                                            value: progress *
                                                _progressAnim.value,
                                            minHeight: 6,
                                            backgroundColor:
                                                Colors.white12,
                                            valueColor:
                                                AlwaysStoppedAnimation(
                                              status == 'completed'
                                                  ? Colors.green
                                                  : status == 'immunized'
                                                      ? Colors.cyan
                                                      : Colors.red,
                                            ),
                                          );
                                        },
                                      ),
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
                ),
        ),
      ),
      floatingActionButton: widget.isParent
          ? FloatingActionButton(
              onPressed: _showAddPunishmentDialog,
              backgroundColor: Colors.red,
              child: const Icon(Icons.add),
            )
          : null,
    );
  }
}
