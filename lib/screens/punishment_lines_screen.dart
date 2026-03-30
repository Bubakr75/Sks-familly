import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:convert';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import '../providers/family_provider.dart';
import '../providers/pin_provider.dart';
import '../widgets/glass_card.dart';
import '../widgets/tv_focus_wrapper.dart';
import '../widgets/animated_background.dart';
import '../screens/immunity_lines_screen.dart';
import '../widgets/page_transitions.dart';

class PunishmentLinesScreen extends StatefulWidget {
  final String? childId;
  const PunishmentLinesScreen({super.key, this.childId});

  @override
  State<PunishmentLinesScreen> createState() => _PunishmentLinesScreenState();
}

class _PunishmentLinesScreenState extends State<PunishmentLinesScreen>
    with TickerProviderStateMixin {
  late AnimationController _listController;
  late AnimationController _progressController;
  String? _selectedChildId;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _listController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _selectedChildId = widget.childId;
    _listController.forward();
    _progressController.forward();
  }

  @override
  void dispose() {
    _listController.dispose();
    _progressController.dispose();
    super.dispose();
  }

  // ──────────────────────────────────────────────
  //  PRENDRE UNE PHOTO DE PREUVE
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
            const Text(
              '📸 Photo de preuve',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Prends une photo de tes lignes pour prouver ton travail',
              style: TextStyle(color: Colors.white70),
              textAlign: TextAlign.center,
            ),
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
                        child: Column(
                          children: [
                            Text('📷', style: TextStyle(fontSize: 32)),
                            SizedBox(height: 8),
                            Text('Appareil photo',
                                style: TextStyle(fontWeight: FontWeight.bold)),
                          ],
                        ),
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
                        child: Column(
                          children: [
                            Text('🖼️', style: TextStyle(fontSize: 32)),
                            SizedBox(height: 8),
                            Text('Galerie',
                                style: TextStyle(fontWeight: FontWeight.bold)),
                          ],
                        ),
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
      source: source,
      maxWidth: 1200,
      maxHeight: 1200,
      imageQuality: 70,
    );

    if (image == null) return null;

    final bytes = await image.readAsBytes();
    // Vérifier la taille (max 2 Mo)
    if (bytes.length > 2 * 1024 * 1024) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('⚠️ Photo trop lourde (max 2 Mo)'),
            backgroundColor: Colors.orange.withOpacity(0.8),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
      return null;
    }

    return base64Encode(bytes);
  }

  // ──────────────────────────────────────────────
  //  ENFANT : SOUMETTRE DES LIGNES AVEC PREUVE
  // ──────────────────────────────────────────────
  void _showSubmitLinesDialog(BuildContext context, Map<String, dynamic> punishment) {
    final totalLines = punishment['totalLines'] ?? 0;
    final completedLines = punishment['completedLines'] ?? 0;
    final remaining = totalLines - completedLines;
    int linesToSubmit = remaining.clamp(1, remaining);
    String? proofPhoto;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return Container(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom,
              ),
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.85,
              ),
              decoration: BoxDecoration(
                color: Theme.of(context).scaffoldBackgroundColor.withOpacity(0.95),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 40, height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text('📝', style: TextStyle(fontSize: 48)),
                    const SizedBox(height: 8),
                    const Text(
                      'Soumettre mes lignes',
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Il reste $remaining lignes à faire',
                      style: const TextStyle(color: Colors.white70),
                    ),
                    const SizedBox(height: 24),

                    // Nombre de lignes faites
                    const Text('Combien de lignes as-tu écrites ?',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        TvFocusWrapper(
                          onTap: () {
                            if (linesToSubmit > 1) {
                              setModalState(() => linesToSubmit--);
                            }
                          },
                          child: IconButton(
                            onPressed: linesToSubmit > 1
                                ? () => setModalState(() => linesToSubmit--)
                                : null,
                            icon: const Icon(Icons.remove_circle_outline),
                            iconSize: 32,
                          ),
                        ),
                        GlassCard(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 24, vertical: 12),
                          child: Text(
                            '$linesToSubmit',
                            style: const TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: Colors.orangeAccent,
                            ),
                          ),
                        ),
                        TvFocusWrapper(
                          onTap: () {
                            if (linesToSubmit < remaining) {
                              setModalState(() => linesToSubmit++);
                            }
                          },
                          child: IconButton(
                            onPressed: linesToSubmit < remaining
                                ? () => setModalState(() => linesToSubmit++)
                                : null,
                            icon: const Icon(Icons.add_circle_outline),
                            iconSize: 32,
                          ),
                        ),
                      ],
                    ),
                    // Slider rapide
                    Slider(
                      value: linesToSubmit.toDouble(),
                      min: 1,
                      max: remaining.toDouble(),
                      divisions: remaining > 1 ? remaining - 1 : 1,
                      activeColor: Colors.orangeAccent,
                      label: '$linesToSubmit',
                      onChanged: (v) => setModalState(() => linesToSubmit = v.round()),
                    ),
                    const SizedBox(height: 24),

                    // Photo de preuve
                    const Text(
                      '📸 Photo de preuve (obligatoire)',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Prends en photo tes lignes écrites pour que ton parent puisse vérifier',
                      style: TextStyle(color: Colors.white54, fontSize: 12),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),

                    if (proofPhoto != null) ...[
                      Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.memory(
                              base64Decode(proofPhoto!),
                              height: 200,
                              width: double.infinity,
                              fit: BoxFit.cover,
                            ),
                          ),
                          Positioned(
                            top: 8,
                            right: 8,
                            child: GestureDetector(
                              onTap: () => setModalState(() => proofPhoto = null),
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: const BoxDecoration(
                                  color: Colors.black54,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.close, size: 20),
                              ),
                            ),
                          ),
                          Positioned(
                            bottom: 8,
                            left: 8,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.green.withOpacity(0.8),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text('✅ Photo ajoutée',
                                  style: TextStyle(fontSize: 12)),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      TvFocusWrapper(
                        onTap: () async {
                          final photo = await _pickProofPhoto();
                          if (photo != null) {
                            setModalState(() => proofPhoto = photo);
                          }
                        },
                        child: TextButton.icon(
                          onPressed: () async {
                            final photo = await _pickProofPhoto();
                            if (photo != null) {
                              setModalState(() => proofPhoto = photo);
                            }
                          },
                          icon: const Icon(Icons.refresh),
                          label: const Text('Reprendre la photo'),
                        ),
                      ),
                    ] else
                      TvFocusWrapper(
                        onTap: () async {
                          final photo = await _pickProofPhoto();
                          if (photo != null) {
                            setModalState(() => proofPhoto = photo);
                          }
                        },
                        child: GlassCard(
                          onTap: () async {
                            final photo = await _pickProofPhoto();
                            if (photo != null) {
                              setModalState(() => proofPhoto = photo);
                            }
                          },
                          glowColor: Colors.orange,
                          child: const Padding(
                            padding: EdgeInsets.symmetric(vertical: 32),
                            child: Column(
                              children: [
                                Icon(Icons.add_a_photo,
                                    size: 48, color: Colors.orangeAccent),
                                SizedBox(height: 8),
                                Text('Ajouter une photo',
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.orangeAccent)),
                                Text('Tape ici pour photographier tes lignes',
                                    style: TextStyle(
                                        fontSize: 12, color: Colors.white54)),
                              ],
                            ),
                          ),
                        ),
                      ),

                    const SizedBox(height: 24),

                    // Bouton soumettre
                    TvFocusWrapper(
                      onTap: () {
                        if (proofPhoto == null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: const Text(
                                  '📸 Tu dois prendre une photo de tes lignes !'),
                              backgroundColor: Colors.orange.withOpacity(0.8),
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                            ),
                          );
                          return;
                        }
                        final familyProvider = context.read<FamilyProvider>();
                        familyProvider.submitPunishmentLines(
                          childId: punishment['childId'] as String,
                          punishmentId: punishment['id'] as String,
                          linesSubmitted: linesToSubmit,
                          proofPhotoBase64: proofPhoto!,
                        );
                        Navigator.pop(ctx);
                        setState(() {});
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: const Text(
                                '📝 Lignes soumises ! En attente de validation du parent...'),
                            backgroundColor: Colors.blue.withOpacity(0.8),
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                        );
                      },
                      child: ElevatedButton.icon(
                        onPressed: () {
                          if (proofPhoto == null) return;
                          final familyProvider = context.read<FamilyProvider>();
                          familyProvider.submitPunishmentLines(
                            childId: punishment['childId'] as String,
                            punishmentId: punishment['id'] as String,
                            linesSubmitted: linesToSubmit,
                            proofPhotoBase64: proofPhoto!,
                          );
                          Navigator.pop(ctx);
                          setState(() {});
                        },
                        icon: const Icon(Icons.send),
                        label: const Text('Soumettre pour validation'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              vertical: 16, horizontal: 24),
                          backgroundColor: proofPhoto != null
                              ? Colors.blue.withOpacity(0.4)
                              : Colors.grey.withOpacity(0.2),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
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

  // ──────────────────────────────────────────────
  //  PARENT : VALIDER OU REFUSER LES LIGNES
  // ──────────────────────────────────────────────
  void _showParentValidationDialog(
      BuildContext context, Map<String, dynamic> punishment, Map<String, dynamic> pending) {
    final linesSubmitted = pending['linesSubmitted'] ?? 0;
    final proofPhoto = pending['proofPhotoBase64'] as String?;
    final submittedAt = pending['submittedAt'] != null
        ? DateTime.tryParse(pending['submittedAt'])
        : null;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        String parentNote = '';
        return Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.9,
          ),
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor.withOpacity(0.95),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 16),
                const Text('👨‍👩‍👧‍👦', style: TextStyle(fontSize: 48)),
                const SizedBox(height: 8),
                const Text(
                  'Validation parentale',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  'L\'enfant dit avoir écrit $linesSubmitted lignes',
                  style: const TextStyle(color: Colors.white70),
                ),
                if (submittedAt != null)
                  Text(
                    'Soumis le ${_formatDate(submittedAt)}',
                    style: const TextStyle(color: Colors.white38, fontSize: 12),
                  ),
                const SizedBox(height: 16),

                // Texte de la punition
                GlassCard(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      children: [
                        const Text('Punition :',
                            style: TextStyle(
                                fontWeight: FontWeight.bold, color: Colors.orangeAccent)),
                        const SizedBox(height: 4),
                        Text(
                          '"${punishment['text'] ?? ''}"',
                          style: const TextStyle(fontStyle: FontStyle.italic),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${punishment['completedLines'] ?? 0} / ${punishment['totalLines'] ?? 0} lignes déjà validées',
                          style: const TextStyle(color: Colors.white54, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Photo de preuve
                const Text('📸 Photo de preuve :',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                if (proofPhoto != null && proofPhoto.isNotEmpty)
                  GestureDetector(
                    onTap: () => _showFullPhoto(context, proofPhoto),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.memory(
                        base64Decode(proofPhoto),
                        height: 250,
                        width: double.infinity,
                        fit: BoxFit.cover,
                      ),
                    ),
                  )
                else
                  GlassCard(
                    child: const Padding(
                      padding: EdgeInsets.all(20),
                      child: Text(
                        '⚠️ Aucune photo fournie',
                        style: TextStyle(color: Colors.redAccent),
                      ),
                    ),
                  ),
                const SizedBox(height: 8),
                if (proofPhoto != null)
                  const Text(
                    'Tape sur la photo pour l\'agrandir',
                    style: TextStyle(color: Colors.white38, fontSize: 11),
                  ),
                const SizedBox(height: 16),

                // Note du parent (optionnelle)
                TextField(
                  onChanged: (v) => parentNote = v,
                  decoration: InputDecoration(
                    labelText: 'Note du parent (optionnel)',
                    hintText: 'Ex: Bon travail ! / Écriture à améliorer...',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                    prefixIcon: const Icon(Icons.note),
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 24),

                // Boutons validation
                Row(
                  children: [
                    Expanded(
                      child: TvFocusWrapper(
                        onTap: () {
                          final familyProvider = context.read<FamilyProvider>();
                          familyProvider.rejectPunishmentSubmission(
                            childId: punishment['childId'] as String,
                            punishmentId: punishment['id'] as String,
                            parentNote: parentNote.isNotEmpty ? parentNote : null,
                          );
                          Navigator.pop(ctx);
                          setState(() {});
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: const Text('❌ Lignes refusées'),
                              backgroundColor: Colors.red.withOpacity(0.8),
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                            ),
                          );
                        },
                        child: ElevatedButton.icon(
                          onPressed: () {
                            final familyProvider = context.read<FamilyProvider>();
                            familyProvider.rejectPunishmentSubmission(
                              childId: punishment['childId'] as String,
                              punishmentId: punishment['id'] as String,
                              parentNote: parentNote.isNotEmpty ? parentNote : null,
                            );
                            Navigator.pop(ctx);
                            setState(() {});
                          },
                          icon: const Icon(Icons.close, color: Colors.redAccent),
                          label: const Text('Refuser',
                              style: TextStyle(color: Colors.redAccent)),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            backgroundColor: Colors.red.withOpacity(0.15),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TvFocusWrapper(
                        onTap: () {
                          final familyProvider = context.read<FamilyProvider>();
                          familyProvider.validatePunishmentSubmission(
                            childId: punishment['childId'] as String,
                            punishmentId: punishment['id'] as String,
                            linesValidated: linesSubmitted,
                            parentNote: parentNote.isNotEmpty ? parentNote : null,
                          );
                          Navigator.pop(ctx);
                          setState(() {});
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                  '✅ $linesSubmitted lignes validées !'),
                              backgroundColor: Colors.green.withOpacity(0.8),
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                            ),
                          );
                        },
                        child: ElevatedButton.icon(
                          onPressed: () {
                            final familyProvider = context.read<FamilyProvider>();
                            familyProvider.validatePunishmentSubmission(
                              childId: punishment['childId'] as String,
                              punishmentId: punishment['id'] as String,
                              linesValidated: linesSubmitted,
                              parentNote: parentNote.isNotEmpty ? parentNote : null,
                            );
                            Navigator.pop(ctx);
                            setState(() {});
                          },
                          icon: const Icon(Icons.check, color: Colors.greenAccent),
                          label: const Text('Valider ✅',
                              style: TextStyle(color: Colors.greenAccent)),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            backgroundColor: Colors.green.withOpacity(0.15),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // Valider partiellement
                TvFocusWrapper(
                  onTap: () => _showPartialValidation(
                      context, ctx, punishment, linesSubmitted, parentNote),
                  child: TextButton(
                    onPressed: () => _showPartialValidation(
                        context, ctx, punishment, linesSubmitted, parentNote),
                    child: const Text(
                      'Valider partiellement...',
                      style: TextStyle(color: Colors.white54),
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
  }

  void _showPartialValidation(BuildContext parentContext, BuildContext sheetContext,
      Map<String, dynamic> punishment, int submitted, String parentNote) {
    int partialLines = (submitted / 2).ceil();
    showDialog(
      context: parentContext,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              backgroundColor: Theme.of(parentContext).scaffoldBackgroundColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Text('📝 Validation partielle'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('L\'enfant a soumis $submitted lignes.'),
                  const SizedBox(height: 8),
                  const Text('Combien en validez-vous ?'),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        onPressed: partialLines > 1
                            ? () => setDialogState(() => partialLines--)
                            : null,
                        icon: const Icon(Icons.remove_circle_outline),
                      ),
                      Text('$partialLines',
                          style: const TextStyle(
                              fontSize: 24, fontWeight: FontWeight.bold)),
                      IconButton(
                        onPressed: partialLines < submitted
                            ? () => setDialogState(() => partialLines++)
                            : null,
                        icon: const Icon(Icons.add_circle_outline),
                      ),
                    ],
                  ),
                  Slider(
                    value: partialLines.toDouble(),
                    min: 1,
                    max: submitted.toDouble(),
                    divisions: submitted > 1 ? submitted - 1 : 1,
                    activeColor: Colors.orangeAccent,
                    onChanged: (v) => setDialogState(() => partialLines = v.round()),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Annuler'),
                ),
                ElevatedButton(
                  onPressed: () {
                    final familyProvider = parentContext.read<FamilyProvider>();
                    familyProvider.validatePunishmentSubmission(
                      childId: punishment['childId'] as String,
                      punishmentId: punishment['id'] as String,
                      linesValidated: partialLines,
                      parentNote: parentNote.isNotEmpty
                          ? '$parentNote (partiel: $partialLines/$submitted)'
                          : 'Validation partielle: $partialLines/$submitted',
                    );
                    Navigator.pop(ctx);
                    Navigator.pop(sheetContext);
                    setState(() {});
                    ScaffoldMessenger.of(parentContext).showSnackBar(
                      SnackBar(
                        content: Text('📝 $partialLines/$submitted lignes validées'),
                        backgroundColor: Colors.orange.withOpacity(0.8),
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    );
                  },
                  child: Text('Valider $partialLines lignes'),
                ),
              ],
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
        child: Stack(
          children: [
            InteractiveViewer(
              child: Image.memory(
                base64Decode(base64Photo),
                fit: BoxFit.contain,
              ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: IconButton(
                onPressed: () => Navigator.pop(ctx),
                icon: const Icon(Icons.close, color: Colors.white, size: 32),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ──────────────────────────────────────────────
  //  UTILISER UNE IMMUNITÉ (avec validation parent)
  // ──────────────────────────────────────────────
  void _showUseImmunityDialog(BuildContext context, Map<String, dynamic> punishment) {
    final familyProvider = context.read<FamilyProvider>();
    final childId = punishment['childId'] as String;

    final immunities = familyProvider.getImmunities(childId).where((imm) {
      final status = imm['status'] ?? 'active';
      if (status != 'active') return false;
      if (imm['expiresAt'] != null) {
        final expires = DateTime.tryParse(imm['expiresAt']);
        if (expires != null && expires.isBefore(DateTime.now())) return false;
      }
      return true;
    }).toList();

    if (immunities.isEmpty) {
      _showNoImmunityDialog(context, childId);
      return;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.7,
          ),
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor.withOpacity(0.95),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              const Text('🛡️ Choisir une immunité',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              const Text(
                'Le parent devra valider l\'utilisation',
                style: TextStyle(color: Colors.white54, fontSize: 12),
              ),
              const SizedBox(height: 16),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: immunities.length,
                  itemBuilder: (_, index) {
                    final immunity = immunities[index];
                    final lines = immunity['lines'] ?? 0;
                    final reason = immunity['reason'] ?? 'Immunité';

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: TvFocusWrapper(
                        onTap: () {
                          Navigator.pop(ctx);
                          _requestImmunityUse(context, punishment, immunity);
                        },
                        child: GlassCard(
                          onTap: () {
                            Navigator.pop(ctx);
                            _requestImmunityUse(context, punishment, immunity);
                          },
                          child: ListTile(
                            leading: Container(
                              width: 48, height: 48,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: LinearGradient(colors: [
                                  Colors.cyan.withOpacity(0.3),
                                  Colors.blue.withOpacity(0.3),
                                ]),
                              ),
                              child: const Center(
                                  child: Text('🛡️', style: TextStyle(fontSize: 24))),
                            ),
                            title: Text(reason,
                                style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text('$lines lignes de protection',
                                style: const TextStyle(color: Colors.cyanAccent)),
                            trailing: const Icon(Icons.arrow_forward_ios,
                                size: 16, color: Colors.white54),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  void _requestImmunityUse(BuildContext context, Map<String, dynamic> punishment,
      Map<String, dynamic> immunity) {
    final familyProvider = context.read<FamilyProvider>();
    final pinProvider = context.read<PinProvider>();

    final childId = punishment['childId'] as String;
    final punishmentId = punishment['id'] as String;
    final immunityId = immunity['id'] as String;
    final immunityLines = immunity['lines'] ?? 0;
    final remainingPunishment =
        (punishment['totalLines'] ?? 0) - (punishment['completedLines'] ?? 0);
    final linesRemoved =
        immunityLines >= remainingPunishment ? remainingPunishment : immunityLines;
    final willComplete = immunityLines >= remainingPunishment;

    // Si le parent est déjà en mode parent, on peut valider directement
    if (pinProvider.canPerformParentAction()) {
      _confirmImmunityUseAsParent(
        context,
        childId: childId,
        punishmentId: punishmentId,
        immunityId: immunityId,
        linesRemoved: linesRemoved,
        willComplete: willComplete,
        immunityReason: immunity['reason'] ?? '',
        remainingPunishment: remainingPunishment,
        immunityLines: immunityLines,
      );
    } else {
      // L'enfant fait la demande → en attente de validation parent
      familyProvider.requestImmunityUse(
        childId: childId,
        punishmentId: punishmentId,
        immunityId: immunityId,
        linesToRemove: linesRemoved,
      );
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
              '🛡️ Demande envoyée ! Le parent doit valider l\'utilisation.'),
          backgroundColor: Colors.blue.withOpacity(0.8),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  void _confirmImmunityUseAsParent(
    BuildContext context, {
    required String childId,
    required String punishmentId,
    required String immunityId,
    required int linesRemoved,
    required bool willComplete,
    required String immunityReason,
    required int remainingPunishment,
    required int immunityLines,
  }) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('⚔️ Valider l\'immunité ?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Immunité : "$immunityReason"'),
            const SizedBox(height: 8),
            Text('🛡️ Lignes de protection : $immunityLines'),
            Text('📝 Lignes restantes : $remainingPunishment'),
            const Divider(height: 24),
            if (willComplete)
              const Text('✅ La punition sera complètement annulée !',
                  style: TextStyle(
                      color: Colors.greenAccent, fontWeight: FontWeight.bold))
            else
              Text(
                  '📉 $linesRemoved lignes seront retirées.\nReste : ${remainingPunishment - linesRemoved} lignes.',
                  style: const TextStyle(color: Colors.cyanAccent)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              final familyProvider = context.read<FamilyProvider>();
              familyProvider.useImmunityOnPunishment(
                childId: childId,
                punishmentId: punishmentId,
                immunityId: immunityId,
                linesRemoved: linesRemoved,
              );
              Navigator.pop(ctx);
              setState(() {});
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(willComplete
                      ? '🛡️ Punition annulée !'
                      : '🛡️ $linesRemoved lignes retirées !'),
                  backgroundColor: Colors.cyan.withOpacity(0.8),
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              );
            },
            icon: const Text('🛡️'),
            label: const Text('Valider'),
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.cyan.withOpacity(0.3)),
          ),
        ],
      ),
    );
  }

  void _showNoImmunityDialog(BuildContext context, String childId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('🛡️ Aucune immunité'),
        content: const Text(
          'Aucune immunité active disponible.\n\n'
          'Tu peux en gagner via les lignes d\'immunité ou en faisant du commerce !',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('OK')),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.push(context,
                  SlidePageRoute(page: ImmunityLinesScreen(childId: childId)));
            },
            child: const Text('Voir les immunités'),
          ),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────────
  //  PARENT : VALIDER DEMANDE D'IMMUNITÉ
  // ──────────────────────────────────────────────
  void _showPendingImmunityValidation(
      BuildContext context, Map<String, dynamic> punishment, Map<String, dynamic> request) {
    final immunityId = request['immunityId'] as String;
    final linesRemoved = request['linesToRemove'] ?? 0;
    final familyProvider = context.read<FamilyProvider>();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('🛡️ Demande d\'immunité'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('L\'enfant souhaite utiliser une immunité pour retirer des lignes de punition.'),
            const SizedBox(height: 12),
            Text('Lignes à retirer : $linesRemoved',
                style: const TextStyle(
                    fontWeight: FontWeight.bold, color: Colors.cyanAccent)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              familyProvider.rejectImmunityRequest(
                childId: punishment['childId'] as String,
                punishmentId: punishment['id'] as String,
              );
              Navigator.pop(ctx);
              setState(() {});
            },
            child: const Text('Refuser', style: TextStyle(color: Colors.redAccent)),
          ),
          ElevatedButton.icon(
            onPressed: () {
              familyProvider.useImmunityOnPunishment(
                childId: punishment['childId'] as String,
                punishmentId: punishment['id'] as String,
                immunityId: immunityId,
                linesRemoved: linesRemoved,
              );
              familyProvider.clearImmunityRequest(
                childId: punishment['childId'] as String,
                punishmentId: punishment['id'] as String,
              );
              Navigator.pop(ctx);
              setState(() {});
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('🛡️ Immunité validée ! $linesRemoved lignes retirées.'),
                  backgroundColor: Colors.cyan.withOpacity(0.8),
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              );
            },
            icon: const Icon(Icons.check),
            label: const Text('Approuver'),
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green.withOpacity(0.3)),
          ),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────────
  //  AJOUTER UNE PUNITION (parent)
  // ──────────────────────────────────────────────
  void _showAddPunishment(BuildContext context) {
    final familyProvider = context.read<FamilyProvider>();
    final children = familyProvider.children;
    if (children.isEmpty) return;

    String? selectedChild = _selectedChildId ?? children.first.id;
    final textController = TextEditingController();
    int lineCount = 10;

    final quickPunishments = [
      {'text': 'Je ne dois pas être insolent(e)', 'lines': 10},
      {'text': 'Je dois respecter les règles de la maison', 'lines': 15},
      {'text': 'Je ne dois pas frapper mon frère/ma sœur', 'lines': 20},
      {'text': 'Je dois faire mes devoirs à l\'heure', 'lines': 10},
      {'text': 'Je ne dois pas mentir', 'lines': 15},
      {'text': 'Je dois ranger ma chambre', 'lines': 10},
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return Container(
              padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
              constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.85),
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
                      child: Container(
                        width: 40, height: 4,
                        decoration: BoxDecoration(
                            color: Colors.white24,
                            borderRadius: BorderRadius.circular(2)),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text('✍️ Nouvelle punition',
                        style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center),
                    const SizedBox(height: 20),
                    if (children.length > 1) ...[
                      const Text('Enfant :',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        children: children.map((child) {
                          final isSelected = child.id == selectedChild;
                          return TvFocusWrapper(
                            onTap: () =>
                                setModalState(() => selectedChild = child.id),
                            child: ChoiceChip(
                              label: Text(child.name),
                              selected: isSelected,
                              selectedColor: Colors.orange.withOpacity(0.3),
                              onSelected: (_) =>
                                  setModalState(() => selectedChild = child.id),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 16),
                    ],
                    const Text('Phrases rapides :',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: quickPunishments.map((qp) {
                        return TvFocusWrapper(
                          onTap: () => setModalState(() {
                            textController.text = qp['text'] as String;
                            lineCount = qp['lines'] as int;
                          }),
                          child: ActionChip(
                            label: Text('${qp['text']} (${qp['lines']}x)',
                                style: const TextStyle(fontSize: 12)),
                            onPressed: () => setModalState(() {
                              textController.text = qp['text'] as String;
                              lineCount = qp['lines'] as int;
                            }),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: textController,
                      decoration: InputDecoration(
                        labelText: 'Texte de la punition',
                        hintText: 'Ex: Je ne dois pas...',
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        TvFocusWrapper(
                          onTap: () {
                            if (lineCount > 5) setModalState(() => lineCount -= 5);
                          },
                          child: IconButton(
                            onPressed: lineCount > 5
                                ? () => setModalState(() => lineCount -= 5)
                                : null,
                            icon: const Icon(Icons.remove_circle_outline),
                            iconSize: 32,
                          ),
                        ),
                        GlassCard(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 24, vertical: 12),
                          child: Text('$lineCount lignes',
                              style: const TextStyle(
                                  fontSize: 20, fontWeight: FontWeight.bold)),
                        ),
                        TvFocusWrapper(
                          onTap: () => setModalState(() => lineCount += 5),
                          child: IconButton(
                            onPressed: () => setModalState(() => lineCount += 5),
                            icon: const Icon(Icons.add_circle_outline),
                            iconSize: 32,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    TvFocusWrapper(
                      onTap: () {
                        if (textController.text.trim().isEmpty ||
                            selectedChild == null) return;
                        familyProvider.addPunishment(
                          childId: selectedChild!,
                          text: textController.text.trim(),
                          totalLines: lineCount,
                        );
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('✍️ Punition ajoutée : $lineCount lignes'),
                            backgroundColor: Colors.orange.withOpacity(0.8),
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                        );
                      },
                      child: ElevatedButton.icon(
                        onPressed: () {
                          if (textController.text.trim().isEmpty ||
                              selectedChild == null) return;
                          familyProvider.addPunishment(
                            childId: selectedChild!,
                            text: textController.text.trim(),
                            totalLines: lineCount,
                          );
                          Navigator.pop(ctx);
                        },
                        icon: const Icon(Icons.check),
                        label: const Text('Ajouter la punition'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          backgroundColor: Colors.orange.withOpacity(0.3),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ──────────────────────────────────────────────
  //  DÉTAIL PUNITION
  // ──────────────────────────────────────────────
  void _showPunishmentDetail(BuildContext context, Map<String, dynamic> punishment) {
    final pinProvider = context.read<PinProvider>();
    final familyProvider = context.read<FamilyProvider>();
    final totalLines = punishment['totalLines'] ?? 0;
    final completedLines = punishment['completedLines'] ?? 0;
    final remaining = totalLines - completedLines;
    final progress = totalLines > 0 ? completedLines / totalLines : 0.0;
    final isCompleted = completedLines >= totalLines;
    final childId = punishment['childId'] as String;
    final isParent = pinProvider.canPerformParentAction();

    // Vérifier s'il y a une soumission en attente
    final pendingSubmission = punishment['pendingSubmission'] as Map<String, dynamic>?;
    final hasPending = pendingSubmission != null && pendingSubmission.isNotEmpty;

    // Vérifier s'il y a une demande d'immunité en attente
    final pendingImmunity = punishment['pendingImmunityRequest'] as Map<String, dynamic>?;
    final hasPendingImmunity = pendingImmunity != null && pendingImmunity.isNotEmpty;

    // Immunités disponibles
    final hasImmunities = familyProvider.getImmunities(childId).any((imm) {
      final status = imm['status'] ?? 'active';
      if (status != 'active') return false;
      if (imm['expiresAt'] != null) {
        final expires = DateTime.tryParse(imm['expiresAt']);
        if (expires != null && expires.isBefore(DateTime.now())) return false;
      }
      return true;
    });

    // Dernier rejet
    final lastRejection = punishment['lastRejection'] as Map<String, dynamic>?;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return Container(
          constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.85),
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor.withOpacity(0.95),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                      color: Colors.white24, borderRadius: BorderRadius.circular(2)),
                ),
                const SizedBox(height: 16),
                Text(isCompleted ? '✅' : '✍️',
                    style: const TextStyle(fontSize: 48)),
                const SizedBox(height: 12),
                Text('"${punishment['text'] ?? ''}"',
                    style: const TextStyle(fontSize: 16, fontStyle: FontStyle.italic),
                    textAlign: TextAlign.center),
                const SizedBox(height: 20),

                // Barre de progression
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 12,
                    backgroundColor: Colors.white12,
                    valueColor: AlwaysStoppedAnimation(
                        isCompleted ? Colors.greenAccent : Colors.orangeAccent),
                  ),
                ),
                const SizedBox(height: 8),
                Text('$completedLines / $totalLines lignes (${(progress * 100).toInt()}%)',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 20),

                // ─── SOUMISSION EN ATTENTE (vue parent) ───
                if (hasPending && isParent) ...[
                  GlassCard(
                    glowColor: Colors.amber,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              const Text('⏳', style: TextStyle(fontSize: 24)),
                              const SizedBox(width: 8),
                              const Expanded(
                                child: Text(
                                  'Soumission en attente de validation',
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.amberAccent),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${pendingSubmission!['linesSubmitted']} lignes soumises avec photo',
                            style: const TextStyle(color: Colors.white70),
                          ),
                          const SizedBox(height: 8),
                          TvFocusWrapper(
                            onTap: () {
                              Navigator.pop(ctx);
                              _showParentValidationDialog(
                                  context, punishment, pendingSubmission);
                            },
                            child: ElevatedButton.icon(
                              onPressed: () {
                                Navigator.pop(ctx);
                                _showParentValidationDialog(
                                    context, punishment, pendingSubmission);
                              },
                              icon: const Icon(Icons.visibility),
                              label: const Text('Examiner'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.amber.withOpacity(0.3),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12)),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],

                // ─── SOUMISSION EN ATTENTE (vue enfant) ───
                if (hasPending && !isParent) ...[
                  GlassCard(
                    glowColor: Colors.blue,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          const Text('⏳', style: TextStyle(fontSize: 24)),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'En attente de validation',
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.lightBlueAccent),
                                ),
                                Text(
                                  '${pendingSubmission!['linesSubmitted']} lignes soumises — demande au parent de vérifier !',
                                  style: const TextStyle(
                                      color: Colors.white54, fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],

                // ─── DEMANDE IMMUNITÉ EN ATTENTE (vue parent) ───
                if (hasPendingImmunity && isParent) ...[
                  GlassCard(
                    glowColor: Colors.cyan,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              const Text('🛡️', style: TextStyle(fontSize: 24)),
                              const SizedBox(width: 8),
                              const Expanded(
                                child: Text(
                                  'Demande d\'utilisation d\'immunité',
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.cyanAccent),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          TvFocusWrapper(
                            onTap: () {
                              Navigator.pop(ctx);
                              _showPendingImmunityValidation(
                                  context, punishment, pendingImmunity!);
                            },
                            child: ElevatedButton.icon(
                              onPressed: () {
                                Navigator.pop(ctx);
                                _showPendingImmunityValidation(
                                    context, punishment, pendingImmunity!);
                              },
                              icon: const Icon(Icons.shield),
                              label: const Text('Examiner'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.cyan.withOpacity(0.3),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12)),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],

                // ─── DERNIER REJET ───
                if (lastRejection != null && !isParent) ...[
                  GlassCard(
                    glowColor: Colors.red,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Text('❌', style: TextStyle(fontSize: 20)),
                              SizedBox(width: 8),
                              Text('Dernière soumission refusée',
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.redAccent)),
                            ],
                          ),
                          if (lastRejection['parentNote'] != null) ...[
                            const SizedBox(height: 4),
                            Text('Message : "${lastRejection['parentNote']}"',
                                style: const TextStyle(
                                    color: Colors.white70, fontSize: 12,
                                    fontStyle: FontStyle.italic)),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],

                // ─── ACTIONS ENFANT ───
                if (!isCompleted && !hasPending) ...[
                  // Soumettre des lignes
                  TvFocusWrapper(
                    onTap: () {
                      Navigator.pop(ctx);
                      _showSubmitLinesDialog(context, punishment);
                    },
                    child: GlassCard(
                      glowColor: Colors.orange,
                      onTap: () {
                        Navigator.pop(ctx);
                        _showSubmitLinesDialog(context, punishment);
                      },
                      child: const Padding(
                        padding: EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text('📝', style: TextStyle(fontSize: 24)),
                            SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Soumettre mes lignes',
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                          color: Colors.orangeAccent)),
                                  Text('Prends une photo de tes lignes écrites',
                                      style: TextStyle(
                                          fontSize: 12, color: Colors.white54)),
                                ],
                              ),
                            ),
                            Icon(Icons.camera_alt, color: Colors.orangeAccent),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Utiliser une immunité
                  if (!hasPendingImmunity)
                    TvFocusWrapper(
                      onTap: () {
                        Navigator.pop(ctx);
                        _showUseImmunityDialog(context, punishment);
                      },
                      child: GlassCard(
                        glowColor: Colors.cyan,
                        onTap: () {
                          Navigator.pop(ctx);
                          _showUseImmunityDialog(context, punishment);
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              vertical: 14, horizontal: 16),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Text('🛡️', style: TextStyle(fontSize: 24)),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Utiliser une immunité',
                                        style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                            color: Colors.cyanAccent)),
                                    Text(
                                      hasImmunities
                                          ? 'Des immunités sont disponibles !'
                                          : 'Aucune immunité disponible',
                                      style: TextStyle(
                                          fontSize: 12,
                                          color: hasImmunities
                                              ? Colors.white70
                                              : Colors.white38),
                                    ),
                                  ],
                                ),
                              ),
                              Icon(
                                hasImmunities
                                    ? Icons.shield
                                    : Icons.shield_outlined,
                                color: hasImmunities
                                    ? Colors.cyanAccent
                                    : Colors.white38,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],

                const SizedBox(height: 16),

                // Supprimer (parent)
                if (isParent)
                  TvFocusWrapper(
                    onTap: () {
                      familyProvider.deletePunishment(
                        childId: childId,
                        punishmentId: punishment['id'] as String,
                      );
                      Navigator.pop(ctx);
                      setState(() {});
                    },
                    child: TextButton.icon(
                      onPressed: () {
                        familyProvider.deletePunishment(
                          childId: childId,
                          punishmentId: punishment['id'] as String,
                        );
                        Navigator.pop(ctx);
                        setState(() {});
                      },
                      icon: const Icon(Icons.delete, color: Colors.redAccent),
                      label: const Text('Supprimer',
                          style: TextStyle(color: Colors.redAccent)),
                    ),
                  ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        );
      },
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year} à ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  // ──────────────────────────────────────────────
  //  BUILD
  // ──────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Consumer<FamilyProvider>(
      builder: (context, familyProvider, _) {
        final children = familyProvider.children;
        final pinProvider = context.watch<PinProvider>();
        final isParent = pinProvider.canPerformParentAction();

        if (_selectedChildId == null && children.isNotEmpty) {
          _selectedChildId = children.first.id;
        }

        final allPunishments = <Map<String, dynamic>>[];
        if (_selectedChildId != null) {
          allPunishments.addAll(familyProvider.getPunishments(_selectedChildId!));
        }

        final activePunishments = allPunishments
            .where((p) => (p['completedLines'] ?? 0) < (p['totalLines'] ?? 0))
            .toList();
        final completedPunishments = allPunishments
            .where((p) => (p['completedLines'] ?? 0) >= (p['totalLines'] ?? 0))
            .toList();

        // Compter les actions en attente de validation
        final pendingCount = allPunishments.where((p) {
          final pending = p['pendingSubmission'] as Map<String, dynamic>?;
          final pendingImm = p['pendingImmunityRequest'] as Map<String, dynamic>?;
          return (pending != null && pending.isNotEmpty) ||
              (pendingImm != null && pendingImm.isNotEmpty);
        }).length;

        return AnimatedBackground(
          child: Scaffold(
            backgroundColor: Colors.transparent,
            floatingActionButton: isParent
                ? TvFocusWrapper(
                    onTap: () => _showAddPunishment(context),
                    child: FloatingActionButton.extended(
                      onPressed: () => _showAddPunishment(context),
                      backgroundColor: Colors.orange.withOpacity(0.8),
                      icon: const Icon(Icons.add),
                      label: const Text('Nouvelle punition'),
                    ),
                  )
                : null,
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
                            icon: const Icon(Icons.arrow_back),
                          ),
                        ),
                        const Expanded(
                          child: Text('✍️ Lignes de punition',
                              style: TextStyle(
                                  fontSize: 22, fontWeight: FontWeight.bold)),
                        ),
                        if (pendingCount > 0 && isParent)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.amber.withOpacity(0.3),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                  color: Colors.amberAccent.withOpacity(0.5)),
                            ),
                            child: Text('$pendingCount en attente',
                                style: const TextStyle(
                                    color: Colors.amberAccent,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold)),
                          ),
                      ],
                    ),
                  ),

                  // Sélecteur enfant
                  if (children.length > 1)
                    SizedBox(
                      height: 50,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: children.length,
                        itemBuilder: (_, index) {
                          final child = children[index];
                          final isSelected = child.id == _selectedChildId;
                          // Compter les pending pour cet enfant
                          final childPending = familyProvider
                              .getPunishments(child.id)
                              .where((p) {
                            final ps = p['pendingSubmission']
                                as Map<String, dynamic>?;
                            final pi = p['pendingImmunityRequest']
                                as Map<String, dynamic>?;
                            return (ps != null && ps.isNotEmpty) ||
                                (pi != null && pi.isNotEmpty);
                          }).length;

                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: TvFocusWrapper(
                              onTap: () =>
                                  setState(() => _selectedChildId = child.id),
                              child: Stack(
                                children: [
                                  ChoiceChip(
                                    label: Text(child.name),
                                    selected: isSelected,
                                    selectedColor: Colors.orange.withOpacity(0.3),
                                    onSelected: (_) => setState(
                                        () => _selectedChildId = child.id),
                                  ),
                                  if (childPending > 0)
                                    Positioned(
                                      right: 0,
                                      top: 0,
                                      child: Container(
                                        width: 18, height: 18,
                                        decoration: const BoxDecoration(
                                          color: Colors.amber,
                                          shape: BoxShape.circle,
                                        ),
                                        child: Center(
                                          child: Text('$childPending',
                                              style: const TextStyle(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.black)),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),

                  const SizedBox(height: 8),

                  // Stats
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: GlassCard(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _statChip('Actives', '${activePunishments.length}',
                                Colors.orangeAccent),
                            _statChip('Terminées', '${completedPunishments.length}',
                                Colors.greenAccent),
                            if (pendingCount > 0)
                              _statChip(
                                  'En attente', '$pendingCount', Colors.amberAccent),
                            _statChip('Total', '${allPunishments.length}',
                                Colors.white70),
                          ],
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 8),

                  // Liste
                  Expanded(
                    child: allPunishments.isEmpty
                        ? const Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text('✍️', style: TextStyle(fontSize: 64)),
                                SizedBox(height: 16),
                                Text('Aucune punition en cours',
                                    style: TextStyle(
                                        fontSize: 18, color: Colors.white54)),
                                Text('Espérons que ça dure !',
                                    style: TextStyle(color: Colors.white38)),
                              ],
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: allPunishments.length,
                            itemBuilder: (_, index) {
                              final punishment = allPunishments[index];
                              final total = punishment['totalLines'] ?? 0;
                              final completed = punishment['completedLines'] ?? 0;
                              final prog = total > 0 ? completed / total : 0.0;
                              final isComplete = completed >= total;
                              final hasPendingSub =
                                  punishment['pendingSubmission'] != null &&
                                      (punishment['pendingSubmission']
                                              as Map<String, dynamic>)
                                          .isNotEmpty;
                              final hasPendingImm =
                                  punishment['pendingImmunityRequest'] != null &&
                                      (punishment['pendingImmunityRequest']
                                              as Map<String, dynamic>)
                                          .isNotEmpty;

                              return SlideTransition(
                                position: Tween<Offset>(
                                  begin: const Offset(1, 0),
                                  end: Offset.zero,
                                ).animate(CurvedAnimation(
                                  parent: _listController,
                                  curve: Interval(
                                    (index * 0.1).clamp(0.0, 1.0),
                                    ((index * 0.1) + 0.4).clamp(0.0, 1.0),
                                    curve: Curves.easeOutCubic,
                                  ),
                                )),
                                child: Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: TvFocusWrapper(
                                    onTap: () => _showPunishmentDetail(
                                        context, punishment),
                                    child: GlassCard(
                                      onTap: () => _showPunishmentDetail(
                                          context, punishment),
                                      glowColor: hasPendingSub || hasPendingImm
                                          ? Colors.amber
                                          : null,
                                      child: Padding(
                                        padding: const EdgeInsets.all(16),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Text(
                                                  isComplete
                                                      ? '✅'
                                                      : hasPendingSub
                                                          ? '⏳'
                                                          : '✍️',
                                                  style: const TextStyle(
                                                      fontSize: 24),
                                                ),
                                                const SizedBox(width: 12),
                                                Expanded(
                                                  child: Text(
                                                    punishment['text'] ?? '',
                                                    style: TextStyle(
                                                      fontWeight: FontWeight.bold,
                                                      decoration: isComplete
                                                          ? TextDecoration
                                                              .lineThrough
                                                          : null,
                                                    ),
                                                    maxLines: 2,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  ),
                                                ),
                                                if (hasPendingSub || hasPendingImm)
                                                  Container(
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                            horizontal: 8,
                                                            vertical: 4),
                                                    decoration: BoxDecoration(
                                                      color: Colors.amber
                                                          .withOpacity(0.2),
                                                      borderRadius:
                                                          BorderRadius.circular(8),
                                                      border: Border.all(
                                                          color: Colors.amberAccent
                                                              .withOpacity(0.5)),
                                                    ),
                                                    child: Text(
                                                      hasPendingSub
                                                          ? '📝 En attente'
                                                          : '🛡️ En attente',
                                                      style: const TextStyle(
                                                          fontSize: 10,
                                                          color:
                                                              Colors.amberAccent),
                                                    ),
                                                  ),
                                              ],
                                            ),
                                            const SizedBox(height: 8),
                                            ClipRRect(
                                              borderRadius:
                                                  BorderRadius.circular(4),
                                              child: LinearProgressIndicator(
                                                value: prog,
                                                minHeight: 6,
                                                backgroundColor: Colors.white12,
                                                valueColor:
                                                    AlwaysStoppedAnimation(
                                                  isComplete
                                                      ? Colors.greenAccent
                                                      : Colors.orangeAccent,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text('$completed / $total lignes',
                                                style: const TextStyle(
                                                    fontSize: 12,
                                                    color: Colors.white54)),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
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

  Widget _statChip(String label, String value, Color color) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(value,
            style: TextStyle(
                fontSize: 20, fontWeight: FontWeight.bold, color: color)),
        Text(label,
            style: const TextStyle(fontSize: 12, color: Colors.white54)),
      ],
    );
  }
}
