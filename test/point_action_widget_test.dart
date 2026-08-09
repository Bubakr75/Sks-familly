import 'dart:async';

import 'package:family_score/models/child_model.dart';
import 'package:family_score/services/point_action_submission_service.dart';
import 'package:family_score/widgets/point_action_panel.dart';
import 'package:family_score/widgets/quick_point_action_form.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _bonusPreset = ActionMotif('bonus', '⭐', 'Chambre rangée', 5);
const _penaltyPreset = ActionMotif('penalty', '⚠️', 'Insolence', 5);
const _other = ActionMotif('other', '✏️', 'Autre', 5, isOther: true);

PointActionConfig config(bool isBonus) => PointActionConfig(
      title: isBonus ? 'Bonus' : 'Pénalité',
      subtitle: 'Test réel',
      buttonText: 'Appliquer',
      category: isBonus ? 'bonus' : 'penalty',
      isBonus: isBonus,
      primaryColor: isBonus ? Colors.green : Colors.red,
      accentColor: Colors.white,
      backgroundColor: Colors.black,
      motifs: [isBonus ? _bonusPreset : _penaltyPreset, _other],
      buttonIcon: Icons.check,
      successMessage: 'OK {name} {amount}',
    );

final _child = ChildModel(id: 'child-1', name: 'Lina', points: 100);

void compactView(WidgetTester tester, {double textScale = 1}) {
  tester.view.physicalSize = const Size(375, 667);
  tester.view.devicePixelRatio = 1;
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
}

void expectVisibleAndTappable(Finder finder, WidgetTester tester) {
  expect(finder, findsOneWidget);
  expect(finder.hitTestable(), findsOneWidget);
  final rect = tester.getRect(finder);
  expect(rect.top, greaterThanOrEqualTo(0));
  expect(rect.bottom, lessThanOrEqualTo(667));
}

Future<void> pumpMain(
  WidgetTester tester, {
  required bool isBonus,
  required Future<int> Function(PointActionDraft) submit,
  double textScale = 1,
}) async {
  compactView(tester, textScale: textScale);
  SharedPreferences.setMockInitialValues({});
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: PointActionPanel(
        config: config(isBonus),
        children: [_child],
        submitAction: submit,
      ),
    ),
  ));
  await tester.pumpAndSettle();
}

Future<void> scrollTo(WidgetTester tester, Finder target, Key scrollKey) async {
  await tester.scrollUntilVisible(
    target,
    180,
    scrollable: find
        .descendant(
          of: find.byKey(scrollKey),
          matching: find.byType(Scrollable),
        )
        .first,
  );
  await tester.pump();
}

Future<void> choosePenaltyLines(
  WidgetTester tester,
  bool value, {
  Key scrollKey = const ValueKey('point_action_scroll_view'),
}) async {
  final label = find.text(value ? 'Oui' : 'Non');
  await scrollTo(tester, label, scrollKey);
  await tester.tap(label);
  await tester.pump();
}

