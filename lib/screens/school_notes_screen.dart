import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/family_provider.dart';
import '../widgets/animated_background.dart';
import '../widgets/glass_card.dart';
import '../widgets/tv_focus_wrapper.dart';

class SchoolNotesScreen extends StatefulWidget {
  final String childId;
  const SchoolNotesScreen({super.key, required this.childId});
  @override
  State<SchoolNotesScreen> createState() => _SchoolNotesScreenState();
}

class _SchoolNotesScreenState extends State<SchoolNotesScreen> {
  void _showAddNote(FamilyProvider provider) {
    String subject = '';
    int value = 10;
    int maxValue = 20;
    final subjectController = TextEditingController();
    final quickSubjects = ['Mathématiques', 'Français', 'Histoire', 'Sciences', 'Anglais', 'Sport', 'Arts', 'Musique'];

    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(builder: (context, setModalState) {
          return DraggableScrollableSheet(
            initialChildSize: 0.75, minChildSize: 0.5, maxChildSize: 0.9,
            builder: (context, scrollController) {
              return Container(
                decoration: BoxDecoration(color: Colors.grey[900]?.withOpacity(0.95), borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
                child: ListView(controller: scrollController, padding: const EdgeInsets.all(20), children: [
                  Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)))),
                  const SizedBox(height: 16),
                  const Text('Nouvelle note', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                  const SizedBox(height: 24),
                  const Text('Matière', style: TextStyle(color: Colors.white70, fontSize: 14)),
                  const SizedBox(height: 8),
                  Wrap(spacing: 8, runSpacing: 8, children: quickSubjects.map((s) {
                    final isSelected = subject == s;
                    return TvFocusWrapper(
                      onTap: () => setModalState(() { subject = isSelected ? '' : s; if (subject.isNotEmpty) subjectController.clear(); }),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(color: isSelected ? Colors.orangeAccent.withOpacity(0.2) : Colors.white.withOpacity(0.06), borderRadius: BorderRadius.circular(20), border: Border.all(color: isSelected ? Colors.orangeAccent : Colors.white24)),
                        child: Text(s, style: TextStyle(color: isSelected ? Colors.orangeAccent : Colors.white70, fontSize: 13)),
                      ),
                    );
                  }).toList()),
                  const SizedBox(height: 12),
                  TextField(
                    controller: subjectController, style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(hintText: 'Ou saisissez une matière...', hintStyle: const TextStyle(color: Colors.white38), filled: true, fillColor: Colors.white.withOpacity(0.06),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Colors.orangeAccent))),
                    onChanged: (val) { if (val.isNotEmpty) setModalState(() => subject = ''); },
                  ),
                  const SizedBox(height: 20),
                  const Text('Note', style: TextStyle(color: Colors.white70, fontSize: 14)),
                  const SizedBox(height: 8),
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    TvFocusWrapper(onTap: () { if (value > 0) setModalState(() => value--); },
                      child: Container(width: 44, height: 44, decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withOpacity(0.1), border: Border.all(color: Colors.white24)), child: const Icon(Icons.remove, color: Colors.white70))),
                    const SizedBox(width: 16),
                    Text('$value / $maxValue', style: TextStyle(color: value >= maxValue * 0.5 ? Colors.greenAccent : Colors.redAccent, fontSize: 32, fontWeight: FontWeight.bold)),
                    const SizedBox(width: 16),
                    TvFocusWrapper(onTap: () { if (value < maxValue) setModalState(() => value++); },
                      child: Container(width: 44, height: 44, decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withOpacity(0.1), border: Border.all(color: Colors.white24)), child: const Icon(Icons.add, color: Colors.white70))),
                  ]),
                  const SizedBox(height: 12),
                  const Text('Barème', style: TextStyle(color: Colors.white70, fontSize: 14)),
                  const SizedBox(height: 8),
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [10, 20, 40, 100].map((val) {
                    return Padding(padding: const EdgeInsets.symmetric(horizontal: 4), child: OutlinedButton(
                      onPressed: () => setModalState(() { maxValue = val; if (value > maxValue) value = maxValue; }),
                      style: OutlinedButton.styleFrom(foregroundColor: maxValue == val ? Colors.orangeAccent : Colors.white54, side: BorderSide(color: maxValue == val ? Colors.orangeAccent : Colors.white24), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))),
                      child: Text('/$val'),
                    ));
                  }).toList()),
                  const SizedBox(height: 28),
                  SizedBox(width: double.infinity, height: 52, child: TvFocusWrapper(
                    onTap: () => _submitNote(ctx, provider, subject, subjectController.text, value, maxValue),
                    child: ElevatedButton.icon(
                      onPressed: () => _submitNote(ctx, provider, subject, subjectController.text, value, maxValue),
                      icon: const Icon(Icons.school),
                      label: const Text('Ajouter la note', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.orangeAccent.shade700, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                    ),
                  )),
                ]),
              );
            },
          );
        });
      },
    );
  }

  void _submitNote(BuildContext ctx, FamilyProvider provider, String subject, String customSubject, int value, int maxValue) {
    final finalSubject = subject.isNotEmpty ? subject : customSubject;
    if (finalSubject.isEmpty) { ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Indiquez une matière'), backgroundColor: Colors.orangeAccent)); return; }
    final normalizedScore = maxValue > 0 ? (value / maxValue * 20).round() : value;
    provider.addPoints(widget.childId, normalizedScore, '$finalSubject: $value/$maxValue', category: 'school_note', isBonus: true);
    Navigator.pop(ctx);
    ScaffoldMessenger.of(this.context).showSnackBar(SnackBar(content: Text('Note ajoutée: $value/$maxValue en $finalSubject'), backgroundColor: Colors.green));
  }

  List<_SchoolNoteDisplay> _getSchoolNotes(FamilyProvider provider) {
    final history = provider.getHistoryForChild(widget.childId);
    final schoolEntries = history.where((h) => h.category == 'school_note').toList();
    return schoolEntries.map((h) {
      String subject = h.reason; int noteValue = h.points; int noteMax = 20;
      final match = RegExp(r'^(.+):\s*(\d+)/(\d+)$').firstMatch(h.reason);
      if (match != null) { subject = match.group(1)!.trim(); noteValue = int.tryParse(match.group(2)!) ?? h.points; noteMax = int.tryParse(match.group(3)!) ?? 20; }
      return _SchoolNoteDisplay(id: h.id, subject: subject, value: noteValue, maxValue: noteMax, date: h.date);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<FamilyProvider>(
      builder: (context, provider, _) {
        final child = provider.getChild(widget.childId);
        final notes = _getSchoolNotes(provider);

        return AnimatedBackground(
          child: Scaffold(
            backgroundColor: Colors.transparent,
            appBar: AppBar(title: Text('Notes – ${child?.name ?? ''}'), backgroundColor: Colors.transparent, elevation: 0),
            body: Column(
              children: [
                Expanded(
                  child: notes.isEmpty
                    ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Icon(Icons.school, size: 64, color: Colors.white24),
                        const SizedBox(height: 12),
                        const Text('Aucune note enregistrée', style: TextStyle(color: Colors.white54)),
                      ]))
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                        itemCount: notes.length,
                        itemBuilder: (context, index) {
                          final note = notes[index];
                          final percentage = note.maxValue > 0 ? (note.value / note.maxValue * 100) : 0.0;
                          final isGood = percentage >= 50;
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: TvFocusWrapper(
                              onTap: () => _showNoteDetail(note, provider),
                              child: GlassCard(
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Row(children: [
                                    Container(width: 48, height: 48, decoration: BoxDecoration(shape: BoxShape.circle, color: (isGood ? Colors.greenAccent : Colors.redAccent).withOpacity(0.15)),
                                      child: Center(child: Text('${percentage.round()}%', style: TextStyle(color: isGood ? Colors.greenAccent : Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 13)))),
                                    const SizedBox(width: 14),
                                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                      Text(note.subject, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
                                      const SizedBox(height: 4),
                                      Text('${note.value}/${note.maxValue}', style: const TextStyle(color: Colors.white54, fontSize: 13)),
                                    ])),
                                    Text('${note.date.day.toString().padLeft(2, '0')}/${note.date.month.toString().padLeft(2, '0')}', style: const TextStyle(color: Colors.white38, fontSize: 12)),
                                    const SizedBox(width: 4),
                                    const Icon(Icons.chevron_right, color: Colors.white24, size: 18),
                                  ]),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  child: SizedBox(width: double.infinity, height: 52, child: TvFocusWrapper(
                    onTap: () => _showAddNote(provider),
                    child: ElevatedButton.icon(
                      onPressed: () => _showAddNote(provider),
                      icon: const Icon(Icons.add),
                      label: const Text('Ajouter une note', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.orangeAccent.shade700, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                    ),
                  )),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showNoteDetail(_SchoolNoteDisplay note, FamilyProvider provider) {
    showModalBottomSheet(context: context, backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(color: Colors.grey[900]?.withOpacity(0.95), borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 16),
          Text(note.subject, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          _detailRow('Note', '${note.value}/${note.maxValue}'),
          _detailRow('Pourcentage', '${(note.maxValue > 0 ? note.value / note.maxValue * 100 : 0).round()}%'),
          _detailRow('Date', '${note.date.day.toString().padLeft(2, '0')}/${note.date.month.toString().padLeft(2, '0')}/${note.date.year}'),
          const SizedBox(height: 24),
        ]),
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(label, style: const TextStyle(color: Colors.white54, fontSize: 14)),
      Text(value, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
    ]));
  }
}

class _SchoolNoteDisplay {
  final String id; final String subject; final int value; final int maxValue; final DateTime date;
  _SchoolNoteDisplay({required this.id, required this.subject, required this.value, required this.maxValue, required this.date});
}
