// lib/screens/child_dashboard_screen.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:math' show cos, sin, pi;
import '../providers/family_provider.dart';
import '../providers/pin_provider.dart';
import '../models/child_model.dart';
import '../models/badge_model.dart';
import '../widgets/animated_background.dart';
import '../widgets/glass_card.dart';
import '../widgets/tv_focus_wrapper.dart';
import '../widgets/timeline_widget.dart';
import 'timeline_screen.dart';

class ChildDashboardScreen extends StatefulWidget {
  final String childId;
  const ChildDashboardScreen({super.key, required this.childId});
  @override
  State<ChildDashboardScreen> createState() => _ChildDashboardScreenState();
}

class _ChildDashboardScreenState extends State<ChildDashboardScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  late AnimationController _profileController;
  late AnimationController _contentController;
  late AnimationController _glowController;
  late AnimationController _headerController;

  late Animation<double> _profileScale;
  late Animation<double> _profileFade;
  late Animation<double> _glowAnim;
  late Animation<double> _headerSlide;

  late String _currentChildId;

  static const _jours = [
    'Lundi','Mardi','Mercredi','Jeudi','Vendredi','Samedi','Dimanche'
  ];
  int _jourCible = 5;
  final Set<int> _joursSources = {0, 1, 2, 3, 4};

  @override
  void initState() {
    super.initState();
    _currentChildId = widget.childId;
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() => setState(() {}));

    _profileController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1200));
    _profileScale = CurvedAnimation(
        parent: _profileController, curve: Curves.elasticOut);
    _profileFade = CurvedAnimation(
        parent: _profileController,
        curve: const Interval(0.0, 0.4, curve: Curves.easeIn));

    _contentController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 800));

    _glowController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 2000))
      ..repeat(reverse: true);
    _glowAnim = Tween<double>(begin: 0.3, end: 0.9).animate(
        CurvedAnimation(parent: _glowController, curve: Curves.easeInOut));

    _headerController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900));
    _headerSlide = CurvedAnimation(
        parent: _headerController, curve: Curves.easeOutCubic);

    _profileController.forward();
    _headerController.forward();
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) _contentController.forward();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _profileController.dispose();
    _contentController.dispose();
    _glowController.dispose();
    _headerController.dispose();
    super.dispose();
  }

  void _switchToChild(String newChildId) {
    if (newChildId == _currentChildId) return;
    setState(() {
      _currentChildId = newChildId;
      _jourCible = 5;
      _joursSources..clear()..addAll({0, 1, 2, 3, 4});
    });
    _profileController..reset()..forward();
    _headerController..reset()..forward();
  }

  void _showChildSwitcher(BuildContext context, FamilyProvider fp) {
    final children = fp.children;
    if (children.length <= 1) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.55,
        minChildSize: 0.35,
        maxChildSize: 0.92,
        expand: false,
        builder: (_, scrollController) => Container(
          decoration: const BoxDecoration(
            color: Color(0xFF1A1A2E),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2)),
              ),
              const SizedBox(height: 16),
              const Text('Changer d\'enfant',
                  style: TextStyle(
                      color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  itemCount: children.length,
                  itemBuilder: (_, i) {
                    final child = children[i];
                    final isCurrent = child.id == _currentChildId;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: TvFocusWrapper(
                        onTap: () {
                          Navigator.pop(ctx);
                          _switchToChild(child.id);
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 14),
                          decoration: BoxDecoration(
                            color: isCurrent
                                ? Colors.cyanAccent.withOpacity(0.15)
                                : Colors.white.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: isCurrent
                                  ? Colors.cyanAccent
                                  : Colors.white24,
                            ),
                          ),
                          child: Row(
                            children: [
                              // ✅ Photo ou avatar dans le switcher
                              _buildChildAvatar(child, radius: 22),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Text(child.name,
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600)),
                              ),
                              Text('${child.points} pts',
                                  style: const TextStyle(
                                      color: Colors.cyanAccent,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14)),
                              if (isCurrent) ...[
                                const SizedBox(width: 8),
                                const Icon(Icons.check_circle,
                                    color: Colors.cyanAccent, size: 20),
                              ],
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ✅ Widget avatar réutilisable — photo si dispo, sinon emoji/initiale
  Widget _buildChildAvatar(ChildModel child, {double radius = 50}) {
    // Photo base64
    if (child.photoBase64 != null && child.photoBase64!.isNotEmpty) {
      try {
        final bytes = base64Decode(child.photoBase64!);
        return CircleAvatar(
          radius: radius,
          backgroundImage: MemoryImage(bytes),
        );
      } catch (_) {}
    }
    // Emoji avatar
    if (child.avatar.isNotEmpty &&
        !RegExp(r'^[a-zA-Z]$').hasMatch(child.avatar)) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: Colors.cyan.withOpacity(0.25),
        child: Text(child.avatar,
            style: TextStyle(fontSize: radius * 0.9)),
      );
    }
    // Initiale avec gradient
    return Container(
      width: radius * 2,
      height: radius * 2,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [
            _childColor(child).withOpacity(0.8),
            _childColor(child).withOpacity(0.4),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Text(
          child.name.isNotEmpty ? child.name[0].toUpperCase() : '?',
          style: TextStyle(
              color: Colors.white,
              fontSize: radius * 0.85,
              fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  // Couleur dérivée du nom de l'enfant (toujours cohérente)
  Color _childColor(ChildModel child) {
    final colors = [
      Colors.cyan, Colors.purple, Colors.orange,
      Colors.green, Colors.pink, Colors.indigo,
    ];
    final idx = child.name.isNotEmpty
        ? child.name.codeUnitAt(0) % colors.length
        : 0;
    return colors[idx];
  }

  String _formatMinutes(int m) {
    if (m < 60) return '${m}min';
    final h = m ~/ 60;
    final r = m % 60;
    return r == 0 ? '${h}h' : '${h}h${r.toString().padLeft(2, '0')}';
  }

  List<Map<String, dynamic>> _getSchoolNotes(FamilyProvider fp) {
    final history = fp.getHistoryForChild(_currentChildId);
    return history.where((h) => h.category == 'school_note').map((h) {
      String subject = h.reason;
      int noteValue = h.points;
      int noteMax = 20;
      final match = RegExp(r'^(.+):\s*(\d+)/(\d+)$').firstMatch(h.reason);
      if (match != null) {
        subject   = match.group(1)!.trim();
        noteValue = int.tryParse(match.group(2)!) ?? h.points;
        noteMax   = int.tryParse(match.group(3)!) ?? 20;
      }
      return {
        'subject': subject,
        'value':   noteValue,
        'max':     noteMax,
        'percent': noteMax > 0 ? noteValue / noteMax * 100 : 0.0,
        'date':    h.date,
      };
    }).toList();
  }

  List<Map<String, dynamic>> _getBehaviorNotes(FamilyProvider fp) {
    final history = fp.getHistoryForChild(_currentChildId);
    return history
        .where((h) =>
            h.category != 'school_note' &&
            h.category != 'screen_time_bonus' &&
            h.category != 'saturday_rating' &&
            h.category != 'tribunal_vote' &&
            h.category != 'tribunal_verdict')
        .take(10)
        .map((h) => {
              'subject': h.reason,
              'points':  h.isBonus ? h.points : -h.points,
              'date':    h.date,
              'isBonus': h.isBonus,
            })
        .toList();
  }

  double _getBehaviorScoreForSelectedDays(FamilyProvider fp) {
    if (_joursSources.isEmpty) return 10.0;
    final now = DateTime.now();
    final debutSemaine = now.subtract(Duration(days: now.weekday - 1));
    final datesCochees = _joursSources.map((jourIdx) {
      final d = debutSemaine.add(Duration(days: jourIdx));
      return DateTime(d.year, d.month, d.day);
    }).toSet();

    final entries = fp.getHistoryForChild(_currentChildId).where((h) {
      if (h.category == 'school_note'       ||
          h.category == 'screen_time_bonus'  ||
          h.category == 'saturday_rating'    ||
          h.category == 'tribunal_vote'      ||
          h.category == 'tribunal_verdict') return false;
      final entryDay = DateTime(h.date.year, h.date.month, h.date.day);
      return datesCochees.contains(entryDay);
    }).toList();

    if (entries.isEmpty) return 10.0;
    final bonusCount   = entries.where((h) => h.isBonus).length;
    final penaltyCount = entries.where((h) => !h.isBonus).length;
    final total = bonusCount + penaltyCount;
    if (total == 0) return 10.0;
    return ((bonusCount / total) * 20).clamp(0.0, 20.0);
  }

  int _percentToStars(double percent) {
    if (percent >= 90) return 5;
    if (percent >= 75) return 4;
    if (percent >= 60) return 3;
    if (percent >= 40) return 2;
    return 1;
  }

  int _calculerTempsEcranPourJour(FamilyProvider fp) {
    if (_joursSources.isEmpty) return 0;
    final now = DateTime.now();
    final debutSemaine = now.subtract(Duration(days: now.weekday - 1));
    final history = fp.getHistoryForChild(_currentChildId);
    final notesSources = <Map<String, dynamic>>[];

    for (final jourIdx in _joursSources) {
      final jourDate = DateTime(
          debutSemaine.year, debutSemaine.month,
          debutSemaine.day + jourIdx);
      final notesJour = history.where((h) =>
          h.category == 'school_note' &&
          h.date.year  == jourDate.year  &&
          h.date.month == jourDate.month &&
          h.date.day   == jourDate.day);
      for (final n in notesJour) {
        int noteValue = n.points;
        int noteMax   = 20;
        final match =
            RegExp(r'^(.+):\s*(\d+)/(\d+)$').firstMatch(n.reason);
        if (match != null) {
          noteValue = int.tryParse(match.group(2)!) ?? n.points;
          noteMax   = int.tryParse(match.group(3)!) ?? 20;
        }
        notesSources
            .add({'percent': noteMax > 0 ? noteValue / noteMax * 100 : 0.0});
      }
    }

    final bonus = fp.getParentBonusMinutes(_currentChildId);
    if (notesSources.isEmpty) {
      final globalScore =
          fp.getGlobalScoreForDays(_currentChildId, _joursSources);
      return ((globalScore / 20 * 180).round() + bonus).clamp(0, 180);
    }
    final avgPercent = notesSources.fold<double>(
            0, (s, n) => s + (n['percent'] as double)) /
        notesSources.length;
    return ((avgPercent / 100 * 180).round() + bonus).clamp(0, 180);
  }

  // ─────────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Consumer<FamilyProvider>(
      builder: (context, fp, _) {
        final child = fp.children
            .cast<ChildModel?>()
            .firstWhere((c) => c!.id == _currentChildId,
                orElse: () => null);
        if (child == null) {
          return const Scaffold(
              body: Center(child: Text('Enfant introuvable')));
        }

        final isParent = context.watch<PinProvider>().isParentMode;
        final hasMultipleChildren = fp.children.length > 1;
        final childColor = _childColor(child);

        return AnimatedBackground(
          child: Scaffold(
            backgroundColor: Colors.transparent,
            // ✅ AppBar personnalisée avec mini photo + nom coloré
            appBar: AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              leading: Navigator.canPop(context)
                  ? IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new_rounded,
                          color: Colors.white70),
                      onPressed: () => Navigator.pop(context),
                    )
                  : null,
              title: AnimatedBuilder(
                animation: _headerSlide,
                builder: (_, ch) => Transform.translate(
                  offset: Offset(-20 * (1 - _headerSlide.value), 0),
                  child: Opacity(
                      opacity: _headerSlide.value.clamp(0.0, 1.0),
                      child: ch),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Mini photo dans l'appbar
                    _buildChildAvatar(child, radius: 16),
                    const SizedBox(width: 10),
                    Text(child.name,
                        style: TextStyle(
                            color: childColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 18)),
                    if (hasMultipleChildren) ...[
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () => _showChildSwitcher(context, fp),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: childColor.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: childColor.withOpacity(0.4)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.swap_horiz_rounded,
                                  color: childColor, size: 14),
                              const SizedBox(width: 3),
                              Text('Changer',
                                  style: TextStyle(
                                      color: childColor, fontSize: 10)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                IconButton(
                  icon: Icon(Icons.timeline_rounded, color: childColor),
                  tooltip: 'Timeline complète',
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          TimelineScreen(initialChildId: _currentChildId),
                    ),
                  ),
                ),
              ],
              flexibleSpace: !isParent
                  ? Align(
                      alignment: Alignment.bottomCenter,
                      child: Container(
                        width: double.infinity,
                        color: Colors.orange.withOpacity(0.15),
                        padding: const EdgeInsets.symmetric(vertical: 3),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.child_care,
                                color: Colors.orange, size: 13),
                            SizedBox(width: 4),
                            Text('Mode enfant · lecture seule',
                                style: TextStyle(
                                    color: Colors.orange,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                    )
                  : null,
              bottom: TabBar(
                controller: _tabController,
                indicatorColor: childColor,
                indicatorWeight: 3,
                labelColor: childColor,
                unselectedLabelColor: Colors.white38,
                tabs: const [
                  Tab(icon: Icon(Icons.person),            text: 'Profil'),
                  Tab(icon: Icon(Icons.timer),              text: 'Écran'),
                  Tab(icon: Icon(Icons.timeline_rounded),   text: 'Historique'),
                  Tab(icon: Icon(Icons.emoji_events),       text: 'Badges'),
                ],
              ),
            ),
            body: TabBarView(
              controller: _tabController,
              children: [
                _buildProfileTab(child, fp),
                _buildScreenTimeTab(child, fp, isParent),
                _buildHistoryTab(child, fp),
                _buildBadgesTab(child, fp),
              ],
            ),
          ),
        );
      },
    );
  }

  // ─── Onglet Profil ────────────────────────────────────────────────────────
  Widget _buildProfileTab(ChildModel child, FamilyProvider fp) {
    final childColor = _childColor(child);
    final history    = fp.getHistoryForChild(child.id);
    final level      = child.currentLevelNumber;

    return SingleChildScrollView(
      padding: EdgeInsets.zero,
      child: Column(
        children: [

          // ✅ HERO HEADER — grande photo + halo + nom en overlay
          AnimatedBuilder(
            animation: Listenable.merge([_profileScale, _glowAnim]),
            builder: (context, _) {
              return Transform.scale(
                scale: _profileScale.value.clamp(0.0, 1.05),
                child: Opacity(
                  opacity: _profileFade.value,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 32),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          childColor.withOpacity(0.25),
                          childColor.withOpacity(0.05),
                          Colors.transparent,
                        ],
                      ),
                    ),
                    child: Column(
                      children: [
                        // Halo + grande photo
                        Stack(
                          alignment: Alignment.center,
                          children: [
                            // Halo externe animé
                            AnimatedBuilder(
                              animation: _glowAnim,
                              builder: (_, __) => Container(
                                width: 130,
                                height: 130,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: childColor
                                          .withOpacity(_glowAnim.value * 0.6),
                                      blurRadius: 40,
                                      spreadRadius: 12,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            // Anneau coloré
                            Container(
                              width: 118,
                              height: 118,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                    color: childColor, width: 3),
                              ),
                            ),
                            // ✅ Grande photo / emoji / initiale
                            _buildChildAvatar(child, radius: 54),
                            // Badge niveau en bas à droite
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: childColor,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                      color: Colors.black38, width: 2),
                                ),
                                child: Text('Niv.$level',
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold)),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        // Nom
                        Text(child.name,
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 28,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.5,
                                shadows: [
                                  Shadow(
                                      color: childColor.withOpacity(0.7),
                                      blurRadius: 12)
                                ])),
                        const SizedBox(height: 6),
                        // Compteur de points animé
                        TweenAnimationBuilder<int>(
                          tween: IntTween(begin: 0, end: child.points),
                          duration: const Duration(milliseconds: 2000),
                          curve: Curves.easeOut,
                          builder: (context, value, _) {
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 18, vertical: 8),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(colors: [
                                  childColor.withOpacity(0.3),
                                  childColor.withOpacity(0.1),
                                ]),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                    color: childColor.withOpacity(0.5)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.stars_rounded,
                                      color: childColor, size: 18),
                                  const SizedBox(width: 6),
                                  Text('$value points',
                                      style: TextStyle(
                                          color: childColor,
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold)),
                                ],
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 8),
                        // Badges débloqués en mini
                        _buildMiniEarnedBadges(child, fp),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),

          // ✅ Cartes stats personnalisées
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Ligne 2 stats côte à côte
                Row(
                  children: [
                    Expanded(child: _buildStatCard(
                      icon: Icons.timeline_rounded,
                      label: 'Activités',
                      value: '${history.length}',
                      color: childColor,
                    )),
                    const SizedBox(width: 12),
                    Expanded(child: _buildStatCard(
                      icon: Icons.military_tech_rounded,
                      label: 'Niveau',
                      value: 'Niv. $level',
                      color: Colors.amber,
                    )),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: _buildStatCard(
                      icon: Icons.thumb_up_rounded,
                      label: 'Bonus',
                      value: '${history.where((h) => h.isBonus).length}',
                      color: Colors.greenAccent,
                    )),
                    const SizedBox(width: 12),
                    Expanded(child: _buildStatCard(
                      icon: Icons.thumb_down_rounded,
                      label: 'Pénalités',
                      value: '${history.where((h) => !h.isBonus).length}',
                      color: Colors.redAccent,
                    )),
                  ],
                ),
                const SizedBox(height: 12),
                // Carte écran pleine largeur
                _buildStatCard(
                  icon: Icons.tv_rounded,
                  label: 'Temps écran samedi',
                  value: _formatMinutes(fp.getSaturdayMinutes(child.id)),
                  color: Colors.blueAccent,
                  fullWidth: true,
                ),
                const SizedBox(height: 20),
                // ✅ Barre de progression vers prochain badge
                _buildNextBadgeProgress(child, fp),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Mini badges débloqués dans le header
  Widget _buildMiniEarnedBadges(ChildModel child, FamilyProvider fp) {
    final earned = fp.getBadgesForChild(child.id);
    if (earned.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ...earned.take(5).map((b) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: Container(
                  width: 32, height: 32,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.1),
                    border: Border.all(color: Colors.white24),
                  ),
                  child: Center(
                      child: Text(b.icon,
                          style: const TextStyle(fontSize: 16))),
                ),
              )),
          if (earned.length > 5)
            Container(
              width: 32, height: 32,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.1),
              ),
              child: Center(
                child: Text('+${earned.length - 5}',
                    style: const TextStyle(
                        color: Colors.white54, fontSize: 10)),
              ),
            ),
        ],
      ),
    );
  }

  // Carte stat stylisée
  Widget _buildStatCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
    bool fullWidth = false,
  }) {
    return Container(
      width: fullWidth ? double.infinity : null,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.07),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: fullWidth
          ? Row(children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: color.withOpacity(0.15)),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                  child: Text(label,
                      style: TextStyle(
                          color: color.withOpacity(0.7), fontSize: 13))),
              Text(value,
                  style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.bold,
                      fontSize: 20)),
            ])
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Icon(icon, color: color, size: 18),
                  const SizedBox(width: 6),
                  Text(label,
                      style: TextStyle(
                          color: color.withOpacity(0.7), fontSize: 12)),
                ]),
                const SizedBox(height: 8),
                Text(value,
                    style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.bold,
                        fontSize: 22)),
              ],
            ),
    );
  }

  // Barre prochain badge
  Widget _buildNextBadgeProgress(ChildModel child, FamilyProvider fp) {
    final allBadges = [...BadgeModel.defaultBadges, ...fp.customBadges];
    final childColor = _childColor(child);
    final nextBadge = allBadges
        .where((b) =>
            !child.badgeIds.contains(b.id) &&
            b.requiredPoints > child.points)
        .fold<BadgeModel?>(null, (closest, b) {
      if (closest == null) return b;
      return b.requiredPoints < closest.requiredPoints ? b : closest;
    });

    if (nextBadge == null) {
      return GlassCard(
        child: Row(children: [
          const Text('🏆', style: TextStyle(fontSize: 24)),
          const SizedBox(width: 12),
          const Expanded(
            child: Text('Tous les badges débloqués !',
                style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold)),
          ),
        ]),
      );
    }

    final progress = (child.points / nextBadge.requiredPoints).clamp(0.0, 1.0);
    final remaining = nextBadge.requiredPoints - child.points;

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Text(nextBadge.icon, style: const TextStyle(fontSize: 22)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Prochain : ${nextBadge.name}',
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 13)),
                  Text('Encore $remaining pts',
                      style: const TextStyle(
                          color: Colors.white54, fontSize: 11)),
                ],
              ),
            ),
            Text('${(progress * 100).round()}%',
                style: TextStyle(
                    color: childColor,
                    fontWeight: FontWeight.bold)),
          ]),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              backgroundColor: Colors.white12,
              valueColor: AlwaysStoppedAnimation(childColor),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Onglet Temps écran ───────────────────────────────────────────────────
  Widget _buildScreenTimeTab(
      ChildModel child, FamilyProvider fp, bool isParent) {
    final schoolAvg     = fp.getWeeklySchoolAverage(child.id);
    final behaviorScore = _getBehaviorScoreForSelectedDays(fp);
    final globalScore   = fp.getGlobalScoreForDays(_currentChildId, _joursSources);
    final bonusMinutes  = fp.getParentBonusMinutes(child.id);
    final immunities    = fp.getImmunitiesForChild(child.id);
    final immunityBonus = immunities
        .where((im) => im.isUsable)
        .fold<int>(0, (s, im) => s + im.availableLines);

    final tempsCalcule  = _calculerTempsEcranPourJour(fp);
    final schoolNotes   = _getSchoolNotes(fp);
    final behaviorNotes = _getBehaviorNotes(fp);
    final cercleMinutes = tempsCalcule;
    final ratio         = (cercleMinutes / 180).clamp(0.0, 1.0);

    final punishmentsActives = fp.punishments
        .where((p) => p.childId == child.id && !p.isCompleted)
        .toList();
    final totalLignesRestantes = punishmentsActives.fold<int>(
        0, (s, p) => s + (p.totalLines - p.completedLines));
    final hasPendingValidation =
        punishmentsActives.any((p) => p.pendingValidation);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          if (punishmentsActives.isNotEmpty) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [
                  Colors.red.withOpacity(0.14),
                  Colors.deepOrange.withOpacity(0.08),
                ]),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.redAccent.withOpacity(0.45)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(children: [
                    Text('✏️', style: TextStyle(fontSize: 20)),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text('Lignes de punition en cours',
                          style: TextStyle(
                              color: Colors.redAccent,
                              fontSize: 14,
                              fontWeight: FontWeight.w800)),
                    ),
                  ]),
                  const SizedBox(height: 6),
                  Text(
                    'Il te reste $totalLignesRestantes ligne${totalLignesRestantes > 1 ? 's' : ''} à écrire.',
                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    '⚠️ Pense à les faire avant de jouer à la console !',
                    style: TextStyle(
                        color: Colors.orangeAccent,
                        fontSize: 12,
                        fontStyle: FontStyle.italic),
                  ),
                  if (hasPendingValidation) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: Colors.orange.withOpacity(0.3)),
                      ),
                      child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.hourglass_top_rounded,
                                color: Colors.orange, size: 14),
                            SizedBox(width: 6),
                            Text('En attente de validation parent',
                                style: TextStyle(
                                    color: Colors.orange,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600)),
                          ]),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [
                Colors.cyan.withOpacity(0.12),
                Colors.blue.withOpacity(0.06),
              ]),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.cyan.withOpacity(0.25)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.cyan.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.bar_chart_rounded,
                        color: Colors.cyan, size: 16),
                  ),
                  const SizedBox(width: 8),
                  const Text('Résumé de la semaine',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w700)),
                ]),
                const SizedBox(height: 14),
                Row(children: [
                  Expanded(child: _miniScoreCard('📚', 'Scolaire',
                      schoolAvg < 0 ? '--' : '${schoolAvg.toStringAsFixed(1)}/20',
                      schoolAvg < 0 ? Colors.white38 : schoolAvg >= 10 ? Colors.greenAccent : Colors.redAccent)),
                  const SizedBox(width: 8),
                  Expanded(child: _miniScoreCard('🧠', 'Comportement',
                      '${behaviorScore.toStringAsFixed(1)}/20',
                      behaviorScore >= 10 ? Colors.greenAccent : Colors.redAccent)),
                  const SizedBox(width: 8),
                  Expanded(child: _miniScoreCard('🌟', 'Global',
                      '${globalScore.toStringAsFixed(1)}/20',
                      globalScore >= 10 ? Colors.amber : Colors.orangeAccent)),
                ]),
                const SizedBox(height: 12),
                _miniDetailRow('🛡️ Immunités dispo',
                    '$immunityBonus lignes', Colors.cyanAccent),
                _miniDetailRow('🎁 Bonus parent',
                    '+${_formatMinutes(bonusMinutes)}', Colors.purpleAccent),
                const Divider(color: Colors.white12, height: 16),
                _miniDetailRow('⭐ Score global',
                    '${globalScore.toStringAsFixed(1)}/20', Colors.amber,
                    bold: true),
              ],
            ),
          ),
          const SizedBox(height: 16),

          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.04),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.white.withOpacity(0.08)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.calculate_rounded,
                        color: Colors.orange, size: 16),
                  ),
                  const SizedBox(width: 8),
                  const Text('Calculer le temps d\'écran',
                      style: TextStyle(
                          color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700)),
                ]),
                const SizedBox(height: 14),
                const Text('Jour à calculer :',
                    style: TextStyle(color: Colors.white70, fontSize: 12)),
                const SizedBox(height: 8),
                SizedBox(
                  height: 36,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _jours.length,
                    itemBuilder: (context, i) {
                      final isSelected = _jourCible == i;
                      final minSource = _joursSources.isNotEmpty
                          ? _joursSources.reduce((a, b) => a > b ? a : b)
                          : -1;
                      final isAvailable = i > minSource;
                      return GestureDetector(
                        onTap: isAvailable
                            ? () => setState(() {
                                  _jourCible = i;
                                  _joursSources.removeWhere((s) => s >= i);
                                })
                            : null,
                        child: Container(
                          margin: const EdgeInsets.only(right: 6),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? Colors.orange
                                : isAvailable
                                    ? Colors.white.withOpacity(0.06)
                                    : Colors.white.withOpacity(0.02),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                                color: isSelected
                                    ? Colors.orange
                                    : Colors.white.withOpacity(
                                        isAvailable ? 0.12 : 0.04)),
                          ),
                          child: Text(_jours[i],
                              style: TextStyle(
                                  color: isSelected
                                      ? Colors.white
                                      : isAvailable
                                          ? Colors.white70
                                          : Colors.white24,
                                  fontSize: 11,
                                  fontWeight: isSelected
                                      ? FontWeight.w700
                                      : FontWeight.w400)),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 12),
                const Text('Basé sur les notes de :',
                    style: TextStyle(color: Colors.white70, fontSize: 12)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: List.generate(_jourCible, (i) {
                    final isSelected = _joursSources.contains(i);
                    return GestureDetector(
                      onTap: () => setState(() {
                        if (isSelected) _joursSources.remove(i);
                        else _joursSources.add(i);
                      }),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? const Color(0xFF7C4DFF).withOpacity(0.25)
                              : Colors.white.withOpacity(0.06),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                              color: isSelected
                                  ? const Color(0xFF7C4DFF)
                                  : Colors.white.withOpacity(0.12)),
                        ),
                        child: Text(_jours[i],
                            style: TextStyle(
                                color: isSelected
                                    ? Colors.white
                                    : Colors.white54,
                                fontSize: 11,
                                fontWeight: isSelected
                                    ? FontWeight.w700
                                    : FontWeight.w400)),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 14),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [
                      Colors.orange.withOpacity(0.12),
                      Colors.deepOrange.withOpacity(0.06),
                    ]),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.orange.withOpacity(0.25)),
                  ),
                  child: Column(
                    children: [
                      Text('${_jours[_jourCible]} :',
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 12)),
                      const SizedBox(height: 4),
                      TweenAnimationBuilder<int>(
                        key: ValueKey(tempsCalcule),
                        tween: IntTween(begin: 0, end: tempsCalcule),
                        duration: const Duration(milliseconds: 800),
                        curve: Curves.easeOutCubic,
                        builder: (context, val, _) => Text(
                          _formatMinutes(val),
                          style: TextStyle(
                              color: tempsCalcule >= 120
                                  ? Colors.greenAccent
                                  : tempsCalcule >= 60
                                      ? Colors.orange
                                      : Colors.redAccent,
                              fontSize: 36,
                              fontWeight: FontWeight.w900),
                        ),
                      ),
                      Text('sur 3h max',
                          style: TextStyle(
                              color: Colors.white.withOpacity(0.4),
                              fontSize: 11)),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                          value: (tempsCalcule / 180).clamp(0.0, 1.0),
                          minHeight: 7,
                          backgroundColor: Colors.white.withOpacity(0.08),
                          valueColor: AlwaysStoppedAnimation(
                              tempsCalcule >= 120
                                  ? Colors.greenAccent
                                  : tempsCalcule >= 60
                                      ? Colors.orange
                                      : Colors.redAccent),
                        ),
                      ),
                      if (bonusMinutes > 0) ...[
                        const SizedBox(height: 8),
                        Text(
                          '+ ${_formatMinutes(bonusMinutes)} bonus parent inclus',
                          style: const TextStyle(
                              color: Colors.purpleAccent, fontSize: 11),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          TweenAnimationBuilder<double>(
            key: ValueKey('$_jourCible-$tempsCalcule'),
            tween: Tween(begin: 0.0, end: ratio),
            duration: const Duration(milliseconds: 2000),
            curve: Curves.easeOutCubic,
            builder: (context, value, _) {
              return Center(
                child: SizedBox(
                  width: 160,
                  height: 160,
                  child: CustomPaint(
                    painter: _ScreenTimePainter(value, cercleMinutes),
                    child: Center(
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        TweenAnimationBuilder<int>(
                          key: ValueKey(cercleMinutes),
                          tween: IntTween(begin: 0, end: cercleMinutes),
                          duration: const Duration(milliseconds: 2000),
                          builder: (context, val, _) => Text(
                              _formatMinutes(val),
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold)),
                        ),
                        Text(_jours[_jourCible],
                            style: const TextStyle(
                                color: Colors.white54, fontSize: 11)),
                      ]),
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 16),

          if (isParent) ...[
            const Text('Bonus rapide',
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [15, 30, 60].map((mins) {
                return TvFocusWrapper(
                  onTap: () {
                    fp.addScreenTimeBonus(
                        child.id, mins, 'Bonus écran +${mins}min');
                    _showBonusAnimation(mins);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 12),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [
                        Colors.cyan.withOpacity(0.3),
                        Colors.blue.withOpacity(0.3)
                      ]),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.cyan.withOpacity(0.5)),
                    ),
                    child: Text('+${mins}min',
                        style: const TextStyle(
                            color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 12),
            TvFocusWrapper(
              onTap: () => _showCustomBonusDialog(child, fp),
              child: GlassCard(
                child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                  Icon(Icons.add_circle, color: Colors.cyan[300]),
                  const SizedBox(width: 8),
                  Text('Bonus personnalisé',
                      style: TextStyle(color: Colors.cyan[300])),
                ]),
              ),
            ),
          ],
          const SizedBox(height: 24),

          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.04),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withOpacity(0.08)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  const Text('🧠', style: TextStyle(fontSize: 18)),
                  const SizedBox(width: 8),
                  const Text('Notes comportementales',
                      style: TextStyle(
                          color: Colors.purpleAccent,
                          fontSize: 14,
                          fontWeight: FontWeight.w700)),
                  const Spacer(),
                  if (_joursSources.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFF7C4DFF).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: const Color(0xFF7C4DFF).withOpacity(0.3)),
                      ),
                      child: Text(
                        (_joursSources.toList()..sort((a, b) => a.compareTo(b)))
                            .map((i) => _jours[i].substring(0, 3))
                            .join(', '),
                        style: const TextStyle(
                            color: Color(0xFF7C4DFF),
                            fontSize: 9,
                            fontWeight: FontWeight.w600),
                      ),
                    ),
                ]),
                const SizedBox(height: 10),
                if (behaviorNotes.isEmpty)
                  _emptyNotes('Aucune note comportementale',
                      Icons.psychology_outlined)
                else
                  ...behaviorNotes.take(4).map((n) {
                    final pts  = n['points'] as int;
                    final isPos = pts >= 0;
                    final c    = isPos ? Colors.greenAccent : Colors.redAccent;
                    final date = n['date'] as DateTime;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: c.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: c.withOpacity(0.2)),
                      ),
                      child: Row(children: [
                        Container(
                          width: 38, height: 38,
                          decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: c.withOpacity(0.15)),
                          child: Center(
                              child: Text(isPos ? '+$pts' : '$pts',
                                  style: TextStyle(
                                      color: c,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 13))),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                            child: Text(n['subject'] as String,
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 2)),
                        Text(
                            '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}',
                            style: const TextStyle(
                                color: Colors.white38, fontSize: 10)),
                      ]),
                    );
                  }),
                const SizedBox(height: 14),
                const Divider(color: Colors.white12),
                const SizedBox(height: 10),
                Row(children: [
                  const Text('📝', style: TextStyle(fontSize: 14)),
                  const SizedBox(width: 8),
                  const Text('Notes scolaires',
                      style: TextStyle(
                          color: Colors.orangeAccent,
                          fontSize: 13,
                          fontWeight: FontWeight.w600)),
                  const Spacer(),
                  if (schoolNotes.isNotEmpty)
                    Text(
                      'Moy. ${(schoolNotes.fold<double>(0, (s, n) => s + (n['percent'] as double)) / schoolNotes.length).round()}%',
                      style: const TextStyle(
                          color: Colors.orangeAccent,
                          fontSize: 11,
                          fontWeight: FontWeight.w600),
                    ),
                ]),
                const SizedBox(height: 8),
                if (schoolNotes.isEmpty)
                  _emptyNotes('Aucune note scolaire', Icons.school_outlined)
                else
                  ...schoolNotes.take(3).map((note) {
                    final percent = note['percent'] as double;
                    final isGood  = percent >= 50;
                    final nc      = isGood ? Colors.greenAccent : Colors.redAccent;
                    final stars   = _percentToStars(percent);
                    final date    = note['date'] as DateTime;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 7),
                      decoration: BoxDecoration(
                        color: nc.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: nc.withOpacity(0.12)),
                      ),
                      child: Row(children: [
                        Container(
                          width: 32, height: 32,
                          decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: nc.withOpacity(0.1)),
                          child: Center(
                              child: Text('${percent.round()}%',
                                  style: TextStyle(
                                      color: nc,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 9))),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(note['subject'] as String,
                                  style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500),
                                  overflow: TextOverflow.ellipsis),
                              Row(
                                  children: List.generate(stars,
                                      (i) => const Text('⭐',
                                          style: TextStyle(fontSize: 8)))),
                            ],
                          ),
                        ),
                        Text(
                            '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}',
                            style: const TextStyle(
                                color: Colors.white38, fontSize: 10)),
                      ]),
                    );
                  }),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  // ─── Onglet Historique ────────────────────────────────────────────────────
  Widget _buildHistoryTab(ChildModel child, FamilyProvider fp) {
    final history = fp.getHistoryForChild(child.id);
    final childColor = _childColor(child);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Row(
            children: [
              _summaryChip(
                '${history.where((h) => h.isBonus).length}',
                '✅ Bonus', Colors.greenAccent),
              const SizedBox(width: 8),
              _summaryChip(
                '${history.where((h) => !h.isBonus).length}',
                '❌ Pénalités', Colors.redAccent),
              const Spacer(),
              GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        TimelineScreen(initialChildId: child.id),
                  ),
                ),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: childColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: childColor.withOpacity(0.5)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.open_in_full_rounded,
                          color: childColor, size: 14),
                      const SizedBox(width: 4),
                      Text('Tout voir',
                          style: TextStyle(
                              color: childColor,
                              fontSize: 12,
                              fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(child: TimelineWidget(entries: history)),
      ],
    );
  }

  Widget _summaryChip(String value, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(value,
              style: TextStyle(
                  color: color, fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(width: 4),
          Text(label,
              style:
                  TextStyle(color: color.withOpacity(0.7), fontSize: 11)),
        ],
      ),
    );
  }

  // ─── Onglet Badges ────────────────────────────────────────────────────────
  Widget _buildBadgesTab(ChildModel child, FamilyProvider fp) {
    final earned    = fp.getBadgesForChild(child.id);
    final allBadges = [...BadgeModel.defaultBadges, ...fp.customBadges];
    final locked    = allBadges
        .where((b) => !child.badgeIds.contains(b.id))
        .toList();
    final childColor = _childColor(child);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (earned.isNotEmpty) ...[
            Row(children: [
              Text('🏆 Badges débloqués',
                  style: TextStyle(
                      color: childColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 16)),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: childColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text('${earned.length}',
                    style: TextStyle(
                        color: childColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 12)),
              ),
            ]),
            const SizedBox(height: 12),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 0.85,
              ),
              itemCount: earned.length,
              itemBuilder: (_, i) {
                final badge = earned[i];
                return TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.0, end: 1.0),
                  duration: Duration(milliseconds: 400 + i * 80),
                  curve: Curves.elasticOut,
                  builder: (_, value, ch) =>
                      Transform.scale(scale: value, child: ch),
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.amber.withOpacity(0.2),
                          Colors.orange.withOpacity(0.1),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                          color: Colors.amber.withOpacity(0.4)),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(badge.icon,
                            style: const TextStyle(fontSize: 32)),
                        const SizedBox(height: 6),
                        Padding(
                          padding:
                              const EdgeInsets.symmetric(horizontal: 6),
                          child: Text(badge.name,
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600)),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 24),
          ],
          if (locked.isNotEmpty) ...[
            const Text('🔒 À débloquer',
                style: TextStyle(
                    color: Colors.white54,
                    fontWeight: FontWeight.bold,
                    fontSize: 14)),
            const SizedBox(height: 12),
            ...locked.take(5).map((badge) {
              final progress = child.points / badge.requiredPoints;
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.03),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white10),
                ),
                child: Row(children: [
                  Opacity(
                    opacity: 0.35,
                    child: Text(badge.icon,
                        style: const TextStyle(fontSize: 24)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(badge.name,
                            style: const TextStyle(
                                color: Colors.white54,
                                fontWeight: FontWeight.w600,
                                fontSize: 13)),
                        const SizedBox(height: 4),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(3),
                          child: LinearProgressIndicator(
                            value: progress.clamp(0.0, 1.0),
                            minHeight: 4,
                            backgroundColor: Colors.white10,
                            valueColor:
                                AlwaysStoppedAnimation(childColor),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                            '${child.points} / ${badge.requiredPoints} pts',
                            style: const TextStyle(
                                color: Colors.white30, fontSize: 10)),
                      ],
                    ),
                  ),
                ]),
              );
            }),
          ],
          if (earned.isEmpty && locked.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(40),
                child: Text('Aucun badge disponible',
                    style: TextStyle(color: Colors.white38)),
              ),
            ),
        ],
      ),
    );
  }

  // ─── Helpers UI ───────────────────────────────────────────────────────────
  Widget _miniScoreCard(
      String emoji, String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 18)),
          const SizedBox(height: 4),
          Text(value,
              style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                  fontSize: 13)),
          Text(label,
              style: const TextStyle(color: Colors.white38, fontSize: 9)),
        ],
      ),
    );
  }

  Widget _miniDetailRow(String label, String value, Color color,
      {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(children: [
        Text(label,
            style: TextStyle(
                color: Colors.white54,
                fontSize: 12,
                fontWeight: bold ? FontWeight.w700 : FontWeight.normal)),
        const Spacer(),
        Text(value,
            style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: bold ? 14 : 12)),
      ]),
    );
  }

  Widget _emptyNotes(String msg, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: Colors.white24, size: 18),
          const SizedBox(width: 8),
          Text(msg, style: const TextStyle(color: Colors.white24, fontSize: 12)),
        ],
      ),
    );
  }

  void _showBonusAnimation(int minutes) {
    final overlay = Overlay.of(context);
    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => Positioned(
        top: MediaQuery.of(context).size.height * 0.3,
        left: 0, right: 0,
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.0, end: 1.0),
          duration: const Duration(milliseconds: 600),
          curve: Curves.elasticOut,
          builder: (_, v, ch) =>
              Transform.scale(scale: v, child: ch),
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 24, vertical: 14),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [
                  Colors.cyan.withOpacity(0.9),
                  Colors.blue.withOpacity(0.9),
                ]),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                      color: Colors.cyan.withOpacity(0.4),
                      blurRadius: 20)
                ],
              ),
              child: Text('+${minutes}min ⏱',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold)),
            ),
          ),
        ),
      ),
    );
    overlay.insert(entry);
    Future.delayed(const Duration(milliseconds: 1800), entry.remove);
  }

  void _showCustomBonusDialog(ChildModel child, FamilyProvider fp) {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        title: const Text('Bonus personnalisé',
            style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            labelText: 'Minutes',
            labelStyle: TextStyle(color: Colors.white54),
            suffixText: 'min',
            suffixStyle: TextStyle(color: Colors.white38),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annuler')),
          FilledButton(
            onPressed: () {
              final mins = int.tryParse(ctrl.text) ?? 0;
              if (mins > 0) {
                fp.addScreenTimeBonus(
                    child.id, mins, 'Bonus écran personnalisé +${mins}min');
                _showBonusAnimation(mins);
              }
              Navigator.pop(context);
            },
            child: const Text('Ajouter'),
          ),
        ],
      ),
    );
  }
}

