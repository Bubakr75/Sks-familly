// lib/screens/school_notes_weekly_screen.dart
//
// 📚 Notes Scolaires Hebdomadaires — refonte v2
// - Multi-enfants (notation rapide de tous en même temps)
// - Évaluation hebdomadaire (pas journalière)
// - Stats filtrées (exclut boutique/overtime/refus)
// - Questions comportement parent (5 questions pertinentes)
// - Calcul automatique des points (10 à 200 selon la note)
// - IA Gemini qui prend en compte bonus/pénalités + réponses comportement

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/family_provider.dart';
import '../config/emerald_theme.dart';
import '../models/child_model.dart';
import '../services/gemini_service.dart';

// ─── Questions comportement ────────────────────────────────────
class BehaviorQuestion {
  final String id;
  final String emoji;
  final String question;
  final String positiveLabel;
  final String negativeLabel;

  const BehaviorQuestion({
    required this.id,
    required this.emoji,
    required this.question,
    required this.positiveLabel,
    required this.negativeLabel,
  });
}

const _behaviorQuestions = [
  BehaviorQuestion(
    id: 'listening',
    emoji: '👂',
    question: 'A bien écouté les parents ?',
    positiveLabel: 'Très attentif',
    negativeLabel: 'A dû être répété',
  ),
  BehaviorQuestion(
    id: 'siblings',
    emoji: '👫',
    question: 'Bon comportement avec frères/sœurs ?',
    positiveLabel: 'Aimable',
    negativeLabel: 'Conflits',
  ),
  BehaviorQuestion(
    id: 'repetition',
    emoji: '🔁',
    question: 'A-t-on dû répéter les choses plusieurs fois ?',
    positiveLabel: 'Du 1er coup',
    negativeLabel: 'Répétitions',
  ),
  BehaviorQuestion(
    id: 'tidiness',
    emoji: '🧹',
    question: 'A rangé ses affaires sans rappel ?',
    positiveLabel: 'Autonome',
    negativeLabel: 'Affaires traînées',
  ),
  BehaviorQuestion(
    id: 'attitude',
    emoji: '😊',
    question: 'Attitude générale (politesse, respect) ?',
    positiveLabel: 'Exemplaire',
    negativeLabel: 'À améliorer',
  ),
];

class SchoolNotesWeeklyScreen extends StatefulWidget {
  const SchoolNotesWeeklyScreen({super.key});

  @override
  State<SchoolNotesWeeklyScreen> createState() =>
      _SchoolNotesWeeklyScreenState();
}

