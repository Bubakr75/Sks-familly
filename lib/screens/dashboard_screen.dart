import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import 'tribunal_screen.dart';
import '../models/trade_model.dart';
import '../models/history_entry.dart';

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
    final todayEntries = provider.getHistoryForDate(DateTime.now());
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
                          _buildQuickAction(Icons.gavel_rounded, 'Tribunal', const Color(0xFF5D4037), isDark, () {
                            Navigator.push(context, MaterialPageRoute(builder: (_) => const TribunalScreen()));
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
                            ...activeTrades.map((trade) => _buildInteractiveTradeCard(trade, provider)),
                          ],
                        ),
                      ),
                    if (provider.children.isNotEmpty)
                      ...provider.children.map((child) {
                        final weekNotes = _getWeekNotesForChild(child.id, provider);
                        final screenTime = _getScreenTimeForChild(child.id, provider);
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                          child: GlassCard(
                            margin: EdgeInsets.zero,
                            padding: const EdgeInsets.all(12),
                            borderRadius: 16,
                            onTap: () => _showChildDetail(context, child, provider),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                ChildCard(child: child, onTap: null),
                                const SizedBox(height: 8),
                                GestureDetector(
                                  onTap: () {
                                    HapticFeedback.lightImpact();
                                    Navigator.push(context, MaterialPageRoute(builder: (_) => SchoolNotesScreen(childId: child.id)));
                                  },
                                  child: _buildWeekNotesBar(weekNotes, child.name),
                                ),
                                const SizedBox(height: 6),
                                GestureDetector(
                                  onTap: () {
                                    HapticFeedback.lightImpact();
                                    Navigator.push(context, MaterialPageRoute(builder: (_) => ChildDashboardScreen(childId: child.id)));
                                  },
                                  child: _buildScreenTimeMini(child.id, screenTime, provider),
                                ),
                              ],
                            ),
                          ),
                        );
                      }),
                    if (provider.children.isEmpty)
                      Padding(padding: const EdgeInsets.all(40), child: Center(child: Column(children: [
                        Icon(Icons.family_restroom_rounded, size: 64, color: Colors.white.withValues(alpha: 0.15)),
                        const SizedBox(height: 16),
                        Text('Ajoutez votre premier enfant !', style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 16)),
                      ]))),
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

  Widget _buildInteractiveTradeCard(TradeModel trade, FamilyProvider provider) {
    final seller = provider.getChild(trade.fromChildId);
    final buyer = provider.getChild(trade.toChildId);
    final statusColor = _tradeStatusColor(trade);
    final statusLabel = _tradeStatusLabel(trade);
    final statusIcon = _tradeStatusIcon(trade);

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        Navigator.push(context, MaterialPageRoute(builder: (_) => TradeScreen(childId: trade.fromChildId)));
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.06), borderRadius: BorderRadius.circular(16), border: Border.all(color: statusColor.withValues(alpha: 0.3))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(
            children: [
              Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)), child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(statusIcon, color: statusColor, size: 14), const SizedBox(width: 6), Text(statusLabel, style: TextStyle(color: statusColor, fontSize: 12, fontWeight: FontWeight.w600))])),
              const Spacer(),
              Icon(Icons.open_in_new_rounded, color: statusColor.withValues(alpha: 0.5), size: 16),
            ],
          ),
          const SizedBox(height: 10),
          Row(children: [
            Container(width: 36, height: 36, decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.sell_rounded, color: Colors.white54, size: 18)),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${seller?.name ?? "?"}  \u{2192}  ${buyer?.name ?? "?"}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14)),
              Text('${trade.immunityLines} ligne${trade.immunityLines > 1 ? 's' : ''} - ${trade.serviceDescription}', style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
            ])),
            Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: const Color(0xFF00E676).withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFF00E676).withValues(alpha: 0.4))), child: Row(mainAxisSize: MainAxisSize.min, children: [const Icon(Icons.shield_rounded, color: Color(0xFF00E676), size: 14), const SizedBox(width: 4), Text('${trade.immunityLines}', style: const TextStyle(color: Color(0xFF00E676), fontWeight: FontWeight.w700, fontSize: 12))])),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: OutlinedButton.icon(onPressed: () async { await provider.cancelTrade(trade.id); }, icon: const Icon(Icons.close_rounded, size: 16), label: const Text('Annuler'), style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFFFF1744), side: BorderSide(color: const Color(0xFFFF1744).withValues(alpha: 0.4)), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), padding: const EdgeInsets.symmetric(vertical: 10)))),
            const SizedBox(width: 10),
            Expanded(child: ElevatedButton.icon(onPressed: trade.isServiceDone ? () => _showParentValidationDialog(context, provider, trade) : null, icon: Icon(trade.isServiceDone ? Icons.gavel_rounded : Icons.hourglass_top_rounded, size: 16), label: Text(trade.isServiceDone ? 'Valider' : statusLabel), style: ElevatedButton.styleFrom(backgroundColor: trade.isServiceDone ? const Color(0xFF7C4DFF) : Colors.orange.withValues(alpha: 0.3), foregroundColor: trade.isServiceDone ? Colors.white : Colors.orange, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), padding: const EdgeInsets.symmetric(vertical: 10)))),
          ]),
        ]),
      ),
    );
  }

  void _showHistoryDetail(BuildContext context, HistoryEntry entry, dynamic child, FamilyProvider provider) {
    final isPositive = entry.isBonus && entry.points > 0;
    final color = isPositive ? const Color(0xFF00E676) : const Color(0xFFFF1744);
    final dateStr = '${entry.date.day.toString().padLeft(2, '0')}/${entry.date.month.toString().padLeft(2, '0')}/${entry.date.year} a ${entry.date.hour.toString().padLeft(2, '0')}:${entry.date.minute.toString().padLeft(2, '0')}';

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0D1B2A),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[700], borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 20),
            Container(
              width: 70, height: 70,
              decoration: BoxDecoration(shape: BoxShape.circle, color: color.withValues(alpha: 0.15), border: Border.all(color: color.withValues(alpha: 0.4), width: 2)),
              child: Center(child: Text('${isPositive ? '+' : ''}${entry.points}', style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 24))),
            ),
            const SizedBox(height: 16),
            Text(child?.name ?? 'Inconnu', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 20)),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.06), borderRadius: BorderRadius.circular(14), border: Border.all(color: Colors.white.withValues(alpha: 0.1))),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Raison', style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 12, fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text(entry.reason, style: const TextStyle(color: Colors.white, fontSize: 15)),
              ]),
            ),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: _detailChip(Icons.category_rounded, 'Categorie', entry.category, const Color(0xFF448AFF))),
              const SizedBox(width: 10),
              Expanded(child: _detailChip(Icons.access_time_rounded, 'Date', dateStr, Colors.amber)),
            ]),
            if (entry.hasProofPhoto) ...[
              const SizedBox(height: 12),
              GestureDetector(
                onTap: () {
                  showDialog(context: context, builder: (dlgCtx) => Dialog(
                    backgroundColor: Colors.black, insetPadding: const EdgeInsets.all(8),
                    child: Stack(children: [
                      InteractiveViewer(child: Image.memory(base64Decode(entry.proofPhotoBase64!), fit: BoxFit.contain)),
                      Positioned(top: 8, right: 8, child: IconButton(icon: const Icon(Icons.close, color: Colors.white, size: 28), onPressed: () => Navigator.pop(dlgCtx))),
                    ]),
                  ));
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: Colors.blue.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(14), border: Border.all(color: Colors.blue.withValues(alpha: 0.2))),
                  child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(Icons.photo_rounded, color: Colors.blue, size: 20),
                    SizedBox(width: 8),
                    Text('Voir la preuve photo', style: TextStyle(color: Colors.blue, fontWeight: FontWeight.w600)),
                  ]),
                ),
              ),
            ],
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.pop(ctx);
                  if (child != null) {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => ChildDashboardScreen(childId: child.id)));
                  }
                },
                icon: const Icon(Icons.person_rounded, size: 18),
                label: const Text('Voir le profil'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF7C4DFF),
                  side: BorderSide(color: const Color(0xFF7C4DFF).withValues(alpha: 0.4)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _detailChip(IconData icon, String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(12), border: Border.all(color: color.withValues(alpha: 0.2))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [Icon(icon, color: color, size: 14), const SizedBox(width: 6), Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600))]),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600), maxLines: 2, overflow: TextOverflow.ellipsis),
      ]),
    );
  }

  Widget _buildScreenTimeMini(String childId, int totalMinutes, FamilyProvider provider) {
    final satMin = provider.getSaturdayMinutes(childId);
    final sunMin = provider.getSundayMinutes(childId);
    final progress = totalMinutes > 0 ? (totalMinutes / 720).clamp(0.0, 1.0) : 0.0;
    Color barColor;
    if (progress >= 0.5) { barColor = const Color(0xFF00E676); }
    else if (progress >= 0.25) { barColor = Colors.orange; }
    else { barColor = const Color(0xFFFF1744); }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(color: const Color(0xFF7C4DFF).withValues(alpha: 0.08), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFF7C4DFF).withValues(alpha: 0.2))),
      child: Row(children: [
        const Icon(Icons.tv_rounded, color: Color(0xFFB388FF), size: 14),
        const SizedBox(width: 6),
        Text('Sam: ${_formatMinutes(satMin)}', style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 11)),
        const SizedBox(width: 8),
        Text('Dim: ${_formatMinutes(sunMin)}', style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 11)),
        const SizedBox(width: 8),
        Text('= ${_formatMinutes(totalMinutes)}', style: TextStyle(color: barColor, fontWeight: FontWeight.w800, fontSize: 12)),
        const SizedBox(width: 8),
        Expanded(child: ClipRRect(borderRadius: BorderRadius.circular(4), child: LinearProgressIndicator(value: progress, minHeight: 5, backgroundColor: Colors.white.withValues(alpha: 0.08), valueColor: AlwaysStoppedAnimation(barColor)))),
        const SizedBox(width: 6),
        Icon(Icons.chevron_right_rounded, color: const Color(0xFFB388FF).withValues(alpha: 0.5), size: 16),
      ]),
    );
  }
  void _showParentValidationDialog(BuildContext context, FamilyProvider provider, TradeModel trade) {
    String note = '';
    final seller = provider.getChild(trade.fromChildId);
    final buyer = provider.getChild(trade.toChildId);
    showDialog(context: context, builder: (ctx) {
      return AlertDialog(
        backgroundColor: const Color(0xFF1a1a4a),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(children: [Icon(Icons.gavel_rounded, color: Color(0xFF7C4DFF), size: 22), SizedBox(width: 8), Text('Validation parent', style: TextStyle(color: Color(0xFF7C4DFF), fontSize: 18))]),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(width: double.infinity, padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.06), borderRadius: BorderRadius.circular(12)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${seller?.name ?? "?"} vend ${trade.immunityLines} ligne${trade.immunityLines > 1 ? 's' : ''} a ${buyer?.name ?? "?"}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Text('Service : ${trade.serviceDescription}', style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 13)),
          ])),
          const SizedBox(height: 16),
          const Text('Note (optionnel) :', style: TextStyle(color: Colors.white70, fontSize: 13)),
          const SizedBox(height: 8),
          TextField(onChanged: (val) => note = val, style: const TextStyle(color: Colors.white), decoration: InputDecoration(hintText: 'Commentaire...', hintStyle: const TextStyle(color: Colors.white30), filled: true, fillColor: Colors.white.withValues(alpha: 0.08), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none))),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler', style: TextStyle(color: Colors.white54))),
          ElevatedButton.icon(
            onPressed: () async {
              await provider.completeTrade(trade.id, parentNote: note.isNotEmpty ? note : null);
              if (ctx.mounted) Navigator.pop(ctx);
              if (mounted) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: const Row(children: [Icon(Icons.check_circle_rounded, color: Colors.white, size: 18), SizedBox(width: 8), Text('Vente validee ! Immunites transferees.')]), backgroundColor: const Color(0xFF7C4DFF), behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)))); }
            },
            icon: const Icon(Icons.check_rounded, size: 18), label: const Text('Valider la vente'),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF7C4DFF), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
          ),
        ],
      );
    });
  }

  Widget _buildWeekNotesBar(List<Map<String, dynamic>> notes, String childName) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(color: const Color(0xFF448AFF).withValues(alpha: 0.08), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFF448AFF).withValues(alpha: 0.2))),
      child: Row(children: [
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
          return Expanded(child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 2), padding: const EdgeInsets.symmetric(vertical: 4),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), color: isToday && hasNote ? noteColor.withValues(alpha: 0.15) : Colors.transparent, border: isToday ? Border.all(color: const Color(0xFF448AFF).withValues(alpha: 0.4), width: 1) : null),
            child: Column(children: [
              Text(n['day'] as String, style: TextStyle(fontSize: 8, color: Colors.white.withValues(alpha: 0.5), fontWeight: FontWeight.w600)),
              const SizedBox(height: 2),
              if (hasNote && grade != null) Text('${grade.toStringAsFixed(grade == grade.roundToDouble() ? 0 : 1)}/20', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: noteColor))
              else if (isFuture == true) Text('-', style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.15)))
              else if (isToday) Container(width: 8, height: 8, decoration: BoxDecoration(shape: BoxShape.circle, color: const Color(0xFF448AFF).withValues(alpha: 0.5)))
              else Text('-', style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.2))),
            ]),
          ));
        }),
        const SizedBox(width: 6),
        Icon(Icons.chevron_right_rounded, color: const Color(0xFF448AFF).withValues(alpha: 0.5), size: 16),
      ]),
    );
  }

  void _showSchoolNotesChildPicker(BuildContext context, FamilyProvider provider) {
    showModalBottomSheet(context: context, backgroundColor: const Color(0xFF141833), shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (ctx) => Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[700], borderRadius: BorderRadius.circular(2))),
        const SizedBox(height: 16),
        Text('Choisir un enfant', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white, shadows: [Shadow(color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3), blurRadius: 8)])),
        const SizedBox(height: 16),
        ...provider.children.map((child) => ListTile(
          leading: Container(width: 40, height: 40, decoration: BoxDecoration(color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12)), child: Center(child: Text(child.avatar.isEmpty ? '\u{1F466}' : child.avatar, style: const TextStyle(fontSize: 22)))),
          title: Text(child.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
          trailing: Icon(Icons.chevron_right, color: Colors.grey[600]),
          onTap: () { Navigator.pop(ctx); Navigator.push(context, MaterialPageRoute(builder: (_) => SchoolNotesScreen(childId: child.id))); },
        )),
        const SizedBox(height: 16),
      ])),
    );
  }

  void _showChildModePicker(BuildContext context, FamilyProvider provider) {
    showModalBottomSheet(context: context, backgroundColor: const Color(0xFF141833), isScrollControlled: true, shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (ctx) => DraggableScrollableSheet(initialChildSize: 0.5, minChildSize: 0.3, maxChildSize: 0.85, expand: false,
        builder: (_, scrollController) => Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[700], borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 16),
          const Text('Choisir un enfant', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
          const SizedBox(height: 16),
          Expanded(child: ListView(controller: scrollController, children: provider.children.map((child) => ListTile(
            leading: Container(width: 44, height: 44, decoration: BoxDecoration(color: const Color(0xFF7C4DFF).withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFF7C4DFF).withValues(alpha: 0.3))), child: ClipRRect(borderRadius: BorderRadius.circular(12), child: child.hasPhoto ? Image.memory(base64Decode(child.photoBase64), fit: BoxFit.cover, width: 44, height: 44) : Center(child: Text(child.avatar.isEmpty ? '\u{1F466}' : child.avatar, style: const TextStyle(fontSize: 22))))),
            title: Text(child.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
            subtitle: Text('${child.points} pts - ${child.levelTitle}', style: TextStyle(color: Colors.grey[500], fontSize: 12)),
            trailing: const Icon(Icons.chevron_right, color: Color(0xFF7C4DFF)),
            onTap: () { Navigator.pop(ctx); Navigator.push(context, MaterialPageRoute(builder: (_) => ChildDashboardScreen(childId: child.id))); },
          )).toList())),
        ])),
      ),
    );
  }

  void _showFullHistory(BuildContext context, FamilyProvider provider) {
    showModalBottomSheet(context: context, isScrollControlled: true, backgroundColor: const Color(0xFF141833), shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (ctx) => DraggableScrollableSheet(initialChildSize: 0.75, minChildSize: 0.4, maxChildSize: 0.92, expand: false,
        builder: (_, sc) => Padding(padding: const EdgeInsets.all(24), child: Column(children: [
          Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[700], borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 16),
          const Text('Historique complet', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
          const SizedBox(height: 16),
          Expanded(child: ListView.builder(controller: sc, itemCount: provider.history.length, itemBuilder: (_, i) {
            final entry = provider.history[i];
            final child = provider.getChild(entry.childId);
            return GestureDetector(
              onTap: () {
                Navigator.pop(ctx);
                _showHistoryDetail(context, entry, child, provider);
              },
              child: Container(
                margin: const EdgeInsets.only(bottom: 8), padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.04), borderRadius: BorderRadius.circular(12)),
                child: Row(children: [
                  Container(width: 32, height: 32, decoration: BoxDecoration(shape: BoxShape.circle, color: entry.isBonus ? const Color(0xFF00E676).withValues(alpha: 0.15) : const Color(0xFFFF1744).withValues(alpha: 0.15)), child: Icon(entry.isBonus ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded, color: entry.isBonus ? const Color(0xFF00E676) : const Color(0xFFFF1744), size: 16)),
                  const SizedBox(width: 10),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(child?.name ?? 'Inconnu', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)), Text(entry.reason, style: TextStyle(fontSize: 11, color: Colors.grey[500]), maxLines: 1, overflow: TextOverflow.ellipsis)])),
                  Text('${entry.isBonus ? '+' : ''}${entry.points}', style: TextStyle(fontWeight: FontWeight.w800, color: entry.isBonus ? const Color(0xFF00E676) : const Color(0xFFFF1744))),
                  const SizedBox(width: 6),
                  Icon(Icons.chevron_right_rounded, color: Colors.white.withValues(alpha: 0.3), size: 16),
                ]),
              ),
            );
          })),
        ])),
      ),
    );
  }

  void _showChildDetail(BuildContext context, dynamic child, FamilyProvider provider) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => ChildDashboardScreen(childId: child.id)));
  }

  Widget _buildModeIndicator(PinProvider pin) {
    final isParent = pin.isParentMode;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: (isParent ? const Color(0xFF7C4DFF) : Colors.orange).withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
      child: Text(isParent ? 'Mode Parent' : 'Mode Enfant', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: isParent ? const Color(0xFF7C4DFF) : Colors.orange)),
    );
  }

  Widget _buildLockButton(PinProvider pin) {
    return IconButton(
      icon: Icon(pin.isParentMode ? Icons.lock_open_rounded : Icons.lock_rounded, color: pin.isParentMode ? const Color(0xFF7C4DFF) : Colors.orange, size: 20),
      constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
      padding: EdgeInsets.zero,
      onPressed: () {
        if (pin.isParentMode) {
          pin.lockParentMode();
        } else {
          Navigator.push(context, MaterialPageRoute(builder: (_) => PinVerificationScreen(onVerified: () { pin.unlockParentMode(); })));
        }
      },
    );
  }

  Widget _buildRefreshButton(FamilyProvider provider, Color primary, bool isDark) {
    return RotationTransition(
      turns: _refreshController,
      child: IconButton(icon: GlowIcon(icon: Icons.refresh_rounded, color: primary, size: 22), constraints: const BoxConstraints(minWidth: 36, minHeight: 36), padding: EdgeInsets.zero, onPressed: _isRefreshing ? null : () => _refreshData(provider)),
    );
  }

  Widget _buildStatChip(IconData icon, String label, Color color, bool isDark) {
    return Expanded(child: Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(12), border: Border.all(color: color.withValues(alpha: 0.2))),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(icon, color: color, size: 16), const SizedBox(width: 6), Flexible(child: Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 12), overflow: TextOverflow.ellipsis))]),
    ));
  }

    Widget _buildQuickAction(IconData icon, String label, Color color, bool isDark, VoidCallback onTap) {
    return Expanded(child: TvFocusWrapper(
      onTap: onTap,
      focusBorderColor: color,
      borderRadius: const BorderRadius.all(Radius.circular(14)),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(14), border: Border.all(color: color.withValues(alpha: 0.25))),
        child: Column(children: [Icon(icon, color: color, size: 24), const SizedBox(height: 6), Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 11))]),
      ),
    ));
  }

