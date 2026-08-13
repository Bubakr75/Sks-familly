import 'dart:io';

import 'package:family_score/services/firestore_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late String source;

  setUpAll(() {
    source = File('lib/services/firestore_service.dart').readAsStringSync();
  });

  test('historique temps réel est borné pour les grandes familles', () {
    expect(FirestoreService.historyRealtimeLimit, 500);
    expect(source, contains('.limit(historyRealtimeLimit)'));
    expect(source, contains(".orderBy('date', descending: true)"));
  });

  test('un démarrage de synchronisation remplace les anciens listeners', () {
    expect(source, contains('_stopListening(cancelReconnect: false);'));
    expect(source, isNot(contains('if (sec > 45) reconnect()')));
  });

  test('les listeners et timers sont annulés au changement de famille', () {
    const subscriptions = [
      'children',
      'history',
      'goals',
      'punishments',
      'notes',
      'immunities',
      'trades',
      'tribunal',
      'badges',
      'requests',
      'joinRequests',
      'screenTime',
      'parentProfiles',
      'chores',
      'rewards',
      'purchases',
      'wallets',
    ];
    for (final name in subscriptions) {
      expect(source, contains('_${name}Sub?.cancel();'), reason: name);
      expect(source, contains('_${name}Sub = null;'), reason: name);
    }
    expect(source, contains('_reconnectTimer?.cancel();'));
    expect(source, contains('_reconnectDebounceTimer?.cancel();'));
    expect(source, contains('_keepAliveTimer?.cancel();'));
  });

  test('une erreur simultanée ne programme qu’une reconnexion', () {
    expect(source, contains('_familyId == null || _reconnectTimer != null'));
    expect(source, contains('if (_familyId == familyAtFailure) reconnect();'));
  });
}
