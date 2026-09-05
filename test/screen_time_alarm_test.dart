import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final inbox =
      File('lib/screens/pending_requests_screen.dart').readAsStringSync();
  final notifications =
      File('lib/services/notification_service.dart').readAsStringSync();
  final provider =
      File('lib/providers/family_provider.dart').readAsStringSync();

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
}
