
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/family_provider.dart';
import '../providers/pin_provider.dart';
import '../widgets/animated_background.dart';
import '../widgets/glass_card.dart';
import '../widgets/tv_focus_wrapper.dart';
import '../models/child_model.dart';
import 'home_screen.dart';
import 'child_dashboard_screen.dart';
import 'dart:convert';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});
  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen>
    with TickerProviderStateMixin {
  late AnimationController _logoController;
  late AnimationController _pulseController;
  late AnimationController _buttonsController;
  late AnimationController _particleController;
  late AnimationController _cardController;

  late Animation<double> _logoScale;
  late Animation<double> _pulseScale;
  late Animation<double> _buttonsOpacity;
  late Animation<Offset> _buttonsSlide;
  late Animation<double> _cardOpacity;

  @override
  void initState() {
    super.initState();
    _logoController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1200));
    _logoScale =
        CurvedAnimation(parent: _logoController, curve: Curves.elasticOut);

    _pulseController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1500))
      ..repeat(reverse: true);
    _pulseScale = Tween<double>(begin: 1.0, end: 1.08).animate(
        CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut));

    _buttonsController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 800));
    _buttonsOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _buttonsController, curve: Curves.easeIn));
    _buttonsSlide =
        Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(
            CurvedAnimation(
                parent: _buttonsController, curve: Curves.easeOut));

    _particleController = AnimationController(
        vsync: this, duration: const Duration(seconds: 10))
      ..repeat();

    _cardController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _cardOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _cardController, curve: Curves.easeIn));

    _logoController.forward();
    Future.delayed(const Duration(milliseconds: 600), () {
      if (mounted) _cardController.forward();
    });
    Future.delayed(const Duration(milliseconds: 1000), () {
      if (mounted) _buttonsController.forward();
    });
  }

  @override
  void dispose() {
    _logoController.dispose();
    _pulseController.dispose();
    _buttonsController.dispose();
    _particleController.dispose();
    _cardController.dispose();
    super.dispose();
  }

  void _navigateToHome() {
    Navigator.of(context)
        .pushReplacement(MaterialPageRoute(builder: (_) => const HomeScreen()));
  }

  void _handleParentMode() async {
    final pinProvider = context.read<PinProvider>();
    if (!pinProvider.isPinSet) {
      _navigateToHome();
      return;
    }

    final pinController = TextEditingController();
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1a1a2e),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Code PIN Parent',
            style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: pinController,
          keyboardType: TextInputType.number,
          obscureText: true,
          maxLength: 6,
          style: const TextStyle(color: Colors.white, fontSize: 24),
          textAlign: TextAlign.center,
          decoration: InputDecoration(
            hintText: '   ',
            hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
            filled: true,
            fillColor: Colors.white.withOpacity(0.1),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none),
            counterStyle: const TextStyle(color: Colors.white38),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Annuler',
                  style: TextStyle(color: Colors.white54))),
          ElevatedButton(
            onPressed: () {
              if (pinProvider.verifyPin(pinController.text)) {
                Navigator.of(ctx).pop(true);
              } else {
                ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(
                    content: Text('Code PIN incorrect'),
                    backgroundColor: Colors.red));
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Valider'),
          ),
        ],
      ),
    );

    if (result == true && mounted) _navigateToHome();
  }

  void _handleChildMode() {
    final provider = context.read<FamilyProvider>();
    final List<ChildModel> children = provider.children;

    if (children.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Aucun enfant enregistré'),
          backgroundColor: Colors.orange));
      return;
    }

    if (children.length == 1) {
      Navigator.of(context).push(MaterialPageRoute(
          builder: (_) =>
              ChildDashboardScreen(childId: children.first.id)));
      return;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1a1a2e),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Qui es-tu ?',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            ...children.map((child) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: TvFocusWrapper(
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Colors.white24,
                        backgroundImage: child.photoBase64.isNotEmpty
                            ? MemoryImage(base64Decode(child.photoBase64))
                            : null,
                        child: child.photoBase64.isEmpty
                            ? Text(
                                child.name.isNotEmpty
                                    ? child.name.substring(0, 1).toUpperCase()
                                    : '?',
                                style: const TextStyle(color: Colors.white))
                            : null,
                      ),
                      title: Text(child.name,
                          style: const TextStyle(color: Colors.white)),
                      subtitle: Text('${child.points} points',
                          style: const TextStyle(color: Colors.white54)),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      tileColor: Colors.white.withOpacity(0.05),
                      onTap: () {
                        Navigator.of(ctx).pop();
                        Navigator.of(context).push(MaterialPageRoute(
                            builder: (_) =>
                                ChildDashboardScreen(childId: child.id)));
                      },
                    ),
                  ),
                )),
          ],
        ),
      ),
    );
  }

  void _showHelpDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1a1a2e),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(children: [
          Icon(Icons.help_outline, color: Colors.amber),
          SizedBox(width: 8),
          Text('Aide', style: TextStyle(color: Colors.white)),
        ]),
        content: const SingleChildScrollView(
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('👑 Mode Parent',
                    style: TextStyle(
                        color: Colors.amber, fontWeight: FontWeight.bold)),
                SizedBox(height: 4),
                Text(
                    'Gérer les enfants, ajouter/retirer des points, créer des punitions, gérer le tribunal et les échanges.',
                    style: TextStyle(color: Colors.white70)),
                SizedBox(height: 12),
                Text('🧒 Mode Enfant',
                    style: TextStyle(
                        color: Colors.cyan, fontWeight: FontWeight.bold)),
                SizedBox(height: 4),
                Text(
                    'Voir son tableau de bord, ses badges, son historique et le temps d\'écran.',
                    style: TextStyle(color: Colors.white70)),
                SizedBox(height: 12),
                Text('⭐ Points',
                    style: TextStyle(
                        color: Colors.green, fontWeight: FontWeight.bold)),
                SizedBox(height: 4),
                Text(
                    'Les bonus donnent des points, les malus en retirent. Accumulez pour débloquer des badges !',
                    style: TextStyle(color: Colors.white70)),
              ]),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Compris !',
                  style: TextStyle(color: Colors.amber))),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<FamilyProvider>();
    // ✅ CORRIGÉ : sortedChildren (pas childrenSorted)
    final List<ChildModel> children = provider.sortedChildren;

    final totalPoints =
        children.fold<int>(0, (sum, c) => sum + c.points);
    final totalBadges =
        children.fold<int>(0, (sum, c) => sum + c.badgeIds.length);
    final leader =
        children.isNotEmpty ? children.first.name : '-';

    return Scaffold(
      extendBodyBehindAppBar: true,
      body: AnimatedBackground(
        child: SafeArea(
          child: CustomPaint(
            painter: _WelcomeParticlePainter(animation: _particleController),
            child: SingleChildScrollView(
              padding:
                  const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Column(children: [
                const SizedBox(height: 20),

                // Logo
                ScaleTransition(
                  scale: _logoScale,
                  child: ScaleTransition(
                    scale: _pulseScale,
                    child: Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const LinearGradient(
                            colors: [Colors.amber, Colors.deepOrange]),
                        boxShadow: [
                          BoxShadow(
                              color: Colors.amber.withOpacity(0.4),
                              blurRadius: 30,
                              spreadRadius: 5)
                        ],
                      ),
                      child: const Icon(Icons.family_restroom,
                          size: 50, color: Colors.white),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Titre
                ScaleTransition(
                  scale: _logoScale,
                  child: const Text('SKS Family',
                      style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: Colors.white)),
                ),
                const SizedBox(height: 24),

                // Classement
                if (children.isNotEmpty)
                  FadeTransition(
                    opacity: _cardOpacity,
                    child: GlassCard(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('🏆 Classement',
                                style: TextStyle(
                                    color: Colors.amber,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold)),
                            const SizedBox(height: 12),
                            ...children.asMap().entries.map((entry) {
                              final idx = entry.key;
                              final child = entry.value;
                              return _ChildStatCard(
                                rank: idx + 1,
                                name: child.name,
                                points: child.points,
                                photoBase64: child.photoBase64.isNotEmpty
                                    ? child.photoBase64
                                    : null,
                                onTap: () => Navigator.of(context).push(
                                    MaterialPageRoute(
                                        builder: (_) => ChildDashboardScreen(
                                            childId: child.id))),
                              );
                            }),
                          ]),
                    ),
                  ),
                const SizedBox(height: 16),

                // Stats globales
                FadeTransition(
                  opacity: _cardOpacity,
                  child: Row(children: [
                    Expanded(
                        child: _StatBubble(
                            label: 'Points', value: '$totalPoints')),
                    const SizedBox(width: 8),
                    Expanded(
                        child: _StatBubble(
                            label: 'Badges', value: '$totalBadges')),
                    const SizedBox(width: 8),
                    Expanded(
                        child: _StatBubble(label: 'Leader', value: leader)),
                  ]),
                ),
                const SizedBox(height: 32),

                // Boutons
                SlideTransition(
                  position: _buttonsSlide,
                  child: FadeTransition(
                    opacity: _buttonsOpacity,
                    child: Column(children: [
                      TvFocusWrapper(
                        child: SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _handleParentMode,
                            icon: const Icon(Icons.admin_panel_settings,
                                size: 28),
                            label: const Text('Mode Parent',
                                style: TextStyle(fontSize: 18)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.amber,
                              foregroundColor: Colors.black87,
                              padding:
                                  const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16)),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TvFocusWrapper(
                        child: SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _handleChildMode,
                            icon: const Icon(Icons.child_care, size: 28),
                            label: const Text('Mode Enfant',
                                style: TextStyle(fontSize: 18)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.cyan,
                              foregroundColor: Colors.black87,
                              padding:
                                  const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16)),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TvFocusWrapper(
                        child: TextButton.icon(
                          onPressed: _showHelpDialog,
                          icon: const Icon(Icons.help_outline,
                              color: Colors.white54),
                          label: const Text('Aide',
                              style: TextStyle(color: Colors.white54)),
                        ),
                      ),
                    ]),
                  ),
                ),
                const SizedBox(height: 24),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Widgets helpers ──────────────────────────────────────────

class _ChildStatCard extends StatelessWidget {
  final int rank;
  final String name;
  final int points;
  final String? photoBase64;
  final VoidCallback? onTap;

  const _ChildStatCard({
    required this.rank,
    required this.name,
    required this.points,
    this.photoBase64,
    this.onTap,
  });

  Color get _rankColor {
    switch (rank) {
      case 1: return Colors.amber;
      case 2: return Colors.grey.shade400;
      case 3: return Colors.brown.shade300;
      default: return Colors.white54;
    }
  }

  String get _rankEmoji {
    switch (rank) {
      case 1: return '🥇';
      case 2: return '🥈';
      case 3: return '🥉';
      default: return '#$rank';
    }
  }

  @override
  Widget build(BuildContext context) {
    final level = points ~/ 50;
    final progress = (points % 50) / 50;

    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: _rankColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _rankColor.withOpacity(0.3)),
          ),
          child: Row(children: [
            Text(_rankEmoji, style: const TextStyle(fontSize: 24)),
            const SizedBox(width: 12),
            CircleAvatar(
              radius: 20,
              backgroundColor: Colors.white24,
              backgroundImage: photoBase64 != null
                  ? MemoryImage(base64Decode(photoBase64!))
                  : null,
              child: photoBase64 == null
                  ? Text(
                      name.isNotEmpty ? name.substring(0, 1).toUpperCase() : '?',
                      style: const TextStyle(color: Colors.white))
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(name,
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                LinearProgressIndicator(
                    value: progress,
                    backgroundColor: Colors.white12,
                    valueColor: AlwaysStoppedAnimation(_rankColor)),
              ]),
            ),
            const SizedBox(width: 12),
            Column(children: [
              Text('$points',
                  style: TextStyle(
                      color: _rankColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 18)),
              Text('Nv.$level',
                  style: const TextStyle(
                      color: Colors.white38, fontSize: 11)),
            ]),
          ]),
        ),
      ),
    );
  }
}

