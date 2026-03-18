import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/family_provider.dart';
import '../utils/pin_guard.dart';
import '../widgets/glass_card.dart';
import '../widgets/animated_background.dart';

class SchoolNotesScreen extends StatefulWidget {
  const SchoolNotesScreen({super.key});
  @override
  State<SchoolNotesScreen> createState() => _SchoolNotesScreenState();
}

class _SchoolNotesScreenState extends State<SchoolNotesScreen> with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  DateTime _selectedMonth = DateTime(DateTime.now().year, DateTime.now().month);
  String? _selectedChildId;

  static const _blueColor = Color(0xFF448AFF);
  static const _cyanColor = Color(0xFF00E5FF);

  static const List<Map<String, dynamic>> _gradeScale = [
    {'min': 20.0, 'max': 20.0, 'points': 10, 'label': 'Exceptionnel', 'color': Color(0xFFFFD740), 'emoji': '\u{1F3C6}'},
    {'min': 18.0, 'max': 19.9, 'points': 8, 'label': 'Excellent', 'color': Color(0xFF00E676), 'emoji': '\u{1F31F}'},
    {'min': 16.0, 'max': 17.9, 'points': 7, 'label': 'Tres bien', 'color': Color(0xFF00E676), 'emoji': '\u{1F4AA}'},
    {'min': 14.0, 'max': 15.9, 'points': 5, 'label': 'Bien', 'color': Color(0xFF448AFF), 'emoji': '\u{1F44D}'},
    {'min': 12.0, 'max': 13.9, 'points': 4, 'label': 'Assez bien', 'color': Color(0xFF448AFF), 'emoji': '\u{1F60A}'},
    {'min': 10.0, 'max': 11.9, 'points': 3, 'label': 'Passable', 'color': Color(0xFFFF9100), 'emoji': '\u{1F44C}'},
    {'min': 8.0, 'max': 9.9, 'points': 2, 'label': 'Insuffisant', 'color': Color(0xFFFF6E40), 'emoji': '\u{1F615}'},
    {'min': 0.0, 'max': 7.9, 'points': 1, 'label': 'Faible', 'color': Color(0xFFFF1744), 'emoji': '\u{1F61F}'},
  ];

  static const _monthNames = ['Janvier', 'Fevrier', 'Mars', 'Avril', 'Mai', 'Juin', 'Juillet', 'Aout', 'Septembre', 'Octobre', 'Novembre', 'Decembre'];
  static const _dayNames = ['Lun', 'Mar', 'Mer', 'Jeu', 'Ven', 'Sam', 'Dim'];

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  static int getPointsForGrade(double grade) {
    for (final scale in _gradeScale) {
      if (grade >= (scale['min'] as double) && grade <= (scale['max'] as double)) return scale['points'] as int;
    }
    return 1;
  }

  static Map<String, dynamic> getScaleForGrade(double grade) {
    for (final scale in _gradeScale) {
      if (grade >= (scale['min'] as double) && grade <= (scale['max'] as double)) return scale;
    }
    return _gradeScale.last;
  }

  double? _extractGrade(String reason) {
    final match = RegExp(r'Note: ([\d.]+)/20').firstMatch(reason);
    if (match != null) return double.tryParse(match.group(1)!);
    return null;
  }

  bool _isSameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E21),
      appBar: AppBar(
        title: const NeonText(text: 'Note du jour', fontSize: 18, color: Colors.white),
        backgroundColor: Colors.transparent,
      ),
      floatingActionButton: Container(
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: _blueColor.withValues(alpha: 0.3), blurRadius: 16)]),
        child: FloatingActionButton.extended(
          heroTag: 'add_daily_note',
          backgroundColor: _blueColor,
          onPressed: () => PinGuard.guardAction(context, () => _showAddNote(context)),
          icon: const Icon(Icons.add_chart_rounded),
          label: const Text('Noter la journee', style: TextStyle(fontWeight: FontWeight.w700)),
        ),
      ),
      body: Consumer<FamilyProvider>(
        builder: (context, provider, _) {
          final schoolHistory = provider.history.where((h) => h.category == 'school_note').toList();
          if (_selectedChildId == null && provider.children.isNotEmpty) {
            _selectedChildId = provider.children.first.id;
          }

          return AnimatedBackground(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
              children: [
                if (provider.children.length > 1) ...[
                  SizedBox(
                    height: 50,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: provider.children.length,
                      itemBuilder: (_, i) {
                        final child = provider.children[i];
                        final isSelected = child.id == _selectedChildId;
                        return GestureDetector(
                          onTap: () => setState(() => _selectedChildId = child.id),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            margin: const EdgeInsets.only(right: 8),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(14),
                              color: isSelected ? _blueColor.withValues(alpha: 0.15) : Colors.white.withValues(alpha: 0.04),
                              border: Border.all(color: isSelected ? _blueColor.withValues(alpha: 0.5) : Colors.white.withValues(alpha: 0.08)),
                            ),
                            child: Row(mainAxisSize: MainAxisSize.min, children: [
                              Text(child.avatar.isEmpty ? '\u{1F466}' : child.avatar, style: const TextStyle(fontSize: 18)),
                              const SizedBox(width: 6),
                              Text(child.name, style: TextStyle(color: isSelected ? _blueColor : Colors.grey[500], fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500, fontSize: 13)),
                            ]),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                _buildTodayCard(provider, schoolHistory),
                const SizedBox(height: 16),
                _buildCalendar(provider, schoolHistory),
                const SizedBox(height: 16),
                _buildMonthAverage(schoolHistory),
                const SizedBox(height: 16),
                _buildMonthHistory(provider, schoolHistory),
                const SizedBox(height: 16),
                _buildGradeScaleCard(),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildTodayCard(FamilyProvider provider, List<dynamic> history) {
    if (_selectedChildId == null) return const SizedBox.shrink();
    final today = DateTime.now();
    final todayNote = history.where((h) => h.childId == _selectedChildId && _isSameDay(h.date, today)).toList();
    final child = provider.getChild(_selectedChildId!);

    if (todayNote.isEmpty) {
      return GlassCard(
        glowColor: _blueColor,
        child: Column(children: [
          const Text('\u{1F4CB}', style: TextStyle(fontSize: 40)),
          const SizedBox(height: 8),
          Text('${child?.name ?? ''} n\'a pas encore de note aujourd\'hui', style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text('Appuyez sur le bouton pour noter la journee', style: TextStyle(color: Colors.grey[500], fontSize: 12)),
        ]),
      );
    }

    final h = todayNote.last;
    final grade = _extractGrade(h.reason) ?? 0;
    final scale = getScaleForGrade(grade);

    return GlassCard(
      glowColor: scale['color'] as Color,
      child: Column(children: [
        Row(children: [
          const Icon(Icons.today_rounded, color: _cyanColor, size: 18),
          const SizedBox(width: 8),
          const Text('Note du jour', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700)),
          const Spacer(),
          Text('${today.day}/${today.month}/${today.year}', style: TextStyle(color: Colors.grey[500], fontSize: 11)),
        ]),
        const SizedBox(height: 16),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(
            width: 70, height: 70,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(colors: [(scale['color'] as Color).withValues(alpha: 0.3), (scale['color'] as Color).withValues(alpha: 0.1)]),
              border: Border.all(color: (scale['color'] as Color).withValues(alpha: 0.5), width: 2),
              boxShadow: [BoxShadow(color: (scale['color'] as Color).withValues(alpha: 0.3), blurRadius: 12)],
            ),
            child: Center(child: Text('${grade.toStringAsFixed(grade == grade.roundToDouble() ? 0 : 1)}', style: TextStyle(color: scale['color'] as Color, fontWeight: FontWeight.w900, fontSize: 24))),
          ),
          const SizedBox(width: 20),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(child?.name ?? '', style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Row(children: [
              Text(scale['emoji'] as String, style: const TextStyle(fontSize: 18)),
              const SizedBox(width: 6),
              Text(scale['label'] as String, style: TextStyle(color: scale['color'] as Color, fontWeight: FontWeight.w700, fontSize: 14)),
            ]),
            const SizedBox(height: 4),
            Text('+${h.points} points', style: const TextStyle(color: Color(0xFF00E676), fontWeight: FontWeight.w800, fontSize: 14)),
          ]),
        ]),
        if (h.reason.contains(' - ')) ...[
          const SizedBox(height: 10),
          Container(
            width: double.infinity, padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), color: Colors.white.withValues(alpha: 0.04)),
            child: Text(h.reason.split(' - ').skip(1).join(' - '), style: TextStyle(color: Colors.grey[400], fontSize: 12, fontStyle: FontStyle.italic)),
          ),
        ],
      ]),
    );
  }

  Widget _buildCalendar(FamilyProvider provider, List<dynamic> history) {
    final year = _selectedMonth.year;
    final month = _selectedMonth.month;
    final daysInMonth = DateTime(year, month + 1, 0).day;
    final firstWeekday = DateTime(year, month, 1).weekday;
    final today = DateTime.now();

    return GlassCard(
      child: Column(children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          IconButton(icon: const Icon(Icons.chevron_left_rounded, color: Colors.white), onPressed: () => setState(() => _selectedMonth = DateTime(year, month - 1))),
          Text('${_monthNames[month - 1]} $year', style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
          IconButton(icon: const Icon(Icons.chevron_right_rounded, color: Colors.white), onPressed: () => setState(() => _selectedMonth = DateTime(year, month + 1))),
        ]),
        const SizedBox(height: 8),
        Row(children: _dayNames.map((d) => Expanded(child: Center(child: Text(d, style: TextStyle(color: Colors.grey[600], fontSize: 10, fontWeight: FontWeight.w600))))).toList()),
        const SizedBox(height: 8),
        ...List.generate(6, (week) {
          return Row(children: List.generate(7, (weekday) {
            final dayIndex = week * 7 + weekday - (firstWeekday - 1);
            if (dayIndex < 1 || dayIndex > daysInMonth) return const Expanded(child: SizedBox(height: 42));
            final date = DateTime(year, month, dayIndex);
            final isToday = _isSameDay(date, today);
            final isFuture = date.isAfter(today);
            double? dayGrade;
            if (_selectedChildId != null) {
              final dayNotes = history.where((h) => h.childId == _selectedChildId && _isSameDay(h.date, date)).toList();
              if (dayNotes.isNotEmpty) dayGrade = _extractGrade(dayNotes.last.reason);
            }
            Color? bgColor;
            Color textColor = Colors.white;
            if (dayGrade != null) {
              final scale = getScaleForGrade(dayGrade);
              bgColor = (scale['color'] as Color).withValues(alpha: 0.25);
              textColor = scale['color'] as Color;
            } else if (isFuture) { textColor = Colors.grey[800]!; }
            return Expanded(
              child: GestureDetector(
                onTap: dayGrade != null ? () => _showDayDetail(context, date, history) : null,
                child: Container(
                  height: 42, margin: const EdgeInsets.all(2),
                  decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), color: bgColor ?? (isToday ? _blueColor.withValues(alpha: 0.1) : null), border: isToday ? Border.all(color: _blueColor.withValues(alpha: 0.5), width: 1.5) : null),
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Text('$dayIndex', style: TextStyle(color: textColor, fontSize: 12, fontWeight: dayGrade != null ? FontWeight.w800 : FontWeight.w500)),
                    if (dayGrade != null) Text('${dayGrade.toStringAsFixed(0)}', style: TextStyle(color: textColor, fontSize: 9, fontWeight: FontWeight.w700)),
                  ]),
                ),
              ),
            );
          }));
        }),
      ]),
    );
  }

  Widget _buildMonthAverage(List<dynamic> history) {
    if (_selectedChildId == null) return const SizedBox.shrink();
    final year = _selectedMonth.year;
    final month = _selectedMonth.month;
    final monthNotes = history.where((h) => h.childId == _selectedChildId && h.date.year == year && h.date.month == month).toList();
    if (monthNotes.isEmpty) return GlassCard(child: Center(child: Text('Aucune note ce mois-ci', style: TextStyle(color: Colors.grey[500], fontSize: 13))));

    double total = 0; int count = 0;
    for (final h in monthNotes) { final grade = _extractGrade(h.reason); if (grade != null) { total += grade; count++; } }
    final average = count > 0 ? total / count : 0.0;
    final scale = getScaleForGrade(average);
    final totalPoints = monthNotes.fold<int>(0, (s, h) => s + (h.points as int));

    return GlassCard(
      glowColor: scale['color'] as Color,
      child: Row(children: [
        Container(
          width: 60, height: 60,
          decoration: BoxDecoration(shape: BoxShape.circle, gradient: LinearGradient(colors: [(scale['color'] as Color).withValues(alpha: 0.3), (scale['color'] as Color).withValues(alpha: 0.1)]), border: Border.all(color: (scale['color'] as Color).withValues(alpha: 0.4))),
          child: Center(child: Text(average.toStringAsFixed(1), style: TextStyle(color: scale['color'] as Color, fontWeight: FontWeight.w900, fontSize: 18))),
        ),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Moyenne du mois', style: TextStyle(color: Colors.grey[400], fontSize: 12)),
          const SizedBox(height: 2),
          Row(children: [Text(scale['emoji'] as String, style: const TextStyle(fontSize: 16)), const SizedBox(width: 6), Text(scale['label'] as String, style: TextStyle(color: scale['color'] as Color, fontWeight: FontWeight.w700, fontSize: 14))]),
          const SizedBox(height: 2),
          Text('$count notes - +$totalPoints pts ce mois', style: TextStyle(color: Colors.grey[600], fontSize: 11)),
        ])),
      ]),
    );
  }

  Widget _buildMonthHistory(FamilyProvider provider, List<dynamic> history) {
    if (_selectedChildId == null) return const SizedBox.shrink();
    final year = _selectedMonth.year; final month = _selectedMonth.month;
    final monthNotes = history.where((h) => h.childId == _selectedChildId && h.date.year == year && h.date.month == month).toList();
    if (monthNotes.isEmpty) return const SizedBox.shrink();
    monthNotes.sort((a, b) => b.date.compareTo(a.date));

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(padding: const EdgeInsets.only(left: 4, bottom: 8), child: NeonText(text: 'Historique du mois', fontSize: 14, color: Colors.white, glowIntensity: 0.15)),
      ...monthNotes.map((h) {
        final grade = _extractGrade(h.reason) ?? 0;
        final scale = getScaleForGrade(grade);
        final comment = h.reason.contains(' - ') ? h.reason.split(' - ').skip(1).join(' - ') : '';
        return Container(
          margin: const EdgeInsets.only(bottom: 8), padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), color: (scale['color'] as Color).withValues(alpha: 0.06), border: Border.all(color: (scale['color'] as Color).withValues(alpha: 0.15))),
          child: Row(children: [
            Container(width: 42, height: 42, decoration: BoxDecoration(shape: BoxShape.circle, color: (scale['color'] as Color).withValues(alpha: 0.15), border: Border.all(color: (scale['color'] as Color).withValues(alpha: 0.3))),
              child: Center(child: Text('${grade.toStringAsFixed(0)}', style: TextStyle(color: scale['color'] as Color, fontWeight: FontWeight.w900, fontSize: 16)))),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [Text(scale['emoji'] as String, style: const TextStyle(fontSize: 14)), const SizedBox(width: 4), Text(scale['label'] as String, style: TextStyle(color: scale['color'] as Color, fontSize: 12, fontWeight: FontWeight.w600))]),
              if (comment.isNotEmpty) Text(comment, style: TextStyle(color: Colors.grey[500], fontSize: 11, fontStyle: FontStyle.italic), maxLines: 1, overflow: TextOverflow.ellipsis),
              Text('${h.date.day}/${h.date.month}/${h.date.year}', style: TextStyle(color: Colors.grey[700], fontSize: 10)),
            ])),
            Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), color: const Color(0xFF00E676).withValues(alpha: 0.12)),
              child: Text('+${h.points}', style: const TextStyle(color: Color(0xFF00E676), fontWeight: FontWeight.w800, fontSize: 13))),
          ]),
        );
      }),
    ]);
  }

  Widget _buildGradeScaleCard() {
    return GlassCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [const Icon(Icons.info_outline_rounded, color: _cyanColor, size: 18), const SizedBox(width: 8), const NeonText(text: 'Bareme des points', fontSize: 14, color: Colors.white)]),
        const SizedBox(height: 12),
        ..._gradeScale.map((scale) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(children: [
            Text(scale['emoji'] as String, style: const TextStyle(fontSize: 14)),
            const SizedBox(width: 8),
            SizedBox(width: 70, child: Text(
              scale['min'] == scale['max'] ? '${(scale['min'] as double).toInt()}/20' : '${(scale['min'] as double).toInt()}-${(scale['max'] as double).toInt()}/20',
              style: TextStyle(color: scale['color'] as Color, fontSize: 12, fontWeight: FontWeight.w600))),
            Expanded(child: Container(height: 6, decoration: BoxDecoration(borderRadius: BorderRadius.circular(3), color: (scale['color'] as Color).withValues(alpha: 0.15)),
              child: FractionallySizedBox(alignment: Alignment.centerLeft, widthFactor: (scale['points'] as int) / 10,
                child: Container(decoration: BoxDecoration(borderRadius: BorderRadius.circular(3), color: scale['color'] as Color))))),
            const SizedBox(width: 8),
            SizedBox(width: 30, child: Text('+${scale['points']}', textAlign: TextAlign.right, style: TextStyle(color: scale['color'] as Color, fontSize: 12, fontWeight: FontWeight.w700))),
          ]),
        )),
      ]),
    );
  }

  void _showDayDetail(BuildContext context, DateTime date, List<dynamic> history) {
    final dayNotes = history.where((h) => h.childId == _selectedChildId && _isSameDay(h.date, date)).toList();
    if (dayNotes.isEmpty) return;
    final h = dayNotes.last;
    final grade = _extractGrade(h.reason) ?? 0;
    final scale = getScaleForGrade(grade);
    final comment = h.reason.contains(' - ') ? h.reason.split(' - ').skip(1).join(' - ') : '';

    showDialog(context: context, builder: (ctx) => AlertDialog(
      backgroundColor: const Color(0xFF0D1B2A),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(children: [Text(scale['emoji'] as String, style: const TextStyle(fontSize: 24)), const SizedBox(width: 10), Text('${date.day}/${date.month}/${date.year}', style: const TextStyle(color: Colors.white, fontSize: 16))]),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 80, height: 80, decoration: BoxDecoration(shape: BoxShape.circle, gradient: LinearGradient(colors: [(scale['color'] as Color).withValues(alpha: 0.3), (scale['color'] as Color).withValues(alpha: 0.1)]), border: Border.all(color: (scale['color'] as Color).withValues(alpha: 0.5), width: 2)),
          child: Center(child: Text('${grade.toStringAsFixed(grade == grade.roundToDouble() ? 0 : 1)}', style: TextStyle(color: scale['color'] as Color, fontWeight: FontWeight.w900, fontSize: 28)))),
        const SizedBox(height: 12),
        Text(scale['label'] as String, style: TextStyle(color: scale['color'] as Color, fontWeight: FontWeight.w700, fontSize: 18)),
        const SizedBox(height: 8),
        Text('+${h.points} points', style: const TextStyle(color: Color(0xFF00E676), fontWeight: FontWeight.w800, fontSize: 16)),
        if (comment.isNotEmpty) ...[const SizedBox(height: 12), Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), color: Colors.white.withValues(alpha: 0.04)),
          child: Text(comment, style: TextStyle(color: Colors.grey[400], fontSize: 13, fontStyle: FontStyle.italic)))],
      ]),
      actions: [FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('Fermer'))],
    ));
  }

  void _showAddNote(BuildContext context) {
    final provider = context.read<FamilyProvider>();
    final gradeCtrl = TextEditingController();
    final commentCtrl = TextEditingController();
    String? selectedChildId = _selectedChildId ?? (provider.children.isNotEmpty ? provider.children.first.id : null);
    double? previewGrade;
    int previewPoints = 0;
    Map<String, dynamic> previewScale = _gradeScale.last;
    final today = DateTime.now();
    bool alreadyHasNote = false;
    if (selectedChildId != null) { alreadyHasNote = provider.history.any((h) => h.childId == selectedChildId && h.category == 'school_note' && _isSameDay(h.date, today)); }

    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: const Color(0xFF0D1B2A),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) {
          if (selectedChildId != null) { alreadyHasNote = provider.history.any((h) => h.childId == selectedChildId && h.category == 'school_note' && _isSameDay(h.date, today)); }
          return Padding(
            padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
            child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[700], borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 16),
              Row(children: [
                Container(width: 40, height: 40, decoration: BoxDecoration(color: _blueColor.withValues(alpha: 0.12), shape: BoxShape.circle, border: Border.all(color: _blueColor.withValues(alpha: 0.3))), child: const Icon(Icons.add_chart_rounded, color: _blueColor)),
                const SizedBox(width: 12),
                const NeonText(text: 'Note du jour', fontSize: 18, color: Colors.white),
              ]),
              const SizedBox(height: 6),
              Text('${today.day}/${today.month}/${today.year}', style: TextStyle(color: Colors.grey[500], fontSize: 12)),
              const SizedBox(height: 16),
              if (alreadyHasNote) Container(
                width: double.infinity, padding: const EdgeInsets.all(12), margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), color: Colors.orange.withValues(alpha: 0.1), border: Border.all(color: Colors.orange.withValues(alpha: 0.3))),
                child: Row(children: [const Icon(Icons.warning_rounded, color: Colors.orange, size: 18), const SizedBox(width: 8),
                  Expanded(child: Text('Cet enfant a deja une note aujourd\'hui. La nouvelle note sera ajoutee en plus.', style: TextStyle(color: Colors.orange[300], fontSize: 12)))]),
              ),
              DropdownButtonFormField<String>(
                value: selectedChildId, dropdownColor: const Color(0xFF162033), style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(labelText: 'Enfant', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                items: provider.children.map((c) => DropdownMenuItem(value: c.id, child: Text('${c.avatar.isEmpty ? "\u{1F466}" : c.avatar} ${c.name}'))).toList(),
                onChanged: (v) => setState(() => selectedChildId = v),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: gradeCtrl, keyboardType: const TextInputType.numberWithOptions(decimal: true), textAlign: TextAlign.center,
                style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: previewGrade != null ? previewScale['color'] as Color : _blueColor),
                decoration: InputDecoration(border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)), labelText: 'Note de comportement', suffixText: '/ 20', suffixStyle: TextStyle(fontSize: 18, color: Colors.grey[500])),
                onChanged: (val) {
                  final grade = double.tryParse(val.replaceAll(',', '.'));
                  setState(() {
                    if (grade != null && grade >= 0 && grade <= 20) { previewGrade = grade; previewPoints = getPointsForGrade(grade); previewScale = getScaleForGrade(grade); }
                    else { previewGrade = null; previewPoints = 0; previewScale = _gradeScale.last; }
                  });
                },
              ),
              const SizedBox(height: 16),
              TextField(controller: commentCtrl, style: const TextStyle(color: Colors.white), maxLines: 2,
                decoration: InputDecoration(border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), labelText: 'Commentaire (optionnel)', hintText: 'Ex: Sage, a bien ecoute...', hintStyle: TextStyle(color: Colors.grey[700], fontSize: 13))),
              const SizedBox(height: 16),
              if (previewGrade != null) AnimatedContainer(
                duration: const Duration(milliseconds: 300), width: double.infinity, padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), gradient: LinearGradient(colors: [(previewScale['color'] as Color).withValues(alpha: 0.12), (previewScale['color'] as Color).withValues(alpha: 0.04)]), border: Border.all(color: (previewScale['color'] as Color).withValues(alpha: 0.3))),
                child: Column(children: [
                  Text(previewScale['emoji'] as String, style: const TextStyle(fontSize: 36)),
                  const SizedBox(height: 8),
                  Text(previewScale['label'] as String, style: TextStyle(color: previewScale['color'] as Color, fontWeight: FontWeight.w700, fontSize: 16)),
                  const SizedBox(height: 4),
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    const Icon(Icons.arrow_upward_rounded, color: Color(0xFF00E676), size: 20),
                    const SizedBox(width: 4),
                    Text('+$previewPoints points', style: const TextStyle(color: Color(0xFF00E676), fontWeight: FontWeight.w800, fontSize: 20)),
                  ]),
                ]),
              ),
              const SizedBox(height: 20),
              SizedBox(width: double.infinity, height: 52, child: FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: _blueColor),
                onPressed: () {
                  if (previewGrade != null && selectedChildId != null) {
                    final comment = commentCtrl.text.trim();
                    final gradeStr = previewGrade!.toStringAsFixed(previewGrade == previewGrade!.roundToDouble() ? 0 : 1);
                    final reason = comment.isNotEmpty ? 'Note: $gradeStr/20 - $comment' : 'Note: $gradeStr/20';
                    provider.addPoints(selectedChildId!, previewPoints, reason, 'school_note', isBonus: true);
                    Navigator.pop(ctx);
                    setState(() => _selectedChildId = selectedChildId);
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Row(children: [Text(previewScale['emoji'] as String, style: const TextStyle(fontSize: 20)), const SizedBox(width: 8), Expanded(child: Text('+$previewPoints points pour $gradeStr/20'))]),
                      backgroundColor: const Color(0xFF00E676), behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ));
                  }
                },
                icon: const Icon(Icons.check_rounded),
                label: Text(previewPoints > 0 ? 'Valider (+$previewPoints pts)' : 'Entrez une note'),
              )),
            ])),
          );
        },
      ),
    );
  }
}
