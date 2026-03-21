  void _showAddNote(BuildContext context) {
    final provider = context.read<FamilyProvider>();
    final gradeCtrl = TextEditingController();
    final commentCtrl = TextEditingController();
    String? selectedChildId = _selectedChildId ?? (provider.children.isNotEmpty ? provider.children.first.id : null);
    double? previewGrade;
    int previewPoints = 0;
    Map<String, dynamic> previewScale = _gradeScale.last;
    DateTime selectedDate = DateTime.now();
    bool alreadyHasNote = false;
    if (selectedChildId != null) { alreadyHasNote = provider.history.any((h) => h.childId == selectedChildId && h.category == 'school_note' && _isSameDay(h.date, selectedDate)); }

    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: const Color(0xFF0D1B2A),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) {
          if (selectedChildId != null) { alreadyHasNote = provider.history.any((h) => h.childId == selectedChildId && h.category == 'school_note' && _isSameDay(h.date, selectedDate)); }
          final isToday = _isSameDay(selectedDate, DateTime.now());
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
              const SizedBox(height: 12),

              // === DATE SELECTOR ===
              GestureDetector(
                onTap: () async {
                  final now = DateTime.now();
                  final mondayThisWeek = now.subtract(Duration(days: now.weekday - 1));
                  final firstAllowed = mondayThisWeek.subtract(const Duration(days: 14));
                  final picked = await showDatePicker(
                    context: ctx,
                    initialDate: selectedDate,
                    firstDate: firstAllowed,
                    lastDate: now,
                    locale: const Locale('fr', 'FR'),
                    builder: (context, child) {
                      return Theme(
                        data: Theme.of(context).copyWith(
                          colorScheme: const ColorScheme.dark(
                            primary: Color(0xFF448AFF),
                            onPrimary: Colors.white,
                            surface: Color(0xFF0D1B2A),
                            onSurface: Colors.white,
                          ),
                          dialogBackgroundColor: const Color(0xFF0D1B2A),
                        ),
                        child: child!,
                      );
                    },
                  );
                  if (picked != null) {
                    setState(() => selectedDate = picked);
                  }
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: isToday ? _blueColor.withValues(alpha: 0.08) : Colors.orange.withValues(alpha: 0.08),
                    border: Border.all(color: isToday ? _blueColor.withValues(alpha: 0.3) : Colors.orange.withValues(alpha: 0.3)),
                  ),
                  child: Row(children: [
                    Icon(Icons.calendar_today_rounded, color: isToday ? _blueColor : Colors.orange, size: 18),
                    const SizedBox(width: 10),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(
                        isToday ? 'Aujourd\'hui' : '${_dayNames[selectedDate.weekday - 1]} ${selectedDate.day}/${selectedDate.month}/${selectedDate.year}',
                        style: TextStyle(color: isToday ? _blueColor : Colors.orange, fontWeight: FontWeight.w700, fontSize: 14),
                      ),
                      if (!isToday) Text('Note en retard', style: TextStyle(color: Colors.orange.withValues(alpha: 0.7), fontSize: 11)),
                    ])),
                    Icon(Icons.arrow_drop_down_rounded, color: isToday ? _blueColor : Colors.orange, size: 24),
                  ]),
                ),
              ),
              const SizedBox(height: 12),

              if (alreadyHasNote) Container(
                width: double.infinity, padding: const EdgeInsets.all(12), margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), color: Colors.orange.withValues(alpha: 0.1), border: Border.all(color: Colors.orange.withValues(alpha: 0.3))),
                child: Row(children: [const Icon(Icons.warning_rounded, color: Colors.orange, size: 18), const SizedBox(width: 8),
                  Expanded(child: Text('Cet enfant a deja une note ce jour. La nouvelle note sera ajoutee en plus.', style: TextStyle(color: Colors.orange[300], fontSize: 12)))]),
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
                    provider.addPoints(selectedChildId!, previewPoints, reason, 'school_note', isBonus: true, date: selectedDate);
                    Navigator.pop(ctx);
                    this.setState(() => _selectedChildId = selectedChildId);
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Row(children: [Text(previewScale['emoji'] as String, style: const TextStyle(fontSize: 20)), const SizedBox(width: 8), Expanded(child: Text('+$previewPoints points pour $gradeStr/20${!isToday ? " (${selectedDate.day}/${selectedDate.month})" : ""}'))]),
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
