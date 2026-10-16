import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:family_score/utils/screen_time_alarm_permission.dart';

void main() {
  Future<void> open(
    WidgetTester tester, {
    required bool allowed,
    required Future<bool> Function() request,
    required void Function(bool) complete,
  }) async {
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: Builder(
      builder: (context) => TextButton(
        onPressed: () async => complete(await prepareScreenTimeAlarm(
          context,
          canScheduleExactly: () async => allowed,
          requestPermission: request,
        )),
        child: const Text('Démarrer'),
      ),
    ))));
    await tester.tap(find.text('Démarrer'));
    await tester.pumpAndSettle();
  }

  testWidgets('accès déjà accordé : aucun dialogue ni demande', (tester) async {
    bool? result;
    var requests = 0;
    await open(tester,
        allowed: true,
        request: () async {
          requests++;
          return true;
        },
        complete: (value) => result = value);
    expect(result, isTrue);
    expect(requests, 0);
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('continuer sans accès ne demande aucune permission',
      (tester) async {
    bool? result;
    var requests = 0;
    await open(tester,
        allowed: false,
        request: () async {
          requests++;
          return true;
        },
        complete: (value) => result = value);
    expect(result, isNull);
    await tester.tap(find.text('Continuer sans autoriser'));
    await tester.pumpAndSettle();
    expect(result, isTrue);
    expect(requests, 0);
  });

  testWidgets('fermer le dialogue annule le démarrage', (tester) async {
    bool? result;
    var requests = 0;
    await open(tester,
        allowed: false,
        request: () async {
          requests++;
          return true;
        },
        complete: (value) => result = value);
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    expect(result, isFalse);
    expect(requests, 0);
  });

  testWidgets('refus Android : expliquer le retard avant de continuer',
      (tester) async {
    bool? result;
    var requests = 0;
    await open(tester,
        allowed: false,
        request: () async {
          requests++;
          return false;
        },
        complete: (value) => result = value);
    await tester.tap(find.text('Autoriser'));
    await tester.pumpAndSettle();
    expect(requests, 1);
    expect(result, isNull);
    expect(find.text('Sonnerie pouvant être retardée'), findsOneWidget);
    await tester.tap(find.text('Compris'));
    await tester.pumpAndSettle();
    expect(result, isTrue);
  });
}
