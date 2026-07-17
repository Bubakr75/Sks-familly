// lib/screens/school_notes_weekly_screen.dart
//
// 📚 Notes Scolaires Hebdomadaires — refonte complète
// - Multi-enfants (notation rapide de tous en même temps)
// - Évaluation hebdomadaire (pas journalière)
// - Calcul automatique des points (10 à 200 selon la note)
// - Intègre l'historique de la semaine (bonus, immunités)
// - Note IA Gemini
// - Tout l'historique de la semaine est pris en compte

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/family_provider.dart';
import '../config/emerald_theme.dart';
import '../models/child_model.dart';
import '../services/gemini_service.dart';

class SchoolNotesWeeklyScreen extends StatefulWidget {
  const SchoolNotesWeeklyScreen({super.key});

  @override
  State<SchoolNotesWeeklyScreen> createState() =>
      _SchoolNotesWeeklyScreenState();
}

class _SchoolNotesWeeklyScreenState extends State<SchoolNotesWeeklyScreen>
    with SingleTickerProviderStateMixin {
  late TabController _weekTabController;
  DateTime _weekStart = _getWeekStart(DateTime.now());

  // notes par enfant pour la semaine : { childId: { 'note': int, 'comment': String, 'aiNote': int, 'aiAppreciation': String } }
  Map<String, Map<String, dynamic>> _weeklyNotes = {};
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _weekTabController = TabController(length: 2, vsync: this);
    _loadWeekNotes();
  }

  @override
  void dispose() {
    _weekTabController.dispose();
    super.dispose();
  }

  static DateTime _getWeekStart(DateTime date) {
    final monday = date.subtract(Duration(days: date.weekday - 1));
    return DateTime(monday.year, monday.month, monday.day);
  }

  String get _weekKey =>
      '${_weekStart.year}_${_weekStart.month}_${_weekStart.day}';

  Future<void> _loadWeekNotes() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('weekly_notes_$_weekKey');
    if (raw != null) {
      setState(() {
        _weeklyNotes = Map<String, Map<String, dynamic>>.from(
          (jsonDecode(raw) as Map).map((k, v) =>
              MapEntry(k as String, Map<String, dynamic>.from(v))),
        );
      });
    } else {
      setState(() => _weeklyNotes = {});
    }
  }

  Future<void> _saveWeekNotes() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('weekly_notes_$_weekKey', jsonEncode(_weeklyNotes));
  }

  /// Calcule les stats de la semaine pour un enfant
  /// (bonus, pénalités, immunités, pour l'évaluation globale)
  Map<String, int> _getChildWeekStats(String childId, FamilyProvider fp) {
    final weekEnd = _weekStart.add(const Duration(days: 7));
    final entries = fp.history.where((h) =>
        h.childId == childId &&
        h.date.isAfter(_weekStart.subtract(const Duration(seconds: 1))) &&
        h.date.isBefore(weekEnd));

    int bonusPts = 0, penaltyPts = 0, bonusCount = 0, penaltyCount = 0;
    for (final h in entries) {
      if (h.isBonus) {
        bonusPts += h.points;
        bonusCount++;
      } else {
        penaltyPts += h.points;
        penaltyCount++;
      }
    }

    // Immunités de la semaine
    final immunities = fp.immunities
        .where((im) =>
            im.childId == childId &&
            im.createdAt.isAfter(_weekStart.subtract(const Duration(seconds: 1))) &&
            im.createdAt.isBefore(weekEnd))
        .length;

    return {
      'bonusPts': bonusPts,
      'penaltyPts': penaltyPts,
      'bonusCount': bonusCount,
      'penaltyCount': penaltyCount,
      'immunities': immunities,
      'net': bonusPts - penaltyPts,
    };
  }

  /// Calcule les points de bonus à attribuer selon la note (sur 20)
  /// Note 20 → 200 pts, Note 10 → 50 pts, Note < 8 → 10 pts
  int _noteToPoints(int note) {
    if (note >= 20) return 200;
    if (note >= 18) return 180;
    if (note >= 16) return 150;
    if (note >= 14) return 120;
    if (note >= 12) return 90;
    if (note >= 10) return 60;
    if (note >= 8) return 30;
    return 10;
  }

  /// Note suggérée par l'app en fonction des stats de la semaine
  int _suggestedNote(Map<String, int> stats) {
    // Base : équilibre bonus/pénalité
    final net = stats['net'] ?? 0;
    final bonusCount = stats['bonusCount'] ?? 0;
    final penaltyCount = stats['penaltyCount'] ?? 0;
    final immunities = stats['immunities'] ?? 0;

    // Commencer à 12 (moyen)
    int note = 12;
    // Ajuster selon le net
    note += (net ~/ 15).clamp(-5, 6);
    // Bonus pour régularité
    if (bonusCount > 7) note += 2;
    if (penaltyCount == 0) note += 1;
    // Pénalité si beaucoup de pénalités
    if (penaltyCount > 5) note -= 2;
    // Bonus immunités (bon comportement)
    note += immunities.clamp(0, 2);

    return note.clamp(0, 20);
  }

  /// Évaluation IA Gemini pour un enfant
  Future<void> _evaluateWithAI(
      ChildModel child, FamilyProvider fp) async {
    if (_loading) return;
    setState(() => _loading = true);

    final stats = _getChildWeekStats(child.id, fp);
    final currentNote =
        (_weeklyNotes[child.id]?['note'] as int?) ?? _suggestedNote(stats);
    final comment =
        (_weeklyNotes[child.id]?['comment'] as String?) ?? '';

    try {
      final result = await GeminiService.chatFamilyAssistant(
        message:
          'Évalue la semaine de ${child.name} : '
          'Note actuelle proposée : $currentNote/20. '
          'Bonus : ${stats['bonusCount']} (${stats['bonusPts']} pts). '
          'Pénalités : ${stats['penaltyCount']} (${stats['penaltyPts']} pts). '
          'Immunités gagnées : ${stats['immunities']}. '
          'Commentaire parent : "$comment". '
          'Donne une note sur 20 et une appréciation en 2 phrases.',
        familyContext: 'Évaluation scolaire hebdomadaire de ${child.name}',
      );

      // Essayer d'extraire la note
      final noteMatch = RegExp(r'(\d{1,2})(?:\s*/\s*20)?')
          .firstMatch(result.split('\n').first);
      final aiNote = noteMatch != null
          ? int.tryParse(noteMatch.group(1)!) ?? currentNote
          : currentNote;

      setState(() {
        _weeklyNotes[child.id] ??= {};
        _weeklyNotes[child.id]!['aiNote'] = aiNote.clamp(0, 20);
        _weeklyNotes[child.id]!['aiAppreciation'] = result;
      });
      await _saveWeekNotes();
    } catch (_) {
      // Fallback silencieux
    }

    setState(() => _loading = false);
  }

  /// Évalue tous les enfants d'un coup avec l'IA
  Future<void> _evaluateAllWithAI(FamilyProvider fp) async {
    for (final child in fp.children) {
      await _evaluateWithAI(child, fp);
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('🤖 Évaluations IA terminées pour tous les enfants'),
          backgroundColor: Colors.deepPurpleAccent,
        ),
      );
    }
  }

  /// Valide les notes de la semaine → attribue les points
  Future<void> _validateWeek(FamilyProvider fp) async {
    bool anyValidated = false;
    for (final child in fp.children) {
      final noteData = _weeklyNotes[child.id];
      if (noteData == null) continue;
      final note = (noteData['note'] as int?) ?? 0;
      if (note == 0) continue;

      final points = _noteToPoints(note);
      final appreciation = noteData['aiAppreciation'] as String? ?? '';

      // Attribuer les points bonus
      await fp.addPoints(
        child.id,
        points,
        '📚 Note de la semaine : $note/20',
        category: 'school_note',
        isBonus: true,
      );

      // Marquer comme validé
      noteData['validated'] = true;
      noteData['pointsAwarded'] = points;
      anyValidated = true;
    }

    if (anyValidated) {
      await _saveWeekNotes();
      HapticFeedback.heavyImpact();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                '✅ Notes validées ! Points attribués pour ${_weeklyNotes.length} enfant(s).'),
            backgroundColor: EmeraldPalette.emerald,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final fp = context.watch<FamilyProvider>();
    final children = fp.children;

    return Scaffold(
      backgroundColor: EmeraldPalette.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text('📚 Notes de la semaine',
            style: TextStyle(
                color: EmeraldPalette.textPrimary,
                fontWeight: FontWeight.bold)),
        iconTheme: const IconThemeData(color: EmeraldPalette.textPrimary),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_today_rounded,
                color: EmeraldPalette.emeraldLight, size: 22),
            onPressed: () => _changeWeek(context),
          ),
        ],
      ),
      body: children.isEmpty
          ? const Center(
              child: Text('Aucun enfant',
                  style: TextStyle(color: Colors.white54)))
          : Column(
              children: [
                // ── Bandeau semaine ──
                _buildWeekHeader(),

                // ── Actions rapides ──
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: _ActionChip(
                          icon: Icons.auto_awesome_rounded,
                          label: 'Évaluer avec IA',
                          color: Colors.deepPurpleAccent,
                          onTap: _loading ? null : () => _evaluateAllWithAI(fp),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _ActionChip(
                          icon: Icons.check_circle_rounded,
                          label: 'Valider la semaine',
                          color: EmeraldPalette.emerald,
                          onTap: () => _validateWeek(fp),
                        ),
                      ),
                    ],
                  ),
                ),

                // ── Liste des enfants ──
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                    itemCount: children.length,
                    itemBuilder: (context, index) {
                      final child = children[index];
                      final stats = _getChildWeekStats(child.id, fp);
                      final noteData = _weeklyNotes[child.id] ?? {};
                      final note = (noteData['note'] as int?) ??
                          _suggestedNote(stats);
                      final validated =
                          (noteData['validated'] as bool?) ?? false;

                      return _ChildNoteCard(
                        child: child,
                        stats: stats,
                        currentNote: note,
                        comment: (noteData['comment'] as String?) ?? '',
                        aiNote: noteData['aiNote'] as int?,
                        aiAppreciation:
                            noteData['aiAppreciation'] as String?,
                        validated: validated,
                        pointsAwarded:
                            noteData['pointsAwarded'] as int?,
                        loading: _loading,
                        onNoteChanged: (newNote) async {
                          setState(() {
                            _weeklyNotes[child.id] ??= {};
                            _weeklyNotes[child.id]!['note'] = newNote;
                          });
                          await _saveWeekNotes();
                        },
                        onCommentChanged: (newComment) async {
                          setState(() {
                            _weeklyNotes[child.id] ??= {};
                            _weeklyNotes[child.id]!['comment'] = newComment;
                          });
                          await _saveWeekNotes();
                        },
                        onEvaluate: () => _evaluateWithAI(child, fp),
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildWeekHeader() {
    final weekEnd = _weekStart.add(const Duration(days: 6));
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: EmeraldPalette.surfaceLow,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: EmeraldPalette.glassBorder),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.date_range_rounded,
              color: EmeraldPalette.emeraldLight, size: 18),
          const SizedBox(width: 8),
          Text(
            'Semaine du ${_weekStart.day.toString().padLeft(2, '0')}/${_weekStart.month.toString().padLeft(2, '0')} au ${weekEnd.day.toString().padLeft(2, '0')}/${weekEnd.month.toString().padLeft(2, '0')}',
            style: const TextStyle(
                color: Colors.white70,
                fontSize: 14,
                fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  void _changeWeek(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: EmeraldPalette.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 16),
            const Text('Changer de semaine',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.chevron_left_rounded,
                  color: Colors.white),
              title: const Text('Semaine précédente',
                  style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(ctx);
                setState(() {
                  _weekStart =
                      _weekStart.subtract(const Duration(days: 7));
                });
                _loadWeekNotes();
              },
            ),
            ListTile(
              leading: const Icon(Icons.today_rounded,
                  color: EmeraldPalette.emeraldLight),
              title: const Text('Cette semaine',
                  style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(ctx);
                setState(() {
                  _weekStart = _getWeekStart(DateTime.now());
                });
                _loadWeekNotes();
              },
            ),
            ListTile(
              leading:
                  const Icon(Icons.chevron_right_rounded, color: Colors.white),
              title: const Text('Semaine suivante',
                  style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(ctx);
                setState(() {
                  _weekStart = _weekStart.add(const Duration(days: 7));
                });
                _loadWeekNotes();
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// CARTE NOTE PAR ENFANT — rapide à remplir
// ════════════════════════════════════════════════════════════════
class _ChildNoteCard extends StatelessWidget {
  final ChildModel child;
  final Map<String, int> stats;
  final int currentNote;
  final String comment;
  final int? aiNote;
  final String? aiAppreciation;
  final bool validated;
  final int? pointsAwarded;
  final bool loading;
  final ValueChanged<int> onNoteChanged;
  final ValueChanged<String> onCommentChanged;
  final VoidCallback onEvaluate;

  const _ChildNoteCard({
    required this.child,
    required this.stats,
    required this.currentNote,
    required this.comment,
    required this.aiNote,
    required this.aiAppreciation,
    required this.validated,
    required this.pointsAwarded,
    required this.loading,
    required this.onNoteChanged,
    required this.onCommentChanged,
    required this.onEvaluate,
  });

  Color _noteColor(int note) {
    if (note >= 16) return EmeraldPalette.emerald;
    if (note >= 12) return EmeraldPalette.gold;
    if (note >= 8) return Colors.orange;
    return Colors.redAccent;
  }

  int _noteToPoints(int note) {
    if (note >= 20) return 200;
    if (note >= 18) return 180;
    if (note >= 16) return 150;
    if (note >= 14) return 120;
    if (note >= 12) return 90;
    if (note >= 10) return 60;
    if (note >= 8) return 30;
    return 10;
  }

  @override
  Widget build(BuildContext context) {
    final noteColor = _noteColor(currentNote);
    final points = validated ? (pointsAwarded ?? 0) : _noteToPoints(currentNote);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: EmeraldPalette.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
            color: validated
                ? EmeraldPalette.emerald.withValues(alpha: 0.5)
                : noteColor.withValues(alpha: 0.25)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header : enfant + note ──
            Row(
              children: [
                Text(child.avatar.isNotEmpty ? child.avatar : '👤',
                    style: const TextStyle(fontSize: 28)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(child.name,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w800)),
                ),
                if (validated) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: EmeraldPalette.emerald.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text('+$points pts',
                        style: const TextStyle(
                            color: EmeraldPalette.emeraldLight,
                            fontSize: 13,
                            fontWeight: FontWeight.w800)),
                  ),
                  const SizedBox(width: 6),
                  const Icon(Icons.check_circle,
                      color: EmeraldPalette.emerald, size: 20),
                ] else ...[
                  // Note sur 20
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: noteColor.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: noteColor.withValues(alpha: 0.4)),
                    ),
                    child: Text('$currentNote/20',
                        style: TextStyle(
                            color: noteColor,
                            fontSize: 16,
                            fontWeight: FontWeight.w900)),
                  ),
                ],
              ],
            ),

            if (!validated) ...[
              const SizedBox(height: 14),

              // ── Sélecteur de note rapide (slider) ──
              Row(
                children: [
                  const Text('Note :',
                      style: TextStyle(color: Colors.white54, fontSize: 13)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Slider(
                      value: currentNote.toDouble(),
                      min: 0,
                      max: 20,
                      divisions: 20,
                      activeColor: noteColor,
                      label: '$currentNote/20 (+${_noteToPoints(currentNote)} pts)',
                      onChanged: (v) => onNoteChanged(v.round()),
                    ),
                  ),
                ],
              ),

              // ── Stats de la semaine ──
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: EmeraldPalette.surfaceLow,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _StatChip(
                        '✅', '${stats['bonusCount']}', '+${stats['bonusPts']}',
                        EmeraldPalette.emeraldLight),
                    _StatChip(
                        '⚠️', '${stats['penaltyCount']}', '-${stats['penaltyPts']}',
                        Colors.redAccent),
                    _StatChip(
                        '🛡️', '${stats['immunities']}', 'immu',
                        Colors.blueAccent),
                    _StatChip(
                        '📊', '${stats['net']}', 'net',
                        EmeraldPalette.gold),
                  ],
                ),
              ),

              // ── Points à attribuer ──
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.stars_rounded,
                      color: EmeraldPalette.gold, size: 18),
                  const SizedBox(width: 6),
                  Text('Bonus : +$points pts',
                      style: const TextStyle(
                          color: EmeraldPalette.goldLight,
                          fontSize: 15,
                          fontWeight: FontWeight.w800)),
                ],
              ),

              // ── IA note (si évaluée) ──
              if (aiNote != null) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.deepPurple.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: Colors.deepPurpleAccent.withValues(alpha: 0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        const Icon(Icons.auto_awesome_rounded,
                            color: Colors.deepPurpleAccent, size: 16),
                        const SizedBox(width: 6),
                        Text('IA : $aiNote/20',
                            style: const TextStyle(
                                color: Colors.deepPurpleAccent,
                                fontWeight: FontWeight.w700,
                                fontSize: 13)),
                        const Spacer(),
                        GestureDetector(
                          onTap: () => onNoteChanged(aiNote!),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color:
                                  Colors.deepPurpleAccent.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text('Appliquer',
                                style: TextStyle(
                                    color: Colors.deepPurpleAccent,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600)),
                          ),
                        ),
                      ]),
                      if (aiAppreciation != null) ...[
                        const SizedBox(height: 6),
                        Text(aiAppreciation!,
                            style: const TextStyle(
                                color: Colors.white70, fontSize: 12),
                            maxLines: 4,
                            overflow: TextOverflow.ellipsis),
                      ],
                    ],
                  ),
                ),
              ],

              // ── Bouton évaluer IA ──
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: loading ? null : onEvaluate,
                  icon: loading
                      ? const SizedBox(
                          width: 16, height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2,
                              color: Colors.deepPurpleAccent))
                      : const Icon(Icons.auto_awesome_rounded,
                          color: Colors.deepPurpleAccent, size: 18),
                  label: Text(
                      aiNote == null ? 'Évaluer avec IA' : 'Réévaluer',
                      style: const TextStyle(
                          color: Colors.deepPurpleAccent, fontSize: 12)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─── Widgets utilitaires ───────────────────────────────────────
class _StatChip extends StatelessWidget {
  final String emoji;
  final String value;
  final String sub;
  final Color color;
  const _StatChip(this.emoji, this.value, this.sub, this.color);

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(emoji, style: const TextStyle(fontSize: 16)),
        const SizedBox(height: 2),
        Text(value,
            style: TextStyle(
                color: color, fontSize: 14, fontWeight: FontWeight.w800)),
        Text(sub,
            style: TextStyle(color: color.withValues(alpha: 0.7), fontSize: 10)),
      ],
    );
  }
}

class _ActionChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;
  const _ActionChip(
      {required this.icon, required this.label, required this.color, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 6),
            Text(label,
                style: TextStyle(
                    color: color,
                    fontSize: 13,
                    fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }
}
