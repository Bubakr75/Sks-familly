import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/child_model.dart';
import '../providers/family_provider.dart';
import '../providers/pin_provider.dart';
import '../widgets/animated_background.dart';
import '../widgets/tv_focus_wrapper.dart';
import 'home_screen.dart';

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
  late AnimationController _cardController;

  late Animation<double> _logoFade;
  late Animation<double> _logoScale;
  late Animation<double> _pulseAnim;
  late Animation<double> _btn1Slide;
  late Animation<double> _btn2Slide;
  late Animation<double> _cardFade;

  final List<_WelcomeParticle> _particles = [];
  final _rng = math.Random();

  @override
  void initState() {
    super.initState();

    _logoController = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 1500));
    _logoFade = CurvedAnimation(
        parent: _logoController,
        curve: const Interval(0.0, 0.5, curve: Curves.easeIn));
    _logoScale = CurvedAnimation(
        parent: _logoController,
        curve:
            const Interval(0.1, 0.7, curve: Curves.elasticOut));

    _pulseController = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 2000))
      ..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.4, end: 1.0).animate(
        CurvedAnimation(
            parent: _pulseController,
            curve: Curves.easeInOut));

    _buttonController = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 1200));
    _btn1Slide = CurvedAnimation(
        parent: _buttonController,
        curve:
            const Interval(0.0, 0.6, curve: Curves.easeOutBack));
    _btn2Slide = CurvedAnimation(
        parent: _buttonController,
        curve:
            const Interval(0.2, 0.8, curve: Curves.easeOutBack));

    _cardController = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 800));
    _cardFade =
        CurvedAnimation(parent: _cardController, curve: Curves.easeOut);

    _particleController = AnimationController(
        vsync: this, duration: const Duration(seconds: 10))
      ..repeat();

    for (int i = 0; i < 40; i++) {
      _particles.add(_WelcomeParticle(_rng));
    }

    _logoController.forward();
    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted) _buttonController.forward();
    });
    Future.delayed(const Duration(milliseconds: 1200), () {
      if (mounted) _cardController.forward();
    });
  }

  @override
  void dispose() {
    _logoController.dispose();
    _pulseController.dispose();
    _buttonController.dispose();
    _particleController.dispose();
    _cardController.dispose();
    super.dispose();
  }

  // ── Mode Parent ───────────────────────────────────────────────────────────
  void _handleParentMode() {
    final pin = context.read<PinProvider>();
    if (!pin.isPinSet) {
      _navigateToHome('Parent');
    } else {
      _showPinDialog();
    }
  }

  void _showPinDialog() {
    final pinCtrl = TextEditingController();
    bool obscure = true;
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          backgroundColor: const Color(0xFF0D1B2A),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24)),
          title: const Row(children: [
            Icon(Icons.lock_rounded, color: Colors.amber),
            SizedBox(width: 8),
            Text('Code Parental',
                style: TextStyle(color: Colors.white)),
          ]),
          content:
              Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('Entrez votre code PIN',
                style: TextStyle(color: Colors.white70)),
            const SizedBox(height: 16),
            TextField(
              controller: pinCtrl,
              obscureText: obscure,
              keyboardType: TextInputType.number,
              maxLength: 6,
              autofocus: true,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 24,
                  letterSpacing: 8,
                  color: Colors.white),
              decoration: InputDecoration(
                counterText: '',
                hintText: '• • • •',
                hintStyle: const TextStyle(
                    fontSize: 24,
                    letterSpacing: 8,
                    color: Colors.white30),
                suffixIcon: IconButton(
                  icon: Icon(
                      obscure
                          ? Icons.visibility_off_rounded
                          : Icons.visibility_rounded,
                      color: Colors.white54),
                  onPressed: () =>
                      setS(() => obscure = !obscure),
                ),
              ),
              onSubmitted: (_) =>
                  _validatePin(ctx, pinCtrl),
            ),
          ]),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text('Annuler',
                    style:
                        TextStyle(color: Colors.grey[400]))),
            FilledButton(
              onPressed: () => _validatePin(ctx, pinCtrl),
              child: const Text('Valider'),
            ),
          ],
        ),
      ),
    );
  }

  void _validatePin(
      BuildContext ctx, TextEditingController ctrl) {
    final pin = context.read<PinProvider>();
    if (pin.verifyPin(ctrl.text.trim())) {
      Navigator.pop(ctx);
      _showParentPicker();
    } else {
      ctrl.clear();
      HapticFeedback.heavyImpact();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Row(children: [
          Icon(Icons.error_rounded, color: Colors.white),
          SizedBox(width: 8),
          Text('Code PIN incorrect'),
        ]),
        backgroundColor: Colors.red.shade700,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 2),
      ));
    }
  }

  void _showParentPicker() {
    final parents = ['Maman', 'Papa', 'Parent'];
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0D1B2A),
      shape: const RoundedRectangleBorder(
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child:
            Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: Colors.grey[700],
                  borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 16),
          const Text('Qui êtes-vous ?',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          ...parents.map((name) => ListTile(
                leading: CircleAvatar(
                  backgroundColor:
                      const Color(0xFF00E5FF).withOpacity(0.15),
                  child: const Icon(Icons.person_rounded,
                      color: Color(0xFF00E5FF)),
                ),
                title: Text(name,
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600)),
                onTap: () {
                  Navigator.pop(ctx);
                  _navigateToHome(name);
                },
              )),
          const SizedBox(height: 8),
        ]),
      ),
    );
  }

  // ── CORRECTION ICI : HomeScreen() sans parentName ─────────────────────────
  void _navigateToHome(String parentName) {
    context.read<PinProvider>().unlockParentMode();
    context.read<FamilyProvider>().setCurrentParent(parentName);
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => const HomeScreen(),
        transitionsBuilder: (_, anim, __, child) =>
            FadeTransition(opacity: anim, child: child),
        transitionDuration: const Duration(milliseconds: 500),
      ),
    );
  }

  // ── Mode Enfant ───────────────────────────────────────────────────────────
  void _handleChildMode() {
    final fp = context.read<FamilyProvider>();
    if (fp.children.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content:
            Text('Aucun enfant enregistré pour l\'instant.'),
        behavior: SnackBarBehavior.floating,
      ));
      return;
    }
    if (fp.children.length == 1) {
      _navigateToHome(fp.children.first.name);
      return;
    }
    _showChildPicker(fp.children);
  }

  void _showChildPicker(List<ChildModel> children) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0D1B2A),
      shape: const RoundedRectangleBorder(
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child:
            Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: Colors.grey[700],
                  borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 16),
          const Text('Qui es-tu ?',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          ...children.map((child) => ListTile(
                leading: CircleAvatar(
                  backgroundColor:
                      const Color(0xFF7C4DFF).withOpacity(0.15),
                  child: child.hasPhoto
                      ? ClipOval(
                          child: Image.memory(
                            base64Decode(child.photoBase64),
                            width: 40,
                            height: 40,
                            fit: BoxFit.cover,
                          ),
                        )
                      : Text(
                          child.avatar.isEmpty
                              ? '🧒'
                              : child.avatar,
                          style: const TextStyle(fontSize: 22)),
                ),
                title: Text(child.name,
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600)),
                subtitle: Text(
                    '${child.points} pts · Nv.${child.currentLevelNumber}',
                    style: TextStyle(
                        color: Colors.grey[500], fontSize: 12)),
                onTap: () {
                  Navigator.pop(ctx);
                  _navigateToHome(child.name);
                },
              )),
          const SizedBox(height: 8),
        ]),
      ),
    );
  }

  // ── Aide ──────────────────────────────────────────────────────────────────
  void _showInteractiveHelp() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24)),
        title: const Text('❔ Comment utiliser SKS Family ?',
            style:
                TextStyle(color: Colors.white, fontSize: 18)),
        content: SingleChildScrollView(
          child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text('👨‍👩‍👧‍👦 Mode Parent',
                    style: TextStyle(
                        color: Colors.cyan,
                        fontWeight: FontWeight.bold)),
                SizedBox(height: 8),
                Text(
                    '• Gère les points, tâches, punitions et récompenses',
                    style: TextStyle(color: Colors.white70)),
                Text('• Crée des objectifs et suit les progrès',
                    style: TextStyle(color: Colors.white70)),
                Text('• Accède au tribunal familial',
                    style: TextStyle(color: Colors.white70)),
                SizedBox(height: 16),
                Text('🧒 Mode Enfant',
                    style: TextStyle(
                        color: Color(0xFF7C4DFF),
                        fontWeight: FontWeight.bold)),
                SizedBox(height: 8),
                Text('• Voit ses points et ses badges',
                    style: TextStyle(color: Colors.white70)),
                Text('• Suit ses objectifs et punitions',
                    style: TextStyle(color: Colors.white70)),
                Text(
                    '• Peut faire des échanges avec les autres enfants',
                    style: TextStyle(color: Colors.white70)),
                SizedBox(height: 20),
                Text(
                    '💡 Le mode Parent est protégé par un code PIN.',
                    style: TextStyle(
                        color: Colors.amber,
                        fontStyle: FontStyle.italic)),
              ]),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Fermer',
                  style: TextStyle(color: Colors.white70))),
        ],
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return AnimatedBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        floatingActionButton: FloatingActionButton.small(
          onPressed: _showInteractiveHelp,
          backgroundColor: Colors.cyan.withOpacity(0.85),
          child: const Icon(Icons.help_outline_rounded,
              color: Colors.white),
        ),
        body: SafeArea(
          child: Stack(
            children: [
              // ── Particules ──────────────────────────────────────────
              AnimatedBuilder(
                animation: _particleController,
                builder: (_, __) => CustomPaint(
                  size: Size(size.width, size.height),
                  painter: _WelcomeParticlePainter(
                    particles: _particles,
                    time: _particleController.value,
                  ),
                ),
              ),

              // ── Contenu ─────────────────────────────────────────────
              SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  children: [
                    const SizedBox(height: 32),

                    // ══ LOGO ══
                    FadeTransition(
                      opacity: _logoFade,
                      child: ScaleTransition(
                        scale: _logoScale,
                        child: AnimatedBuilder(
                          animation: _pulseAnim,
                          builder: (_, __) => Container(
                            width: 110,
                            height: 110,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: const LinearGradient(
                                colors: [
                                  Color(0xFF00E5FF),
                                  Color(0xFF7C4DFF)
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF00E5FF)
                                      .withOpacity(
                                          _pulseAnim.value * 0.5),
                                  blurRadius: 30,
                                  spreadRadius: 5,
                                ),
                              ],
                            ),
                            child: const Center(
                              child: Text('👨‍👩‍👧‍👦',
                                  style:
                                      TextStyle(fontSize: 48)),
                            ),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // ══ TITRE ══
                    FadeTransition(
                      opacity: _logoFade,
                      child: ShaderMask(
                        shaderCallback: (bounds) =>
                            const LinearGradient(
                          colors: [
                            Color(0xFF00E5FF),
                            Colors.white,
                            Color(0xFF7C4DFF),
                          ],
                        ).createShader(bounds),
                        child: const Text(
                          'SKS Family',
                          style: TextStyle(
                            fontSize: 38,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            letterSpacing: 2,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 6),

                    FadeTransition(
                      opacity: _logoFade,
                      child: Text(
                        'Le système de points familial',
                        style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[400],
                            letterSpacing: 1),
                      ),
                    ),

                    const SizedBox(height: 28),

                    // ══ CARTES ENFANTS ══
                    Consumer<FamilyProvider>(
                      builder: (_, fp, __) {
                        if (fp.children.isEmpty) {
                          return FadeTransition(
                            opacity: _cardFade,
                            child: Padding(
                              padding:
                                  const EdgeInsets.symmetric(
                                      horizontal: 24),
                              child: Container(
                                padding:
                                    const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  borderRadius:
                                      BorderRadius.circular(20),
                                  color: Colors.white
                                      .withOpacity(0.04),
                                  border: Border.all(
                                      color: Colors.white
                                          .withOpacity(0.08)),
                                ),
                                child: Column(children: [
                                  const Text('🏠',
                                      style: TextStyle(
                                          fontSize: 36)),
                                  const SizedBox(height: 8),
                                  Text(
                                      'Aucun enfant enregistré',
                                      style: TextStyle(
                                          color: Colors.grey[400],
                                          fontSize: 14)),
                                  const SizedBox(height: 4),
                                  Text(
                                      'Connectez-vous en mode Parent\npour commencer',
                                      textAlign:
                                          TextAlign.center,
                                      style: TextStyle(
                                          color: Colors.grey[600],
                                          fontSize: 12)),
                                ]),
                              ),
                            ),
                          );
                        }

                        final sorted =
                            List<ChildModel>.from(fp.children)
                              ..sort((a, b) =>
                                  b.points.compareTo(a.points));

                        return FadeTransition(
                          opacity: _cardFade,
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(
                                        horizontal: 24),
                                child: Row(children: [
                                  const Text('🏆 ',
                                      style: TextStyle(
                                          fontSize: 16)),
                                  Text(
                                    'Classement de la famille',
                                    style: TextStyle(
                                        color: Colors.grey[400],
                                        fontSize: 13,
                                        fontWeight:
                                            FontWeight.w600,
                                        letterSpacing: 0.5),
                                  ),
                                ]),
                              ),
                              const SizedBox(height: 10),
                              SizedBox(
                                height: 130,
                                child: ListView.builder(
                                  scrollDirection:
                                      Axis.horizontal,
                                  padding:
                                      const EdgeInsets.symmetric(
                                          horizontal: 20),
                                  itemCount: sorted.length,
                                  itemBuilder: (_, i) =>
                                      _ChildStatCard(
                                    child: sorted[i],
                                    rank: i + 1,
                                    delay: i * 100,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),

                    const SizedBox(height: 24),

                    // ══ BOUTON PARENT ══
                    SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(-1, 0),
                        end: Offset.zero,
                      ).animate(_btn1Slide),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 28),
                        child: TvFocusWrapper(
                          onTap: _handleParentMode,
                          child: Container(
                            width: double.infinity,
                            height: 62,
                            decoration: BoxDecoration(
                              borderRadius:
                                  BorderRadius.circular(20),
                              gradient: const LinearGradient(
                                colors: [
                                  Color(0xFF00E5FF),
                                  Color(0xFF0090B5),
                                ],
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF00E5FF)
                                      .withOpacity(0.35),
                                  blurRadius: 20,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            child: const Row(
                              mainAxisAlignment:
                                  MainAxisAlignment.center,
                              children: [
                                Icon(Icons.shield_rounded,
                                    color: Colors.black,
                                    size: 26),
                                SizedBox(width: 12),
                                Text(
                                  'Mode Parent',
                                  style: TextStyle(
                                    color: Colors.black,
                                    fontSize: 19,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 14),

                    // ══ BOUTON ENFANT ══
                    SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(1, 0),
                        end: Offset.zero,
                      ).animate(_btn2Slide),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 28),
                        child: TvFocusWrapper(
                          onTap: _handleChildMode,
                          child: Container(
                            width: double.infinity,
                            height: 62,
                            decoration: BoxDecoration(
                              borderRadius:
                                  BorderRadius.circular(20),
                              border: Border.all(
                                color: const Color(0xFF7C4DFF)
                                    .withOpacity(0.6),
                                width: 2,
                              ),
                              gradient: LinearGradient(
                                colors: [
                                  const Color(0xFF7C4DFF)
                                      .withOpacity(0.15),
                                  const Color(0xFF7C4DFF)
                                      .withOpacity(0.05),
                                ],
                              ),
                            ),
                            child: const Row(
                              mainAxisAlignment:
                                  MainAxisAlignment.center,
                              children: [
                                Text('🧒',
                                    style:
                                        TextStyle(fontSize: 26)),
                                SizedBox(width: 12),
                                Text(
                                  'Mode Enfant',
                                  style: TextStyle(
                                    color: Color(0xFF7C4DFF),
                                    fontSize: 19,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // ══ STATS GLOBALES ══
                    Consumer<FamilyProvider>(
                      builder: (_, fp, __) {
                        if (fp.children.isEmpty) {
                          return const SizedBox.shrink();
                        }
                        final totalPts = fp.children.fold<int>(
                            0, (s, c) => s + c.points);
                        final totalBadges =
                            fp.children.fold<int>(
                                0,
                                (s, c) =>
                                    s + c.badgeIds.length);
                        final topChild =
                            fp.childrenSorted.isNotEmpty
                                ? fp.childrenSorted.first
                                : null;
                        return FadeTransition(
                          opacity: _cardFade,
                          child: Padding(
                            padding:
                                const EdgeInsets.symmetric(
                                    horizontal: 24),
                            child: Container(
                              padding:
                                  const EdgeInsets.symmetric(
                                      vertical: 14,
                                      horizontal: 16),
                              decoration: BoxDecoration(
                                borderRadius:
                                    BorderRadius.circular(18),
                                color: Colors.white
                                    .withOpacity(0.04),
                                border: Border.all(
                                    color: Colors.white
                                        .withOpacity(0.07)),
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceAround,
                                children: [
                                  _StatBubble(
                                    icon: '⭐',
                                    value: '$totalPts',
                                    label: 'Points total',
                                  ),
                                  Container(
                                      width: 1,
                                      height: 36,
                                      color: Colors.white
                                          .withOpacity(0.1)),
                                  _StatBubble(
                                    icon: '🏅',
                                    value: '$totalBadges',
                                    label: 'Badges',
                                  ),
                                  Container(
                                      width: 1,
                                      height: 36,
                                      color: Colors.white
                                          .withOpacity(0.1)),
                                  _StatBubble(
                                    icon: '👑',
                                    value: topChild?.name
                                            .split(' ')
                                            .first ??
                                        '—',
                                    label: 'Leader',
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),

                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  CARTE ENFANT
// ══════════════════════════════════════════════════════════════════════════════

class _ChildStatCard extends StatefulWidget {
  final ChildModel child;
  final int rank;
  final int delay;

  const _ChildStatCard({
    required this.child,
    required this.rank,
    required this.delay,
  });

  @override
  State<_ChildStatCard> createState() => _ChildStatCardState();
}

class _ChildStatCardState extends State<_ChildStatCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 600));
    _anim = CurvedAnimation(
        parent: _ctrl, curve: Curves.easeOutBack);
    Future.delayed(Duration(milliseconds: widget.delay), () {
      if (mounted) _ctrl.forward();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Color get _rankColor {
    switch (widget.rank) {
      case 1:
        return const Color(0xFFFFD700);
      case 2:
        return const Color(0xFFC0C0C0);
      case 3:
        return const Color(0xFFCD7F32);
      default:
        return const Color(0xFF00E5FF);
    }
  }

  String get _rankEmoji {
    switch (widget.rank) {
      case 1:
        return '🥇';
      case 2:
        return '🥈';
      case 3:
        return '🥉';
      default:
        return '${widget.rank}';
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.child;
    return ScaleTransition(
      scale: _anim,
      child: Container(
        width: 110,
        margin: const EdgeInsets.only(right: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              _rankColor.withOpacity(0.12),
              _rankColor.withOpacity(0.04),
            ],
          ),
          border: Border.all(
              color: _rankColor.withOpacity(0.3), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: _rankColor.withOpacity(0.1),
              blurRadius: 12,
              spreadRadius: 1,
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _rankColor.withOpacity(0.15),
                    border: Border.all(
                        color: _rankColor.withOpacity(0.4),
                        width: 2),
                  ),
                  child: c.hasPhoto
                      ? ClipOval(
                          child: Image.memory(
                            base64Decode(c.photoBase64),
                            fit: BoxFit.cover,
                          ),
                        )
                      : Center(
                          child: Text(
                              c.avatar.isEmpty
                                  ? '🧒'
                                  : c.avatar,
                              style: const TextStyle(
                                  fontSize: 22))),
                ),
                Positioned(
                  top: -6,
                  right: -6,
                  child: Text(_rankEmoji,
                      style: const TextStyle(fontSize: 14)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              c.name.split(' ').first,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              '${c.points} pts',
              style: TextStyle(
                color: _rankColor,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: c.levelProgress.clamp(0.0, 1.0),
                minHeight: 4,
                backgroundColor:
                    Colors.white.withOpacity(0.08),
                valueColor:
                    AlwaysStoppedAnimation<Color>(_rankColor),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              c.levelTitle,
              style:
                  TextStyle(color: Colors.grey[500], fontSize: 9),
            ),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  STAT BUBBLE
// ══════════════════════════════════════════════════════════════════════════════

class _StatBubble extends StatelessWidget {
  final String icon;
  final String value;
  final String label;

  const _StatBubble({
    required this.icon,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(icon, style: const TextStyle(fontSize: 18)),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
        ),
        Text(
          label,
          style:
              TextStyle(color: Colors.grey[500], fontSize: 10),
        ),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  PARTICULES
// ══════════════════════════════════════════════════════════════════════════════

class _WelcomeParticle {
  late double x, y, speed, size;

  _WelcomeParticle(math.Random rng) {
    x = rng.nextDouble() * 400;
    y = rng.nextDouble() * 800;
    speed = rng.nextDouble() * 0.5 + 0.2;
    size = rng.nextDouble() * 3 + 1;
  }
}

class _WelcomeParticlePainter extends CustomPainter {
  final List<_WelcomeParticle> particles;
  final double time;

  _WelcomeParticlePainter(
      {required this.particles, required this.time});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.15);
    for (var p in particles) {
      final yPos =
          (p.y + time * p.speed * 50) % (size.height + 50);
      canvas.drawCircle(Offset(p.x, yPos), p.size, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => true;
}