void main() {
  group('PointActionPanel réel sur petit écran', () {
    testWidgets('bonus prédéfini reste visible, tappable et transmet le motif',
        (tester) async {
      PointActionDraft? sent;
      await pumpMain(tester, isBonus: true, submit: (draft) async {
        sent = draft;
        return draft.amount;
      });
      await tester.tap(find.text('Chambre rangée'));
      await tester.pump();
      final button = find.byKey(const ValueKey('point_action_apply_button'));
      expectVisibleAndTappable(button, tester);
      expect(tester.widget<ElevatedButton>(button).onPressed, isNotNull);
      await tester.tap(button);
      await tester.pumpAndSettle();
      expect(sent?.reason, 'Chambre rangée');
    });

    testWidgets('pénalité prédéfinie sans lignes est visible et tappable',
        (tester) async {
      PointActionDraft? sent;
      await pumpMain(tester, isBonus: false, submit: (draft) async {
        sent = draft;
        return draft.amount;
      });
      await tester.tap(find.text('Insolence'));
      await choosePenaltyLines(tester, false);
      final button = find.byKey(const ValueKey('point_action_apply_button'));
      expectVisibleAndTappable(button, tester);
      await tester.tap(button);
      await tester.pumpAndSettle();
      expect(sent?.reason, 'Insolence');
      expect(sent?.hasPenaltyLines, isFalse);
    });

    testWidgets('Autre, texte agrandi et clavier gardent le bouton accessible',
        (tester) async {
      PointActionDraft? sent;
      await pumpMain(
        tester,
        isBonus: true,
        textScale: 1.5,
        submit: (draft) async {
          sent = draft;
          return draft.amount;
        },
      );
      await tester.tap(find.text('Autre'));
      final customReason =
          find.byKey(const ValueKey('point_action_custom_reason'));
      await scrollTo(
        tester,
        customReason,
        const ValueKey('point_action_scroll_view'),
      );
      await tester.enterText(customReason, '  Super effort  ');
      tester.view.viewInsets = const FakeViewPadding(bottom: 260);
      addTearDown(tester.view.resetViewInsets);
      await tester.pump();
      final button = find.byKey(const ValueKey('point_action_apply_button'));
      expectVisibleAndTappable(button, tester);
      await tester.tap(button);
      await tester.pumpAndSettle();
      expect(sent?.reason, 'Super effort');
    });

    testWidgets('pénalité prédéfinie avec lignes transmet toute l’obligation',
        (tester) async {
      PointActionDraft? sent;
      await pumpMain(tester, isBonus: false, submit: (draft) async {
        sent = draft;
        return draft.amount;
      });
      await tester.tap(find.text('Insolence'));
      await choosePenaltyLines(tester, true);
      await tester.enterText(
        find.byKey(const ValueKey('penalty_lines_count')),
        '20',
      );
      await tester.pump();
      final button = find.byKey(const ValueKey('point_action_apply_button'));
      expectVisibleAndTappable(button, tester);
      await tester.tap(button);
      await tester.pumpAndSettle();
      expect(sent?.penaltyLinesCount, 20);
    });
  });

  group('QuickPointActionForm réel', () {
    Future<void> pumpQuick(
      WidgetTester tester, {
      required bool isBonus,
      required Future<void> Function(PointActionDraft) submit,
    }) async {
      compactView(tester);
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: QuickPointActionForm(
            isBonus: isBonus,
            children: [_child],
            presets: const [QuickPointActionPreset('Motif rapide', 4)],
            onSubmit: submit,
          ),
        ),
      ));
    }

    testWidgets('bonus rapide prédéfini est visible, tappable et transmis',
        (tester) async {
      PointActionDraft? sent;
      await pumpQuick(tester,
          isBonus: true, submit: (draft) async => sent = draft);
      await tester.tap(find.text('Motif rapide'));
      await tester.pump();
      final button = find.byKey(const ValueKey('quick_apply_button'));
      expectVisibleAndTappable(button, tester);
      await tester.tap(button);
      await tester.pumpAndSettle();
      expect(sent?.reason, 'Motif rapide');
    });

    testWidgets('pénalité rapide Autre avec lignes est visible et transmise',
        (tester) async {
      PointActionDraft? sent;
      await pumpQuick(tester,
          isBonus: false, submit: (draft) async => sent = draft);
      await tester.tap(find.text('Autre'));
      final quickReason = find.byKey(const ValueKey('quick_custom_reason'));
      await scrollTo(
        tester,
        quickReason,
        const ValueKey('quick_point_action_scroll'),
      );
      await tester.enterText(quickReason, '  Motif libre  ');
      await choosePenaltyLines(
        tester,
        true,
        scrollKey: const ValueKey('quick_point_action_scroll'),
      );
      final lineCount = find.byKey(const ValueKey('quick_lines_count'));
      await scrollTo(
        tester,
        lineCount,
        const ValueKey('quick_point_action_scroll'),
      );
      await tester.enterText(lineCount, '12');
      await tester.pump();
      final button = find.byKey(const ValueKey('quick_apply_button'));
      expectVisibleAndTappable(button, tester);
      await tester.tap(button);
      await tester.pumpAndSettle();
      expect(sent?.reason, 'Motif libre');
      expect(sent?.penaltyLinesCount, 12);
    });

    testWidgets('double appui rapide ne soumet qu’une fois', (tester) async {
      final gate = Completer<void>();
      var calls = 0;
      await pumpQuick(tester, isBonus: true, submit: (_) async {
        calls++;
        await gate.future;
      });
      await tester.tap(find.text('Motif rapide'));
      await tester.pump();
      final button = find.byKey(const ValueKey('quick_apply_button'));
      await tester.tap(button, warnIfMissed: false);
      await tester.tap(button, warnIfMissed: false);
      await tester.pump();
      expect(calls, 1);
      gate.complete();
      await tester.pumpAndSettle();
    });

    testWidgets('un retry rapide conserve exactement le même operationId',
        (tester) async {
      final operationIds = <String>[];
      var attempt = 0;
      await pumpQuick(tester, isBonus: true, submit: (draft) async {
        operationIds.add(draft.actionId);
        attempt++;
        if (attempt == 1) {
          draft.onVerifying?.call();
          throw const PointActionRemoteException(code: 'unavailable');
        }
      });
      await tester.tap(find.text('Motif rapide'));
      await tester.pump();
      final button = find.byKey(const ValueKey('quick_apply_button'));
      await tester.tap(button);
      await tester.pumpAndSettle();
      expect(find.text('Impossible d’enregistrer le bonus. Réessayez.'),
          findsOneWidget);
      await tester.tap(button);
      await tester.pumpAndSettle();
      expect(operationIds, hasLength(2));
      expect(operationIds[1], operationIds[0]);
    });
  });
}
