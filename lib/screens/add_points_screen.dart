import 'dart:math';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:speech_to_text/speech_to_text.dart';
import '../providers/family_provider.dart';
import '../providers/pin_provider.dart';
import '../services/gemini_service.dart';
import '../models/child_model.dart';
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
  bool    _isSubmitting = false;

  final TextEditingController _reasonCtrl = TextEditingController();
  final ImagePicker _picker = ImagePicker();

  late AnimationController _toggleCtrl;
  late Animation<Color?> _bgColorAnim;

  // Raisons (mutables pour permettre la personnalisation des points)
  static List<Map<String, dynamic>> _bonusReasons = [
    {'emoji': '🧹', 'label': 'Ménage',            'points': 3},
    {'emoji': '📚', 'label': 'Devoirs',            'points': 2},
    {'emoji': '🤝', 'label': 'Entraide',           'points': 2},
    {'emoji': '⭐', 'label': 'Bon comportement',   'points': 1},
    {'emoji': '🍽️', 'label': 'Aide cuisine',       'points': 2},
    {'emoji': '🛏️', 'label': 'Chambre rangée',     'points': 1},
    {'emoji': '🌟', 'label': 'Effort scolaire',    'points': 3},
    {'emoji': '😊', 'label': 'Bonne attitude',     'points': 1},
  ];

  static List<Map<String, dynamic>> _penaltyReasons = [
    {'emoji': '😠', 'label': 'Insolence',          'points': 2},
    {'emoji': '🤜', 'label': 'Bagarre',             'points': 3},
    {'emoji': '📵', 'label': 'Écran interdit',      'points': 2},
    {'emoji': '🙉', 'label': 'Désobéissance',       'points': 1},
    {'emoji': '🗣️', 'label': 'Gros mot',            'points': 1},
    {'emoji': '😈', 'label': 'Bêtise',             'points': 2},
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

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? photo = await _picker.pickImage(
        source:       source,
        maxWidth:     800,
        imageQuality: 70,
      );
      if (photo == null) return;
      final bytes = await photo.readAsBytes();
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

  /// Ouvre un dialogue pour régler les points par défaut d'une tâche.
  void _showPointEditor(BuildContext context, int index, Map<String, dynamic> reason) {
    int newPoints = reason['points'] as int;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF0F2620),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Row(
            children: [
              Text(reason['emoji'] as String, style: const TextStyle(fontSize: 28)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Points pour "${reason['label']}"',
                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Maintiens appuyé sur une étiquette pour changer ses points',
                style: TextStyle(color: Colors.white54, fontSize: 11),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Bouton -
                  GestureDetector(
                    onTap: () => setDialogState(() {
                      if (newPoints > 1) newPoints--;
                    }),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.redAccent.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.remove, color: Colors.redAccent, size: 24),
                    ),
                  ),
                  // Valeur
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 24),
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [Color(0xFFD4AF37), Color(0xFFB8860B)]),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      '$newPoints',
                      style: const TextStyle(
                        color: Color(0xFF051410),
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  // Bouton +
                  GestureDetector(
                    onTap: () => setDialogState(() {
                      if (newPoints < 100) newPoints++;
                    }),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.add, color: Colors.green, size: 24),
                    ),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Annuler', style: TextStyle(color: Colors.white54)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFD4AF37),
                foregroundColor: const Color(0xFF051410),
              ),
              onPressed: () {
                setState(() {
                  reason['points'] = newPoints;
                  // Si l'étiquette est sélectionnée, on met à jour les points
                  if (_reason == reason['label']) {
                    _points = newPoints;
                  }
                });
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('✅ "${reason['label']}" = $newPoints pts'),
                    backgroundColor: const Color(0xFFD4AF37),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
              child: const Text('Enregistrer', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  /// Ouvre un dialogue pour taper directement le nombre de points.
  /// Prend une photo, l'envoie à Gemini Vision, et propose une pénalité auto.
  final TextEditingController _nlCtrl = TextEditingController();
  bool _nlLoading = false;
  final SpeechToText _speech = SpeechToText();
  bool _isListening = false;

  /// Champ de saisie en langage naturel (IA Gemini)
  Widget _buildNaturalLanguageInput(BuildContext context, List<ChildModel> children) {
    return GlassCard(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ─── Titre avec étapes ───
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [Colors.deepPurpleAccent, Colors.purpleAccent]),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text('IA', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800)),
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Saisie rapide par IA',
                    style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                ),
                if (_nlLoading)
                  const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.deepPurpleAccent)),
              ],
            ),
            const SizedBox(height: 10),

            // ─── Étape 1 ───
            Row(
              children: [
                Container(
                  width: 20, height: 20,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.deepPurpleAccent.withValues(alpha: 0.3)),
                  child: const Center(child: Text('1', style: TextStyle(color: Colors.deepPurpleAccent, fontSize: 11, fontWeight: FontWeight.w800))),
                ),
                const SizedBox(width: 8),
                const Text('Décris ce qu\'a fait l\'enfant (ou parle 🎤)', style: TextStyle(color: Colors.white54, fontSize: 12)),
              ],
            ),
            const SizedBox(height: 8),

            // ─── Champ texte + boutons ───
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _nlCtrl,
                    style: const TextStyle(color: Colors.white, fontSize: 15),
                    enabled: !_nlLoading,
                    decoration: InputDecoration(
                      hintText: 'ex: "Adam a rangé sa chambre"',
                      hintStyle: const TextStyle(color: Colors.white24),
                      filled: true,
                      fillColor: Colors.white.withValues(alpha: 0.06),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                    onSubmitted: (_) => _processNaturalLanguage(context, children),
                  ),
                ),
                const SizedBox(width: 8),
                // Bouton Micro
                Container(
                  decoration: BoxDecoration(
                    color: _isListening
                        ? Colors.redAccent.withValues(alpha: 0.3)
                        : Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: _isListening
                        ? Border.all(color: Colors.redAccent, width: 2)
                        : null,
                  ),
                  child: IconButton(
                    icon: Icon(
                      _isListening ? Icons.mic_rounded : Icons.mic_none_rounded,
                      color: _isListening ? Colors.redAccent : Colors.white70,
                    ),
                    onPressed: _nlLoading ? null : () => _toggleSpeech(),
                  ),
                ),
                const SizedBox(width: 8),
                // Bouton Envoyer
                Container(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [Colors.deepPurpleAccent, Colors.purpleAccent]),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [BoxShadow(color: Colors.deepPurpleAccent.withValues(alpha: 0.3), blurRadius: 8)],
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.send_rounded, color: Colors.white),
                    onPressed: _nlLoading ? null : () => _processNaturalLanguage(context, children),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // ─── Étape 2 + exemples cliquables ───
            Row(
              children: [
                Container(
                  width: 20, height: 20,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.deepPurpleAccent.withValues(alpha: 0.3)),
                  child: const Center(child: Text('2', style: TextStyle(color: Colors.deepPurpleAccent, fontSize: 11, fontWeight: FontWeight.w800))),
                ),
                const SizedBox(width: 8),
                const Text('L\'IA remplit tout seul → tu valides en bas', style: TextStyle(color: Colors.white54, fontSize: 12)),
              ],
            ),
            const SizedBox(height: 8),

            // Exemples cliquables
            Wrap(
              spacing: 6, runSpacing: 4,
              children: [
                'Rangé sa chambre',
                'Aide à la cuisine',
                'A eu un 18/20',
                'A menti',
                'A disputé son frère',
              ].map((example) {
                return GestureDetector(
                  onTap: _nlLoading ? null : () {
                    _nlCtrl.text = example;
                    _processNaturalLanguage(context, children);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.deepPurpleAccent.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.deepPurpleAccent.withValues(alpha: 0.3)),
                    ),
                    child: Text(example, style: const TextStyle(color: Colors.deepPurpleAccent, fontSize: 11)),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  /// Active/désactive la saisie vocale
  Future<void> _toggleSpeech() async {
    if (_isListening) {
      _speech.stop();
      setState(() => _isListening = false);
      return;
    }

    final available = await _speech.initialize(
      onStatus: (status) {
        if (status == 'done' || status == 'notListening') {
          setState(() => _isListening = false);
        }
      },
      onError: (_) => setState(() => _isListening = false),
    );

    if (available) {
      setState(() => _isListening = true);
      _speech.listen(
        onResult: (result) {
          setState(() {
            _nlCtrl.text = result.recognizedWords;
          });
        },
        localeId: 'fr_FR',
      );
    }
  }

  Future<void> _processNaturalLanguage(BuildContext context, List<ChildModel> children) async {
    final text = _nlCtrl.text.trim();
    if (text.isEmpty) return;

    setState(() => _nlLoading = true);
    final messenger = ScaffoldMessenger.of(context);
    final fp = context.read<FamilyProvider>();

    // Analyser avec Gemini (avec la liste des enfants pour la détection)
    final result = await GeminiService.parseNaturalLanguage(text, childNames: children.map((c) => c.name).toList());

    if (!mounted) return;
    setState(() => _nlLoading = false);

    if (result['type'] == 'error') {
      messenger.showSnackBar(SnackBar(
        content: Text('❌ ${result['reason']}'),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
      ));
      return;
    }

    final isBonus = result['type'] == 'bonus';
    final points = result['points'] as int;
    final reason = result['reason'] as String;
    final childName = result['childName'] as String;

    // Détecter l'enfant automatiquement
    ChildModel? targetChild;
    if (childName.isNotEmpty) {
      targetChild = children.where((c) => c.name.toLowerCase() == childName.toLowerCase()).firstOrNull;
      // Si pas de match exact, chercher par proximité (première lettre)
      if (targetChild == null) {
        targetChild = children.where((c) => c.name.toLowerCase().startsWith(childName.toLowerCase().substring(0, 1))).firstOrNull;
      }
    }
    // Si pas détecté, utiliser l'enfant sélectionné
    targetChild ??= _selectedChildId != null ? children.where((c) => c.id == _selectedChildId).firstOrNull : null;
    if (targetChild == null && children.length == 1) targetChild = children.first;

    if (targetChild == null) {
      // Pré-remplir les champs pour validation manuelle
      setState(() {
        _isBonus = isBonus;
        _points = points;
        _reason = reason;
        _reasonCtrl.text = reason;
        _nlCtrl.clear();
      });
      if (isBonus) { _toggleCtrl.reverse(); } else { _toggleCtrl.forward(); }
      messenger.showSnackBar(SnackBar(
        content: Text('🤖 IA détecté : ${isBonus ? "Bonus" : "Pénalité"} $points pts\nSélectionne un enfant pour valider'),
        backgroundColor: Colors.deepPurpleAccent,
        behavior: SnackBarBehavior.floating,
      ));
      return;
    }

    // ✅ APPLIQUER DIRECTEMENT (sans validation manuelle)
    if (isBonus) {
      await fp.addQuickBonus(targetChild.id, reason);
    } else {
      await fp.addQuickPenalty(targetChild.id, reason);
    }

    setState(() => _nlCtrl.clear());

    HapticFeedback.heavyImpact();
    messenger.showSnackBar(SnackBar(
      content: Text('🤖 ${isBonus ? "✅ Bonus" : "⚠️ Pénalité"} pour ${targetChild.name}\n$points pts : "$reason"'),
      backgroundColor: isBonus ? Colors.green.shade700 : Colors.red.shade700,
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  Future<void> _analyzePhoto(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);

    // 1. Prendre la photo
    final xfile = await ImagePicker().pickImage(
      source: ImageSource.camera,
      imageQuality: 70,
      maxWidth: 800,
    );
    if (xfile == null) return;
    final bytes = await xfile.readAsBytes();
    final base64Photo = base64Encode(bytes);

    // 2. Loader pendant l'analyse
    if (!context.mounted) return;
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
            Text('🔍 Analyse IA en cours...', style: TextStyle(color: Colors.white)),
          ],
        ),
      ),
    );

    // 3. Analyser avec Gemini
    final result = await GeminiService.analyzePhoto(base64Photo);
    if (context.mounted) Navigator.pop(context); // Fermer le loader
    if (!context.mounted) return;

    final isBonus = result['type'] == 'bonus';
    final points = result['points'] as int;
    final reason = result['reason'] as String;

    HapticFeedback.mediumImpact();

    // 4. Dialogue de confirmation avec SÉLECTEUR D'ENFANT
    final fp = context.read<FamilyProvider>();
    final children = fp.children;
    String? selectedChildId;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialog) => AlertDialog(
          backgroundColor: const Color(0xFF0F2620),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(children: [
            Text('🤖', style: TextStyle(fontSize: 28)),
            SizedBox(width: 8),
            Text('Résultat IA', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ]),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Aperçu de la photo
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.memory(
                    bytes,
                    height: 100,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(height: 14),

                // Résultat de l'IA
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: (isBonus ? Colors.green : Colors.redAccent).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: (isBonus ? Colors.green : Colors.redAccent).withValues(alpha: 0.4)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(isBonus ? Icons.check_circle_rounded : Icons.warning_rounded,
                              color: isBonus ? Colors.green : Colors.redAccent, size: 20),
                          const SizedBox(width: 6),
                          Text(
                            '${isBonus ? "BONUS" : "PÉNALITÉ"}',
                            style: TextStyle(
                              color: isBonus ? Colors.green : Colors.redAccent,
                              fontSize: 14, fontWeight: FontWeight.w800,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            '${isBonus ? "+" : "-"}$points pts',
                            style: TextStyle(
                              color: isBonus ? Colors.green : Colors.redAccent,
                              fontSize: 20, fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text('"$reason"',
                        style: const TextStyle(color: Colors.white70, fontSize: 13, fontStyle: FontStyle.italic),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Sélecteur d'enfant
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
                          color: isSelected
                              ? (isBonus ? Colors.green : Colors.redAccent)
                              : Colors.white12,
                          width: isSelected ? 1.5 : 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Text(c.avatar.isNotEmpty ? c.avatar : '👤', style: const TextStyle(fontSize: 20)),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(c.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                          ),
                          if (isSelected)
                            Icon(Icons.check_circle_rounded,
                                color: isBonus ? Colors.green : Colors.redAccent, size: 20),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Annuler', style: TextStyle(color: Colors.white54)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: isBonus ? Colors.green : Colors.redAccent,
                foregroundColor: Colors.white,
              ),
              onPressed: selectedChildId == null ? null : () async {
                Navigator.pop(ctx);
                // 📸 Appliquer les points AVEC la photo (sauvegardée pour le bilan)
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
                    content: Text('${isBonus ? "✅ Bonus" : "⚠️ Pénalité"} appliqué à ${fp.getChild(selectedChildId!)?.name}\n$points pts : "$reason"'),
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

  void _showDirectInput(BuildContext context) {
    final ctrl = TextEditingController(text: _points.toString());
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0F2620),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Nombre de points', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          autofocus: true,
          style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.white.withValues(alpha: 0.06),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler', style: TextStyle(color: Colors.white54))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: _accentColor, foregroundColor: Colors.black),
            onPressed: () {
              final val = int.tryParse(ctrl.text.trim());
              if (val != null && val > 0 && val <= 999) {
                setState(() => _points = val);
                HapticFeedback.selectionClick();
              }
              Navigator.pop(ctx);
            },
            child: const Text('OK', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<void> _submit() async {
    if (_isSubmitting) return;

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

    await showPointsAnimation(context, isBonus: _isBonus, points: _points);
    if (!mounted) return;

    await context.read<FamilyProvider>().addPoints(
      _selectedChildId!,
      _points,
      finalReason,
      isBonus:          _isBonus,
      proofPhotoBase64: _photoBase64,
    );

    if (!mounted) return;

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
      _reason       = '';
      _points       = 1;
      _photoBase64  = null;
      _isSubmitting = false;
      _reasonCtrl.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<FamilyProvider>(
      builder: (context, provider, _) {
        final children = provider.children;

        return Scaffold(
            backgroundColor: const Color(0xFF051410),
            body: SafeArea(
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
                    const SizedBox(height: 16),

                    // ─── Saisie rapide IA (langage naturel) ───
                    _buildNaturalLanguageInput(context, children),

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

                    // ─── ACCÈS RAPIDE (Bonus/Pénalité cumulatif auto) ───
                    if (children.isNotEmpty) ...[
                      Row(
                        children: [
                          Expanded(
                            child: _buildQuickButton(
                              isBonus: true,
                              icon: Icons.add_circle_rounded,
                              label: 'Quick Bonus',
                              color: const Color(0xFF00E676),
                              onTap: () => _quickAction(context, children, isBonus: true),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildQuickButton(
                              isBonus: false,
                              icon: Icons.remove_circle_rounded,
                              label: 'Quick Pénalité',
                              color: const Color(0xFFEF4444),
                              onTap: () => _quickAction(context, children, isBonus: false),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      GlassCard(
                        child: Padding(
                          padding: const EdgeInsets.all(10),
                          child: Row(
                            children: [
                              Icon(Icons.auto_awesome_rounded, size: 16, color: Colors.amberAccent.withValues(alpha: 0.8)),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Le montant est calculé automatiquement : plus il y a de bonus dans la journée, plus ça rapporte !',
                                  style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 11),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Diviseur
                      Row(children: [
                        const Expanded(child: Divider(color: Colors.white12)),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Text('OU choix détaillé', style: TextStyle(color: Colors.white.withValues(alpha: 0.3), fontSize: 11)),
                        ),
                        const Expanded(child: Divider(color: Colors.white12)),
                      ]),
                      const SizedBox(height: 16),
                    ],

                    // ─── Sélection enfant ───────────────────
                    if (children.isEmpty)
                      GlassCard(
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            children: const [
                              Icon(Icons.person_off_rounded,
                                  color: Colors.white38, size: 40),
                              const SizedBox(height: 8),
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

                    // ─── Photo IA (bonus ET pénalité automatiques) ───
                    if (children.isNotEmpty) ...[
                      GlassCard(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.camera_alt_rounded, color: Colors.deepPurpleAccent, size: 20),
                                  const SizedBox(width: 8),
                                  const Expanded(
                                    child: Text(
                                      'Analyse photo IA',
                                      style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w600),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  Container(width: 20, height: 20, decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.deepPurpleAccent.withValues(alpha: 0.3)), child: const Center(child: Text('1', style: TextStyle(color: Colors.deepPurpleAccent, fontSize: 11, fontWeight: FontWeight.w800)))),
                                  const SizedBox(width: 8),
                                  const Text('Prends une photo de la scène', style: TextStyle(color: Colors.white54, fontSize: 12)),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Container(width: 20, height: 20, decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.deepPurpleAccent.withValues(alpha: 0.3)), child: const Center(child: Text('2', style: TextStyle(color: Colors.deepPurpleAccent, fontSize: 11, fontWeight: FontWeight.w800)))),
                                  const SizedBox(width: 8),
                                  const Text('L\'IA détecte bonus/pénalité + points auto', style: TextStyle(color: Colors.white54, fontSize: 12)),
                                ],
                              ),
                              const SizedBox(height: 12),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.deepPurpleAccent,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                  ),
                                  icon: const Icon(Icons.photo_camera_rounded),
                                  label: const Text('Prendre une photo', style: TextStyle(fontWeight: FontWeight.w600)),
                                  onPressed: () => _analyzePhoto(context),
                                ),
                              ),
                              // Aperçu de la photo prise
                              if (_photoBase64 != null) ...[
                                const SizedBox(height: 10),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: Image.memory(
                                    base64Decode(_photoBase64!),
                                    height: 120,
                                    width: double.infinity,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

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
                              children: _currentReasons.asMap().entries.map((entry) {
                                final index = entry.key;
                                final r = entry.value;
                                final isSelected = _reason == r['label'];
                                return GestureDetector(
                                  onTap: () => setState(() {
                                    if (isSelected) {
                                      _reason = '';
                                    } else {
                                      _reason = r['label'] as String;
                                      _points = r['points'] as int;
                                      _reasonCtrl.clear();
                                    }
                                  }),
                                  onLongPress: () => _showPointEditor(context, index, r),
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
                                // 🔧 Le chiffre est cliquable pour taper directement
                                GestureDetector(
                                  onTap: () => _showDirectInput(context),
                                  child: TweenAnimationBuilder<int>(
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
                                        decoration: TextDecoration.underline,
                                        decorationColor: _accentColor.withValues(alpha: 0.3),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 24),
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
                            Wrap(
                              spacing: 6,
                              children: [1, 2, 3, 5, 10, 15, 20, 25, 50].map((val) {
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
        );
      },
    );
  }

  // ─── Bouton d'accès rapide (Bonus/Pénalité cumulatif) ────
  Widget _buildQuickButton({
    required bool isBonus,
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              color.withValues(alpha: 0.25),
              color.withValues(alpha: 0.08),
            ],
          ),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: color.withValues(alpha: 0.5), width: 1.5),
          boxShadow: [
            BoxShadow(color: color.withValues(alpha: 0.2), blurRadius: 12),
          ],
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Action rapide : ouvre un dialogue de sélection MULTI-ENFANTS, puis
  /// applique le bonus ou la pénalité avec calcul automatique du montant.
  /// En mode enfant, crée une demande (createRequest) au lieu d'appliquer direct.
  Future<void> _quickAction(
    BuildContext context,
    List<ChildModel> children, {
    required bool isBonus,
  }) async {
    final fp = context.read<FamilyProvider>();
    final isParent = context.read<PinProvider>().isParentMode;
    final accentColor = isBonus ? const Color(0xFF00E676) : const Color(0xFFEF4444);

    // Si un seul enfant, on applique direct
    if (children.length == 1) {
      if (isParent) {
        await _applyQuick(context, fp, children.first.id, isBonus);
      } else {
        await _createQuickRequest(context, fp, children.first, isBonus);
      }
      return;
    }

    // Bottom sheet de SÉLECTION MULTIPLE
    final selectedIds = await showModalBottomSheet<Set<String>>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => _MultiChildPicker(
        children: children,
        isBonus: isBonus,
        accentColor: accentColor,
      ),
    );

    if (selectedIds == null || selectedIds.isEmpty || !context.mounted) return;

    // Appliquer à chaque enfant sélectionné
    final messenger = ScaffoldMessenger.of(context);
    int totalApplied = 0;
    for (final id in selectedIds) {
      final child = fp.getChild(id);
      if (child == null) continue;
      if (isParent) {
        if (isBonus) {
          totalApplied += await fp.addQuickBonus(id, isBonus ? '🎁 Bonne action' : '⚠️ Mauvaise action');
        } else {
          totalApplied += await fp.addQuickPenalty(id, isBonus ? '🎁 Bonne action' : '⚠️ Mauvaise action');
        }
      } else {
        await _createQuickRequest(context, fp, child, isBonus);
      }
    }

    if (isParent) {
      final label = isBonus ? '+$totalApplied pts' : '-$totalApplied pts';
      messenger.showSnackBar(SnackBar(
        content: Text('✅ ${selectedIds.length} enfant(s) mis à jour ($label)'),
        backgroundColor: accentColor,
        behavior: SnackBarBehavior.floating,
      ));
    } else {
      messenger.showSnackBar(SnackBar(
        content: Text('Demande envoyée pour ${selectedIds.length} enfant(s) ✅'),
        backgroundColor: const Color(0xFF7C4DFF),
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  /// Crée une demande (createRequest) pour validation parent (mode enfant).
  Future<void> _createQuickRequest(BuildContext context, FamilyProvider fp, ChildModel child, bool isBonus) async {
    await fp.createRequest(
      type: isBonus ? 'bonus' : 'penalty',
      childId: child.id,
      requestedBy: child.name,
      text: isBonus ? '🎁 Demande de bonus' : '⚠️ Demande de pénalité',
      amount: isBonus ? 10 : 5,
    );
  }

  /// Applique un quick bonus/pénalité à un seul enfant (mode parent).
  Future<void> _applyQuick(BuildContext context, FamilyProvider fp, String childId, bool isBonus) async {
    final messenger = ScaffoldMessenger.of(context);
    final child = fp.getChild(childId);
    if (child == null) {
      messenger.showSnackBar(const SnackBar(content: Text('Erreur : enfant introuvable')));
      return;
    }

    final reason = isBonus ? '🎁 Bonne action' : '⚠️ Mauvaise action';

    if (isBonus) {
      final amount = await fp.addQuickBonus(childId, reason);
      messenger.showSnackBar(SnackBar(
        content: Text('🎉 +$amount pts pour ${child.name} !'),
        backgroundColor: const Color(0xFF00E676),
        behavior: SnackBarBehavior.floating,
      ));
    } else {
      final amount = await fp.addQuickPenalty(childId, reason);
      if (amount == 0) {
        messenger.showSnackBar(SnackBar(
          content: Text('❌ ${child.name} est déjà à 0 point.'),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
        ));
      } else {
        messenger.showSnackBar(SnackBar(
          content: Text('⚠️ -$amount pts pour ${child.name}'),
          backgroundColor: const Color(0xFFEF4444),
          behavior: SnackBarBehavior.floating,
        ));
      }
    }
  }
}

// ════════════════════════════════════════════════════════════════
// SÉLECTEUR MULTI-ENFANTS (Bottom Sheet)
// ════════════════════════════════════════════════════════════════
class _MultiChildPicker extends StatefulWidget {
  final List<ChildModel> children;
  final bool isBonus;
  final Color accentColor;

  const _MultiChildPicker({
    required this.children,
    required this.isBonus,
    required this.accentColor,
  });

  @override
  State<_MultiChildPicker> createState() => _MultiChildPickerState();
}

class _MultiChildPickerState extends State<_MultiChildPicker> {
  final Set<String> _selected = {};

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF0F2620),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Poignée
          Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 16), decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),

          // Titre
          Text(
            widget.isBonus ? '🎁 Quick Bonus pour qui ?' : '⚠️ Quick Pénalité pour qui ?',
            style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text('${_selected.length} sélectionné(s)', style: TextStyle(color: widget.accentColor, fontSize: 13, fontWeight: FontWeight.w600)),

          const SizedBox(height: 16),

          // Bouton "Tout le monde"
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: widget.accentColor.withValues(alpha: 0.2),
                foregroundColor: widget.accentColor,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: Icon(
                _selected.length == widget.children.length ? Icons.deselect_rounded : Icons.select_all_rounded,
                size: 18,
              ),
              label: Text(_selected.length == widget.children.length ? 'Tout désélectionner' : 'Tout le monde'),
              onPressed: () {
                setState(() {
                  if (_selected.length == widget.children.length) {
                    _selected.clear();
                  } else {
                    _selected.addAll(widget.children.map((c) => c.id));
                  }
                });
              },
            ),
          ),
          const SizedBox(height: 12),

          // Liste des enfants avec cases à cocher
          ConstrainedBox(
            constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.4),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: widget.children.length,
              itemBuilder: (ctx, i) {
                final c = widget.children[i];
                final isSelected = _selected.contains(c.id);
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: widget.accentColor.withValues(alpha: 0.15),
                    child: Text(c.avatar.isNotEmpty ? c.avatar : '👤'),
                  ),
                  title: Text(c.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                  subtitle: Text('${c.points} pts', style: TextStyle(color: widget.accentColor, fontSize: 12)),
                  trailing: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 28, height: 28,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isSelected ? widget.accentColor : Colors.transparent,
                      border: Border.all(color: isSelected ? widget.accentColor : Colors.white24, width: 2),
                    ),
                    child: isSelected ? const Icon(Icons.check, color: Colors.white, size: 18) : null,
                  ),
                  onTap: () {
                    setState(() {
                      if (isSelected) {
                        _selected.remove(c.id);
                      } else {
                        _selected.add(c.id);
                      }
                    });
                  },
                );
              },
            ),
          ),

          const SizedBox(height: 16),

          // Bouton Valider
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: widget.accentColor,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: _selected.isEmpty ? null : () => Navigator.pop(context, _selected),
              child: Text(
                'Valider (${_selected.length})',
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
              ),
            ),
          ),
        ],
      ),
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
}
