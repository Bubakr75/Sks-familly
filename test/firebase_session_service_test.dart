import 'package:family_score/services/firebase_session_service.dart';
import 'package:flutter_test/flutter_test.dart';

class _Unauthenticated implements Exception {}

void main() {
  group('renouvellement de session borné', () {
    test('jeton refusé, renouvellement réussi puis retry unique', () async {
      var calls = 0;
      var refreshes = 0;
      final result = await callWithSingleAuthRetry(
        call: () async {
          calls++;
          if (calls == 1) throw _Unauthenticated();
          return 'ok';
        },
        refreshSession: () async {
          refreshes++;
          return const FirebaseSessionSnapshot(
            FirebaseSessionState.authenticated,
            uid: 'uid-stable',
          );
        },
        isUnauthenticated: (error) => error is _Unauthenticated,
      );

      expect(result, 'ok');
      expect(calls, 2);
      expect(refreshes, 1);
    });

    test('renouvellement échoué sans nouvel appel ni changement identité',
        () async {
      var calls = 0;
      await expectLater(
        callWithSingleAuthRetry<void>(
          call: () async {
            calls++;
            throw _Unauthenticated();
          },
          refreshSession: () async => const FirebaseSessionSnapshot(
            FirebaseSessionState.reconnectionRequired,
            uid: 'uid-conserve',
          ),
          isUnauthenticated: (error) => error is _Unauthenticated,
        ),
        throwsA(isA<FirebaseSessionException>()),
      );
      expect(calls, 1);
    });

    test('un second unauthenticated n’entraîne pas de troisième appel',
        () async {
      var calls = 0;
      await expectLater(
        callWithSingleAuthRetry<void>(
          call: () async {
            calls++;
            throw _Unauthenticated();
          },
          refreshSession: () async => const FirebaseSessionSnapshot(
            FirebaseSessionState.authenticated,
            uid: 'uid-stable',
          ),
          isUnauthenticated: (error) => error is _Unauthenticated,
        ),
        throwsA(isA<_Unauthenticated>()),
      );
      expect(calls, 2);
    });
  });
}
