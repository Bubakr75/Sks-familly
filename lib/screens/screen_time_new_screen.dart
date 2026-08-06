// lib/screens/screen_time_new_screen.dart
//
// Temps d'Écran — Design premium type Apple Watch
// Horloge circulaire avec anneau de progression, glass morphism
// États : Solde → Session en cours → Overtime

import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/family_provider.dart';
import '../providers/pin_provider.dart';
import '../models/child_model.dart';
import '../config/emerald_theme.dart';
import 'punishment_lines_screen.dart';

class ScreenTimeNewScreen extends StatefulWidget {
  const ScreenTimeNewScreen({super.key});

  @override
  State<ScreenTimeNewScreen> createState() => _ScreenTimeNewScreenState();
}

class _ScreenTimeNewScreenState extends State<ScreenTimeNewScreen>
    with TickerProviderStateMixin {
  String? _selectedChildId;
  Timer? _timer;
  late AnimationController _pulseController;
  late AnimationController _tickController;
  late Animation<double> _pulse;
  late Animation<double> _tick;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _tickController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat();
    _pulse = CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut);
    _tick = CurvedAnimation(parent: _tickController, curve: Curves.linear);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pulseController.dispose();
    _tickController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fp = context.watch<FamilyProvider>();
    final isParent = context.watch<PinProvider>().isParentMode;
    final children = fp.children;

    final child = _selectedChildId != null
        ? fp.getChild(_selectedChildId!)
        : (children.isNotEmpty ? children.first : null);

    if (child == null) {
      return Scaffold(
        backgroundColor: EmeraldPalette.background,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          title: const Text("Temps d'écran",
              style: TextStyle(color: Colors.white)),
        ),
        body: const Center(
            child:
                Text('Aucun enfant', style: TextStyle(color: Colors.white54))),
      );
    }

    final account = fp.getScreenTimeAccount(child.id);

    if (!isParent && fp.isScreenAccessBlocked(child.id)) {
      final pending = fp.pendingPenaltyLinesForChild(child.id);
      final total = pending.fold<int>(0, (sum, item) => sum + item.totalLines);
      return Scaffold(
        backgroundColor: EmeraldPalette.background,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          title: const Text(
            "Temps d’écran interdit",
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ),
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: Colors.red.shade900,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.orangeAccent, width: 2),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.phonelink_erase_rounded,
                    color: Colors.white,
                    size: 58,
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Lignes de pénalité en attente',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'L’accès aux écrans est interdit jusqu’à ce que tes lignes soient terminées et validées par un parent.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white, fontSize: 15),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '$total ligne${total > 1 ? 's' : ''} à faire',
                    style: const TextStyle(
                      color: Colors.amberAccent,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const PunishmentLinesScreen(),
                      ),
                    ),
                    icon: const Icon(Icons.visibility_rounded),
                    label: const Text('Voir mes lignes'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    // Timer 1s pour rafraîchir le chrono
    if (account.isRunning && _timer == null) {
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() {});
      });
    } else if (!account.isRunning && _timer != null) {
      _timer?.cancel();
      _timer = null;
    }

    return Scaffold(
      backgroundColor: EmeraldPalette.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text("Temps d'écran",
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Column(
        children: [
          // ── Sélecteur d'enfants (avatars) ──
          if (children.length > 1)
            SizedBox(
              height: 72,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                itemCount: children.length,
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (_, i) {
                  final c = children[i];
                  final isSel = c.id == child.id;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedChildId = c.id),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSel
                            ? EmeraldPalette.emerald.withValues(alpha: 0.18)
                            : Colors.white.withValues(alpha: 0.04),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color:
                              isSel ? EmeraldPalette.emerald : Colors.white12,
                          width: isSel ? 2 : 1,
                        ),
                      ),
                      child: Row(children: [
                        Text(c.avatar.isNotEmpty ? c.avatar : '👤',
                            style: const TextStyle(fontSize: 22)),
                        const SizedBox(width: 8),
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(c.name,
                                style: TextStyle(
                                    color: isSel
                                        ? EmeraldPalette.emeraldLight
                                        : Colors.white70,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700)),
                            Text(
                                '${fp.getScreenTimeAccount(c.id).balanceMinutes} min',
                                style: TextStyle(
                                    color: EmeraldPalette.gold, fontSize: 11)),
                          ],
                        ),
                      ]),
                    ),
                  );
                },
              ),
            ),

          // ── Horloge / Solde ──
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(children: [
                // Horloge circulaire
                if (account.isOvertime)
                  _OvertimeClock(
                    overtimeMinutes: account.overtimeMinutes,
                    penalty: account.overtimePenalty,
                    pulseAnim: _pulse,
                    onStop: () {
                      HapticFeedback.heavyImpact();
                      fp.stopScreenTimeSession(child.id);
                    },
                  )
                else if (account.isRunning)
                  _SessionClock(
                    remaining: account.sessionRemaining,
                    total: account.sessionMinutes,
                    tickAnim: _tick,
                    onStop: () {
                      HapticFeedback.heavyImpact();
                      fp.stopScreenTimeSession(child.id);
                    },
                  )
                else
                  _BalanceClock(
                    balance: account.balanceMinutes,
                    onStart: account.balanceMinutes > 0
                        ? (mins) {
                            HapticFeedback.mediumImpact();
                            fp.startScreenTimeSession(child.id, mins);
                          }
                        : null,
                  ),

                const SizedBox(height: 20),

                // ── Prolongation (parent) ──
                if (isParent && account.isRunning) ...[
                  _buildExtendTimeRow(child, fp),
                  const SizedBox(height: 20),
                ],

                // ── Stats ──
                Row(children: [
                  _StatChip(
                    icon: Icons.trending_up_rounded,
                    label: 'Gagné',
                    value: '${account.totalEarned} min',
                    color: EmeraldPalette.emerald,
                  ),
                  const SizedBox(width: 10),
                  _StatChip(
                    icon: Icons.trending_down_rounded,
                    label: 'Utilisé',
                    value: '${account.totalUsed} min',
                    color: Colors.redAccent,
                  ),
                  const SizedBox(width: 10),
                  _StatChip(
                    icon: Icons.savings_rounded,
                    label: 'Solde',
                    value: '${account.balanceMinutes} min',
                    color: EmeraldPalette.gold,
                  ),
                ]),

                const SizedBox(height: 20),

                // ── Historique ──
                if (account.history.isNotEmpty) ...[
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Historique',
                        style: TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                            fontWeight: FontWeight.w600)),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: EmeraldPalette.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: EmeraldPalette.glassBorder),
                    ),
                    child: Column(
                      children: account.history
                          .take(8)
                          .map((t) => _HistoryTile(transaction: t))
                          .toList(),
                    ),
                  ),
                ],
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExtendTimeRow(ChildModel child, FamilyProvider fp) {
    return Row(children: [
      Expanded(
        child: _GlassButton(
          label: '+10 min',
          icon: Icons.add_rounded,
          color: EmeraldPalette.gold,
          onTap: () {
            HapticFeedback.mediumImpact();
            fp.extendScreenTime(child.id, 10);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                  content: Text('+10 min pour ${child.name}'),
                  backgroundColor: EmeraldPalette.gold),
            );
          },
        ),
      ),
      const SizedBox(width: 8),
      Expanded(
        child: _GlassButton(
          label: '+30 min',
          icon: Icons.add_rounded,
          color: EmeraldPalette.goldLight,
          onTap: () {
            HapticFeedback.mediumImpact();
            fp.extendScreenTime(child.id, 30);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                  content: Text('+30 min pour ${child.name}'),
                  backgroundColor: EmeraldPalette.gold),
            );
          },
        ),
      ),
    ]);
  }
}

