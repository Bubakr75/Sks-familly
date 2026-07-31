// lib/widgets/ai_photo_flow.dart
//
// Flow Photo IA réutilisable — utilisé par le bouton central de navigation
// et partout où l'on veut analyser une photo avec Gemini.
//
// Étapes : photo → analyse IA → dialogue (type modifiable, enfant, points -/+, raison modifiable) → confirmation.

import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../providers/family_provider.dart';
import '../services/action_photo_service.dart';
import '../services/gemini_service.dart';
import '../services/storage_service.dart';
import '../utils/checklist_helpers.dart';

/// Lance le flow Photo IA complet.
/// Retourne true si des points ont été appliqués, false sinon.
Future<bool> startAiPhotoFlow(BuildContext context) async {
  final fp = context.read<FamilyProvider>();
  final messenger = ScaffoldMessenger.of(context);

  // 1. Prendre la photo
  final xfile = await ImagePicker().pickImage(
    source: ImageSource.camera,
    imageQuality: 70,
    maxWidth: 800,
  );
  if (xfile == null) return false;
  final bytes = await xfile.readAsBytes();
  final base64Photo = base64Encode(bytes);

  // 2. Loader pendant l'analyse
  if (!context.mounted) return false;
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => const AlertDialog(
      backgroundColor: Color(0xFF0F2620),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(color: Colors.deepPurpleAccent),
          SizedBox(height: 16),
          Text('🔍 Analyse IA en cours...',
              style: TextStyle(color: Colors.white)),
        ],
      ),
    ),
  );

  // 3. Analyser avec Gemini — try/catch pour gérer les erreurs
  Map<String, dynamic> result;
  try {
    result = await GeminiService.analyzePhoto(base64Photo);
  } catch (_) {
    if (context.mounted) Navigator.pop(context);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('⚠️ Analyse IA impossible — réessaie'),
        backgroundColor: Colors.redAccent,
      ));
    }
    return false;
  }
  if (context.mounted) Navigator.pop(context);
  if (!context.mounted) return false;

  // 🔒 Validation robuste du résultat Gemini — sans casts directs
  final parsedBonus = parseGeminiType(result['type']);
  final parsedPoints = parseGeminiPoints(result['points']);
  final reason = parseGeminiReason(result['reason']);

  if (parsedBonus == null || parsedPoints == null || reason == null) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('⚠️ Résultat IA invalide — réessaie'),
        backgroundColor: Colors.redAccent,
      ));
    }
    return false;
  }

  final bool isBonus = parsedBonus;
  final int points = parsedPoints.clamp(1, 999);

  // 4. Dialogue de confirmation (StatefulWidget pour garantir dispose)
  final dialogResult = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => _AiPhotoDialog(
      fp: fp,
      bytes: bytes,
      initialIsBonus: isBonus,
      initialPoints: points,
      initialReason: reason,
      base64Photo: base64Photo,
      messenger: messenger,
    ),
  );

  return dialogResult == true;
}

/// StatefulWidget privé garantissant le dispose du TextEditingController.
class _AiPhotoDialog extends StatefulWidget {
  final FamilyProvider fp;
  final Uint8List bytes;
  final bool initialIsBonus;
  final int initialPoints;
  final String initialReason;
  final String base64Photo;
  final ScaffoldMessengerState messenger;

  const _AiPhotoDialog({
    required this.fp,
    required this.bytes,
    required this.initialIsBonus,
    required this.initialPoints,
    required this.initialReason,
    required this.base64Photo,
    required this.messenger,
  });

  @override
  State<_AiPhotoDialog> createState() => _AiPhotoDialogState();
}

class _AiPhotoDialogState extends State<_AiPhotoDialog> {
  late bool _isBonus;
  late int _points;
  late TextEditingController _reasonCtrl;
  String? _selectedChildId;
  bool _processing = false;
  final String _actionId = const Uuid().v4();
  String? _uploadedPhotoPath;

  @override
  void initState() {
    super.initState();
    _isBonus = widget.initialIsBonus;
    _points = widget.initialPoints;
    _reasonCtrl = TextEditingController(text: widget.initialReason);
  }

  @override
  void dispose() {
    final orphanPath = _uploadedPhotoPath;
    if (orphanPath != null) {
      unawaited(
        StorageService().deleteActionPhoto(orphanPath).catchError((_) {}),
      );
    }
    _reasonCtrl.dispose();
    super.dispose();
  }

  bool get _reasonValid => _reasonCtrl.text.trim().isNotEmpty;
  bool get _canConfirm =>
      _selectedChildId != null && !_processing && _reasonValid;