class _SchoolNotesWeeklyScreenState extends State<SchoolNotesWeeklyScreen>
    with SingleTickerProviderStateMixin {
  DateTime _weekStart = _getWeekStart(DateTime.now());

  // notes par enfant : { childId: { 'note', 'behavior': {qId: 1-5}, 'aiNote', 'aiAppreciation', 'validated', 'pointsAwarded' } }
  Map<String, Map<String, dynamic>> _weeklyNotes = {};
  Set<String> _evaluatingChildren = {}; // enfants en cours d'éval IA
  bool _validating = false;

  @override
  void initState() {
    super.initState();
    _loadWeekNotes();
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

  /// Stats de la semaine FILTRÉES (exclut boutique, overtime, refus, écran)
  Map<String, int> _getChildWeekStats(String childId, FamilyProvider fp) {
    final weekEnd = _weekStart.add(const Duration(days: 7));
    // Catégories à EXCLURE (ne reflètent pas le comportement)
    const excludeCategories = {
      'boutique', 'overtime', 'refus', 'screen_time_bonus',
      'saturday_rating', 'échange',
    };

    final entries = fp.history.where((h) =>
        h.childId == childId &&
        h.date.isAfter(_weekStart.subtract(const Duration(seconds: 1))) &&
        h.date.isBefore(weekEnd) &&
        !excludeCategories.contains(h.category.toLowerCase()));

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

    // Immunités = bonne attitude (gagnées par bon comportement)
    final immunities = fp.immunities.where((im) =>
        im.childId == childId &&
        im.createdAt.isAfter(_weekStart.subtract(const Duration(seconds: 1))) &&
        im.createdAt.isBefore(weekEnd)).length;

    // Punitions = mauvaise conduite
    final punishments = fp.punishments.where((p) =>
        p.childId == childId &&
        p.createdAt.isAfter(_weekStart.subtract(const Duration(seconds: 1))) &&
        p.createdAt.isBefore(weekEnd)).length;

    return {
      'bonusPts': bonusPts,
      'penaltyPts': penaltyPts,
      'bonusCount': bonusCount,
      'penaltyCount': penaltyCount,
      'immunities': immunities,
      'punishments': punishments,
      'net': bonusPts - penaltyPts,
    };
  }

  /// Note suggérée : combine stats + comportement
  int _suggestedNote(String childId) {
    final fp = context.read<FamilyProvider>();
    final stats = _getChildWeekStats(childId, fp);
    final behavior = _weeklyNotes[childId]?['behavior']
        as Map<String, dynamic>?;

    int note = 12; // Base moyenne

    // Ajustement selon points nets (bonus - pénalités)
    final net = stats['net'] ?? 0;
    note += (net ~/ 15).clamp(-5, 6);

    // Régularité
    if ((stats['bonusCount'] ?? 0) > 7) note += 2;
    if ((stats['penaltyCount'] ?? 0) == 0) note += 1;
    if ((stats['penaltyCount'] ?? 0) > 5) note -= 2;

    // Immunités = bon comportement
    note += (stats['immunities'] ?? 0).clamp(0, 2);
    // Punitions = mauvais comportement
    note -= ((stats['punishments'] ?? 0) * 2).clamp(0, 6);

    // Ajustement comportement parent (1 à 5 par question)
    if (behavior != null && behavior.isNotEmpty) {
      final avgBehavior = behavior.values
          .map((v) => (v as num).toDouble())
          .reduce((a, b) => a + b) / behavior.length;
      // avgBehavior 5 = excellent → +3, avgBehavior 1 = mauvais → -3
      note += ((avgBehavior - 3) * 1.5).round().clamp(-3, 3);
    }

    return note.clamp(0, 20);
  }

  /// Points attribués selon la note
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

  /// Évaluation IA pour UN enfant (avec stats + comportement)
  Future<void> _evaluateWithAI(
      ChildModel child, FamilyProvider fp) async {
    if (_evaluatingChildren.contains(child.id)) return;
    setState(() => _evaluatingChildren.add(child.id));

    final stats = _getChildWeekStats(child.id, fp);
    final behavior = _weeklyNotes[child.id]?['behavior']
        as Map<String, dynamic>? ?? {};
    final currentNote = (_weeklyNotes[child.id]?['note'] as int?) ??
        _suggestedNote(child.id);

    // Construire le résumé comportement
    final behaviorLines = <String>[];
    for (final q in _behaviorQuestions) {
      final val = behavior[q.id];
      if (val != null) {
        final label = (val as num).toInt() >= 4 ? q.positiveLabel :
                      (val as num).toInt() <= 2 ? q.negativeLabel : 'Moyen';
        behaviorLines.add('${q.emoji} ${q.question} : $label (${(val as num).toInt()}/5)');
      }
    }
    final behaviorText = behaviorLines.isEmpty
        ? 'Non évalué'
        : behaviorLines.join(', ');

    try {
      final result = await GeminiService.chatFamilyAssistant(
        message:
          'Tu es un psychologue de l\'éducation. Évalue la semaine de ${child.name} UNIQUEMENT à partir des données ci-dessous.\n\n'
          'DONNÉES DE LA SEMAINE:\n'
          '- Bonus obtenus: ${stats['bonusCount']} (${stats['bonusPts']} pts)\n'
          '- Pénalités: ${stats['penaltyCount']} (${stats['penaltyPts']} pts)\n'
          '- Immunités gagnées (bon comportement): ${stats['immunities']}\n'
          '- Punitions: ${stats['punishments']}\n'
          '- Points nets: ${stats['net']}\n\n'
          'COMPORTEMENT (évalué par le parent sur 5):\n'
          '$behaviorText\n\n'
          'BARÈME POUR TA NOTE SUR 20:\n'
          '- Beaucoup de bonus, peu de pénalités, bon comportement (4-5/5) = 16 à 20\n'
          '- Plus de bonus que de pénalités, comportement correct (3/5) = 12 à 15\n'
          '- Autant de bonus que de pénalités, comportement moyen = 8 à 11\n'
          '- Plus de pénalités, comportement à améliorer (1-2/5) = 4 à 7\n'
          '- Beaucoup de punitions et pénalités = 0 à 3\n\n'
          'Calcule TA note toi-même à partir de ces données. Ne recopie pas une note qu\'on te donnerait.\n\n'
          'FORMAT EXACT (respecte les mots clés):\n'
          'NOTE: X\n'
          'APPRECIATION: ton appréciation en 2 phrases, style psychologue bienveillant\n'
          'CONSEIL PARENT: un conseil concret pour le parent\n'
          'MOT POUR ENFANT: un message d\'encouragement pour ${child.name}',
        familyContext: 'Évaluation comportementale hebdomadaire de ${child.name}',
      );

      // Si l'IA n'est pas configurée, on garde la note suggérée
      if (result.contains('n\'est pas configuré') || result.isEmpty) {
        setState(() {
          _evaluatingChildren.remove(child.id);
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('⚠️ IA non disponible. Note suggérée : $currentNote/20'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      // Extraire la note depuis "NOTE: X"
      final noteMatch = RegExp(r'NOTE:\s*(\d{1,2})', caseSensitive: false).firstMatch(result);
      int aiNote = currentNote; // fallback
      if (noteMatch != null) {
        final parsed = int.tryParse(noteMatch.group(1)!);
        if (parsed != null && parsed >= 0 && parsed <= 20) {
          aiNote = parsed;
        }
      }

      // Parser les sections avec un regex simple
      String extractSection(String startKeyword, [String? endKeyword]) {
        final startIdx = result.indexOf(startKeyword);
        if (startIdx == -1) return '';
        final contentStart = startIdx + startKeyword.length;
        int endIdx = result.length;
        if (endKeyword != null) {
          final endMatch = result.indexOf(endKeyword, contentStart);
          if (endMatch != -1) endIdx = endMatch;
        }
        return result.substring(contentStart, endIdx).trim();
      }

      final appreciation = extractSection('APPRECIATION:', 'CONSEIL PARENT:');
      final conseilParent = extractSection('CONSEIL PARENT:', 'MOT POUR ENFANT:');
      final motEnfant = extractSection('MOT POUR ENFANT:');

      // Construire le texte complet structuré
      final fullText = StringBuffer();
      if (appreciation.isNotEmpty) fullText.writeln('💬 $appreciation');
      if (conseilParent.isNotEmpty) fullText.writeln('\n👨‍👩‍👧 Conseil parent : $conseilParent');
      if (motEnfant.isNotEmpty) fullText.writeln('\n👦 À ${child.name} : $motEnfant');
      if (fullText.isEmpty) fullText.write(result);

      setState(() {
        _weeklyNotes[child.id] ??= {};
        _weeklyNotes[child.id]!['aiNote'] = aiNote;
        _weeklyNotes[child.id]!['aiAppreciation'] = fullText.toString().trim();
      });
      await _saveWeekNotes();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('⚠️ Évaluation IA échouée pour ${child.name}'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }

    setState(() => _evaluatingChildren.remove(child.id));
  }

  /// Évalue tous les enfants d'un coup
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

  /// Valide les notes → attribue les points
  Future<void> _validateWeek(FamilyProvider fp) async {
    if (_validating) return;
    setState(() => _validating = true);

    int count = 0;
    for (final child in fp.children) {
      final noteData = _weeklyNotes[child.id];
      if (noteData == null) continue;
      final note = (noteData['note'] as int?) ?? 0;
      if (note == 0) continue;
      if ((noteData['validated'] as bool?) ?? false) continue; // déjà validé

      final points = _noteToPoints(note);
      await fp.addPoints(
        child.id,
        points,
        '📚 Note de la semaine : $note/20',
        category: 'school_note',
        isBonus: true,
      );
      noteData['validated'] = true;
      noteData['pointsAwarded'] = points;
      count++;
    }

    if (count > 0) {
      await _saveWeekNotes();
      HapticFeedback.heavyImpact();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ $count note(s) validée(s) ! Points attribués.'),
            backgroundColor: EmeraldPalette.emerald,
          ),
        );
      }
    }
    setState(() => _validating = false);
  }

  @override
  Widget build(BuildContext context) {
    final fp = context.watch<FamilyProvider>();
    final children = fp.children;

    return Scaffold(
      backgroundColor: EmeraldPalette.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text('📚 Notes Comportementales',
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
                _buildWeekHeader(),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: _ActionChip(
                          icon: Icons.auto_awesome_rounded,
                          label: 'Évaluer tous (IA)',
                          color: Colors.deepPurpleAccent,
                          onTap: _evaluatingChildren.isNotEmpty
                              ? null
                              : () => _evaluateAllWithAI(fp),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _ActionChip(
                          icon: Icons.check_circle_rounded,
                          label: 'Valider la semaine',
                          color: EmeraldPalette.emerald,
                          onTap: _validating
                              ? null
                              : () => _validateWeek(fp),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                    itemCount: children.length,
                    itemBuilder: (context, index) {
                      final child = children[index];
                      final noteData = _weeklyNotes[child.id] ?? {};
                      final note = (noteData['note'] as int?) ??
                          _suggestedNote(child.id);
                      final validated = (noteData['validated'] as bool?) ?? false;
                      final behavior = (noteData['behavior']
                          as Map<String, dynamic>?) ?? {};

                      return _ChildNoteCard(
                        child: child,
                        stats: _getChildWeekStats(child.id, fp),
                        currentNote: note,
                        behavior: behavior,
                        aiNote: noteData['aiNote'] as int?,
                        aiAppreciation: noteData['aiAppreciation'] as String?,
                        validated: validated,
                        pointsAwarded: noteData['pointsAwarded'] as int?,
                        isEvaluating: _evaluatingChildren.contains(child.id),
                        onNoteChanged: (newNote) async {
                          setState(() {
                            _weeklyNotes[child.id] ??= {};
                            _weeklyNotes[child.id]!['note'] = newNote;
                          });
                          await _saveWeekNotes();
                        },
                        onBehaviorChanged: (qId, value) async {
                          setState(() {
                            _weeklyNotes[child.id] ??= {};
                            _weeklyNotes[child.id]!['behavior'] ??= {};
                            _weeklyNotes[child.id]!['behavior'][qId] = value;
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
// CARTE NOTE PAR ENFANT
// ════════════════════════════════════════════════════════════════
class _ChildNoteCard extends StatelessWidget {
  final ChildModel child;
  final Map<String, int> stats;
  final int currentNote;
  final Map<String, dynamic> behavior;
  final int? aiNote;
  final String? aiAppreciation;
  final bool validated;
  final int? pointsAwarded;
  final bool isEvaluating;
  final ValueChanged<int> onNoteChanged;
  final void Function(String qId, int value) onBehaviorChanged;
  final VoidCallback onEvaluate;

  const _ChildNoteCard({
    required this.child,
    required this.stats,
    required this.currentNote,
    required this.behavior,
    required this.aiNote,
    required this.aiAppreciation,
    required this.validated,
    required this.pointsAwarded,
    required this.isEvaluating,
    required this.onNoteChanged,
    required this.onBehaviorChanged,
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

  void _showFullAppreciation(BuildContext context, String childName) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: const Color(0xFF0F2620),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.7,
            maxWidth: MediaQuery.of(context).size.width * 0.9,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.deepPurpleAccent.withValues(alpha: 0.15),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                ),
                child: Row(children: [
                  const Icon(Icons.auto_awesome_rounded,
                      color: Colors.deepPurpleAccent, size: 24),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text('Évaluation IA - $childName',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold)),
                  ),
                  if (aiNote != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.deepPurpleAccent.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text('$aiNote/20',
                          style: const TextStyle(
                              color: Colors.deepPurpleAccent,
                              fontWeight: FontWeight.w800)),
                    ),
                ]),
              ),
              // Contenu
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    aiAppreciation ?? '',
                    style: const TextStyle(color: Colors.white70, fontSize: 14, height: 1.5),
                  ),
                ),
              ),
              // Bouton fermer
              Padding(
                padding: const EdgeInsets.all(16),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepPurpleAccent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Fermer', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
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
      child: ExpansionTile(
        initiallyExpanded: !validated,
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        backgroundColor: Colors.transparent,
        collapsedBackgroundColor: Colors.transparent,
        title: Row(
          children: [
            Text(child.avatar.isNotEmpty ? child.avatar : '👤',
                style: const TextStyle(fontSize: 26)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(child.name,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w800)),
            ),
            if (validated) ...[
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
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
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: noteColor.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10),
                  border:
                      Border.all(color: noteColor.withValues(alpha: 0.4)),
                ),
                child: Text('$currentNote/20',
                    style: TextStyle(
                        color: noteColor,
                        fontSize: 15,
                        fontWeight: FontWeight.w900)),
              ),
            ],
          ],
        ),
        children: [
          if (!validated) ...[
            // ── Sélecteur de note (boutons +/− au lieu de slider) ──
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  onPressed: () => onNoteChanged((currentNote - 1).clamp(0, 20)),
                  icon: const Icon(Icons.remove_circle_outline,
                      color: Colors.white54, size: 32),
                ),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  decoration: BoxDecoration(
                    color: noteColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: noteColor.withValues(alpha: 0.4)),
                  ),
                  child: Column(
                    children: [
                      Text('$currentNote/20',
                          style: TextStyle(
                              color: noteColor,
                              fontSize: 28,
                              fontWeight: FontWeight.w900)),
                      Text('+${_noteToPoints(currentNote)} pts',
                          style: TextStyle(
                              color: noteColor.withValues(alpha: 0.8),
                              fontSize: 12,
                              fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                IconButton(
                  onPressed: () => onNoteChanged((currentNote + 1).clamp(0, 20)),
                  icon: const Icon(Icons.add_circle_outline,
                      color: Colors.white54, size: 32),
                ),
              ],
            ),

            // ── Stats semaine ──
            const SizedBox(height: 4),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: EmeraldPalette.surfaceLow,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _StatChip('✅', '${stats['bonusCount']}',
                      '+${stats['bonusPts']}', EmeraldPalette.emeraldLight),
                  _StatChip('⚠️', '${stats['penaltyCount']}',
                      '-${stats['penaltyPts']}', Colors.redAccent),
                  _StatChip('🛡️', '${stats['immunities']}', 'immu',
                      Colors.blueAccent),
                  _StatChip('📝', '${stats['punishments']}', 'punis',
                      Colors.deepOrange),
                  _StatChip('📊', '${stats['net']}', 'net',
                      EmeraldPalette.gold),
                ],
              ),
            ),

            // ── Questions comportement ──
            const SizedBox(height: 12),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text('🧠 Comportement de la semaine',
                  style: TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                      fontWeight: FontWeight.w700)),
            ),
            const SizedBox(height: 6),
            ..._behaviorQuestions.map((q) {
              final val = (behavior[q.id] as num?)?.toDouble() ?? 3.0;
              return _BehaviorSlider(
                question: q,
                value: val,
                onChanged: (v) => onBehaviorChanged(q.id, v.round()),
              );
            }),

            // ── Points ──
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

            // ── IA ──
            if (aiNote != null || aiAppreciation != null) ...[
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
                      if (aiNote != null)
                        Text('IA : $aiNote/20',
                            style: const TextStyle(
                                color: Colors.deepPurpleAccent,
                                fontWeight: FontWeight.w700,
                                fontSize: 13)),
                      const Spacer(),
                      if (aiNote != null)
                        GestureDetector(
                          onTap: () => onNoteChanged(aiNote!),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.deepPurpleAccent
                                  .withValues(alpha: 0.2),
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
                      GestureDetector(
                        onTap: () => _showFullAppreciation(context, child.name),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.deepPurple.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(aiAppreciation!,
                                  style: const TextStyle(
                                      color: Colors.white70, fontSize: 12),
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis),
                              const SizedBox(height: 4),
                              const Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  Text('Lire tout',
                                      style: TextStyle(
                                          color: Colors.deepPurpleAccent,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600)),
                                  Icon(Icons.expand_more,
                                      color: Colors.deepPurpleAccent, size: 14),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
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
                onPressed: isEvaluating ? null : onEvaluate,
                icon: isEvaluating
                    ? const SizedBox(
                        width: 16, height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2,
                            color: Colors.deepPurpleAccent))
                    : const Icon(Icons.auto_awesome_rounded,
                        color: Colors.deepPurpleAccent, size: 18),
                label: Text(
                    isEvaluating
                        ? 'Évaluation...'
                        : (aiNote == null
                            ? 'Évaluer avec IA'
                            : 'Réévaluer avec IA'),
                    style: const TextStyle(
                        color: Colors.deepPurpleAccent, fontSize: 12)),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─── Sélecteur comportement (5 boutons ronds) ──────────────────
class _BehaviorSlider extends StatelessWidget {
  final BehaviorQuestion question;
  final double value;
  final ValueChanged<double> onChanged;

  const _BehaviorSlider({
    required this.question,
    required this.value,
    required this.onChanged,
  });

  Color _colorForLevel(int level) {
    if (level >= 4) return EmeraldPalette.emerald;
    if (level == 3) return EmeraldPalette.gold;
    if (level == 2) return Colors.orange;
    return Colors.redAccent;
  }

  String get _label {
    if (value >= 4) return question.positiveLabel;
    if (value <= 2) return question.negativeLabel;
    return 'Moyen';
  }

  @override
  Widget build(BuildContext context) {
    final currentLevel = value.round();
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Text(question.emoji, style: const TextStyle(fontSize: 18)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(question.question,
                  style: const TextStyle(
                      color: Colors.white70, fontSize: 12)),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: _colorForLevel(currentLevel).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(_label,
                  style: TextStyle(
                      color: _colorForLevel(currentLevel),
                      fontSize: 10,
                      fontWeight: FontWeight.w700)),
            ),
          ]),
          const SizedBox(height: 6),
          // 5 boutons ronds (1 à 5)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: List.generate(5, (i) {
              final level = i + 1;
              final isSelected = level == currentLevel;
              final color = _colorForLevel(level);
              return GestureDetector(
                onTap: () => onChanged(level.toDouble()),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isSelected ? color : Colors.transparent,
                    border: Border.all(
                      color: isSelected ? color : Colors.white24,
                      width: isSelected ? 0 : 1.5,
                    ),
                    boxShadow: isSelected
                        ? [BoxShadow(
                            color: color.withValues(alpha: 0.4),
                            blurRadius: 8,
                            spreadRadius: 1)]
                        : null,
                  ),
                  child: Center(
                    child: Text(
                      '$level',
                      style: TextStyle(
                        color: isSelected
                            ? const Color(0xFF051410)
                            : Colors.white54,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
        ],
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
        Text(emoji, style: const TextStyle(fontSize: 14)),
        const SizedBox(height: 2),
        Text(value,
            style: TextStyle(
                color: color, fontSize: 13, fontWeight: FontWeight.w800)),
        Text(sub,
            style: TextStyle(color: color.withValues(alpha: 0.6), fontSize: 9)),
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
