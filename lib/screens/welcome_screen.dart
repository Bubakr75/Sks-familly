// lib/screens/welcome_screen.dart

import 'dart:ui';
import '../utils/image_cache_util.dart';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import '../models/child_model.dart';
import '../providers/family_provider.dart';
import '../providers/pin_provider.dart';
import '../widgets/tv_focus_wrapper.dart';
import '../widgets/animated_background.dart';
import '../utils/tv_detector.dart';
import 'home_screen.dart';
import 'child_dashboard_screen.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});
  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> with TickerProviderStateMixin {
  late AnimationController _logoController, _pulseController, _buttonController, _particleController, _cardController;
  late Animation<double> _logoFade, _logoScale, _pulseAnim, _btn1Slide, _btn2Slide, _cardFade;
  final List<_WelcomeParticle> _particles = [];
  final _rng = math.Random();
  String? _selectedProfileId;
  late VideoPlayerController _videoBgController;
  late AnimationController _introController;
  bool _introDone = false;
  String _pinInput = '';
  int _failedAttempts = 0;
  bool _pinError = false;
  List<String> _customParents = [];

  @override
  void initState() {
    super.initState();
    _logoController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500));
    _logoFade = CurvedAnimation(parent: _logoController, curve: const Interval(0.0, 0.5, curve: Curves.easeIn));
    _logoScale = CurvedAnimation(parent: _logoController, curve: const Interval(0.1, 0.7, curve: Curves.elasticOut));
    _pulseController = AnimationController(vsync: this, duration: const Duration(milliseconds: 2000))..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.4, end: 1.0).animate(CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut));
    _buttonController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200));
    _btn1Slide = CurvedAnimation(parent: _buttonController, curve: const Interval(0.0, 0.6, curve: Curves.easeOutBack));
    _btn2Slide = CurvedAnimation(parent: _buttonController, curve: const Interval(0.2, 0.8, curve: Curves.easeOutBack));
    _cardController = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _cardFade = CurvedAnimation(parent: _cardController, curve: Curves.easeOut);
    _introController = AnimationController(vsync: this, duration: const Duration(seconds: 19))..forward().then((_) { if (mounted) setState(() => _introDone = true); });
    _videoBgController = VideoPlayerController.asset('assets/videos/family_bg.mp4')
      ..initialize().then((_) {
        _videoBgController.setLooping(true);
        _videoBgController.setVolume(1.0);
        _videoBgController.play();
        // Listener pour relancer avant la fin et eviter le freeze
        _videoBgController.addListener(() {
          final pos = _videoBgController.value.position;
          final dur = _videoBgController.value.duration;
          if (dur.inMilliseconds > 0 && pos.inMilliseconds > dur.inMilliseconds - 150) {
            _videoBgController.seekTo(Duration.zero);
          }
        });
        if (mounted) setState(() {});
      });
    _particleController = AnimationController(vsync: this, duration: const Duration(seconds: 10))..repeat();
    for (int i = 0; i < 40; i++) { _particles.add(_WelcomeParticle(_rng)); }
    _loadCustomParents();
    _logoController.forward();
    Future.delayed(const Duration(milliseconds: 800), () { if (mounted) _buttonController.forward(); });
    Future.delayed(const Duration(milliseconds: 1200), () { if (mounted) _cardController.forward(); });
  }

  @override
  void dispose() { _logoController.dispose(); _pulseController.dispose(); _buttonController.dispose(); _introController.dispose();
    _videoBgController.dispose();
    _particleController.dispose(); _cardController.dispose(); super.dispose(); }

  void _selectProfile(String id) { setState(() { _selectedProfileId = id; _pinInput = ''; _pinError = false; _failedAttempts = 0; }); }
  void _onPinDigit(String d) { if (_pinInput.length >= 6) return; setState(() { _pinInput += d; _pinError = false; }); if (_pinInput.length == 4) Future.delayed(const Duration(milliseconds: 200), () { if (mounted) _validateTvPin(); }); }
  void _onPinBackspace() { if (_pinInput.isEmpty) return; setState(() { _pinInput = _pinInput.substring(0, _pinInput.length - 1); _pinError = false; }); }
  void _validateTvPin() {
    final fp = context.read<FamilyProvider>(); final pin = context.read<PinProvider>();
    if (_selectedProfileId == 'parent_maman' || _selectedProfileId == 'parent_papa' || _selectedProfileId == 'parent') {
      if (!pin.isPinSet) { _loginAsParent(_getParentName()); return; }
      if (pin.verifyPin(_pinInput)) {
        _loginAsParent(_getParentName());
      } else {
        _handlePinError();
      }
    } else {
      final child = fp.children.firstWhere((c) => c.id == _selectedProfileId, orElse: () => ChildModel(id: '', name: ''));
      if (child.id.isEmpty) return;
      if (!child.hasPinSet) { _loginAsChild(child.id); return; }
      if (child.verifyPin(_pinInput)) {
        _loginAsChild(child.id);
      } else {
        _handlePinError();
      }
    }
  }
  String _getParentName() { if (_selectedProfileId == 'parent_maman') return 'Maman'; if (_selectedProfileId == 'parent_papa') return 'Papa'; return 'Parent'; }
  void _handlePinError() { setState(() { _pinError = true; _failedAttempts++; _pinInput = ''; }); HapticFeedback.heavyImpact(); }
  void _loginAsParent(String name) { context.read<PinProvider>().unlockParentMode(); context.read<FamilyProvider>().setCurrentParent(name); Navigator.pushReplacement(context, PageRouteBuilder(pageBuilder: (_, __, ___) => const HomeScreen(), transitionsBuilder: (_, a, __, c) => FadeTransition(opacity: a, child: c), transitionDuration: const Duration(milliseconds: 500))); }
  void _loginAsChild(String childId) { context.read<PinProvider>().enterChildMode(); Navigator.pushReplacement(context, PageRouteBuilder(pageBuilder: (_, __, ___) => const HomeScreen(), transitionsBuilder: (_, a, __, c) => FadeTransition(opacity: a, child: c), transitionDuration: const Duration(milliseconds: 400))); WidgetsBinding.instance.addPostFrameCallback((_) { if (mounted) Navigator.push(context, MaterialPageRoute(builder: (_) => ChildDashboardScreen(childId: childId))); }); }
  void _goBackToProfiles() { setState(() { _selectedProfileId = null; _pinInput = ''; _pinError = false; _failedAttempts = 0; }); }


  Future<void> _loadCustomParents() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList('custom_parents') ?? [];
    if (mounted) setState(() => _customParents = list);
  }

  Future<void> _addCustomParent(String name) async {
    if (name.trim().isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    _customParents.add(name.trim());
    await prefs.setStringList('custom_parents', _customParents);
    if (mounted) setState(() {});
  }

  Future<void> _removeCustomParent(String name) async {
    final prefs = await SharedPreferences.getInstance();
    _customParents.remove(name);
    await prefs.setStringList('custom_parents', _customParents);
    if (mounted) setState(() {});
  }

  void _showAddParentDialog() {
    final ctrl = TextEditingController();
    final isTV = TvDetector.isTV;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0D1B2A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(children: [
          Icon(Icons.person_add_rounded, color: const Color(0xFF00E5FF), size: isTV ? 32 : 24),
          const SizedBox(width: 8),
          Text('Nouveau profil parent', style: TextStyle(color: Colors.white, fontSize: isTV ? 24 : 18)),
        ]),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('Entrez le nom du parent', style: TextStyle(color: Colors.white70, fontSize: isTV ? 18 : 14)),
          const SizedBox(height: 16),
          TvTextField(
            controller: ctrl,
            autofocus: true,
            keyboardTitle: 'Nom du parent',
            style: TextStyle(color: Colors.white, fontSize: isTV ? 22 : 16),
            decoration: InputDecoration(
              hintText: 'Ex: Tonton, Mamie...',
              hintStyle: TextStyle(color: Colors.white30, fontSize: isTV ? 20 : 14),
              prefixIcon: const Icon(Icons.person_rounded, color: Color(0xFF00E5FF)),
            ),
            onSubmitted: (val) {
              if (val.trim().isNotEmpty) { _addCustomParent(val.trim()); Navigator.pop(ctx); }
            },
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx),
            child: Text('Annuler', style: TextStyle(color: Colors.grey[400], fontSize: isTV ? 18 : 14))),
          FilledButton(onPressed: () {
            if (ctrl.text.trim().isNotEmpty) { _addCustomParent(ctrl.text.trim()); Navigator.pop(ctx); }
          }, child: Text('Ajouter', style: TextStyle(fontSize: isTV ? 18 : 14))),
        ],
      ),
    );
  }
  void _handleParentMode() { final pin = context.read<PinProvider>(); if (!pin.isPinSet) {
    _navigateToHome('Parent');
  } else {
    _showPinDialog();
  } }
  void _showPinDialog() {
    final pinCtrl = TextEditingController(); bool obscure = true;
    showDialog(context: context, builder: (ctx) => StatefulBuilder(builder: (ctx, setS) => AlertDialog(
      backgroundColor: const Color(0xFF0D1B2A), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: const Row(children: [Icon(Icons.lock_rounded, color: Colors.amber, size: 24), SizedBox(width: 8), Text('Code Parental', style: TextStyle(color: Colors.white, fontSize: 20))]),
      content: Column(mainAxisSize: MainAxisSize.min, children: [const Text('Entrez votre code PIN', style: TextStyle(color: Colors.white70, fontSize: 14)), const SizedBox(height: 16),
        SizedBox(width: 250, child: TextField(controller: pinCtrl, obscureText: obscure, keyboardType: TextInputType.number, maxLength: 6, autofocus: true, textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 24, letterSpacing: 8, color: Colors.white),
          decoration: InputDecoration(counterText: '', hintText: '* * * *', hintStyle: const TextStyle(fontSize: 24, letterSpacing: 8, color: Colors.white30),
            suffixIcon: IconButton(icon: Icon(obscure ? Icons.visibility_off_rounded : Icons.visibility_rounded, color: Colors.white54), onPressed: () => setS(() => obscure = !obscure))),
          onSubmitted: (_) => _validatePinMobile(ctx, pinCtrl)))]),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Annuler', style: TextStyle(color: Colors.grey[400]))), FilledButton(onPressed: () => _validatePinMobile(ctx, pinCtrl), child: const Text('Valider'))])));
  }
  void _validatePinMobile(BuildContext ctx, TextEditingController ctrl) {
    if (context.read<PinProvider>().verifyPin(ctrl.text.trim())) { Navigator.pop(ctx); _showParentPicker(); }
    else { ctrl.clear(); HapticFeedback.heavyImpact(); ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: const Row(children: [Icon(Icons.error_rounded, color: Colors.white), SizedBox(width: 8), Text('Code PIN incorrect')]), backgroundColor: Colors.red.shade700, behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)))); }
  }
  void _showParentPicker() {
    showModalBottomSheet(context: context, backgroundColor: const Color(0xFF0D1B2A), shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[700], borderRadius: BorderRadius.circular(2))),
        const SizedBox(height: 16), const Text('Qui etes-vous ?', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)), const SizedBox(height: 16),
        ...['Maman', 'Papa', 'Parent'].map((p) => ListTile(leading: CircleAvatar(backgroundColor: const Color(0xFF00E5FF).withOpacity(0.15), child: const Icon(Icons.person_rounded, color: Color(0xFF00E5FF))),
          title: Text(p, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)), onTap: () { Navigator.pop(ctx); _navigateToHome(p); })), const SizedBox(height: 8)])));
  }
  void _navigateToHome(String parentName) { context.read<PinProvider>().unlockParentMode(); context.read<FamilyProvider>().setCurrentParent(parentName); Navigator.pushReplacement(context, PageRouteBuilder(pageBuilder: (_, __, ___) => const HomeScreen(), transitionsBuilder: (_, a, __, c) => FadeTransition(opacity: a, child: c), transitionDuration: const Duration(milliseconds: 500))); }
  void _handleChildMode() {
    final fp = context.read<FamilyProvider>(); final pin = context.read<PinProvider>();
    if (fp.children.isEmpty) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Aucun enfant enregistre.'), behavior: SnackBarBehavior.floating)); return; }
    pin.enterChildMode(); if (fp.children.length == 1) { _navigateToChildDashboard(fp.children.first.id); return; } _showChildPicker(fp.children);
  }
  void _navigateToChildDashboard(String childId) {
    Navigator.pushReplacement(context, PageRouteBuilder(pageBuilder: (_, __, ___) => const HomeScreen(), transitionsBuilder: (_, a, __, c) => FadeTransition(opacity: a, child: c), transitionDuration: const Duration(milliseconds: 400)));
    WidgetsBinding.instance.addPostFrameCallback((_) { if (mounted) Navigator.push(context, MaterialPageRoute(builder: (_) => ChildDashboardScreen(childId: childId))); });
  }
  void _showChildPicker(List<ChildModel> children) {
    showModalBottomSheet(context: context, backgroundColor: Colors.transparent, isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(initialChildSize: 0.55, minChildSize: 0.35, maxChildSize: 0.92, expand: false,
        builder: (_, sc) => Container(decoration: const BoxDecoration(color: Color(0xFF0D1B2A), borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
          child: Column(children: [const SizedBox(height: 12), Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[700], borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 16), const Text('Qui es-tu ?', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)), const SizedBox(height: 12),
            Expanded(child: ListView.builder(controller: sc, padding: const EdgeInsets.fromLTRB(16, 0, 16, 24), itemCount: children.length, itemBuilder: (_, i) {
              final child = children[i];
              return Padding(padding: const EdgeInsets.only(bottom: 10), child: ListTile(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)), tileColor: const Color(0xFF7C4DFF).withOpacity(0.08),
                leading: CircleAvatar(backgroundColor: const Color(0xFF7C4DFF).withOpacity(0.15), radius: 24,
                  child: child.hasPhoto ? ClipOval(child: Image.memory(ImageCacheUtil.fromBase64(child.photoBase64), width: 48, height: 48, fit: BoxFit.cover)) : Text(child.avatar.isEmpty ? '?' : child.avatar, style: const TextStyle(fontSize: 22))),
                title: Text(child.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 16)),
                subtitle: Text('${child.points} pts - Nv.${child.currentLevelNumber}', style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                trailing: const Icon(Icons.chevron_right, color: Colors.white38), onTap: () { Navigator.pop(ctx); _navigateToChildDashboard(child.id); })); }))]))));
  }
  void _showInteractiveHelp() {
    showDialog(context: context, builder: (ctx) => AlertDialog(backgroundColor: const Color(0xFF1A1A2E), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: const Text('Comment utiliser SKS Family ?', style: TextStyle(color: Colors.white, fontSize: 18)),
      content: const SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Mode Parent', style: TextStyle(color: Colors.cyan, fontWeight: FontWeight.bold, fontSize: 14)), SizedBox(height: 8),
        Text('Gere les points, taches, punitions et recompenses', style: TextStyle(color: Colors.white70, fontSize: 14)), SizedBox(height: 16),
        Text('Mode Enfant', style: TextStyle(color: Color(0xFF7C4DFF), fontWeight: FontWeight.bold, fontSize: 14)), SizedBox(height: 8),
        Text('Voit ses points et badges, suit ses objectifs', style: TextStyle(color: Colors.white70, fontSize: 14)), SizedBox(height: 20),
        Text('Le mode Parent est protege par un code PIN.', style: TextStyle(color: Colors.amber, fontStyle: FontStyle.italic, fontSize: 14))])),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Fermer', style: TextStyle(color: Colors.white70)))]));
  }

  @override
  Widget build(BuildContext context) { final size = MediaQuery.of(context).size; if (TvDetector.isTV) return _buildTvLogin(size); return _buildMobileLayout(size); }

  Widget _buildTvLogin(Size size) {
    return Scaffold(backgroundColor: Colors.black, body: Stack(children: [
      // Video de fond
      if (_videoBgController.value.isInitialized)
        SizedBox.expand(child: FittedBox(fit: BoxFit.cover, child: SizedBox(
          width: _videoBgController.value.size.width,
          height: _videoBgController.value.size.height,
          child: VideoPlayer(_videoBgController)))),
      // Overlay sombre pour lisibilite
      Container(color: Colors.black.withOpacity(0.55)),
      SafeArea(child: Stack(children: [
      AnimatedBuilder(animation: _particleController, builder: (_, __) => CustomPaint(size: Size(size.width, size.height), painter: _WelcomeParticlePainter(particles: _particles, time: _particleController.value))),
      _selectedProfileId == null ? _buildProfileCarousel(size) : _buildPinPad(size)]))]));
  }

  Widget _buildProfileCarousel(Size size) {
    final fp = context.watch<FamilyProvider>(); final pin = context.read<PinProvider>();
    final List<_ProfileItem> profiles = [];
    profiles.add(_ProfileItem(id: 'parent_maman', name: 'Maman', icon: Icons.face_3_rounded, color: const Color(0xFF00E5FF), isParent: true));
    profiles.add(_ProfileItem(id: 'parent_papa', name: 'Papa', icon: Icons.face_rounded, color: const Color(0xFF00E5FF), isParent: true));
    for (final name in _customParents) {
      profiles.add(_ProfileItem(id: 'parent_custom_$name', name: name, icon: Icons.person_rounded, color: const Color(0xFF00E5FF), isParent: true));
    }
    for (final child in fp.children) {
      profiles.add(_ProfileItem(id: child.id, name: child.name, icon: Icons.child_care_rounded,
        color: const Color(0xFF7C4DFF), isParent: false,
        photoBase64: child.hasPhoto ? child.photoBase64 : null,
        avatar: child.avatar, hasPinSet: child.hasPinSet));
    }

    return AnimatedBuilder(
      animation: _introController,
      builder: (context, _) {
        // Phase: 0.0-0.7 = cotes, 0.7-1.0 = transition vers centre
        final t = _introController.value;
        final phase2 = t < 0.86 ? 0.0 : ((t - 0.86) / 0.14).clamp(0.0, 1.0);
        final phase2Curve = Curves.easeOutBack.transform(phase2);

        // Taille des profils: petit (80) -> grand (130)
        final profileSize = 80 + (50 * phase2Curve);
        final fontSize = 14.0 + (6.0 * phase2Curve);
        final iconSize = 36.0 + (22.0 * phase2Curve);
        final emojiSize = 32.0 + (20.0 * phase2Curve);
        final spacing = 12.0 + (8.0 * phase2Curve);

        // Opacite du titre: apparait en phase 2
        final titleOpacity = phase2Curve;
        // Opacite des profils: toujours visibles
        final profileOpacity = (t / 0.3).clamp(0.0, 1.0);

        if (phase2Curve < 0.95) {
          // === PHASE 1 : Profils sur les cotes ===
          final half = (profiles.length / 2).ceil();
          final leftProfiles = profiles.sublist(0, half);
          final rightProfiles = profiles.sublist(half);

          return Opacity(opacity: profileOpacity, child: Stack(children: [
            // Titre centre (apparait progressivement)
            Center(child: Opacity(opacity: titleOpacity, child: Column(mainAxisSize: MainAxisSize.min, children: [
              ShaderMask(shaderCallback: (b) => const LinearGradient(colors: [Color(0xFF00E5FF), Colors.white, Color(0xFF7C4DFF)]).createShader(b),
                child: const Text('SKS Family', style: TextStyle(fontSize: 42, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 2))),
              const SizedBox(height: 10),
              Text('Qui se connecte ?', style: TextStyle(fontSize: 22, color: Colors.grey[300], letterSpacing: 1)),
            ]))),

            // Profils GAUCHE
            Positioned(left: 30 + (phase2Curve * 50), top: 0, bottom: 0,
              child: Column(mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: leftProfiles.asMap().entries.map((entry) {
                  final p = entry.value;
                  final glowColor = p.isParent ? const Color(0xFF00E5FF) : const Color(0xFF7C4DFF);
                  return _buildAnimatedProfile(p, glowColor, profileSize, fontSize, iconSize, emojiSize, pin, autofocus: entry.key == 0);
                }).toList())),

            // Profils DROITE
            Positioned(right: 30 + (phase2Curve * 50), top: 0, bottom: 0,
              child: Column(mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: rightProfiles.asMap().entries.map((entry) {
                  final p = entry.value;
                  final glowColor = p.isParent ? const Color(0xFF00E5FF) : const Color(0xFF7C4DFF);
                  return _buildAnimatedProfile(p, glowColor, profileSize, fontSize, iconSize, emojiSize, pin, autofocus: false);
                }).toList())),
          ]));
        } else {
          // === PHASE 2 TERMINEE : Layout carrousel classique ===
          return Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Spacer(flex: 3),
            ShaderMask(shaderCallback: (b) => const LinearGradient(colors: [Color(0xFF00E5FF), Colors.white, Color(0xFF7C4DFF)]).createShader(b),
              child: const Text('SKS Family', style: TextStyle(fontSize: 42, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 2))),
            const SizedBox(height: 10),
            Text('Qui se connecte ?', style: TextStyle(fontSize: 22, color: Colors.grey[300], letterSpacing: 1)),
            const SizedBox(height: 50),
            SizedBox(height: 230, child: TvFocusScope(child: SingleChildScrollView(scrollDirection: Axis.horizontal,
              padding: EdgeInsets.symmetric(horizontal: (size.width - 160) / 2),
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: profiles.asMap().entries.map((entry) {
                final i = entry.key; final p = entry.value;
                final glowColor = p.isParent ? const Color(0xFF00E5FF) : const Color(0xFF7C4DFF);
                return Padding(padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: TvFocusWrapper(autofocus: i == 0, focusScale: 1.15, onTap: () => _selectProfile(p.id),
                    child: SizedBox(width: 160, child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Container(width: 130, height: 130,
                        decoration: BoxDecoration(shape: BoxShape.circle,
                          border: Border.all(color: glowColor.withOpacity(0.7), width: 2.5),
                          boxShadow: [BoxShadow(color: glowColor.withOpacity(0.3), blurRadius: 24, spreadRadius: 4)]),
                        child: ClipOval(child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                          child: Container(
                            decoration: BoxDecoration(shape: BoxShape.circle,
                              gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight,
                                colors: [Colors.white.withOpacity(0.12), glowColor.withOpacity(0.06)])),
                            child: p.photoBase64 != null
                              ? Opacity(opacity: 0.85, child: Image.memory(ImageCacheUtil.fromBase64(p.photoBase64!), fit: BoxFit.cover, width: 130, height: 130))
                              : p.avatar != null && p.avatar!.isNotEmpty
                                ? Center(child: Text(p.avatar!, style: const TextStyle(fontSize: 52)))
                                : Icon(p.icon, color: glowColor.withOpacity(0.9), size: 58))))),
                      const SizedBox(height: 16),
                      Text(p.name, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700), maxLines: 1, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 4),
                      Row(mainAxisAlignment: MainAxisAlignment.center, mainAxisSize: MainAxisSize.min, children: [
                        Text(p.isParent ? 'Parent' : 'Enfant', style: TextStyle(color: p.color.withOpacity(0.7), fontSize: 13)),
                        if ((p.isParent && pin.isPinSet) || p.hasPinSet) ...[const SizedBox(width: 6), Icon(Icons.lock_rounded, color: Colors.amber.withOpacity(0.8), size: 13)]])]))));
              }).toList())))),
            const SizedBox(height: 30),
            FadeTransition(opacity: _cardFade, child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.chevron_left_rounded, color: Colors.white.withOpacity(0.2), size: 24), const SizedBox(width: 6),
              Text('\u25C0  \u25B6', style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 16, letterSpacing: 8)), const SizedBox(width: 6),
              Icon(Icons.chevron_right_rounded, color: Colors.white.withOpacity(0.2), size: 24)])),
            const Spacer(flex: 4)]);
        }
      },
    );
  }

  Widget _buildAnimatedProfile(_ProfileItem p, Color glowColor, double profileSize, double fontSize, double iconSize, double emojiSize, PinProvider pin, {bool autofocus = false}) {
    return TvFocusWrapper(autofocus: autofocus, onTap: () => _selectProfile(p.id),
      child: SizedBox(width: profileSize + 30, child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(width: profileSize, height: profileSize,
          decoration: BoxDecoration(shape: BoxShape.circle,
            border: Border.all(color: glowColor.withOpacity(0.7), width: 2),
            boxShadow: [BoxShadow(color: glowColor.withOpacity(0.3), blurRadius: 16, spreadRadius: 2)]),
          child: ClipOval(child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
            child: Container(
              decoration: BoxDecoration(shape: BoxShape.circle,
                gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight,
                  colors: [Colors.white.withOpacity(0.12), glowColor.withOpacity(0.06)])),
              child: p.photoBase64 != null
                ? Opacity(opacity: 0.85, child: Image.memory(ImageCacheUtil.fromBase64(p.photoBase64!), fit: BoxFit.cover, width: profileSize, height: profileSize))
                : p.avatar != null && p.avatar!.isNotEmpty
                  ? Center(child: Text(p.avatar!, style: TextStyle(fontSize: emojiSize)))
                  : Icon(p.icon, color: glowColor.withOpacity(0.9), size: iconSize))))),
        SizedBox(height: fontSize * 0.4),
        Text(p.name, style: TextStyle(color: Colors.white, fontSize: fontSize, fontWeight: FontWeight.w700), maxLines: 1, overflow: TextOverflow.ellipsis),
        Row(mainAxisAlignment: MainAxisAlignment.center, mainAxisSize: MainAxisSize.min, children: [
          Text(p.isParent ? 'Parent' : 'Enfant', style: TextStyle(color: p.color.withOpacity(0.7), fontSize: fontSize * 0.65)),
          if ((p.isParent && pin.isPinSet) || p.hasPinSet) ...[const SizedBox(width: 4), Icon(Icons.lock_rounded, color: Colors.amber.withOpacity(0.8), size: fontSize * 0.65)]])])));
  }


  Widget _buildPinPad(Size size) {
    final fp = context.watch<FamilyProvider>(); final pin = context.read<PinProvider>();
    bool pinRequired = false; String profileName = '';
    if (_selectedProfileId == 'parent_maman' || _selectedProfileId == 'parent_papa' || _selectedProfileId == 'parent') { pinRequired = pin.isPinSet; profileName = _getParentName(); }
    else { final child = fp.children.firstWhere((c) => c.id == _selectedProfileId, orElse: () => ChildModel(id: '', name: '')); pinRequired = child.hasPinSet; profileName = child.name; }
    if (!pinRequired) { WidgetsBinding.instance.addPostFrameCallback((_) { if (mounted) _validateTvPin(); }); return const Center(child: CircularProgressIndicator(color: Color(0xFF00E5FF))); }
    return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Align(alignment: Alignment.topLeft, child: Padding(padding: const EdgeInsets.only(left: 40, top: 20),
        child: TvFocusWrapper(onTap: _goBackToProfiles, child: Container(padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), color: Colors.white.withOpacity(0.05), border: Border.all(color: Colors.white.withOpacity(0.1))),
          child: const Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.arrow_back_rounded, color: Colors.white70, size: 24), SizedBox(width: 8), Text('Retour', style: TextStyle(color: Colors.white70, fontSize: 18))]))))),
      const Spacer(),
      Text(profileName, style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.w800)), const SizedBox(height: 8),
      Text('Entrez votre code PIN', style: TextStyle(color: Colors.grey[400], fontSize: 20)), const SizedBox(height: 24),
      Row(mainAxisAlignment: MainAxisAlignment.center, children: List.generate(4, (i) { final filled = i < _pinInput.length;
        return AnimatedContainer(duration: const Duration(milliseconds: 200), margin: const EdgeInsets.symmetric(horizontal: 10), width: 28, height: 28,
          decoration: BoxDecoration(shape: BoxShape.circle, color: _pinError ? Colors.red.withOpacity(filled ? 1.0 : 0.3) : filled ? const Color(0xFF00E5FF) : Colors.white.withOpacity(0.15),
            border: Border.all(color: _pinError ? Colors.red : const Color(0xFF00E5FF).withOpacity(0.5), width: 2),
            boxShadow: filled && !_pinError ? [BoxShadow(color: const Color(0xFF00E5FF).withOpacity(0.5), blurRadius: 10)] : null)); })),
      if (_pinError) ...[const SizedBox(height: 12), Text(_failedAttempts >= 3 ? 'Trop de tentatives ($_failedAttempts)' : 'Code incorrect', style: const TextStyle(color: Colors.red, fontSize: 16))],
      const SizedBox(height: 40),
      TvFocusScope(child: SizedBox(width: 320, child: Column(children: [
        _buildPinRow(['1', '2', '3']), const SizedBox(height: 12), _buildPinRow(['4', '5', '6']), const SizedBox(height: 12),
        _buildPinRow(['7', '8', '9']), const SizedBox(height: 12), _buildPinRow(['\u232B', '0', '\u2713'])]))),
      const Spacer()]));
  }

  Widget _buildPinRow(List<String> keys) {
    return Row(mainAxisAlignment: MainAxisAlignment.center, children: keys.map((key) { final isBack = key == '\u232B'; final isOk = key == '\u2713';
      return Padding(padding: const EdgeInsets.symmetric(horizontal: 8), child: TvFocusWrapper(autofocus: key == '5',
        onTap: () { if (isBack) {
          _onPinBackspace();
        } else if (isOk) _validateTvPin(); else _onPinDigit(key); },
        child: Container(width: 80, height: 80, decoration: BoxDecoration(borderRadius: BorderRadius.circular(16),
          color: isBack ? Colors.orange.withOpacity(0.1) : isOk ? Colors.green.withOpacity(0.1) : Colors.white.withOpacity(0.06),
          border: Border.all(color: isBack ? Colors.orange.withOpacity(0.4) : isOk ? Colors.green.withOpacity(0.4) : Colors.white.withOpacity(0.15), width: 2)),
          child: Center(child: isBack ? const Icon(Icons.backspace_rounded, color: Colors.orange, size: 32)
            : isOk ? const Icon(Icons.check_rounded, color: Colors.green, size: 36)
            : Text(key, style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w700)))))); }).toList());
  }

  Widget _buildMobileLayout(Size size) {
    return AnimatedBackground(child: Scaffold(backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.small(onPressed: _showInteractiveHelp, backgroundColor: Colors.cyan.withOpacity(0.85),
        child: const Icon(Icons.help_outline_rounded, color: Colors.white)),
      body: SafeArea(child: Stack(children: [
        AnimatedBuilder(animation: _particleController, builder: (_, __) => CustomPaint(
          size: Size(size.width, size.height), painter: _WelcomeParticlePainter(particles: _particles, time: _particleController.value))),
        SingleChildScrollView(physics: const BouncingScrollPhysics(), child: Column(children: [
          const SizedBox(height: 32),
          FadeTransition(opacity: _logoFade, child: ScaleTransition(scale: _logoScale,
            child: AnimatedBuilder(animation: _pulseAnim, builder: (_, __) => Container(width: 110, height: 110,
              decoration: BoxDecoration(shape: BoxShape.circle,
                gradient: const LinearGradient(colors: [Color(0xFF00E5FF), Color(0xFF7C4DFF)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                boxShadow: [BoxShadow(color: const Color(0xFF00E5FF).withOpacity(_pulseAnim.value * 0.5), blurRadius: 30, spreadRadius: 5)]),
              child: const Center(child: Text('\u{1F3E0}', style: TextStyle(fontSize: 48))))))),
          const SizedBox(height: 20),
          FadeTransition(opacity: _logoFade, child: ShaderMask(
            shaderCallback: (b) => const LinearGradient(colors: [Color(0xFF00E5FF), Colors.white, Color(0xFF7C4DFF)]).createShader(b),
            child: const Text('SKS Family', style: TextStyle(fontSize: 38, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 2)))),
          const SizedBox(height: 6),
          FadeTransition(opacity: _logoFade, child: Text('Le systeme de points familial', style: TextStyle(fontSize: 14, color: Colors.grey[400], letterSpacing: 1))),
          const SizedBox(height: 28),
          Consumer<FamilyProvider>(builder: (_, fp, __) {
            if (fp.children.isEmpty) {
              return FadeTransition(opacity: _cardFade, child: Padding(padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(borderRadius: BorderRadius.circular(20),
                color: Colors.white.withOpacity(0.04), border: Border.all(color: Colors.white.withOpacity(0.08))),
                child: Column(children: [const Text('\u{1F476}', style: TextStyle(fontSize: 36)), const SizedBox(height: 8),
                  Text('Aucun enfant enregistre', style: TextStyle(color: Colors.grey[400], fontSize: 14)), const SizedBox(height: 4),
                  Text('Connectez-vous en mode Parent\npour commencer', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey[600], fontSize: 12))]))));
            }
            final sorted = List<ChildModel>.from(fp.children)..sort((a, b) => b.points.compareTo(a.points));
            return FadeTransition(opacity: _cardFade, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Padding(padding: const EdgeInsets.symmetric(horizontal: 24), child: Row(children: [
                const Text('\u{1F3C6} ', style: TextStyle(fontSize: 16)),
                Text('Classement de la famille', style: TextStyle(color: Colors.grey[400], fontSize: 13, fontWeight: FontWeight.w600, letterSpacing: 0.5))])),
              const SizedBox(height: 10),
              SizedBox(height: 130, child: ListView.builder(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: sorted.length, itemBuilder: (_, i) => _ChildStatCard(child: sorted[i], rank: i + 1, delay: i * 100, isTV: false)))]));
          }),
          const SizedBox(height: 24),
          SlideTransition(position: Tween<Offset>(begin: const Offset(-1, 0), end: Offset.zero).animate(_btn1Slide),
            child: Padding(padding: const EdgeInsets.symmetric(horizontal: 28), child: GestureDetector(onTap: _handleParentMode,
              child: Container(width: double.infinity, height: 62, decoration: BoxDecoration(borderRadius: BorderRadius.circular(20),
                gradient: const LinearGradient(colors: [Color(0xFF00E5FF), Color(0xFF0090B5)]),
                boxShadow: [BoxShadow(color: const Color(0xFF00E5FF).withOpacity(0.35), blurRadius: 20, offset: const Offset(0, 8))]),
                child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Icons.shield_rounded, color: Colors.black, size: 26), SizedBox(width: 12),
                  Text('Mode Parent', style: TextStyle(color: Colors.black, fontSize: 19, fontWeight: FontWeight.w800))]))))),
          const SizedBox(height: 14),
          SlideTransition(position: Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero).animate(_btn2Slide),
            child: Padding(padding: const EdgeInsets.symmetric(horizontal: 28), child: GestureDetector(onTap: _handleChildMode,
              child: Container(width: double.infinity, height: 62, decoration: BoxDecoration(borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFF7C4DFF).withOpacity(0.6), width: 2),
                gradient: LinearGradient(colors: [const Color(0xFF7C4DFF).withOpacity(0.15), const Color(0xFF7C4DFF).withOpacity(0.05)])),
                child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Text('\u{1F9D2}', style: TextStyle(fontSize: 26)), SizedBox(width: 12),
                  Text('Mode Enfant', style: TextStyle(color: Color(0xFF7C4DFF), fontSize: 19, fontWeight: FontWeight.w800))]))))),
          const SizedBox(height: 20),
          Consumer<FamilyProvider>(builder: (_, fp, __) {
            if (fp.children.isEmpty) return const SizedBox.shrink();
            final totalPts = fp.children.fold(0, (s, c) => s + c.points);
            final totalBadges = fp.children.fold(0, (s, c) => s + c.badgeIds.length);
            final topChild = fp.childrenSorted.isNotEmpty ? fp.childrenSorted.first : null;
            return FadeTransition(opacity: _cardFade, child: Padding(padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Container(padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(18), color: Colors.white.withOpacity(0.04), border: Border.all(color: Colors.white.withOpacity(0.07))),
                child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
                  _StatBubble(icon: '\u{1F3C6}', value: '$totalPts', label: 'Points total', isTV: false),
                  Container(width: 1, height: 36, color: Colors.white.withOpacity(0.1)),
                  _StatBubble(icon: '\u{1F396}', value: '$totalBadges', label: 'Badges', isTV: false),
                  Container(width: 1, height: 36, color: Colors.white.withOpacity(0.1)),
                  _StatBubble(icon: '\u{1F451}', value: topChild?.name.split(' ').first ?? '-', label: 'Leader', isTV: false)]))));
          }),
          const SizedBox(height: 32)]))]))));


  }
}

