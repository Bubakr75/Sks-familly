// lib/widgets/ai_floating_button.dart
//
// Bouton flottant IA 🤖 avec :
// 📸 Photo IA (analyse + modification + choix enfant)
// 🎤 Conversation vocale (parle → Gemini répond → applique)
// ⌨️ Conversation texte (tape → Gemini répond → applique)

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
import '../config/emerald_theme.dart';

class AIFloatingButton extends StatefulWidget {
  const AIFloatingButton({super.key});

  @override
  State<AIFloatingButton> createState() => _AIFloatingButtonState();
}

class _AIFloatingButtonState extends State<AIFloatingButton>
    with SingleTickerProviderStateMixin {
  bool _isOpen = false;
  late AnimationController _animController;
  late Animation<double> _anim;
  final SpeechToText _speech = SpeechToText();
  bool _isListening = false;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _anim = CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic);
  }

  @override
  void dispose() {
    _animController.dispose();
    _speech.stop();
    super.dispose();
  }

  void _toggle() {
    setState(() => _isOpen = !_isOpen);
    if (_isOpen) {
      _animController.forward();
      HapticFeedback.lightImpact();
    } else {
      _animController.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    final fp = context.watch<FamilyProvider>();
    if (fp.children.isEmpty) return const SizedBox.shrink();

    return Stack(
      children: [
        if (_isOpen)
          GestureDetector(
            onTap: _toggle,
            child: Container(color: Colors.black.withValues(alpha: 0.5)),
          ),
        Positioned(
          bottom: 16,
          right: 16,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (_isOpen) ...[
                _MenuItem(animation: _anim, icon: Icons.photo_camera_rounded, label: 'Photo IA', color: Colors.deepPurpleAccent, delay: 0, onTap: () { _toggle(); _photoIA(fp); }),
                const SizedBox(height: 8),
                _MenuItem(animation: _anim, icon: Icons.mic_rounded, label: 'Parler à l\'IA', color: Colors.redAccent, delay: 0.1, onTap: () { _toggle(); _converserVocal(fp); }),
                const SizedBox(height: 8),
                _MenuItem(animation: _anim, icon: Icons.keyboard_rounded, label: 'Texte IA', color: Colors.cyanAccent, delay: 0.15, onTap: () { _toggle(); _converserTexte(fp); }),
                const SizedBox(height: 8),
                _MenuItem(animation: _anim, icon: Icons.chat_rounded, label: 'Chat IA', color: Colors.amberAccent, delay: 0.2, onTap: () { _toggle(); Navigator.push(context, MaterialPageRoute(builder: (_) => const GeminiChatScreen())); }),
                const SizedBox(height: 12),
              ],
              GestureDetector(
                onTap: _toggle,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 60, height: 60,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: _isOpen ? [Colors.redAccent, Colors.orangeAccent] : [Colors.deepPurpleAccent, Colors.purpleAccent]),
                    shape: BoxShape.circle,
                    boxShadow: [BoxShadow(color: (_isOpen ? Colors.redAccent : Colors.deepPurpleAccent).withValues(alpha: 0.4), blurRadius: 16, spreadRadius: 2)],
                  ),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: _isOpen
                        ? const Icon(Icons.close_rounded, color: Colors.white, size: 30, key: ValueKey('close'))
                        : const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 30, key: ValueKey('open')),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ════════════════════════════════════════════════════════════
  // 📸 PHOTO IA : analyse + modification + choix enfant
  // ════════════════════════════════════════════════════════════
  Future<void> _photoIA(FamilyProvider fp) async {
    final children = fp.children;
    final messenger = ScaffoldMessenger.of(context);

    final xfile = await ImagePicker().pickImage(source: ImageSource.camera, imageQuality: 70, maxWidth: 800);
    if (xfile == null) return;
    final bytes = await xfile.readAsBytes();
    final base64Photo = base64Encode(bytes);

    if (!mounted) return;
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
    if (mounted) Navigator.pop(context);
    if (!mounted) return;

    bool isBonus = result['type'] == 'bonus';
    int points = result['points'] as int;
    String reason = result['reason'] as String;
    String? selectedChildId;

    HapticFeedback.mediumImpact();

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

              // Toggle Bonus/Pénalité (modifiable)
              Row(children: [
                Expanded(child: GestureDetector(
                  onTap: () => setDialog(() => isBonus = true),
                  child: Container(padding: const EdgeInsets.symmetric(vertical: 8), decoration: BoxDecoration(color: isBonus ? Colors.green.withValues(alpha: 0.2) : Colors.white.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(10), border: Border.all(color: isBonus ? Colors.green : Colors.white12)),
                    child: Center(child: Text('✅ Bonus', style: TextStyle(color: isBonus ? Colors.green : Colors.white54, fontWeight: FontWeight.w600))),
                  ),
                )),
                const SizedBox(width: 8),
                Expanded(child: GestureDetector(
                  onTap: () => setDialog(() => isBonus = false),
                  child: Container(padding: const EdgeInsets.symmetric(vertical: 8), decoration: BoxDecoration(color: !isBonus ? Colors.redAccent.withValues(alpha: 0.2) : Colors.white.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(10), border: Border.all(color: !isBonus ? Colors.redAccent : Colors.white12)),
                    child: Center(child: Text('⚠️ Pénalité', style: TextStyle(color: !isBonus ? Colors.redAccent : Colors.white54, fontWeight: FontWeight.w600))),
                  ),
                )),
              ]),

              const SizedBox(height: 12),

              // Points modifiables
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
                return GestureDetector(
                  onTap: () => setDialog(() => selectedChildId = c.id),
                  child: Container(margin: const EdgeInsets.only(bottom: 6), padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(color: isSelected ? (isBonus ? Colors.green : Colors.redAccent).withValues(alpha: 0.15) : Colors.white.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(12), border: Border.all(color: isSelected ? (isBonus ? Colors.green : Colors.redAccent) : Colors.white12, width: isSelected ? 1.5 : 1)),
                    child: Row(children: [
                      Text(c.avatar.isNotEmpty ? c.avatar : '👤', style: const TextStyle(fontSize: 20)),
                      const SizedBox(width: 10),
                      Expanded(child: Text(c.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600))),
                      if (isSelected) Icon(Icons.check_circle_rounded, color: isBonus ? Colors.green : Colors.redAccent, size: 20),
                    ]),
                  ),
                );
              }).toList(),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler', style: TextStyle(color: Colors.white54))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: isBonus ? Colors.green : Colors.redAccent, foregroundColor: Colors.white),
              onPressed: selectedChildId == null ? null : () async {
                Navigator.pop(ctx);
                if (isBonus) { await fp.addQuickBonus(selectedChildId!, reason); }
                else { await fp.addQuickPenalty(selectedChildId!, reason); }
                if (context.mounted) {
                  HapticFeedback.heavyImpact();
                  messenger.showSnackBar(SnackBar(
                    content: Text('${isBonus ? "✅ Bonus" : "⚠️ Pénalité"} pour ${fp.getChild(selectedChildId!)?.name}\n$points pts : "$reason"'),
                    backgroundColor: isBonus ? Colors.green.shade700 : Colors.red.shade700,
                    behavior: SnackBarBehavior.floating, duration: const Duration(seconds: 4),
                  ));
                }
              },
              child: const Text('Confirmer', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════
  // 🎤 CONVERSATION VOCALE : parle → Gemini détecte → applique
  // ════════════════════════════════════════════════════════════
  Future<void> _converserVocal(FamilyProvider fp) async {
    final children = fp.children;
    final messenger = ScaffoldMessenger.of(context);
    String lastText = '';

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialog) {
          void startListening() async {
            final available = await _speech.initialize(
              onStatus: (status) {
                if (status == 'done' || status == 'notListening') {
                  setDialog(() => _isListening = false);
                  if (lastText.isNotEmpty) {
                    // Traiter la phrase
                    _processVoiceCommand(fp, children, lastText, messenger, setDialog);
                  }
                }
              },
              onError: (_) => setDialog(() => _isListening = false),
            );
            if (available) {
              setDialog(() => _isListening = true);
              _speech.listen(
                onResult: (result) {
                  lastText = result.recognizedWords;
                  setDialog(() {});
                },
                localeId: 'fr_FR',
              );
            }
          }

          return AlertDialog(
            backgroundColor: const Color(0xFF0F2620),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Row(children: [
              Icon(Icons.mic_rounded, color: Colors.redAccent),
              SizedBox(width: 8),
              Text('Assistant vocal IA', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ]),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Statut
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: _isListening ? Colors.redAccent.withValues(alpha: 0.15) : Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: _isListening ? Colors.redAccent : Colors.white12),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        _isListening ? Icons.graphic_eq_rounded : Icons.mic_none_rounded,
                        color: _isListening ? Colors.redAccent : Colors.white54,
                        size: 48,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _isListening ? 'Je t\'écoute...' : 'Clique pour parler',
                        style: TextStyle(color: _isListening ? Colors.redAccent : Colors.white54, fontSize: 14),
                      ),
                      if (lastText.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(10)),
                          child: Text('"$lastText"', style: const TextStyle(color: Colors.white, fontSize: 14, fontStyle: FontStyle.italic)),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                // Bouton micro
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isListening ? Colors.redAccent : Colors.deepPurpleAccent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    icon: Icon(_isListening ? Icons.stop_rounded : Icons.mic_rounded),
                    label: Text(_isListening ? 'Arrêter' : 'Parler'),
                    onPressed: () {
                      if (_isListening) {
                        _speech.stop();
                        setDialog(() => _isListening = false);
                        if (lastText.isNotEmpty) {
                          _processVoiceCommand(fp, children, lastText, messenger, setDialog);
                        }
                      } else {
                        startListening();
                      }
                    },
                  ),
                ),
                const SizedBox(height: 8),
                const Text('Ex: "Adam a rangé sa chambre" ou "Sara a menti"',
                  style: TextStyle(color: Colors.white38, fontSize: 11), textAlign: TextAlign.center),
              ],
            ),
            actions: [
              TextButton(onPressed: () { _speech.stop(); Navigator.pop(ctx); }, child: const Text('Fermer', style: TextStyle(color: Colors.white54))),
            ],
          );
        },
      ),
    );
  }

  Future<void> _processVoiceCommand(FamilyProvider fp, List<ChildModel> children, String text, ScaffoldMessengerState messenger, StateSetter setDialog) async {
    setDialog(() {});
    final result = await GeminiService.parseNaturalLanguage(text, childNames: children.map((c) => c.name).toList());

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

    // Si enfant détecté → appliquer direct
    if (target != null) {
      if (isBonus) { await fp.addQuickBonus(target.id, reason); }
      else { await fp.addQuickPenalty(target.id, reason); }
      HapticFeedback.heavyImpact();
      messenger.showSnackBar(SnackBar(
        content: Text('🤖 ${isBonus ? "✅ Bonus" : "⚠️ Pénalité"} pour ${target.name}\n$points pts : "$reason"'),
        backgroundColor: isBonus ? Colors.green.shade700 : Colors.red.shade700,
        behavior: SnackBarBehavior.floating, duration: const Duration(seconds: 4),
      ));
      if (mounted) Navigator.pop(context);
    } else {
      // Pas d'enfant détecté → proposer le choix
      String? selectedId;
      await showDialog(context: context,
        builder: (ctx) => StatefulBuilder(
          builder: (ctx, setInner) => AlertDialog(
            backgroundColor: const Color(0xFF0F2620),
            title: const Text('🤖 Pour quel enfant ?', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            content: Column(mainAxisSize: MainAxisSize.min, children: [
              Text('${isBonus ? "Bonus" : "Pénalité"} de $points pts\n"$reason"', style: const TextStyle(color: Colors.white70), textAlign: TextAlign.center),
              const SizedBox(height: 12),
              ...children.map((c) {
                final isSelected = selectedId == c.id;
                return GestureDetector(
                  onTap: () => setInner(() => selectedId = c.id),
                  child: Container(margin: const EdgeInsets.only(bottom: 6), padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(color: isSelected ? Colors.deepPurpleAccent.withValues(alpha: 0.2) : Colors.white.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(12), border: Border.all(color: isSelected ? Colors.deepPurpleAccent : Colors.white12)),
                    child: Row(children: [
                      Text(c.avatar.isNotEmpty ? c.avatar : '👤', style: const TextStyle(fontSize: 20)),
                      const SizedBox(width: 10),
                      Expanded(child: Text(c.name, style: const TextStyle(color: Colors.white))),
                      if (isSelected) const Icon(Icons.check_circle_rounded, color: Colors.deepPurpleAccent),
                    ]),
                  ),
                );
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
                child: const Text('Confirmer'),
              ),
            ],
          ),
        ),
      );
    }
  }

  // ════════════════════════════════════════════════════════════
  // ⌨️ CONVERSATION TEXTE : tape → Gemini détecte → applique
  // ════════════════════════════════════════════════════════════
  Future<void> _converserTexte(FamilyProvider fp) async {
    Navigator.push(context, MaterialPageRoute(builder: (_) => const AddPointsScreen()));
  }
}

class _MenuItem extends StatelessWidget {
  final Animation<double> animation;
  final IconData icon;
  final String label;
  final Color color;
  final double delay;
  final VoidCallback onTap;

  const _MenuItem({required this.animation, required this.icon, required this.label, required this.color, required this.delay, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        final value = ((animation.value - delay) / (1 - delay)).clamp(0.0, 1.0);
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 20 * (1 - value)),
            child: GestureDetector(
              onTap: onTap,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(color: EmeraldPalette.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: color.withValues(alpha: 0.4)), boxShadow: [BoxShadow(color: color.withValues(alpha: 0.2), blurRadius: 8)]),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(icon, color: color, size: 22),
                  const SizedBox(width: 8),
                  Text(label, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
                ]),
              ),
            ),
          ),
        );
      },
    );
  }
}
