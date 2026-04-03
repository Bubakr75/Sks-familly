// lib/widgets/timeline_widget.dart
import 'package:flutter/material.dart';
import '../models/history_entry.dart';
import '../models/child_model.dart';
import 'glass_card.dart';

// ─── Helpers catégorie ────────────────────────────────────────
IconData timelineCategoryIcon(String cat) {
  switch (cat.toLowerCase()) {
    case 'punition':          return Icons.edit_note_rounded;
    case 'immunité':          return Icons.shield_rounded;
    case 'school_note':       return Icons.school_rounded;
    case 'objectif':          return Icons.flag_rounded;
    case 'échange':           return Icons.swap_horiz_rounded;
    case 'tribunal_vote':
    case 'tribunal_verdict':
    case 'tribunal':          return Icons.gavel_rounded;
    case 'bonus':             return Icons.star_rounded;
    case 'pénalité':          return Icons.remove_circle_rounded;
    case 'screen_time_bonus': return Icons.timer_rounded;
    case 'saturday_rating':   return Icons.calendar_today_rounded;
    default:                  return Icons.circle_rounded;
  }
}

Color timelineCategoryColor(String cat) {
  switch (cat.toLowerCase()) {
    case 'punition':          return const Color(0xFFFF6B6B);
    case 'immunité':          return const Color(0xFF4FC3F7);
    case 'school_note':       return const Color(0xFF81C784);
    case 'objectif':          return const Color(0xFFFFD54F);
    case 'échange':           return const Color(0xFFBA68C8);
    case 'tribunal_vote':
    case 'tribunal_verdict':
    case 'tribunal':          return const Color(0xFFFF8A65);
    case 'bonus':             return const Color(0xFF4DB6AC);
    case 'pénalité':          return const Color(0xFFE57373);
    case 'screen_time_bonus': return const Color(0xFF64B5F6);
    case 'saturday_rating':   return const Color(0xFFA5D6A7);
    default:                  return const Color(0xFF90A4AE);
  }
}

String timelineCategoryLabel(String cat) {
  switch (cat.toLowerCase()) {
    case 'punition':          return 'Punition';
    case 'immunité':          return 'Immunité';
    case 'school_note':       return 'Note scolaire';
    case 'objectif':          return 'Objectif';
    case 'échange':           return 'Échange';
    case 'tribunal_vote':     return 'Tribunal (vote)';
    case 'tribunal_verdict':  return 'Tribunal (verdict)';
    case 'tribunal':          return 'Tribunal';
    case 'bonus':             return 'Bonus';
    case 'pénalité':          return 'Pénalité';
    case 'screen_time_bonus': return 'Temps écran';
    case 'saturday_rating':   return 'Note samedi';
    default:                  return cat;
  }
}

String _formatTime(DateTime d) {
  return '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
}

String _formatPoints(HistoryEntry e) {
  final sign = e.isBonus ? '+' : '-';
  if (e.category.toLowerCase() == 'punition') {
    final pts = e.points / 100.0;
    return '$sign${pts.toStringAsFixed(2)} pt';
  }
  return '$sign${e.points} pt';
}

Widget timelineDateSeparator(DateTime date) {
  final now   = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final d     = DateTime(date.year, date.month, date.day);
  String label;
  if (d == today) {
    label = "Aujourd'hui";
  } else if (d == today.subtract(const Duration(days: 1))) {
    label = 'Hier';
  } else {
    const jours = ['Lun', 'Mar', 'Mer', 'Jeu', 'Ven', 'Sam', 'Dim'];
    const mois  = ['jan', 'fév', 'mar', 'avr', 'mai', 'juin', 'juil', 'août', 'sep', 'oct', 'nov', 'déc'];
    label = '${jours[date.weekday - 1]} ${date.day} ${mois[date.month - 1]} ${date.year}';
  }
  return Padding(
    padding: const EdgeInsets.only(top: 12, bottom: 6, left: 48),
    child: Text(
      label,
      style: const TextStyle(
        color: Colors.white38,
        fontSize: 11,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.8,
      ),
    ),
  );
}

