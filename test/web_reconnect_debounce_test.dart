import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String reconnectSource;
  late String firestoreSource;
  late String mainSource;

  setUpAll(() {
    reconnectSource =
        File('lib/utils/web_reconnect_web.dart').readAsStringSync() +
            File('lib/utils/pwa_lifecycle.dart').readAsStringSync();
    firestoreSource =
        File('lib/services/firestore_service.dart').readAsStringSync();
    mainSource = File('lib/main.dart').readAsStringSync();
  });

  test('focus, visibilité et retour réseau partagent un debounce', () {
    expect(reconnectSource, contains('class PwaLifecycle'));
    expect(reconnectSource, contains('Duration(milliseconds: 700)'));
    expect(reconnectSource, contains('onVisibilityChange'));
    expect(reconnectSource, contains('onOnline'));
    expect(reconnectSource, contains('onFocus'));
  });

  test('aucune reprise n’est lancée quand la PWA est masquée', () {
    expect(reconnectSource, contains('if (!isVisible()) return;'));
    expect(reconnectSource, contains('onPause?.call();'));
    expect(firestoreSource, contains('_reconnectDebounceTimer?.cancel();'));
  });

  test('les abonnements et les timers sont annulables', () {
    expect(reconnectSource, contains('static void detach()'));
    expect(reconnectSource, contains('_resumeDebounce?.cancel();'));
    expect(firestoreSource, contains('detachWebReconnectHandlers();'));
    expect(firestoreSource, contains('Duration(milliseconds: 750)'));
    expect(reconnectSource, contains('subscription.cancel()'));
    expect(reconnectSource, contains('_subscriptions.clear()'));
  });

  test('le cycle Flutter ne double pas la reprise Web', () {
    expect(
        mainSource, contains('state == AppLifecycleState.resumed && !kIsWeb'));
    expect(mainSource, isNot(contains('Reconnect Firestore error:')));
  });
}