// ─── Painter cercle temps écran ──────────────────────────────────────────────
class _ScreenTimePainter extends CustomPainter {
  final double progress;
  final int minutes;
  _ScreenTimePainter(this.progress, this.minutes);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 12;

    final bgPaint = Paint()
      ..color = Colors.white.withOpacity(0.06)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10;
    canvas.drawCircle(center, radius, bgPaint);

    final color = minutes >= 120
        ? Colors.greenAccent
        : minutes >= 60
            ? Colors.orange
            : Colors.redAccent;

    final fgPaint = Paint()
      ..shader = SweepGradient(
        startAngle: -pi / 2,
        endAngle: -pi / 2 + 2 * pi * progress,
        colors: [color.withOpacity(0.4), color],
      ).createShader(Rect.fromCircle(center: center, radius: radius))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -pi / 2,
      2 * pi * progress,
      false,
      fgPaint,
    );

    if (progress > 0) {
      final angle = -pi / 2 + 2 * pi * progress;
      final dotCenter = Offset(
        center.dx + radius * cos(angle),
        center.dy + radius * sin(angle),
      );
      final dotPaint = Paint()
        ..color = color
        ..style = PaintingStyle.fill;
      canvas.drawCircle(dotCenter, 6, dotPaint);
    }
  }

  @override
  bool shouldRepaint(_ScreenTimePainter old) =>
      old.progress != progress || old.minutes != minutes;
}
