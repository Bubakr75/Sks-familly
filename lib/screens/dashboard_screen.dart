import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/family_provider.dart';
import '../providers/pin_provider.dart';
import '../utils/pin_guard.dart';
import '../widgets/podium_widget.dart';
import '../widgets/child_card.dart';
import '../widgets/confetti_widget.dart';
import '../widgets/animated_background.dart';
import '../widgets/glass_card.dart';
import 'manage_children_screen.dart';
import 'badges_screen.dart';
import 'punishment_lines_screen.dart';
import 'pin_verification_screen.dart';
import 'notes_screen.dart';
import 'child_dashboard_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});
  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> with SingleTickerProviderStateMixin {
  bool _showConfetti = false;
  bool _isRefreshing = false;
  late AnimationController _refreshController;

  @override
  void initState() {
    super.initState();
    _refreshController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
  }

  @override
  void dispose() {
    _refreshController.dispose();
    super.dispose();
  }

  Future<void> _refreshData(FamilyProvider provider) async {
    if (_isRefreshing) return;
    setState(() => _isRefreshing = true);
    _refreshController.repeat();
    try {
      if (provider.isSyncEnabled) {
        final code = await provider.getFamilyCode();
        if (code != null) {
          await provider.disconnectFamily();
          await Future.delayed(const Duration(milliseconds: 500));
          await provider.joinFamily(code);
        }
      }
    } catch (_) {}
    await Future.delayed(const Duration(milliseconds: 500));
    _refreshController.stop();
    _refreshController.reset();
    if (mounted) {
      setState(() => _isRefreshing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(children: [
            Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
            SizedBox(width: 10),
            Text('Donnees rafraichies !'),
          ]),
          backgroundColor: const Color(0xFF00E676),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  List<Map<String, dynamic>> _getWeekNotesForChild(String childId, FamilyProvider provider) {
    final now = DateTime.now();
    final monday = now.subtract(Duration(days: now.weekday - 1));
    final dayNames = ['Lun', 'Mar', 'Mer', 'Jeu', 'Ven'];
    final List<Map<String, dynamic>> notes = [];

    for (int i = 0; i < 5; i++) {
      final day = DateTime(monday.year, monday.month, monday.day + i);
      final dayHistory = provider.history.where((h) =>
          h.childId == childId &&
          h.category == 'school_note' &&
          h.date.year == day.year &&
          h.date.month == day.month &&
          h.date.day == day.day).toList();

      final bool isToday = day.year == now.year && day.month == now.month && day.day == now.day;
      final bool isFuture = day.isAfter(now);

      if (dayHistory.isNotEmpty) {
        final reason = dayHistory.last.reason;
        final match = RegExp(r'Note: ([\d.]+)/20').firstMatch(reason);
        if (match != null) {
          final grade = double.tryParse(match.group(1)!);
          if (grade != null) {
            notes.add({'day': dayNames[i], 'grade': grade, 'isToday': isToday, 'hasNote': true});
            continue;
          }
        }
      }
      notes.add({'day': dayNames[i], 'grade': null, 'isToday': isToday, 'hasNote': false, 'isFuture': isFuture});
    }
    return notes;
  }

  static int _getScreenMinutesForGrade(double grade) {
    if (grade >= 18) return 45;
    if (grade >= 16) return 35;
    if (grade >= 14) return 25;
    if (grade >= 12) return 20;
    if (grade >= 10) return 15;
    if (grade >= 8) return 5;
    return 0;
  }

  int _getScreenTimeForChild(String childId, FamilyProvider provider) {
    final now = DateTime.now();
    final monday = now.subtract(Duration(days: now.weekday - 1));
    int totalMinutes = 0;

    for (int i = 0; i < 5; i++) {
      final day = DateTime(monday.year, monday.month, monday.day + i);
      final dayHistory = provider.history.where((h) =>
          h.childId == childId &&
          h.category == 'school_note' &&
          h.date.year == day.year &&
          h.date.month == day.month &&
          h.date.day == day.day).toList();

      if (dayHistory.isNotEmpty) {
        final reason = dayHistory.last.reason;
        final match = RegExp(r'Note: ([\d.]+)/20').firstMatch(reason);
        if (match != null) {
          final grade = double.tryParse(match.group(1)!);
          if (grade != null) totalMinutes += _getScreenMinutesForGrade(grade);
        }
      }
    }
    return totalMinutes.clamp(0, 360);
  }

  String _formatMinutes(int minutes) {
    final h = minutes ~/ 60;
    final m = minutes % 60;
    if (h == 0) return '${m}min';
    if (m == 0) return '${h}h';
    return '${h}h${m.toString().padLeft(2, '0')}';
  }
  @override
  Widget build(BuildContext context) {
    final provider = context.watch<FamilyProvider>();
    final pin = context.watch<PinProvider>();
    final totalPoints = provider.children.fold<int>(0, (s, c) => s + c.points);
    final todayEntries = provider.getHistoryForDate(DateTime.now());
    final totalBadges = provider.children.fold<int>(0, (s, c) => s + c.badgeIds.length);
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AnimatedBackground(
        child: SafeArea(
          child: Stack(
            children: [
              SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.only(bottom: 80),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 12, 8),
                      child: Row(
                        children: [
                          InkWell(
                            borderRadius: BorderRadius.circular(14),
                            onTap: () => Scaffold.of(context).openDrawer(),
                            child: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(colors: [primary, primary.withValues(alpha: 0.7)]),
                                borderRadius: BorderRadius.circular(14),
                                boxShadow: isDark ? [BoxShadow(color: primary.withValues(alpha: 0.3), blurRadius: 12)] : null,
                              ),
                              child: const Text('SKS', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 14, letterSpacing: 1)),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                NeonText(text: 'SKS Family', fontSize: 18, fontWeight: FontWeight.w800, color: isDark ? Colors.white : Colors.black87, glowIntensity: 0.2),
                                _buildModeIndicator(pin),
                              ],
                            ),
                          ),
                          _buildLockButton(pin),
                          IconButton(
                            icon: GlowIcon(icon: Icons.people_alt_rounded, color: primary, size: 22),
                            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                            padding: EdgeInsets.zero,
                            onPressed: () => PinGuard.guardNavigation(context, const ManageChildrenScreen()),
                          ),
                          _buildRefreshButton(provider, primary, isDark),
                        ],
                      ),
                    ),
                    if (provider.children.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        child: Row(
                          children: [
                            _buildStatChip(Icons.star_rounded, '$totalPoints pts', primary, isDark),
                            const SizedBox(width: 8),
                            _buildStatChip(Icons.people_rounded, '${provider.children.length}', const Color(0xFF00B0FF), isDark),
                            const SizedBox(width: 8),
                            _buildStatChip(Icons.emoji_events_rounded, '$totalBadges', const Color(0xFFFFD700), isDark),
                          ],
                        ),
                      ),
                    if (todayEntries.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        child: GlassCard(
                          margin: EdgeInsets.zero,
                          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
                          borderRadius: 14,
                          child: Row(
                            children: [
                              GlowIcon(icon: Icons.today_rounded, size: 18, color: const Color(0xFF00E5FF)),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  "${todayEntries.length} activites aujourd'hui (+${todayEntries.where((e) => e.isBonus).fold<int>(0, (s, e) => s + e.points)} pts)",
                                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isDark ? const Color(0xFF00E5FF) : Colors.teal),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    if (provider.children.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 8),
                        child: PodiumWidget(children: provider.children),
                      ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Row(
                        children: [
                          _buildQuickAction(Icons.emoji_events_rounded, 'Badges', const Color(0xFFFFD700), isDark, () {
                            Navigator.push(context, MaterialPageRoute(builder: (_) => BadgesScreen()));
                          }),
                          const SizedBox(width: 8),
                          _buildQuickAction(Icons.edit_note_rounded, 'Lignes', const Color(0xFFFF1744), isDark, () {
                            PinGuard.guardNavigation(context, const PunishmentLinesScreen());
                          }),
                          const SizedBox(width: 8),
                          _buildQuickAction(Icons.tv_rounded, 'Ecran', const Color(0xFF7C4DFF), isDark, () {
                            _showScreenTimeSummary(context, provider);
                          }),
                          const SizedBox(width: 8),
                          _buildQuickAction(Icons.child_care_rounded, 'Enfant', const Color(0xFF00E676), isDark, () {
                            _showChildModePicker(context, provider);
                          }),
                        ],
                      ),
                    ),
                    if (provider.children.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 60),
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 120, height: 120,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: primary.withValues(alpha: 0.1),
                                  boxShadow: isDark ? [BoxShadow(color: primary.withValues(alpha: 0.2), blurRadius: 24)] : null,
                                ),
                                child: const Center(child: Text('\u{1F468}\u{200D}\u{1F469}\u{200D}\u{1F467}\u{200D}\u{1F466}', style: TextStyle(fontSize: 56))),
                              ),
                              const SizedBox(height: 24),
                              NeonText(text: 'Bienvenue !', fontSize: 24, color: Colors.white),
                              const SizedBox(height: 8),
                              Text('Ajoutez vos enfants pour commencer', style: TextStyle(color: Colors.grey[400], fontSize: 16)),
                              const SizedBox(height: 24),
                              FilledButton.icon(
                                onPressed: () => PinGuard.guardNavigation(context, const ManageChildrenScreen()),
                                icon: const Icon(Icons.add),
                                label: const Text('Ajouter un enfant'),
                              ),
                            ],
                          ),
                        ),
                      ),
                    if (provider.children.isNotEmpty) ...[
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                        child: Row(
                          children: [
                            NeonText(text: 'Mes enfants', fontSize: 18, color: Colors.white, glowIntensity: 0.15),
                            const Spacer(),
                            TextButton.icon(
                              onPressed: () => PinGuard.guardNavigation(context, const ManageChildrenScreen()),
                              icon: Icon(Icons.edit_rounded, size: 16, color: primary),
                              label: Text('Gerer', style: TextStyle(color: primary)),
                            ),
                          ],
                        ),
                      ),
                      ...List.generate(provider.children.length, (index) {
                        final sorted = provider.childrenSorted;
                        final child = sorted[index];
                        final weekNotes = _getWeekNotesForChild(child.id, provider);
                        final hasAnyNote = weekNotes.any((n) => n['hasNote'] == true);
                        final screenMin = _getScreenTimeForChild(child.id, provider);
                        return TweenAnimationBuilder<double>(
                          tween: Tween(begin: 0.0, end: 1.0),
                          duration: Duration(milliseconds: 400 + index * 100),
                          curve: Curves.easeOutCubic,
                          builder: (_, v, w) => Opacity(
                            opacity: v.clamp(0.0, 1.0),
                            child: Transform.translate(offset: Offset(0, 30 * (1 - v)), child: w),
                          ),
                          child: Column(
                            children: [
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 0),
                                child: ChildCard(
                                  child: child,
                                  rank: index,
                                  onTap: () => _showChildDetail(context, child, provider),
                                  onAddPoints: () {
                                    PinGuard.guardAction(context, () {
                                      _quickAddPoints(context, child, provider);
                                    });
                                  },
                                ),
                              ),
                              if (hasAnyNote || screenMin > 0)
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
                                  child: Column(
                                    children: [
                                      if (hasAnyNote) _buildWeekNotesBar(weekNotes, child.name),
                                      if (screenMin > 0) ...[
                                        const SizedBox(height: 4),
                                        _buildScreenTimeMini(child.name, screenMin),
                                      ],
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        );
                      }),
                    ],
                    if (provider.history.isNotEmpty) ...[
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                        child: Row(
                          children: [
                            NeonText(text: 'Activite recente', fontSize: 18, color: Colors.white, glowIntensity: 0.15),
                            const Spacer(),
                            TextButton(
                              onPressed: () => _showFullHistory(context, provider),
                              child: Text('Tout voir', style: TextStyle(color: primary)),
                            ),
                          ],
                        ),
                      ),
                      ...provider.history.take(5).map((entry) {
                        final child = provider.getChild(entry.childId);
                        return GlassCard(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          child: Row(
                            children: [
                              Container(
                                width: 36, height: 36,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: entry.isBonus ? const Color(0xFF00E676).withValues(alpha: 0.15) : const Color(0xFFFF1744).withValues(alpha: 0.15),
                                ),
                                child: Icon(
                                  entry.isBonus ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
                                  color: entry.isBonus ? const Color(0xFF00E676) : const Color(0xFFFF1744),
                                  size: 18,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(child?.name ?? 'Inconnu', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                                    Text(entry.reason, style: TextStyle(fontSize: 12, color: Colors.grey[500]), maxLines: 1, overflow: TextOverflow.ellipsis),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(8),
                                  color: entry.isBonus ? const Color(0xFF00E676).withValues(alpha: 0.12) : const Color(0xFFFF1744).withValues(alpha: 0.12),
                                ),
                                child: Text(
                                  '${entry.isBonus ? '+' : ''}${entry.points}',
                                  style: TextStyle(fontWeight: FontWeight.w800, color: entry.isBonus ? const Color(0xFF00E676) : const Color(0xFFFF1744)),
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                  ],
                ),
              ),
              if (_showConfetti)
                Positioned.fill(
                  child: IgnorePointer(
                    child: ConfettiWidget(onComplete: () => setState(() => _showConfetti = false)),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildScreenTimeMini(String childName, int minutes) {
    final progress = (minutes / 360).clamp(0.0, 1.0);
    Color barColor;
    if (progress >= 0.8) barColor = const Color(0xFF00E676);
    else if (progress >= 0.5) barColor = Colors.orange;
    else barColor = const Color(0xFFFF1744);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF7C4DFF).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF7C4DFF).withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          const Icon(Icons.tv_rounded, color: Color(0xFFB388FF), size: 14),
          const SizedBox(width: 6),
          Text('Week-end: ', style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 11)),
          Text(_formatMinutes(minutes), style: TextStyle(color: barColor, fontWeight: FontWeight.w800, fontSize: 12)),
          Text(' / 6h', style: TextStyle(color: Colors.white.withValues(alpha: 0.3), fontSize: 11)),
          const SizedBox(width: 8),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 5,
                backgroundColor: Colors.white.withValues(alpha: 0.08),
                valueColor: AlwaysStoppedAnimation(barColor),
              ),
            ),
          ),
        ],
      ),
    );
  }
  void _showScreenTimeSummary(BuildContext context, FamilyProvider provider) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? const Color(0xFF141833) : null,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[700], borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 16),
            const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.tv_rounded, color: Color(0xFFB388FF), size: 24),
                SizedBox(width: 10),
                Text('Temps d\'ecran - Week-end', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
              ],
            ),
            const SizedBox(height: 20),
            if (provider.children.isEmpty)
              const Padding(
                padding: EdgeInsets.all(20),
                child: Text('Aucun enfant', style: TextStyle(color: Colors.white60)),
              )
            else
              ...provider.children.map((child) {
                final minutes = _getScreenTimeForChild(child.id, provider);
                final satMin = minutes > 180 ? 180 : minutes;
                final sunMin = minutes > 180 ? (minutes - 180).clamp(0, 180) : 0;
                final progress = (minutes / 360).clamp(0.0, 1.0);
                Color barColor;
                if (progress >= 0.8) barColor = const Color(0xFF00E676);
                else if (progress >= 0.5) barColor = Colors.orange;
                else barColor = const Color(0xFFFF1744);

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFF7C4DFF).withValues(alpha: 0.25)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          if (child.hasPhoto)
                            ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: Image.memory(base64Decode(child.photoBase64), width: 36, height: 36, fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Container(width: 36, height: 36, decoration: BoxDecoration(color: const Color(0xFF7C4DFF).withValues(alpha: 0.2), borderRadius: BorderRadius.circular(10)),
                                  child: Center(child: Text(child.avatar.isEmpty ? child.name[0] : child.avatar, style: const TextStyle(fontSize: 18))))),
                            )
                          else
                            Container(width: 36, height: 36, decoration: BoxDecoration(color: const Color(0xFF7C4DFF).withValues(alpha: 0.2), borderRadius: BorderRadius.circular(10)),
                              child: Center(child: Text(child.avatar.isEmpty ? child.name[0] : child.avatar, style: const TextStyle(fontSize: 18)))),
                          const SizedBox(width: 12),
                          Expanded(child: Text(child.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15))),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(color: barColor.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8), border: Border.all(color: barColor.withValues(alpha: 0.4))),
                            child: Text(_formatMinutes(minutes), style: TextStyle(color: barColor, fontWeight: FontWeight.w900, fontSize: 14)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(value: progress, minHeight: 6, backgroundColor: Colors.white.withValues(alpha: 0.08), valueColor: AlwaysStoppedAnimation(barColor)),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Text('\u{1F4C5} Sam: ${_formatMinutes(satMin)}', style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 12)),
                          const SizedBox(width: 16),
                          Text('\u{1F31E} Dim: ${_formatMinutes(sunMin)}', style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 12)),
                          const Spacer(),
                          Text('/ 6h max', style: TextStyle(color: Colors.white.withValues(alpha: 0.3), fontSize: 11)),
                        ],
                      ),
                    ],
                  ),
                );
              }),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildWeekNotesBar(List<Map<String, dynamic>> notes, String childName) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF448AFF).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF448AFF).withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          const Icon(Icons.school_rounded, color: Color(0xFF448AFF), size: 14),
          const SizedBox(width: 6),
          ...notes.map((n) {
            final hasNote = n['hasNote'] as bool;
            final isToday = n['isToday'] as bool;
            final isFuture = n['isFuture'] ?? false;
            final grade = n['grade'] as double?;

            Color noteColor = Colors.grey;
            if (hasNote && grade != null) {
              if (grade >= 16) noteColor = const Color(0xFF00E676);
              else if (grade >= 12) noteColor = const Color(0xFF448AFF);
              else if (grade >= 10) noteColor = Colors.orange;
              else noteColor = const Color(0xFFFF1744);
            }

            return Expanded(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 2),
                padding: const EdgeInsets.symmetric(vertical: 4),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: isToday && hasNote ? noteColor.withValues(alpha: 0.15) : Colors.transparent,
                  border: isToday ? Border.all(color: const Color(0xFF448AFF).withValues(alpha: 0.4), width: 1) : null,
                ),
                child: Column(
                  children: [
                    Text(n['day'] as String, style: TextStyle(fontSize: 8, color: Colors.white.withValues(alpha: 0.5), fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    if (hasNote && grade != null)
                      Text(
                        '${grade.toStringAsFixed(grade == grade.roundToDouble() ? 0 : 1)}/20',
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: noteColor),
                      )
                    else if (isFuture == true)
                      Text('-', style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.15)))
                    else if (isToday)
                      Container(
                        width: 8, height: 8,
                        decoration: BoxDecoration(shape: BoxShape.circle, color: const Color(0xFF448AFF).withValues(alpha: 0.5)),
                      )
                    else
                      Text('-', style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.2))),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  void _showChildModePicker(BuildContext context, FamilyProvider provider) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF141833),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.5, minChildSize: 0.3, maxChildSize: 0.85, expand: false,
        builder: (_, scrollController) => Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[700], borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 16),
              const Text('Choisir un enfant', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
              const SizedBox(height: 16),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  children: provider.children.map((child) => ListTile(
                    leading: Container(
                      width: 44, height: 44,
                      decoration: BoxDecoration(
                        color: const Color(0xFF7C4DFF).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFF7C4DFF).withValues(alpha: 0.3)),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: child.hasPhoto
                            ? Image.memory(base64Decode(child.photoBase64), fit: BoxFit.cover, width: 44, height: 44)
                            : Center(child: Text(child.avatar.isEmpty ? '\u{1F466}' : child.avatar, style: const TextStyle(fontSize: 22))),
                      ),
                    ),
                    title: Text(child.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                    subtitle: Text('${child.points} pts - ${child.levelTitle}', style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                    trailing: const Icon(Icons.chevron_right, color: Color(0xFF7C4DFF)),
                    onTap: () {
                      Navigator.pop(ctx);
                      Navigator.push(context, MaterialPageRoute(builder: (_) => ChildDashboardScreen(childId: child.id)));
                    },
                  )).toList(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModeIndicator(PinProvider pin) {
    if (!pin.isPinSet) {
      return Text('Tableau de bord', style: TextStyle(color: Colors.grey[500], fontSize: 12, fontWeight: FontWeight.w500));
    }
    final isParent = pin.isParentMode;
    final color = isParent ? const Color(0xFF00E676) : Colors.orange;
    return Container(
      margin: const EdgeInsets.only(top: 2),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(isParent ? Icons.lock_open : Icons.lock, size: 10, color: color),
          const SizedBox(width: 3),
          Text(isParent ? 'Parent' : 'Enfant', style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildLockButton(PinProvider pin) {
    if (!pin.isPinSet) return const SizedBox.shrink();
    if (pin.isParentMode) {
      return IconButton(
        icon: const GlowIcon(icon: Icons.lock_open_rounded, color: Color(0xFF00E676), size: 22),
        constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
        padding: EdgeInsets.zero,
        tooltip: 'Verrouiller',
        onPressed: () => pin.lockParentMode(),
      );
    }
    return IconButton(
      icon: const GlowIcon(icon: Icons.lock_rounded, color: Colors.orange, size: 22),
      constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
      padding: EdgeInsets.zero,
      tooltip: 'Deverrouiller',
      onPressed: () {
        Navigator.push(context, MaterialPageRoute(builder: (_) => PinVerificationScreen(onVerified: () => Navigator.pop(context))));
      },
    );
  }

  Widget _buildRefreshButton(FamilyProvider provider, Color primary, bool isDark) {
    return AnimatedBuilder(
      animation: _refreshController,
      builder: (context, child) {
        return Transform.rotate(
          angle: _refreshController.value * 2 * 3.14159,
          child: IconButton(
            icon: GlowIcon(icon: Icons.refresh_rounded, color: _isRefreshing ? const Color(0xFF00E5FF) : primary, size: 22),
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            padding: EdgeInsets.zero,
            tooltip: 'Rafraichir',
            onPressed: _isRefreshing ? null : () => _refreshData(provider),
          ),
        );
      },
    );
  }

  Widget _buildStatChip(IconData icon, String label, Color color, bool isDark) {
    return Expanded(
      child: GlassCard(
        margin: EdgeInsets.zero,
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        borderRadius: 14,
        borderColor: color.withValues(alpha: isDark ? 0.2 : 0.1),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            GlowIcon(icon: icon, size: 16, color: color),
            const SizedBox(width: 4),
            Flexible(child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color), overflow: TextOverflow.ellipsis)),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickAction(IconData icon, String label, Color color, bool isDark, VoidCallback onTap) {
    return Expanded(
      child: GlassCard(
        margin: EdgeInsets.zero,
        padding: EdgeInsets.zero,
        borderRadius: 18,
        glowColor: isDark ? color : null,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 18),
          child: Column(
            children: [
              GlowIcon(icon: icon, color: color, size: 28),
              const SizedBox(height: 6),
              Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 12)),
            ],
          ),
        ),
      ),
    );
  }

  void _quickAddPoints(BuildContext context, child, FamilyProvider provider) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF141833) : null,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[700], borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 16),
            NeonText(text: 'Points pour ${child.name}', fontSize: 18, color: Colors.white, glowIntensity: 0.2),
            const SizedBox(height: 20),
            Wrap(
              spacing: 10, runSpacing: 10, alignment: WrapAlignment.center,
              children: [
                _pointChip('+1', const Color(0xFF00E676), isDark, () { provider.addPoints(child.id, 1, 'Bonus +1', 'Bonus'); Navigator.pop(ctx); setState(() => _showConfetti = true); }),
                _pointChip('+2', const Color(0xFF00E676), isDark, () { provider.addPoints(child.id, 2, 'Bon comportement', 'Bonus'); Navigator.pop(ctx); setState(() => _showConfetti = true); }),
                _pointChip('+5', const Color(0xFF00E676), isDark, () { provider.addPoints(child.id, 5, 'Tres bien !', 'Bonus'); Navigator.pop(ctx); setState(() => _showConfetti = true); }),
                _pointChip('+10', const Color(0xFF00E676), isDark, () { provider.addPoints(child.id, 10, 'Excellent !', 'Bonus'); Navigator.pop(ctx); setState(() => _showConfetti = true); }),
                _pointChip('-1', const Color(0xFFFF1744), isDark, () { provider.addPoints(child.id, -1, 'Penalite -1', 'Penalite', isBonus: false); Navigator.pop(ctx); }),
                _pointChip('-2', const Color(0xFFFF1744), isDark, () { provider.addPoints(child.id, -2, 'Mauvais comportement', 'Penalite', isBonus: false); Navigator.pop(ctx); }),
                _pointChip('-5', const Color(0xFFFF1744), isDark, () { provider.addPoints(child.id, -5, 'Sanction', 'Penalite', isBonus: false); Navigator.pop(ctx); }),
              ],
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _pointChip(String label, Color color, bool isDark, VoidCallback onTap) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            color: color.withValues(alpha: isDark ? 0.1 : 0.08),
            border: Border.all(color: color.withValues(alpha: isDark ? 0.4 : 0.3)),
            boxShadow: isDark ? [BoxShadow(color: color.withValues(alpha: 0.15), blurRadius: 8)] : null,
          ),
          child: Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 18)),
        ),
      ),
    );
  }

  void _showChildDetail(BuildContext context, child, FamilyProvider provider) {
    final badges = provider.getBadgesForChild(child);
    final history = provider.getHistoryForChild(child.id);
    final notes = provider.getNotesForChild(child.id);
    final primary = Theme.of(context).colorScheme.primary;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? const Color(0xFF141833) : null,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.75, minChildSize: 0.4, maxChildSize: 0.92, expand: false,
        builder: (_, sc) => ListView(
          controller: sc,
          padding: const EdgeInsets.all(24),
          children: [
            Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[700], borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 20),
            Center(
              child: child.hasPhoto
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child: Image.memory(base64Decode(child.photoBase64), width: 100, height: 100, fit: BoxFit.cover, gaplessPlayback: true,
                        errorBuilder: (_, __, ___) => _buildAvatarFallback(child, primary, isDark)),
                    )
                  : _buildAvatarFallback(child, primary, isDark),
            ),
            const SizedBox(height: 16),
            Center(child: NeonText(text: child.name, fontSize: 26, color: Colors.white)),
            const SizedBox(height: 4),
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(color: primary.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8), border: Border.all(color: primary.withValues(alpha: 0.3))),
                child: Text('${child.levelTitle}', style: TextStyle(color: primary, fontWeight: FontWeight.w600)),
              ),
            ),
            const SizedBox(height: 12),
            Center(child: NeonText(text: '${child.points} points', fontSize: 36, color: primary)),
            const SizedBox(height: 16),
            GlassCard(
              margin: EdgeInsets.zero,
              padding: EdgeInsets.zero,
              borderRadius: 16,
              onTap: () {
                Navigator.pop(ctx);
                Navigator.push(context, MaterialPageRoute(builder: (_) => ChildDashboardScreen(childId: child.id)));
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                child: Row(
                  children: [
                    Container(
                      width: 40, height: 40,
                      decoration: BoxDecoration(color: const Color(0xFF7C4DFF).withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFF7C4DFF).withValues(alpha: 0.3))),
                      child: const Icon(Icons.child_care_rounded, color: Color(0xFF7C4DFF), size: 22),
                    ),
                    const SizedBox(width: 14),
                    const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Voir la fiche enfant', style: TextStyle(fontWeight: FontWeight.w700, color: Colors.white, fontSize: 15)),
                      Text('Mode enfant avec stats personnalisees', style: TextStyle(fontSize: 12, color: Colors.grey)),
                    ])),
                    const Icon(Icons.chevron_right_rounded, color: Color(0xFF7C4DFF)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(value: child.levelProgress, minHeight: 12, backgroundColor: Colors.white.withValues(alpha: 0.08), valueColor: AlwaysStoppedAnimation(primary)),
            ),
            const SizedBox(height: 4),
            Text('${child.points}/${child.nextLevelPoints} pts - prochain niveau', style: TextStyle(fontSize: 12, color: Colors.grey[500]), textAlign: TextAlign.center),
            const SizedBox(height: 20),
            GlassCard(
              margin: EdgeInsets.zero, padding: EdgeInsets.zero, borderRadius: 16,
              onTap: () {
                Navigator.pop(ctx);
                Navigator.push(context, MaterialPageRoute(builder: (_) => NotesScreen(childId: child.id, childName: child.name)));
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                child: Row(
                  children: [
                    Container(
                      width: 40, height: 40,
                      decoration: BoxDecoration(color: const Color(0xFFFFD740).withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFFFD740).withValues(alpha: 0.3))),
                      child: const Icon(Icons.sticky_note_2_rounded, color: Color(0xFFFFD740), size: 22),
                    ),
                    const SizedBox(width: 14),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text('Notes', style: TextStyle(fontWeight: FontWeight.w700, color: Colors.white, fontSize: 15)),
                      Text(notes.isEmpty ? 'Aucune note' : '${notes.length} note${notes.length > 1 ? 's' : ''}', style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                    ])),
                    Icon(Icons.chevron_right_rounded, color: Colors.grey[600]),
                  ],
                ),
              ),
            ),
            if (badges.isNotEmpty) ...[
              const SizedBox(height: 24),
              NeonText(text: 'Badges obtenus', fontSize: 16, color: Colors.white, glowIntensity: 0.2),
              const SizedBox(height: 8),
              Wrap(spacing: 8, runSpacing: 8, children: badges.map((b) => Chip(avatar: const Icon(Icons.emoji_events_rounded, size: 18, color: Colors.amber), label: Text(b.name, style: const TextStyle(fontSize: 12)))).toList()),
            ],
            if (history.isNotEmpty) ...[
              const SizedBox(height: 24),
              NeonText(text: 'Dernieres activites', fontSize: 16, color: Colors.white, glowIntensity: 0.2),
              ...history.take(10).map((h) => ListTile(
                dense: true, contentPadding: EdgeInsets.zero,
                leading: Icon(h.isBonus ? Icons.add_circle_rounded : Icons.remove_circle_rounded, color: h.isBonus ? const Color(0xFF00E676) : const Color(0xFFFF1744), size: 20),
                title: Text(h.reason, style: const TextStyle(fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
                trailing: Text('${h.isBonus ? '+' : ''}${h.points}', style: TextStyle(fontWeight: FontWeight.w800, color: h.isBonus ? const Color(0xFF00E676) : const Color(0xFFFF1744))),
              )),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAvatarFallback(child, Color primary, bool isDark) {
    return Container(
      width: 100, height: 100,
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [primary, primary.withValues(alpha: 0.5)]),
        borderRadius: BorderRadius.circular(24),
        boxShadow: isDark ? [BoxShadow(color: primary.withValues(alpha: 0.3), blurRadius: 16)] : null,
      ),
      child: Center(child: Text(child.avatar.isEmpty ? '\u{1F466}' : child.avatar, style: const TextStyle(fontSize: 48))),
    );
  }

  void _showFullHistory(BuildContext context, FamilyProvider provider) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context, isScrollControlled: true,
      backgroundColor: isDark ? const Color(0xFF141833) : null,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.8, expand: false,
        builder: (_, sc) => Column(
          children: [
            const SizedBox(height: 12),
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[700], borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 12),
            NeonText(text: 'Historique complet', fontSize: 18, color: Colors.white),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.builder(
                controller: sc, itemCount: provider.history.length,
                itemBuilder: (_, i) {
                  final h = provider.history[i];
                  final child = provider.getChild(h.childId);
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: h.isBonus ? const Color(0xFF00E676).withValues(alpha: 0.15) : const Color(0xFFFF1744).withValues(alpha: 0.15),
                      child: Icon(h.isBonus ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded, color: h.isBonus ? const Color(0xFF00E676) : const Color(0xFFFF1744), size: 20),
                    ),
                    title: Text(child?.name ?? 'Inconnu'),
                    subtitle: Text(h.reason, style: TextStyle(fontSize: 13, color: Colors.grey[500]), maxLines: 1, overflow: TextOverflow.ellipsis),
                    trailing: Text('${h.isBonus ? '+' : ''}${h.points}', style: TextStyle(fontWeight: FontWeight.w800, color: h.isBonus ? const Color(0xFF00E676) : const Color(0xFFFF1744))),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
