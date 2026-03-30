import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:flutter/foundation.dart';
import 'dart:math' as math;

import '../providers/family_provider.dart';
import '../providers/pin_provider.dart';
import '../widgets/animated_background.dart';
import '../widgets/tv_focus_wrapper.dart';
import '../widgets/animated_page_transition.dart';
import 'home_screen.dart';
import 'child_dashboard_screen.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});
  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen>
    with TickerProviderStateMixin {
  late AnimationController _logoController;
  late AnimationController _pulseController;
  late AnimationController _buttonController;
  late AnimationController _particleController;

  late Animation<double> _logoFade;
  late Animation<double> _logoScale;
  late Animation<double> _pulseAnim;
  late Animation<double> _btn1Slide;
  late Animation<double> _btn2Slide;

  final List<_WelcomeParticle> _particles = [];
  final _rng = math.Random();

  @override
  void initState() {
    super.initState();

    _logoController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _logoFade = CurvedAnimation(
      parent: _logoController,
      curve: const Interval(0.0, 0.5, curve: Curves.easeIn),
    );
    _logoScale = CurvedAnimation(
      parent: _logoController,
      curve: const Interval(0.1, 0.7, curve: Curves.elasticOut),
    );

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _buttonController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _btn1Slide = CurvedAnimation(
      parent: _buttonController,
      curve: const Interval(0.0, 0.6, curve: Curves.easeOutBack),
    );
    _btn2Slide = CurvedAnimation(
      parent: _buttonController,
      curve: const Interval(0.2, 0.8, curve: Curves.easeOutBack),
    );

    _particleController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat();
    for (int i = 0; i < 40; i++) {
      _particles.add(_WelcomeParticle(_rng));
    }

    _logoController.forward();
    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted) _buttonController.forward();
    });
  }

  @override
  void dispose() {
    _logoController.dispose();
    _pulseController.dispose();
    _buttonController.dispose();
    _particleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Stack(
          children: [
            AnimatedBuilder(
              animation: _particleController,
              builder: (context, _) {
                return CustomPaint(
                  size: MediaQuery.of(context).size,
                  painter: _WelcomeParticlePainter(
                    particles: _particles,
                    time: _particleController.value,
                  ),
                );
              },
            ),
            SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(height: 40),
                      AnimatedBuilder(
                        animation: Listenable.merge([_logoScale, _pulseAnim]),
                        builder: (context, child) {
                          return Transform.scale(
                            scale: _logoScale.value.clamp(0.0, 1.0),
                            child: Opacity(
                              opacity: _logoFade.value,
                              child: Container(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.cyan.withOpacity(0.3 * _pulseAnim.value),
                                      blurRadius: 40,
                                      spreadRadius: 10,
                                    ),
                                    BoxShadow(
                                      color: Colors.purple.withOpacity(0.2 * _pulseAnim.value),
                                      blurRadius: 60,
                                      spreadRadius: 20,
                                    ),
                                  ],
                                ),
                                child: const Text('👨‍👩‍👧‍👦', style: TextStyle(fontSize: 80)),
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 24),
                      FadeTransition(
                        opacity: _logoFade,
                        child: ShaderMask(
                          shaderCallback: (bounds) => const LinearGradient(
                            colors: [Colors.cyan, Colors.white, Colors.purple, Colors.cyan],
                          ).createShader(bounds),
                          child: const Text(
                            'Family Points',
                            style: TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      FadeTransition(
                        opacity: _logoFade,
                        child: Text('v4.9.0',
                            style: TextStyle(
                                color: Colors.white.withOpacity(0.4),
                                fontSize: 13)),
                      ),
                      const SizedBox(height: 60),
                      AnimatedBuilder(
                        animation: _btn1Slide,
                        builder: (context, child) {
                          return Transform.translate(
                            offset: Offset(0, 50 * (1 - _btn1Slide.value)),
                            child: Opacity(opacity: _btn1Slide.value, child: child),
                          );
                        },
                        child: TvFocusWrapper(
                          autofocus: true,
                          onTap: () => _handleParentMode(),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 18),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(colors: [Color(0xFF00BCD4), Color(0xFF0097A7)]),
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(color: Colors.cyan.withOpacity(0.4), blurRadius: 16, offset: const Offset(0, 4)),
                              ],
                            ),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.admin_panel_settings, color: Colors.white, size: 24),
                                SizedBox(width: 10),
                                Text('Mode Parent',
                                    style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      AnimatedBuilder(
                        animation: _btn2Slide,
                        builder: (context, child) {
                          return Transform.translate(
                            offset: Offset(0, 50 * (1 - _btn2Slide.value)),
                            child: Opacity(opacity: _btn2Slide.value, child: child),
                          );
                        },
                        child: TvFocusWrapper(
                          onTap: () => _handleChildMode(),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 18),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(colors: [Colors.purple.shade400, Colors.purple.shade700]),
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(color: Colors.purple.withOpacity(0.4), blurRadius: 16, offset: const Offset(0, 4)),
                              ],
                            ),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.child_care, color: Colors.white, size: 24),
                                SizedBox(width: 10),
                                Text('Mode Enfant',
                                    style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                        ),
                      ),
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

  void _handleParentMode() {
    final pin = Provider.of<PinProvider>(context, listen: false);
    if (pin.isPinSet) {
      _showPinDialog(() => _showParentPicker());
    } else {
      _showParentPicker();
    }
  }

  void _showPinDialog(VoidCallback onSuccess) {
    final controller = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogContext) {
        final pinProvider = Provider.of<PinProvider>(dialogContext, listen: false);
        
        return AlertDialog(
          backgroundColor: const Color(0xFF1A1A2E),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('🔒 PIN Parental', style: TextStyle(color: Colors.white)),
          content: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            maxLength: 4,
            obscureText: true,
            autofocus: true,
            style: const TextStyle(color: Colors.white, fontSize: 28, letterSpacing: 10),
            textAlign: TextAlign.center,
            decoration: InputDecoration(
              counterText: '',
              hintText: '••••',
              hintStyle: const TextStyle(color: Colors.white24),
              enabledBorder: OutlineInputBorder(
                borderSide: BorderSide(color: Colors.cyan.withOpacity(0.3)),
                borderRadius: BorderRadius.circular(10),
              ),
              focusedBorder: OutlineInputBorder(
                borderSide: const BorderSide(color: Colors.cyan),
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Annuler', style: TextStyle(color: Colors.white54)),
            ),
            ElevatedButton(
              onPressed: () {
                if (pinProvider.verifyPin(controller.text)) {
                  Navigator.pop(dialogContext);
                  onSuccess();
                  debugPrint("✅ PIN accepté - Ouverture du sélecteur parent");
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('❌ PIN incorrect'), backgroundColor: Colors.red),
                  );
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.cyan),
              child: const Text('Valider'),
            ),
          ],
        );
      },
    );
  }

  // ==================== TES AUTRES MÉTHODES (à remettre ci-dessous) ====================
  // Colle ici toutes tes autres méthodes (_showParentPicker, _showCustomParentDialog, _navigateToHome, _handleChildMode, etc.)
  // Elles étaient dans ton ancien fichier.
}