class _ProfileItem {
  final String id, name; final IconData icon; final Color color; final bool isParent; final String? photoBase64, avatar; final bool hasPinSet;
  _ProfileItem({required this.id, required this.name, required this.icon, required this.color, required this.isParent, this.photoBase64, this.avatar, this.hasPinSet = false});
}

class _ChildStatCard extends StatefulWidget {
  final ChildModel child; final int rank, delay; final bool isTV;
  const _ChildStatCard({required this.child, required this.rank, required this.delay, required this.isTV});
  @override State<_ChildStatCard> createState() => _ChildStatCardState();
}
class _ChildStatCardState extends State<_ChildStatCard> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl; late Animation<double> _anim;
  @override void initState() { super.initState(); _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 600)); _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutBack); Future.delayed(Duration(milliseconds: widget.delay), () { if (mounted) _ctrl.forward(); }); }
  @override void dispose() { _ctrl.dispose(); super.dispose(); }
  Color get _rankColor { switch (widget.rank) { case 1: return const Color(0xFFFFD700); case 2: return const Color(0xFFC0C0C0); case 3: return const Color(0xFFCD7F32); default: return const Color(0xFF00E5FF); } }
  String get _rankEmoji { switch (widget.rank) { case 1: return '\u{1F947}'; case 2: return '\u{1F948}'; case 3: return '\u{1F949}'; default: return '${widget.rank}'; } }
  @override Widget build(BuildContext context) {
    final c = widget.child; final cw = widget.isTV ? 160.0 : 110.0; final av = widget.rank == 1 ? (widget.isTV ? 56.0 : 44.0) : (widget.isTV ? 42.0 : 30.0);
    return ScaleTransition(scale: _anim, child: Container(width: cw, margin: const EdgeInsets.only(right: 12), padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(18),
        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [_rankColor.withOpacity(0.12), _rankColor.withOpacity(0.04)]),
        border: Border.all(color: _rankColor.withOpacity(0.3), width: 1.5), boxShadow: [BoxShadow(color: _rankColor.withOpacity(0.1), blurRadius: 12, spreadRadius: 1)]),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Stack(clipBehavior: Clip.none, children: [
          Container(width: av, height: av, decoration: BoxDecoration(shape: BoxShape.circle, color: _rankColor.withOpacity(0.15), border: Border.all(color: _rankColor.withOpacity(0.4), width: 2)),
            child: c.hasPhoto ? ClipOval(child: Image.memory(ImageCacheUtil.fromBase64(c.photoBase64), fit: BoxFit.cover)) : Center(child: Text(c.avatar.isEmpty ? '?' : c.avatar, style: TextStyle(fontSize: widget.isTV ? 26 : 22)))),
          Positioned(top: -6, right: -6, child: Text(_rankEmoji, style: const TextStyle(fontSize: 14)))]),
        const SizedBox(height: 8),
        Text(c.name.split(' ').first, style: TextStyle(color: Colors.white, fontSize: widget.isTV ? 17 : 13, fontWeight: FontWeight.w700), maxLines: 1, overflow: TextOverflow.ellipsis),
        const SizedBox(height: 4), Text('${c.points} pts', style: TextStyle(color: _rankColor, fontSize: widget.isTV ? 15 : 12, fontWeight: FontWeight.w600)),
        const SizedBox(height: 4), ClipRRect(borderRadius: BorderRadius.circular(4), child: LinearProgressIndicator(value: c.levelProgress.clamp(0.0, 1.0), minHeight: 4, backgroundColor: Colors.white.withOpacity(0.08), valueColor: AlwaysStoppedAnimation(_rankColor))),
        const SizedBox(height: 2), Text(c.levelTitle, style: TextStyle(color: Colors.grey[500], fontSize: widget.isTV ? 11 : 9))])));
  }
}

