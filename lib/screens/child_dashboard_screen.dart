// lib/screens/child_dashboard_screen.dart

import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';

import '../providers/family_provider.dart';
import '../providers/pin_provider.dart';
import '../models/child_model.dart';
import '../models/badge_model.dart';
import '../widgets/animated_background.dart';
import '../widgets/glass_card.dart';
import '../widgets/tv_focus_wrapper.dart';
import '../widgets/timeline_widget.dart';
import 'timeline_screen.dart';

// ─── Shimmer holographique ────────────────────────────────────
class _HoloPainter extends CustomPainter {
  final double animValue;
  final Color  baseColor;
  _HoloPainter({required this.animValue, required this.baseColor});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final gradient = LinearGradient(
      begin: Alignment((-1 + animValue * 2).clamp(-1.0, 1.0), -1),
      end:   Alignment((animValue * 2).clamp(-1.0, 1.0), 1),
      colors: const [
        Colors.transparent,
        Color(0x22FF0080),
        Color(0x33FF8C00),
        Color(0x2200E5FF),
        Color(0x2276FF03),
        Color(0x22FF0080),
        Colors.transparent,
      ],
      stops: const [0.0, 0.2, 0.35, 0.5, 0.65, 0.8, 1.0],
    );
    final paint = Paint()
      ..shader = gradient.createShader(rect)
      ..blendMode = BlendMode.screen;
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(20)),
      paint,
    );
    final starPaint = Paint()..color = Colors.white.withOpacity(0.12 * animValue);
    final rng = Random(42);
    for (int i = 0; i < 30; i++) {
      canvas.drawCircle(
        Offset(rng.nextDouble() * size.width, rng.nextDouble() * size.height),
        rng.nextDouble() * 2 + 0.5,
        starPaint,
      );
    }
  }

  @override
  bool shouldRepaint(_HoloPainter old) => old.animValue != animValue;
}

// ─── Arc screen-time ─────────────────────────────────────────
class _ScreenTimePainter extends CustomPainter {
  final double progress;
  final double animValue;
  _ScreenTimePainter({required this.progress, required this.animValue});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = min(size.width, size.height) / 2 - 8;
    canvas.drawCircle(center, radius,
        Paint()
          ..color = Colors.white10
          ..style = PaintingStyle.stroke
          ..strokeWidth = 10);
    final color = progress >= 1.0
        ? Colors.greenAccent
        : progress >= 0.5
            ? Colors.orangeAccent
            : Colors.redAccent;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -pi / 2, 2 * pi * progress * animValue, false,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 10
        ..strokeCap = StrokeCap.round,
    );
    final angle  = -pi / 2 + 2 * pi * progress * animValue;
    final dotPos = Offset(
      center.dx + radius * cos(angle),
      center.dy + radius * sin(angle),
    );
    canvas.drawCircle(dotPos, 6,  Paint()..color = color);
    canvas.drawCircle(dotPos, 10, Paint()..color = color.withOpacity(0.3));
  }

  @override
  bool shouldRepaint(_ScreenTimePainter old) =>
      old.progress != progress || old.animValue != animValue;
}

// ─────────────────────────────────────────────────────────────
//  MAIN WIDGET
// ─────────────────────────────────────────────────────────────
class ChildDashboardScreen extends StatefulWidget {
  // ✅ childId optionnel — compatibilité avec welcome_screen et dashboard_screen
  final String? childId;
  const ChildDashboardScreen({super.key, this.childId});

  @override
  State<ChildDashboardScreen> createState() => _ChildDashboardScreenState();
}

