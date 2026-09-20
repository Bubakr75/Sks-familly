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

  test('screen time purchase offers approval with or without timer', () {
    expect(inbox, contains("'Accepter')"));
    expect(inbox, contains("const Text('Accepter + chrono')"));
    expect(inbox, contains('await fp.approveRequest(r.id)'));
    expect(inbox, contains('fp.lastApprovedPurchaseMinutes'));
    expect(
        inbox,
        contains(
            'await fp.startScreenTimeSession(r.childId, confirmedMinutes)'));
    expect(inbox, contains('Le serveur n’a confirmé aucune minute.'));
  });

  test('the Android timer keeps an audible alarm channel', () {
    expect(notifications, contains("'sks_screen_timer_channel'"));
    expect(notifications, contains('AndroidNotificationCategory.alarm'));
    expect(notifications, contains('AudioAttributesUsage.alarm'));
    expect(notifications, contains('exactAllowWhileIdle'));
    expect(notifications, contains('inexactAllowWhileIdle'));
  });

  test('timer actions handle their alarms and visible errors', () {
    expect(provider, contains('NotificationService.scheduleScreenTimeEnd'));
    expect(provider, contains('NotificationService.cancelScreenTimeEnd'));
    expect(screen, contains('Future<void> _runTimerAction('));
    expect(screen, contains('await _runTimerAction('));
    expect(screen, contains('Erreur du chrono'));
  });

  test('server extended minutes reschedule a running timer', () {
    expect(provider, contains("operation: 'screen_extend'"));
    expect(provider, contains('updated.sessionRemaining'));
  });
}
