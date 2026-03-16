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

  static const _blueColor = Color(0xFF448AFF);
  static const _cyanColor = Color(0xFF00E5FF);

  static const List<Map<String, dynamic>> _gradeScale = [
    {'min': 20.0, 'max': 20.0, 'points': 100, 'label': 'Exceptionnel', 'color': Color(0xFFFFD740), 'emoji': '\u{1F3C6}'},
    {'min': 18.0, 'max': 19.9, 'points': 90, 'label': 'Excellent', 'color': Color(0xFF00E676), 'emoji': '\u{1F31F}'},
    {'min': 16.0, 'max': 17.9, 'points': 75, 'label': 'Tres bien', 'color': Color(0xFF00E676), 'emoji': '\u{1F4AA}'},
    {'min': 14.0, 'max': 15.9, 'points': 50, 'label': 'Bien', 'color': Color(0xFF448AFF), 'emoji': '\u{1F44D}'},
    {'min': 12.0, 'max': 13.9, 'points': 35, 'label': 'Assez bien', 'color': Color(0xFF448AFF), 'emoji': '\u{1F60A}'},
    {'min': 10.0, 'max': 11.9, 'points': 25, 'label': 'Passable', 'color': Color(0xFFFF9100), 'emoji': '\u{1F44C}'},
    {'min': 8.0, 'max': 9.9, 'points': 10, 'label': 'Insuffisant', 'color': Color(0xFFFF6E40), 'emoji': '\u{1F615}'},
    {'min': 6.0, 'max': 7.9, 'points': 5, 'label': 'Faible', 'color': Color(0xFFFF1744), 'emoji': '\u{1F61F}'},
    {'min': 0.0, 'max': 5.9, 'points': 0, 'label': 'Tres faible', 'color': Color(0xFFFF1744), 'emoji': '\u{1F625}'},
  ];

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
      if (grade >= (scale['min'] as double) && grade <= (scale['max'] as double)) {
        return scale['points'] as int;
      }
    }
    return 0;
  }

  static Map<String, dynamic> getScaleForGrade(double grade) {
    for (final scale in _gradeScale) {
      if (grade >= (scale['min'] as double) && grade <= (scale['max'] as double)) {
        return scale;
      }
    }
    return _gradeScale.last;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E21),
      appBar: AppBar(
        title: NeonText(text: 'Notes comportement', fontSize: 18, color: Colors.white),
        backgroundColor: Colors.transparent,
      ),
      floatingActionButton: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: _blueColor.withValues(alpha: 0.3), blurRadius: 16)],
        ),
        child: FloatingActionButton.extended(
          heroTag: 'add_school_note',
          backgroundColor: _blueColor,
          onPressed: () => PinGuard.guardAction(context, () => _showAddNote(context)),
          icon: const Icon(Icons.add_chart_rounded),
          label: const Text('Ajouter une note', style: TextStyle(fontWeight: FontWeight.w700)),
        ),
      ),
      body: Consumer<FamilyProvider>(
        builder: (context, provider, _) {
          final schoolHistory = provider.history.where((h) => h.category == 'school_note').toList();

          return AnimatedBackground(
            child: schoolHistory.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        GlowIcon(icon: Icons.add_chart_rounded, size: 64, color: Colors.grey[600]),
                        const SizedBox(height: 16),
                        Text('Aucune note de comportement', style: TextStyle(fontSize: 18, color: Colors.grey[500])),
                        const SizedBox(height: 8),
                        Text('Notez le comportement de vos enfants', style: TextStyle(fontSize: 13, color: Colors.grey[700])),
                        const SizedBox(height: 24),
                        _buildGradeScaleCard(),
                      ],
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
                    children: [
                      _buildGradeScaleCard(),
                      const SizedBox(height: 16),
                      ...schoolHistory.map((h) {
                        final child = provider.getChild(h.childId);
                        final gradeMatch = RegExp(r'Note: ([\d.]+)/20').firstMatch(h.reason);
                        final grade = gradeMatch != null ? double.tryParse(gradeMatch.group(1)!) ?? 0 : 0.0;
                        final scale = getScaleForGrade(grade);

                        return SlideTransition(
                          position: Tween<Offset>(begin: const Offset(0.3, 0), end: Offset.zero)
                              .animate(CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic)),
                          child: GlassCard(
                            margin: const EdgeInsets.only(bottom: 10),
                            glowColor: scale['color'] as Color,
                            child: Row(
                              children: [
                                Container(
                                  width: 56, height: 56,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: LinearGradient(colors: [
                                      (scale['color'] as Color).withValues(alpha: 0.3),
                                      (scale['color'] as Color).withValues(alpha: 0.1),
                                    ], begin: Alignment.topLeft, end: Alignment.bottomRight),
                                    border: Border.all(color: (scale['color'] as Color).withValues(alpha: 0.4)),
                                    boxShadow: [BoxShadow(color: (scale['color'] as Color).withValues(alpha: 0.2), blurRadius: 8)],
                                  ),
                                  child: Center(
                                    child: Text(
                                      grade.toStringAsFixed(grade == grade.roundToDouble() ? 0 : 1),
                                      style: TextStyle(color: scale['color'] as Color, fontWeight: FontWeight.w900, fontSize: 18),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(child?.name ?? 'Inconnu', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.white)),
                                      const SizedBox(height: 2),
                                      Row(children: [
                                        Text(scale['emoji'] as String, style: const TextStyle(fontSize: 14)),
                                        const SizedBox(width: 4),
                                        Text(scale['label'] as String, style: TextStyle(color: scale['color'] as Color, fontSize: 12, fontWeight: FontWeight.w600)),
                                      ]),
                                      const SizedBox(height: 2),
                                      Text(
                                        '${h.reason.replaceAll(RegExp(r'Note: [\d.]+/20'), '').replaceAll(' en ', '').trim()}'
                                        '\n${h.date.day}/${h.date.month}/${h.date.year} ${h.date.hour}:${h.date.minute.toString().padLeft(2, '0')}',
                                        style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(12),
                                    color: const Color(0xFF00E676).withValues(alpha: 0.12),
                                    border: Border.all(color: const Color(0xFF00E676).withValues(alpha: 0.3)),
                                  ),
                                  child: Text('+${h.points}', style: const TextStyle(color: Color(0xFF00E676), fontWeight: FontWeight.w800, fontSize: 16)),
                                ),
                              ],
                            ),
                          ),
                        );
                      }),
                    ],
                  ),
          );
        },
      ),
    );
  }

  Widget _buildGradeScaleCard() {
    return GlassCard(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.info_outline_rounded, color: _cyanColor, size: 18),
            const SizedBox(width: 8),
            const NeonText(text: 'Bareme des points', fontSize: 14, color: Colors.white),
          ]),
          const SizedBox(height: 12),
          ..._gradeScale.map((scale) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(children: [
              Text(scale['emoji'] as String, style: const TextStyle(fontSize: 14)),
              const SizedBox(width: 8),
              SizedBox(
                width: 70,
                child: Text(
                  scale['min'] == scale['max']
                      ? '${(scale['min'] as double).toInt()}/20'
                      : '${(scale['min'] as double).toInt()}-${(scale['max'] as double).toInt()}/20',
                  style: TextStyle(color: scale['color'] as Color, fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ),
              Expanded(
                child: Container(
                  height: 6,
                  decoration: BoxDecoration(borderRadius: BorderRadius.circular(3), color: (scale['color'] as Color).withValues(alpha: 0.15)),
                  child: FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: (scale['points'] as int) / 100,
                    child: Container(decoration: BoxDecoration(borderRadius: BorderRadius.circular(3), color: scale['color'] as Color)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(width: 40, child: Text('+${scale['points']}', textAlign: TextAlign.right, style: TextStyle(color: scale['color'] as Color, fontSize: 12, fontWeight: FontWeight.w700))),
            ]),
          )),
        ],
      ),
    );
  }

  void _showAddNote(BuildContext context) {
    final provider = context.read<FamilyProvider>();
    final gradeCtrl = TextEditingController();
    final commentCtrl = TextEditingController();
    String? selectedChildId = provider.children.isNotEmpty ? provider.children.first.id : null;
    double? previewGrade;
    int previewPoints = 0;
    Map<String, dynamic> previewScale = _gradeScale.last;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF0D1B2A),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => Padding(
          padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[700], borderRadius: BorderRadius.circular(2)))),
                const SizedBox(height: 16),
                Row(children: [
                  Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(
                      color: _blueColor.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                      border: Border.all(color: _blueColor.withValues(alpha: 0.3)),
                    ),
                    child: const Icon(Icons.add_chart_rounded, color: _blueColor),
                  ),
                  const SizedBox(width: 12),
                  const NeonText(text: 'Noter le comportement', fontSize: 18, color: Colors.white),
                ]),
                const SizedBox(height: 20),

                DropdownButtonFormField<String>(
                  value: selectedChildId,
                  dropdownColor: const Color(0xFF162033),
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(labelText: 'Enfant', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                  items: provider.children.map((c) => DropdownMenuItem(
                    value: c.id,
                    child: Text('${c.avatar.isEmpty ? "\u{1F466}" : c.avatar} ${c.name}'),
                  )).toList(),
                  onChanged: (v) => setState(() => selectedChildId = v),
                ),
                const SizedBox(height: 16),

                TextField(
                  controller: gradeCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 32, fontWeight: FontWeight.w900,
                    color: previewGrade != null ? previewScale['color'] as Color : _blueColor,
                  ),
                  decoration: InputDecoration(
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                    labelText: 'Note de comportement',
                    suffixText: '/ 20',
                    suffixStyle: TextStyle(fontSize: 18, color: Colors.grey[500]),
                  ),
                  onChanged: (val) {
                    final grade = double.tryParse(val.replaceAll(',', '.'));
                    setState(() {
                      if (grade != null && grade >= 0 && grade <= 20) {
                        previewGrade = grade;
                        previewPoints = getPointsForGrade(grade);
                        previewScale = getScaleForGrade(grade);
                      } else {
                        previewGrade = null;
                        previewPoints = 0;
                        previewScale = _gradeScale.last;
                      }
                    });
                  },
                ),
                const SizedBox(height: 16),

                TextField(
                  controller: commentCtrl,
                  style: const TextStyle(color: Colors.white),
                  maxLines: 2,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    labelText: 'Commentaire (optionnel)',
                    hintText: 'Ex: Bon comportement en classe, aide ses camarades...',
                    hintStyle: TextStyle(color: Colors.grey[700], fontSize: 13),
                  ),
                ),
                const SizedBox(height: 16),

                if (previewGrade != null)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      gradient: LinearGradient(colors: [
                        (previewScale['color'] as Color).withValues(alpha: 0.12),
                        (previewScale['color'] as Color).withValues(alpha: 0.04),
                      ]),
                      border: Border.all(color: (previewScale['color'] as Color).withValues(alpha: 0.3)),
                    ),
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

                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(backgroundColor: _blueColor),
                    onPressed: () {
                      if (previewGrade != null && selectedChildId != null && previewPoints > 0) {
                        final comment = commentCtrl.text.trim();
                        final gradeStr = previewGrade!.toStringAsFixed(previewGrade == previewGrade!.roundToDouble() ? 0 : 1);
                        final reason = comment.isNotEmpty
                            ? 'Note: $gradeStr/20 - $comment'
                            : 'Note: $gradeStr/20';
                        provider.addPoints(selectedChildId!, previewPoints, reason, 'school_note', isBonus: true);
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Row(children: [
                              Text(previewScale['emoji'] as String, style: const TextStyle(fontSize: 20)),
                              const SizedBox(width: 8),
                              Expanded(child: Text('+$previewPoints points pour $gradeStr/20')),
                            ]),
                            backgroundColor: const Color(0xFF00E676),
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        );
                      }
                    },
                    icon: const Icon(Icons.check_rounded),
                    label: Text(previewPoints > 0 ? 'Valider (+$previewPoints pts)' : 'Entrez une note'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
