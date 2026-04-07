// lib/screens/dashboard_screen.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/family_provider.dart';
import '../providers/pin_provider.dart';
import '../models/child_model.dart';
import '../models/trade_model.dart';
import '../models/tribunal_model.dart';
import '../utils/pin_guard.dart';
import '../widgets/animated_background.dart';
import '../widgets/glass_card.dart';
import '../widgets/tv_focus_wrapper.dart';
import '../widgets/animated_page_transition.dart';
import 'punishment_lines_screen.dart';
import 'immunity_lines_screen.dart';
import 'trade_screen.dart';
import 'child_dashboard_screen.dart';
import 'tribunal_screen.dart';
import 'school_notes_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});
  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with TickerProviderStateMixin {
  late AnimationController _actionsController;
  late AnimationController _floatingController;
  late AnimationController _journalController;
  final List<Animation<double>> _actionAnims = [];
  late Animation<double> _floatingAnim;
  late Animation<double> _journalAnim;
  int _journalPage = 0;

  @override
  void initState() {
    super.initState();
    _actionsController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1500));
    for (int i = 0; i < 6; i++) {
      final start = i * 0.10;
      final end = (start + 0.4).clamp(0.0, 1.0);
      _actionAnims.add(CurvedAnimation(
          parent: _actionsController,
          curve: Interval(start, end, curve: Curves.elasticOut)));
    }
    _floatingController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 3000))
      ..repeat(reverse: true);
    _floatingAnim = Tween<double>(begin: -6, end: 6).animate(
        CurvedAnimation(
            parent: _floatingController, curve: Curves.easeInOut));
    _journalController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900));
    _journalAnim = CurvedAnimation(
        parent: _journalController, curve: Curves.easeOutBack);
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) {
        _actionsController.forward();
        _journalController.forward();
      }
    });
  }

  @override
  void dispose() {
    _actionsController.dispose();
    _floatingController.dispose();
    _journalController.dispose();
    super.dispose();
  }

  Widget _buildChildAvatar(ChildModel child, double radius) {
    if (child.hasPhoto) {
      try {
        final bytes = base64Decode(child.photoBase64);
        return Container(
          width: radius * 2,
          height: radius * 2,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
                color: Colors.cyanAccent.withOpacity(0.5), width: 2),
            image: DecorationImage(
                image: MemoryImage(bytes), fit: BoxFit.cover),
          ),
        );
      } catch (_) {}
    }
    return Container(
      width: radius * 2,
      height: radius * 2,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(colors: [
          Colors.cyan.withOpacity(0.4),
          Colors.purple.withOpacity(0.3),
        ]),
        border: Border.all(color: Colors.cyan.withOpacity(0.5), width: 2),
      ),
      child: Center(
        child: Text(
          child.avatar.isNotEmpty
              ? child.avatar
              : (child.name.isNotEmpty ? child.name[0].toUpperCase() : '?'),
          style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: radius * 0.7),
        ),
      ),
    );
  }

  bool _isParentMode() =>
      context.read<PinProvider>().canPerformParentAction();

  void _goToChildDashboard(String childId) {
    context.read<PinProvider>().enterChildMode();
    Navigator.push(
        context, ZoomPageRoute(page: ChildDashboardScreen(childId: childId)));
  }

  Widget _badgeWrapper({required Widget child, required int count}) {
    if (count == 0) return child;
    return Stack(
      clipBehavior: Clip.none,
      fit: StackFit.expand,
      children: [
        child,
        Positioned(
          top: -6,
          right: -6,
          child: Container(
            padding: const EdgeInsets.all(4),
            decoration: const BoxDecoration(
                color: Colors.redAccent,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(color: Colors.red, blurRadius: 6, spreadRadius: 1)
                ]),
            constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
            child: Text(count > 99 ? '99+' : '$count',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold),
                textAlign: TextAlign.center),
          ),
        ),
      ],
    );
  }

  // ══════════════════════════════════════════════════════════
  //  JOURNAL DE BORD — données (100% local, zéro appel externe)
  // ══════════════════════════════════════════════════════════
  Map<String, dynamic> _getJournalData(FamilyProvider fp, ChildModel child) {
    try {
      final now = DateTime.now();
      final weekStart = now.subtract(Duration(days: now.weekday - 1));
      final start = DateTime(weekStart.year, weekStart.month, weekStart.day);

      List<dynamic> weekEntries = [];
      try {
        weekEntries = fp
            .getHistoryForChild(child.id)
            .where((h) => h.date.isAfter(start))
            .toList();
      } catch (_) {}

      final bonuses = weekEntries
          .where((h) => h.isBonus == true && h.category == 'bonus')
          .toList();
      bonuses.sort((a, b) => (b.points as int).compareTo(a.points as int));
      final bestBonus = bonuses.isNotEmpty ? bonuses.first : null;

      final penalties = weekEntries
          .where((h) =>
              h.isBonus != true &&
              h.category != 'school_note' &&
              h.category != 'screen_time_bonus')
          .toList();

      final schoolNotes =
          weekEntries.where((h) => h.category == 'school_note').toList();
      double? avgNote;
      if (schoolNotes.isNotEmpty) {
        try {
          avgNote = schoolNotes.fold<double>(0, (s, h) {
                final match =
                    RegExp(r'(\d+)/(\d+)').firstMatch(h.reason ?? '');
                if (match != null) {
                  final v = int.tryParse(match.group(1)!) ?? (h.points as int);
                  final mx = int.tryParse(match.group(2)!) ?? 20;
                  return s + (v / mx * 20);
                }
                return s + (h.points as int).toDouble();
              }) /
              schoolNotes.length;
        } catch (_) {}
      }

      final immunities =
          weekEntries.where((h) => h.category == 'immunité').toList();

      final punishmentsDone = weekEntries
          .where((h) =>
              h.category == 'punition' &&
              (h.reason ?? '').toLowerCase().contains('terminée'))
          .toList();

      // ✅ Score calculé localement — pas d'appel à getWeeklyGlobalScore
      double globalScore = 10.0;
      try {
        final totalPoints = weekEntries.fold<int>(
            0, (s, h) => s + ((h.isBonus == true ? 1 : -1) * (h.points as int)));
        globalScore = (10.0 + totalPoints / 10.0).clamp(0.0, 20.0);
      } catch (_) {}

      // ✅ Streak lu directement sur le modèle, nullable géré
      int streak = 0;
      try {
        streak = child.streakDays ?? 0;
      } catch (_) {}

      return {
        'bestBonus': bestBonus,
        'bonusCount': bonuses.length,
        'penaltyCount': penalties.length,
        'avgNote': avgNote,
        'noteCount': schoolNotes.length,
        'immunityCount': immunities.length,
        'punishmentsDone': punishmentsDone.length,
        'globalScore': globalScore,
        'streak': streak,
        'weekStart': start,
      };
    } catch (_) {
      return {
        'bestBonus': null,
        'bonusCount': 0,
        'penaltyCount': 0,
        'avgNote': null,
        'noteCount': 0,
        'immunityCount': 0,
        'punishmentsDone': 0,
        'globalScore': 10.0,
        'streak': 0,
        'weekStart': DateTime.now(),
      };
    }
  }

  String _scoreEmoji(double score) {
    if (score >= 17) return '🌟';
    if (score >= 14) return '😊';
    if (score >= 10) return '😐';
    if (score >= 6) return '😕';
    return '😔';
  }

  String _scoreLabel(double score) {
    if (score >= 17) return 'Excellente semaine !';
    if (score >= 14) return 'Bonne semaine';
    if (score >= 10) return 'Semaine correcte';
    if (score >= 6) return 'Semaine difficile';
    return 'Semaine très difficile';
  }

  Color _scoreColor(double score) {
    if (score >= 17) return Colors.greenAccent;
    if (score >= 14) return Colors.lightGreenAccent;
    if (score >= 10) return Colors.orangeAccent;
    if (score >= 6) return Colors.deepOrangeAccent;
    return Colors.redAccent;
  }

  String _fmtDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}';

  String _safeString(dynamic obj, String field, {String fallback = ''}) {
    try {
      switch (field) {
        case 'levelTitle':
          return (obj as ChildModel).levelTitle;
        default:
          return fallback;
      }
    } catch (_) {
      return fallback;
    }
  }

  // ══════════════════════════════════════════════════════════
  //  JOURNAL DE BORD — UI
  // ══════════════════════════════════════════════════════════
  Widget _buildJournalDeBord(FamilyProvider fp) {
    final children = fp.children;
    if (children.isEmpty) return const SizedBox.shrink();

    final pageIndex = _journalPage >= children.length ? 0 : _journalPage;
    final child = children[pageIndex];

    Map<String, dynamic> data;
    try {
      data = _getJournalData(fp, child);
    } catch (_) {
      data = {
        'bestBonus': null,
        'bonusCount': 0,
        'penaltyCount': 0,
        'avgNote': null,
        'noteCount': 0,
        'immunityCount': 0,
        'punishmentsDone': 0,
        'globalScore': 10.0,
        'streak': 0,
        'weekStart': DateTime.now(),
      };
    }

    final globalScore = (data['globalScore'] as num).toDouble();
    final scoreColor = _scoreColor(globalScore);
    final weekStart = data['weekStart'] as DateTime;

    return AnimatedBuilder(
      animation: _journalAnim,
      builder: (context, ch) => Transform.translate(
        offset: Offset(0, 30 * (1 - _journalAnim.value)),
        child: Opacity(opacity: _journalAnim.value.clamp(0.0, 1.0), child: ch),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            AnimatedBuilder(
              animation: _floatingAnim,
              builder: (context, ch) => Transform.translate(
                  offset: Offset(0, _floatingAnim.value * 0.4), child: ch),
              child: const Text('📖', style: TextStyle(fontSize: 20)),
            ),
            const SizedBox(width: 8),
            ShaderMask(
              shaderCallback: (bounds) => const LinearGradient(
                colors: [Colors.white, Colors.cyanAccent],
              ).createShader(bounds),
              child: const Text('Journal de Bord',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold)),
            ),
            const Spacer(),
            Text('Sem. du ${_fmtDate(weekStart)}',
                style: const TextStyle(color: Colors.white38, fontSize: 11)),
          ]),
          const SizedBox(height: 12),

          if (children.length > 1) ...[
            SizedBox(
              height: 36,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: children.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, i) {
                  final c = children[i];
                  final isSel = pageIndex == i;
                  return GestureDetector(
                    onTap: () => setState(() => _journalPage = i),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: isSel
                            ? Colors.cyanAccent.withOpacity(0.15)
                            : Colors.white.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: isSel ? Colors.cyanAccent : Colors.white24),
                      ),
                      child: Text(c.name,
                          style: TextStyle(
                              color: isSel ? Colors.cyanAccent : Colors.white54,
                              fontSize: 13,
                              fontWeight: FontWeight.bold)),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
          ],

          GlassCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  TvFocusWrapper(
                    onTap: () => _goToChildDashboard(child.id),
                    child: _buildChildAvatar(child, 26),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(child.name,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold)),
                        Text(
                            _safeString(child, 'levelTitle',
                                fallback: 'Niveau ?'),
                            style: const TextStyle(
                                color: Colors.white54, fontSize: 12)),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: scoreColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: scoreColor.withOpacity(0.4)),
                    ),
                    child: Column(children: [
                      Text(_scoreEmoji(globalScore),
                          style: const TextStyle(fontSize: 20)),
                      Text('${globalScore.round()}/20',
                          style: TextStyle(
                              color: scoreColor,
                              fontSize: 12,
                              fontWeight: FontWeight.bold)),
                    ]),
                  ),
                ]),
                const SizedBox(height: 10),
                Center(
                  child: Text(_scoreLabel(globalScore),
                      style: TextStyle(
                          color: scoreColor,
                          fontSize: 14,
                          fontWeight: FontWeight.w600)),
                ),
                const SizedBox(height: 14),
                const Divider(color: Colors.white12, height: 1),
                const SizedBox(height: 14),

                Row(children: [
                  _journalStat('✅', '${data['bonusCount']}', 'Bonus',
                      Colors.greenAccent),
                  _journalStat('⚡', '${data['penaltyCount']}', 'Pénalités',
                      Colors.redAccent),
                  _journalStat(
                      '🧠',
                      data['avgNote'] != null
                          ? '${(data['avgNote'] as double).round()}/20'
                          : '—',
                      'Moy. notes',
                      Colors.purpleAccent),
                  _journalStat(
                      '🔥', '${data['streak']}j', 'Streak', Colors.orangeAccent),
                ]),

                if (data['bestBonus'] != null) ...[
                  const SizedBox(height: 14),
                  const Divider(color: Colors.white12, height: 1),
                  const SizedBox(height: 10),
                  const Row(children: [
                    Text('⭐', style: TextStyle(fontSize: 14)),
                    SizedBox(width: 6),
                    Text('Meilleur moment',
                        style: TextStyle(
                            color: Colors.white54,
                            fontSize: 12,
                            fontWeight: FontWeight.w600)),
                  ]),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.greenAccent.withOpacity(0.06),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: Colors.greenAccent.withOpacity(0.2)),
                    ),
                    child: Row(children: [
                      const Icon(Icons.star_rounded,
                          color: Colors.greenAccent, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${data['bestBonus'].reason ?? ''}',
                          style: const TextStyle(
                              color: Colors.white, fontSize: 13),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text('+${data['bestBonus'].points} pts',
                          style: const TextStyle(
                              color: Colors.greenAccent,
                              fontWeight: FontWeight.bold,
                              fontSize: 13)),
                    ]),
                  ),
                ],

                if ((data['immunityCount'] as int) > 0 ||
                    (data['punishmentsDone'] as int) > 0) ...[
                  const SizedBox(height: 10),
                  Wrap(spacing: 8, runSpacing: 6, children: [
                    if ((data['immunityCount'] as int) > 0)
                      _infoPill(
                          '🛡️ ${data['immunityCount']} immunité${(data['immunityCount'] as int) > 1 ? 's' : ''}',
                          Colors.amberAccent),
                    if ((data['punishmentsDone'] as int) > 0)
                      _infoPill(
                          '📏 ${data['punishmentsDone']} punition${(data['punishmentsDone'] as int) > 1 ? 's' : ''} terminée${(data['punishmentsDone'] as int) > 1 ? 's' : ''}',
                          Colors.tealAccent),
                  ]),
                ],

                if ((data['bonusCount'] as int) == 0 &&
                    (data['penaltyCount'] as int) == 0 &&
                    data['avgNote'] == null) ...[
                  const SizedBox(height: 10),
                  const Center(
                    child: Text('Aucune activité cette semaine',
                        style: TextStyle(color: Colors.white38, fontSize: 12)),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _journalStat(String emoji, String value, String label, Color color) {
    return Expanded(
      child: Column(children: [
        Text(emoji, style: const TextStyle(fontSize: 18)),
        const SizedBox(height: 2),
        Text(value,
            style: TextStyle(
                color: color, fontSize: 14, fontWeight: FontWeight.bold)),
        Text(label,
            style: const TextStyle(color: Colors.white38, fontSize: 10),
            textAlign: TextAlign.center),
      ]),
    );
  }

  Widget _infoPill(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(text,
          style: TextStyle(
              color: color, fontSize: 11, fontWeight: FontWeight.w600)),
    );
  }

  // ══════════════════════════════════════════════════════════
  //  BUILD PRINCIPAL
  // ══════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    return Consumer<FamilyProvider>(
      builder: (context, fp, _) {
        return AnimatedBackground(
          child: Scaffold(
            backgroundColor: Colors.transparent,
            body: SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeader(fp),
                    const SizedBox(height: 20),
                    if (fp.children.isNotEmpty) _buildJournalDeBord(fp),
                    const SizedBox(height: 20),
                    _buildQuickActions(fp),
                    const SizedBox(height: 20),
                    _buildActiveTrades(fp),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // ══════════════════════════════════════════════════════════
  //  HEADER
  // ══════════════════════════════════════════════════════════
  Widget _buildHeader(FamilyProvider fp) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 800),
      curve: Curves.easeOutBack,
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(0, -30 * (1 - value)),
          child: Opacity(opacity: value.clamp(0.0, 1.0), child: child),
        );
      },
      child: Row(
        children: [
          AnimatedBuilder(
            animation: _floatingAnim,
            builder: (context, child) => Transform.translate(
                offset: Offset(0, _floatingAnim.value), child: child),
            child: const Text('🏠', style: TextStyle(fontSize: 28)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ShaderMask(
                  shaderCallback: (bounds) => const LinearGradient(
                    colors: [Colors.white, Colors.cyanAccent],
                  ).createShader(bounds),
                  child: const Text('Tableau de Bord',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold)),
                ),
                // ✅ currentParentName supprimé — remplacé par familyCode
                Text(
                  '${fp.children.length} enfant${fp.children.length > 1 ? 's' : ''} • Famille',
                  style: const TextStyle(color: Colors.white54, fontSize: 13),
                ),
              ],
            ),
          ),
          Consumer<PinProvider>(
            builder: (context, pin, _) {
              final isParent = pin.canPerformParentAction();
              return TvFocusWrapper(
                onTap: () {
                  if (!isParent && pin.isPinSet) {
                    PinGuard.guardAction(context, () => setState(() {}));
                  }
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 5),
                  margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                    color: isParent
                        ? Colors.greenAccent.withOpacity(0.15)
                        : Colors.redAccent.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isParent
                          ? Colors.greenAccent.withOpacity(0.4)
                          : Colors.redAccent.withOpacity(0.4),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: (isParent ? Colors.greenAccent : Colors.redAccent)
                            .withOpacity(0.15),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(isParent ? Icons.lock_open : Icons.lock,
                          color: isParent ? Colors.greenAccent : Colors.redAccent,
                          size: 14),
                      const SizedBox(width: 4),
                      Text(
                        isParent ? 'Parent' : 'Enfant',
                        style: TextStyle(
                            color: isParent
                                ? Colors.greenAccent
                                : Colors.redAccent,
                            fontSize: 11,
                            fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          TvFocusWrapper(
            onTap: () => Scaffold.of(context).openDrawer(),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.menu, color: Colors.white, size: 24),
            ),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════
  //  ACTIONS RAPIDES
  // ══════════════════════════════════════════════════════════
  Widget _buildQuickActions(FamilyProvider fp) {
    final isParent = _isParentMode();
    final tribunalCount = fp.tribunalCases
        .where((c) => c.status != TribunalStatus.closed)
        .length;
    final venteCount = fp.trades.where((t) => t.status == 'pending').length;

    final actions = <_ActWithBadge>[
      _ActWithBadge(
        act: _Act('Punition', Icons.menu_book, Colors.red, true, () {
          PinGuard.guardAction(context, () {
            Navigator.push(
                context,
                SlidePageRoute(
                    page: const PunishmentLinesScreen(),
                    direction: SlideDirection.up));
          });
        }),
        badge: 0,
      ),
      _ActWithBadge(
        act: _Act('Immunité', Icons.shield, Colors.amber, true, () {
          PinGuard.guardAction(context, () {
            Navigator.push(context,
                SpinPageRoute(page: const ImmunityLinesScreen()));
          });
        }),
        badge: 0,
      ),
      _ActWithBadge(
        act: _Act('Profil', Icons.tv, Colors.blue, true, () {
          PinGuard.guardAction(context, () {
            _showChildPickerForNav(fp, (childId) {
              Navigator.push(
                  context,
                  ZoomPageRoute(
                      page: ChildDashboardScreen(childId: childId)));
            });
          });
        }),
        badge: 0,
      ),
      _ActWithBadge(
        act: _Act('Tribunal', Icons.gavel, Colors.purple, false, () {
          Navigator.push(
              context, SlidePageRoute(page: const TribunalScreen()));
        }),
        badge: tribunalCount,
      ),
      _ActWithBadge(
        act: _Act('Vente', Icons.storefront, Colors.green, false, () {
          _showChildPickerForNav(fp, (childId) {
            Navigator.push(context,
                DoorPageRoute(page: TradeScreen(childId: childId)));
          });
        }),
        badge: venteCount,
      ),
      _ActWithBadge(
        act: _Act('Notes', Icons.bar_chart, Colors.teal, false, () {
          _showChildPickerForNav(fp, (childId) {
            Navigator.push(
                context,
                SlidePageRoute(
                    page: SchoolNotesScreen(childId: childId)));
          });
        }),
        badge: 0,
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.0, end: 1.0),
          duration: const Duration(milliseconds: 800),
          curve: Curves.easeOutBack,
          builder: (context, value, child) => Opacity(
            opacity: value.clamp(0.0, 1.0),
            child: Transform.translate(
                offset: Offset(-20 * (1 - value), 0), child: child),
          ),
          child: const Text('⚡ Actions Rapides',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold)),
        ),
        const SizedBox(height: 10),
        GridView.count(
          crossAxisCount: 3,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 1.05,
          children: List.generate(actions.length, (i) {
            final item = actions[i];
            final anim = i < _actionAnims.length ? _actionAnims[i] : null;
            final tile = _actionTileWithBadge(item, isParent);
            if (anim == null) return tile;
            return AnimatedBuilder(
              animation: anim,
              builder: (context, child) => Transform.scale(
                scale: anim.value.clamp(0.0, 1.0),
                child: Opacity(
                    opacity: anim.value.clamp(0.0, 1.0), child: child),
              ),
              child: tile,
            );
          }),
        ),
      ],
    );
  }

  Widget _actionTileWithBadge(_ActWithBadge item, bool isParent) {
    final action = item.act;
    final tile = TvFocusWrapper(
      onTap: action.onTap,
      child: GlassCard(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: action.color.withOpacity(0.15),
                boxShadow: [
                  BoxShadow(
                      color: action.color.withOpacity(0.3),
                      blurRadius: 12,
                      spreadRadius: 2),
                ],
              ),
              child: Icon(action.icon, color: action.color, size: 24),
            ),
            const SizedBox(height: 6),
            Text(action.label,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w600),
                textAlign: TextAlign.center),
            if (action.parentOnly && !isParent)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Icon(Icons.lock,
                    color: Colors.white.withOpacity(0.3), size: 12),
              ),
          ],
        ),
      ),
    );
    return _badgeWrapper(child: tile, count: item.badge);
  }

  // ══════════════════════════════════════════════════════════
  //  VENTES ACTIVES
  // ══════════════════════════════════════════════════════════
  Widget _buildActiveTrades(FamilyProvider fp) {
    final active = fp.trades.where((t) => t.isActive).toList();
    if (active.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.0, end: 1.0),
          duration: const Duration(milliseconds: 800),
          builder: (context, value, child) =>
              Opacity(opacity: value.clamp(0.0, 1.0), child: child),
          child: const Text('🤝 Ventes en cours',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold)),
        ),
        const SizedBox(height: 8),
        ...active.asMap().entries.map((entry) {
          final trade = entry.value;
          final sellerName = fp.getChild(trade.fromChildId)?.name ?? '?';
          final buyerName = fp.getChild(trade.toChildId)?.name ?? '?';
          return TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: 1.0),
            duration: Duration(milliseconds: 500 + entry.key * 200),
            curve: Curves.easeOutCubic,
            builder: (context, value, child) => Transform.translate(
              offset: Offset(0, 20 * (1 - value)),
              child: Opacity(opacity: value.clamp(0.0, 1.0), child: child),
            ),
            child: Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: TvFocusWrapper(
                onTap: () => Navigator.push(
                    context,
                    DoorPageRoute(
                        page: TradeScreen(childId: trade.fromChildId))),
                child: GlassCard(
                  child: Row(children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.greenAccent,
                        boxShadow: [
                          BoxShadow(
                              color: Colors.greenAccent.withOpacity(0.5),
                              blurRadius: 6)
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('$sellerName → $buyerName',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold)),
                          Text(
                              '${trade.immunityLines} lignes • ${trade.serviceDescription}',
                              style: const TextStyle(
                                  color: Colors.white54, fontSize: 12),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.greenAccent.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(trade.statusLabel,
                          style: const TextStyle(
                              color: Colors.greenAccent, fontSize: 11)),
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.chevron_right, color: Colors.white38),
                  ]),
                ),
              ),
            ),
          );
        }),
      ],
    );
  }

  // ══════════════════════════════════════════════════════════
  //  SÉLECTEUR ENFANT NAVIGATION
  // ══════════════════════════════════════════════════════════
  void _showChildPickerForNav(
      FamilyProvider fp, Function(String) onSelected) {
    if (fp.children.isEmpty) return;
    if (fp.children.length == 1) {
      onSelected(fp.children.first.id);
      return;
    }
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
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(height: 16),
            const Text('Choisir un enfant',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Expanded(
              child: ListView.builder(
                controller: scrollController,
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                itemCount: fp.children.length,
                itemBuilder: (_, i) {
                  final c = fp.children[i];
                  return TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0.0, end: 1.0),
                    duration: Duration(milliseconds: 300 + i * 100),
                    curve: Curves.easeOutBack,
                    builder: (context, value, ch) => Transform.translate(
                      offset: Offset(30 * (1 - value), 0),
                      child: Opacity(
                          opacity: value.clamp(0.0, 1.0), child: ch),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: TvFocusWrapper(
                        onTap: () {
                          Navigator.pop(ctx);
                          onSelected(c.id);
                        },
                        child: GlassCard(
                          padding: const EdgeInsets.symmetric(
                              vertical: 10, horizontal: 14),
                          borderRadius: 14,
                          child: Row(children: [
                            _buildChildAvatar(c, 22),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Text(c.name,
                                      style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold)),
                                  Text(
                                      '${c.points} pts • ${_safeString(c, 'levelTitle', fallback: 'Niveau ?')}',
                                      style: const TextStyle(
                                          color: Colors.white54,
                                          fontSize: 12)),
                                ],
                              ),
                            ),
                            const Icon(Icons.chevron_right,
                                color: Colors.white38),
                          ]),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
//  MODÈLES INTERNES
// ══════════════════════════════════════════════════════════════
class _Act {
  final String label;
  final IconData icon;
  final Color color;
  final bool parentOnly;
  final VoidCallback onTap;
  const _Act(this.label, this.icon, this.color, this.parentOnly, this.onTap);
}

class _ActWithBadge {
  final _Act act;
  final int badge;
  const _ActWithBadge({required this.act, required this.badge});
}
