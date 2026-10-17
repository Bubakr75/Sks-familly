import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:family_score/services/notification_diagnostic.dart';

void main() {
  var saved = 0;
  NotificationDiagnostic runner(
          {String? problem,
          bool allowed = true,
          Future<void> Function(String)? save,
          Future<String?> Function()? token}) =>
      NotificationDiagnostic(
          contextProblem: () async => problem,
          permission: () async => allowed,
          token: token ?? () async => 'private-token',
          save: save ??
              (_) async {
                saved++;
              },
          errorCode: (_) => 'permission-denied',
          timeout: const Duration(milliseconds: 10));
  setUp(() => saved = 0);
  test('la vérification ne modifie pas l’enregistrement', () async {
    final result = await runner().run();
    expect(result.code, 'verification-locale-ok');
    expect(result.registered, false);
    expect(saved, 0);
    expect(result.message, isNot(contains('private-token')));
  });
  test('la réparation attend la confirmation de l’écriture', () async {
    final result = await runner().run(repair: true);
    expect(saved, 1);
    expect(result.registered, true);
  });
  test('un refus serveur ne devient jamais un succès', () async {
    final result =
        await runner(save: (_) async => throw StateError('private-data'))
            .run(repair: true);
    expect(result.code, 'enregistrement/permission-denied');
    expect(result.registered, false);
    expect(result.message, isNot(contains('private-data')));
  });
  test('une permission refusée ou une famille absente bloque la réparation',
      () async {
    expect((await runner(allowed: false).run(repair: true)).code,
        'notifications-refusees');
    expect((await runner(problem: 'famille-absente').run(repair: true)).code,
        'famille-absente');
    expect(saved, 0);
  });
  test('un service sans réponse reste borné et ne confirme rien', () async {
    final result = await runner(token: () => Completer<String?>().future)
        .run(repair: true);
    expect(result.code, 'adresse/delai-depasse');
    expect(saved, 0);
    expect(result.registered, false);
  });
}