// ─── Widget principal réutilisable ───────────────────────────
class TimelineWidget extends StatelessWidget {
  final List<HistoryEntry> entries;

  /// Si null → pas d'affichage du nom de l'enfant.
  /// Si renseigné → affiche "👤 nom" sous chaque entrée pour les vues multi-enfants.
  final Map<String, ChildModel>? childrenMap;

  /// Si true, affiche le nom de l'enfant même si childrenMap est renseigné
  final bool showChildName;

  /// Callback optionnel pour supprimer une entrée (swipe to delete ou bouton)
  final void Function(String entryId)? onDelete;

  const TimelineWidget({
    super.key,
    required this.entries,
    this.childrenMap,
    this.showChildName = false,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.timeline_rounded, color: Colors.white24, size: 64),
            SizedBox(height: 16),
            Text(
              'Aucun événement',
              style: TextStyle(
                  color: Colors.white54,
                  fontSize: 18,
                  fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text(
              'L\'historique apparaîtra ici.',
              style: TextStyle(color: Colors.white30, fontSize: 13),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: entries.length,
      itemBuilder: (context, index) {
        final entry   = entries[index];
        final color   = timelineCategoryColor(entry.category);
        final icon    = timelineCategoryIcon(entry.category);
        final label   = timelineCategoryLabel(entry.category);
        final isBonus = entry.isBonus;
        final child   = childrenMap?[entry.childId];

        // ── Séparateur de date ──
        Widget? dateSep;
        if (index == 0) {
          dateSep = timelineDateSeparator(entry.date);
        } else {
          final prev = entries[index - 1];
          if (prev.date.day   != entry.date.day   ||
              prev.date.month != entry.date.month  ||
              prev.date.year  != entry.date.year) {
            dateSep = timelineDateSeparator(entry.date);
          }
        }

        final card = Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Colonne gauche : icône + trait ──
            Column(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.18),
                    shape: BoxShape.circle,
                    border: Border.all(color: color, width: 1.5),
                  ),
                  child: Icon(icon, color: color, size: 18),
                ),
                if (index < entries.length - 1)
                  Container(
                    width: 1.5,
                    height: 40,
                    color: Colors.white10,
                  ),
              ],
            ),
            const SizedBox(width: 12),
            // ── Carte ──
            Expanded(
              child: GlassCard(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // En-tête
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: color.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            label,
                            style: TextStyle(
                              color: color,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const Spacer(),
                        Text(
                          _formatTime(entry.date),
                          style: const TextStyle(
                              color: Colors.white38, fontSize: 11),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _formatPoints(entry),
                          style: TextStyle(
                            color: isBonus
                                ? Colors.greenAccent
                                : Colors.redAccent,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                        // ── Bouton supprimer ──
                        if (onDelete != null) ...[
                          const SizedBox(width: 4),
                          GestureDetector(
                            onTap: () => onDelete!(entry.id),
                            child: const Icon(Icons.close_rounded,
                                color: Colors.white24, size: 16),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 6),
                    // Description
                    Text(
                      entry.reason,
                      style: const TextStyle(
                          color: Colors.white70, fontSize: 13),
                    ),
                    // Nom de l'enfant
                    if (showChildName && child != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        '${child.avatar.isNotEmpty ? child.avatar : '👤'} ${child.name}',
                        style: const TextStyle(
                            color: Colors.white38, fontSize: 11),
                      ),
                    ],
                    // Auteur
                    if (entry.actionBy != null &&
                        entry.actionBy!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        'Par : ${entry.actionBy}',
                        style: const TextStyle(
                          color: Colors.white24,
                          fontSize: 10,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        );

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (dateSep != null) dateSep,
            card,
          ],
        );
      },
    );
  }
}
