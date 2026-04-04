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
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = Colors.white10
        ..style = PaintingStyle.stroke
        ..strokeWidth = 10,
    );
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

  late Animation<double>   _contentFade;
  late Animation<double>   _glowAnim;
  late Animation<double>   _bonusFloatAnim;
  late Animation<double>   _bonusOpacity;

  String? _selectedChildId;
  String? _selectedDay;

  bool   _showBonusAnim = false;
  String _bonusAnimText = '';

  // Badges personnalisés locaux (ajoutés par l'enfant/parent)
  List<_CustomBadgeItem> _customLocalBadges = [];

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
        _loadCustomBadges(id);
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

  // ─── Chargement / sauvegarde badges locaux ───────────────
  Future<void> _loadCustomBadges(String childId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw   = prefs.getStringList('custom_badges_$childId') ?? [];
    setState(() {
      _customLocalBadges = raw.map((s) {
        final parts = s.split('||');
        return _CustomBadgeItem(
          emoji: parts.isNotEmpty ? parts[0] : '⭐',
          label: parts.length > 1 ? parts[1] : s,
        );
      }).toList();
    });
  }

  Future<void> _saveCustomBadges(String childId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      'custom_badges_$childId',
      _customLocalBadges.map((b) => '${b.emoji}||${b.label}').toList(),
    );
  }

  // ─── Ajouter un badge personnalisé ───────────────────────
  Future<void> _addCustomBadge(String childId) async {
    final emojiCtrl = TextEditingController();
    final labelCtrl = TextEditingController();
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        title: const Text('Ajouter un badge',
            style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              '💡 Appuie sur le champ émoji et utilise le clavier de ton téléphone pour choisir ton émoji',
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
                  borderSide:   const BorderSide(color: Colors.white24),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide:   const BorderSide(color: Colors.deepPurpleAccent),
                ),
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
                  borderSide:   const BorderSide(color: Colors.white24),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide:   const BorderSide(color: Colors.deepPurpleAccent),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler',
                style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurpleAccent),
            onPressed: () {
              final e = emojiCtrl.text.trim();
              final l = labelCtrl.text.trim();
              if (l.isNotEmpty) {
                setState(() => _customLocalBadges.add(
                    _CustomBadgeItem(
                        emoji: e.isEmpty ? '⭐' : e, label: l)));
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

  // ─── Supprimer un badge personnalisé ─────────────────────
  void _removeCustomBadge(int index, String childId) {
    setState(() => _customLocalBadges.removeAt(index));
    _saveCustomBadges(childId);
  }

  // ─── Couleur enfant ──────────────────────────────────────
  Color _childColor(ChildModel child) {
    if (child.accentColorHex != null) {
      try {
        return Color(
            int.parse(child.accentColorHex!.replaceFirst('#', '0xFF')));
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
    final color      = _childColor(child);
    final frameColor = _frameColor(child.level);
    final highLevel  = child.level >= 4;

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
              color:      color,
            )),
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
              _loadCustomBadges(c.id);
            },
          )),
        ],
      ),
    );
  }

  // ─── Édition photo ───────────────────────────────────────
  Future<void> _editPhoto(ChildModel child, FamilyProvider fp) async {
    final xfile = await ImagePicker().pickImage(
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
                  if (pin.verifyPin(ctrl.text)) {
                    ok = true;
                    Navigator.pop(ctx);
                  } else {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                        const SnackBar(
                            content: Text('PIN incorrect ❌')));
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

  // ─── Édition slogan ──────────────────────────────────────
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
            labelText:   'Slogan',
            labelStyle:  TextStyle(color: Colors.white54),
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
        backgroundColor:       const Color(0xFF0F0F1E),
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

  // ─── TAB PROFIL ──────────────────────────────────────────
  Widget _buildProfileTab(ChildModel child, FamilyProvider fp, Color color) {
    final frame = _frameColor(child.level);
    return SingleChildScrollView(
      padding: const EdgeInsets.only(top: 120, bottom: 24),
      child: Column(children: [
        // ── Carte profil simple (comme avant) ──
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: GlassCard(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(children: [
                // Bannière
                if (child.bannerBase64 != null &&
                    child.bannerBase64!.isNotEmpty)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: SizedBox(
                      height: 100,
                      width:  double.infinity,
                      child: Image.memory(
                        base64Decode(child.bannerBase64!),
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                if (child.bannerBase64 != null &&
                    child.bannerBase64!.isNotEmpty)
                  const SizedBox(height: 16),
                // Photo + cadre niveau
                _buildAvatar(child, 52, showFrame: true),
                const SizedBox(height: 12),
                // Nom
                Text(child.name,
                    style: const TextStyle(
                        color:      Colors.white,
                        fontSize:   22,
                        fontWeight: FontWeight.bold)),
                // Slogan
                if (child.sloganText != null &&
                    child.sloganText!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text('"${child.sloganText}"',
                        style: const TextStyle(
                            color:     Colors.white60,
                            fontSize:  12,
                            fontStyle: FontStyle.italic)),
                  ),
                const SizedBox(height: 16),
                // Niveau + barre HP
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(child.levelTitle,
                        style: TextStyle(
                            color:      frame,
                            fontWeight: FontWeight.bold,
                            fontSize:   13)),
                    Text('${child.points} pts',
                        style: const TextStyle(
                            color: Colors.white54, fontSize: 12)),
                  ],
                ),
                const SizedBox(height: 6),
                // Barre de progression (carré avec barre inside)
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
                      style: const TextStyle(
                          color: Colors.white38, fontSize: 10)),
                ),
              ]),
            ),
          ),
        ),
        const SizedBox(height: 12),
        // Boutons édition
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
                label: const Text('Photo',
                    style: TextStyle(fontSize: 12)),
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
    final bonuses   = history.where((h) => h.points > 0).length;
    final penalties = history.where((h) => h.points < 0).length;
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount:  2,
      crossAxisSpacing: 10,
      mainAxisSpacing:  10,
      childAspectRatio: 1.6,
      children: [
        _statCard('🎯', 'Bonus',     '$bonuses',   Colors.greenAccent),
        _statCard('⚡', 'Pénalités', '$penalties', Colors.redAccent),
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
          Text(value,
              style: TextStyle(
                  color: color, fontWeight: FontWeight.bold, fontSize: 13)),
          Text(label,
              style: const TextStyle(color: Colors.white54, fontSize: 10)),
        ]),
      );

  // ─── TAB ÉCRAN ───────────────────────────────────────────
  Widget _buildScreenTab(ChildModel child, FamilyProvider fp, Color color) {
    final immunities    = fp.getUsableImmunitiesForChild(child.id);
    final immunityBonus = immunities.fold(0, (s, i) => s + i.availableLines);
    final bonusMinutes  = fp.getParentBonusMinutes(child.id);

    final jours = ['Lundi', 'Mardi', 'Mercredi', 'Jeudi',
        'Vendredi', 'Samedi', 'Dimanche'];
    _selectedDay ??= jours[DateTime.now().weekday - 1];

    final schoolNotes   = _getSchoolNotes(child, fp);
    final behaviorNotes = _getBehaviorNotes(child, fp);
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
                  style: TextStyle(
                      color: color, fontWeight: FontWeight.bold,
                      fontSize: 14)),
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
                        ? color.withOpacity(0.25) : Colors.white10,
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
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900, fontSize: 28)),
                const Text('temps écran',
                    style: TextStyle(
                        color: Colors.white54, fontSize: 12)),
              ]),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _buildQuickBonusRow(child, fp, color),
        const SizedBox(height: 16),
        _buildImmunitySection(child, fp, color),
      ]),
    );
  }

  Widget _buildImmunitySection(
      ChildModel child, FamilyProvider fp, Color color) {
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
                    color:      Colors.amberAccent,
                    fontWeight: FontWeight.bold,
                    fontSize:   14)),
            const SizedBox(height: 8),
            ...immunities.map((imm) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(children: [
                const Text('🛡️', style: TextStyle(fontSize: 16)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(imm.reason,
                      style: const TextStyle(
                          color: Colors.white70, fontSize: 12),
                      overflow: TextOverflow.ellipsis),
                ),
                Text('${imm.availableLines} ligne(s)',
                    style: const TextStyle(
                        color:      Colors.amberAccent,
                        fontWeight: FontWeight.bold,
                        fontSize:   12)),
              ]),
            )),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value, Color vColor) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: Colors.white60, fontSize: 12)),
        Text(value,
            style: TextStyle(
                color: vColor, fontWeight: FontWeight.bold, fontSize: 12)),
      ],
    ),
  );

  Widget _buildQuickBonusRow(
      ChildModel child, FamilyProvider fp, Color color) =>
      Row(children: [15, 30, 60].map((min) => Expanded(
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
      )).toList());

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
    final entries   = fp.getHistoryForChild(child.id);

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
          child: TimelineWidget(entries: entries.take(10).toList()),
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
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) =>
                    TimelineScreen(initialChildId: child.id))),
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
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

        // ── Badges personnalisés (ajoutables / supprimables) ──
        GlassCard(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('⭐ Mes badges perso',
                        style: TextStyle(
                            color:      color,
                            fontWeight: FontWeight.bold,
                            fontSize:   14)),
                    GestureDetector(
                      onTap: () => _addCustomBadge(child.id),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                              color: color.withOpacity(0.5)),
                        ),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(Icons.add, color: color, size: 14),
                          const SizedBox(width: 4),
                          Text('Ajouter',
                              style: TextStyle(
                                  color:      color,
                                  fontSize:   12,
                                  fontWeight: FontWeight.bold)),
                        ]),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                if (_customLocalBadges.isEmpty)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Text(
                        'Aucun badge perso. Appuie sur "Ajouter" !',
                        style: TextStyle(
                            color: Colors.white38, fontSize: 12),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  )
                else
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount:   3,
                      crossAxisSpacing: 8,
                      mainAxisSpacing:  8,
                      childAspectRatio: 0.85,
                    ),
                    itemCount: _customLocalBadges.length,
                    itemBuilder: (_, i) {
                      final b = _customLocalBadges[i];
                      return Stack(
                        children: [
                          GlassCard(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(b.emoji,
                                    style: const TextStyle(fontSize: 30)),
                                const SizedBox(height: 4),
                                Text(b.label,
                                    style: const TextStyle(
                                        color:      Colors.white,
                                        fontSize:   10,
                                        fontWeight: FontWeight.bold),
                                    textAlign: TextAlign.center,
                                    maxLines:  2,
                                    overflow:  TextOverflow.ellipsis),
                              ],
                            ),
                          ),
                          Positioned(
                            top:   4,
                            right: 4,
                            child: GestureDetector(
                              onTap: () => _removeCustomBadge(i, child.id),
                              child: Container(
                                padding: const EdgeInsets.all(2),
                                decoration: const BoxDecoration(
                                  color:     Colors.redAccent,
                                  shape:     BoxShape.circle,
                                ),
                                child: const Icon(Icons.close,
                                    color: Colors.white, size: 12),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),

        // ── Badges gagnés ──
        Text('🏅 Badges obtenus (${earned.length})',
            style: TextStyle(
                color:      color,
                fontWeight: FontWeight.bold,
                fontSize:   14)),
        const SizedBox(height: 10),
        if (earned.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(
                child: Text('Aucun badge encore obtenu',
                    style: TextStyle(color: Colors.white38))),
          )
        else
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate:
                const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount:   3,
              crossAxisSpacing: 10,
              mainAxisSpacing:  10,
              childAspectRatio: 0.9,
            ),
            itemCount: earned.length,
            itemBuilder: (_, i) => _badgeEarnedCard(earned[i], color),
          ),
        const SizedBox(height: 20),

        // ── Badges à débloquer ──
        Text('🔒 Badges à débloquer (${locked.length})',
            style: const TextStyle(
                color:      Colors.white54,
                fontWeight: FontWeight.bold,
                fontSize:   14)),
        const SizedBox(height: 10),
        ...locked.map((b) => _badgeLockedTile(b, child)),
      ]),
    );
  }

  Widget _badgeEarnedCard(BadgeModel badge, Color color) => GlassCard(
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Text(badge.powerEmoji, style: const TextStyle(fontSize: 28)),
      const SizedBox(height: 4),
      Text(badge.name,
          style: const TextStyle(
              color:      Colors.white,
              fontWeight: FontWeight.bold,
              fontSize:   11),
          textAlign: TextAlign.center,
          maxLines:  2,
          overflow:  TextOverflow.ellipsis),
    ]),
  );

  Widget _badgeLockedTile(BadgeModel badge, ChildModel child) {
    final progress =
        (child.points / badge.requiredPoints).clamp(0.0, 1.0);
    final frame = _frameColor(child.level);
    return Container(
      margin:  const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color:        Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border:       Border.all(color: Colors.white12),
      ),
      child: Row(children: [
        Container(
          width: 52, height: 52,
          decoration: BoxDecoration(
              color: Colors.white10,
              borderRadius: BorderRadius.circular(10)),
          child: Center(child: Text(badge.powerEmoji,
              style: const TextStyle(fontSize: 24))),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
            Text(badge.name,
                style: const TextStyle(
                    color: Colors.white70,
                    fontWeight: FontWeight.bold,
                    fontSize: 13)),
            Text(badge.description,
                style: const TextStyle(
                    color: Colors.white38, fontSize: 11),
                maxLines: 1, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 6),
            // Carré avec barre de progression à l'intérieur
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: frame.withOpacity(0.4)),
                color: Colors.white10,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(5),
                child: LinearProgressIndicator(
                  value:           progress,
                  backgroundColor: Colors.transparent,
                  valueColor:
                      AlwaysStoppedAnimation(Colors.deepPurpleAccent),
                  minHeight: 12,
                ),
              ),
            ),
            const SizedBox(height: 2),
            Text('${child.points} / ${badge.requiredPoints} pts',
                style: const TextStyle(
                    color: Colors.white38, fontSize: 10)),
          ]),
        ),
      ]),
    );
  }

  // ─── Helpers calcul temps écran ──────────────────────────
  List<dynamic> _getSchoolNotes(ChildModel child, FamilyProvider fp) =>
      fp.history
          .where((h) =>
              h.childId == child.id && h.category == 'school_note')
          .toList();

  List<dynamic> _getBehaviorNotes(ChildModel child, FamilyProvider fp) =>
      fp.history
          .where((h) =>
              h.childId == child.id &&
              h.category != 'school_note' &&
              h.category != 'screen_time_bonus')
          .toList();

  int _calculerTempsEcranPourJour(
    String jour,
    List<dynamic> schoolNotes,
    List<dynamic> behaviorNotes,
    int bonusMinutes,
    ChildModel child,
    FamilyProvider fp,
  ) {
    int base = 60;
    if (jour == 'Samedi' || jour == 'Dimanche') base = 90;
    if (jour == 'Mercredi') base = 75;
    final pts = child.points;
    if (pts >= 50)      base += 30;
    else if (pts >= 20) base += 15;
    else if (pts < 0)   base -= 20;
    base += bonusMinutes;
    return base.clamp(0, 300);
  }

  String _formatMinutes(int minutes) {
    if (minutes < 60) return '${minutes}min';
    final h = minutes ~/ 60;
    final m = minutes % 60;
    return m == 0 ? '${h}h' : '${h}h${m.toString().padLeft(2, '0')}';
  }
}
