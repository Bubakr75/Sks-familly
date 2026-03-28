import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/family_provider.dart';
import '../providers/pin_provider.dart';
import '../widgets/animated_background.dart';
import '../widgets/tv_focus_wrapper.dart';
import 'home_screen.dart';
import 'child_dashboard_screen.dart';
import 'pin_verification_screen.dart';

// ═══════════════════════════════════════════════════════════
//  PARTICULES CONVERGENTES — effet de lumière au lancement
// ═══════════════════════════════════════════════════════════
class _Particle {
  double x, y, size, speed, angle;
  _Particle({required this.x, required this.y, required this.size, required this.speed, required this.angle});
}

class _ConvergingParticles extends StatefulWidget {
  const _ConvergingParticles();
  @override
  State<_ConvergingParticles> createState() => _ConvergingParticlesState();
}

class _ConvergingParticlesState extends State<_ConvergingParticles> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  final List<_Particle> _particles = [];
  final _rng = Random();

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(seconds: 6))..repeat();
    for (int i = 0; i < 40; i++) {
      _particles.add(_Particle(
        x: _rng.nextDouble(),
        y: _rng.nextDouble(),
        size: 1.5 + _rng.nextDouble() * 2.5,
        speed: 0.002 + _rng.nextDouble() * 0.004,
        angle: _rng.nextDouble() * 2 * pi,
      ));
    }
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
        return CustomPaint(
          size: Size.infinite,
          painter: _ParticlePainter(_particles, _ctrl.value),
        );
      },
    );
  }
}

class _ParticlePainter extends CustomPainter {
  final List<_Particle> particles;
  final double t;
  _ParticlePainter(this.particles, this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height * 0.32; // converge vers le logo
    for (final p in particles) {
      final progress = (t + p.angle / (2 * pi)) % 1.0;
      final ease = Curves.easeInOut.transform(progress);
      final dx = p.x * size.width + (cx - p.x * size.width) * ease * 0.6;
      final dy = p.y * size.height + (cy - p.y * size.height) * ease * 0.6;
      final opacity = (0.3 + 0.7 * (1 - ease)).clamp(0.0, 1.0);
      final paint = Paint()
        ..color = Color.lerp(Colors.cyanAccent, Colors.purpleAccent, p.angle / (2 * pi))!.withOpacity(opacity)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, p.size);
      canvas.drawCircle(Offset(dx, dy), p.size, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _ParticlePainter old) => true;
}

// ═══════════════════════════════════════════════════════════
//  LOGO LUMINEUX — halo pulsant autour du logo
// ═══════════════════════════════════════════════════════════
class _GlowingLogo extends StatelessWidget {
  final Animation<double> pulse;
  final Animation<double> glow;
  const _GlowingLogo({required this.pulse, required this.glow});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([pulse, glow]),
      builder: (context, child) {
        return Container(
          width: 110,
          height: 110,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: [
                Colors.cyanAccent.withOpacity(0.3),
                Colors.purpleAccent.withOpacity(0.3),
              ],
            ),
            boxShadow: [
              BoxShadow(color: Colors.cyanAccent.withOpacity(0.15 + 0.15 * glow.value), blurRadius: 30 + 20 * glow.value, spreadRadius: 5 * glow.value),
              BoxShadow(color: Colors.purpleAccent.withOpacity(0.1 + 0.1 * glow.value), blurRadius: 40 + 20 * glow.value, spreadRadius: 3 * glow.value),
            ],
          ),
          child: Transform.scale(
            scale: pulse.value,
            child: const Icon(Icons.family_restroom, size: 52, color: Colors.white),
          ),
        );
      },
    );
  }
}

