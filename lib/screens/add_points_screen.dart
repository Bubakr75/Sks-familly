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

class _StarExplosionState extends State<_StarExplosion> with TickerProviderStateMixin {
  late AnimationController _burstCtrl;
  late AnimationController _textCtrl;
  late Animation<double> _textScale;
  late Animation<double> _textFade;
  final _rng = Random();
  late List<_StarParticle> _stars;

  @override
  void initState() {
    super.initState();
    _burstCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))
      ..forward().then((_) => widget.onComplete());
    _textCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _textScale = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(parent: _textCtrl, curve: Curves.elasticOut));
    _textFade = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(parent: _textCtrl, curve: const Interval(0.0, 0.4)));

    _stars = List.generate(24, (i) => _StarParticle(
      angle: (i / 24) * 2 * pi + _rng.nextDouble() * 0.3,
      speed: 80 + _rng.nextDouble() * 160,
      size: 6 + _rng.nextDouble() * 10,
      color: [Colors.amber, Colors.yellowAccent, Colors.orangeAccent, Colors.white, Colors.greenAccent][_rng.nextInt(5)],
      rotation: _rng.nextDouble() * 2 * pi,
      rotSpeed: (_rng.nextDouble() - 0.5) * 8,
    ));

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
            // Fond doré semi-transparent
            Container(color: Colors.amber.withOpacity(0.08 * (1 - t))),
            // Étoiles
            CustomPaint(size: Size.infinite, painter: _StarBurstPainter(_stars, t)),
            // Texte "+X pts"
            FadeTransition(
              opacity: _textFade,
              child: ScaleTransition(
                scale: _textScale,
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Text('⭐', style: TextStyle(fontSize: 48)),
                  const SizedBox(height: 8),
                  Text('+${widget.points}', style: const TextStyle(color: Colors.amber, fontSize: 56, fontWeight: FontWeight.w900, shadows: [Shadow(color: Colors.orangeAccent, blurRadius: 20)])),
                  const Text('BONUS !', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold, letterSpacing: 4)),
                ]),
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
  _StarParticle({required this.angle, required this.speed, required this.size, required this.color, required this.rotation, required this.rotSpeed});
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
      final dy = cy + sin(star.angle) * dist - 30 * t; // légère montée
      final opacity = (1.0 - t).clamp(0.0, 1.0);
      final scale = star.size * (0.5 + 0.5 * (1 - t));
      if (opacity <= 0) continue;
      canvas.save();
      canvas.translate(dx, dy);
      canvas.rotate(star.rotation + star.rotSpeed * t);
      final paint = Paint()..color = star.color.withOpacity(opacity);
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

class _PenaltyFlashState extends State<_PenaltyFlash> with TickerProviderStateMixin {
  late AnimationController _flashCtrl;
  late AnimationController _shakeCtrl;
  late AnimationController _textCtrl;
  late Animation<double> _textScale;

