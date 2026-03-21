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

        // Récupérer les notes scolaires de l'enfant
        final schoolNotes = provider.getHistoryForChild(widget.childId)
            .where((h) => h.category == 'school_note')
            .toList();
        schoolNotes.sort((a, b) => b.date.compareTo(a.date));

        // Notes du mois sélectionné
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
    final dateStr = DateFormat('dd/MM/yyyy', 'fr_FR').format(note.date);
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
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(dateStr, style: const TextStyle(color: Colors.white54, fontSize: 12)),
              const SizedBox(height: 2),
              Text(note.reason, style: const TextStyle(color: Colors.white70, fontSize: 13)),
            ],
          ),
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

  // ===== DIALOG AJOUTER NOTE =====
  void _showAddNote(BuildContext context, FamilyProvider provider, ChildModel child) {
    int selectedGrade = 10;
    String reason = '';
    DateTime selectedDate = DateTime.now();

    // Calculer les jours disponibles (lundi à aujourd'hui de cette semaine)
    final now = DateTime.now();
    final monday = now.subtract(Duration(days: now.weekday - 1));
    final List<DateTime> availableDays = [];
    for (int i = 0; i <= now.weekday - 1 && i < 5; i++) {
      availableDays.add(DateTime(monday.year, monday.month, monday.day + i));
    }

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
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
                    // Sélection du jour
                    const Text('Jour à noter :', style: TextStyle(color: Colors.white70, fontSize: 14)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: availableDays.map((day) {
                        final isSelected = day.day == selectedDate.day &&
                            day.month == selectedDate.month &&
                            day.year == selectedDate.year;
                        final dayName = DateFormat('EEE dd', 'fr_FR').format(day);

                        // Vérifier si une note existe déjà pour ce jour
                        final existingNote = provider.getHistoryForChild(widget.childId).any((h) =>
                            h.category == 'school_note' &&
                            h.date.day == day.day &&
                            h.date.month == day.month &&
                            h.date.year == day.year);

                        return GestureDetector(
                          onTap: () {
                            setDialogState(() {
                              selectedDate = day;
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? Colors.amber.withOpacity(0.3)
                                  : Colors.white.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isSelected ? Colors.amber : Colors.white24,
                                width: isSelected ? 2 : 1,
                              ),
                            ),
                            child: Column(
                              children: [
                                Text(dayName,
                                    style: TextStyle(
                                        color: isSelected ? Colors.amber : Colors.white70,
                                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                        fontSize: 13)),
                                if (existingNote)
                                  const Icon(Icons.check_circle, color: Colors.greenAccent, size: 14),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
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
                            if (selectedGrade > 0) {
                              setDialogState(() => selectedGrade--);
                            }
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
                            if (selectedGrade < 20) {
                              setDialogState(() => selectedGrade++);
                            }
                          },
                          icon: const Icon(Icons.add_circle, color: Colors.greenAccent, size: 32),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    // Slider
                    Slider(
                      value: selectedGrade.toDouble(),
                      min: 0,
                      max: 20,
                      divisions: 20,
                      activeColor: Colors.amber,
                      inactiveColor: Colors.white24,
                      onChanged: (val) {
                        setDialogState(() => selectedGrade = val.round());
                      },
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

                    // Aperçu temps d'écran
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