class _StatBubble extends StatelessWidget {
  final String icon, value, label; final bool isTV;
  const _StatBubble({required this.icon, required this.value, required this.label, required this.isTV});
  @override Widget build(BuildContext context) { return Column(mainAxisSize: MainAxisSize.min, children: [
    Text(icon, style: TextStyle(fontSize: isTV ? 26 : 18)), const SizedBox(height: 4),
    Text(value, style: TextStyle(color: Colors.white, fontSize: isTV ? 22 : 16, fontWeight: FontWeight.w800)),
    Text(label, style: TextStyle(color: Colors.grey[500], fontSize: isTV ? 14 : 10))]); }
}

class _WelcomeParticle {
  late double x, y, speed, size;
  _WelcomeParticle(math.Random rng) { x = rng.nextDouble() * 400; y = rng.nextDouble() * 800; speed = rng.nextDouble() * 0.5 + 0.2; size = rng.nextDouble() * 3 + 1; }
}

class _WelcomeParticlePainter extends CustomPainter {
  final List<_WelcomeParticle> particles; final double time;
  _WelcomeParticlePainter({required this.particles, required this.time});
  @override void paint(Canvas canvas, Size size) { final paint = Paint()..color = Colors.white.withOpacity(0.15); for (var p in particles) { final yPos = (p.y + time * p.speed * 50) % (size.height + 50); canvas.drawCircle(Offset(p.x, yPos), p.size, paint); } }
  @override bool shouldRepaint(covariant CustomPainter old) => true;
}