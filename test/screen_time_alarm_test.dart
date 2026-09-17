import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final inbox =
      File('lib/screens/pending_requests_screen.dart').readAsStringSync();
  final notifications =
      File('lib/services/notification_service.dart').readAsStringSync();
  final provider =
      File('lib/providers/family_provider.dart').readAsStringSync();
  final screen =
      File('lib/screens/screen_time_new_screen.dart').readAsStringSync();

  test('le temps écran peut être accepté avec ou sans chrono', () {
    expect(inbox, contains("const Text('Accepter')"));
    expect(inbox, contains("const Text('Accepter + chrono')"));
    expect(inbox, contains('await fp.approveRequest(r.id)'));
    expect(
        inbox, contains('await fp.startScreenTimeSession(r.childId, minutes)'));
  });

  test('la fin du chrono programme une alarme Android audible', () {
    expect(notifications, contains("'sks_screen_timer_channel'"));
    expect(notifications, contains('AndroidNotificationCategory.alarm'));
    expect(notifications, contains('AudioAttributesUsage.alarm'));
    expect(notifications, contains('exactAllowWhileIdle'));
    expect(notifications, contains('inexactAllowWhileIdle'));
  });

  test('démarrer et arrêter une session gèrent son alarme', () {
    expect(provider, contains('NotificationService.scheduleScreenTimeEnd'));
    expect(provider, contains('NotificationService.cancelScreenTimeEnd'));
  });

  test(
      'tous les boutons du chrono attendent le résultat et signalent les erreurs',
      () {
    expect(screen, contains('Future<void> _runTimerAction('));
    expect(screen, contains('await _runTimerAction('));
    expect(screen, contains('Erreur du chrono'));
  });

  test('une prolongation reprogramme la sonnerie', () {
    expect(provider, contains('final wasRunning = account.isRunning'));
    expect(provider, contains('minutes: account.sessionRemaining'));
  });
}