class _ChildDashboardScreenState extends State<ChildDashboardScreen>
    with TickerProviderStateMixin {

  late TabController       _tabController;
  late AnimationController _profileController;
  late AnimationController _contentController;
  late AnimationController _glowController;
  late AnimationController _headerController;
  late AnimationController _holoController;
  late AnimationController _streakController;
  late AnimationController _bonusFloatController;

  late Animation<double>   _profileFade;
  late Animation<double>   _contentFade;
  late Animation<double>   _glowAnim;
  late Animation<double>   _holoAnim;
  late Animation<double>   _streakBounce;
  late Animation<double>   _bonusFloatAnim;
  late Animation<double>   _bonusOpacity;

  String? _selectedChildId;
  String? _selectedDay;

  bool   _showBonusAnim = false;
  String _bonusAnimText = '';
  bool   _showHeroBack  = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);

    _profileController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900));
    _contentController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 700));
    _glowController = AnimationController(
        vsync: this, duration: const Duration(seconds: 2))
      ..repeat(reverse: true);
    _headerController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _holoController = AnimationController(
        vsync: this, duration: const Duration(seconds: 3))
      ..repeat();
    _streakController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 800))
      ..repeat(reverse: true);
    _bonusFloatController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1200));

    _profileFade = TweenSequence([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 40),
      TweenSequenceItem(tween: ConstantTween(1.0), weight: 60),
    ]).animate(_profileController);

    _contentFade  = CurvedAnimation(parent: _contentController, curve: Curves.easeIn);
    _glowAnim     = CurvedAnimation(parent: _glowController, curve: Curves.easeInOut);
    _holoAnim     = CurvedAnimation(parent: _holoController, curve: Curves.linear);
    _streakBounce = Tween(begin: 1.0, end: 1.18)
        .animate(CurvedAnimation(parent: _streakController, curve: Curves.easeInOut));
    _bonusFloatAnim = Tween(begin: 0.0, end: -60.0).animate(_bonusFloatController);
    _bonusOpacity = TweenSequence([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 20),
      TweenSequenceItem(tween: ConstantTween(1.0), weight: 60),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 20),
    ]).animate(_bonusFloatController);

    _profileController.forward();
    _contentController.forward();
    _headerController.forward();

    // ✅ Initialise avec le childId passé en paramètre si disponible
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final fp = context.read<FamilyProvider>();
      if (fp.children.isNotEmpty) {
        setState(() {
          if (widget.childId != null &&
              fp.children.any((c) => c.id == widget.childId)) {
            _selectedChildId = widget.childId;
          } else {
            _selectedChildId = fp.children.first.id;
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _profileController.dispose();
    _contentController.dispose();
    _glowController.dispose();
    _headerController.dispose();
    _holoController.dispose();
    _streakController.dispose();
    _bonusFloatController.dispose();
    super.dispose();
  }

  // ─── Couleur enfant ──────────────────────────────────────
  Color _childColor(ChildModel child) {
    if (child.accentColorHex != null) {
      try {
        return Color(int.parse(
            child.accentColorHex!.replaceFirst('#', '0xFF')));
      } catch (_) {}
    }
    const palette = [
      Colors.deepPurpleAccent,
      Colors.blueAccent,
      Color(0xFF00897B),
      Color(0xFFF57C00),
      Colors.pinkAccent,
      Color(0xFF00ACC1),
    ];
    return palette[child.name.codeUnitAt(0) % palette.length];
  }

  // ─── Rareté ──────────────────────────────────────────────
  String _rarityLabel(int level) {
    switch (level) {
      case 1:  return 'COMMUN';
      case 2:  return 'RARE';
      case 3:  return 'ÉPIQUE';
      case 4:  return 'LÉGENDAIRE';
      default: return 'MYTHIQUE ✨';
    }
  }

  List<Color> _rarityGradient(int level) {
    switch (level) {
      case 1:  return [const Color(0xFF607D8B), const Color(0xFF37474F)];
      case 2:  return [const Color(0xFF1565C0), const Color(0xFF0D47A1)];
      case 3:  return [const Color(0xFF6A1B9A), const Color(0xFF4A148C)];
      case 4:  return [const Color(0xFFE65100), const Color(0xFFBF360C)];
      default: return [const Color(0xFF00897B), const Color(0xFF004D40)];
    }
  }

  Color _frameColor(int level) {
    switch (level) {
      case 1:  return Colors.grey.shade400;
      case 2:  return const Color(0xFFCD7F32);
      case 3:  return const Color(0xFFC0C0C0);
      case 4:  return const Color(0xFFFFD700);
      default: return const Color(0xFF00E5FF);
    }
  }

  // ─── Avatar ──────────────────────────────────────────────
  Widget _buildAvatar(ChildModel child, double radius,
      {bool showFrame = true}) {
    final color     = _childColor(child);
    final frameColor = _frameColor(child.level);
    final highLevel = child.level >= 4;

    Widget core;
    if (child.photoBase64.isNotEmpty) {
      try {
        core = CircleAvatar(
          radius: radius,
          backgroundImage: MemoryImage(base64Decode(child.photoBase64)),
        );
      } catch (_) {
        core = _letterAvatar(child, radius, color);
      }
    } else {
      core = _letterAvatar(child, radius, color);
    }

    if (!showFrame || child.level < 2) return core;

    return AnimatedBuilder(
      animation: _glowAnim,
      builder: (_, __) => Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: highLevel
              ? SweepGradient(colors: [
                  frameColor, Colors.white, frameColor,
                  frameColor.withOpacity(0.5), frameColor,
                ])
              : null,
          color: highLevel ? null : frameColor,
          boxShadow: [
            BoxShadow(
              color: frameColor.withOpacity(0.4 + 0.3 * _glowAnim.value),
              blurRadius:   12 + 8 * _glowAnim.value,
              spreadRadius: 2  + 2 * _glowAnim.value,
            ),
          ],
        ),
        child: Container(
          padding: const EdgeInsets.all(2),
          decoration: const BoxDecoration(
              shape: BoxShape.circle, color: Color(0xFF1A1A2E)),
          child: core,
        ),
      ),
    );
  }

  Widget _letterAvatar(ChildModel child, double radius, Color color) =>
      CircleAvatar(
        radius: radius,
        backgroundColor: color.withOpacity(0.3),
        child: Text(
          child.name[0].toUpperCase(),
          style: TextStyle(
            fontSize:   radius * 0.9,
            fontWeight: FontWeight.bold,
            color:      color,
          ),
        ),
      );

  // ─── Hero Card ───────────────────────────────────────────
  Widget _buildHeroCard(ChildModel child, FamilyProvider fp) {
    final color    = _childColor(child);
    final gradient = _rarityGradient(child.level);
    final frame    = _frameColor(child.level);

    final history      = fp.history.where((h) => h.childId == child.id).toList();
    final bonuses      = history.where((h) => h.points > 0).length;
    final penalties    = history.where((h) => h.points < 0).length;
    final earnedBadges = fp.customBadges
        .where((b) => child.badgeIds.contains(b.id)).length;
    final totalImm     = fp.getTotalAvailableImmunity(child.id);

    return GestureDetector(
      onTap: () => setState(() => _showHeroBack = !_showHeroBack),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 500),
        transitionBuilder: (child, anim) => AnimatedBuilder(
          animation: anim,
          child: child,
          builder: (_, c) => Transform(
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.001)
              ..rotateY((1 - anim.value) * pi / 2),
            alignment: Alignment.center,
            child: c,
          ),
        ),
        child: _showHeroBack
            ? _cardBack(child, fp, gradient, frame, color)
            : _cardFront(child, gradient, frame, color,
                _rarityLabel(child.level),
                bonuses, penalties, earnedBadges, totalImm),
      ),
    );
  }

  Widget _cardFront(
    ChildModel child,
    List<Color> gradient,
    Color frame,
    Color color,
    String rarity,
    int bonuses,
    int penalties,
    int earnedBadges,
    int totalImm,
  ) {
    return AnimatedBuilder(
      key: const ValueKey('front'),
      animation: _holoAnim,
      builder: (_, __) => Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        height: 500,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end:   Alignment.bottomRight,
            colors: gradient,
          ),
          border: Border.all(color: frame, width: 2.5),
          boxShadow: [
            BoxShadow(color: frame.withOpacity(0.5),
                blurRadius: 20, spreadRadius: 2),
          ],
        ),
        child: Stack(
          children: [
            // Bannière
            if (child.bannerBase64 != null && child.bannerBase64!.isNotEmpty)
              Positioned.fill(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: Opacity(
                    opacity: 0.35,
                    child: Image.memory(
                      base64Decode(child.bannerBase64!),
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ),
            // Shimmer
            Positioned.fill(
              child: CustomPaint(
                painter: _HoloPainter(
                    animValue: _holoAnim.value, baseColor: color),
              ),
            ),
            // Contenu
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _chip(rarity, frame),
                      _chip('NIV.${child.level}  •  ${child.points} pts',
                          Colors.white24, textColor: frame),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Center(child: _buildAvatar(child, 72, showFrame: true)),
                  const SizedBox(height: 12),
                  Center(
                    child: Column(children: [
                      Text(
                        child.name.toUpperCase(),
                        style: TextStyle(
                          color: Colors.white, fontSize: 22,
                          fontWeight: FontWeight.w900, letterSpacing: 3,
                          shadows: [Shadow(color: frame, blurRadius: 8)],
                        ),
                      ),
                      if (child.sloganText != null &&
                          child.sloganText!.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            '"${child.sloganText}"',
                            style: const TextStyle(
                              color: Colors.white60, fontSize: 11,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                    ]),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.black38,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _statCell('🎯', 'BONUS',    '$bonuses',     color),
                        _divV(),
                        _statCell('⚡', 'PÉNALITÉS','$penalties',   Colors.redAccent),
                        _divV(),
                        _statCell('🛡️', 'IMMU.',   '$totalImm',    Colors.amberAccent),
                        _divV(),
                        _statCell('🏅', 'BADGES',  '$earnedBadges', Colors.greenAccent),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  _levelBar(child, frame),
                  const Spacer(),
                  Center(
                    child: Text('↻ Appuie pour le dos',
                        style: TextStyle(color: Colors.white38, fontSize: 10)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _cardBack(ChildModel child, FamilyProvider fp,
      List<Color> gradient, Color frame, Color color) {
    final history = fp.history
        .where((h) => h.childId == child.id)
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    final last5 = history.take(5).toList();

    return Container(
      key: const ValueKey('back'),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      height: 500,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment.bottomLeft,
          end:   Alignment.topRight,
          colors: gradient.reversed.toList(),
        ),
        border: Border.all(color: frame, width: 2.5),
        boxShadow: [
          BoxShadow(color: frame.withOpacity(0.4), blurRadius: 18),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Text(
                '📋 FICHE ${child.name.toUpperCase()}',
                style: TextStyle(
                  color: frame, fontWeight: FontWeight.w900,
                  letterSpacing: 2, fontSize: 14,
                ),
              ),
            ),
            const SizedBox(height: 16),
            _streakRow(child, frame),
            const SizedBox(height: 12),
            const Divider(color: Colors.white12),
            const SizedBox(height: 8),
            const Text('🕒 Dernières activités',
                style: TextStyle(color: Colors.white70,
                    fontSize: 12, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            ...last5.map((h) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(children: [
                Text(h.points > 0 ? '✅' : '❌',
                    style: const TextStyle(fontSize: 14)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(h.reason,
                      style: const TextStyle(
                          color: Colors.white70, fontSize: 11),
                      overflow: TextOverflow.ellipsis),
                ),
                Text(
                  '${h.points > 0 ? '+' : ''}${h.points}',
                  style: TextStyle(
                    color: h.points > 0
                        ? Colors.greenAccent : Colors.redAccent,
                    fontWeight: FontWeight.bold, fontSize: 12,
                  ),
                ),
              ]),
            )),
            const Spacer(),
            Center(
              child: Text('↻ Appuie pour le recto',
                  style: TextStyle(color: Colors.white38, fontSize: 10)),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Helpers widgets ─────────────────────────────────────
  Widget _chip(String text, Color bg, {Color? textColor}) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: bg.withOpacity(0.25),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: textColor ?? bg, width: 1),
    ),
    child: Text(text,
        style: TextStyle(
          color: textColor ?? Colors.white,
          fontWeight: FontWeight.w900,
          fontSize: 11, letterSpacing: 1.2,
        )),
  );

  Widget _statCell(String emoji, String label, String value, Color color) =>
      Column(mainAxisSize: MainAxisSize.min, children: [
        Text(emoji, style: const TextStyle(fontSize: 16)),
        const SizedBox(height: 2),
        Text(value, style: TextStyle(
            color: color, fontWeight: FontWeight.w900, fontSize: 16)),
        Text(label, style: const TextStyle(
            color: Colors.white54, fontSize: 8, letterSpacing: 0.5)),
      ]);

  Widget _divV() =>
      Container(height: 40, width: 1, color: Colors.white12);

  Widget _levelBar(ChildModel child, Color frame) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(child.levelTitle, style: const TextStyle(
            color: Colors.white60, fontSize: 10,
            fontWeight: FontWeight.w600)),
        Text('${(child.levelProgress * 100).toInt()}% → NIV.${child.level + 1}',
            style: const TextStyle(color: Colors.white38, fontSize: 10)),
      ]),
      const SizedBox(height: 4),
      ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: LinearProgressIndicator(
          value: child.levelProgress,
          backgroundColor: Colors.white12,
          valueColor: AlwaysStoppedAnimation(frame),
          minHeight: 5,
        ),
      ),
    ],
  );

  Widget _streakRow(ChildModel child, Color frame) {
    final streak = child.streakDays ?? 0;
    return AnimatedBuilder(
      animation: _streakBounce,
      builder: (_, __) => Row(children: [
        Transform.scale(
          scale: streak > 0 ? _streakBounce.value : 1.0,
          child: Text(streak > 0 ? '🔥' : '💤',
              style: const TextStyle(fontSize: 28)),
        ),
        const SizedBox(width: 10),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(
            streak > 0
                ? '$streak jour${streak > 1 ? 's' : ''} sans pénalité !'
                : 'Aucun streak actif',
            style: TextStyle(color: frame,
                fontWeight: FontWeight.w800, fontSize: 14),
          ),
          Text(
            streak >= 7
                ? '🏆 Badge streak débloqué !'
                : streak > 0
                    ? '${7 - streak} jour(s) pour le badge 🏆'
                    : 'Évite les pénalités pour démarrer',
            style: const TextStyle(color: Colors.white54, fontSize: 11),
          ),
        ]),
      ]),
    );
  }

  // ─── Sélecteur enfant ────────────────────────────────────
  void _showChildSwitcher(FamilyProvider fp) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A2E),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.all(16),
        children: [
          const Text('Choisir un enfant',
              style: TextStyle(color: Colors.white,
                  fontSize: 16, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center),
          const SizedBox(height: 12),
          ...fp.children.map((c) => ListTile(
            leading:  _buildAvatar(c, 22, showFrame: false),
            title:    Text(c.name,
                style: const TextStyle(color: Colors.white)),
            subtitle: Text('${c.points} pts',
                style: const TextStyle(color: Colors.white54)),
            trailing: c.id == _selectedChildId
                ? const Icon(Icons.check_circle, color: Colors.greenAccent)
                : null,
            onTap: () {
              setState(() => _selectedChildId = c.id);
              Navigator.pop(context);
            },
          )),
        ],
      ),
    );
  }

  // ─── Édition photo ───────────────────────────────────────
  Future<void> _editPhoto(ChildModel child, FamilyProvider fp) async {
    final picker = ImagePicker();
    final xfile  = await picker.pickImage(
        source: ImageSource.gallery, imageQuality: 80, maxWidth: 600);
    if (xfile == null) return;
    final bytes = await xfile.readAsBytes();
    await fp.updateChildPhoto(child.id, base64Encode(bytes));
    if (mounted) setState(() {});
  }

  // ─── Édition bannière ────────────────────────────────────
  Future<void> _editBanner(ChildModel child, FamilyProvider fp,
      {required bool requirePin}) async {
    if (requirePin) {
      final pin = context.read<PinProvider>();
      bool ok   = false;
      await showDialog(
        context: context,
        builder: (ctx) {
          final ctrl = TextEditingController();
          return AlertDialog(
            backgroundColor: const Color(0xFF1A1A2E),
            title: const Text('PIN parent',
                style: TextStyle(color: Colors.white)),
            content: TextField(
              controller:   ctrl,
              obscureText:  true,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText:  'Code PIN',
                labelStyle: TextStyle(color: Colors.white54),
              ),
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Annuler')),
              ElevatedButton(
                onPressed: () {
                  // ✅ verifyPin() — nom exact dans PinProvider
                  if (pin.verifyPin(ctrl.text)) {
                    ok = true;
                    Navigator.pop(ctx);
                  } else {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      const SnackBar(content: Text('PIN incorrect ❌')),
                    );
                  }
                },
                child: const Text('Valider'),
              ),
            ],
          );
        },
      );
      if (!ok) return;
    }
    final picker = ImagePicker();
    final xfile  = await picker.pickImage(
        source: ImageSource.gallery, imageQuality: 70, maxWidth: 1200);
    if (xfile == null) return;
    final bytes = await xfile.readAsBytes();
    // ✅ updateChildBanner() — méthode ajoutée dans family_provider.dart
    await fp.updateChildBanner(child.id, base64Encode(bytes));
    if (mounted) setState(() {});
  }

  // ─────────────────────────────────────────────────────────
  //  BUILD
  // ─────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Consumer<FamilyProvider>(
      builder: (context, fp, _) {
        final children = fp.children;
        if (children.isEmpty) {
          return const Scaffold(
            backgroundColor: Color(0xFF0F0F1E),
            body: Center(child: Text('Aucun enfant',
                style: TextStyle(color: Colors.white54))),
          );
        }

        if (_selectedChildId == null ||
            !children.any((c) => c.id == _selectedChildId)) {
          _selectedChildId = children.first.id;
        }

        final child = children.firstWhere((c) => c.id == _selectedChildId);
        final color = _childColor(child);

        return Scaffold(
          backgroundColor: const Color(0xFF0F0F1E),
          extendBodyBehindAppBar: true,
          appBar: AppBar(
            backgroundColor:  Colors.transparent,
            elevation:        0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white70),
              onPressed: () => Navigator.pop(context),
            ),
            title: Row(children: [
              _buildAvatar(child, 16, showFrame: false),
              const SizedBox(width: 8),
              Text(child.name,
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold)),
            ]),
            actions: [
              if (children.length > 1)
                TextButton.icon(
                  onPressed: () => _showChildSwitcher(fp),
                  icon:  const Icon(Icons.swap_horiz,
                      color: Colors.white70, size: 18),
                  label: const Text('Changer',
                      style: TextStyle(color: Colors.white70)),
                ),
            ],
            bottom: TabBar(
              controller:           _tabController,
              indicatorColor:       color,
              labelColor:           color,
              unselectedLabelColor: Colors.white38,
              tabs: const [
                Tab(icon: Icon(Icons.person),       text: 'Profil'),
                Tab(icon: Icon(Icons.tv),            text: 'Écran'),
                Tab(icon: Icon(Icons.history),       text: 'Historique'),
                Tab(icon: Icon(Icons.emoji_events),  text: 'Badges'),
              ],
            ),
          ),
          body: AnimatedBackground(
            child: FadeTransition(
              opacity: _contentFade,
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildProfileTab(child, fp, color),
                  _buildScreenTab(child, fp, color),
                  _buildHistoryTab(child, fp, color),
                  _buildBadgesTab(child, fp, color),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ─── TAB PROFIL ──────────────────────────────────────────
  Widget _buildProfileTab(ChildModel child, FamilyProvider fp, Color color) {
    return SingleChildScrollView(
      padding: const EdgeInsets.only(top: 120, bottom: 24),
      child: Column(children: [
        _buildHeroCard(child, fp),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(children: [
            Expanded(
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: color,
                  side: BorderSide(color: color.withOpacity(0.5)),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () => _editPhoto(child, fp),
                icon:  const Icon(Icons.camera_alt, size: 16),
                label: const Text('Photo', style: TextStyle(fontSize: 12)),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: _frameColor(child.level),
                  side: BorderSide(
                      color: _frameColor(child.level).withOpacity(0.5)),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () => _editBanner(child, fp, requirePin: false),
                icon:  const Icon(Icons.image, size: 16),
                label: const Text('Bannière 🖼️',
                    style: TextStyle(fontSize: 11)),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white54,
                  side: const BorderSide(color: Colors.white24),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () => _editBanner(child, fp, requirePin: true),
                icon:  const Icon(Icons.lock, size: 16),
                label: const Text('Bannière 🔒',
                    style: TextStyle(fontSize: 11)),
              ),
            ),
          ]),
        ),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: _buildStatsGrid(child, fp, color),
        ),
      ]),
    );
  }

  Widget _buildStatsGrid(ChildModel child, FamilyProvider fp, Color color) {
    final history   = fp.history.where((h) => h.childId == child.id).toList();
    final bonuses   = history.where((h) => h.points > 0).length;
    final penalties = history.where((h) => h.points < 0).length;
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      childAspectRatio: 1.6,
      children: [
        _statCard('🎯', 'Bonus',     '$bonuses',    Colors.greenAccent),
        _statCard('⚡', 'Pénalités', '$penalties',  Colors.redAccent),
        _statCard('🏆', 'Niveau',
            '${child.level} – ${child.levelTitle}', color),
        _statCard('🛡️', 'Immunités',
            '${fp.getTotalAvailableImmunity(child.id)} lignes',
            Colors.amberAccent),
      ],
    );
  }

  Widget _statCard(String emoji, String label, String value, Color color) =>
      GlassCard(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text(emoji, style: const TextStyle(fontSize: 22)),
          const SizedBox(height: 4),
          Text(value, style: TextStyle(
              color: color, fontWeight: FontWeight.bold, fontSize: 13)),
          Text(label, style: const TextStyle(
              color: Colors.white54, fontSize: 10)),
        ]),
      );

  // ─── TAB ÉCRAN ───────────────────────────────────────────
  Widget _buildScreenTab(ChildModel child, FamilyProvider fp, Color color) {
    final schoolNotes   = _getSchoolNotes(child, fp);
    final behaviorNotes = _getBehaviorNotes(child, fp);
    final immunities    = fp.getUsableImmunitiesForChild(child.id);
    final immunityBonus = immunities.fold(0, (s, i) => s + i.availableLines);
    final bonusMinutes  = fp.getParentBonusMinutes(child.id);

    final jours = ['Lundi','Mardi','Mercredi','Jeudi','Vendredi',
        'Samedi','Dimanche'];
    _selectedDay ??= jours[DateTime.now().weekday - 1];

    final minutes = _calculerTempsEcranPourJour(
        _selectedDay!, schoolNotes, behaviorNotes, bonusMinutes, child, fp);

    return SingleChildScrollView(
      padding: const EdgeInsets.only(
          top: 120, bottom: 24, left: 16, right: 16),
      child: Column(children: [
        GlassCard(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              Text('📊 Résumé de la semaine',
                  style: TextStyle(color: color,
                      fontWeight: FontWeight.bold, fontSize: 14)),
              const SizedBox(height: 8),
              _infoRow('🛡️ Immunités',
                  '$immunityBonus lignes', Colors.amberAccent),
              _infoRow('⏱️ Bonus parent',
                  '${bonusMinutes > 0 ? '+' : ''}$bonusMinutes min',
                  Colors.greenAccent),
              _infoRow('📅 Jour', _selectedDay!, color),
              _infoRow('⏰ Temps calculé',
                  _formatMinutes(minutes), Colors.white),
            ]),
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 36,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: jours.length,
            separatorBuilder: (_, __) => const SizedBox(width: 6),
            itemBuilder: (_, i) {
              final j        = jours[i];
              final selected = j == _selectedDay;
              return GestureDetector(
                onTap: () => setState(() => _selectedDay = j),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: selected
                        ? color.withOpacity(0.25)
                        : Colors.white10,
                    borderRadius: BorderRadius.circular(10),
                    border: selected ? Border.all(color: color) : null,
                  ),
                  child: Text(j.substring(0, 3),
                      style: TextStyle(
                        color: selected ? color : Colors.white54,
                        fontWeight: selected
                            ? FontWeight.bold : FontWeight.normal,
                        fontSize: 12,
                      )),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 20),
        SizedBox(
          height: 200,
          child: Stack(
            alignment: Alignment.center,
            children: [
              AnimatedBuilder(
                animation: _contentFade,
                builder: (_, __) => CustomPaint(
                  size: const Size(180, 180),
                  painter: _ScreenTimePainter(
                    progress:  (minutes / 180).clamp(0, 1),
                    animValue: _contentFade.value,
                  ),
                ),
              ),
              Column(mainAxisSize: MainAxisSize.min, children: [
                Text(_formatMinutes(minutes),
                    style: const TextStyle(color: Colors.white,
                        fontWeight: FontWeight.w900, fontSize: 28)),
                const Text('temps écran',
                    style: TextStyle(color: Colors.white54, fontSize: 12)),
              ]),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _buildQuickBonusRow(child, fp, color),
      ]),
    );
  }

  Widget _infoRow(String label, String value, Color vColor) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(
                color: Colors.white60, fontSize: 12)),
            Text(value, style: TextStyle(
                color: vColor, fontWeight: FontWeight.bold, fontSize: 12)),
          ],
        ),
      );

  Widget _buildQuickBonusRow(
      ChildModel child, FamilyProvider fp, Color color) =>
      Row(
        children: [15, 30, 60].map((min) => Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: color.withOpacity(0.2),
                foregroundColor: color,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () async {
                await fp.addScreenTimeBonus(
                    child.id, min, 'Bonus parent +$min min');
                _triggerBonusAnim('+$min min 🎉');
              },
              child: Text('+$min min',
                  style: const TextStyle(fontSize: 12)),
            ),
          ),
        )).toList(),
      );

  void _triggerBonusAnim(String text) {
    setState(() { _showBonusAnim = true; _bonusAnimText = text; });
    _bonusFloatController.forward(from: 0).then((_) {
      if (mounted) setState(() => _showBonusAnim = false);
    });
  }

  // ─── TAB HISTORIQUE ──────────────────────────────────────
  Widget _buildHistoryTab(ChildModel child, FamilyProvider fp, Color color) {
    final history   = fp.history.where((h) => h.childId == child.id).toList();
    final bonuses   = history.where((h) => h.points > 0).length;
    final penalties = history.where((h) => h.points < 0).length;

    // ✅ TimelineWidget prend entries (pas childId)
    final entries = fp.getHistoryForChild(child.id);

    return SingleChildScrollView(
      padding: const EdgeInsets.only(
          top: 120, bottom: 24, left: 16, right: 16),
      child: Column(children: [
        Row(children: [
          Expanded(child: _statCard('✅', 'Bonus',
              '$bonuses', Colors.greenAccent)),
          const SizedBox(width: 10),
          Expanded(child: _statCard('❌', 'Pénalités',
              '$penalties', Colors.redAccent)),
        ]),
        const SizedBox(height: 16),
        SizedBox(
          height: 400,
          child: TimelineWidget(
            entries: entries.take(10).toList(),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: color,
              side: BorderSide(color: color.withOpacity(0.5)),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            // ✅ TimelineScreen prend initialChildId (pas childId)
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) =>
                  TimelineScreen(initialChildId: child.id)),
            ),
            icon:  const Icon(Icons.open_in_new, size: 16),
            label: const Text('Voir tout l\'historique'),
          ),
        ),
      ]),
    );
  }

  // ─── TAB BADGES ──────────────────────────────────────────
  Widget _buildBadgesTab(ChildModel child, FamilyProvider fp, Color color) {
    final all    = fp.customBadges;
    final earned = all.where((b) => child.badgeIds.contains(b.id)).toList();
    final locked = all.where((b) => !child.badgeIds.contains(b.id)).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.only(
          top: 120, bottom: 24, left: 16, right: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('🏅 Badges obtenus (${earned.length})',
              style: TextStyle(color: color,
                  fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 10),
          if (earned.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(child: Text('Aucun badge encore obtenu',
                  style: TextStyle(color: Colors.white38))),
            )
          else
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate:
                  const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3, crossAxisSpacing: 10,
                mainAxisSpacing: 10, childAspectRatio: 0.9,
              ),
              itemCount: earned.length,
              itemBuilder: (_, i) => _badgeEarnedCard(earned[i], color),
            ),
          const SizedBox(height: 20),
          Text('🔒 Badges à débloquer (${locked.length})',
              style: const TextStyle(color: Colors.white54,
                  fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 10),
          ...locked.map((b) => _badgeLockedTile(b, child)),
        ],
      ),
    );
  }

  Widget _badgeEarnedCard(BadgeModel badge, Color color) =>
      GlassCard(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text(badge.powerEmoji, style: const TextStyle(fontSize: 28)),
          const SizedBox(height: 4),
          Text(badge.name,
              style: const TextStyle(color: Colors.white,
                  fontWeight: FontWeight.bold, fontSize: 11),
              textAlign: TextAlign.center,
              maxLines: 2, overflow: TextOverflow.ellipsis),
        ]),
      );

  Widget _badgeLockedTile(BadgeModel badge, ChildModel child) {
    final progress = (child.points / badge.requiredPoints).clamp(0.0, 1.0);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(children: [
        Container(
          width: 52, height: 52,
          decoration: BoxDecoration(
            color: Colors.white10,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Center(child: Text(badge.powerEmoji,
              style: const TextStyle(fontSize: 24))),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(badge.name, style: const TextStyle(
                color: Colors.white70,
                fontWeight: FontWeight.bold, fontSize: 13)),
            Text(badge.description, style: const TextStyle(
                color: Colors.white38, fontSize: 11),
                maxLines: 1, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 6),
            LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.white12,
              valueColor: const AlwaysStoppedAnimation(Colors.amberAccent),
              minHeight: 5,
              borderRadius: BorderRadius.circular(4),
            ),
            const SizedBox(height: 2),
            Text('${child.points}/${badge.requiredPoints} pts',
                style: const TextStyle(color: Colors.white38, fontSize: 10)),
          ]),
        ),
      ]),
    );
  }

  // ─── Helpers calcul temps écran ──────────────────────────
  String _formatMinutes(int minutes) {
    if (minutes <= 0) return '0 min';
    final h = minutes ~/ 60;
    final m = minutes % 60;
    if (h == 0) return '${m}min';
    if (m == 0) return '${h}h';
    return '${h}h${m.toString().padLeft(2, '0')}';
  }

  List<Map<String, dynamic>> _getSchoolNotes(
      ChildModel child, FamilyProvider fp) =>
      fp.history
          .where((h) => h.childId == child.id &&
              h.category == 'school_note')
          .map((h) => {'note': h.points.toDouble(), 'reason': h.reason})
          .toList();

  List<Map<String, dynamic>> _getBehaviorNotes(
      ChildModel child, FamilyProvider fp) =>
      fp.history
          .where((h) => h.childId == child.id &&
              h.category != 'school_note' &&
              h.category != 'screen_time_bonus')
          .take(10)
          .map((h) => {'points': h.points, 'reason': h.reason})
          .toList();

  int _calculerTempsEcranPourJour(
    String jour,
    List<Map<String, dynamic>> schoolNotes,
    List<Map<String, dynamic>> behaviorNotes,
    int bonusMinutes,
    ChildModel child,
    FamilyProvider fp,
  ) {
    final isWeekend = jour == 'Samedi' || jour == 'Dimanche';
    int base        = isWeekend ? 120 : 60;

    if (behaviorNotes.isNotEmpty) {
      final avg = behaviorNotes.fold(
              0, (s, n) => s + (n['points'] as int)) /
          behaviorNotes.length;
      if (avg > 0) base += 15;
      if (avg < 0) base -= 15;
    }
    if (schoolNotes.isNotEmpty) {
      final avg = schoolNotes.fold(
              0.0, (s, n) => s + (n['note'] as double)) /
          schoolNotes.length;
      if (avg >= 15)     base += 20;
      else if (avg < 10) base -= 20;
    }

    base += bonusMinutes;
    base += fp.getTotalAvailableImmunity(child.id) * 5;
    return base.clamp(0, 300);
  }
}
