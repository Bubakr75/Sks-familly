// lib/screens/screen_time_new_screen.dart
//
// Nouvel écran Temps d'Écran :
// - Solde de minutes par enfant
// - Chronomètre qui se décompte
// - Bouton prolongation +10 min (parent)
// - Historique des transactions

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/family_provider.dart';
import '../providers/pin_provider.dart';
import '../models/child_model.dart';
import '../config/emerald_theme.dart';

class ScreenTimeNewScreen extends StatefulWidget {
  const ScreenTimeNewScreen({super.key});

  @override
  State<ScreenTimeNewScreen> createState() => _ScreenTimeNewScreenState();
}

class _ScreenTimeNewScreenState extends State<ScreenTimeNewScreen> {
  String? _selectedChildId;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
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
        appBar: AppBar(backgroundColor: Colors.transparent, title: const Text('Temps d\'écran', style: TextStyle(color: Colors.white))),
        body: const Center(child: Text('Aucun enfant', style: TextStyle(color: Colors.white54))),
      );
    }

    final account = fp.getScreenTimeAccount(child.id);

    // Timer pour rafraîchir le chrono
    if (account.isRunning && _timer == null) {
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() {});
        // Auto-stop si temps écoulé
        if (account.sessionRemaining <= 0) {
          // NE PAS auto-stop : laisser l'overtime commencer
          if (!account.isOvertime) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('⏰ Temps écoulé pour ${child.name} ! Viens voir le parent !'),
                backgroundColor: Colors.redAccent, behavior: SnackBarBehavior.floating, duration: const Duration(seconds: 5)),
            );
          }
        }
      });
    } else if (!account.isRunning && _timer != null) {
      _timer?.cancel();
      _timer = null;
    }

    return Scaffold(
      backgroundColor: EmeraldPalette.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text('📺 Temps d\'écran', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Column(
        children: [
          // Sélecteur d'enfant
          if (children.length > 1)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: DropdownButtonFormField<String>(
                value: _selectedChildId ?? children.first.id,
                dropdownColor: EmeraldPalette.surface,
                decoration: InputDecoration(filled: true, fillColor: EmeraldPalette.surfaceLow,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none)),
                items: children.map((c) => DropdownMenuItem(value: c.id,
                  child: Row(children: [
                    Text(c.avatar.isNotEmpty ? c.avatar : '👤', style: const TextStyle(fontSize: 18)),
                    const SizedBox(width: 8),
                    Text(c.name, style: const TextStyle(color: Colors.white)),
                    const Spacer(),
                    Text('${fp.getScreenTimeAccount(c.id).balanceMinutes} min', style: const TextStyle(color: EmeraldPalette.emeraldLight, fontSize: 12)),
                  ]))).toList(),
                onChanged: (v) => setState(() => _selectedChildId = v),
              ),
            ),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  // ─── CHRONO / SOLDE ───
                  if (account.isOvertime) ...[
                    // ⚠️ OVERTIME : temps écoulé, pénalités en cours
                    _OvertimeCard(
                      overtimeMinutes: account.overtimeMinutes,
                      penalty: account.overtimePenalty,
                      onStop: () => fp.stopScreenTimeSession(child.id),
                    ),
                  ] else if (account.isRunning) ...[
                    // Chrono en cours (temps restant)
                    _ChronoCard(
                      remaining: account.sessionRemaining,
                      total: account.sessionMinutes,
                      onStop: () => fp.stopScreenTimeSession(child.id),
                    ),
                  ] else ...[
                    // Solde disponible
                    _BalanceCard(
                      balance: account.balanceMinutes,
                      onStart: account.balanceMinutes > 0
                        ? (mins) => fp.startScreenTimeSession(child.id, mins)
                        : null,
                    ),
                  ],

                  const SizedBox(height: 16),

                  // ─── Prolongation (parent) ───
                  if (isParent) ...[
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: EmeraldPalette.gold.withValues(alpha: 0.2),
                              foregroundColor: EmeraldPalette.goldLight,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            ),
                            icon: const Icon(Icons.add_circle_rounded),
                            label: const Text('+10 min'),
                            onPressed: () {
                              HapticFeedback.mediumImpact();
                              fp.extendScreenTime(child.id, 10);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('✅ +10 min pour ${child.name}'),
                                  backgroundColor: EmeraldPalette.gold),
                              );
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: EmeraldPalette.gold.withValues(alpha: 0.2),
                              foregroundColor: EmeraldPalette.goldLight,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            ),
                            icon: const Icon(Icons.add_circle_outline),
                            label: const Text('+30 min'),
                            onPressed: () {
                              HapticFeedback.mediumImpact();
                              fp.extendScreenTime(child.id, 30);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('✅ +30 min pour ${child.name}'),
                                  backgroundColor: EmeraldPalette.gold),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                  ],

                  // ─── Stats ───
                  Row(
                    children: [
                      Expanded(child: _StatCard(label: 'Gagné', value: '${account.totalEarned} min', color: EmeraldPalette.emerald)),
                      const SizedBox(width: 8),
                      Expanded(child: _StatCard(label: 'Utilisé', value: '${account.totalUsed} min', color: Colors.redAccent)),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // ─── Historique ───
                  if (account.history.isNotEmpty) ...[
                    const Align(alignment: Alignment.centerLeft,
                      child: Text('Historique', style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w600))),
                    const SizedBox(height: 8),
                    ...account.history.take(10).map((t) => _HistoryRow(transaction: t)),
                  ],

                  // ─── Message si solde vide ───
                  if (account.balanceMinutes == 0 && !account.isRunning) ...[
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: EmeraldPalette.surfaceLow,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: EmeraldPalette.glassBorder),
                      ),
                      child: const Column(
                        children: [
                          Text('🎮', style: TextStyle(fontSize: 48)),
                          SizedBox(height: 12),
                          Text('Pas de temps d\'écran disponible', style: TextStyle(color: Colors.white70, fontSize: 15, fontWeight: FontWeight.w600)),
                          SizedBox(height: 4),
                          Text('Va à la boutique pour acheter du temps !', style: TextStyle(color: Colors.white38, fontSize: 12)),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Carte OVERTIME (temps écoulé, pénalités en cours) ──────
class _OvertimeCard extends StatelessWidget {
  final int overtimeMinutes;
  final int penalty;
  final VoidCallback onStop;

  const _OvertimeCard({required this.overtimeMinutes, required this.penalty, required this.onStop});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.redAccent.withValues(alpha: 0.3), Colors.red.withValues(alpha: 0.1)],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.redAccent, width: 2),
        boxShadow: [BoxShadow(color: Colors.redAccent.withValues(alpha: 0.4), blurRadius: 20, spreadRadius: 2)],
      ),
      child: Column(
        children: [
          // Animation pulsation
          const Icon(Icons.warning_rounded, color: Colors.redAccent, size: 56,
            shadows: [Shadow(color: Colors.redAccent, blurRadius: 20)]),
          const SizedBox(height: 12),
          const Text('TEMPS ÉCOULÉ !', style: TextStyle(color: Colors.redAccent, fontSize: 20, fontWeight: FontWeight.w900, letterSpacing: 1)),
          const SizedBox(height: 8),
          Text('${overtimeMinutes} min de retard', style: const TextStyle(color: Colors.white70, fontSize: 16)),
          const SizedBox(height: 16),
          // Pénalité
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.redAccent.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.redAccent.withValues(alpha: 0.5)),
            ),
            child: Column(
              children: [
                const Text('Pénalité en cours', style: TextStyle(color: Colors.white54, fontSize: 12)),
                const SizedBox(height: 4),
                Text('-$penalty pts', style: const TextStyle(color: Colors.redAccent, fontSize: 32, fontWeight: FontWeight.w900)),
                const Text('(-10 pts / 5 min)', style: TextStyle(color: Colors.white38, fontSize: 11)),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Text('L\'enfant doit venir te voir pour arrêter !',
            style: TextStyle(color: Colors.white54, fontSize: 13), textAlign: TextAlign.center),
          const SizedBox(height: 20),
          // Bouton STOP (parent)
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              icon: const Icon(Icons.stop_circle_rounded, size: 28),
              label: const Text('ARRÊTER MAINTENANT', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
              onPressed: () { HapticFeedback.heavyImpact(); onStop(); },
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Carte chrono (session en cours) ──────────────────────────
class _ChronoCard extends StatelessWidget {
  final int remaining;
  final int total;
  final VoidCallback onStop;

  const _ChronoCard({required this.remaining, required this.total, required this.onStop});

  String _formatDuration(int minutes) {
    final h = minutes ~/ 60;
    final m = minutes % 60;
    if (h > 0) return '${h}h ${m}min';
    return '${m}min';
  }

  @override
  Widget build(BuildContext context) {
    final progress = total > 0 ? remaining / total : 0.0;
    final isLow = remaining <= 5;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isLow
            ? [Colors.redAccent.withValues(alpha: 0.2), Colors.redAccent.withValues(alpha: 0.05)]
            : [EmeraldPalette.emerald.withValues(alpha: 0.2), EmeraldPalette.emerald.withValues(alpha: 0.05)],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: isLow ? Colors.redAccent.withValues(alpha: 0.4) : EmeraldPalette.emerald.withValues(alpha: 0.4), width: 2),
      ),
      child: Column(
        children: [
          // Barre de progression
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress.clamp(0.0, 1.0),
              minHeight: 12,
              backgroundColor: Colors.white.withValues(alpha: 0.1),
              valueColor: AlwaysStoppedAnimation<Color>(isLow ? Colors.redAccent : EmeraldPalette.emerald),
            ),
          ),
          const SizedBox(height: 20),
          // Temps restant
          Text(_formatDuration(remaining),
            style: TextStyle(
              fontSize: 56,
              fontWeight: FontWeight.w900,
              color: isLow ? Colors.redAccent : EmeraldPalette.emeraldLight,
              shadows: [Shadow(color: isLow ? Colors.redAccent : EmeraldPalette.emerald, blurRadius: 20)],
            ),
          ),
          const SizedBox(height: 4),
          Text(isLow ? '⚠️ Bientôt fini !' : 'Temps restant',
            style: TextStyle(color: isLow ? Colors.redAccent : Colors.white54, fontSize: 14)),
          const SizedBox(height: 20),
          // Bouton arrêter
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              icon: const Icon(Icons.stop_rounded),
              label: const Text('Arrêter', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
              onPressed: () { HapticFeedback.heavyImpact(); onStop(); },
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Carte solde (pas de session) ────────────────────────────
class _BalanceCard extends StatelessWidget {
  final int balance;
  final void Function(int minutes)? onStart;

  const _BalanceCard({required this.balance, required this.onStart});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [EmeraldPalette.gold.withValues(alpha: 0.2), EmeraldPalette.gold.withValues(alpha: 0.05)],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: EmeraldPalette.gold.withValues(alpha: 0.4), width: 2),
      ),
      child: Column(
        children: [
          const Text('⏱️', style: TextStyle(fontSize: 48)),
          const SizedBox(height: 12),
          Text('$balance', style: const TextStyle(fontSize: 56, fontWeight: FontWeight.w900, color: EmeraldPalette.goldLight,
            shadows: [Shadow(color: EmeraldPalette.gold, blurRadius: 20)])),
          const Text('minutes disponibles', style: TextStyle(color: Colors.white54, fontSize: 14)),
          if (onStart != null) ...[
            const SizedBox(height: 20),
            const Text('Démarrer une session :', style: TextStyle(color: Colors.white70, fontSize: 13)),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: _StartButton(label: '15 min', minutes: 15, onTap: () => onStart!(15))),
                const SizedBox(width: 8),
                Expanded(child: _StartButton(label: '30 min', minutes: 30, onTap: () => onStart!(30))),
                const SizedBox(width: 8),
                Expanded(child: _StartButton(label: 'Tout', minutes: balance, onTap: () => onStart!(balance))),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _StartButton extends StatelessWidget {
  final String label;
  final int minutes;
  final VoidCallback onTap;

  const _StartButton({required this.label, required this.minutes, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: EmeraldPalette.emerald,
        foregroundColor: const Color(0xFF051410),
        padding: const EdgeInsets.symmetric(vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      onPressed: onTap,
      child: Text(label, style: const TextStyle(fontWeight: FontWeight.w800)),
    );
  }
}

// ─── Carte stats ──────────────────────────────────────────────
class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatCard({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: EmeraldPalette.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: color)),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(color: Colors.white54, fontSize: 11)),
        ],
      ),
    );
  }
}

// ─── Ligne historique ─────────────────────────────────────────
class _HistoryRow extends StatelessWidget {
  final dynamic transaction;

  const _HistoryRow({required this.transaction});

  @override
  Widget build(BuildContext context) {
    final isEarned = transaction.type == 'earned';
    final color = isEarned ? EmeraldPalette.emerald : Colors.redAccent;

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Icon(isEarned ? Icons.add_circle_rounded : Icons.remove_circle_rounded, color: color, size: 16),
          const SizedBox(width: 8),
          Expanded(child: Text(transaction.reason, style: const TextStyle(color: Colors.white70, fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis)),
          Text('${isEarned ? "+" : "-"}${transaction.minutes} min', style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}