  Future<void> _confirm() async {
    if (!_canConfirm) return;
    setState(() => _processing = true);
    HapticFeedback.mediumImpact();

    final capturedChildId = _selectedChildId!;
    final capturedIsBonus = _isBonus;
    final childName = widget.fp.getChild(capturedChildId)?.name ?? '';
    final child = widget.fp.getChild(capturedChildId);
    final capturedReason = _reasonCtrl.text.trim();
    final actualPoints = actualPenaltyAmount(
      requested: _points,
      balance: child?.points ?? 0,
      isBonus: capturedIsBonus,
    );

    if (actualPoints == 0) {
      // 🔒 Ne pas fermer le dialogue : garder les valeurs, libérer _processing
      if (mounted) {
        setState(() => _processing = false);
      }
      widget.messenger.showSnackBar(const SnackBar(
        content: Text('Cet enfant n\'a aucun point à retirer'),
        backgroundColor: Colors.orange,
      ));
      return;
    }

    try {
      var photoPath = _uploadedPhotoPath;
      if (photoPath == null) {
        final familyId = widget.fp.familyId;
        if (familyId == null) {
          throw StateError('Connexion familiale indisponible.');
        }
        final photo = await ActionPhotoService().prepare(
          base64Decode(widget.base64Photo),
        );
        photoPath = await StorageService().uploadActionPhoto(
          familyId: familyId,
          actionId: _actionId,
          bytes: photo.bytes,
          contentType: photo.contentType,
          extension: photo.extension,
        );
        _uploadedPhotoPath = photoPath;
      }
      await widget.fp.addPoints(
        capturedChildId,
        actualPoints,
        capturedReason,
        category: capturedIsBonus ? 'Bonus' : 'Pénalité',
        isBonus: capturedIsBonus,
        actionId: _actionId,
        photoStoragePath: photoPath,
      );

      if (!mounted) return;
      _uploadedPhotoPath = null;
      Navigator.pop(context, true);

      HapticFeedback.heavyImpact();
      widget.messenger.showSnackBar(SnackBar(
        content: Text(
            '${capturedIsBonus ? "✅ Bonus" : "⚠️ Pénalité"} pour $childName\n$actualPoints pts : "$capturedReason"'),
        backgroundColor:
            capturedIsBonus ? Colors.green.shade700 : Colors.red.shade700,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
      ));
    } catch (_) {
      if (!mounted) return;
      widget.messenger.showSnackBar(const SnackBar(
        content: Text('Erreur lors de l\'application des points'),
        backgroundColor: Colors.redAccent,
      ));
      // Garder le dialogue ouvert pour réessayer
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final children = widget.fp.children;
    final accent = _isBonus ? Colors.green : Colors.redAccent;

    return PopScope(
      canPop: !_processing,
      child: AlertDialog(
        backgroundColor: const Color(0xFF0F2620),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(children: [
          Text('🤖', style: TextStyle(fontSize: 28)),
          SizedBox(width: 8),
          Text('Résultat IA',
              style:
                  TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        ]),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Aperçu photo
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.memory(widget.bytes,
                    height: 100, width: double.infinity, fit: BoxFit.cover),
              ),
              const SizedBox(height: 14),
              // Toggle Bonus/Pénalité
              Row(children: [
                Expanded(
                  child: GestureDetector(
                    onTap: _processing
                        ? null
                        : () => setState(() => _isBonus = true),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: _isBonus
                            ? Colors.green.withValues(alpha: 0.2)
                            : Colors.white.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: _isBonus ? Colors.green : Colors.white12),
                      ),
                      child: Center(
                          child: Text('✅ Bonus',
                              style: TextStyle(
                                  color:
                                      _isBonus ? Colors.green : Colors.white54,
                                  fontWeight: FontWeight.w600))),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: GestureDetector(
                    onTap: _processing
                        ? null
                        : () => setState(() => _isBonus = false),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: !_isBonus
                            ? Colors.redAccent.withValues(alpha: 0.2)
                            : Colors.white.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color:
                                !_isBonus ? Colors.redAccent : Colors.white12),
                      ),
                      child: Center(
                          child: Text('⚠️ Pénalité',
                              style: TextStyle(
                                  color: !_isBonus
                                      ? Colors.redAccent
                                      : Colors.white54,
                                  fontWeight: FontWeight.w600))),
                    ),
                  ),
                ),
              ]),
              const SizedBox(height: 12),
              // Montant modifiable (− / valeur / +)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    onPressed: _processing
                        ? null
                        : () => setState(() {
                              if (_points > 1) _points--;
                            }),
                    icon: const Icon(Icons.remove_circle_outline,
                        color: Colors.white54),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text('${_isBonus ? "+" : "-"}$_points pts',
                        style: TextStyle(
                            color: accent,
                            fontSize: 20,
                            fontWeight: FontWeight.w800)),
                  ),
                  IconButton(
                    onPressed: _processing
                        ? null
                        : () => setState(() {
                              if (_points < 999) _points++;
                            }),
                    icon: const Icon(Icons.add_circle_outline,
                        color: Colors.white54),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // 📝 Explication IA modifiable
              const Text('Explication proposée par l\'IA',
                  style: TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              TextField(
                controller: _reasonCtrl,
                enabled: !_processing,
                maxLength: 150,
                maxLines: 3,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.06),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none),
                  counterStyle:
                      const TextStyle(color: Colors.white24, fontSize: 10),
                ),
                onChanged: (_) => setState(() {}),
              ),
              const Text(
                  'Tu peux corriger l\'explication si l\'IA s\'est trompée.',
                  style: TextStyle(color: Colors.white38, fontSize: 11)),
              const SizedBox(height: 16),
              // Sélecteur enfant
              const Text('Pour quel enfant ?',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              ...children.map((c) {
                final isSelected = _selectedChildId == c.id;
                return GestureDetector(
                  onTap: _processing
                      ? null
                      : () => setState(() => _selectedChildId = c.id),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? accent.withValues(alpha: 0.15)
                          : Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: isSelected ? accent : Colors.white12,
                          width: isSelected ? 1.5 : 1),
                    ),
                    child: Row(children: [
                      Text(c.avatar.isNotEmpty ? c.avatar : '👤',
                          style: const TextStyle(fontSize: 20)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(c.name,
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600)),
                      ),
                      if (isSelected)
                        Icon(Icons.check_circle_rounded,
                            color: accent, size: 20),
                    ]),
                  ),
                );
              }),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: _processing ? null : () => Navigator.pop(context, false),
            child:
                const Text('Annuler', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: accent,
              foregroundColor: Colors.white,
            ),
            onPressed: _canConfirm ? _confirm : null,
            child: _processing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Text('Confirmer',
                    style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