class _StatBubble extends StatelessWidget {
  final String label;
  final String value;
  const _StatBubble({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: Column(children: [
        Text(value,
            style: const TextStyle(
                color: Colors.amber,
                fontSize: 20,
                fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(label,
            style: const TextStyle(color: Colors.white54, fontSize: 12)),
      ]),
    );
  }
}

// ── Particules ───────────────────────────────────────────────

class _WelcomeParticle {
  double x, y, speed, size, opacity;
  _WelcomeParticle(
      {required this.x,
      required this.y,
      required this.speed,
      required this.size,
      required this.opacity});
}

class _WelcomeParticlePainter extends CustomPainter {
  final Animation<double> animation;
  final List<_WelcomeParticle> particles;

  _WelcomeParticlePainter({required this.animation})
      : particles = List.generate(30, (i) {
          final r = Random(i);
          return _WelcomeParticle(
              x: r.nextDouble(),
              y: r.nextDouble(),
              speed: 0.2 + r.nextDouble() * 0.5,
              size: 1 + r.nextDouble() * 3,
              opacity: 0.1 + r.nextDouble() * 0.4);
        }),
        super(repaint: animation);

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in particles) {
      final yPos = (p.y + animation.value * p.speed) % 1.0;
      canvas.drawCircle(
          Offset(p.x * size.width, yPos * size.height),
          p.size,
          Paint()
            ..color =
                Colors.white.withOpacity(p.opacity * (1.0 - yPos)));
    }
  }

  @override
  bool shouldRepaint(covariant _WelcomeParticlePainter old) => true;
}
