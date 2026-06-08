// lib/screens/timeline_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/family_provider.dart';
import '../models/history_entry.dart';
import '../models/child_model.dart';
import '../widgets/animated_background.dart';
import '../widgets/glass_card.dart';

// ─────────────────────────────────────────────────────────────
//  Correspondance catégorie → icône / couleur / libellé
// ─────────────────────────────────────────────────────────────
IconData _categoryIcon(String cat) {
  switch (cat.toLowerCase()) {
    case 'punition':        return Icons.edit_note_rounded;
    case 'immunité':        return Icons.shield_rounded;
    case 'school_note':     return Icons.school_rounded;
    case 'objectif':        return Icons.flag_rounded;
    case 'échange':         return Icons.swap_horiz_rounded;
    case 'tribunal_vote':
    case 'tribunal_verdict':
    case 'tribunal':        return Icons.gavel_rounded;
    case 'bonus':           return Icons.star_rounded;
    case 'pénalité':        return Icons.remove_circle_rounded;
    case 'screen_time_bonus': return Icons.timer_rounded;
    case 'saturday_rating': return Icons.calendar_today_rounded;
    default:                return Icons.circle_rounded;
  }
}

Color _categoryColor(String cat) {
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

String _categoryLabel(String cat) {
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

// ─────────────────────────────────────────────────────────────
//  Toutes les catégories disponibles dans le filtre
// ─────────────────────────────────────────────────────────────
const List<String> _allCategories = [
  'punition',
  'immunité',
  'school_note',
  'objectif',
  'échange',
  'tribunal',
  'tribunal_vote',
  'tribunal_verdict',
  'bonus',
  'pénalité',
  'screen_time_bonus',
  'saturday_rating',
];

// Catégories affichées dans les chips (regroupées visuellement)
const List<String> _filterChips = [
  'punition',
  'immunité',
  'school_note',
  'objectif',
  'échange',
  'tribunal',
  'bonus',
  'pénalité',
  'screen_time_bonus',
  'saturday_rating',
];

// ─────────────────────────────────────────────────────────────
//  Widget principal
// ─────────────────────────────────────────────────────────────
class TimelineScreen extends StatefulWidget {
  final String? initialChildId;

  const TimelineScreen({super.key, this.initialChildId});

  @override
  State<TimelineScreen> createState() => _TimelineScreenState();
}

class _TimelineScreenState extends State<TimelineScreen> {
  String?        _selectedChildId;
  Set<String>    _activeCategories = {};
  DateTimeRange? _dateRange;

  @override
  void initState() {
    super.initState();
    _selectedChildId = widget.initialChildId;
    _activeCategories = Set.from(_allCategories); // tout activé par défaut
  }

  // ── Filtrage ──────────────────────────────────────────────
  List<HistoryEntry> _filteredEntries(FamilyProvider fp) {
    List<HistoryEntry> entries = _selectedChildId == null
        ? List.from(fp.history)
        : fp.history.where((h) => h.childId == _selectedChildId).toList();

    // filtre catégories
    entries = entries.where((e) {
      final cat = e.category.toLowerCase();
      // Les sous-catégories tribunal sont couvertes par le chip 'tribunal'
      if (_activeCategories.contains('tribunal') &&
          (cat == 'tribunal_vote' || cat == 'tribunal_verdict' || cat == 'tribunal')) {
        return true;
      }
      return _activeCategories.contains(cat);
    }).toList();

    // filtre dates
    if (_dateRange != null) {
      final start = DateTime(
          _dateRange!.start.year, _dateRange!.start.month, _dateRange!.start.day);
      final end = DateTime(
          _dateRange!.end.year, _dateRange!.end.month, _dateRange!.end.day, 23, 59, 59);
      entries = entries
          .where((e) => e.date.isAfter(start) && e.date.isBefore(end))
          .toList();
    }

    // tri chronologique inversé (le plus récent en premier)
    entries.sort((a, b) => b.date.compareTo(a.date));
    return entries;
  }

  // ── Build principal ───────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Consumer<FamilyProvider>(
      builder: (context, fp, _) {
        final entries = _filteredEntries(fp);
        return AnimatedBackground(
          child: Scaffold(
            backgroundColor: Colors.transparent,
            appBar: _buildAppBar(fp),
            body: Column(
              children: [
                _buildChildSelector(fp.children),
                const SizedBox(height: 4),
                _buildCategoryFilter(),
                if (_dateRange != null) _buildDateRangeBadge(),
                const SizedBox(height: 4),
                Expanded(
                  child: entries.isEmpty
                      ? _buildEmpty()
                      : _buildTimeline(entries, fp),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ── AppBar ────────────────────────────────────────────────
  AppBar _buildAppBar(FamilyProvider fp) {
    final hasFilters = _dateRange != null ||
        _activeCategories.length != _allCategories.length;
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      title: const Text(
        '📅 Timeline',
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 20,
        ),
      ),
      iconTheme: const IconThemeData(color: Colors.white),
      actions: [
        IconButton(
          icon: Icon(
            Icons.date_range_rounded,
            color: _dateRange != null ? Colors.cyanAccent : Colors.white70,
          ),
          tooltip: 'Filtrer par date',
          onPressed: () => _pickDateRange(context),
        ),
        if (hasFilters)
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.orangeAccent),
            tooltip: 'Réinitialiser les filtres',
            onPressed: () => setState(() {
              _dateRange = null;
              _activeCategories = Set.from(_allCategories);
            }),
          ),
      ],
    );
  }

  // ── Sélecteur d'enfant ────────────────────────────────────
  Widget _buildChildSelector(List<ChildModel> children) {
    return SizedBox(
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        children: [
          _childChip(null, 'Tous', '👨‍👩‍👧‍👦'),
          ...children.map((c) => _childChip(c.id, c.name, c.avatar)),
        ],
      ),
    );
  }

  Widget _childChip(String? id, String name, String avatar) {
    final selected = _selectedChildId == id;
    return GestureDetector(
      onTap: () => setState(() => _selectedChildId = id),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(right: 8, top: 4, bottom: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected
              ? const Color(0xFF7C4DFF)
              : Colors.white.withOpacity(0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? Colors.transparent : Colors.white24,
          ),
        ),
        child: Row(
          children: [
            Text(avatar, style: const TextStyle(fontSize: 16)),
            const SizedBox(width: 6),
            Text(
              name,
              style: TextStyle(
                color: selected ? Colors.white : Colors.white70,
                fontWeight:
                    selected ? FontWeight.bold : FontWeight.normal,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Filtre catégories ─────────────────────────────────────
  Widget _buildCategoryFilter() {
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        children: _filterChips.map((cat) {
          // Le chip 'tribunal' couvre aussi tribunal_vote et tribunal_verdict
          final isActive = cat == 'tribunal'
              ? _activeCategories.contains('tribunal')
              : _activeCategories.contains(cat);
          final color = _categoryColor(cat);
          return GestureDetector(
            onTap: () => setState(() {
              if (cat == 'tribunal') {
                if (_activeCategories.contains('tribunal')) {
                  _activeCategories.remove('tribunal');
                  _activeCategories.remove('tribunal_vote');
                  _activeCategories.remove('tribunal_verdict');
                } else {
                  _activeCategories.add('tribunal');
                  _activeCategories.add('tribunal_vote');
                  _activeCategories.add('tribunal_verdict');
                }
              } else {
                if (_activeCategories.contains(cat)) {
                  _activeCategories.remove(cat);
                } else {
                  _activeCategories.add(cat);
                }
              }
            }),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              margin: const EdgeInsets.only(right: 6, top: 4, bottom: 4),
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: isActive
                    ? color.withOpacity(0.25)
                    : Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isActive ? color : Colors.white12,
                  width: 1.2,
                ),
              ),
              child: Row(
                children: [
                  Icon(_categoryIcon(cat),
                      color: isActive ? color : Colors.white30, size: 14),
                  const SizedBox(width: 4),
                  Text(
                    _categoryLabel(cat),
                    style: TextStyle(
                      color: isActive ? color : Colors.white30,
                      fontSize: 12,
                      fontWeight: isActive
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ── Badge plage de dates ──────────────────────────────────
  Widget _buildDateRangeBadge() {
    if (_dateRange == null) return const SizedBox.shrink();
    final f = (DateTime d) =>
        '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          const Icon(Icons.filter_alt_rounded,
              color: Colors.cyanAccent, size: 14),
          const SizedBox(width: 6),
          Text(
            '${f(_dateRange!.start)} → ${f(_dateRange!.end)}',
            style: const TextStyle(color: Colors.cyanAccent, fontSize: 12),
          ),
        ],
      ),
    );
  }

  // ── Timeline liste ────────────────────────────────────────
  Widget _buildTimeline(List<HistoryEntry> entries, FamilyProvider fp) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: entries.length,
      itemBuilder: (context, index) {
        final entry     = entries[index];
        final color     = _categoryColor(entry.category);
        final icon      = _categoryIcon(entry.category);
        final label     = _categoryLabel(entry.category);
        final isBonus   = entry.isBonus;
        final childName = fp.getChild(entry.childId)?.name ?? '';

        // Affiche séparateur de date si le jour change
        Widget? dateSep;
        if (index == 0) {
          dateSep = _dateSeparator(entry.date);
        } else {
          final prev = entries[index - 1];
          if (prev.date.day   != entry.date.day   ||
              prev.date.month != entry.date.month  ||
              prev.date.year  != entry.date.year) {
            dateSep = _dateSeparator(entry.date);
          }
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (dateSep != null) dateSep,
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Ligne verticale + icône
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
                // Carte
                Expanded(
                  child: GlassCard(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // En-tête : catégorie + heure + points
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
                                color: Colors.white38,
                                fontSize: 11,
                              ),
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
                          ],
                        ),
                        const SizedBox(height: 6),
                        // Description
                        Text(
                          entry.reason,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 13,
                          ),
                        ),
                        // Nom de l'enfant si on est en mode "tous"
                        if (_selectedChildId == null && childName.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            '👤 $childName',
                            style: const TextStyle(
                              color: Colors.white38,
                              fontSize: 11,
                            ),
                          ),
                        ],
                        // Auteur de l'action
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
            ),
          ],
        );
      },
    );
  }

  // ── Séparateur de jour ────────────────────────────────────
  Widget _dateSeparator(DateTime date) {
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
      const mois  = [
        'jan', 'fév', 'mar', 'avr', 'mai', 'juin',
        'juil', 'août', 'sep', 'oct', 'nov', 'déc'
      ];
      label =
          '${jours[date.weekday - 1]} ${date.day} ${mois[date.month - 1]} ${date.year}';
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

  // ── État vide ─────────────────────────────────────────────
  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.timeline_rounded,
              color: Colors.white24, size: 64),
          const SizedBox(height: 16),
          const Text(
            'Aucun événement',
            style: TextStyle(
                color: Colors.white54,
                fontSize: 18,
                fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            _dateRange != null
                ? 'Aucun événement sur cette période.'
                : 'Modifie les filtres pour voir des entrées.',
            style: const TextStyle(color: Colors.white30, fontSize: 13),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // ── Sélecteur de plage de dates ───────────────────────────
  Future<void> _pickDateRange(BuildContext context) async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: _dateRange,
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.dark(
            primary:   Color(0xFF7C4DFF),
            onPrimary: Colors.white,
            surface:   Color(0xFF1A1A2E),
            onSurface: Colors.white,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _dateRange = picked);
  }

  // ── Helpers de formatage ──────────────────────────────────
  String _formatTime(DateTime d) {
    final h = d.hour.toString().padLeft(2, '0');
    final m = d.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  String _formatPoints(HistoryEntry e) {
    final sign = e.isBonus ? '+' : '-';
    // Les punitions stockent (deduction * 100).round() comme points
    if (e.category.toLowerCase() == 'punition') {
      final pts = e.points / 100.0;
      return '$sign${pts.toStringAsFixed(2)} pt';
    }
    return '$sign${e.points} pt';
  }
}