  @override
  void initState() {
    super.initState();
    _flashCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))
      ..forward().then((_) => widget.onComplete());
    _shakeCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 500))..forward();
    _textCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _textScale = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(parent: _textCtrl, curve: Curves.elasticOut));

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
        final flashT = _flashCtrl.value;
        final shakeT = _shakeCtrl.value;
        // Tremblement horizontal
        final shakeOffset = sin(shakeT * pi * 8) * 8 * (1 - shakeT);

        return Transform.translate(
          offset: Offset(shakeOffset, 0),
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Flash rouge
              Container(
                color: Colors.red.withOpacity(
                  flashT < 0.15 ? flashT / 0.15 * 0.4 : 0.4 * (1 - ((flashT - 0.15) / 0.85)).clamp(0.0, 1.0),
                ),
              ),
              // Lignes d'impact
              CustomPaint(size: Size.infinite, painter: _ImpactLinesPainter(flashT)),
              // Texte
              ScaleTransition(
                scale: _textScale,
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Text('⚡', style: TextStyle(fontSize: 48)),
                  const SizedBox(height: 8),
                  Text('-${widget.points}', style: const TextStyle(color: Colors.redAccent, fontSize: 56, fontWeight: FontWeight.w900, shadows: [Shadow(color: Colors.red, blurRadius: 20)])),
                  const Text('PÉNALITÉ', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold, letterSpacing: 4)),
                ]),
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
    final cx = size.width / 2;
    final cy = size.height / 2;
    final paint = Paint()
      ..color = Colors.redAccent.withOpacity((0.6 - t) / 0.6 * 0.5)
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;
    final rng = Random(42);
    for (int i = 0; i < 12; i++) {
      final angle = (i / 12) * 2 * pi + rng.nextDouble() * 0.2;
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
Future<void> showPointsAnimation(BuildContext context, {required bool isBonus, required int points}) {
  return showGeneralDialog(
    context: context,
    barrierDismissible: false,
    barrierColor: Colors.black54,
    transitionDuration: const Duration(milliseconds: 100),
    pageBuilder: (ctx, _, __) {
      return Material(
        color: Colors.transparent,
        child: isBonus
            ? _StarExplosion(points: points, onComplete: () => Navigator.of(ctx).pop())
            : _PenaltyFlash(points: points, onComplete: () => Navigator.of(ctx).pop()),
      );
    },
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

class _AddPointsScreenState extends State<AddPointsScreen> with SingleTickerProviderStateMixin {
  String? _selectedChildId;
  bool _isBonus = true;
  int _points = 1;
  String _reason = '';
  String? _photoBase64;
  final TextEditingController _reasonCtrl = TextEditingController();
  final ImagePicker _picker = ImagePicker();

  late AnimationController _toggleCtrl;
  late Animation<Color?> _bgColorAnim;

  final List<Map<String, dynamic>> _bonusReasons = [
    {'emoji': '🧹', 'label': 'Ménage', 'points': 3},
    {'emoji': '📚', 'label': 'Devoirs', 'points': 2},
    {'emoji': '🤝', 'label': 'Entraide', 'points': 2},
    {'emoji': '⭐', 'label': 'Bon comportement', 'points': 1},
    {'emoji': '🍽️', 'label': 'Aide cuisine', 'points': 2},
    {'emoji': '🛏️', 'label': 'Chambre rangée', 'points': 1},
  ];

  final List<Map<String, dynamic>> _penaltyReasons = [
    {'emoji': '😠', 'label': 'Insolence', 'points': 2},
    {'emoji': '🤜', 'label': 'Bagarre', 'points': 3},
    {'emoji': '📵', 'label': 'Écran interdit', 'points': 2},
    {'emoji': '🙉', 'label': 'Désobéissance', 'points': 1},
    {'emoji': '🗣️', 'label': 'Gros mot', 'points': 1},
    {'emoji': '😈', 'label': 'Bêtise', 'points': 2},
  ];

  @override
  void initState() {
    super.initState();
    _toggleCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 400));
    _bgColorAnim = ColorTween(
      begin: Colors.green.withOpacity(0.06),
      end: Colors.red.withOpacity(0.06),
    ).animate(CurvedAnimation(parent: _toggleCtrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _toggleCtrl.dispose();
    _reasonCtrl.dispose();
    super.dispose();
  }

  void _toggleMode(bool bonus) {
    setState(() {
      _isBonus = bonus;
      _reason = '';
      _reasonCtrl.clear();
    });
    if (bonus) {
      _toggleCtrl.reverse();
    } else {
      _toggleCtrl.forward();
    }
  }

  List<Map<String, dynamic>> get _currentReasons => _isBonus ? _bonusReasons : _penaltyReasons;
  Color get _accentColor => _isBonus ? Colors.greenAccent : Colors.redAccent;

  Future<void> _takePhoto() async {
    final XFile? photo = await _picker.pickImage(source: ImageSource.camera, maxWidth: 800, imageQuality: 70);
    if (photo != null) {
      final bytes = await photo.readAsBytes();
      setState(() => _photoBase64 = base64Encode(bytes));
    }
  }

  Future<void> _pickPhoto() async {
    final XFile? photo = await _picker.pickImage(source: ImageSource.gallery, maxWidth: 800, imageQuality: 70);
    if (photo != null) {
      final bytes = await photo.readAsBytes();
      setState(() => _photoBase64 = base64Encode(bytes));
    }
  }

  void _submit() async {
    if (_selectedChildId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sélectionnez un enfant'), backgroundColor: Colors.orangeAccent));
      return;
    }
    final finalReason = _reason.isNotEmpty ? _reason : _reasonCtrl.text;
    if (finalReason.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Indiquez une raison'), backgroundColor: Colors.orangeAccent));
      return;
    }

    // Animation AVANT l'ajout
    await showPointsAnimation(context, isBonus: _isBonus, points: _points);

    if (!mounted) return;

    final provider = Provider.of<FamilyProvider>(context, listen: false);
    provider.addPoints(
      _selectedChildId!,
      _points,
      finalReason,
      isBonus: _isBonus,
      proofPhotoBase64: _photoBase64,
    );

    HapticFeedback.mediumImpact();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(_isBonus ? '+$_points pts ajoutés !' : '-$_points pts retirés'),
      backgroundColor: _isBonus ? Colors.green : Colors.redAccent,
    ));

    setState(() {
      _reason = '';
      _reasonCtrl.clear();
      _points = 1;
      _photoBase64 = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<FamilyProvider>(
      builder: (context, provider, _) {
        final children = provider.children;

        return AnimatedBackground(
          child: Scaffold(
            backgroundColor: Colors.transparent,
            body: AnimatedBuilder(
              animation: _bgColorAnim,
              builder: (context, child) {
                return Container(
                  color: _bgColorAnim.value,
                  child: child,
                );
              },
              child: SafeArea(
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    // Header
                    Row(children: [
                      Icon(_isBonus ? Icons.star_rounded : Icons.warning_rounded, color: _accentColor, size: 28),
                      const SizedBox(width: 10),
                      Text(_isBonus ? 'Ajouter un bonus' : 'Retirer des points', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                    ]),
                    const SizedBox(height: 20),

                    // Toggle Bonus / Pénalité
                    GlassCard(child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Row(children: [
                        Expanded(child: TvFocusWrapper(
                          autofocus: true,
                          onTap: () => _toggleMode(true),
                          child: GestureDetector(
                            onTap: () => _toggleMode(true),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 300),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              decoration: BoxDecoration(
                                color: _isBonus ? Colors.green.withOpacity(0.2) : Colors.transparent,
                                borderRadius: BorderRadius.circular(12),
                                border: _isBonus ? Border.all(color: Colors.greenAccent.withOpacity(0.5)) : null,
                              ),
                              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                                Icon(Icons.add_circle_rounded, color: _isBonus ? Colors.greenAccent : Colors.white38, size: 22),
                                const SizedBox(width: 8),
                                Text('Bonus', style: TextStyle(color: _isBonus ? Colors.greenAccent : Colors.white38, fontWeight: FontWeight.bold, fontSize: 16)),
                              ]),
                            ),
                          ),
                        )),
                        const SizedBox(width: 8),
                        Expanded(child: TvFocusWrapper(
                          onTap: () => _toggleMode(false),
                          child: GestureDetector(
                            onTap: () => _toggleMode(false),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 300),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              decoration: BoxDecoration(
                                color: !_isBonus ? Colors.red.withOpacity(0.2) : Colors.transparent,
                                borderRadius: BorderRadius.circular(12),
                                border: !_isBonus ? Border.all(color: Colors.redAccent.withOpacity(0.5)) : null,
                              ),
                              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                                Icon(Icons.remove_circle_rounded, color: !_isBonus ? Colors.redAccent : Colors.white38, size: 22),
                                const SizedBox(width: 8),
                                Text('Pénalité', style: TextStyle(color: !_isBonus ? Colors.redAccent : Colors.white38, fontWeight: FontWeight.bold, fontSize: 16)),
                              ]),
                            ),
                          ),
                        )),
                      ]),
                    )),
                    const SizedBox(height: 16),

                    // Sélection enfant
                    GlassCard(child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        const Text('Enfant', style: TextStyle(color: Colors.white70, fontSize: 14)),
                        const SizedBox(height: 10),
                        Wrap(spacing: 8, runSpacing: 8, children: children.map((child) {
                          final isSelected = _selectedChildId == child.id;
                          return TvFocusWrapper(
                            onTap: () => setState(() => _selectedChildId = child.id),
                            child: GestureDetector(
                              onTap: () => setState(() => _selectedChildId = child.id),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                decoration: BoxDecoration(
                                  color: isSelected ? _accentColor.withOpacity(0.2) : Colors.white.withOpacity(0.06),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: isSelected ? _accentColor : Colors.white24, width: isSelected ? 2 : 1),
                                ),
                                child: Row(mainAxisSize: MainAxisSize.min, children: [
                                  CircleAvatar(
                                    radius: 14, backgroundColor: _accentColor.withOpacity(0.3),
                                    backgroundImage: child.hasPhoto ? MemoryImage(base64Decode(child.photoBase64!)) : null,
                                    child: !child.hasPhoto ? Text(child.avatar.isNotEmpty ? child.avatar : child.name[0], style: const TextStyle(fontSize: 12)) : null,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(child.name, style: TextStyle(color: isSelected ? _accentColor : Colors.white70, fontWeight: FontWeight.w600)),
                                ]),
                              ),
                            ),
                          );
                        }).toList()),
                      ]),
                    )),
                    const SizedBox(height: 16),

                    // Raisons rapides
                    GlassCard(child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(_isBonus ? 'Raison du bonus' : 'Raison de la pénalité', style: const TextStyle(color: Colors.white70, fontSize: 14)),
                        const SizedBox(height: 10),
                        Wrap(spacing: 8, runSpacing: 8, children: _currentReasons.map((r) {
                          final isSelected = _reason == r['label'];
                          return TvFocusWrapper(
                            onTap: () => setState(() { _reason = isSelected ? '' : r['label']; _points = r['points']; if (!isSelected) _reasonCtrl.clear(); }),
                            child: GestureDetector(
                              onTap: () => setState(() { _reason = isSelected ? '' : r['label']; _points = r['points']; if (!isSelected) _reasonCtrl.clear(); }),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: isSelected ? _accentColor.withOpacity(0.2) : Colors.white.withOpacity(0.06),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: isSelected ? _accentColor : Colors.white24),
                                ),
                                child: Row(mainAxisSize: MainAxisSize.min, children: [
                                  Text(r['emoji'], style: const TextStyle(fontSize: 16)),
                                  const SizedBox(width: 6),
                                  Text(r['label'], style: TextStyle(color: isSelected ? _accentColor : Colors.white70, fontSize: 13)),
                                ]),
                              ),
                            ),
                          );
                        }).toList()),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _reasonCtrl,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            hintText: 'Ou saisissez une raison personnalisée...',
                            hintStyle: const TextStyle(color: Colors.white30),
                            filled: true, fillColor: Colors.white.withOpacity(0.06),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: _accentColor)),
                          ),
                          onChanged: (val) { if (val.isNotEmpty) setState(() => _reason = ''); },
                        ),
                      ]),
                    )),
                    const SizedBox(height: 16),

                    // Points
                    GlassCard(child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(children: [
                        const Text('Nombre de points', style: TextStyle(color: Colors.white70, fontSize: 14)),
                        const SizedBox(height: 12),
                        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                          TvFocusWrapper(
                            onTap: () { if (_points > 1) setState(() => _points--); },
                            child: GestureDetector(
                              onTap: () { if (_points > 1) setState(() => _points--); },
                              child: Container(width: 48, height: 48, decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withOpacity(0.1), border: Border.all(color: Colors.white24)),
                                child: const Icon(Icons.remove, color: Colors.white70)),
                            ),
                          ),
                          const SizedBox(width: 24),
                          // Points animés
                          TweenAnimationBuilder<double>(
                            tween: Tween<double>(begin: _points.toDouble(), end: _points.toDouble()),
                            duration: const Duration(milliseconds: 200),
                            builder: (context, val, _) => Text(
                              '${val.round()}',
                              style: TextStyle(color: _accentColor, fontSize: 44, fontWeight: FontWeight.w900),
                            ),
                          ),
                          const SizedBox(width: 24),
                          TvFocusWrapper(
                            onTap: () { if (_points < 50) setState(() => _points++); },
                            child: GestureDetector(
                              onTap: () { if (_points < 50) setState(() => _points++); },
                              child: Container(width: 48, height: 48, decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withOpacity(0.1), border: Border.all(color: Colors.white24)),
                                child: const Icon(Icons.add, color: Colors.white70)),
                            ),
                          ),
                        ]),
                        const SizedBox(height: 10),
                        Row(mainAxisAlignment: MainAxisAlignment.center, children: [1, 2, 3, 5, 10].map((val) {
                          return Padding(padding: const EdgeInsets.symmetric(horizontal: 4), child: TvFocusWrapper(
                            onTap: () => setState(() => _points = val),
                            child: OutlinedButton(
                              onPressed: () => setState(() => _points = val),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: _points == val ? _accentColor : Colors.white54,
                                side: BorderSide(color: _points == val ? _accentColor : Colors.white24),
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                              ),
                              child: Text('$val'),
                            ),
                          ));
                        }).toList()),
                      ]),
                    )),
                    const SizedBox(height: 16),

                    // Photo preuve
                    GlassCard(child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        const Text('Photo preuve (optionnel)', style: TextStyle(color: Colors.white70, fontSize: 14)),
                        const SizedBox(height: 10),
                        if (_photoBase64 != null) ...[
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.memory(base64Decode(_photoBase64!), height: 150, width: double.infinity, fit: BoxFit.cover),
                          ),
                          const SizedBox(height: 8),
                          Center(child: TvFocusWrapper(
                            onTap: () => setState(() => _photoBase64 = null),
                            child: TextButton.icon(
                              onPressed: () => setState(() => _photoBase64 = null),
                              icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 18),
                              label: const Text('Supprimer', style: TextStyle(color: Colors.redAccent)),
                            ),
                          )),
                        ] else
                          Row(children: [
                            Expanded(child: TvFocusWrapper(
                              onTap: _takePhoto,
                              child: OutlinedButton.icon(
                                onPressed: _takePhoto,
                                icon: const Icon(Icons.camera_alt, size: 18),
                                label: const Text('Caméra'),
                                style: OutlinedButton.styleFrom(foregroundColor: Colors.white54, side: const BorderSide(color: Colors.white24), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                              ),
                            )),
                            const SizedBox(width: 10),
                            Expanded(child: TvFocusWrapper(
                              onTap: _pickPhoto,
                              child: OutlinedButton.icon(
                                onPressed: _pickPhoto,
                                icon: const Icon(Icons.photo_library, size: 18),
                                label: const Text('Galerie'),
                                style: OutlinedButton.styleFrom(foregroundColor: Colors.white54, side: const BorderSide(color: Colors.white24), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                              ),
                            )),
                          ]),
                      ]),
                    )),
                    const SizedBox(height: 24),

                    // Bouton soumettre
                    SizedBox(width: double.infinity, height: 56, child: TvFocusWrapper(
                      onTap: _submit,
                      child: ElevatedButton.icon(
                        onPressed: _submit,
                        icon: Icon(_isBonus ? Icons.star_rounded : Icons.warning_rounded, size: 24),
                        label: Text(_isBonus ? 'Ajouter le bonus' : 'Retirer les points', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _isBonus ? Colors.greenAccent.shade700 : Colors.redAccent.shade700,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          elevation: 6,
                        ),
                      ),
                    )),
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
