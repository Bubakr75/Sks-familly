// lib/screens/child_dashboard_screen.dart

import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../providers/family_provider.dart';
import '../providers/pin_provider.dart';
import '../models/child_model.dart';
import '../models/badge_model.dart';
import '../models/history_entry.dart';
import '../widgets/animated_background.dart';
import '../widgets/glass_card.dart';
import '../widgets/timeline_widget.dart';
import 'timeline_screen.dart';

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
      -pi / 2,
      2 * pi * progress * animValue,
      false,
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

// ─── Modèle badge personnalisé local ─────────────────────────
class _CustomBadgeItem {
  String emoji;
  String label;
  _CustomBadgeItem({required this.emoji, required this.label});
}

// ─────────────────────────────────────────────────────────────
//  MAIN WIDGET
// ─────────────────────────────────────────────────────────────
class ChildDashboardScreen extends StatefulWidget {
  final String? childId;
  const ChildDashboardScreen({super.key, this.childId});

  @override
  State<ChildDashboardScreen> createState() => _ChildDashboardScreenState();
}

class _ChildDashboardScreenState extends State<ChildDashboardScreen>
    with TickerProviderStateMixin {

  late TabController       _tabController;
  late AnimationController _contentController;
  late AnimationController _glowController;
  late AnimationController _bonusFloatController;

  late Animation<double> _contentFade;
  late Animation<double> _glowAnim;
  late Animation<double> _bonusFloatAnim;
  late Animation<double> _bonusOpacity;

  String? _selectedChildId;
  String? _selectedDay;

  String _historyFilter = 'Tout';
  static const _historyFilters = [
    'Tout', 'Bonus', 'Punition', 'Immunité', 'Tribunal', 'École', 'Échange',
  ];

  Set<int> _joursSources = {0, 1, 2, 3, 4};

  bool   _showBonusAnim = false;
  String _bonusAnimText = '';

  List<_CustomBadgeItem> _customLocalBadges    = [];
  List<String>           _hiddenDefaultBadgeIds = [];

  static const _joursNoms = [
    'Lundi','Mardi','Mercredi','Jeudi','Vendredi','Samedi','Dimanche'
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);

    _contentController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 700));
    _glowController = AnimationController(
        vsync: this, duration: const Duration(seconds: 2))
      ..repeat(reverse: true);
    _bonusFloatController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1200));

    _contentFade = CurvedAnimation(
        parent: _contentController, curve: Curves.easeIn);
    _glowAnim = CurvedAnimation(
        parent: _glowController, curve: Curves.easeInOut);
    _bonusFloatAnim =
        Tween(begin: 0.0, end: -60.0).animate(_bonusFloatController);
    _bonusOpacity = TweenSequence([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 20),
      TweenSequenceItem(tween: ConstantTween(1.0),           weight: 60),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 20),
    ]).animate(_bonusFloatController);

    _contentController.forward();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final fp = context.read<FamilyProvider>();
      if (fp.children.isNotEmpty) {
        final id = (widget.childId != null &&
                fp.children.any((c) => c.id == widget.childId))
            ? widget.childId!
            : fp.children.first.id;
        setState(() => _selectedChildId = id);
        _loadPrefs(id);
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _contentController.dispose();
    _glowController.dispose();
    _bonusFloatController.dispose();
    super.dispose();
  }

  // ─── Prefs ───────────────────────────────────────────────
  Future<void> _loadPrefs(String childId) async {
    final prefs  = await SharedPreferences.getInstance();
    final raw    = prefs.getStringList('custom_badges_$childId') ?? [];
    final hidden = prefs.getStringList('hidden_badges_$childId') ?? [];
    setState(() {
      _customLocalBadges = raw.map((s) {
        final parts = s.split('||');
        return _CustomBadgeItem(
          emoji: parts.isNotEmpty ? parts[0] : '⭐',
          label: parts.length > 1 ? parts[1] : s,
        );
      }).toList();
      _hiddenDefaultBadgeIds = hidden;
    });
  }

  Future<void> _saveCustomBadges(String childId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      'custom_badges_$childId',
      _customLocalBadges.map((b) => '${b.emoji}||${b.label}').toList(),
    );
  }

  Future<void> _saveHiddenBadges(String childId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('hidden_badges_$childId', _hiddenDefaultBadgeIds);
  }

  // ─── Badges perso ────────────────────────────────────────
  Future<void> _addCustomBadge(String childId) async {
    final emojiCtrl = TextEditingController();
    final labelCtrl = TextEditingController();
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        title: const Text('Ajouter un badge',
            style: TextStyle(color: Colors.white)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text(
            '💡 Appuie sur le champ émoji et utilise le clavier de ton téléphone',
            style: TextStyle(color: Colors.white54, fontSize: 11),
          ),
          const SizedBox(height: 12),
          TextField(
            controller:   emojiCtrl,
            style:        const TextStyle(color: Colors.white, fontSize: 30),
            textAlign:    TextAlign.center,
            keyboardType: TextInputType.text,
            decoration: InputDecoration(
              labelText:  'Émoji',
              labelStyle: const TextStyle(color: Colors.white54),
              hintText:   '🏆',
              hintStyle:  const TextStyle(color: Colors.white24),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Colors.white24)),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Colors.deepPurpleAccent)),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: labelCtrl,
            style:      const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              labelText:  'Nom du badge',
              labelStyle: const TextStyle(color: Colors.white54),
              hintText:   'ex : Super lecteur',
              hintStyle:  const TextStyle(color: Colors.white24),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Colors.white24)),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Colors.deepPurpleAccent)),
            ),
          ),
        ]),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Annuler',
                  style: TextStyle(color: Colors.white54))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurpleAccent),
            onPressed: () {
              final e = emojiCtrl.text.trim();
              final l = labelCtrl.text.trim();
              if (l.isNotEmpty) {
                setState(() => _customLocalBadges.add(
                    _CustomBadgeItem(emoji: e.isEmpty ? '⭐' : e, label: l)));
                _saveCustomBadges(childId);
              }
              Navigator.pop(ctx);
            },
            child: const Text('Ajouter'),
          ),
        ],
      ),
    );
  }

  void _removeCustomBadge(int index, String childId) {
    setState(() => _customLocalBadges.removeAt(index));
    _saveCustomBadges(childId);
  }

  Future<void> _hideDefaultBadge(String badgeId, String childId) async {
    setState(() => _hiddenDefaultBadgeIds.add(badgeId));
    await _saveHiddenBadges(childId);
  }

  Future<void> _resetHiddenBadges(String childId) async {
    setState(() => _hiddenDefaultBadgeIds = []);
    await _saveHiddenBadges(childId);
  }

  // ─── Couleurs ────────────────────────────────────────────
  Color _childColor(ChildModel child) {
    if (child.accentColorHex != null) {
      try {
        return Color(int.parse(child.accentColorHex!.replaceFirst('#', '0xFF')));
      } catch (_) {}
    }
    const palette = [
      Colors.deepPurpleAccent, Colors.blueAccent,
      Color(0xFF00897B),        Color(0xFFF57C00),
      Colors.pinkAccent,        Color(0xFF00ACC1),
    ];
    return palette[child.name.codeUnitAt(0) % palette.length];
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

  Color _categoryColor(HistoryEntry e) {
    final cat = e.category.toLowerCase();
    if (cat.contains('punition') || cat.contains('penalty')) return Colors.redAccent;
    if (cat.contains('immunité') || cat.contains('immunity')) return Colors.amberAccent;
    if (cat.contains('tribunal') || cat.contains('verdict')) return Colors.purpleAccent;
    if (cat.contains('school') || cat.contains('école') || cat.contains('note')) return Colors.blueAccent;
    if (cat.contains('échange') || cat.contains('trade')) return Colors.tealAccent;
    if (cat.contains('screen')) return Colors.cyanAccent;
    if (e.isBonus) return Colors.greenAccent;
    return Colors.redAccent;
  }

  String _categoryEmoji(HistoryEntry e) {
    final cat = e.category.toLowerCase();
    if (cat.contains('punition')) return '📝';
    if (cat.contains('immunité')) return '🛡️';
    if (cat.contains('tribunal') || cat.contains('verdict')) return '⚖️';
    if (cat.contains('school') || cat.contains('note')) return '📚';
    if (cat.contains('échange') || cat.contains('trade')) return '🔄';
    if (cat.contains('screen')) return '📺';
    if (e.isBonus) return '✅';
    return '❌';
  }

  // ─── Avatar ──────────────────────────────────────────────
  Widget _buildAvatar(ChildModel child, double radius,
      {bool showFrame = true}) {
    final color      = _childColor(child);
    final frameColor = _frameColor(child.level);
    final highLevel  = child.level >= 4;

    Widget core;
    if (child.photoBase64.isNotEmpty) {
      try {
        core = CircleAvatar(
            radius: radius,
            backgroundImage: MemoryImage(base64Decode(child.photoBase64)));
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
              color:        frameColor.withOpacity(0.4 + 0.3 * _glowAnim.value),
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
        child: Text(child.name[0].toUpperCase(),
            style: TextStyle(
                fontSize:   radius * 0.9,
                fontWeight: FontWeight.bold,
                color:      color)),
      );

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
              style: TextStyle(
                  color: Colors.white, fontSize: 16,
                  fontWeight: FontWeight.bold),
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
              _loadPrefs(c.id);
            },
          )),
        ],
      ),
    );
  }

  // ─── Edition photo / bannière / slogan ───────────────────
  Future<void> _editPhoto(ChildModel child, FamilyProvider fp) async {
    final xfile = await ImagePicker().pickImage(
        source: ImageSource.gallery, imageQuality: 80, maxWidth: 600);
    if (xfile == null) return;
    final bytes = await xfile.readAsBytes();
    await fp.updateChildPhoto(child.id, base64Encode(bytes));
    if (mounted) setState(() {});
  }

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
                  if (pin.verifyPin(ctrl.text)) {
                    ok = true;
                    Navigator.pop(ctx);
                  } else {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                        const SnackBar(content: Text('PIN incorrect ❌')));
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
    final xfile = await ImagePicker().pickImage(
        source: ImageSource.gallery, imageQuality: 70, maxWidth: 1200);
    if (xfile == null) return;
    final bytes = await xfile.readAsBytes();
    await fp.updateChildBanner(child.id, base64Encode(bytes));
    if (mounted) setState(() {});
  }

  Future<void> _editSlogan(ChildModel child, FamilyProvider fp) async {
    final ctrl = TextEditingController(text: child.sloganText ?? '');
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        title: const Text('Modifier le slogan',
            style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: ctrl,
          style:      const TextStyle(color: Colors.white),
          maxLength:  60,
          decoration: const InputDecoration(
            labelText:    'Slogan',
            labelStyle:   TextStyle(color: Colors.white54),
            counterStyle: TextStyle(color: Colors.white38),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () async {
              await fp.updateChildSlogan(child.id, ctrl.text.trim());
              if (mounted) setState(() {});
              Navigator.pop(ctx);
            },
            child: const Text('Sauvegarder'),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────
  //  BUILD
  // ─────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Consumer<FamilyProvider>(builder: (context, fp, _) {
      final children = fp.children;
      if (children.isEmpty) {
        return const Scaffold(
          backgroundColor: Color(0xFF0F0F1E),
          body: Center(
              child: Text('Aucun enfant',
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
        backgroundColor:        const Color(0xFF0F0F1E),
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation:       0,
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
                icon:  const Icon(Icons.swap_horiz, color: Colors.white70, size: 18),
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
              Tab(icon: Icon(Icons.person),      text: 'Profil'),
              Tab(icon: Icon(Icons.tv),           text: 'Écran'),
              Tab(icon: Icon(Icons.history),      text: 'Historique'),
              Tab(icon: Icon(Icons.emoji_events), text: 'Badges'),
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
    });
  }

  // ════════════════════════════════════════════════════════
  //  TAB PROFIL
  // ════════════════════════════════════════════════════════
  Widget _buildProfileTab(ChildModel child, FamilyProvider fp, Color color) {
    final frame = _frameColor(child.level);
    return SingleChildScrollView(
      padding: const EdgeInsets.only(top: 120, bottom: 24),
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: GlassCard(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(children: [

                // ══════════════════════════════════════════
                // BANNIÈRE — pleine largeur, 200 px, centrée
                // ══════════════════════════════════════════
                if (child.bannerBase64 != null &&
                    child.bannerBase64!.isNotEmpty) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: SizedBox(
                      height: 200,               // ← PLUS GRANDE (100 → 200)
                      width:  double.infinity,
                      child: Image.memory(
                        base64Decode(child.bannerBase64!),
                        fit:       BoxFit.cover,
                        alignment: Alignment.center, // ← CENTRÉ SUR LE VISAGE
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                _buildAvatar(child, 52, showFrame: true),
                const SizedBox(height: 12),
                Text(child.name,
                    style: const TextStyle(
                        color: Colors.white, fontSize: 22,
                        fontWeight: FontWeight.bold)),
                if (child.sloganText != null && child.sloganText!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text('"${child.sloganText}"',
                        style: const TextStyle(
                            color: Colors.white60, fontSize: 12,
                            fontStyle: FontStyle.italic)),
                  ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(child.levelTitle,
                        style: TextStyle(
                            color: frame, fontWeight: FontWeight.bold,
                            fontSize: 13)),
                    Text('${child.points} pts',
                        style: const TextStyle(
                            color: Colors.white54, fontSize: 12)),
                  ],
                ),
                const SizedBox(height: 6),
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: frame.withOpacity(0.5)),
                    color: Colors.white10,
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(7),
                    child: LinearProgressIndicator(
                      value:           child.levelProgress,
                      backgroundColor: Colors.transparent,
                      valueColor:      AlwaysStoppedAnimation(frame),
                      minHeight:       18,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    '${(child.levelProgress * 100).toInt()}% → NIV.${child.level + 1}',
                    style: const TextStyle(color: Colors.white38, fontSize: 10),
                  ),
                ),
              ]),
            ),
          ),
        ),

        const SizedBox(height: 12),
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
                  foregroundColor: frame,
                  side: BorderSide(color: frame.withOpacity(0.5)),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () => _editBanner(child, fp, requirePin: false),
                icon:  const Icon(Icons.image, size: 16),
                label: const Text('Bannière 🖼️', style: TextStyle(fontSize: 11)),
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
                label: const Text('Bannière 🔒', style: TextStyle(fontSize: 11)),
              ),
            ),
          ]),
        ),

        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white54,
                side: const BorderSide(color: Colors.white24),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () => _editSlogan(child, fp),
              icon:  const Icon(Icons.edit, size: 16),
              label: const Text('Modifier le slogan',
                  style: TextStyle(fontSize: 12)),
            ),
          ),
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
    final bonuses   = history.where((h) => h.isBonus).length;
    final penalties = history.where((h) => !h.isBonus).length;
    return GridView.count(
      shrinkWrap:        true,
      physics:           const NeverScrollableScrollPhysics(),
      crossAxisCount:    2,
      crossAxisSpacing:  10,
      mainAxisSpacing:   10,
      childAspectRatio:  1.6,
      children: [
        _statCard('🎯', 'Bonus',     '$bonuses',   Colors.greenAccent),
        _statCard('⚡', 'Pénalités', '$penalties', Colors.redAccent),
        _statCard('🏆', 'Niveau',    '${child.level} – ${child.levelTitle}', color),
        _statCard('🛡️', 'Immunités',
            '${fp.getTotalAvailableImmunity(child.id)} lignes',
            Colors.amberAccent),
      ],
    );
  }

  Widget _statCard(String emoji, String label, String value, Color color) =>
      GlassCard(
        child: Column(
            mainAxisAlignment: MainAxisAlignment.center, children: [
          Text(emoji, style: const TextStyle(fontSize: 22)),
          const SizedBox(height: 4),
          Text(value,
              style: TextStyle(
                  color: color, fontWeight: FontWeight.bold, fontSize: 13)),
          Text(label,
              style: const TextStyle(color: Colors.white54, fontSize: 10)),
        ]),
      );

  // ════════════════════════════════════════════════════════
  //  TAB ÉCRAN
  // ════════════════════════════════════════════════════════
  Widget _buildScreenTab(ChildModel child, FamilyProvider fp, Color color) {
    final immunities    = fp.getUsableImmunitiesForChild(child.id);
    final immunityBonus = immunities.fold(0, (s, i) => s + i.availableLines);
    final bonusMinutes  = fp.getParentBonusMinutes(child.id);

    _selectedDay ??= _joursNoms[DateTime.now().weekday - 1];

    final schoolNotes   = _getSchoolNotes(child, fp);
    final behaviorNotes = _getBehaviorNotes(child, fp);
    final minutes = _calculerTempsEcranPourJour(
        _selectedDay!, schoolNotes, behaviorNotes, bonusMinutes, child, fp);

    final schoolAvg     = fp.getSchoolAverageForDays(child.id, _joursSources);
    final behaviorScore = fp.getBehaviorScoreForDays(child.id, _joursSources);
    final globalScore   = fp.getGlobalScoreForDays(child.id, _joursSources);

    return SingleChildScrollView(
      padding: const EdgeInsets.only(top: 120, bottom: 24, left: 16, right: 16),
      child: Column(children: [
        GlassCard(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              Text('📊 Résumé',
                  style: TextStyle(
                      color: color, fontWeight: FontWeight.bold, fontSize: 14)),
              const SizedBox(height: 8),
              _infoRow('🛡️ Immunités', '$immunityBonus lignes', Colors.amberAccent),
              _infoRow('⏱️ Bonus parent',
                  '${bonusMinutes > 0 ? '+' : ''}$bonusMinutes min',
                  Colors.greenAccent),
              _infoRow('📅 Jour affiché', _selectedDay!, color),
              _infoRow('⏰ Temps écran calculé', _formatMinutes(minutes), Colors.white),
              if (_joursSources.isNotEmpty) ...[
                const Divider(color: Colors.white12, height: 20),
                _infoRow(
                    '📚 Moy. scolaire (jours cochés)',
                    schoolAvg >= 0
                        ? '${schoolAvg.toStringAsFixed(1)}/20'
                        : 'Aucune note',
                    Colors.purpleAccent),
                _infoRow('😊 Comportement (jours cochés)',
                    '${behaviorScore.toStringAsFixed(1)}/20',
                    Colors.lightBlueAccent),
                _infoRow('🌟 Score global',
                    '${globalScore.toStringAsFixed(1)}/20',
                    Colors.orangeAccent),
              ],
            ]),
          ),
        ),
        const SizedBox(height: 16),
        GlassCard(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Icon(Icons.calendar_today, color: color, size: 15),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text('📚 Jours pour le calcul des notes',
                        style: TextStyle(
                            color: color, fontWeight: FontWeight.bold,
                            fontSize: 13)),
                  ),
                ]),
                const SizedBox(height: 4),
                const Text(
                  'Ex : noter le mercredi pour lundi + mardi → cocher Lun & Mar',
                  style: TextStyle(color: Colors.white38, fontSize: 11),
                ),
                const SizedBox(height: 12),
                Row(
                  children: List.generate(7, (i) {
                    final sel = _joursSources.contains(i);
                    return Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() {
                          if (sel) _joursSources.remove(i);
                          else     _joursSources.add(i);
                        }),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          margin:  const EdgeInsets.symmetric(horizontal: 2),
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            color: sel ? color.withOpacity(0.25) : Colors.white10,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: sel ? color : Colors.white24,
                              width: sel ? 1.5 : 1,
                            ),
                          ),
                          child: Column(children: [
                            Text(
                              _joursNoms[i].substring(0, 3),
                              style: TextStyle(
                                color:      sel ? color : Colors.white38,
                                fontSize:   9,
                                fontWeight: sel
                                    ? FontWeight.bold : FontWeight.normal,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 2),
                            Icon(
                              sel ? Icons.check_circle
                                  : Icons.radio_button_unchecked,
                              color: sel ? color : Colors.white24,
                              size: 11,
                            ),
                          ]),
                        ),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 10),
                Row(children: [
                  _joursShortcut('Sem.',    {0, 1, 2, 3, 4},       color),
                  const SizedBox(width: 6),
                  _joursShortcut('Lun-Mar', {0, 1},                 color),
                  const SizedBox(width: 6),
                  _joursShortcut('Lun-Mer', {0, 1, 2},              color),
                  const SizedBox(width: 6),
                  _joursShortcut('Tout',    {0, 1, 2, 3, 4, 5, 6}, color),
                ]),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Align(
          alignment: Alignment.centerLeft,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text('📅 Jour pour le temps d\'écran',
                style: TextStyle(
                    color: color.withOpacity(0.8),
                    fontSize: 12,
                    fontWeight: FontWeight.w600)),
          ),
        ),
        SizedBox(
          height: 36,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount:       _joursNoms.length,
            separatorBuilder: (_, __) => const SizedBox(width: 6),
            itemBuilder: (_, i) {
              final j        = _joursNoms[i];
              final selected = j == _selectedDay;
              return GestureDetector(
                onTap: () => setState(() => _selectedDay = j),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: selected ? color.withOpacity(0.25) : Colors.white10,
                    borderRadius: BorderRadius.circular(10),
                    border: selected ? Border.all(color: color) : null,
                  ),
                  child: Text(j.substring(0, 3),
                      style: TextStyle(
                        color:      selected ? color : Colors.white54,
                        fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                        fontSize:   12,
                      )),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 20),
        SizedBox(
          height: 200,
          child: Stack(alignment: Alignment.center, children: [
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
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w900,
                      fontSize: 28)),
              const Text('temps écran',
                  style: TextStyle(color: Colors.white54, fontSize: 12)),
            ]),
          ]),
        ),
        const SizedBox(height: 16),
        _buildQuickBonusRow(child, fp, color),
        const SizedBox(height: 16),
        _buildImmunitySection(child, fp),
      ]),
    );
  }

  Widget _joursShortcut(String label, Set<int> jours, Color color) {
    final isActive = _joursSources.length == jours.length &&
        _joursSources.containsAll(jours);
    return GestureDetector(
      onTap: () => setState(() => _joursSources = Set.from(jours)),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color:  isActive ? color.withOpacity(0.2) : Colors.white10,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: isActive ? color : Colors.white24),
        ),
        child: Text(label,
            style: TextStyle(
                color:      isActive ? color : Colors.white38,
                fontSize:   10,
                fontWeight: isActive ? FontWeight.bold : FontWeight.normal)),
      ),
    );
  }

  Widget _buildImmunitySection(ChildModel child, FamilyProvider fp) {
    final immunities = fp.getUsableImmunitiesForChild(child.id);
    if (immunities.isEmpty) return const SizedBox.shrink();
    return GlassCard(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
          const Text('🛡️ Immunités disponibles',
              style: TextStyle(
                  color: Colors.amberAccent, fontWeight: FontWeight.bold,
                  fontSize: 14)),
          const SizedBox(height: 8),
          ...immunities.map((imm) => Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(children: [
              const Text('🛡️', style: TextStyle(fontSize: 16)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(imm.reason,
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                    overflow: TextOverflow.ellipsis),
              ),
              Text('${imm.availableLines} ligne(s)',
                  style: const TextStyle(
                      color: Colors.amberAccent, fontWeight: FontWeight.bold,
                      fontSize: 12)),
            ]),
          )),
        ]),
      ),
    );
  }

  Widget _infoRow(String label, String value, Color vColor) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(child: Text(label,
                style: const TextStyle(color: Colors.white60, fontSize: 12))),
            Text(value,
                style: TextStyle(
                    color: vColor, fontWeight: FontWeight.bold, fontSize: 12)),
          ],
        ),
      );

  Widget _buildQuickBonusRow(ChildModel child, FamilyProvider fp, Color color) =>
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
                child: Text('+$min min', style: const TextStyle(fontSize: 12)),
              ),
            ),
          )).toList());

  void _triggerBonusAnim(String text) {
    setState(() { _showBonusAnim = true; _bonusAnimText = text; });
    _bonusFloatController.forward(from: 0).then((_) {
      if (mounted) setState(() => _showBonusAnim = false);
    });
  }

  List<HistoryEntry> _getSchoolNotes(ChildModel child, FamilyProvider fp) =>
      fp.history
          .where((h) => h.childId == child.id && h.category == 'school_note')
          .toList();

  List<HistoryEntry> _getBehaviorNotes(ChildModel child, FamilyProvider fp) =>
      fp.history
          .where((h) =>
              h.childId == child.id &&
              h.category != 'school_note' &&
              h.category != 'screen_time_bonus' &&
              h.category != 'saturday_rating')
          .toList();

  int _calculerTempsEcranPourJour(
    String jour,
    List<HistoryEntry> schoolNotes,
    List<HistoryEntry> behaviorNotes,
    int bonusMinutes,
    ChildModel child,
    FamilyProvider fp,
  ) {
    if (jour == 'Samedi')  return fp.getSaturdayMinutes(child.id);
    if (jour == 'Dimanche') return fp.getSundayMinutes(child.id);
    final globalScore = fp.getWeeklyGlobalScore(child.id);
    int base = 0;
    if (globalScore >= 18)      base = 180;
    else if (globalScore >= 16) base = 150;
    else if (globalScore >= 14) base = 120;
    else if (globalScore >= 12) base = 90;
    else if (globalScore >= 10) base = 60;
    else if (globalScore >= 8)  base = 30;
    return (base + bonusMinutes).clamp(0, 480);
  }

  String _formatMinutes(int minutes) {
    if (minutes <= 0) return '0 min';
    final h = minutes ~/ 60;
    final m = minutes % 60;
    if (h == 0) return '${m}min';
    if (m == 0) return '${h}h';
    return '${h}h${m.toString().padLeft(2, '0')}';
  }

  // ════════════════════════════════════════════════════════
  //  TAB HISTORIQUE
  // ════════════════════════════════════════════════════════
  Widget _buildHistoryTab(ChildModel child, FamilyProvider fp, Color color) {
    final allEntries = fp.getHistoryForChild(child.id)
      ..sort((a, b) => b.date.compareTo(a.date));

    final filtered = _historyFilter == 'Tout'
        ? allEntries
        : allEntries.where((e) {
            final cat = e.category.toLowerCase();
            switch (_historyFilter) {
              case 'Bonus':
                return e.isBonus &&
                    !cat.contains('punition') &&
                    !cat.contains('immunité') &&
                    !cat.contains('tribunal') &&
                    !cat.contains('school') &&
                    !cat.contains('note') &&
                    !cat.contains('échange');
              case 'Punition':   return cat.contains('punition');
              case 'Immunité':   return cat.contains('immunité') || cat.contains('immunity');
              case 'Tribunal':   return cat.contains('tribunal') || cat.contains('verdict');
              case 'École':
                return cat.contains('school') || cat.contains('note') ||
                    cat.contains('école') || cat.contains('saturday');
              case 'Échange':    return cat.contains('échange') || cat.contains('trade');
              default:           return true;
            }
          }).toList();

    final bonuses   = allEntries.where((h) => h.isBonus).length;
    final penalties = allEntries.where((h) => !h.isBonus).length;

    return SingleChildScrollView(
      padding: const EdgeInsets.only(top: 120, bottom: 24, left: 16, right: 16),
      child: Column(children: [
        // ── Résumé ──
        GlassCard(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _histStat('✅ Bonus',     '$bonuses',   Colors.greenAccent),
                _histStat('❌ Pénalités', '$penalties', Colors.redAccent),
                _histStat('📋 Total',
                    '${allEntries.length}', Colors.white70),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),

        // ── Filtres ──
        SizedBox(
          height: 36,
          child: ListView.separated(
            scrollDirection:  Axis.horizontal,
            itemCount:        _historyFilters.length,
            separatorBuilder: (_, __) => const SizedBox(width: 6),
            itemBuilder: (_, i) {
              final f   = _historyFilters[i];
              final sel = f == _historyFilter;
              return GestureDetector(
                onTap: () => setState(() => _historyFilter = f),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: sel ? color.withOpacity(0.25) : Colors.white10,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: sel ? color : Colors.white24,
                        width: sel ? 1.5 : 1),
                  ),
                  child: Text(f,
                      style: TextStyle(
                          color:      sel ? color : Colors.white54,
                          fontSize:   12,
                          fontWeight: sel
                              ? FontWeight.bold : FontWeight.normal)),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 12),

        // ── Liste ──
        if (filtered.isEmpty)
          Padding(
            padding: const EdgeInsets.all(32),
            child: Column(children: [
              const Text('📭', style: TextStyle(fontSize: 40)),
              const SizedBox(height: 8),
              Text('Aucune entrée dans « $_historyFilter »',
                  style: const TextStyle(
                      color: Colors.white54, fontSize: 13),
                  textAlign: TextAlign.center),
            ]),
          )
        else
          ...filtered.map((e) => _buildHistoryCard(e, color)),
      ]),
    );
  }

  Widget _histStat(String label, String value, Color c) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(value,
          style: TextStyle(
              color: c, fontWeight: FontWeight.bold, fontSize: 18)),
      Text(label,
          style: const TextStyle(color: Colors.white54, fontSize: 11)),
    ],
  );

  Widget _buildHistoryCard(HistoryEntry e, Color accentColor) {
    final cat   = _categoryColor(e);
    final emoji = _categoryEmoji(e);
    final pts   = e.points;
    final sign  = pts >= 0 ? '+' : '';

    // Formatage date
    final now   = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final eDay  = DateTime(e.date.year, e.date.month, e.date.day);
    String dateLabel;
    if (eDay == today) {
      dateLabel = "Aujourd'hui";
    } else if (eDay == today.subtract(const Duration(days: 1))) {
      dateLabel = 'Hier';
    } else {
      dateLabel =
          '${e.date.day.toString().padLeft(2, '0')}/${e.date.month.toString().padLeft(2, '0')}/${e.date.year}';
    }
    final timeLabel =
        '${e.date.hour.toString().padLeft(2, '0')}:${e.date.minute.toString().padLeft(2, '0')}';

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        decoration: BoxDecoration(
          color:        cat.withOpacity(0.07),
          borderRadius: BorderRadius.circular(12),
          border:       Border.all(color: cat.withOpacity(0.35), width: 1),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Text(emoji, style: const TextStyle(fontSize: 18)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(e.reason,
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.w600,
                          fontSize: 13),
                      overflow: TextOverflow.ellipsis),
                ),
                Text('$sign$pts pts',
                    style: TextStyle(
                        color:      pts >= 0 ? Colors.greenAccent : Colors.redAccent,
                        fontWeight: FontWeight.bold,
                        fontSize:   14)),
              ]),
              const SizedBox(height: 4),
              Row(children: [
                Icon(Icons.access_time, size: 11, color: Colors.white38),
                const SizedBox(width: 4),
                Text('$dateLabel à $timeLabel',
                    style: const TextStyle(
                        color: Colors.white38, fontSize: 11)),
                if (e.actionBy != null && e.actionBy!.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  const Text('·',
                      style: TextStyle(color: Colors.white24)),
                  const SizedBox(width: 4),
                  Text('par ${e.actionBy}',
                      style: const TextStyle(
                          color: Colors.white38, fontSize: 11)),
                ],
              ]),
              if (e.hasProofPhoto) ...[
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.memory(
                    base64Decode(e.proofPhotoBase64!),
                    height: 120,
                    width:  double.infinity,
                    fit:    BoxFit.cover,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // ════════════════════════════════════════════════════════
  //  TAB BADGES
  // ════════════════════════════════════════════════════════
  Widget _buildBadgesTab(ChildModel child, FamilyProvider fp, Color color) {
    final allBadges = fp.badges;
    final earned = allBadges
        .where((b) =>
            child.badgeIds.contains(b.id) &&
            !_hiddenDefaultBadgeIds.contains(b.id))
        .toList();
    final locked = allBadges
        .where((b) =>
            !child.badgeIds.contains(b.id) &&
            !_hiddenDefaultBadgeIds.contains(b.id))
        .toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.only(top: 120, bottom: 24, left: 16, right: 16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

        // ── Badges personnalisés ──
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('⭐ Badges personnalisés',
                style: TextStyle(
                    color: color, fontWeight: FontWeight.bold, fontSize: 14)),
            IconButton(
              icon: const Icon(Icons.add_circle, color: Colors.deepPurpleAccent),
              onPressed: () => _addCustomBadge(child.id),
            ),
          ],
        ),
        if (_customLocalBadges.isEmpty)
          const Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: Text('Aucun badge personnalisé. Appuie sur + pour en ajouter.',
                style: TextStyle(color: Colors.white38, fontSize: 12)),
          )
        else
          Wrap(
            spacing: 8, runSpacing: 8,
            children: List.generate(_customLocalBadges.length, (i) {
              final b = _customLocalBadges[i];
              return GestureDetector(
                onLongPress: () {
                  showDialog(
                    context: context,
                    builder: (_) => AlertDialog(
                      backgroundColor: const Color(0xFF1A1A2E),
                      title: const Text('Supprimer ce badge ?',
                          style: TextStyle(color: Colors.white)),
                      actions: [
                        TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Annuler')),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.redAccent),
                          onPressed: () {
                            _removeCustomBadge(i, child.id);
                            Navigator.pop(context);
                          },
                          child: const Text('Supprimer'),
                        ),
                      ],
                    ),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color:        Colors.deepPurple.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                    border:       Border.all(
                        color: Colors.deepPurpleAccent.withOpacity(0.5)),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Text(b.emoji,
                        style: const TextStyle(fontSize: 18)),
                    const SizedBox(width: 6),
                    Text(b.label,
                        style: const TextStyle(
                            color: Colors.white, fontSize: 12)),
                  ]),
                ),
              );
            }),
          ),

        const SizedBox(height: 16),
        const Divider(color: Colors.white12),
        const SizedBox(height: 8),

        // ── Badges obtenus ──
        Text('🏆 Badges obtenus (${earned.length})',
            style: TextStyle(
                color: color, fontWeight: FontWeight.bold, fontSize: 14)),
        const SizedBox(height: 8),
        if (earned.isEmpty)
          const Text('Aucun badge obtenu pour l\'instant.',
              style: TextStyle(color: Colors.white38, fontSize: 12))
        else
          Wrap(
            spacing: 8, runSpacing: 8,
            children: earned.map((b) => GestureDetector(
              onLongPress: () {
                showDialog(
                  context: context,
                  builder: (_) => AlertDialog(
                    backgroundColor: const Color(0xFF1A1A2E),
                    title: const Text('Masquer ce badge ?',
                        style: TextStyle(color: Colors.white)),
                    content: Text(
                        'Masquer « ${b.name} » de la vue ?',
                        style: const TextStyle(color: Colors.white70)),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Annuler')),
                      ElevatedButton(
                        onPressed: () {
                          _hideDefaultBadge(b.id, child.id);
                          Navigator.pop(context);
                        },
                        child: const Text('Masquer'),
                      ),
                    ],
                  ),
                );
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color:        Colors.amber.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                  border:       Border.all(
                      color: Colors.amber.withOpacity(0.4)),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Text(b.icon, style: const TextStyle(fontSize: 18)),
                  const SizedBox(width: 6),
                  Text(b.name,
                      style: const TextStyle(
                          color: Colors.white, fontSize: 12)),
                ]),
              ),
            )).toList(),
          ),

        if (_hiddenDefaultBadgeIds.isNotEmpty) ...[
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: () => _resetHiddenBadges(child.id),
            icon:  const Icon(Icons.visibility, size: 16,
                color: Colors.white38),
            label: Text(
                'Afficher les ${_hiddenDefaultBadgeIds.length} badge(s) masqué(s)',
                style: const TextStyle(
                    color: Colors.white38, fontSize: 12)),
          ),
        ],

        const SizedBox(height: 16),
        const Divider(color: Colors.white12),
        const SizedBox(height: 8),

        // ── Badges verrouillés ──
        Text('🔒 Badges à débloquer (${locked.length})',
            style: const TextStyle(
                color: Colors.white54, fontWeight: FontWeight.bold,
                fontSize: 14)),
        const SizedBox(height: 8),
        if (locked.isEmpty)
          const Text('Tous les badges ont été débloqués ! 🎉',
              style: TextStyle(color: Colors.white38, fontSize: 12))
        else
          Wrap(
            spacing: 8, runSpacing: 8,
            children: locked.map((b) => Opacity(
              opacity: 0.4,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color:        Colors.white10,
                  borderRadius: BorderRadius.circular(20),
                  border:       Border.all(color: Colors.white24),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Text('🔒',
                      style: TextStyle(fontSize: 18)),
                  const SizedBox(width: 6),
                  Text(b.name,
                      style: const TextStyle(
                          color: Colors.white54, fontSize: 12)),
                ]),
              ),
            )).toList(),
          ),
      ]),
    );
  }
}