// ═══════════════════════════════════════════════════════════
//  WELCOME SCREEN
// ═══════════════════════════════════════════════════════════
class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});
  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> with TickerProviderStateMixin {
  late AnimationController _fadeCtrl;
  late Animation<double> _fadeAnim;

  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;

  late AnimationController _glowCtrl;
  late Animation<double> _glowAnim;

  late AnimationController _slideCtrl;
  late Animation<Offset> _parentSlide;
  late Animation<Offset> _childSlide;
  late Animation<double> _buttonFade;

  @override
  void initState() {
    super.initState();

    // Fade in global
    _fadeCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1000))..forward();
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeIn);

    // Pulse du logo
    _pulseCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.95, end: 1.05).animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));

    // Glow du logo
    _glowCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 3))..repeat(reverse: true);
    _glowAnim = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(parent: _glowCtrl, curve: Curves.easeInOut));

    // Boutons qui glissent du bas
    _slideCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200));
    _parentSlide = Tween<Offset>(begin: const Offset(0, 1.5), end: Offset.zero)
        .animate(CurvedAnimation(parent: _slideCtrl, curve: const Interval(0.3, 0.7, curve: Curves.easeOutCubic)));
    _childSlide = Tween<Offset>(begin: const Offset(0, 1.5), end: Offset.zero)
        .animate(CurvedAnimation(parent: _slideCtrl, curve: const Interval(0.5, 0.9, curve: Curves.easeOutCubic)));
    _buttonFade = Tween<double>(begin: 0.0, end: 1.0)
        .animate(CurvedAnimation(parent: _slideCtrl, curve: const Interval(0.3, 0.8, curve: Curves.easeIn)));

    // Lancer les boutons après le fade du logo
    Future.delayed(const Duration(milliseconds: 600), () {
      if (mounted) _slideCtrl.forward();
    });
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    _pulseCtrl.dispose();
    _glowCtrl.dispose();
    _slideCtrl.dispose();
    super.dispose();
  }

  // ─── Navigation identique à l'original ─────────────────
  void _enterParentMode() async {
    final pinProvider = context.read<PinProvider>();
    if (pinProvider.isPinSet) {
      final result = await Navigator.push<bool>(context, MaterialPageRoute(builder: (_) => PinVerificationScreen()));
      if (result == true && mounted) _showParentProfilePicker();
    } else {
      pinProvider.unlockParentMode();
      if (mounted) _showParentProfilePicker();
    }
  }

  void _showParentProfilePicker() {
    final familyProvider = context.read<FamilyProvider>();
    final currentName = familyProvider.currentParentName;
    final profiles = [
      {'name': 'Papa', 'icon': Icons.face, 'color': Colors.cyanAccent},
      {'name': 'Maman', 'icon': Icons.face_3, 'color': Colors.pinkAccent},
    ];

    showModalBottomSheet(
      context: context, isDismissible: false, enableDrag: false, backgroundColor: Colors.transparent, isScrollControlled: true,
      builder: (ctx) => Container(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
        decoration: BoxDecoration(color: Colors.grey[900]?.withOpacity(0.97), borderRadius: const BorderRadius.vertical(top: Radius.circular(28))),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 20),
          const Icon(Icons.person_pin, color: Colors.cyanAccent, size: 48),
          const SizedBox(height: 12),
          const Text('Qui êtes-vous ?', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Text('Vos actions seront signées avec ce profil', style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 13)),
          const SizedBox(height: 24),
          Row(children: profiles.map((profile) {
            final name = profile['name'] as String;
            final icon = profile['icon'] as IconData;
            final color = profile['color'] as Color;
            final isSelected = currentName == name;
            return Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 6), child: TvFocusWrapper(
              autofocus: name == 'Papa',
              onTap: () { familyProvider.setCurrentParent(name); Navigator.pop(ctx); _goToHomeScreen(); },
              child: GestureDetector(
                onTap: () { familyProvider.setCurrentParent(name); Navigator.pop(ctx); _goToHomeScreen(); },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  decoration: BoxDecoration(
                    color: isSelected ? color.withOpacity(0.15) : Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: isSelected ? color.withOpacity(0.6) : Colors.white12, width: isSelected ? 2 : 1),
                  ),
                  child: Column(children: [
                    Icon(icon, color: color, size: 40),
                    const SizedBox(height: 10),
                    Text(name, style: TextStyle(color: color, fontSize: 17, fontWeight: FontWeight.bold)),
                  ]),
                ),
              ),
            )));
          }).toList()),
          const SizedBox(height: 16),
          TvFocusWrapper(
            onTap: () => _showCustomParentName(ctx, familyProvider),
            child: GestureDetector(
              onTap: () => _showCustomParentName(ctx, familyProvider),
              child: Container(
                width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white12)),
                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Icons.edit, color: Colors.white.withOpacity(0.6), size: 20),
                  const SizedBox(width: 10),
                  Text('Autre profil...', style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 15, fontWeight: FontWeight.w500)),
                ]),
              ),
            ),
          ),
        ]),
      ),
    );
  }

  void _showCustomParentName(BuildContext bottomSheetCtx, FamilyProvider provider) {
    final controller = TextEditingController();
    showDialog(
      context: bottomSheetCtx,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: Colors.grey[900],
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Profil personnalisé', style: TextStyle(color: Colors.white)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('Entrez votre nom ou surnom', style: TextStyle(color: Colors.white70, fontSize: 14)),
          const SizedBox(height: 16),
          TextField(
            controller: controller, autofocus: true,
            style: const TextStyle(color: Colors.white, fontSize: 18),
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(
              hintText: 'Ex: Tonton, Tata, Nounou...', hintStyle: const TextStyle(color: Colors.white24),
              filled: true, fillColor: Colors.white.withOpacity(0.08),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Colors.cyanAccent)),
            ),
            onSubmitted: (val) {
              if (val.trim().isNotEmpty) { provider.setCurrentParent(val.trim()); Navigator.pop(dialogCtx); Navigator.pop(bottomSheetCtx); _goToHomeScreen(); }
            },
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogCtx), child: const Text('Annuler', style: TextStyle(color: Colors.white54))),
          TvFocusWrapper(
            onTap: () { if (controller.text.trim().isNotEmpty) { provider.setCurrentParent(controller.text.trim()); Navigator.pop(dialogCtx); Navigator.pop(bottomSheetCtx); _goToHomeScreen(); } },
            child: ElevatedButton(
              onPressed: () { if (controller.text.trim().isNotEmpty) { provider.setCurrentParent(controller.text.trim()); Navigator.pop(dialogCtx); Navigator.pop(bottomSheetCtx); _goToHomeScreen(); } },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.cyanAccent.shade700, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              child: const Text('Valider'),
            ),
          ),
        ],
      ),
    );
  }

  void _goToHomeScreen() {
    if (mounted) Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const HomeScreen()));
  }

  void _enterChildMode() {
    final provider = context.read<FamilyProvider>();
    final children = provider.children;
    if (children.isEmpty) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Aucun enfant enregistré. Passez en mode parent d\'abord.'), backgroundColor: Colors.orangeAccent)); return; }
    if (children.length == 1) { Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => ChildDashboardScreen(childId: children.first.id))); return; }
    _showChildPicker();
  }

  void _showChildPicker() {
    final provider = context.read<FamilyProvider>();
    final children = provider.children;
    showModalBottomSheet(
      context: context, backgroundColor: Colors.transparent, isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.5, minChildSize: 0.3, maxChildSize: 0.8,
        builder: (context, scrollController) => Container(
          decoration: BoxDecoration(color: Colors.grey[900]?.withOpacity(0.95), borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
          child: Column(children: [
            const SizedBox(height: 12),
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 16),
            const Text('Choisir un enfant', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Expanded(child: ListView.builder(
              controller: scrollController, itemCount: children.length, padding: const EdgeInsets.symmetric(horizontal: 16),
              itemBuilder: (context, index) {
                final child = children[index];
                return Padding(padding: const EdgeInsets.only(bottom: 8), child: TvFocusWrapper(
                  autofocus: index == 0,
                  onTap: () { Navigator.pop(context); Navigator.pushReplacement(this.context, MaterialPageRoute(builder: (_) => ChildDashboardScreen(childId: child.id))); },
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: Colors.white.withOpacity(0.06), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white12)),
                    child: Row(children: [
                      CircleAvatar(
                        radius: 24, backgroundColor: Colors.cyanAccent.withOpacity(0.3),
                        backgroundImage: child.hasPhoto ? MemoryImage(base64Decode(child.photoBase64!)) : null,
                        child: !child.hasPhoto ? Text(child.avatar.isNotEmpty ? child.avatar : (child.name.isNotEmpty ? child.name[0].toUpperCase() : '?'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20)) : null,
                      ),
                      const SizedBox(width: 16),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(child.name, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 4),
                        Text('${child.levelTitle} • ${child.points} pts', style: const TextStyle(color: Colors.white54, fontSize: 13)),
                      ])),
                      const Icon(Icons.chevron_right, color: Colors.white38),
                    ]),
                  ),
                ));
              },
            )),
          ]),
        ),
      ),
    );
  }

  // ─── BUILD ──────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return AnimatedBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Stack(
          children: [
            // Particules convergentes
            const _ConvergingParticles(),
            // Contenu principal
            SafeArea(
              child: FadeTransition(
                opacity: _fadeAnim,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Spacer(flex: 2),
                      // Logo lumineux
                      _GlowingLogo(pulse: _pulseAnim, glow: _glowAnim),
                      const SizedBox(height: 28),
                      // Titre avec shimmer-like glow
                      ShaderMask(
                        shaderCallback: (bounds) => LinearGradient(
                          colors: [Colors.white, Colors.cyanAccent.withOpacity(0.8), Colors.white],
                          stops: const [0.0, 0.5, 1.0],
                        ).createShader(bounds),
                        child: const Text('SKS Family', style: TextStyle(color: Colors.white, fontSize: 34, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
                      ),
                      const SizedBox(height: 8),
                      Text('Gestion familiale intelligente', style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 16)),
                      const Spacer(flex: 2),
                      // Bouton Parent — glisse du bas
                      SlideTransition(
                        position: _parentSlide,
                        child: FadeTransition(
                          opacity: _buttonFade,
                          child: TvFocusWrapper(
                            autofocus: true,
                            onTap: _enterParentMode,
                            child: SizedBox(
                              width: double.infinity, height: 56,
                              child: ElevatedButton.icon(
                                onPressed: _enterParentMode,
                                icon: const Icon(Icons.admin_panel_settings, size: 24),
                                label: const Text('Mode Parent', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                                style: ElevatedButton.styleFrom(backgroundColor: Colors.cyanAccent.shade700, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), elevation: 6),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Bouton Enfant — glisse du bas (décalé)
                      SlideTransition(
                        position: _childSlide,
                        child: FadeTransition(
                          opacity: _buttonFade,
                          child: TvFocusWrapper(
                            onTap: _enterChildMode,
                            child: SizedBox(
                              width: double.infinity, height: 56,
                              child: OutlinedButton.icon(
                                onPressed: _enterChildMode,
                                icon: const Icon(Icons.child_care, size: 24),
                                label: const Text('Mode Enfant', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                                style: OutlinedButton.styleFrom(foregroundColor: Colors.purpleAccent, side: const BorderSide(color: Colors.purpleAccent, width: 2), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const Spacer(),
                      Text('v4.8.0', style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 12)),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