class _WelcomeParticle {
  final math.Random rng;
  late double x, y, speed, size;

  _WelcomeParticle(this.rng) {
    x = rng.nextDouble() * 400;
    y = rng.nextDouble() * 800;
    speed = rng.nextDouble() * 0.5 + 0.2;
    size = rng.nextDouble() * 3 + 1;
  }
}

class _WelcomeParticlePainter extends CustomPainter {
  final List<_WelcomeParticle> particles;
  final double time;

  _WelcomeParticlePainter({required this.particles, required this.time});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white.withOpacity(0.15);
    for (var p in particles) {
      final yPos = (p.y + time * p.speed * 50) % (size.height + 50);
      canvas.drawCircle(Offset(p.x, yPos), p.size, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
  void _handleChildMode() {
    final fp = Provider.of<FamilyProvider>(context, listen: false);
    final children = fp.children;
    if (children.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Aucun enfant enregistré. Connectez-vous en mode Parent.'),
            backgroundColor: Colors.orange),
      );
      return;
    }
    if (children.length == 1) {
      Navigator.pushReplacement(
        context,
        ZoomPageRoute(page: ChildDashboardScreen(childId: children.first.id)),
      );
      return;
    }
    // Le reste de la méthode (si tu l'avais avant, colle-le ici)
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Plusieurs enfants - fonctionnalité en cours')),
    );
  }

  void _showParentPicker() {
    final presets = ['Papa', 'Maman'];
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          decoration: const BoxDecoration(
            color: Color(0xFF1A1A2E),
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Qui es-tu ?', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              ...presets.map((name) => ListTile(
                    title: Text(name, style: const TextStyle(color: Colors.white)),
                    onTap: () {
                      Navigator.pop(ctx);
                      _navigateToHome(name);
                    },
                  )),
            ],
          ),
        );
      },
    );
  }
}
