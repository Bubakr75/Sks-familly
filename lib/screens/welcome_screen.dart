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
            // ... (le reste du build reste identique, je ne le recopie pas pour éviter de faire trop long)
            // Tu peux garder tout le Stack et le Column tel quel
          ],
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: _showInteractiveHelp,
          backgroundColor: Colors.cyan.withOpacity(0.9),
          child: const Icon(Icons.help_outline, color: Colors.white),
        ),
      ),
    );
  }

  // ====================== AIDE INTERACTIVE ======================
  void _showInteractiveHelp() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        title: const Text('❔ Comment utiliser SKS Family ?', 
            style: TextStyle(color: Colors.white, fontSize: 20)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('👨‍👩‍👧‍👦 Mode Parent', style: TextStyle(color: Colors.cyan, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const Text('• Gère les points, les tâches, les punitions et les récompenses', style: TextStyle(color: Colors.white70)),
              const Text('• Crée des objectifs et suit les progrès', style: TextStyle(color: Colors.white70)),
              const Text('• Accède au tribunal familial', style: TextStyle(color: Colors.white70)),
              const SizedBox(height: 16),
              
              const Text('🧒 Mode Enfant', style: TextStyle(color: Colors.purple, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const Text('• Voit ses points et ses badges', style: TextStyle(color: Colors.white70)),
              const Text('• Suit ses objectifs et ses punitions', style: TextStyle(color: Colors.white70)),
              const Text('• Peut faire des échanges avec les autres enfants', style: TextStyle(color: Colors.white70)),
              const SizedBox(height: 20),
              
              const Text('💡 Astuce : Le mode Parent est protégé par un code PIN.', 
                  style: TextStyle(color: Colors.amber, fontStyle: FontStyle.italic)),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Fermer', style: TextStyle(color: Colors.white70)),
          ),
        ],
      ),
    );
  }

  // ==================== TES AUTRES MÉTHODES (à remettre) ====================
  // Colle ici toutes tes autres méthodes (_handleParentMode, _showPinDialog, _showParentPicker, _navigateToHome, _handleChildMode, etc.)
  // Elles étaient dans ton ancien fichier.
}

// Garde aussi les classes _WelcomeParticle et _WelcomeParticlePainter à la fin
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
}