// ════════════════════════════════════════════════════════════════
// 🕐 HORLOGE CIRCULAIRE — Session en cours
// ════════════════════════════════════════════════════════════════
class _SessionClock extends StatelessWidget {
  final int remaining; // minutes
  final int total;
  final Animation<double> tickAnim;
  final VoidCallback onStop;

  const _SessionClock({
    required this.remaining,
    required this.total,
    required this.tickAnim,
    required this.onStop,
  });

  String _formatClock() {
    // Affiche en format mm:ss (on déduit les secondes du tick)
    final now = DateTime.now();
    final sec = 60 - now.second;
    final m = remaining;
    if (m >= 60) {
      final h = m ~/ 60;
      final mm = m % 60;
      return '${h.toString().padLeft(2, '0')}:${mm.toString().padLeft(2, '0')}';
    }
    return '${m.toString().padLeft(2, '0')}:${(sec % 60).toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final progress = total > 0 ? remaining / total : 0.0;
    final isLow = remaining <= 5;
    final color = isLow ? Colors.redAccent : EmeraldPalette.emerald;

    return AnimatedBuilder(
      animation: tickAnim,
      builder: (context, _) {
        return CustomPaint(
          painter: _ClockPainter(
            progress: progress.clamp(0.0, 1.0),
            color: color,
            bgColor: Colors.white.withValues(alpha: 0.06),
            tickProgress: tickAnim.value,
          ),
          child: SizedBox(
            width: 280,
            height: 280,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                    isLow
                        ? Icons.timer_rounded
                        : Icons.play_circle_fill_rounded,
                    color: color,
                    size: 32),
                const SizedBox(height: 4),
                Text(
                  _formatClock(),
                  style: const TextStyle(
                    fontSize: 52,
                    fontWeight: FontWeight.w200,
                    color: Colors.white,
                    letterSpacing: 2,
                    height: 1,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    isLow ? 'Bientôt fini' : 'En cours',
                    style: TextStyle(
                        color: color,
                        fontSize: 12,
                        fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ════════════════════════════════════════════════════════════════
// ⚠️ HORLOGE OVERTIME — temps écoulé
// ════════════════════════════════════════════════════════════════
class _OvertimeClock extends StatelessWidget {
  final int overtimeMinutes;
  final int penalty;
  final Animation<double> pulseAnim;
  final VoidCallback onStop;

  const _OvertimeClock({
    required this.overtimeMinutes,
    required this.penalty,
    required this.pulseAnim,
    required this.onStop,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: pulseAnim,
      builder: (context, _) {
        final pulse = pulseAnim.value;
        return Column(children: [
          CustomPaint(
            painter: _ClockPainter(
              progress: 1.0,
              color: Colors.redAccent.withValues(alpha: 0.6 + 0.4 * pulse),
              bgColor: Colors.redAccent.withValues(alpha: 0.1),
              tickProgress: 0,
              pulse: pulse,
            ),
            child: SizedBox(
              width: 280,
              height: 280,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.warning_amber_rounded,
                      color:
                          Colors.redAccent.withValues(alpha: 0.7 + 0.3 * pulse),
                      size: 36 + 4 * pulse),
                  const SizedBox(height: 4),
                  Text(
                    '+${overtimeMinutes}min',
                    style: TextStyle(
                      fontSize: 48,
                      fontWeight: FontWeight.w800,
                      color: Colors.redAccent
                          .withValues(alpha: 0.85 + 0.15 * pulse),
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.redAccent.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'En retard',
                      style: TextStyle(
                          color: Colors.redAccent,
                          fontSize: 12,
                          fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Carte pénalité
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [
                Colors.redAccent.withValues(alpha: 0.2),
                Colors.redAccent.withValues(alpha: 0.05),
              ]),
              borderRadius: BorderRadius.circular(20),
              border:
                  Border.all(color: Colors.redAccent.withValues(alpha: 0.4)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.remove_circle_rounded,
                    color: Colors.redAccent, size: 24),
                const SizedBox(width: 10),
                Text('-$penalty pts',
                    style: const TextStyle(
                        color: Colors.redAccent,
                        fontSize: 28,
                        fontWeight: FontWeight.w900)),
                const SizedBox(width: 8),
                const Text('(-10 / 5 min)',
                    style: TextStyle(color: Colors.white38, fontSize: 12)),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Bouton STOP
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                elevation: 8,
                shadowColor: Colors.redAccent.withValues(alpha: 0.4),
              ),
              icon: const Icon(Icons.stop_circle_rounded, size: 28),
              label: const Text('ARRÊTER',
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
              onPressed: onStop,
            ),
          ),
        ]);
      },
    );
  }
}

// ════════════════════════════════════════════════════════════════
// ⏱️ HORLOGE SOLDE — pas de session
// ════════════════════════════════════════════════════════════════
class _BalanceClock extends StatelessWidget {
  final int balance;
  final void Function(int minutes)? onStart;

  const _BalanceClock({required this.balance, required this.onStart});

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      CustomPaint(
        painter: _ClockPainter(
          progress: 0.0,
          color: EmeraldPalette.gold,
          bgColor: Colors.white.withValues(alpha: 0.06),
          tickProgress: 0,
        ),
        child: SizedBox(
          width: 280,
          height: 280,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.hourglass_top_rounded,
                  color: EmeraldPalette.goldLight, size: 32),
              const SizedBox(height: 4),
              Text(
                '$balance',
                style: const TextStyle(
                  fontSize: 64,
                  fontWeight: FontWeight.w200,
                  color: Colors.white,
                  letterSpacing: 1,
                ),
              ),
              const Text('minutes dispo',
                  style: TextStyle(color: Colors.white54, fontSize: 13)),
            ],
          ),
        ),
      ),
      const SizedBox(height: 20),
      if (onStart != null) ...[
        const Text('Démarrer une session',
            style: TextStyle(
                color: Colors.white70,
                fontSize: 13,
                fontWeight: FontWeight.w600)),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(
              child: _GlassButton(
            label: '15 min',
            icon: Icons.play_arrow_rounded,
            color: EmeraldPalette.emerald,
            onTap: () => onStart!(15),
          )),
          const SizedBox(width: 8),
          Expanded(
              child: _GlassButton(
            label: '30 min',
            icon: Icons.play_arrow_rounded,
            color: EmeraldPalette.emerald,
            onTap: () => onStart!(30),
          )),
          const SizedBox(width: 8),
          Expanded(
              child: _GlassButton(
            label: 'Tout',
            icon: Icons.fast_forward_rounded,
            color: EmeraldPalette.emeraldLight,
            onTap: () => onStart!(balance),
          )),
        ]),
      ] else ...[
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: EmeraldPalette.surfaceLow,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: EmeraldPalette.glassBorder),
          ),
          child: const Column(children: [
            Text('🎮', style: TextStyle(fontSize: 40)),
            SizedBox(height: 8),
            Text("Pas de temps d'écran",
                style: TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                    fontWeight: FontWeight.w600)),
            Text('Va à la boutique !',
                style: TextStyle(color: Colors.white38, fontSize: 12)),
          ]),
        ),
      ],
    ]);
  }
}

