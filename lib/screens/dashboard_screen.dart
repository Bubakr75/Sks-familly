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
import 'immunity_lines_screen.dart';
import 'pin_verification_screen.dart';
import 'notes_screen.dart';
import 'child_dashboard_screen.dart';
import 'school_notes_screen.dart';
import 'trade_screens.dart';
import 'screen_time_screen.dart';
import '../models/trade_model.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});
  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with SingleTickerProviderStateMixin {
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
        final code = provider.getFamilyCode();
        if (code.isNotEmpty) {
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
      final dayHistory = provider.history.where((h) => h.childId == childId && h.category == 'school_note' && h.date.year == day.year && h.date.month == day.month && h.date.day == day.day).toList();
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

  int _getScreenTimeForChild(String childId, FamilyProvider provider) {
    final satMin = provider.getSaturdayMinutes(childId);
    final sunMin = provider.getSundayMinutes(childId);
    return (satMin + sunMin).clamp(0, 720);
  }

  String _formatMinutes(int minutes) {
    final h = minutes ~/ 60;
    final m = minutes % 60;
    if (h == 0) return '${m}min';
    if (m == 0) return '${h}h';
    return '${h}h${m.toString().padLeft(2, '0')}';
  }

  List<TradeModel> _getActiveTrades(FamilyProvider provider) {
    return provider.trades.where((t) => t.isActive).toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  String _tradeStatusLabel(TradeModel trade) {
    if (trade.isPending) return 'En attente';
    if (trade.isAccepted) return 'Service en cours';
    if (trade.isServiceDone) return 'A valider';
    return '';
  }

  Color _tradeStatusColor(TradeModel trade) {
    if (trade.isPending) return Colors.amber;
    if (trade.isAccepted) return Colors.orange;
    if (trade.isServiceDone) return const Color(0xFF7C4DFF);
    return Colors.grey;
  }

  IconData _tradeStatusIcon(TradeModel trade) {
    if (trade.isPending) return Icons.schedule_rounded;
    if (trade.isAccepted) return Icons.hourglass_top_rounded;
    if (trade.isServiceDone) return Icons.gavel_rounded;
    return Icons.help_outline;
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
    final activeTrades = _getActiveTrades(provider);

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
                              const GlowIcon(icon: Icons.today_rounded, size: 18, color: Color(0xFF00E5FF)),
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
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      child: Row(
                        children: [
                          _buildQuickAction(Icons.edit_note_rounded, 'Punition', const Color(0xFFFF1744), isDark, () {
                            PinGuard.guardNavigation(context, const PunishmentLinesScreen());
                          }),
                          const SizedBox(width: 8),
                          _buildQuickAction(Icons.shield_rounded, 'Immunite', const Color(0xFF00E676), isDark, () {
                            PinGuard.guardNavigation(context, const ImmunityLinesScreen());
                          }),
                          const SizedBox(width: 8),
                          _buildQuickAction(Icons.tv_rounded, 'Ecran', const Color(0xFF7C4DFF), isDark, () {
                            Navigator.push(context, MaterialPageRoute(builder: (_) => const ScreenTimeScreen()));
                          }),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      child: Row(
                        children: [
                          _buildQuickAction(Icons.school_rounded, 'Notes', const Color(0xFF448AFF), isDark, () {
                            if (provider.children.isNotEmpty) _showSchoolNotesChildPicker(context, provider);
                          }),
                          const SizedBox(width: 8),
                          _buildQuickAction(Icons.child_care_rounded, 'Enfant', const Color(0xFFFF9800), isDark, () {
                            _showChildModePicker(context, provider);
                          }),
                          const SizedBox(width: 8),
                          _buildQuickAction(Icons.emoji_events_rounded, 'Badges', const Color(0xFFFFD700), isDark, () {
                            Navigator.push(context, MaterialPageRoute(builder: (_) => BadgesScreen()));
                          }),
                        ],
                      ),
                    ),
                    if (activeTrades.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(children: [
                              const Icon(Icons.sell_rounded, color: Color(0xFF7C4DFF), size: 18),
                              const SizedBox(width: 8),
                              const NeonText(text: 'Ventes en cours', fontSize: 16, color: Color(0xFF7C4DFF), glowIntensity: 0.15),
                              const SizedBox(width: 8),
                              Container(padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2), decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(10)), child: Text('${activeTrades.length}', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold))),
                            ]),
                            const SizedBox(height: 8),
                            ...activeTrades.map((trade) {
                              final seller = provider.getChild(trade.fromChildId);
                              final buyer = provider.getChild(trade.toChildId);
                              final statusColor = _tradeStatusColor(trade);
                              final statusLabel = _tradeStatusLabel(trade);
                              final statusIcon = _tradeStatusIcon(trade);
                              return Container(
                                margin: const EdgeInsets.only(bottom: 10),
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.06), borderRadius: BorderRadius.circular(16), border: Border.all(color: statusColor.withValues(alpha: 0.3))),
                                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)), child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(statusIcon, color: statusColor, size: 14), const SizedBox(width: 6), Text(statusLabel, style: TextStyle(color: statusColor, fontSize: 12, fontWeight: FontWeight.w600))])),
                                  const SizedBox(height: 10),
                                  Row(children: [
                                    Container(width: 36, height: 36, decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.sell_rounded, color: Colors.white54, size: 18)),
                                    const SizedBox(width: 10),
                                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                      Text('${seller?.name ?? "?"} → ${buyer?.name ?? "?"}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14)),
                                      Text('${trade.immunityLines} ligne${trade.immunityLines > 1 ? 's' : ''} - ${trade.serviceDescription}', style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
                                    ])),
                                    Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: const Color(0xFF00E676).withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFF00E676).withValues(alpha: 0.4))), child: Row(mainAxisSize: MainAxisSize.min, children: [const Icon(Icons.shield_rounded, color: Color(0xFF00E676), size: 14), const SizedBox(width: 4), Text('${trade.immunityLines} ligne${trade.immunityLines > 1 ? 's' : ''}', style: const TextStyle(color: Color(0xFF00E676), fontWeight: FontWeight.w700, fontSize: 12))])),
                                  ]),
                                  const SizedBox(height: 10),
                                  Row(children: [
                                    Expanded(child: OutlinedButton.icon(onPressed: () async { await provider.cancelTrade(trade.id); }, icon: const Icon(Icons.close_rounded, size: 16), label: const Text('Annuler'), style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFFFF1744), side: BorderSide(color: const Color(0xFFFF1744).withValues(alpha: 0.4)), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), padding: const EdgeInsets.symmetric(vertical: 10)))),
                                    const SizedBox(width: 10),
                                    Expanded(child: ElevatedButton.icon(onPressed: trade.isServiceDone ? () => _showParentValidationDialog(context, provider, trade) : null, icon: Icon(trade.isServiceDone ? Icons.gavel_rounded : Icons.hourglass_top_rounded, size: 16), label: Text(trade.isServiceDone ? 'Valider' : statusLabel), style: ElevatedButton.styleFrom(backgroundColor: trade.isServiceDone ? const Color(0xFF7C4DFF) : Colors.orange.withValues(alpha: 0.3), foregroundColor: trade.isServiceDone ? Colors.white : Colors.orange, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), padding: const EdgeInsets.symmetric(vertical: 10)))),
                                  ]),
                                ]),
                              );
                            }),
                          ],
                        ),
                      ),
                    if (provider.children.isNotEmpty)
                      ...provider.children.map((child) {
                        final weekNotes = _getWeekNotesForChild(child.id, provider);
                        final screenTime = _getScreenTimeForChild(child.id, provider);
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                          child: GlassCard(margin: EdgeInsets.zero, padding: const EdgeInsets.all(12), borderRadius: 16, onTap: () => _showChildDetail(context, child, provider), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            ChildCard(child: child, onTap: null),
                            const SizedBox(height: 8),
                            _buildWeekNotesBar(weekNotes, child.name),
                            const SizedBox(height: 6),
                            _buildScreenTimeMini(child.id, screenTime, provider),
                          ])),
                        );
                      }),
                    if (provider.children.isEmpty)
                      Padding(padding: const EdgeInsets.all(40), child: Center(child: Column(children: [
                        Icon(Icons.family_restroom_rounded, size: 64, color: Colors.white.withValues(alpha: 0.15)),
                        const SizedBox(height: 16),
                        Text('Ajoutez votre premier enfant !', style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 16)),
                      ]))),
                    if (provider.history.isNotEmpty) ...[
                      Padding(padding: const EdgeInsets.fromLTRB(20, 16, 20, 8), child: Row(children: [
                        const NeonText(text: 'Activite recente', fontSize: 18, color: Colors.white, glowIntensity: 0.15),
                        const Spacer(),
                        TextButton(onPressed: () => _showFullHistory(context, provider), child: Text('Tout voir', style: TextStyle(color: primary))),
                      ])),
                      ...provider.history.take(5).map((entry) {
                        final child = provider.getChild(entry.childId);
                        return GlassCard(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          child: Row(children: [
                            Container(width: 36, height: 36, decoration: BoxDecoration(shape: BoxShape.circle, color: entry.isBonus ? const Color(0xFF00E676).withValues(alpha: 0.15) : const Color(0xFFFF1744).withValues(alpha: 0.15)), child: Icon(entry.isBonus ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded, color: entry.isBonus ? const Color(0xFF00E676) : const Color(0xFFFF1744), size: 18)),
                            const SizedBox(width: 12),
                            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(child?.name ?? 'Inconnu', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                              Text(entry.reason, style: TextStyle(fontSize: 12, color: Colors.grey[500]), maxLines: 1, overflow: TextOverflow.ellipsis),
                            ])),
                            Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), color: entry.isBonus ? const Color(0xFF00E676).withValues(alpha: 0.12) : const Color(0xFFFF1744).withValues(alpha: 0.12)), child: Text('${entry.isBonus ? '+' : ''}${entry.points}', style: TextStyle(fontWeight: FontWeight.w800, color: entry.isBonus ? const Color(0xFF00E676) : const Color(0xFFFF1744)))),
                          ]),
                        );
                      }),
                    ],
                  ],
                ),
              ),
              if (_showConfetti)
                Positioned.fill(child: IgnorePointer(child: ConfettiWidget(onComplete: () => setState(() => _showConfetti = false)))),
            ],
          ),
        ),
      ),
    );
  }
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
import 'immunity_lines_screen.dart';
import 'pin_verification_screen.dart';
import 'notes_screen.dart';
import 'child_dashboard_screen.dart';
import 'school_notes_screen.dart';
import 'trade_screens.dart';
import 'screen_time_screen.dart';
import '../models/trade_model.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});
  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with SingleTickerProviderStateMixin {
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
        final code = provider.getFamilyCode();
        if (code.isNotEmpty) {
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
      final dayHistory = provider.history.where((h) => h.childId == childId && h.category == 'school_note' && h.date.year == day.year && h.date.month == day.month && h.date.day == day.day).toList();
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

  int _getScreenTimeForChild(String childId, FamilyProvider provider) {
    final satMin = provider.getSaturdayMinutes(childId);
    final sunMin = provider.getSundayMinutes(childId);
    return (satMin + sunMin).clamp(0, 720);
  }

  String _formatMinutes(int minutes) {
    final h = minutes ~/ 60;
    final m = minutes % 60;
    if (h == 0) return '${m}min';
    if (m == 0) return '${h}h';
    return '${h}h${m.toString().padLeft(2, '0')}';
  }

  List<TradeModel> _getActiveTrades(FamilyProvider provider) {
    return provider.trades.where((t) => t.isActive).toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  String _tradeStatusLabel(TradeModel trade) {
    if (trade.isPending) return 'En attente';
    if (trade.isAccepted) return 'Service en cours';
    if (trade.isServiceDone) return 'A valider';
    return '';
  }

  Color _tradeStatusColor(TradeModel trade) {
    if (trade.isPending) return Colors.amber;
    if (trade.isAccepted) return Colors.orange;
    if (trade.isServiceDone) return const Color(0xFF7C4DFF);
    return Colors.grey;
  }

  IconData _tradeStatusIcon(TradeModel trade) {
    if (trade.isPending) return Icons.schedule_rounded;
    if (trade.isAccepted) return Icons.hourglass_top_rounded;
    if (trade.isServiceDone) return Icons.gavel_rounded;
    return Icons.help_outline;
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
    final activeTrades = _getActiveTrades(provider);

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
                              const GlowIcon(icon: Icons.today_rounded, size: 18, color: Color(0xFF00E5FF)),
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
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      child: Row(
                        children: [
                          _buildQuickAction(Icons.edit_note_rounded, 'Punition', const Color(0xFFFF1744), isDark, () {
                            PinGuard.guardNavigation(context, const PunishmentLinesScreen());
                          }),
                          const SizedBox(width: 8),
                          _buildQuickAction(Icons.shield_rounded, 'Immunite', const Color(0xFF00E676), isDark, () {
                            PinGuard.guardNavigation(context, const ImmunityLinesScreen());
                          }),
                          const SizedBox(width: 8),
                          _buildQuickAction(Icons.tv_rounded, 'Ecran', const Color(0xFF7C4DFF), isDark, () {
                            Navigator.push(context, MaterialPageRoute(builder: (_) => const ScreenTimeScreen()));
                          }),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      child: Row(
                        children: [
                          _buildQuickAction(Icons.school_rounded, 'Notes', const Color(0xFF448AFF), isDark, () {
                            if (provider.children.isNotEmpty) _showSchoolNotesChildPicker(context, provider);
                          }),
                          const SizedBox(width: 8),
                          _buildQuickAction(Icons.child_care_rounded, 'Enfant', const Color(0xFFFF9800), isDark, () {
                            _showChildModePicker(context, provider);
                          }),
                          const SizedBox(width: 8),
                          _buildQuickAction(Icons.emoji_events_rounded, 'Badges', const Color(0xFFFFD700), isDark, () {
                            Navigator.push(context, MaterialPageRoute(builder: (_) => BadgesScreen()));
                          }),
                        ],
                      ),
                    ),
                    if (activeTrades.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(children: [
                              const Icon(Icons.sell_rounded, color: Color(0xFF7C4DFF), size: 18),
                              const SizedBox(width: 8),
                              const NeonText(text: 'Ventes en cours', fontSize: 16, color: Color(0xFF7C4DFF), glowIntensity: 0.15),
                              const SizedBox(width: 8),
                              Container(padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2), decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(10)), child: Text('${activeTrades.length}', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold))),
                            ]),
                            const SizedBox(height: 8),
                            ...activeTrades.map((trade) {
                              final seller = provider.getChild(trade.fromChildId);
                              final buyer = provider.getChild(trade.toChildId);
                              final statusColor = _tradeStatusColor(trade);
                              final statusLabel = _tradeStatusLabel(trade);
                              final statusIcon = _tradeStatusIcon(trade);
                              return Container(
                                margin: const EdgeInsets.only(bottom: 10),
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.06), borderRadius: BorderRadius.circular(16), border: Border.all(color: statusColor.withValues(alpha: 0.3))),
                                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)), child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(statusIcon, color: statusColor, size: 14), const SizedBox(width: 6), Text(statusLabel, style: TextStyle(color: statusColor, fontSize: 12, fontWeight: FontWeight.w600))])),
                                  const SizedBox(height: 10),
                                  Row(children: [
                                    Container(width: 36, height: 36, decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.sell_rounded, color: Colors.white54, size: 18)),
                                    const SizedBox(width: 10),
                                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                      Text('${seller?.name ?? "?"} → ${buyer?.name ?? "?"}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14)),
                                      Text('${trade.immunityLines} ligne${trade.immunityLines > 1 ? 's' : ''} - ${trade.serviceDescription}', style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
                                    ])),
                                    Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: const Color(0xFF00E676).withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFF00E676).withValues(alpha: 0.4))), child: Row(mainAxisSize: MainAxisSize.min, children: [const Icon(Icons.shield_rounded, color: Color(0xFF00E676), size: 14), const SizedBox(width: 4), Text('${trade.immunityLines} ligne${trade.immunityLines > 1 ? 's' : ''}', style: const TextStyle(color: Color(0xFF00E676), fontWeight: FontWeight.w700, fontSize: 12))])),
                                  ]),
                                  const SizedBox(height: 10),
                                  Row(children: [
                                    Expanded(child: OutlinedButton.icon(onPressed: () async { await provider.cancelTrade(trade.id); }, icon: const Icon(Icons.close_rounded, size: 16), label: const Text('Annuler'), style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFFFF1744), side: BorderSide(color: const Color(0xFFFF1744).withValues(alpha: 0.4)), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), padding: const EdgeInsets.symmetric(vertical: 10)))),
                                    const SizedBox(width: 10),
                                    Expanded(child: ElevatedButton.icon(onPressed: trade.isServiceDone ? () => _showParentValidationDialog(context, provider, trade) : null, icon: Icon(trade.isServiceDone ? Icons.gavel_rounded : Icons.hourglass_top_rounded, size: 16), label: Text(trade.isServiceDone ? 'Valider' : statusLabel), style: ElevatedButton.styleFrom(backgroundColor: trade.isServiceDone ? const Color(0xFF7C4DFF) : Colors.orange.withValues(alpha: 0.3), foregroundColor: trade.isServiceDone ? Colors.white : Colors.orange, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), padding: const EdgeInsets.symmetric(vertical: 10)))),
                                  ]),
                                ]),
                              );
                            }),
                          ],
                        ),
                      ),
                    if (provider.children.isNotEmpty)
                      ...provider.children.map((child) {
                        final weekNotes = _getWeekNotesForChild(child.id, provider);
                        final screenTime = _getScreenTimeForChild(child.id, provider);
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                          child: GlassCard(margin: EdgeInsets.zero, padding: const EdgeInsets.all(12), borderRadius: 16, onTap: () => _showChildDetail(context, child, provider), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            ChildCard(child: child, onTap: null),
                            const SizedBox(height: 8),
                            _buildWeekNotesBar(weekNotes, child.name),
                            const SizedBox(height: 6),
                            _buildScreenTimeMini(child.id, screenTime, provider),
                          ])),
                        );
                      }),
                    if (provider.children.isEmpty)
                      Padding(padding: const EdgeInsets.all(40), child: Center(child: Column(children: [
                        Icon(Icons.family_restroom_rounded, size: 64, color: Colors.white.withValues(alpha: 0.15)),
                        const SizedBox(height: 16),
                        Text('Ajoutez votre premier enfant !', style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 16)),
                      ]))),
                    if (provider.history.isNotEmpty) ...[
                      Padding(padding: const EdgeInsets.fromLTRB(20, 16, 20, 8), child: Row(children: [
                        const NeonText(text: 'Activite recente', fontSize: 18, color: Colors.white, glowIntensity: 0.15),
                        const Spacer(),
                        TextButton(onPressed: () => _showFullHistory(context, provider), child: Text('Tout voir', style: TextStyle(color: primary))),
                      ])),
                      ...provider.history.take(5).map((entry) {
                        final child = provider.getChild(entry.childId);
                        return GlassCard(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          child: Row(children: [
                            Container(width: 36, height: 36, decoration: BoxDecoration(shape: BoxShape.circle, color: entry.isBonus ? const Color(0xFF00E676).withValues(alpha: 0.15) : const Color(0xFFFF1744).withValues(alpha: 0.15)), child: Icon(entry.isBonus ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded, color: entry.isBonus ? const Color(0xFF00E676) : const Color(0xFFFF1744), size: 18)),
                            const SizedBox(width: 12),
                            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(child?.name ?? 'Inconnu', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                              Text(entry.reason, style: TextStyle(fontSize: 12, color: Colors.grey[500]), maxLines: 1, overflow: TextOverflow.ellipsis),
                            ])),
                            Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), color: entry.isBonus ? const Color(0xFF00E676).withValues(alpha: 0.12) : const Color(0xFFFF1744).withValues(alpha: 0.12)), child: Text('${entry.isBonus ? '+' : ''}${entry.points}', style: TextStyle(fontWeight: FontWeight.w800, color: entry.isBonus ? const Color(0xFF00E676) : const Color(0xFFFF1744)))),
                          ]),
                        );
                      }),
                    ],
                  ],
                ),
              ),
              if (_showConfetti)
                Positioned.fill(child: IgnorePointer(child: ConfettiWidget(onComplete: () => setState(() => _showConfetti = false)))),
            ],
          ),
        ),
      ),
    );
  }
