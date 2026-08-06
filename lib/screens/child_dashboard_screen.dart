// lib/screens/child_dashboard_screen.dart

import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../providers/family_provider.dart';
import '../providers/pin_provider.dart';
import '../models/child_model.dart';
import '../models/punishment_lines.dart';
import '../models/badge_model.dart';
import '../models/history_entry.dart';
import '../utils/image_cache.dart';
import '../config/emerald_theme.dart';
import '../widgets/animated_background.dart';
import '../widgets/glass_card.dart';
import '../widgets/timeline_widget.dart';
import '../widgets/history_proof_photo.dart';
import 'timeline_screen.dart';
import 'shop_screen.dart';
import 'wallet_screen.dart';
import 'punishment_lines_screen.dart';

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
    canvas.drawCircle(dotPos, 10, Paint()..color = color.withValues(alpha: 0.3));
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
        backgroundColor: EmeraldPalette.surface,
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
    if (cat.contains('punition')) return '📝';
    if (cat.contains('immunité')) return '🛡️';
    if (cat.contains('tribunal') || cat.contains('verdict')) return '⚖️';
    if (cat.contains('school') || cat.contains('note')) return '📚';
    if (cat.contains('échange') || cat.contains('trade')) return '🔄';
    if (cat.contains('screen')) return '📺';
    if (e.isBonus) return '✅';
    return '❌';
  }

  // ─── Avatar ──────────────────────────────────────────────
  // Utilise StableAvatar : la photo ne se recharge JAMAIS sauf si
  // le base64 change réellement. Fini le clignotement.
  Widget _buildAvatar(ChildModel child, double radius) {
    final color = _childColor(child);
    return StableAvatar(
      photoBase64: child.photoBase64,
      emoji: child.avatar,
      name: child.name,
      radius: radius,
      color: color,
    );
  }

  Widget _letterAvatar(ChildModel child, double radius, Color color) =>
      CircleAvatar(
        radius: radius,
        backgroundColor: color.withValues(alpha: 0.3),
        child: Text(child.name.isEmpty ? '?' : child.name[0].toUpperCase(),
            style: TextStyle(
                fontSize:   radius * 0.9,
                fontWeight: FontWeight.bold,
                color:      color)),
      );

  // ─── Sélecteur enfant ────────────────────────────────────
  void _showChildSwitcher(FamilyProvider fp) {
    showModalBottomSheet(
      context: context,
      backgroundColor: EmeraldPalette.surface,
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
            leading:  _buildAvatar(c, 22),
            title:    Text(c.name,
                style: const TextStyle(color: Colors.white)),
            subtitle: Text('${c.points} pts bonus',
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

    // Loader pendant l'upload (évite l'écran gris)
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const AlertDialog(
        backgroundColor: Color(0xFF0F2620),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: Color(0xFF00E676)),
            const SizedBox(height: 16),
            Text('Upload en cours...', style: TextStyle(color: Colors.white)),
          ],
        ),
      ),
    );

    try {
      await fp.updateChildPhoto(child.id, base64Encode(bytes));
    } catch (e) {
      if (kDebugMode) debugPrint('Edit photo error: $e');
    }
    if (mounted) {
      Navigator.pop(context); // Fermer le loader
      setState(() {});
    }
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
            backgroundColor: EmeraldPalette.surface,
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

    // Loader pendant l'upload bannière
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const AlertDialog(
        backgroundColor: Color(0xFF0F2620),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: Color(0xFF00E676)),
            const SizedBox(height: 16),
            Text('Upload bannière...', style: TextStyle(color: Colors.white)),
          ],
        ),
      ),
    );

    try {
      await fp.updateChildBanner(child.id, base64Encode(bytes));
    } catch (e) {
      if (kDebugMode) debugPrint('Edit banner error: $e');
    }
    if (mounted) {
      Navigator.pop(context); // Fermer le loader
      setState(() {});
    }
  }

  Future<void> _editSlogan(ChildModel child, FamilyProvider fp) async {
    final ctrl = TextEditingController(text: child.sloganText ?? '');
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: EmeraldPalette.surface,
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
          backgroundColor: EmeraldPalette.background,
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
        backgroundColor:        EmeraldPalette.background,
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation:       0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white70),
            onPressed: () => Navigator.pop(context),
          ),
          title: Row(children: [
            _buildAvatar(child, 16),
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
            // Menu réinitialisation (parent uniquement) — watch pour réagir au changement de mode
            if (context.watch<PinProvider>().isParentMode)
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, color: Colors.white70),
                color: EmeraldPalette.surface,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                onSelected: (value) {
                  if (value == 'reset_points') {
                    _confirmReset(context, fp, child,
                        'Réinitialiser les points ?',
                        'Les points de ${child.name} repassent à 0. Les badges seront retirés.',
                        () async {
                      await fp.resetChildPoints(child.id);
                    });
                  } else if (value == 'reset_all') {
                    _confirmReset(context, fp, child,
                        'Tout réinitialiser ?',
                        'Points, badges, punitions, immunités, objectifs, notes et historique de ${child.name} seront supprimés. Action irréversible.',
                        () async {
                      await fp.resetChildCompletely(child.id);
                      if (context.mounted) Navigator.pop(context);
                    });
                  }
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(
                    value: 'reset_points',
                    child: Row(children: [
                      Icon(Icons.refresh, color: Colors.amber, size: 20),
                      const SizedBox(width: 10),
                      Text('Réinitialiser les points', style: TextStyle(color: Colors.white)),
                    ]),
                  ),
                  const PopupMenuItem(
                    value: 'reset_all',
                    child: Row(children: [
                      Icon(Icons.delete_forever, color: Colors.redAccent, size: 20),
                      const SizedBox(width: 10),
                      Text('Tout réinitialiser', style: TextStyle(color: Colors.redAccent)),
                    ]),
                  ),
                ],
              ),
          ],
          bottom: TabBar(
            controller:           _tabController,
            indicatorColor:       color,
            labelColor:           color,
            unselectedLabelColor: Colors.white38,
            dividerColor:         Colors.transparent,
            overlayColor:         WidgetStateProperty.all(Colors.transparent),
            indicatorSize:        TabBarIndicatorSize.tab,
            tabs: const [
              Tab(icon: Icon(Icons.person),      text: 'Profil'),
              Tab(icon: Icon(Icons.tv),           text: 'Écran'),
              Tab(icon: Icon(Icons.history),      text: 'Historique'),
              Tab(icon: Icon(Icons.shopping_bag_rounded), text: 'Boutique'),
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

  // â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
  //  TAB PROFIL
  // â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
  // ─── Confirmation de réinitialisation (parent) ───
  void _confirmReset(BuildContext context, FamilyProvider fp, ChildModel child,
      String title, String message, Future<void> Function() onConfirm) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: EmeraldPalette.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Row(children: [
          const Icon(Icons.warning_amber_rounded, color: Colors.redAccent),
          const SizedBox(width: 10),
          Expanded(child: Text(title, style: const TextStyle(color: Colors.white, fontSize: 17))),
        ]),
        content: Text(message, style: TextStyle(color: Colors.white.withValues(alpha: 0.8))),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () async {
              Navigator.pop(ctx);
              await onConfirm();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Réinitialisé'), backgroundColor: Colors.green),
                );
              }
            },
            child: const Text('Confirmer', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // ─── Proposition enfant : Demande de BONUS ───
  void _showBonusRequestDialog(BuildContext context, FamilyProvider fp, ChildModel child) {
    final reasonCtrl = TextEditingController();
    int amount = 10;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF0F2620),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(children: [
            Text('⭐', style: TextStyle(fontSize: 28)),
            const SizedBox(width: 10),
            Text('Demander un bonus', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          ]),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Explique pourquoi tu mérites un bonus :',
                  style: TextStyle(color: Colors.white54, fontSize: 13)),
              const SizedBox(height: 12),
              TextField(
                controller: reasonCtrl,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Ex: J\'ai rangé ma chambre sans qu\'on me le demande',
                  hintStyle: const TextStyle(color: Colors.white30),
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.06),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 16),
              const Text('Points demandés :', style: TextStyle(color: Colors.white54, fontSize: 13)),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    onPressed: () => setDialogState(() { if (amount > 1) amount--; }),
                    icon: const Icon(Icons.remove_circle_outline, color: Colors.white54),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.green.withValues(alpha: 0.4)),
                    ),
                    child: Text('$amount pts', style: const TextStyle(color: Colors.green, fontSize: 20, fontWeight: FontWeight.w800)),
                  ),
                  IconButton(
                    onPressed: () => setDialogState(() { if (amount < 50) amount++; }),
                    icon: const Icon(Icons.add_circle_outline, color: Colors.white54),
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
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
              onPressed: () {
                final reason = reasonCtrl.text.trim();
                if (reason.isEmpty) return;
                fp.createRequest(
                  type: 'bonus',
                  childId: child.id,
                  requestedBy: child.name,
                  text: '⭐ $reason',
                  amount: amount,
                );
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Demande de bonus envoyée ! En attente du parent.'),
                    backgroundColor: Colors.green,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
              child: const Text('Envoyer', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Proposition enfant (penalite / immunite) avec validation parentale ───
  void _showProposeRequestDialog(BuildContext context, FamilyProvider fp, ChildModel child, String type) {
    final isPenalite = type == 'punishment';
    final mainColor = isPenalite ? const Color(0xFFFF5252) : const Color(0xFFFFC107);
    final commentCtrl = TextEditingController();
    final customCtrl = TextEditingController();
    int nbLines = 20;
    bool isCustom = false;
    final presets = [20, 50, 100];

    showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 24),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF1E1E3F), Color(0xFF15152B)],
              ),
              border: Border.all(color: mainColor.withValues(alpha: 0.4), width: 1.5),
              boxShadow: [
                BoxShadow(color: mainColor.withValues(alpha: 0.25), blurRadius: 30, spreadRadius: 2),
              ],
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // En-tete avec icone
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: mainColor.withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          isPenalite ? Icons.edit_document : Icons.shield_rounded,
                          color: mainColor, size: 28,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isPenalite ? 'Me proposer' : 'Me proposer',
                              style: const TextStyle(color: Colors.white54, fontSize: 13),
                            ),
                            Text(
                              isPenalite ? 'une penalite' : 'une immunite',
                              style: TextStyle(color: mainColor, fontSize: 20, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  // Champ commentaire
                  const Text("Qu'as-tu fait ?", style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: TextField(
                      controller: commentCtrl,
                      style: const TextStyle(color: Colors.white),
                      maxLines: 3,
                      decoration: const InputDecoration(
                        hintText: 'Explique ce que tu as fait...',
                        hintStyle: TextStyle(color: Colors.white30),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.all(14),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Nombre de lignes
                  const Text('Nombre de lignes', style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      ...presets.map((p) {
                        final sel = !isCustom && nbLines == p;
                        return GestureDetector(
                          onTap: () => setS(() { isCustom = false; nbLines = p; }),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            width: 70, height: 60,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(14),
                              gradient: sel ? LinearGradient(colors: [mainColor, mainColor.withValues(alpha: 0.7)]) : null,
                              color: sel ? null : Colors.white.withValues(alpha: 0.06),
                              border: Border.all(color: sel ? mainColor : Colors.white12, width: 1.5),
                            ),
                            child: Center(
                              child: Text('$p',
                                style: TextStyle(
                                  color: sel ? Colors.black : Colors.white,
                                  fontSize: 20, fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        );
                      }),
                      // Bouton Perso
                      GestureDetector(
                        onTap: () => setS(() => isCustom = true),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          width: 70, height: 60,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14),
                            gradient: isCustom ? LinearGradient(colors: [mainColor, mainColor.withValues(alpha: 0.7)]) : null,
                            color: isCustom ? null : Colors.white.withValues(alpha: 0.06),
                            border: Border.all(color: isCustom ? mainColor : Colors.white12, width: 1.5),
                          ),
                          child: Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.tune_rounded, color: isCustom ? Colors.black : Colors.white, size: 20),
                                Text('Perso', style: TextStyle(color: isCustom ? Colors.black : Colors.white, fontSize: 11)),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  // Champ perso
                  if (isCustom) ...[
                    const SizedBox(height: 14),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: mainColor.withValues(alpha: 0.5)),
                      ),
                      child: TextField(
                        controller: customCtrl,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(color: Colors.white, fontSize: 16),
                        decoration: const InputDecoration(
                          hintText: 'Nombre de lignes...',
                          hintStyle: TextStyle(color: Colors.white30),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 28),
                  // Boutons actions
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
                          child: const Text('Annuler', style: TextStyle(color: Colors.white54, fontSize: 15)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: mainColor,
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          onPressed: () {
                            final txt = commentCtrl.text.trim();
                            if (txt.isEmpty) {
                              ScaffoldMessenger.of(ctx).showSnackBar(
                                const SnackBar(content: Text('Ajoute un commentaire')),
                              );
                              return;
                            }
                            int finalLines = nbLines;
                            if (isCustom) {
                              final parsed = int.tryParse(customCtrl.text.trim());
                              if (parsed == null || parsed <= 0) {
                                ScaffoldMessenger.of(ctx).showSnackBar(
                                  const SnackBar(content: Text('Entre un nombre valide')),
                                );
                                return;
                              }
                              finalLines = parsed;
                            }
                            fp.createRequest(
                              type: type,
                              childId: child.id,
                              requestedBy: child.name,
                              text: txt,
                              amount: finalLines,
                            );
                            Navigator.pop(ctx);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Demande envoyee ! En attente du parent'),
                                backgroundColor: Colors.green,
                              ),
                            );
                          },
                          child: const Text('Envoyer la demande', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
  
  Widget _buildProfileTab(ChildModel child, FamilyProvider fp, Color color) {
    final pendingLines = fp.pendingPenaltyLinesForChild(child.id);
    return SingleChildScrollView(
      padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top + kToolbarHeight + kTextTabBarHeight + 8, bottom: 24),
      child: Column(children: [
        if (pendingLines.isNotEmpty)
          _buildPenaltyLinesAlert(child, pendingLines),
        // ─── Boutons proposition enfant (Bonus + Pénalité + Immunité) ───
        if (!context.watch<PinProvider>().isParentMode)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: () => _showBonusRequestDialog(context, fp, child),
                    icon: const Icon(Icons.star_rounded, size: 18),
                    label: const Text('Bonus', style: TextStyle(fontSize: 12)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.redAccent,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: () => _showProposeRequestDialog(context, fp, child, 'punishment'),
                    icon: const Icon(Icons.edit_document, size: 18),
                    label: const Text('Pénalité', style: TextStyle(fontSize: 12)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.amberAccent,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: () => _showProposeRequestDialog(context, fp, child, 'immunity'),
                    icon: const Icon(Icons.shield_rounded, size: 18),
                    label: const Text('Immunité', style: TextStyle(fontSize: 12)),
                  ),
                ),
              ],
            ),
          ),
        if (!context.watch<PinProvider>().isParentMode) const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: GlassCard(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(children: [

                // â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
                // BANNIÃˆRE — pleine largeur, 200 px, centrée
                // â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
                if (child.bannerBase64 != null &&
                    child.bannerBase64!.isNotEmpty) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: SizedBox(
                      height: 200,
                      width:  double.infinity,
                      child: child.isBannerUrl
                        ? Image.network(
                            child.bannerBase64!,
                            fit: BoxFit.cover,
                            alignment: Alignment.center,
                            errorBuilder: (_, __, ___) => Container(
                              color: EmeraldPalette.surfaceLow,
                              child: const Center(child: Icon(Icons.image, color: Colors.white24, size: 40)),
                            ),
                          )
                        : Image.memory(
                            base64Decode(child.bannerBase64!),
                            fit: BoxFit.cover,
                            alignment: Alignment.center,
                            errorBuilder: (_, __, ___) => Container(
                              color: EmeraldPalette.surfaceLow,
                              child: const Center(child: Icon(Icons.image, color: Colors.white24, size: 40)),
                            ),
                          ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                _buildAvatar(child, 52),
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
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(14),
                    border:
                        Border.all(color: color.withValues(alpha: 0.35)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.stars_rounded, color: color, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        '${child.points} points disponibles',
                        style: TextStyle(
                          color: color,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () => Navigator.of(context).push(
                    PageRouteBuilder<void>(
                      pageBuilder: (_, __, ___) =>
                          WalletScreen(childId: child.id),
                      transitionsBuilder: (_, animation, __, child) =>
                          FadeTransition(opacity: animation, child: child),
                      transitionDuration: const Duration(milliseconds: 240),
                    ),
                  ),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: EmeraldPalette.gold.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: EmeraldPalette.gold.withValues(alpha: 0.35),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.account_balance_wallet_rounded,
                            color: EmeraldPalette.gold, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Cagnotte SKS',
                                style: TextStyle(
                                  color: EmeraldPalette.gold,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${fp.getWalletForChild(child.id).balance} points cagnotte · indépendants des points de comportement',
                                style: const TextStyle(
                                  color: Colors.white60,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_right_rounded,
                            color: EmeraldPalette.gold),
                      ],
                    ),
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
                  side: BorderSide(color: color.withValues(alpha: 0.5)),
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
                  foregroundColor: color,
                  side: BorderSide(color: color.withValues(alpha: 0.5)),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                // Un seul bouton : PIN requis selon le mode (parent/enfant)
                onPressed: () => _editBanner(child, fp,
                    requirePin: context.read<PinProvider>().isParentMode),
                icon: const Icon(Icons.image, size: 16),
                label: const Text('Bannière', style: TextStyle(fontSize: 12)),
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
    final penalties = history.where((h) => h.isPenalty).length;
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
        _statCard(
            '\u{2B50}', 'Points disponibles', '${child.points} pts', color),        _statCard('🛡️', 'Immunités',
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

  // â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
  //  TAB ÉCRAN
  // â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
  Widget _buildPenaltyLinesAlert(
      ChildModel child, List<PunishmentLines> pendingLines) {
    final total = pendingLines.fold<int>(0, (sum, item) => sum + item.totalLines);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.red.shade900, Colors.deepOrange.shade700],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.orangeAccent, width: 2),
          boxShadow: [
            BoxShadow(
              color: Colors.red.withValues(alpha: 0.4),
              blurRadius: 18,
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(children: [
              Icon(Icons.warning_amber_rounded, color: Colors.white, size: 30),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Lignes de pénalité en attente',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ]),
            const SizedBox(height: 10),
            const Text(
              'L’accès aux écrans est interdit jusqu’à ce que tes lignes soient terminées et validées par un parent.',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 10),
            Text(
              '$total ligne${total > 1 ? 's' : ''} à faire',
              style: const TextStyle(
                color: Colors.amberAccent,
                fontWeight: FontWeight.w800,
              ),
            ),
            ...pendingLines.where((item) => item.text.trim().isNotEmpty).map(
              (item) => Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  '• ${item.totalLines} lignes : ${item.text}',
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const PunishmentLinesScreen()),
              ),
              icon: const Icon(Icons.visibility_rounded),
              label: Text('Voir les lignes de ${child.name}'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: const BorderSide(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

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
      padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top + kToolbarHeight + kTextTabBarHeight + 8, bottom: 24, left: 16, right: 16),
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
              _infoRow('🛡️ Immunités', '$immunityBonus lignes', Colors.amberAccent),
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
                            color: sel ? color.withValues(alpha: 0.25) : Colors.white10,
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
                    color: color.withValues(alpha: 0.8),
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
                    color: selected ? color.withValues(alpha: 0.25) : Colors.white10,
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
          color:  isActive ? color.withValues(alpha: 0.2) : Colors.white10,
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
          const Text('🛡️ Immunités disponibles',
              style: TextStyle(
                  color: Colors.amberAccent, fontWeight: FontWeight.bold,
                  fontSize: 14)),
          const SizedBox(height: 8),
          ...immunities.map((imm) => Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(children: [
              const Text('🛡️', style: TextStyle(fontSize: 16)),
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
                  backgroundColor: color.withValues(alpha: 0.2),
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

  // â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
  //  TAB HISTORIQUE
  // â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
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
    final penalties = allEntries.where((h) => h.isPenalty).length;

    return SingleChildScrollView(
      padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top + kToolbarHeight + kTextTabBarHeight + 8, bottom: 24, left: 16, right: 16),
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
                    color: sel ? color.withValues(alpha: 0.25) : Colors.white10,
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
    // 🔒 Utiliser isBonus (pas pts >= 0 qui est toujours vrai)
    final isBonus = e.isBonus;
    final sign  = isBonus ? '+' : '-';
    final ptsLabel = isBonus ? '$sign$pts pts' : '$sign$pts pts';

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

    final isParent = context.read<PinProvider>().isParentMode;

    return GestureDetector(
      onLongPress: isParent ? () => _showHistoryEditMenu(e) : null,
      child: Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        decoration: BoxDecoration(
          color:        cat.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(12),
          border:       Border.all(color: cat.withValues(alpha: 0.35), width: 1),
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
                Text(isBonus ? '+$pts pts' : '-$pts pts',
                    style: TextStyle(
                        color:      isBonus ? Colors.greenAccent : Colors.redAccent,
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
                const SizedBox(width: 8),
                const Text('·',
                    style: TextStyle(color: Colors.white24)),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    'par ${e.displayActorName}',
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: Colors.white38, fontSize: 11),
                  ),
                ),
              ]),
              if (e.hasProofPhoto) ...[
                const SizedBox(height: 8),
                HistoryProofPhoto(
                  entry: e,
                  height: 120,
                  width: double.infinity,
                ),
              ],
            ],
          ),
        ),
      ),
      ),
    );
  }

  // ─── Menu Modifier / Supprimer (mode parent) ───────────────
  void _showHistoryEditMenu(HistoryEntry e) {
    showModalBottomSheet(
      context: context,
      backgroundColor: EmeraldPalette.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.edit_outlined, color: Colors.blueAccent),
              title: const Text('Modifier',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
              subtitle: Text('Changer les points, la raison ou le type',
                  style: const TextStyle(color: Colors.white54, fontSize: 12)),
              onTap: () {
                Navigator.pop(ctx);
                _showHistoryEditDialog(e);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.redAccent),
              title: const Text('Supprimer',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
              subtitle: Text("Efface l'entrée et recalcule les points",
                  style: const TextStyle(color: Colors.white54, fontSize: 12)),
              onTap: () async {
                Navigator.pop(ctx);
                final confirm = await _confirmDialog(
                  title: 'Supprimer ?',
                  message: "Cette entrée (${e.isBonus ? '+' : '-'}${e.points} pts)"
                      "\nva être supprimée et les points de l'enfant recalculés.",
                  confirmLabel: 'Supprimer',
                  isDanger: true,
                );
                if (confirm == true) {
                  if (!mounted) return;
                  await context.read<FamilyProvider>().deleteHistoryEntry(e.id);
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('✅ Entrée supprimée, points recalculés'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                }
              },
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  void _showHistoryEditDialog(HistoryEntry e) {
    final ptsCtrl = TextEditingController(text: e.points.toString());
    final reasonCtrl = TextEditingController(text: e.reason);
    bool isBonus = e.isBonus;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => AlertDialog(
          backgroundColor: EmeraldPalette.surface,
          title: const Text("Modifier l'entrée",
              style: TextStyle(color: Colors.white)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Type toggle
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setSt(() => isBonus = true),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: isBonus
                                ? Colors.green.withValues(alpha: 0.25)
                                : Colors.white10,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isBonus
                                  ? Colors.greenAccent
                                  : Colors.white24,
                            ),
                          ),
                          child: Center(
                            child: Text('✅ Bonus',
                                style: TextStyle(
                                  color: isBonus
                                      ? Colors.greenAccent
                                      : Colors.white54,
                                  fontWeight: FontWeight.bold,
                                )),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setSt(() => isBonus = false),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: !isBonus
                                ? Colors.red.withValues(alpha: 0.25)
                                : Colors.white10,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: !isBonus
                                  ? Colors.redAccent
                                  : Colors.white24,
                            ),
                          ),
                          child: Center(
                            child: Text('❌ Pénalité',
                                style: TextStyle(
                                  color: !isBonus
                                      ? Colors.redAccent
                                      : Colors.white54,
                                  fontWeight: FontWeight.bold,
                                )),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: ptsCtrl,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                  decoration: const InputDecoration(
                    labelText: 'Points',
                    labelStyle: TextStyle(color: Colors.white54),
                    enabledBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: Colors.white24)),
                    focusedBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: Colors.blueAccent)),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: reasonCtrl,
                  style: const TextStyle(color: Colors.white),
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Raison',
                    labelStyle: TextStyle(color: Colors.white54),
                    enabledBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: Colors.white24)),
                    focusedBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: Colors.blueAccent)),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Annuler',
                  style: TextStyle(color: Colors.white54)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueAccent,
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                final pts = int.tryParse(ptsCtrl.text.trim()) ?? 0;
                final reason = reasonCtrl.text.trim();
                if (reason.isEmpty || pts == 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('⚠️ Raison et points requis')),
                  );
                  return;
                }
                Navigator.pop(ctx);
                await context.read<FamilyProvider>().editHistoryEntry(
                      entryId: e.id,
                      newPoints: pts.abs(),
                      newReason: reason,
                      isBonus: isBonus,
                    );
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('✅ Entrée modifiée'),
                      duration: Duration(seconds: 2)),
                );
              },
              child: const Text('Enregistrer'),
            ),
          ],
        ),
      ),
    );
  }

  Future<bool?> _confirmDialog({
    required String title,
    required String message,
    required String confirmLabel,
    bool isDanger = false,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: EmeraldPalette.surface,
        title: Text(title, style: const TextStyle(color: Colors.white)),
        content: Text(message, style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler',
                style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: isDanger ? Colors.redAccent : Colors.blueAccent,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
  }

  // â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
  //  TAB BADGES
  // â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
  Widget _buildBadgesTab(ChildModel child, FamilyProvider fp, Color color) {
    // 🛒 NOUVEAU : on remplace les badges par "Mes Récompenses" (boutique)
    final myPurchases = fp.purchases.where((p) => p['childId'] == child.id).toList();

    return SingleChildScrollView(
      padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top + kToolbarHeight + kTextTabBarHeight + 8, bottom: 24, left: 16, right: 16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // ─── Solde actuel ───
        Container(
          padding: const EdgeInsets.all(16),
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFFD4AF37), Color(0xFFB8860B)],
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(color: const Color(0xFFD4AF37).withValues(alpha: 0.3), blurRadius: 16),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.stars_rounded, color: Color(0xFF051410), size: 28),
                  const SizedBox(width: 8),
                  Text('Mes points', style: TextStyle(color: Color(0xFF051410), fontSize: 16, fontWeight: FontWeight.w600)),
                ],
              ),
              Text(
                '${child.points}',
                style: const TextStyle(
                  color: Color(0xFF051410),
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),

        // ─── Bouton vers la boutique ───
        GestureDetector(
          onTap: () {
            Navigator.push(context, MaterialPageRoute(
              builder: (_) => const ShopScreen(),
            ));
          },
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  color.withValues(alpha: 0.15),
                  Colors.transparent,
                ],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: color.withValues(alpha: 0.4)),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('🛒', style: TextStyle(fontSize: 24)),
                const SizedBox(width: 10),
                Text('Aller à la Boutique', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)),
                const SizedBox(width: 8),
                Icon(Icons.chevron_right_rounded, color: Colors.white70),
              ],
            ),
          ),
        ),

        // ─── Mes achats ───
        Text('📦 Mes achats (${myPurchases.length})',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
        const SizedBox(height: 10),

        if (myPurchases.isEmpty)
          Container(
            padding: const EdgeInsets.all(32),
            child: const Column(
              children: [
                Text('🛍️', style: TextStyle(fontSize: 48)),
                const SizedBox(height: 12),
                Text('Aucun achat pour l\'instant',
                    style: TextStyle(color: Colors.white38, fontSize: 14)),
                const SizedBox(height: 4),
                Text('Va à la boutique pour dépenser tes points !',
                    style: TextStyle(color: Colors.white24, fontSize: 12)),
              ],
            ),
          )
        else
          ...myPurchases.map((p) => _buildPurchaseCard(p, color)),
      ]),
    );
  }

  Widget _buildPurchaseCard(Map<String, dynamic> purchase, Color color) {
    final title = purchase['title'] ?? '';
    final icon = purchase['icon'] ?? '🎁';
    final cost = purchase['cost'] ?? 0;
    final status = purchase['status'] ?? 'pending';
    final dateStr = purchase['date'] ?? '';

    // Formater la date
    String formattedDate = '';
    try {
      final dt = DateTime.parse(dateStr);
      formattedDate = '${dt.day}/${dt.month} à ${dt.hour}h${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {}

    // Couleur selon le statut
    Color statusColor;
    String statusText;
    IconData statusIcon;
    switch (status) {
      case 'approved':
        statusColor = const Color(0xFF00E676);
        statusText = 'Validé';
        statusIcon = Icons.check_circle_rounded;
        break;
      case 'rejected':
        statusColor = const Color(0xFFEF4444);
        statusText = 'Refusé';
        statusIcon = Icons.cancel_rounded;
        break;
      default:
        statusColor = const Color(0xFFF59E0B);
        statusText = 'En attente';
        statusIcon = Icons.hourglass_top_rounded;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF0F2620),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: statusColor.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 8, offset: const Offset(0, 3)),
        ],
      ),
      child: Row(
        children: [
          // Icône
          Container(
            width: 48, height: 48,
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(child: Text(icon, style: const TextStyle(fontSize: 24))),
          ),
          const SizedBox(width: 12),
          // Infos
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14)),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Icon(statusIcon, size: 14, color: statusColor),
                    const SizedBox(width: 4),
                    Text(statusText, style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.w600)),
                    const SizedBox(width: 8),
                    Text(formattedDate, style: const TextStyle(color: Colors.white24, fontSize: 10)),
                  ],
                ),
              ],
            ),
          ),
          // Coût
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0xFFD4AF37).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFD4AF37).withValues(alpha: 0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.stars_rounded, size: 14, color: Color(0xFFD4AF37)),
                const SizedBox(width: 3),
                Text('$cost', style: const TextStyle(color: Color(0xFFD4AF37), fontSize: 12, fontWeight: FontWeight.w800)),
              ],
            ),
          ),
        ],
      ),
    );
  }

}