// ════════════════════════════════════════════════════════════════
// 🎨 PEINTRE DE L'HORLOGE CIRCULAIRE
// ════════════════════════════════════════════════════════════════
class _ClockPainter extends CustomPainter {
  final double progress; // 0.0 → 1.0
  final Color color;
  final Color bgColor;
  final double tickProgress; // pour l'aiguille des secondes
  final double pulse; // 0→1 pour l'effet pulsation

  _ClockPainter({
    required this.progress,
    required this.color,
    required this.bgColor,
    this.tickProgress = 0,
    this.pulse = 0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 18;

    // ── Anneau de fond ──
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 10
        ..color = bgColor,
    );

    // ── Graduations (60 ticks comme une vraie horloge) ──
    for (int i = 0; i < 60; i++) {
      final angle = (i * 6 - 90) * math.pi / 180;
      final isMajor = i % 5 == 0;
      final tickLen = isMajor ? 12.0 : 6.0;
      final inner = radius - 22;
      final outer = inner - tickLen;
      canvas.drawLine(
        Offset(
          center.dx + inner * math.cos(angle),
          center.dy + inner * math.sin(angle),
        ),
        Offset(
          center.dx + outer * math.cos(angle),
          center.dy + outer * math.sin(angle),
        ),
        Paint()
          ..color = isMajor
              ? Colors.white.withValues(alpha: 0.25)
              : Colors.white.withValues(alpha: 0.08)
          ..strokeWidth = isMajor ? 2 : 1,
      );
    }

    // ── Anneau de progression (arc coloré) ──
    if (progress > 0) {
      final sweep = progress * 360;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -math.pi / 2, // commence en haut
        sweep * math.pi / 180,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 10
          ..strokeCap = StrokeCap.round
          ..color = color,
      );

      // Point lumineux au bout de l'arc
      final endAngle = (-90 + sweep) * math.pi / 180;
      canvas.drawCircle(
        Offset(
          center.dx + radius * math.cos(endAngle),
          center.dy + radius * math.sin(endAngle),
        ),
        8,
        Paint()..color = Colors.white.withValues(alpha: 0.9),
      );
    }

