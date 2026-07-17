// lib/screens/daily_wheel_screen.dart
//
// 🎡 Roue de la Fortune v2 — Design 3D premium
// Segments personnalisables par le parent (dessert, points, écran...)
// 1 tour par jour par enfant.

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/family_provider.dart';
import '../providers/pin_provider.dart';
import '../models/child_model.dart';
import '../config/emerald_theme.dart';
import '../models/wheel_segment.dart';
import '../services/sound_service.dart';

class DailyWheelScreen extends StatefulWidget {
  const DailyWheelScreen({super.key});

  @override
  State<DailyWheelScreen> createState() => _DailyWheelScreenState();
}

class _DailyWheelScreenState extends State<DailyWheelScreen>
    with TickerProviderStateMixin {
  late AnimationController _spinController;
  late Animation<double> _spinAnim;
  String? _selectedChildId;
  bool _hasSpunToday = false;
  WheelSegment? _wonSegment;
  bool _isSpinning = false;
  double _currentRotation = 0;

  @override
  void initState() {
    super.initState();
    _spinController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4500),
    );
    _spinAnim = CurvedAnimation(parent: _spinController, curve: Curves.decelerate);
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
    final spun = prefs.getBool(key) ?? false;
    if (spun != _hasSpunToday) {
      setState(() => _hasSpunToday = spun);
    }
  }

  Future<void> _spin(String childId) async {
    if (_isSpinning || _hasSpunToday) return;
    final fp = context.read<FamilyProvider>();
    final segments = fp.wheelSegments;
    if (segments.isEmpty) return;

    setState(() => _isSpinning = true);
    HapticFeedback.heavyImpact();

    // Choisir un segment au hasard
    final rand = math.Random();
    int wonIndex = rand.nextInt(segments.length);

    // Calculer l'angle pour atterrir sur ce segment
    final segmentAngle = 360.0 / segments.length;
    final targetSegmentCenter = wonIndex * segmentAngle + segmentAngle / 2;
    // 5 tours complets + atterrissage (pointer en haut = 270° / -90°)
    final totalRotation = (360 * 5) + (360 - targetSegmentCenter);

    _spinController.reset();
    _currentRotation = 0;

    _spinController.addListener(() {
      setState(() {
        _currentRotation = totalRotation * _spinAnim.value;
      });
    });

    _spinController.forward();

    await Future.delayed(const Duration(milliseconds: 4600));

    _wonSegment = segments[wonIndex];

    // Appliquer la récompense
    if (_wonSegment!.isPoints && _wonSegment!.points! > 0) {
      await fp.addPoints(
        childId,
        _wonSegment!.points!,
        '🎡 Roue de la fortune',
        category: 'Bonus',
        isBonus: true,
      );
    }

    // Marquer le tour comme fait
    final prefs = await SharedPreferences.getInstance();
    final today = DateTime.now();
    final key = 'daily_wheel_${childId}_${today.year}_${today.month}_${today.day}';
    await prefs.setBool(key, true);

    setState(() {
      _isSpinning = false;
      _hasSpunToday = true;
    });

    // 🔊 Son
    if (_wonSegment!.isPoints && _wonSegment!.points! >= 10) {
      SoundService.playJackpot();
    } else {
      SoundService.playBonus();
    }
  }

  @override
  Widget build(BuildContext context) {
    final fp = context.watch<FamilyProvider>();
    final isParent = context.watch<PinProvider>().isParentMode;
    final children = fp.children;
    final segments = fp.wheelSegments;

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
        actions: [
          if (isParent)
            IconButton(
              icon: const Icon(Icons.settings_rounded, color: EmeraldPalette.goldLight, size: 24),
              onPressed: () => _showSegmentEditor(context, fp),
            ),
        ],
      ),
      body: child == null
          ? const Center(child: Text('Aucun enfant', style: TextStyle(color: Colors.white54)))
          : Column(
              children: [
                // Sélecteur d'enfant
                if (children.length > 1)
                  SizedBox(
                    height: 60,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      itemCount: children.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (_, i) {
                        final c = children[i];
                        final isSel = c.id == child.id;
                        return GestureDetector(
                          onTap: () => setState(() {
                            _selectedChildId = c.id;
                            _hasSpunToday = false;
                            _wonSegment = null;
                          }),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: isSel ? EmeraldPalette.emerald.withValues(alpha: 0.2) : Colors.white.withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: isSel ? EmeraldPalette.emerald : Colors.white12),
                            ),
                            child: Row(children: [
                              Text(c.avatar.isNotEmpty ? c.avatar : '👤', style: const TextStyle(fontSize: 18)),
                              const SizedBox(width: 6),
                              Text(c.name, style: TextStyle(color: isSel ? EmeraldPalette.emeraldLight : Colors.white70, fontSize: 12, fontWeight: FontWeight.w600)),
                            ]),
                          ),
                        );
                      },
                    ),
                  ),

                // Roue 3D
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Roue avec effet 3D
                        _buildWheel3D(segments),

                        const SizedBox(height: 30),

                        // Résultat / bouton
                        if (_hasSpunToday && _wonSegment != null) ...[
                          _buildResultCard(_wonSegment!),
                          const SizedBox(height: 12),
                          _buildReplayButton(child),
                        ]
                        else if (_hasSpunToday) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                            decoration: BoxDecoration(
                              color: EmeraldPalette.surfaceLow,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: EmeraldPalette.glassBorder),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.schedule_rounded, color: Colors.white54, size: 20),
                                SizedBox(width: 8),
                                Text('Reviens demain !', style: TextStyle(color: Colors.white54, fontSize: 15, fontWeight: FontWeight.w600)),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          _buildReplayButton(child),
                        ]
                        else
                          Text(
                            _isSpinning ? 'Rotation...' : 'Tire ta chance !',
                            style: const TextStyle(color: Colors.white70, fontSize: 16, fontWeight: FontWeight.w600),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  // ─── Roue 3D avec profondeur et reflets ───────────────────────
  Widget _buildWheel3D(List<WheelSegment> segments) {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Ombre portée (effet 3D — roue surélevée)
        Container(
          width: 300,
          height: 300,
          margin: const EdgeInsets.only(top: 12),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.6),
                blurRadius: 30,
                spreadRadius: 5,
                offset: const Offset(0, 20),
              ),
            ],
          ),
        ),

        // Anneau doré extérieur (effet 3D — bord métallique)
        Container(
          width: 310,
          height: 310,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const SweepGradient(
              colors: [
                Color(0xFFD4AF37), Color(0xFFFFD700), Color(0xFFD4AF37),
                Color(0xFF8B6914), Color(0xFFD4AF37), Color(0xFFFFD700),
                Color(0xFFD4AF37), Color(0xFF8B6914), Color(0xFFD4AF37),
              ],
            ),
          ),
        ),

        // Roue intérieure (segments)
        Transform.rotate(
          angle: _currentRotation * math.pi / 180,
          child: CustomPaint(
            size: const Size(280, 280),
            painter: _Wheel3DPainter(segments: segments),
          ),
        ),

        // Reflet vitré (effet 3D — brillance du haut)
        Container(
          width: 280,
          height: 280,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.center,
              colors: [
                Colors.white.withValues(alpha: 0.15),
                Colors.transparent,
              ],
            ),
          ),
        ),

        // Pointeur 3D (triangle doré en haut)
        Positioned(
          top: -2,
          child: CustomPaint(
            size: const Size(40, 30),
            painter: _PointerPainter(),
          ),
        ),

        // Bouton central 3D (SPIN)
        GestureDetector(
          onTap: _hasSpunToday || _isSpinning ? null : () => _spin(_selectedChildId ?? ''),
          child: Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: _hasSpunToday || _isSpinning
                    ? [Colors.grey.shade600, Colors.grey.shade800]
                    : [const Color(0xFFFFD700), const Color(0xFFB8860B)],
              ),
              boxShadow: [
                BoxShadow(
                  color: (_hasSpunToday || _isSpinning)
                      ? Colors.black.withValues(alpha: 0.3)
                      : const Color(0xFFFFD700).withValues(alpha: 0.6),
                  blurRadius: 16,
                  spreadRadius: 3,
                  offset: const Offset(0, 4),
                ),
              ],
              border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 2),
            ),
            child: Center(
              child: _isSpinning
                  ? const SizedBox(
                      width: 24, height: 24,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : Text(
                      _hasSpunToday ? '✓' : 'SPIN',
                      style: TextStyle(
                        color: const Color(0xFF051410),
                        fontWeight: FontWeight.w900,
                        fontSize: _hasSpunToday ? 28 : 15,
                        shadows: const [Shadow(color: Colors.white, blurRadius: 4)],
                      ),
                    ),
            ),
          ),
        ),
      ],
    );
  }

  // ─── Bouton rejouer (code parent) ─────────────────────────────
  Widget _buildReplayButton(ChildModel child) {
    return GestureDetector(
      onTap: () => _showReplayDialog(child),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white12),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.refresh_rounded, color: Colors.white38, size: 16),
            SizedBox(width: 6),
            Text('Rejouer', style: TextStyle(color: Colors.white38, fontSize: 12, fontWeight: FontWeight.w600)),
            SizedBox(width: 4),
            Icon(Icons.lock_outline, color: Colors.white24, size: 12),
          ],
        ),
      ),
    );
  }

  void _showReplayDialog(ChildModel child) {
    final pinCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: EmeraldPalette.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(children: [
          Icon(Icons.lock_outline, color: EmeraldPalette.gold),
          SizedBox(width: 10),
          Text('Code parent requis', style: TextStyle(color: EmeraldPalette.textPrimary, fontSize: 18, fontWeight: FontWeight.bold)),
        ]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Entrez le code parent pour autoriser un nouveau tour.',
                style: TextStyle(color: Colors.white54, fontSize: 13)),
            const SizedBox(height: 16),
            TextField(
              controller: pinCtrl,
              obscureText: true,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontSize: 24, letterSpacing: 8),
              decoration: InputDecoration(
                filled: true,
                fillColor: EmeraldPalette.surfaceLow,
                hintText: '• • • •',
                hintStyle: const TextStyle(color: Colors.white24, letterSpacing: 8),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
              ),
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
              backgroundColor: EmeraldPalette.gold,
              foregroundColor: const Color(0xFF051410),
            ),
            onPressed: () async {
              final pin = context.read<PinProvider>();
              if (pin.verifyPin(pinCtrl.text.trim())) {
                Navigator.pop(ctx);
                // Réinitialiser le tour
                final prefs = await SharedPreferences.getInstance();
                final today = DateTime.now();
                final key = 'daily_wheel_${child.id}_${today.year}_${today.month}_${today.day}';
                await prefs.setBool(key, false);
                setState(() {
                  _hasSpunToday = false;
                  _wonSegment = null;
                });
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('🔄 Nouveau tour autorisé !'),
                      backgroundColor: EmeraldPalette.gold,
                      duration: Duration(seconds: 2),
                    ),
                  );
                }
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('❌ Code incorrect'),
                    backgroundColor: Colors.redAccent,
                  ),
                );
              }
            },
            child: const Text('Débloquer', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // ─── Carte de résultat ────────────────────────────────────────
  Widget _buildResultCard(WheelSegment segment) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [
          segment.color.withValues(alpha: 0.3),
          segment.color.withValues(alpha: 0.1),
        ]),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: segment.color.withValues(alpha: 0.5), width: 2),
        boxShadow: [
          BoxShadow(color: segment.color.withValues(alpha: 0.3), blurRadius: 20, spreadRadius: 2),
        ],
      ),
      child: Column(
        children: [
          Text(segment.emoji, style: const TextStyle(fontSize: 48)),
          const SizedBox(height: 8),
          const Text('Tu as gagné !',
              style: TextStyle(color: Colors.white54, fontSize: 13)),
          const SizedBox(height: 4),
          Text(
            segment.label,
            style: TextStyle(
              color: segment.color,
              fontSize: 24,
              fontWeight: FontWeight.w900,
            ),
          ),
          if (segment.rewardText != null && segment.rewardText != segment.label) ...[
            const SizedBox(height: 4),
            Text(segment.rewardText!,
                style: const TextStyle(color: Colors.white70, fontSize: 14)),
          ],
          if (segment.isPoints) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: EmeraldPalette.emerald.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text('+${segment.points} pts ajoutés !',
                  style: const TextStyle(color: EmeraldPalette.emeraldLight, fontSize: 13, fontWeight: FontWeight.w700)),
            ),
          ] else if (!segment.isPoints && segment.rewardText != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: EmeraldPalette.gold.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text('Demande au parent pour profiter !',
                  style: TextStyle(color: EmeraldPalette.goldLight, fontSize: 12, fontWeight: FontWeight.w600)),
            ),
          ],
        ],
      ),
    );
  }

  // ─── Éditeur de segments (parent) ─────────────────────────────
  void _showSegmentEditor(BuildContext context, FamilyProvider fp) {
    showModalBottomSheet(
      context: context,
      backgroundColor: EmeraldPalette.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setSheet) {
          return SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 12),
                Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
                const SizedBox(height: 16),
                const Text('Personnaliser les gains',
                    style: TextStyle(color: EmeraldPalette.textPrimary, fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                const Text('Choisis ce que les enfants peuvent gagner',
                    style: TextStyle(color: Colors.white54, fontSize: 13)),
                const SizedBox(height: 16),
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: fp.wheelSegments.length,
                    itemBuilder: (_, i) {
                      final seg = fp.wheelSegments[i];
                      return _SegmentEditTile(
                        segment: seg,
                        onEdit: () {
                          Navigator.pop(ctx);
                          _showSegmentDialog(context, fp, existing: seg);
                        },
                        onDelete: fp.wheelSegments.length > 2
                            ? () async {
                                await fp.deleteWheelSegment(seg.id);
                                setSheet(() {});
                              }
                            : null,
                      );
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: EmeraldPalette.emerald,
                        foregroundColor: const Color(0xFF051410),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('Ajouter un gain', style: TextStyle(fontWeight: FontWeight.w800)),
                      onPressed: () {
                        Navigator.pop(ctx);
                        _showSegmentDialog(context, fp);
                      },
                    ),
                  ),
                ),
              ],
            ),
          );
        });
      },
    );
  }

  void _showSegmentDialog(BuildContext context, FamilyProvider fp, {WheelSegment? existing}) {
    final labelCtrl = TextEditingController(text: existing?.label ?? '');
    final emojiCtrl = TextEditingController(text: existing?.emoji ?? '🎁');
    final pointsCtrl = TextEditingController(text: existing?.points?.toString() ?? '');
    final rewardCtrl = TextEditingController(text: existing?.rewardText ?? '');
    bool isPoints = existing?.isPoints ?? true;
    final emojis = ['⭐', '🍰', '🎮', '🏆', '🍫', '🎬', '🍕', '🎨', '⚽', '🛌', '📱', '🍦', '🚲', '🎯', '🎁', '🔄', '💸', '🎵'];
    final colors = [
      const Color(0xFF2E7D32), const Color(0xFFD4AF37), const Color(0xFF1565C0),
      const Color(0xFF6A1B9A), const Color(0xFF00838F), const Color(0xFFAD1457),
      const Color(0xFFE65100), const Color(0xFF455A64),
    ];
    Color selColor = existing?.color ?? colors[(existing?.id.hashCode ?? 0).abs() % colors.length];
    String selEmoji = existing?.emoji ?? '🎁';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          backgroundColor: EmeraldPalette.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Text(existing == null ? 'Nouveau gain' : 'Modifier',
              style: const TextStyle(color: EmeraldPalette.textPrimary, fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Toggle type
                Row(children: [
                  Expanded(child: GestureDetector(
                    onTap: () => setD(() => isPoints = true),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(color: isPoints ? EmeraldPalette.emerald.withValues(alpha: 0.2) : Colors.white.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(10), border: Border.all(color: isPoints ? EmeraldPalette.emerald : Colors.white12)),
                      child: Center(child: Text('Points', style: TextStyle(color: isPoints ? EmeraldPalette.emeraldLight : Colors.white54, fontWeight: FontWeight.w700))),
                    ),
                  )),
                  const SizedBox(width: 8),
                  Expanded(child: GestureDetector(
                    onTap: () => setD(() => isPoints = false),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(color: !isPoints ? EmeraldPalette.gold.withValues(alpha: 0.2) : Colors.white.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(10), border: Border.all(color: !isPoints ? EmeraldPalette.gold : Colors.white12)),
                      child: Center(child: Text('Récompense', style: TextStyle(color: !isPoints ? EmeraldPalette.goldLight : Colors.white54, fontWeight: FontWeight.w700))),
                    ),
                  )),
                ]),
                const SizedBox(height: 12),
                // Emoji picker
                SizedBox(
                  height: 50,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: emojis.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 4),
                    itemBuilder: (_, i) => GestureDetector(
                      onTap: () => setD(() => selEmoji = emojis[i]),
                      child: Container(
                        width: 44, height: 44,
                        decoration: BoxDecoration(
                          color: selEmoji == emojis[i] ? EmeraldPalette.gold.withValues(alpha: 0.2) : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: selEmoji == emojis[i] ? EmeraldPalette.gold : Colors.transparent),
                        ),
                        child: Center(child: Text(emojis[i], style: const TextStyle(fontSize: 22))),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                if (isPoints)
                  TextField(
                    controller: pointsCtrl,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(labelText: 'Points', labelStyle: TextStyle(color: Colors.white54), filled: true, fillColor: EmeraldPalette.surfaceLow, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none)),
                  )
                else
                  TextField(
                    controller: rewardCtrl,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(labelText: 'Description récompense', labelStyle: TextStyle(color: Colors.white54), filled: true, fillColor: EmeraldPalette.surfaceLow, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none)),
                  ),
                const SizedBox(height: 12),
                TextField(
                  controller: labelCtrl,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(labelText: 'Nom court', labelStyle: TextStyle(color: Colors.white54), filled: true, fillColor: EmeraldPalette.surfaceLow, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none)),
                ),
                const SizedBox(height: 12),
                // Couleurs
                SizedBox(
                  height: 40,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: colors.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 6),
                    itemBuilder: (_, i) => GestureDetector(
                      onTap: () => setD(() => selColor = colors[i]),
                      child: Container(
                        width: 36, height: 36,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: colors[i],
                          border: Border.all(color: selColor == colors[i] ? Colors.white : Colors.transparent, width: 3),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler', style: TextStyle(color: Colors.white54))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: EmeraldPalette.emerald, foregroundColor: const Color(0xFF051410)),
              onPressed: () {
                final label = labelCtrl.text.trim();
                if (label.isEmpty) return;
                final seg = WheelSegment(
                  id: existing?.id ?? 'w_${DateTime.now().millisecondsSinceEpoch}',
                  label: label,
                  emoji: selEmoji,
                  points: isPoints ? (int.tryParse(pointsCtrl.text.trim()) ?? 1) : null,
                  rewardText: isPoints ? null : (rewardCtrl.text.trim().isEmpty ? label : rewardCtrl.text.trim()),
                  color: selColor,
                );
                if (existing != null) {
                  fp.updateWheelSegment(seg);
                } else {
                  fp.addWheelSegment(seg);
                }
                Navigator.pop(ctx);
              },
              child: const Text('Enregistrer', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Painter de la roue 3D ─────────────────────────────────────
class _Wheel3DPainter extends CustomPainter {
  final List<WheelSegment> segments;
  _Wheel3DPainter({required this.segments});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final count = segments.length;
    final sweep = 2 * math.pi / count;

    for (int i = 0; i < count; i++) {
      final startAngle = i * sweep - math.pi / 2;
      final seg = segments[i];

      // Segment avec dégradé radial (effet 3D)
      final rect = Rect.fromCircle(center: center, radius: radius);
      final gradient = RadialGradient(
        colors: [seg.color.withValues(alpha: 0.9), seg.color],
        center: Alignment.center,
        radius: 1.0,
      );
      canvas.drawArc(rect, startAngle, sweep, true, Paint()..shader = gradient.createShader(rect));

      // Bordure entre segments
      canvas.drawArc(rect, startAngle, sweep, true,
        Paint()..color = Colors.white.withValues(alpha: 0.15)..style = PaintingStyle.stroke..strokeWidth = 1.5);

      // Emoji + label — lisibilité maximale
      final textAngle = startAngle + sweep / 2;
      final textRadius = radius * 0.68;
      final textOffset = Offset(
        center.dx + textRadius * math.cos(textAngle),
        center.dy + textRadius * math.sin(textAngle),
      );

      // Emoji (gros, avec ombre pour contraste)
      final emojiPainter = TextPainter(
        text: TextSpan(
          text: seg.emoji,
          style: const TextStyle(
            fontSize: 32,
            shadows: [Shadow(color: Colors.black54, blurRadius: 4)],
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      emojiPainter.layout();
      canvas.save();
      canvas.translate(textOffset.dx, textOffset.dy - 12);
      canvas.rotate(textAngle + math.pi / 2);
      emojiPainter.paint(canvas, Offset(-emojiPainter.width / 2, -emojiPainter.height / 2));
      canvas.restore();

      // Label (gros, blanc, gras, avec ombre noire pour lisibilité)
      final labelPainter = TextPainter(
        text: TextSpan(
          text: seg.label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.w900,
            shadows: [
              Shadow(color: Colors.black87, blurRadius: 3, offset: Offset(0, 1)),
              Shadow(color: Colors.black87, blurRadius: 2, offset: Offset(0, 0)),
            ],
          ),
        ),
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.center,
      );
      labelPainter.layout(maxWidth: 90);
      canvas.save();
      canvas.translate(textOffset.dx, textOffset.dy + 18);
      canvas.rotate(textAngle + math.pi / 2);
      labelPainter.paint(canvas, Offset(-labelPainter.width / 2, -labelPainter.height / 2));
      canvas.restore();
    }

    // Contour intérieur
    canvas.drawCircle(center, radius - 1,
      Paint()..color = Colors.white.withValues(alpha: 0.1)..style = PaintingStyle.stroke..strokeWidth = 2);
  }

  @override
  bool shouldRepaint(covariant _Wheel3DPainter old) => old.segments != segments;
}

// ─── Pointeur 3D ───────────────────────────────────────────────
class _PointerPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFFFFD700), Color(0xFFB8860B)],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..style = PaintingStyle.fill;

    final path = Path()
      ..moveTo(size.width / 2, size.height)
      ..lineTo(0, 0)
      ..lineTo(size.width, 0)
      ..close();

    canvas.drawPath(path, paint);
    canvas.drawPath(path, Paint()..color = const Color(0xFF8B6914)..style = PaintingStyle.stroke..strokeWidth = 1.5);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ─── Tile d'édition de segment ─────────────────────────────────
class _SegmentEditTile extends StatelessWidget {
  final WheelSegment segment;
  final VoidCallback onEdit;
  final VoidCallback? onDelete;

  const _SegmentEditTile({required this.segment, required this.onEdit, this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: EmeraldPalette.surfaceLow,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        leading: Container(
          width: 36, height: 36,
          decoration: BoxDecoration(shape: BoxShape.circle, color: segment.color),
          child: Center(child: Text(segment.emoji, style: const TextStyle(fontSize: 18))),
        ),
        title: Text(segment.label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
        subtitle: Text(
          segment.isPoints ? '+${segment.points} pts' : (segment.rewardText ?? ''),
          style: const TextStyle(color: Colors.white54, fontSize: 12),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(icon: const Icon(Icons.edit_rounded, color: EmeraldPalette.emeraldLight, size: 18), onPressed: onEdit),
            if (onDelete != null)
              IconButton(icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 18), onPressed: onDelete),
          ],
        ),
      ),
    );
  }
}
