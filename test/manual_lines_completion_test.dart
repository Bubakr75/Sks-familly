import 'package:family_score/models/punishment_lines.dart';
import 'package:family_score/screens/punishment_lines_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'home_redesign_test.dart' as demo;

class LinesFamily extends demo.DemoFamily {
  LinesFamily({super.role, super.childId});
  int validations = 0;
  final lines = PunishmentLines(id: 'manual', childId: 'adam', text: 'Ma consigne', totalLines: 10);
  @override
  List<PunishmentLines> get punishments => [lines];
  @override
  Future<void> completeLinkedPenaltyLines(String id) async {
    validations++;
    lines.completedLines = lines.totalLines;
    lines.completedAt = DateTime(2026, 10, 16);
    lines.completedBy = 'parent';
    notifyListeners();
  }
}

void main() {
  testWidgets('le parent valide les lignes manuelles après confirmation', (tester) async {
    final family = LinesFamily(role: 'parent');
    await tester.pumpWidget(demo.wrap(const PunishmentLinesScreen(), parent: true, family: family));
    await tester.pump();
    await tester.ensureVisible(find.text('Valider les lignes effectuées'));
    await tester.tap(find.text('Valider les lignes effectuées'));
    await tester.pump();
    expect(family.validations, 0);
    await tester.tap(find.text('Confirmer'));
    await tester.pump();
    expect(family.validations, 1);
    expect(family.lines.isCompleted, isTrue);
    expect(find.text('Valider les lignes effectuées'), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('un appareil enfant ne propose pas la validation parentale', (tester) async {
    final family = LinesFamily(role: 'child', childId: 'adam');
    await tester.pumpWidget(demo.wrap(const PunishmentLinesScreen(), parent: true, family: family));
    await tester.pump();
    expect(find.text('Valider les lignes effectuées'), findsNothing);
    expect(family.validations, 0);
    await tester.pumpWidget(const SizedBox());
  });

  test('les lignes manuelles conservent l’auteur et la date après relecture', () {
    final lines = PunishmentLines(id: 'manual', childId: 'adam', text: 'Consigne',
      totalLines: 10, completedLines: 10, completedAt: DateTime(2026, 10, 16),
      completedBy: 'parent', status: PenaltyLinesStatus.completed);
    final restored = PunishmentLines.fromMap(lines.toMap());
    expect(restored.isCompleted, isTrue);
    expect(restored.completedBy, 'parent');
    expect(restored.completedAt, lines.completedAt);
    expect(restored.isLinkedToPenalty, isFalse);
  });
}
