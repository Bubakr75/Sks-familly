import 'dart:async';
import 'package:family_score/models/child_model.dart';
import 'package:family_score/widgets/tribunal_case_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> openDialog(WidgetTester tester, SubmitTribunalCase submit) async {
  await tester.pumpWidget(MaterialApp(
      home: Builder(
          builder: (context) => Scaffold(
              body: TextButton(
                  onPressed: () => showDialog<bool>(
                      context: context,
                      builder: (_) => TribunalCaseDialog(
                          childAccount: true,
                          childId: 'c1',
                          children: [
                            ChildModel(id: 'c1', name: 'Enfant 1'),
                            ChildModel(id: 'c2', name: 'Enfant 2')
                          ],
                          onSubmit: submit)),
                  child: const Text('Ouvrir'))))));
  await tester.tap(find.text('Ouvrir'));
  await tester.pumpAndSettle();
  await tester.enterText(
      find.byKey(const ValueKey('tribunal_title')), 'Titre test');
  await tester.enterText(
      find.byKey(const ValueKey('tribunal_description')), 'Description test');
  await tester.tap(find.byKey(const ValueKey('tribunal_accused_c2')));
  await tester.pump();
}

void main() {
  testWidgets('attend le serveur, bloque double appui puis ferme sur succès',
      (tester) async {
    final gate = Completer<void>();
    var calls = 0;
    await openDialog(tester, (id, title, description, plaintiff, accused) {
      calls++;
      expect(plaintiff, 'c1');
      expect(accused, 'c2');
      return gate.future;
    });
    final button = find.byKey(const ValueKey('tribunal_submit'));
    await tester.tap(button);
    await tester.tap(button);
    await tester.pump();
    expect(calls, 1);
    expect(find.byType(TribunalCaseDialog), findsOneWidget);
    expect(find.text('Envoi en cours…'), findsOneWidget);
    gate.complete();
    await tester.pumpAndSettle();
    expect(find.byType(TribunalCaseDialog), findsNothing);
  });

  testWidgets(
      'échec visible, texte conservé, nouvelle tentative avec même identifiant',
      (tester) async {
    final ids = <String>[];
    await openDialog(tester,
        (id, title, description, plaintiff, accused) async {
      ids.add(id);
      if (ids.length == 1) throw StateError('offline');
    });
    final button = find.byKey(const ValueKey('tribunal_submit'));
    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('tribunal_error')), findsOneWidget);
    expect(find.text('Titre test'), findsOneWidget);
    expect(find.text('Description test'), findsOneWidget);
    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(ids.length, 2);
    expect(ids[0], ids[1]);
    expect(find.byType(TribunalCaseDialog), findsNothing);
  });

  testWidgets('compte enfant ne peut pas choisir un autre plaignant',
      (tester) async {
    await openDialog(tester, (_, __, ___, ____, _____) async {});
    final chips =
        tester.widgetList<ChoiceChip>(find.byType(ChoiceChip)).toList();
    expect(chips.length, 2);
    expect(chips.first.selected, true);
    expect(chips.first.onSelected, isNull);
  });
}
