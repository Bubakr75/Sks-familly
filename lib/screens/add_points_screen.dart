import 'dart:math';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../providers/family_provider.dart';
import '../widgets/animated_background.dart';
import '../widgets/glass_card.dart';
import '../widgets/tv_focus_wrapper.dart';

// ═══════════════════════════════════════════════════════════
//  EXPLOSION D'ÉTOILES (bonus)
// ═══════════════════════════════════════════════════════════
class _StarExplosion extends StatefulWidget {
  final VoidCallback onComplete;
  final int points;
  const _StarExplosion({required this.onComplete, required this.points});
  @override
  State<_StarExplosion> createState() => _StarExplosionState();
}

class _StarExplosionState extends State<_StarExplosion>
    with TickerProviderStateMixin {
  late AnimationController _burstCtrl;
  late AnimationController _textCtrl;
  late Animation<double> _textScale;
  late Animation<double> _textFade;
  late List<_StarParticle> _stars;
  final _rng = Random();

  @override
  void initState() {
    super.initState();
    _burstCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1400))
      ..forward().then((_) => widget.onComplete());

    _textCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 800));
    _textScale = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _textCtrl, curve: Curves.elasticOut));
    _textFade = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(
            parent: _textCtrl,
            curve: const Interval(0.0, 0.4)));

    _stars = List.generate(
      24,
      (i) => _StarParticle(
        angle: (i / 24) * 2 * pi + _rng.nextDouble() * 0.3,
        speed: 80 + _rng.nextDouble() * 160,
        size: 6 + _rng.nextDouble() * 10,
        color: [
          Colors.amber,
          Colors.yellowAccent,
          Colors.orangeAccent,
          Colors.white,
          Colors.greenAccent,
        ][_rng.nextInt(5)],
        rotation: _rng.nextDouble() * 2 * pi,
        rotSpeed: (_rng.nextDouble() - 0.5) * 8,
      ),
    );

    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) _textCtrl.forward();
    });
  }

  @override
  void dispose() {
    _burstCtrl.dispose();
    _textCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_burstCtrl, _textCtrl]),
      builder: (context, _) {
        final t = _burstCtrl.value;
        return Stack(
          alignment: Alignment.center,
          children: [
            Container(color: Colors.amber.withValues(alpha: 0.08 * (1 - t))),
            CustomPaint(
                size: Size.infinite,
                painter: _StarBurstPainter(_stars, t)),
            FadeTransition(
              opacity: _textFade,
              child: ScaleTransition(
                scale: _textScale,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('⭐', style: TextStyle(fontSize: 48)),
                    const SizedBox(height: 8),
                    Text(
                      '+${widget.points}',
                      style: const TextStyle(
                        color: Colors.amber,
                        fontSize: 56,
                        fontWeight: FontWeight.w900,
                        shadows: [
                          Shadow(color: Colors.orangeAccent, blurRadius: 20)
                        ],
                      ),
                    ),
                    const Text(
                      'BONUS !',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 4,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _StarParticle {
  final double angle, speed, size, rotation, rotSpeed;
  final Color color;
  _StarParticle({
    required this.angle,
    required this.speed,
    required this.size,
    required this.color,
    required this.rotation,
    required this.rotSpeed,
  });
}

class _StarBurstPainter extends CustomPainter {
  final List<_StarParticle> stars;
  final double t;
  _StarBurstPainter(this.stars, this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    for (final star in stars) {
      final dist = star.speed * t;
      final dx = cx + cos(star.angle) * dist;
      final dy = cy + sin(star.angle) * dist - 30 * t;
      final opacity = (1.0 - t).clamp(0.0, 1.0);
      final scale   = star.size * (0.5 + 0.5 * (1 - t));
      if (opacity <= 0) continue;
      canvas.save();
      canvas.translate(dx, dy);
      canvas.rotate(star.rotation + star.rotSpeed * t);
      final paint = Paint()
        ..color = star.color.withValues(alpha: opacity);
      _drawStar(canvas, scale, paint);
      canvas.restore();
    }
  }

  void _drawStar(Canvas canvas, double r, Paint paint) {
    final path = Path();
    for (int i = 0; i < 5; i++) {
      final outerAngle = (i * 2 * pi / 5) - pi / 2;
      final innerAngle = outerAngle + pi / 5;
      if (i == 0) {
        path.moveTo(cos(outerAngle) * r, sin(outerAngle) * r);
      } else {
        path.lineTo(cos(outerAngle) * r, sin(outerAngle) * r);
      }
      path.lineTo(cos(innerAngle) * r * 0.4, sin(innerAngle) * r * 0.4);
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _StarBurstPainter old) => true;
}

// ═══════════════════════════════════════════════════════════
//  FLASH ROUGE (pénalité)
// ═══════════════════════════════════════════════════════════
class _PenaltyFlash extends StatefulWidget {
  final VoidCallback onComplete;
  final int points;
  const _PenaltyFlash({required this.onComplete, required this.points});
  @override
  State<_PenaltyFlash> createState() => _PenaltyFlashState();
}

class _PenaltyFlashState extends State<_PenaltyFlash>
    with TickerProviderStateMixin {
  late AnimationController _flashCtrl;
  late AnimationController _shakeCtrl;
  late AnimationController _textCtrl;
  late Animation<double> _textScale;

  @override
  void initState() {
    super.initState();
    _flashCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1200))
      ..forward().then((_) => widget.onComplete());

    _shakeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500))
      ..forward();

    _textCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _textScale = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _textCtrl, curve: Curves.elasticOut));

    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) _textCtrl.forward();
    });
  }

  @override
  void dispose() {
    _flashCtrl.dispose();
    _shakeCtrl.dispose();
    _textCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_flashCtrl, _shakeCtrl, _textCtrl]),
      builder: (context, _) {
        final flashT  = _flashCtrl.value;
        final shakeT  = _shakeCtrl.value;
        final shakeOffset = sin(shakeT * pi * 8) * 8 * (1 - shakeT);

        return Transform.translate(
          offset: Offset(shakeOffset, 0),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                color: Colors.red.withValues(
                  alpha: flashT < 0.15
                      ? flashT / 0.15 * 0.4
                      : 0.4 *
                          (1 - ((flashT - 0.15) / 0.85))
                              .clamp(0.0, 1.0),
                ),
              ),
              CustomPaint(
                  size: Size.infinite,
                  painter: _ImpactLinesPainter(flashT)),
              ScaleTransition(
                scale: _textScale,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('⚡', style: TextStyle(fontSize: 48)),
                    const SizedBox(height: 8),
                    Text(
                      '-${widget.points}',
                      style: const TextStyle(
                        color: Colors.redAccent,
                        fontSize: 56,
                        fontWeight: FontWeight.w900,
                        shadows: [
                          Shadow(color: Colors.red, blurRadius: 20)
                        ],
                      ),
                    ),
                    const Text(
                      'PÉNALITÉ',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ImpactLinesPainter extends CustomPainter {
  final double t;
  _ImpactLinesPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    if (t > 0.6) return;
    final cx    = size.width / 2;
    final cy    = size.height / 2;
    final paint = Paint()
      ..color      = Colors.redAccent.withValues(alpha: (0.6 - t) / 0.6 * 0.5)
      ..strokeWidth = 2.5
      ..style      = PaintingStyle.stroke;
    final rng = Random(42);
    for (int i = 0; i < 12; i++) {
      final angle  = (i / 12) * 2 * pi + rng.nextDouble() * 0.2;
      final innerR = 40 + 80 * t;
      final outerR = 60 + 140 * t;
      canvas.drawLine(
        Offset(cx + cos(angle) * innerR, cy + sin(angle) * innerR),
        Offset(cx + cos(angle) * outerR, cy + sin(angle) * outerR),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ImpactLinesPainter old) => true;
}

// ═══════════════════════════════════════════════════════════
//  DIALOGUE D'ANIMATION POINTS
// ═══════════════════════════════════════════════════════════
Future<void> showPointsAnimation(
  BuildContext context, {
  required bool isBonus,
  required int points,
}) {
  return showGeneralDialog(
    context: context,
    barrierDismissible: false,
    barrierColor: Colors.black54,
    transitionDuration: const Duration(milliseconds: 100),
    pageBuilder: (ctx, _, __) => Material(
      color: Colors.transparent,
      child: isBonus
          ? _StarExplosion(
              points: points,
              onComplete: () => Navigator.of(ctx).pop(),
            )
          : _PenaltyFlash(
              points: points,
              onComplete: () => Navigator.of(ctx).pop(),
            ),
    ),
  );
}

// ═══════════════════════════════════════════════════════════
//  ADD POINTS SCREEN
// ═══════════════════════════════════════════════════════════
class AddPointsScreen extends StatefulWidget {
  const AddPointsScreen({super.key});
  @override
  State<AddPointsScreen> createState() => _AddPointsScreenState();
}

class _AddPointsScreenState extends State<AddPointsScreen>
    with SingleTickerProviderStateMixin {
  String? _selectedChildId;
  bool    _isBonus      = true;
  int     _points       = 1;
  String  _reason       = '';
  String? _photoBase64;
  bool    _isSubmitting = false; // ✅ évite les doubles soumissions

  final TextEditingController _reasonCtrl = TextEditingController();
  final ImagePicker _picker = ImagePicker();

  late AnimationController _toggleCtrl;
  late Animation<Color?> _bgColorAnim;

  // ─── Raisons rapides ──────────────────────────────────────
  static const _bonusReasons = [
    {'emoji': '🧹', 'label': 'Ménage',            'points': 3},
    {'emoji': '📚', 'label': 'Devoirs',            'points': 2},
    {'emoji': '🤝', 'label': 'Entraide',           'points': 2},
    {'emoji': '⭐', 'label': 'Bon comportement',   'points': 1},
    {'emoji': '🍽️', 'label': 'Aide cuisine',       'points': 2},
    {'emoji': '🛏️', 'label': 'Chambre rangée',     'points': 1},
    {'emoji': '🌟', 'label': 'Effort scolaire',    'points': 3},
    {'emoji': '😊', 'label': 'Bonne attitude',     'points': 1},
  ];

  static const _penaltyReasons = [
    {'emoji': '😠', 'label': 'Insolence',          'points': 2},
    {'emoji': '🤜', 'label': 'Bagarre',             'points': 3},
    {'emoji': '📵', 'label': 'Écran interdit',      'points': 2},
    {'emoji': '🙉', 'label': 'Désobéissance',       'points': 1},
    {'emoji': '🗣️', 'label': 'Gros mot',            'points': 1},
    {'emoji': '😈', 'label': 'Bêtise',              'points': 2},
    {'emoji': '🤥', 'label': 'Mensonge',            'points': 2},
    {'emoji': '🏚️', 'label': 'Désordre',            'points': 1},
  ];

  @override
  void initState() {
    super.initState();
    _toggleCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 400));
    _bgColorAnim = ColorTween(
      begin: Colors.green.withValues(alpha: 0.06),
      end:   Colors.red.withValues(alpha: 0.06),
    ).animate(CurvedAnimation(parent: _toggleCtrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _toggleCtrl.dispose();
    _reasonCtrl.dispose();
    super.dispose();
  }

  // ─── Toggle bonus / pénalité ────────────────────────────
  void _toggleMode(bool bonus) {
    if (_isBonus == bonus) return;
    setState(() {
      _isBonus = bonus;
      _reason  = '';
      _reasonCtrl.clear();
      _points  = 1;
    });
    bonus ? _toggleCtrl.reverse() : _toggleCtrl.forward();
    HapticFeedback.selectionClick();
  }

  List<Map<String, dynamic>> get _currentReasons =>
      _isBonus ? _bonusReasons : _penaltyReasons;
  Color get _accentColor =>
      _isBonus ? Colors.greenAccent : Colors.redAccent;

  // ─── Photos ─────────────────────────────────────────────
  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? photo = await _picker.pickImage(
        source:       source,
        maxWidth:     800,
        imageQuality: 70,
      );
      if (photo == null) return;
      final bytes = await photo.readAsBytes();
      // ✅ Vérifie que l'image ne dépasse pas ~700KB une fois encodée
      if (bytes.lengthInBytes > 700 * 1024) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('⚠️ Image trop lourde. Choisissez une image plus petite.'),
            backgroundColor: Colors.orange,
          ));
        }
        return;
      }
      setState(() => _photoBase64 = base64Encode(bytes));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Erreur photo : $e'),
          backgroundColor: Colors.red,
        ));
      }
    }
  }

  // ─── Soumission ─────────────────────────────────────────
  Future<void> _submit() async {
    if (_isSubmitting) return; // ✅ anti double-tap

    if (_selectedChildId == null) {
      HapticFeedback.heavyImpact();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('👆 Sélectionnez un enfant'),
        backgroundColor: Colors.orange,
        behavior: SnackBarBehavior.floating,
      ));
      return;
    }

    final finalReason = _reason.isNotEmpty
        ? _reason
        : _reasonCtrl.text.trim();
    if (finalReason.isEmpty) {
      HapticFeedback.heavyImpact();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('📝 Indiquez une raison'),
        backgroundColor: Colors.orange,
        behavior: SnackBarBehavior.floating,
      ));
      return;
    }

    setState(() => _isSubmitting = true);

    // Animation d'abord
    await showPointsAnimation(context, isBonus: _isBonus, points: _points);
    if (!mounted) return;

    // ✅ CORRIGÉ : await sur addPoints
    await context.read<FamilyProvider>().addPoints(
      _selectedChildId!,
      _points,
      finalReason,
      isBonus:          _isBonus,
      proofPhotoBase64: _photoBase64,
    );

    if (!mounted) return;

    // Haptic selon le type
    if (_isBonus) {
      HapticFeedback.mediumImpact();
    } else {
      HapticFeedback.heavyImpact();
    }

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(
        children: [
          Icon(_isBonus ? Icons.star_rounded : Icons.warning_rounded,
              color: Colors.white, size: 18),
          const SizedBox(width: 8),
          Text(_isBonus
              ? '+$_points pts ajoutés à ${context.read<FamilyProvider>().getChild(_selectedChildId!)?.name ?? ''} !'
              : '-$_points pts retirés'),
        ],
      ),
      backgroundColor: _isBonus ? Colors.green.shade700 : Colors.red.shade700,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));

    setState(() {
      _reason      = '';
      _points      = 1;
      _photoBase64 = null;
      _isSubmitting = false;
      _reasonCtrl.clear();
    });
  }

  // ─── BUILD ──────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Consumer<FamilyProvider>(
      builder: (context, provider, _) {
        final children = provider.children;
        final primary  = Theme.of(context).colorScheme.primary;

        return AnimatedBackground(
          child: Scaffold(
            backgroundColor: Colors.transparent,
            body: AnimatedBuilder(
              animation: _bgColorAnim,
              builder: (context, child) => Container(
                color: _bgColorAnim.value,
                child: child,
              ),
              child: SafeArea(
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [

                    // ─── Header ────────────────────────────
                    Row(
                      children: [
                        Icon(
                          _isBonus
                              ? Icons.star_rounded
                              : Icons.warning_rounded,
                          color: _accentColor,
                          size: 28,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          _isBonus ? 'Ajouter un bonus' : 'Retirer des points',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // ─── Toggle Bonus / Pénalité ────────────
                    GlassCard(
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: Row(
                          children: [
                            _ToggleButton(
                              label: 'Bonus',
                              icon: Icons.add_circle_rounded,
                              isSelected: _isBonus,
                              activeColor: Colors.greenAccent,
                              onTap: () => _toggleMode(true),
                              autofocus: true,
                            ),
                            const SizedBox(width: 8),
                            _ToggleButton(
                              label: 'Pénalité',
                              icon: Icons.remove_circle_rounded,
                              isSelected: !_isBonus,
                              activeColor: Colors.redAccent,
                              onTap: () => _toggleMode(false),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // ─── Sélection enfant ───────────────────
                    if (children.isEmpty)
                      GlassCard(
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            children: const [
                              Icon(Icons.person_off_rounded,
                                  color: Colors.white38, size: 40),
                              SizedBox(height: 8),
                              Text(
                                'Aucun enfant enregistré.\nAjoutez des enfants dans les Réglages.',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Colors.white54),
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      GlassCard(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.child_care_rounded,
                                      color: _accentColor, size: 18),
                                  const SizedBox(width: 6),
                                  const Text('Choisir l\'enfant',
                                      style: TextStyle(
                                          color: Colors.white70,
                                          fontSize: 14)),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: children.map((child) {
                                  final isSelected =
                                      _selectedChildId == child.id;
                                  return TvFocusWrapper(
                                    onTap: () => setState(
                                        () => _selectedChildId = child.id),
                                    child: AnimatedContainer(
                                      duration:
                                          const Duration(milliseconds: 200),
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 14, vertical: 10),
                                      decoration: BoxDecoration(
                                        color: isSelected
                                            ? _accentColor.withValues(alpha: 0.2)
                                            : Colors.white.withValues(alpha: 0.06),
                                        borderRadius: BorderRadius.circular(14),
                                        border: Border.all(
                                          color: isSelected
                                              ? _accentColor
                                              : Colors.white24,
                                          width: isSelected ? 2 : 1,
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          CircleAvatar(
                                            radius: 14,
                                            backgroundColor: _accentColor
                                                .withValues(alpha: 0.3),
                                            backgroundImage: child.hasPhoto
                                                ? MemoryImage(base64Decode(
                                                    child.photoBase64))
                                                : null,
                                            child: !child.hasPhoto
                                                ? Text(
                                                    child.avatar.isNotEmpty
                                                        ? child.avatar
                                                        : child.name[0]
                                                            .toUpperCase(),
                                                    style: const TextStyle(
                                                        fontSize: 12),
                                                  )
                                                : null,
                                          ),
                                          const SizedBox(width: 8),
                                          Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                child.name,
                                                style: TextStyle(
                                                  color: isSelected
                                                      ? _accentColor
                                                      : Colors.white70,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                              Text(
                                                '${child.points} pts',
                                                style: TextStyle(
                                                  color: isSelected
                                                      ? _accentColor
                                                          .withValues(alpha: 0.7)
                                                      : Colors.white38,
                                                  fontSize: 11,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                            ],
                          ),
                        ),
                      ),
                    const SizedBox(height: 16),

                    // ─── Raisons rapides ────────────────────
                    GlassCard(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.label_rounded,
                                    color: _accentColor, size: 18),
                                const SizedBox(width: 6),
                                Text(
                                  _isBonus
                                      ? 'Raison du bonus'
                                      : 'Raison de la pénalité',
                                  style: const TextStyle(
                                      color: Colors.white70, fontSize: 14),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: _currentReasons.map((r) {
                                final isSelected = _reason == r['label'];
                                return TvFocusWrapper(
                                  onTap: () => setState(() {
                                    if (isSelected) {
                                      _reason = '';
                                    } else {
                                      _reason = r['label'] as String;
                                      _points = r['points'] as int;
                                      _reasonCtrl.clear();
                                    }
                                  }),
                                  child: AnimatedContainer(
                                    duration:
                                        const Duration(milliseconds: 200),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? _accentColor.withValues(alpha: 0.2)
                                          : Colors.white.withValues(alpha: 0.06),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                        color: isSelected
                                            ? _accentColor
                                            : Colors.white24,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(r['emoji'] as String,
                                            style: const TextStyle(
                                                fontSize: 16)),
                                        const SizedBox(width: 6),
                                        Text(
                                          r['label'] as String,
                                          style: TextStyle(
                                            color: isSelected
                                                ? _accentColor
                                                : Colors.white70,
                                            fontSize: 13,
                                          ),
                                        ),
                                        if (isSelected) ...[
                                          const SizedBox(width: 4),
                                          Text(
                                            '(${r['points']} pts)',
                                            style: TextStyle(
                                              color: _accentColor
                                                  .withValues(alpha: 0.7),
                                              fontSize: 11,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: _reasonCtrl,
                              style: const TextStyle(color: Colors.white),
                              decoration: InputDecoration(
                                hintText:
                                    'Ou saisissez une raison personnalisée...',
                                hintStyle:
                                    const TextStyle(color: Colors.white30),
                                prefixIcon: Icon(Icons.edit_note_rounded,
                                    color: _accentColor),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide:
                                      BorderSide(color: _accentColor),
                                ),
                              ),
                              onChanged: (val) {
                                if (val.isNotEmpty && _reason.isNotEmpty) {
                                  setState(() => _reason = '');
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // ─── Nombre de points ───────────────────
                    GlassCard(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Icon(Icons.star_half_rounded,
                                    color: _accentColor, size: 18),
                                const SizedBox(width: 6),
                                const Text('Nombre de points',
                                    style: TextStyle(
                                        color: Colors.white70, fontSize: 14)),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                // ─ Bouton moins
                                _PointsButton(
                                  icon: Icons.remove_rounded,
                                  onTap: () {
                                    if (_points > 1) {
                                      setState(() => _points--);
                                      HapticFeedback.selectionClick();
                                    }
                                  },
                                  enabled: _points > 1,
                                ),
                                const SizedBox(width: 24),
                                // ─ Valeur animée
                                TweenAnimationBuilder<int>(
                                  tween: IntTween(
                                      begin: _points, end: _points),
                                  duration:
                                      const Duration(milliseconds: 200),
                                  builder: (context, val, _) => Text(
                                    '$val',
                                    style: TextStyle(
                                      color: _accentColor,
                                      fontSize: 48,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 24),
                                // ─ Bouton plus
                                _PointsButton(
                                  icon: Icons.add_rounded,
                                  onTap: () {
                                    if (_points < 99) {
                                      setState(() => _points++);
                                      HapticFeedback.selectionClick();
                                    }
                                  },
                                  enabled: _points < 99,
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            // Raccourcis rapides
                            Wrap(
                              spacing: 6,
                              children: [1, 2, 3, 5, 10, 20].map((val) {
                                final isSelected = _points == val;
                                return TvFocusWrapper(
                                  onTap: () {
                                    setState(() => _points = val);
                                    HapticFeedback.selectionClick();
                                  },
                                  child: AnimatedContainer(
                                    duration:
                                        const Duration(milliseconds: 150),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 14, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? _accentColor.withValues(alpha: 0.2)
                                          : Colors.transparent,
                                      borderRadius:
                                          BorderRadius.circular(20),
                                      border: Border.all(
                                        color: isSelected
                                            ? _accentColor
                                            : Colors.white24,
                                      ),
                                    ),
                                    child: Text(
                                      '$val',
                                      style: TextStyle(
                                        color: isSelected
                                            ? _accentColor
                                            : Colors.white54,
                                        fontWeight: isSelected
                                            ? FontWeight.bold
                                            : FontWeight.normal,
                                      ),
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // ─── Photo preuve ───────────────────────
                    GlassCard(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.photo_camera_rounded,
                                    color: _accentColor, size: 18),
                                const SizedBox(width: 6),
                                const Text(
                                  'Photo preuve (optionnel)',
                                  style: TextStyle(
                                      color: Colors.white70, fontSize: 14),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            if (_photoBase64 != null) ...[
                              ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Image.memory(
                                  base64Decode(_photoBase64!),
                                  height: 150,
                                  width: double.infinity,
                                  fit: BoxFit.cover,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Center(
                                child: TextButton.icon(
                                  onPressed: () =>
                                      setState(() => _photoBase64 = null),
                                  icon: const Icon(Icons.delete_outline,
                                      color: Colors.redAccent, size: 18),
                                  label: const Text('Supprimer la photo',
                                      style:
                                          TextStyle(color: Colors.redAccent)),
                                ),
                              ),
                            ] else
                              Row(
                                children: [
                                  Expanded(
                                    child: TvFocusWrapper(
                                      onTap: () =>
                                          _pickImage(ImageSource.camera),
                                      child: OutlinedButton.icon(
                                        onPressed: () => _pickImage(
                                            ImageSource.camera),
                                        icon: const Icon(
                                            Icons.camera_alt_rounded,
                                            size: 18),
                                        label: const Text('Caméra'),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: TvFocusWrapper(
                                      onTap: () =>
                                          _pickImage(ImageSource.gallery),
                                      child: OutlinedButton.icon(
                                        onPressed: () => _pickImage(
                                            ImageSource.gallery),
                                        icon: const Icon(
                                            Icons.photo_library_rounded,
                                            size: 18),
                                        label: const Text('Galerie'),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // ─── Bouton soumettre ───────────────────
                    SizedBox(
                      width: double.infinity,
                      height: 58,
                      child: TvFocusWrapper(
                        onTap: _isSubmitting ? null : _submit,
                        child: ElevatedButton.icon(
                          onPressed: _isSubmitting ? null : _submit,
                          icon: _isSubmitting
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white),
                                )
                              : Icon(
                                  _isBonus
                                      ? Icons.star_rounded
                                      : Icons.warning_rounded,
                                  size: 24,
                                ),
                          label: Text(
                            _isSubmitting
                                ? 'Enregistrement...'
                                : _isBonus
                                    ? 'Ajouter le bonus'
                                    : 'Retirer les points',
                            style: const TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _isBonus
                                ? Colors.green.shade600
                                : Colors.red.shade600,
                            foregroundColor: Colors.white,
                            disabledBackgroundColor: Colors.grey.shade700,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16)),
                            elevation: 6,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
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

// ─── Widgets helpers ────────────────────────────────────────

class _ToggleButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final Color activeColor;
  final VoidCallback onTap;
  final bool autofocus;

  const _ToggleButton({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.activeColor,
    required this.onTap,
    this.autofocus = false,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: TvFocusWrapper(
        autofocus: autofocus,
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: isSelected
                ? activeColor.withValues(alpha: 0.2)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: isSelected
                ? Border.all(color: activeColor.withValues(alpha: 0.5))
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon,
                  color: isSelected ? activeColor : Colors.white38,
                  size: 22),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? activeColor : Colors.white38,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PointsButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool enabled;

  const _PointsButton({
    required this.icon,
    required this.onTap,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return TvFocusWrapper(
      onTap: enabled ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: enabled
              ? Colors.white.withValues(alpha: 0.1)
              : Colors.white.withValues(alpha: 0.03),
          border: Border.all(
              color: enabled ? Colors.white24 : Colors.white12),
        ),
        child: Icon(icon,
            color: enabled ? Colors.white70 : Colors.white24),
      ),
    );
  }
  // Ajouter dans le State, après la soumission réussie d'un point :

// Stocker le dernier ajout pour permettre l'annulation
String? _lastEntryId;
String? _lastChildId;
bool _showUndoButton = false;

// Après l'appel à familyProvider.addPoints, récupérer l'ID :
// (addPoints doit retourner l'ID — voir modification provider ci-dessous)

void _submitPoints() {
  // ... validation existante ...
  
  final entryId = familyProvider.addPoints(
    childId: selectedChildId,
    points: _pointCount,
    reason: _reason,
    category: _isBonus ? 'Bonus' : 'Pénalité',
    isBonus: _isBonus,
    proofPhotoBase64: _proofPhoto,
  );

  // Stocker pour annulation
  _lastEntryId = entryId;
  _lastChildId = selectedChildId;
  _showUndoButton = true;

  // Masquer le bouton après 10 secondes
  Future.delayed(const Duration(seconds: 10), () {
    if (mounted) setState(() => _showUndoButton = false);
  });

  // ... animation existante ...
}

// Ajouter un bouton "Annuler" dans le build, visible après soumission :

if (_showUndoButton && _lastEntryId != null)
  Positioned(
    bottom: 100,
    left: 20,
    right: 20,
    child: TvFocusWrapper(
      onTap: () {
        final familyProvider = context.read<FamilyProvider>();
        familyProvider.deleteHistoryEntry(
          childId: _lastChildId!,
          entryId: _lastEntryId!,
          reversePoints: true,
        );
        setState(() => _showUndoButton = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('↩️ Action annulée — Points restaurés'),
            backgroundColor: Colors.purple.withOpacity(0.8),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
          ),
        );
      },
      child: GlassCard(
        glowColor: Colors.purple,
        onTap: () { /* handled above */ },
        child: const Padding(
          padding: EdgeInsets.symmetric(vertical: 14),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.undo, color: Colors.purpleAccent),
              SizedBox(width: 8),
              Text('↩️ Annuler le dernier ajout',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.purpleAccent)),
            ],
          ),
        ),
      ),
    ),
  ),

}
