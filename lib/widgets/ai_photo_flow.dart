// lib/widgets/ai_photo_flow.dart
//
// Flow Photo IA réutilisable — utilisé par le bouton central de navigation
// et partout où l'on veut analyser une photo avec Gemini.
//
// Étapes : photo → analyse IA → dialogue (type modifiable, enfant, points -/+) → confirmation.

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../providers/family_provider.dart';
import '../models/child_model.dart';
import '../services/gemini_service.dart';

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
    if (context.mounted) Navigator.pop(context); // Fermer le loader
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('⚠️ Analyse IA impossible — réessaie'),
        backgroundColor: Colors.redAccent,
      ));
    }
    return false;
  }
  if (context.mounted) Navigator.pop(context); // Fermer le loader
  if (!context.mounted) return false;

  bool isBonus = result['type'] == 'bonus';
  // 🔒 Valider et limiter le montant entre 1 et 999
  int points = (result['points'] as int).clamp(1, 999);
  final reason = result['reason'] as String;
  String? selectedChildId;
  bool processing = false;

  // 4. Dialogue de confirmation
  final dialogResult = await showDialog<bool>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setDialog) {
        final children = fp.children;
        final accent = isBonus ? Colors.green : Colors.redAccent;

        Future<void> confirm() async {
          if (selectedChildId == null || processing) return;
          setDialog(() => processing = true);
          HapticFeedback.mediumImpact();

          final capturedChildId = selectedChildId!;
          final capturedIsBonus = isBonus;
          final childName = fp.getChild(capturedChildId)?.name ?? '';
          // 🔒 Pour une pénalité : montant réel = min(demandé, solde)
          final child = fp.getChild(capturedChildId);
          // 🔒 Montant réel : bonus = demandé ; pénalité = min(demandé, solde) ou 0
          final actualPoints = capturedIsBonus
              ? points
              : (child == null || child.points <= 0 ? 0 : points.clamp(1, child.points));

          // 🔒 Pénalité avec solde nul : ne rien faire
          if (actualPoints == 0) {
            if (ctx.mounted) Navigator.pop(ctx);
            messenger.showSnackBar(const SnackBar(
              content: Text('Cet enfant n\'a aucun point à retirer'),
              backgroundColor: Colors.orange,
            ));
            return;
          }

          try {
            await fp.addPoints(
              capturedChildId,
              actualPoints,
              reason,
              category: capturedIsBonus ? 'Bonus' : 'Pénalité',
              isBonus: capturedIsBonus,
              proofPhotoBase64: base64Photo,
            );

            if (!ctx.mounted) return;
            Navigator.pop(ctx, true); // true = succès

            HapticFeedback.heavyImpact();
            messenger.showSnackBar(SnackBar(
              content: Text(
                  '${capturedIsBonus ? "✅ Bonus" : "⚠️ Pénalité"} pour $childName\n$actualPoints pts : "$reason"'),
              backgroundColor:
                  capturedIsBonus ? Colors.green.shade700 : Colors.red.shade700,
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 4),
            ));
          } catch (_) {
            if (!ctx.mounted) return;
            messenger.showSnackBar(const SnackBar(
              content: Text('Erreur lors de l\'application des points'),
              backgroundColor: Colors.redAccent,
            ));
          } finally {
            if (ctx.mounted) setDialog(() => processing = false);
          }
        }

        return AlertDialog(
          backgroundColor: const Color(0xFF0F2620),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(children: [
            Text('🤖', style: TextStyle(fontSize: 28)),
            SizedBox(width: 8),
            Text('Résultat IA',
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold)),
          ]),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Aperçu photo
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.memory(bytes,
                      height: 100, width: double.infinity, fit: BoxFit.cover),
                ),
                const SizedBox(height: 14),
                // Toggle Bonus/Pénalité
                Row(children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: processing
                          ? null
                          : () => setDialog(() => isBonus = true),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: isBonus
                              ? Colors.green.withValues(alpha: 0.2)
                              : Colors.white.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                              color: isBonus ? Colors.green : Colors.white12),
                        ),
                        child: Center(
                            child: Text('✅ Bonus',
                                style: TextStyle(
                                    color:
                                        isBonus ? Colors.green : Colors.white54,
                                    fontWeight: FontWeight.w600))),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: GestureDetector(
                      onTap: processing
                          ? null
                          : () => setDialog(() => isBonus = false),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: !isBonus
                              ? Colors.redAccent.withValues(alpha: 0.2)
                              : Colors.white.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                              color:
                                  !isBonus ? Colors.redAccent : Colors.white12),
                        ),
                        child: Center(
                            child: Text('⚠️ Pénalité',
                                style: TextStyle(
                                    color: !isBonus
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
                      onPressed: processing
                          ? null
                          : () => setDialog(() {
                                if (points > 1) points--;
                              }),
                      icon: const Icon(Icons.remove_circle_outline,
                          color: Colors.white54),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 8),
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text('${isBonus ? "+" : "-"}$points pts',
                          style: TextStyle(
                              color: accent,
                              fontSize: 20,
                              fontWeight: FontWeight.w800)),
                    ),
                    IconButton(
                      onPressed: processing
                          ? null
                          : () => setDialog(() {
                                if (points < 999) points++;
                              }),
                      icon: const Icon(Icons.add_circle_outline,
                          color: Colors.white54),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // Raison IA
                Text('"$reason"',
                    style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                        fontStyle: FontStyle.italic)),
                const SizedBox(height: 16),
                // Sélecteur enfant
                const Text('Pour quel enfant ?',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                ...children.map((c) {
                  final isSelected = selectedChildId == c.id;
                  return GestureDetector(
                    onTap: processing
                        ? null
                        : () => setDialog(() => selectedChildId = c.id),
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
              onPressed: processing ? null : () => Navigator.pop(ctx),
              child: const Text('Annuler',
                  style: TextStyle(color: Colors.white54)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: accent,
                foregroundColor: Colors.white,
              ),
              onPressed:
                  (selectedChildId != null && !processing) ? confirm : null,
              child: processing
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Text('Confirmer',
                      style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    ),
  );

  return dialogResult == true;
}
