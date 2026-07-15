// lib/screens/daily_wheel_screen.dart
//
// 🎡 Roue de la Fortune — bonus quotidien aléatoire (1 fois/jour/enfant)

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/family_provider.dart';
import '../models/child_model.dart';
import '../config/emerald_theme.dart';
import '../services/sound_service.dart';

class DailyWheelScreen extends StatefulWidget {
  const DailyWheelScreen({super.key});

  @override
  State<DailyWheelScreen> createState() => _DailyWheelScreenState();
}

class _DailyWheelScreenState extends State<DailyWheelScreen>
    with TickerProviderStateMixin {
  late AnimationController _spinController;
  String? _selectedChildId;
  bool _hasSpunToday = false;
  int _wonAmount = 0;
  bool _isSpinning = false;

  // Segments de la roue : liste de (valeur, label) pour permettre doublons
  static const _segmentValues = [2, 5, 3, 10, 1, 8, 5, 15];
  static const _segmentLabels = [
    '2 pts', '5 pts', '3 pts', 'JACKPOT\n10 pts',
    '1 pt', '8 pts', '5 pts', 'SUPER\n15 pts',
  ];

  static const _segmentColors = <Color>[
    Color(0xFF2E7D32), // vert
    Color(0xFF1565C0), // bleu
    Color(0xFF6A1B9A), // violet
    Color(0xFFD4AF37), // or
    Color(0xFF00838F), // teal
    Color(0xFFAD1457), // rose
    Color(0xFF2E7D32), // vert
    Color(0xFFE65100), // orange
  ];

  @override
  void initState() {
    super.initState();
    _spinController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4000),
    );
  }

  @override
  void dispose() {
    _spinController.dispose();
    super.dispose();
  }

  Future<void> _checkIfSpunToday(String childId) async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateTime.now();
    final key = 'daily_wheel_${childId}_${today.year}_${today.month}_${today.day}';
    setState(() {
      _hasSpunToday = prefs.getBool(key) ?? false;
    });
  }

  Future<void> _markSpunToday(String childId) async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateTime.now();
    final key = 'daily_wheel_${childId}_${today.year}_${today.month}_${today.day}';
    await prefs.setBool(key, true);
  }

  Future<void> _spin(String childId) async {
    if (_isSpinning || _hasSpunToday) return;
    setState(() => _isSpinning = true);
    HapticFeedback.heavyImpact();

    // Choisir un segment gagnant (pondéré : les gros gains sont rares)
    final rand = math.Random();
    final weights = [20, 20, 15, 5, 15, 10, 10, 5]; // correspond aux segments
    final totalWeight = weights.reduce((a, b) => a + b);
    int roll = rand.nextInt(totalWeight);
    int wonIndex = 0;
    for (int i = 0; i < weights.length; i++) {
      roll -= weights[i];
      if (roll < 0) {
        wonIndex = i;
        break;
      }
    }

    _wonAmount = _segmentValues[wonIndex];

    // Animation : tourner 5 tours + atterrir sur le segment gagnant
    final segmentAngle = 360.0 / _segmentValues.length;
    final targetAngle = 360 * 5 + (360 - (wonIndex * segmentAngle) - segmentAngle / 2);

    final tween = Tween<double>(begin: 0, end: targetAngle);
    final animation = CurvedAnimation(
      parent: _spinController,
      curve: Curves.decelerate,
    );

    _spinController.reset();
    _spinController.forward();

    await Future.delayed(const Duration(milliseconds: 4100));

    // Appliquer les points
    final fp = context.read<FamilyProvider>();
    await fp.addPoints(
      childId,
      _wonAmount,
      '🎡 Roue de la fortune quotidienne',
      category: 'Bonus',
      isBonus: true,
    );

    await _markSpunToday(childId);
    setState(() {
      _isSpinning = false;
      _hasSpunToday = true;
    });

    // 🔊 Son : jackpot si gros gain, sinon bonus normal
    if (_wonAmount >= 10) {
      SoundService.playJackpot();
    } else {
      SoundService.playBonus();
    }
  }

  @override
  Widget build(BuildContext context) {
    final fp = context.watch<FamilyProvider>();
    final children = fp.children;
    final child = _selectedChildId != null
        ? fp.getChild(_selectedChildId!)
        : (children.isNotEmpty ? children.first : null);

    if (child != null) {
      _checkIfSpunToday(child.id);
    }

    return Scaffold(
      backgroundColor: EmeraldPalette.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text('🎡 Roue de la Fortune',
            style: TextStyle(color: EmeraldPalette.textPrimary, fontWeight: FontWeight.bold)),
        iconTheme: const IconThemeData(color: EmeraldPalette.textPrimary),
      ),
      body: child == null
          ? const Center(child: Text('Aucun enfant', style: TextStyle(color: Colors.white54)))
          : Column(
              children: [
                // Sélecteur d'enfant
                if (children.length > 1)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: DropdownButtonFormField<String>(
                      value: _selectedChildId ?? children.first.id,
                      dropdownColor: EmeraldPalette.surface,
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: EmeraldPalette.surfaceLow,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                      ),
                      items: children.map((c) => DropdownMenuItem(
                        value: c.id,
                        child: Row(children: [
                          Text(c.avatar.isNotEmpty ? c.avatar : '👤', style: const TextStyle(fontSize: 18)),
                          const SizedBox(width: 8),
                          Text(c.name, style: const TextStyle(color: Colors.white)),
                        ]),
                      )).toList(),
                      onChanged: (v) => setState(() {
                        _selectedChildId = v;
                        _hasSpunToday = false;
                      }),
                    ),
                  ),

                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Roue
                        Stack(
                          alignment: Alignment.center,
                          children: [
                            // Roue animée
                            AnimatedBuilder(
                              animation: _spinController,
                              builder: (context, _) {
                                final value = _spinController.isAnimating
                                    ? Tween<double>(begin: 0, end: 1).evaluate(
                                        CurvedAnimation(parent: _spinController, curve: Curves.decelerate))
                                    : 0.0;
                                final angle = (2 * 5 + 1) * 360 * value * math.pi / 180;
                                return Transform.rotate(
                                  angle: _isSpinning
                                      ? Curves.decelerate.transform(_spinController.value) * targetAngleRad
                                      : 0,
                                  child: _WheelPainter(
                                    values: _segmentValues,
                                    labels: _segmentLabels,
                                    colors: _segmentColors,
                                  ),
                                );
                              },
                            ),
                            // Pointeur (triangle en haut)
                            const Positioned(
                              top: 0,
                              child: Icon(Icons.arrow_drop_down, color: Colors.white, size: 48),
                            ),
                            // Bouton central
                            GestureDetector(
                              onTap: _hasSpunToday || _isSpinning ? null : () => _spin(child.id),
                              child: Container(
                                width: 60,
                                height: 60,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: _hasSpunToday ? Colors.grey : EmeraldPalette.gold,
                                  boxShadow: [
                                    BoxShadow(
                                      color: (_hasSpunToday ? Colors.grey : EmeraldPalette.gold).withValues(alpha: 0.5),
                                      blurRadius: 12,
                                      spreadRadius: 2,
                                    ),
                                  ],
                                ),
                                child: Center(
                                  child: Text(
                                    _isSpinning ? '...' : 'SPIN',
                                    style: TextStyle(
                                      color: const Color(0xFF051410),
                                      fontWeight: FontWeight.w900,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 30),

                        // Message résultat ou info
                        if (_hasSpunToday && _wonAmount > 0)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                            decoration: BoxDecoration(
                              gradient: EmeraldPalette.goldGradient,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Text(
                              '🎉 Tu as gagné +$_wonAmount pts aujourd\'hui !',
                              style: const TextStyle(
                                color: Color(0xFF051410),
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          )
                        else if (_hasSpunToday)
                          const Text(
                            '✅ Reviens demain pour retenter ta chance !',
                            style: TextStyle(color: Colors.white54, fontSize: 14),
                          )
                        else
                          const Text(
                            'Tire ta chance une fois par jour !',
                            style: TextStyle(color: Colors.white54, fontSize: 14),
                          ),

                        const SizedBox(height: 12),
                        const Text(
                          'Gains possibles : 1, 2, 3, 5, 8, 10, 15 pts',
                          style: TextStyle(color: Colors.white38, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  double get targetAngleRad => (2 * 5 * math.pi) + (math.pi);
}

// ─── Painter de la roue ────────────────────────────────────────
class _WheelPainter extends StatelessWidget {
  final List<int> values;
  final List<String> labels;
  final List<Color> colors;

  const _WheelPainter({required this.values, required this.labels, required this.colors});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(280, 280),
      painter: _WheelCustomPainter(values: values, labels: labels, colors: colors),
    );
  }
}

class _WheelCustomPainter extends CustomPainter {
  final List<int> values;
  final List<String> labels;
  final List<Color> colors;

  _WheelCustomPainter({required this.values, required this.labels, required this.colors});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final count = values.length;
    final sweep = 2 * math.pi / count;

    for (int i = 0; i < count; i++) {
      final startAngle = i * sweep - math.pi / 2;
      final paint = Paint()
        ..color = colors[i % colors.length]
        ..style = PaintingStyle.fill;

      // Segment
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweep,
        true,
        paint,
      );

      // Bordure
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweep,
        true,
        Paint()
          ..color = Colors.white.withValues(alpha: 0.2)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );

      // Texte
      final textAngle = startAngle + sweep / 2;
      final textRadius = radius * 0.65;
      final textOffset = Offset(
        center.dx + textRadius * math.cos(textAngle),
        center.dy + textRadius * math.sin(textAngle),
      );

      final textPainter = TextPainter(
        text: TextSpan(
          text: labels[i],
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w800,
          ),
        ),
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      canvas.save();
      canvas.translate(textOffset.dx, textOffset.dy);
      canvas.rotate(textAngle + math.pi / 2);
      textPainter.paint(canvas, Offset(-textPainter.width / 2, -textPainter.height / 2));
      canvas.restore();
    }

    // Contour doré
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = EmeraldPalette.gold
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
