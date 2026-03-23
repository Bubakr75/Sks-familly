import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/family_provider.dart';
import '../models/child_model.dart';
import '../models/history_entry.dart';

class SchoolNotesScreen extends StatefulWidget {
  final String childId;
  const SchoolNotesScreen({super.key, required this.childId});

  @override
  State<SchoolNotesScreen> createState() => _SchoolNotesScreenState();
}

class _SchoolNotesScreenState extends State<SchoolNotesScreen> {
  DateTime _selectedDate = DateTime.now();

  @override
  Widget build(BuildContext context) {
    return Consumer<FamilyProvider>(
      builder: (context, provider, _) {
        final child = provider.getChild(widget.childId);
        if (child == null) {
          return Scaffold(
            body: Center(child: Text('Enfant non trouvé')),
          );
        }

        final weeklyAvg = provider.getWeeklySchoolAverage(widget.childId);
        final globalScore = provider.getWeeklyGlobalScore(widget.childId);
        final satMinutes = provider.getSaturdayMinutes(widget.childId);
        final sunMinutes = provider.getSundayMinutes(widget.childId);

        final schoolNotes = provider.getHistoryForChild(widget.childId)
            .where((h) => h.category == 'school_note')
            .toList();
        schoolNotes.sort((a, b) => b.date.compareTo(a.date));

        final monthNotes = schoolNotes.where((h) =>
            h.date.month == _selectedDate.month &&
            h.date.year == _selectedDate.year).toList();

        return Scaffold(
          backgroundColor: const Color(0xFF0a0a2a),
          appBar: AppBar(
            title: Text('Notes - ${child.name}'),
            backgroundColor: Colors.transparent,
            elevation: 0,
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => _showAddNote(context, provider, child),
            backgroundColor: Colors.amber,
            icon: const Icon(Icons.add, color: Colors.black),
            label: const Text('Noter la journée', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ===== TEMPS D'ÉCRAN =====
                _buildGlassCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('📺 Temps d\'écran ce week-end',
                          style: TextStyle(color: Colors.amber, fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildTimeChip('Samedi', satMinutes),
                          _buildTimeChip('Dimanche', sunMinutes),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Note globale : ${globalScore >= 0 ? "${globalScore.toStringAsFixed(1)}/20" : "Aucune note"}',
                        style: const TextStyle(color: Colors.white70, fontSize: 14),
                      ),
                      if (weeklyAvg >= 0)
                        Text(
                          'Moyenne scolaire semaine : ${weeklyAvg.toStringAsFixed(1)}/20',
                          style: const TextStyle(color: Colors.white54, fontSize: 13),
                        ),
                      Text(
                        'Comportement semaine : ${provider.getWeeklyBehaviorScore(widget.childId).toStringAsFixed(1)}/20',
                        style: const TextStyle(color: Colors.white54, fontSize: 13),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // ===== SEMAINE EN COURS (vue rapide) =====
                _buildGlassCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('📅 Cette semaine',
                          style: TextStyle(color: Colors.amber, fontSize: 16, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      _buildCurrentWeekView(provider),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // ===== BARÈME =====
                _buildGlassCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('📊 Barème des points',
                          style: TextStyle(color: Colors.amber, fontSize: 16, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      _buildBaremeRow('18-20/20', '3h', Colors.greenAccent),
                      _buildBaremeRow('16-17/20', '2h30', Colors.lightGreen),
                      _buildBaremeRow('14-15/20', '2h', Colors.yellow),
                      _buildBaremeRow('12-13/20', '1h30', Colors.orange),
                      _buildBaremeRow('10-11/20', '1h', Colors.deepOrange),
                      _buildBaremeRow('8-9/20', '30min', Colors.red),
                      _buildBaremeRow('< 8/20', '0min', Colors.red.shade900),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // ===== NAVIGATION MOIS =====
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      onPressed: () {
                        setState(() {
                          _selectedDate = DateTime(_selectedDate.year, _selectedDate.month - 1);
                        });
                      },
                      icon: const Icon(Icons.chevron_left, color: Colors.white),
                    ),
                    Text(
                      DateFormat('MMMM yyyy', 'fr_FR').format(_selectedDate),
                      style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    IconButton(
                      onPressed: () {
                        setState(() {
                          _selectedDate = DateTime(_selectedDate.year, _selectedDate.month + 1);
                        });
                      },
                      icon: const Icon(Icons.chevron_right, color: Colors.white),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // ===== HISTORIQUE DU MOIS =====
                _buildGlassCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('📅 Historique du mois',
                          style: TextStyle(color: Colors.amber, fontSize: 16, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      if (monthNotes.isEmpty)
                        const Padding(
                          padding: EdgeInsets.all(16),
                          child: Text('Aucune note ce mois-ci', style: TextStyle(color: Colors.white54)),
                        )
                      else
                        ...monthNotes.map((note) => _buildNoteTile(note)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ===== VUE SEMAINE EN COURS =====
  Widget _buildCurrentWeekView(FamilyProvider provider) {
    final now = DateTime.now();
    final monday = now.subtract(Duration(days: now.weekday - 1));
    final dayNames = ['Lun', 'Mar', 'Mer', 'Jeu', 'Ven'];

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: List.generate(5, (i) {
        final day = DateTime(monday.year, monday.month, monday.day + i);
        final isToday = day.year == now.year && day.month == now.month && day.day == now.day;
        final isFuture = day.isAfter(now);

        final dayHistory = provider.getHistoryForChild(widget.childId).where((h) =>
            h.category == 'school_note' &&
            h.date.year == day.year &&
            h.date.month == day.month &&
            h.date.day == day.day).toList();

        double? grade;
        if (dayHistory.isNotEmpty) {
          final reason = dayHistory.last.reason;
          final match = RegExp(r'(\d+)/20').firstMatch(reason);
          if (match != null) {
            grade = double.tryParse(match.group(1)!);
          }
        }

        Color noteColor = Colors.grey;
        if (grade != null) {
          if (grade >= 16) noteColor = Colors.greenAccent;
          else if (grade >= 12) noteColor = Colors.yellow;
          else if (grade >= 8) noteColor = Colors.orange;
          else noteColor = Colors.red;
        }

        return GestureDetector(
          onTap: isFuture ? null : () => _showAddNoteForDate(context, provider, provider.getChild(widget.childId)!, day),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
            decoration: BoxDecoration(
              color: isToday ? Colors.amber.withOpacity(0.15) : Colors.white.withOpacity(0.04),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isToday ? Colors.amber.withOpacity(0.5) : Colors.white.withOpacity(0.1),
                width: isToday ? 2 : 1,
              ),
            ),
            child: Column(
              children: [
                Text(dayNames[i], style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 11, fontWeight: FontWeight.w600)),
                Text('${day.day}', style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 10)),
                const SizedBox(height: 4),
                if (grade != null)
                  Text('${grade.toInt()}', style: TextStyle(color: noteColor, fontWeight: FontWeight.w900, fontSize: 18))
                else if (isFuture)
                  Text('-', style: TextStyle(color: Colors.white.withOpacity(0.15), fontSize: 18))
                else
                  Icon(Icons.add_circle_outline, color: Colors.amber.withOpacity(0.4), size: 20),
              ],
            ),
          ),
        );
      }),
    );
  }

  Widget _buildTimeChip(String label, int minutes) {
    final hours = minutes ~/ 60;
    final mins = minutes % 60;
    String timeStr;
    if (hours > 0 && mins > 0) {
      timeStr = '${hours}h${mins.toString().padLeft(2, '0')}';
    } else if (hours > 0) {
      timeStr = '${hours}h';
    } else {
      timeStr = '${mins}min';
    }

    Color color;
    if (minutes >= 150) {
      color = Colors.greenAccent;
    } else if (minutes >= 90) {
      color = Colors.yellow;
    } else if (minutes >= 30) {
      color = Colors.orange;
    } else {
      color = Colors.red;
    }

    return Column(
      children: [
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.2),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: color, width: 1),
          ),
          child: Text(timeStr, style: TextStyle(color: color, fontSize: 20, fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }

  Widget _buildBaremeRow(String note, String temps, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(note, style: TextStyle(color: color, fontSize: 13)),
          Text(temps, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildNoteTile(HistoryEntry note) {
    final dateStr = DateFormat('EEEE dd/MM', 'fr_FR').format(note.date);
    Color noteColor;
    if (note.points >= 16) {
      noteColor = Colors.greenAccent;
    } else if (note.points >= 12) {
      noteColor = Colors.yellow;
    } else if (note.points >= 8) {
      noteColor = Colors.orange;
    } else {
      noteColor = Colors.red;
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(dateStr, style: const TextStyle(color: Colors.white54, fontSize: 12)),
                const SizedBox(height: 2),
                Text(note.reason, style: const TextStyle(color: Colors.white70, fontSize: 13), maxLines: 2, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: noteColor.withOpacity(0.2),
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: noteColor),
            ),
            child: Text(
              '${note.points}/20',
              style: TextStyle(color: noteColor, fontWeight: FontWeight.bold, fontSize: 15),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGlassCard({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.15)),
      ),
      child: child,
    );
  }

  // ===== DIALOG NOTER UN JOUR SPÉCIFIQUE =====
  void _showAddNoteForDate(BuildContext context, FamilyProvider provider, ChildModel child, DateTime date) {
    int selectedGrade = 10;
    String reason = '';
    final dayStr = DateFormat('EEEE dd MMMM', 'fr_FR').format(date);

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF1a1a4a),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text('📝 ', style: TextStyle(fontSize: 24)),
                      Expanded(
                        child: Text('Noter ${child.name}',
                            style: const TextStyle(color: Colors.amber, fontSize: 18)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.amber.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(dayStr, style: const TextStyle(color: Colors.amber, fontSize: 13)),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(
                          onPressed: () {
                            if (selectedGrade > 0) setDialogState(() => selectedGrade--);
                          },
                          icon: const Icon(Icons.remove_circle, color: Colors.red, size: 32),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '$selectedGrade/20',
                            style: TextStyle(
                              color: selectedGrade >= 16
                                  ? Colors.greenAccent
                                  : selectedGrade >= 12
                                      ? Colors.yellow
                                      : selectedGrade >= 8
                                          ? Colors.orange
                                          : Colors.red,
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () {
                            if (selectedGrade < 20) setDialogState(() => selectedGrade++);
                          },
                          icon: const Icon(Icons.add_circle, color: Colors.greenAccent, size: 32),
                        ),
                      ],
                    ),
                    Slider(
                      value: selectedGrade.toDouble(),
                      min: 0,
                      max: 20,
                      divisions: 20,
                      activeColor: Colors.amber,
                      inactiveColor: Colors.white24,
                      onChanged: (val) => setDialogState(() => selectedGrade = val.round()),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      onChanged: (val) => reason = val,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'Raison (ex: Bonne journée...)',
                        hintStyle: const TextStyle(color: Colors.white38),
                        filled: true,
                        fillColor: Colors.white.withOpacity(0.1),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.amber.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.amber.withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          const Text('📺 ', style: TextStyle(fontSize: 16)),
                          Expanded(
                            child: Text(
                              'Cette note donnera environ ${_previewMinutes(selectedGrade)}',
                              style: const TextStyle(color: Colors.amber, fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Annuler', style: TextStyle(color: Colors.white54)),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final noteReason = reason.isNotEmpty ? reason : 'Note du jour';
                    await provider.addPoints(
                      widget.childId,
                      selectedGrade,
                      '📝 $noteReason ($selectedGrade/20)',
                      category: 'school_note',
                      isBonus: true,
                      date: date,
                    );
                    if (ctx.mounted) Navigator.pop(ctx);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.amber,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Valider', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ===== DIALOG AJOUTER NOTE (avec sélecteur de date libre) =====
  void _showAddNote(BuildContext context, FamilyProvider provider, ChildModel child) {
    int selectedGrade = 10;
    String reason = '';
    DateTime selectedDate = DateTime.now();

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            final dayStr = DateFormat('EEEE dd MMMM yyyy', 'fr_FR').format(selectedDate);

            return AlertDialog(
              backgroundColor: const Color(0xFF1a1a4a),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Row(
                children: [
                  const Text('📝 ', style: TextStyle(fontSize: 24)),
                  Expanded(
                    child: Text('Noter ${child.name}',
                        style: const TextStyle(color: Colors.amber, fontSize: 18)),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Sélecteur de date libre
                    const Text('Jour à noter :', style: TextStyle(color: Colors.white70, fontSize: 14)),
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: ctx,
                          initialDate: selectedDate,
                          firstDate: DateTime(2024, 1, 1),
                          lastDate: DateTime.now(),
                          locale: const Locale('fr', 'FR'),
                          builder: (context, child) {
                            return Theme(
                              data: ThemeData.dark().copyWith(
                                colorScheme: const ColorScheme.dark(
                                  primary: Colors.amber,
                                  onPrimary: Colors.black,
                                  surface: Color(0xFF1a1a4a),
                                  onSurface: Colors.white,
                                ),
                                dialogBackgroundColor: const Color(0xFF1a1a4a),
                              ),
                              child: child!,
                            );
                          },
                        );
                        if (picked != null) {
                          setDialogState(() => selectedDate = picked);
                        }
                      },
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.amber.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.amber.withOpacity(0.4)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.calendar_today_rounded, color: Colors.amber, size: 18),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(dayStr, style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.w600, fontSize: 14)),
                            ),
                            const Icon(Icons.edit_rounded, color: Colors.amber, size: 16),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Note sur 20
                    const Text('Note sur 20 :', style: TextStyle(color: Colors.white70, fontSize: 14)),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(
                          onPressed: () {
                            if (selectedGrade > 0) setDialogState(() => selectedGrade--);
                          },
                          icon: const Icon(Icons.remove_circle, color: Colors.red, size: 32),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '$selectedGrade/20',
                            style: TextStyle(
                              color: selectedGrade >= 16
                                  ? Colors.greenAccent
                                  : selectedGrade >= 12
                                      ? Colors.yellow
                                      : selectedGrade >= 8
                                          ? Colors.orange
                                          : Colors.red,
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () {
                            if (selectedGrade < 20) setDialogState(() => selectedGrade++);
                          },
                          icon: const Icon(Icons.add_circle, color: Colors.greenAccent, size: 32),
                        ),
                      ],
                    ),
                    Slider(
                      value: selectedGrade.toDouble(),
                      min: 0,
                      max: 20,
                      divisions: 20,
                      activeColor: Colors.amber,
                      inactiveColor: Colors.white24,
                      onChanged: (val) => setDialogState(() => selectedGrade = val.round()),
                    ),
                    const SizedBox(height: 12),

                    // Raison
                    TextField(
                      onChanged: (val) => reason = val,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'Raison (ex: Bonne journée, maths 16/20...)',
                        hintStyle: const TextStyle(color: Colors.white38),
                        filled: true,
                        fillColor: Colors.white.withOpacity(0.1),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Aperçu
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.amber.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.amber.withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          const Text('📺 ', style: TextStyle(fontSize: 20)),
                          Expanded(
                            child: Text(
                              'Cette note donnera environ ${_previewMinutes(selectedGrade)}',
                              style: const TextStyle(color: Colors.amber, fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Annuler', style: TextStyle(color: Colors.white54)),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final noteReason = reason.isNotEmpty ? reason : 'Note du jour';
                    await provider.addPoints(
                      widget.childId,
                      selectedGrade,
                      '📝 $noteReason ($selectedGrade/20)',
                      category: 'school_note',
                      isBonus: true,
                      date: selectedDate,
                    );
                    if (ctx.mounted) Navigator.pop(ctx);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.amber,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Valider', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  String _previewMinutes(int grade) {
    if (grade >= 18) return '3h';
    if (grade >= 16) return '2h30';
    if (grade >= 14) return '2h';
    if (grade >= 12) return '1h30';
    if (grade >= 10) return '1h';
    if (grade >= 8) return '30min';
    return '0min';
  }
}
