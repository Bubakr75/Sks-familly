// lib/widgets/ai_floating_button.dart
//
// Bouton IA flottant 🤖 — version simple et fiable.
// 4 fonctions : Photo / Voix / Texte / Chat

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'dart:convert';
import '../providers/family_provider.dart';
import '../models/child_model.dart';
import '../services/gemini_service.dart';
import '../screens/add_points_screen.dart';
import '../screens/gemini_chat_screen.dart';

class AIFloatingButton extends StatelessWidget {
  const AIFloatingButton({super.key});

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton(
      heroTag: 'ai_fab',
      backgroundColor: Colors.deepPurpleAccent,
      child: const Icon(Icons.auto_awesome_rounded, color: Colors.white),
      onPressed: () => _showMenu(context),
    );
  }

  void _showMenu(BuildContext context) {
    HapticFeedback.lightImpact();
    final fp = context.read<FamilyProvider>();
    if (fp.children.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ajoute d\'abord un enfant !')),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0F2620),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 16), decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
            const Text('Assistant IA', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),

            // 📸 Photo IA
            _MenuTile(
              icon: Icons.photo_camera_rounded,
              label: 'Photo IA',
              subtitle: 'Prends une photo → l\'IA détecte bonus/pénalité',
              color: Colors.deepPurpleAccent,
              onTap: () { Navigator.pop(ctx); _photoIA(context, fp); },
            ),

            // 🎤 Parler
            _MenuTile(
              icon: Icons.mic_rounded,
              label: 'Parler à l\'IA',
              subtitle: 'Dis ce qui s\'est passé → l\'IA applique',
              color: Colors.redAccent,
              onTap: () { Navigator.pop(ctx); _voiceIA(context, fp); },
            ),

            // ⌨️ Texte
            _MenuTile(
              icon: Icons.keyboard_rounded,
              label: 'Saisie texte IA',
              subtitle: 'Tape une phrase → l\'IA remplit',
              color: Colors.cyanAccent,
              onTap: () { Navigator.pop(ctx); Navigator.push(context, MaterialPageRoute(builder: (_) => const AddPointsScreen())); },
            ),

            // 💬 Chat
            _MenuTile(
              icon: Icons.chat_rounded,
              label: 'Chat IA',
              subtitle: 'Pose tes questions à Gemini',
              color: Colors.amberAccent,
              onTap: () { Navigator.pop(ctx); Navigator.push(context, MaterialPageRoute(builder: (_) => const GeminiChatScreen())); },
            ),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════
  // 📸 PHOTO IA
  // ════════════════════════════════════════════════════════════
  Future<void> _photoIA(BuildContext context, FamilyProvider fp) async {
    final children = fp.children;
    final messenger = ScaffoldMessenger.of(context);

    final xfile = await ImagePicker().pickImage(source: ImageSource.camera, imageQuality: 70, maxWidth: 800);
    if (xfile == null) return;
    final bytes = await xfile.readAsBytes();
    final base64Photo = base64Encode(bytes);

    if (!context.mounted) return;
    showDialog(context: context, barrierDismissible: false,
      builder: (ctx) => const AlertDialog(backgroundColor: Color(0xFF0F2620),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          CircularProgressIndicator(color: Colors.deepPurpleAccent),
          SizedBox(height: 16),
          Text('🔍 Analyse en cours...', style: TextStyle(color: Colors.white)),
        ]),
      ),
    );

    final result = await GeminiService.analyzePhoto(base64Photo);
    if (context.mounted) Navigator.pop(context);
    if (!context.mounted) return;

    bool isBonus = result['type'] == 'bonus';
    int points = result['points'] as int;
    String reason = result['reason'] as String;
    String? selectedChildId;

    HapticFeedback.mediumImpact();

    if (!context.mounted) return;
    await showDialog(context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialog) => AlertDialog(
          backgroundColor: const Color(0xFF0F2620),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('🤖 Résultat IA', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.memory(bytes, height: 100, width: double.infinity, fit: BoxFit.cover)),
              const SizedBox(height: 14),
              Row(children: [
                Expanded(child: GestureDetector(onTap: () => setDialog(() => isBonus = true),
                  child: Container(padding: const EdgeInsets.symmetric(vertical: 8), decoration: BoxDecoration(color: isBonus ? Colors.green.withValues(alpha: 0.2) : Colors.white.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(10), border: Border.all(color: isBonus ? Colors.green : Colors.white12)),
                    child: Center(child: Text('✅ Bonus', style: TextStyle(color: isBonus ? Colors.green : Colors.white54, fontWeight: FontWeight.w600)))))),
                const SizedBox(width: 8),
                Expanded(child: GestureDetector(onTap: () => setDialog(() => isBonus = false),
                  child: Container(padding: const EdgeInsets.symmetric(vertical: 8), decoration: BoxDecoration(color: !isBonus ? Colors.redAccent.withValues(alpha: 0.2) : Colors.white.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(10), border: Border.all(color: !isBonus ? Colors.redAccent : Colors.white12)),
                    child: Center(child: Text('⚠️ Pénalité', style: TextStyle(color: !isBonus ? Colors.redAccent : Colors.white54, fontWeight: FontWeight.w600)))))),
              ]),
              const SizedBox(height: 12),
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                IconButton(onPressed: () => setDialog(() { if (points > 1) points--; }), icon: const Icon(Icons.remove_circle_outline, color: Colors.white54)),
                Container(padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8), decoration: BoxDecoration(color: (isBonus ? Colors.green : Colors.redAccent).withValues(alpha: 0.2), borderRadius: BorderRadius.circular(12)),
                  child: Text('${isBonus ? "+" : "-"}$points pts', style: TextStyle(color: isBonus ? Colors.green : Colors.redAccent, fontSize: 20, fontWeight: FontWeight.w800))),
                IconButton(onPressed: () => setDialog(() { if (points < 50) points++; }), icon: const Icon(Icons.add_circle_outline, color: Colors.white54)),
              ]),
              const SizedBox(height: 8),
              Text('"$reason"', style: const TextStyle(color: Colors.white70, fontSize: 13, fontStyle: FontStyle.italic)),
              const SizedBox(height: 16),
              const Text('Pour quel enfant ?', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              ...children.map((c) {
                final isSelected = selectedChildId == c.id;
                return GestureDetector(onTap: () => setDialog(() => selectedChildId = c.id),
                  child: Container(margin: const EdgeInsets.only(bottom: 6), padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(color: isSelected ? (isBonus ? Colors.green : Colors.redAccent).withValues(alpha: 0.15) : Colors.white.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(12), border: Border.all(color: isSelected ? (isBonus ? Colors.green : Colors.redAccent) : Colors.white12, width: isSelected ? 1.5 : 1)),
                    child: Row(children: [
                      Text(c.avatar.isNotEmpty ? c.avatar : '👤', style: const TextStyle(fontSize: 20)),
                      const SizedBox(width: 10),
                      Expanded(child: Text(c.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600))),
                      if (isSelected) Icon(Icons.check_circle_rounded, color: isBonus ? Colors.green : Colors.redAccent, size: 20),
                    ])));
              }),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler', style: TextStyle(color: Colors.white54))),
            ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: isBonus ? Colors.green : Colors.redAccent, foregroundColor: Colors.white),
              onPressed: selectedChildId == null ? null : () async {
                Navigator.pop(ctx);
                // 📸 On enregistre la photo dans l'historique (pour le bilan du soir)
                await fp.addPoints(
                  selectedChildId!,
                  points,
                  reason,
                  category: isBonus ? 'Bonus' : 'Pénalité',
                  isBonus: isBonus,
                  proofPhotoBase64: base64Photo,
                );
                if (context.mounted) {
                  HapticFeedback.heavyImpact();
                  messenger.showSnackBar(SnackBar(
                    content: Text('${isBonus ? "✅ Bonus" : "⚠️ Pénalité"} pour ${fp.getChild(selectedChildId!)?.name}\n$points pts : "$reason"'),
                    backgroundColor: isBonus ? Colors.green.shade700 : Colors.red.shade700, behavior: SnackBarBehavior.floating, duration: const Duration(seconds: 4)));
                }
              },
              child: const Text('Confirmer', style: TextStyle(fontWeight: FontWeight.bold))),
          ],
        ),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════
  // 🎤 VOIX IA
  // ════════════════════════════════════════════════════════════
  Future<void> _voiceIA(BuildContext context, FamilyProvider fp) async {
    final children = fp.children;
    final messenger = ScaffoldMessenger.of(context);
    final speech = SpeechToText();
    String heard = '';
    bool isListening = false;

    if (!context.mounted) return;
    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialog) {
          Future<void> toggle() async {
            if (isListening) {
              await speech.stop();
              setDialog(() => isListening = false);
              if (heard.isNotEmpty) {
                Navigator.pop(ctx);
                _processCommand(context, fp, children, heard, messenger);
              }
            } else {
              final ok = await speech.initialize(
                onStatus: (s) {
                  if (s == 'done' || s == 'notListening') {
                    setDialog(() => isListening = false);
                    if (heard.isNotEmpty) {
                      Navigator.pop(ctx);
                      _processCommand(context, fp, children, heard, messenger);
                    }
                  }
                },
                onError: (_) => setDialog(() => isListening = false),
              );
              if (ok) {
                setDialog(() => isListening = true);
                speech.listen(onResult: (r) { heard = r.recognizedWords; setDialog(() {}); }, localeId: 'fr_FR');
              }
            }
          }

          return AlertDialog(
            backgroundColor: const Color(0xFF0F2620),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Text('🎤 Assistant vocal', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            content: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(isListening ? Icons.graphic_eq_rounded : Icons.mic_none_rounded, color: isListening ? Colors.redAccent : Colors.white54, size: 56),
              const SizedBox(height: 12),
              Text(isListening ? 'Je t\'écoute...' : 'Clique pour parler', style: TextStyle(color: isListening ? Colors.redAccent : Colors.white54, fontSize: 14)),
              if (heard.isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(10)),
                  child: Text('"$heard"', style: const TextStyle(color: Colors.white, fontSize: 14))),
              ],
            ]),
            actions: [
              TextButton(onPressed: () { speech.stop(); Navigator.pop(ctx); }, child: const Text('Fermer', style: TextStyle(color: Colors.white54))),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: isListening ? Colors.redAccent : Colors.deepPurpleAccent, foregroundColor: Colors.white),
                icon: Icon(isListening ? Icons.stop_rounded : Icons.mic_rounded),
                label: Text(isListening ? 'Arrêter' : 'Parler'),
                onPressed: toggle,
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _processCommand(BuildContext context, FamilyProvider fp, List<ChildModel> children, String text, ScaffoldMessengerState messenger) async {
    showDialog(context: context, barrierDismissible: false,
      builder: (ctx) => const AlertDialog(backgroundColor: Color(0xFF0F2620),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          CircularProgressIndicator(color: Colors.deepPurpleAccent),
          SizedBox(height: 16),
          Text('🤖 Analyse...', style: TextStyle(color: Colors.white)),
        ]),
      ),
    );

    final result = await GeminiService.parseNaturalLanguage(text, childNames: children.map((c) => c.name).toList());
    if (context.mounted) Navigator.pop(context);
    if (!context.mounted) return;

    if (result['type'] == 'error') {
      messenger.showSnackBar(SnackBar(content: Text('❌ ${result['reason']}'), backgroundColor: Colors.redAccent));
      return;
    }

    final isBonus = result['type'] == 'bonus';
    final points = result['points'] as int;
    final reason = result['reason'] as String;
    final childName = result['childName'] as String? ?? '';

    ChildModel? target;
    if (childName.isNotEmpty) {
      target = children.where((c) => c.name.toLowerCase() == childName.toLowerCase()).firstOrNull;
    }

    if (target != null) {
      if (isBonus) { await fp.addQuickBonus(target.id, reason); }
      else { await fp.addQuickPenalty(target.id, reason); }
      HapticFeedback.heavyImpact();
      messenger.showSnackBar(SnackBar(
        content: Text('🤖 ${isBonus ? "✅ Bonus" : "⚠️ Pénalité"} pour ${target.name}\n$points pts : "$reason"'),
        backgroundColor: isBonus ? Colors.green.shade700 : Colors.red.shade700, behavior: SnackBarBehavior.floating, duration: const Duration(seconds: 4)));
    } else {
      // Sélecteur d'enfant
      String? selectedId;
      if (!context.mounted) return;
      await showDialog(context: context,
        builder: (ctx) => StatefulBuilder(
          builder: (ctx, setInner) => AlertDialog(
            backgroundColor: const Color(0xFF0F2620),
            title: const Text('Pour quel enfant ?', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            content: Column(mainAxisSize: MainAxisSize.min, children: [
              Text('${isBonus ? "Bonus" : "Pénalité"} de $points pts\n"$reason"', style: const TextStyle(color: Colors.white70), textAlign: TextAlign.center),
              const SizedBox(height: 12),
              ...children.map((c) {
                final isSelected = selectedId == c.id;
                return GestureDetector(onTap: () => setInner(() => selectedId = c.id),
                  child: Container(margin: const EdgeInsets.only(bottom: 6), padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(color: isSelected ? Colors.deepPurpleAccent.withValues(alpha: 0.2) : Colors.white.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(12), border: Border.all(color: isSelected ? Colors.deepPurpleAccent : Colors.white12)),
                    child: Row(children: [
                      Text(c.avatar.isNotEmpty ? c.avatar : '👤', style: const TextStyle(fontSize: 20)),
                      const SizedBox(width: 10),
                      Expanded(child: Text(c.name, style: const TextStyle(color: Colors.white))),
                      if (isSelected) const Icon(Icons.check_circle_rounded, color: Colors.deepPurpleAccent),
                    ])));
              }),
            ]),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler', style: TextStyle(color: Colors.white54))),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurpleAccent),
                onPressed: selectedId == null ? null : () async {
                  Navigator.pop(ctx);
                  if (isBonus) { await fp.addQuickBonus(selectedId!, reason); }
                  else { await fp.addQuickPenalty(selectedId!, reason); }
                  messenger.showSnackBar(SnackBar(content: Text('✅ Appliqué à ${fp.getChild(selectedId!)?.name}'), backgroundColor: Colors.deepPurpleAccent));
                },
                child: const Text('Confirmer')),
            ],
          ),
        ),
      );
    }
  }
}

// ─── Tuile du menu ───────────────────────────────────────────
class _MenuTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _MenuTile({required this.icon, required this.label, required this.subtitle, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(children: [
          Container(width: 44, height: 44, decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: color, size: 22)),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)),
            const SizedBox(height: 2),
            Text(subtitle, style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 11)),
          ]),
          ),
          Icon(Icons.chevron_right_rounded, color: color.withValues(alpha: 0.5), size: 22),
        ]),
      ),
    );
  }
}