    // ── Aiguille des secondes (si session active) ──
    if (tickProgress > 0 && progress > 0 && progress < 1) {
      final secAngle = (tickProgress * 360 - 90) * math.pi / 180;
      final handLen = radius - 28;
      canvas.drawLine(
        center,
        Offset(
          center.dx + handLen * math.cos(secAngle),
          center.dy + handLen * math.sin(secAngle),
        ),
        Paint()
          ..color = Colors.white.withValues(alpha: 0.3)
          ..strokeWidth = 1.5
          ..strokeCap = StrokeCap.round,
      );
    }

    // ── Pulsation (pour overtime) ──
    if (pulse > 0) {
      canvas.drawCircle(
        center,
        radius + 6 * pulse,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3 * (1 - pulse)
          ..color = Colors.redAccent.withValues(alpha: (1 - pulse) * 0.4),
      );
    }

    // ── Glow central ──
    canvas.drawCircle(
      center,
      radius * 0.6,
      Paint()
        ..shader = RadialGradient(colors: [
          color.withValues(alpha: 0.06 + 0.04 * pulse),
          Colors.transparent,
        ]).createShader(Rect.fromCircle(center: center, radius: radius * 0.6)),
    );
  }

  @override
  bool shouldRepaint(covariant _ClockPainter old) =>
      old.progress != progress ||
      old.tickProgress != tickProgress ||
      old.pulse != pulse;
}

