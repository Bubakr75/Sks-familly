// lib/widgets/ai_floating_button.dart
//
// Bouton flottant IA 🤖 qui ouvre un menu radial avec toutes les fonctions IA :
// 📸 Photo, 🎤 Voix, ⌨️ Texte, 💬 Chat
// Accessible depuis n'importe où dans l'app.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:convert';
import '../providers/family_provider.dart';
import '../providers/pin_provider.dart';
import '../services/gemini_service.dart';
import '../models/child_model.dart';
import '../config/emerald_theme.dart';

class AIFloatingButton extends StatefulWidget {
  final VoidCallback? onOpenChat;

  const AIFloatingButton({super.key, this.onOpenChat});

  @override
  State<AIFloatingButton> createState() => _AIFloatingButtonState();
}

class _AIFloatingButtonState extends State<AIFloatingButton>
    with SingleTickerProviderStateMixin {
  bool _isOpen = false;
  late AnimationController _animController;
  late Animation<double> _anim;

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
    final isParent = context.watch<PinProvider>().isParentMode;

    // Ne pas afficher si pas d'enfants
    if (fp.children.isEmpty) return const SizedBox.shrink();

    return Stack(
      children: [
        // Overlay sombre quand le menu est ouvert
        if (_isOpen)
          GestureDetector(
            onTap: _toggle,
            child: Container(
              color: Colors.black.withValues(alpha: 0.5),
            ),
          ),

        // Bouton principal + menu radial
        Positioned(
          bottom: 16,
          right: 16,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // Options du menu
              if (_isOpen) ...[
                _MenuItem(
                  animation: _anim,
                  icon: Icons.photo_camera_rounded,
                  label: 'Photo IA',
                  color: Colors.deepPurpleAccent,
                  delay: 0,
                  onTap: () {
                    _toggle();
                    _photoIA(fp);
                  },
                ),
                const SizedBox(height: 8),
                _MenuItem(
                  animation: _anim,
                  icon: Icons.mic_rounded,
                  label: 'Voix IA',
                  color: Colors.redAccent,
                  delay: 0.1,
                  onTap: () {
                    _toggle();
                    _voiceIA(fp);
                  },
                ),
                const SizedBox(height: 8),
                _MenuItem(
                  animation: _anim,
                  icon: Icons.chat_rounded,
                  label: 'Chat IA',
                  color: Colors.cyanAccent,
                  delay: 0.2,
                  onTap: () {
                    _toggle();
                    widget.onOpenChat?.call();
                  },
                ),
                const SizedBox(height: 12),
              ],

              // Bouton principal
              GestureDetector(
                onTap: _toggle,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: _isOpen
                          ? [Colors.redAccent, Colors.orangeAccent]
                          : [Colors.deepPurpleAccent, Colors.purpleAccent],
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: (_isOpen ? Colors.redAccent : Colors.deepPurpleAccent).withValues(alpha: 0.4),
                        blurRadius: 16,
                        spreadRadius: 2,
                      ),
                    ],
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

  // 📸 Photo IA
  Future<void> _photoIA(FamilyProvider fp) async {
    final children = fp.children;
    final messenger = ScaffoldMessenger.of(context);

    // Prendre la photo
    final xfile = await ImagePicker().pickImage(
      source: ImageSource.camera,
      imageQuality: 70,
      maxWidth: 800,
    );
    if (xfile == null) return;
    final bytes = await xfile.readAsBytes();
    final base64Photo = base64Encode(bytes);

    if (!mounted) return;
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
            Text('🔍 Analyse en cours...', style: TextStyle(color: Colors.white)),
          ],
        ),
      ),
    );

    final result = await GeminiService.analyzePhoto(base64Photo);
    if (mounted) Navigator.pop(context);

    final isBonus = result['type'] == 'bonus';
    final points = result['points'] as int;
    final reason = result['reason'] as String;

    HapticFeedback.mediumImpact();

    // Dialogue avec sélecteur d'enfant
    String? selectedChildId;
    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialog) => AlertDialog(
          backgroundColor: const Color(0xFF0F2620),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('🤖 Résultat IA', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.memory(bytes, height: 100, width: double.infinity, fit: BoxFit.cover),
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: (isBonus ? Colors.green : Colors.redAccent).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: (isBonus ? Colors.green : Colors.redAccent).withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    children: [
                      Icon(isBonus ? Icons.check_circle_rounded : Icons.warning_rounded,
                          color: isBonus ? Colors.green : Colors.redAccent, size: 20),
                      const SizedBox(width: 6),
                      Text(isBonus ? 'BONUS' : 'PÉNALITÉ',
                        style: TextStyle(color: isBonus ? Colors.green : Colors.redAccent, fontSize: 14, fontWeight: FontWeight.w800)),
                      const Spacer(),
                      Text('${isBonus ? "+" : "-"}$points pts',
                        style: TextStyle(color: isBonus ? Colors.green : Colors.redAccent, fontSize: 20, fontWeight: FontWeight.w900)),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                Text('"$reason"', style: const TextStyle(color: Colors.white70, fontSize: 13, fontStyle: FontStyle.italic)),
                const SizedBox(height: 16),
                const Text('Pour quel enfant ?', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                ...children.map((c) {
                  final isSelected = selectedChildId == c.id;
                  return GestureDetector(
                    onTap: () => setDialog(() => selectedChildId = c.id),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? (isBonus ? Colors.green : Colors.redAccent).withValues(alpha: 0.15)
                            : Colors.white.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected ? (isBonus ? Colors.green : Colors.redAccent) : Colors.white12,
                          width: isSelected ? 1.5 : 1,
                        ),
                      ),
                      child: Row(children: [
                        Text(c.avatar.isNotEmpty ? c.avatar : '👤', style: const TextStyle(fontSize: 20)),
                        const SizedBox(width: 10),
                        Expanded(child: Text(c.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600))),
                        if (isSelected)
                          Icon(Icons.check_circle_rounded, color: isBonus ? Colors.green : Colors.redAccent, size: 20),
                      ]),
                    ),
                  );
                }).toList(),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler', style: TextStyle(color: Colors.white54))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: isBonus ? Colors.green : Colors.redAccent, foregroundColor: Colors.white),
              onPressed: selectedChildId == null ? null : () async {
                Navigator.pop(ctx);
                if (isBonus) {
                  await fp.addQuickBonus(selectedChildId!, reason);
                } else {
                  await fp.addQuickPenalty(selectedChildId!, reason);
                }
                if (context.mounted) {
                  HapticFeedback.heavyImpact();
                  messenger.showSnackBar(SnackBar(
                    content: Text('${isBonus ? "✅ Bonus" : "⚠️ Pénalité"} pour ${fp.getChild(selectedChildId!)?.name}\n$points pts : "$reason"'),
                    backgroundColor: isBonus ? Colors.green.shade700 : Colors.red.shade700,
                    behavior: SnackBarBehavior.floating,
                    duration: const Duration(seconds: 4),
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

  // 🎤 Voix IA
  Future<void> _voiceIA(FamilyProvider fp) async {
    // Rediriger vers l'écran Points
    Navigator.pushNamed(context, '/points');
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('🎤 Parle maintenant ! Tape ta phrase ou utilise le micro'),
        backgroundColor: Colors.deepPurpleAccent,
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 3),
      ),
    );
  }
}

class _MenuItem extends StatelessWidget {
  final Animation<double> animation;
  final IconData icon;
  final String label;
  final Color color;
  final double delay;
  final VoidCallback onTap;

  const _MenuItem({
    required this.animation,
    required this.icon,
    required this.label,
    required this.color,
    required this.delay,
    required this.onTap,
  });

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
                decoration: BoxDecoration(
                  color: EmeraldPalette.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: color.withValues(alpha: 0.4)),
                  boxShadow: [BoxShadow(color: color.withValues(alpha: 0.2), blurRadius: 8)],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, color: color, size: 22),
                    const SizedBox(width: 8),
                    Text(label, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
