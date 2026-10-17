import 'dart:async';
import 'package:family_score/models/child_model.dart';
import 'package:family_score/models/punishment_lines.dart';
import 'package:family_score/providers/family_provider.dart';
import 'package:family_score/providers/pin_provider.dart';
import 'package:family_score/screens/punishment_lines_screen.dart';
import 'package:family_score/services/point_action_submission_service.dart';
import 'package:family_score/utils/checklist_helpers.dart';
import 'package:family_score/widgets/quick_point_action_form.dart';
import 'package:family_score/widgets/punishment_form_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

class UpdatingLinesFamily extends FamilyProvider {
  List<ChildModel> currentChildren = [ChildModel(id: 'a', name: 'Adam')];
  @override
  List<ChildModel> get children => currentChildren;
  @override
  List<PunishmentLines> get punishments => [
        PunishmentLines(
            id: 'pa', childId: 'a', text: 'Consigne Adam', totalLines: 10),
        PunishmentLines(
            id: 'pb', childId: 'b', text: 'Consigne Lina', totalLines: 10),
      ];
}

void main() {
  testWidgets(
      'les lignes ne gardent pas le profil supprimé après synchronisation',
      (tester) async {
    final family = UpdatingLinesFamily();
    await tester.pumpWidget(MultiProvider(providers: [
      ChangeNotifierProvider<FamilyProvider>.value(value: family),
      ChangeNotifierProvider(create: (_) => PinProvider()),
    ], child: const MaterialApp(home: PunishmentLinesScreen())));
    await tester.pump();
    expect(find.textContaining('Consigne Adam'), findsOneWidget);
    family.currentChildren = [ChildModel(id: 'b', name: 'Lina')];
    family.notifyListeners();
    await tester.pump();
    expect(find.textContaining('Consigne Adam'), findsNothing);
    expect(find.textContaining('Consigne Lina'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    family.dispose();
  });

  test('l’aperçu des points ne plafonne pas les grands soldes', () {
    expect(
        pointActionBalancePreview(balance: 2500, requested: 5, isBonus: false),
        2495);
    expect(pointActionBalancePreview(balance: 3, requested: 10, isBonus: false),
        0);
    expect(pointActionBalancePreview(balance: 998, requested: 5, isBonus: true),
        1003);
  });

  testWidgets('formulaire rapide sans enfant : message et envoi désactivé',
      (tester) async {
    var submissions = 0;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: QuickPointActionForm(
                isBonus: true,
                children: const [],
                presets: const [QuickPointActionPreset('Effort', 5)],
                onSubmit: (_) async {
                  submissions++;
                }))));
    await tester.tap(find.text('Effort'));
    await tester.pump();
    expect(
        tester
            .widget<ElevatedButton>(
                find.byKey(const ValueKey('quick_apply_button')))
            .onPressed,
        isNull);
    expect(
        find.textContaining('Aucun profil enfant disponible'), findsOneWidget);
    expect(submissions, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('la vérification du service peut échouer puis être relancée',
      (tester) async {
    var checks = 0;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: QuickPointActionForm(
                isBonus: true,
                children: [ChildModel(id: 'a', name: 'Adam')],
                presets: const [QuickPointActionPreset('Effort', 5)],
                onSubmit: (_) async {},
                checkServiceAvailability: ({bool force = false}) async {
                  checks++;
                  if (checks == 1) throw StateError('Erreur simulée');
                  return true;
                }))));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.ensureVisible(find.text('Vérifier à nouveau'));
    await tester.tap(find.text('Vérifier à nouveau'));
    await tester.pumpAndSettle();
    expect(checks, 2);
    expect(
        find.byKey(const ValueKey('quick_maintenance_message')), findsNothing);
  });

  testWidgets('le profil supprimé pendant la saisie ne reçoit pas l’action',
      (tester) async {
    final children = ValueNotifier(
        [ChildModel(id: 'a', name: 'Adam'), ChildModel(id: 'b', name: 'Lina')]);
    PointActionDraft? sent;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: ValueListenableBuilder(
      valueListenable: children,
      builder: (_, value, child) => QuickPointActionForm(
          isBonus: true,
          children: value,
          presets: const [QuickPointActionPreset('Effort', 5)],
          onSubmit: (draft) async {
            sent = draft;
          }),
    ))));
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Lina').last);
    await tester.pumpAndSettle();
    children.value = [ChildModel(id: 'a', name: 'Adam')];
    await tester.pump();
    await tester.tap(find.text('Effort'));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('quick_apply_button')));
    await tester.pumpAndSettle();
    expect(sent?.childId, 'a');
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    children.dispose();
  });

  Future<void> openSheet(
      WidgetTester tester, Future<void> Function(String, int) submit) async {
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: Builder(
                builder: (context) => TextButton(
                      onPressed: () => showModalBottomSheet<void>(
                          context: context,
                          isScrollControlled: true,
                          builder: (_) => PunishmentFormSheet(
                              childName: 'Adam', onSubmit: submit)),
                      child: const Text('Ouvrir'),
                    )))));
    await tester.tap(find.text('Ouvrir'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('punishment_description')),
        'Je respecte les autres');
    await tester.enterText(
        find.byKey(const ValueKey('punishment_lines')), '10');
  }

  testWidgets(
      'nouvelle punition : un seul envoi et texte conservé après erreur',
      (tester) async {
    final pending = Completer<void>();
    var calls = 0;
    await openSheet(tester, (_, lines) {
      calls++;
      return pending.future;
    });
    final save = find.byKey(const ValueKey('punishment_save'));
    await tester.tap(save);
    await tester.tap(save);
    await tester.pump();
    expect(calls, 1);
    pending.completeError(StateError('Erreur simulée'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Enregistrement non confirmé'), findsOneWidget);
    expect(
        tester
            .widget<TextField>(
                find.byKey(const ValueKey('punishment_description')))
            .controller!
            .text,
        'Je respecte les autres');
    expect(tester.widget<FilledButton>(save).onPressed, isNotNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'quitter l’écran pendant l’envoi n’entraîne pas de navigation tardive',
      (tester) async {
    final pending = Completer<void>();
    await openSheet(tester, (_, lines) => pending.future);
    await tester.tap(find.byKey(const ValueKey('punishment_save')));
    await tester.pump();
    await tester.pumpWidget(const MaterialApp(home: Text('Autre écran')));
    pending.complete();
    await tester.pumpAndSettle();
    expect(find.text('Autre écran'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('un succès ferme uniquement le formulaire de punition',
      (tester) async {
    final pending = Completer<void>();
    await openSheet(tester, (_, lines) => pending.future);
    await tester.tap(find.byKey(const ValueKey('punishment_save')));
    await tester.pump();
    pending.complete();
    await tester.pumpAndSettle();
    expect(find.byType(PunishmentFormSheet), findsNothing);
    expect(find.text('Ouvrir'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('zéro ligne ne déclenche aucun enregistrement', (tester) async {
    var calls = 0;
    await openSheet(tester, (_, lines) async {
      calls++;
    });
    await tester.enterText(find.byKey(const ValueKey('punishment_lines')), '0');
    await tester.tap(find.byKey(const ValueKey('punishment_save')));
    await tester.pumpAndSettle();
    expect(calls, 0);
    expect(find.textContaining('supérieur à zéro'), findsOneWidget);
  });
}