// ════════════════════════════════════════════════════════════════
// 🎯 WIDGETS UTILITAIRES
// ════════════════════════════════════════════════════════════════
class _GlassButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _GlassButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 6),
            Text(label,
                style: TextStyle(
                    color: color, fontSize: 15, fontWeight: FontWeight.w800)),
          ],
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatChip({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: EmeraldPalette.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(height: 4),
          Text(value,
              style: TextStyle(
                  color: color, fontSize: 15, fontWeight: FontWeight.w800)),
          Text(label,
              style: const TextStyle(color: Colors.white38, fontSize: 10)),
        ]),
      ),
    );
  }
}

class _HistoryTile extends StatelessWidget {
  final dynamic transaction;

  const _HistoryTile({required this.transaction});

  @override
  Widget build(BuildContext context) {
    final isEarned = transaction.type == 'earned';
    final color = isEarned ? EmeraldPalette.emerald : Colors.redAccent;
    final timeStr = _formatTime(transaction.date);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.white10, width: 0.5)),
      ),
      child: Row(children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          child: Icon(isEarned ? Icons.add_rounded : Icons.remove_rounded,
              color: color, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(transaction.reason,
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
              Text(timeStr,
                  style: const TextStyle(color: Colors.white24, fontSize: 10)),
            ],
          ),
        ),
        Text(
          '${isEarned ? '+' : '-'}${transaction.minutes} min',
          style: TextStyle(
              color: color, fontSize: 14, fontWeight: FontWeight.w800),
        ),
      ]),
    );
  }

  String _formatTime(DateTime d) {
    return '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')} · '
        '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}';
  }
}
