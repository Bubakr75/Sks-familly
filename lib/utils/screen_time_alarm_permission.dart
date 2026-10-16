import 'package:flutter/material.dart';

import '../services/notification_service.dart';

/// Explique l'accès aux alarmes avant toute modification du chrono ou de l'achat.
Future<bool> prepareScreenTimeAlarm(
  BuildContext context, {
  Future<bool> Function()? canScheduleExactly,
  Future<bool> Function()? requestPermission,
}) async {
  final canSchedule =
      canScheduleExactly ?? NotificationService.canScheduleScreenTimeExactly;
  final request =
      requestPermission ?? NotificationService.requestScreenTimeAlarmPermission;
  if (await canSchedule()) return context.mounted;
  if (!context.mounted) return false;

  final choice = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Sonnerie de fin du chrono'),
      content: const Text(
        'Pour sonner à l’heure prévue lorsque le téléphone est en veille, '
        'SKS Family a besoin de l’accès aux alarmes et rappels Android. '
        'Les notifications doivent aussi être autorisées.\n\n'
        'Vous pouvez continuer sans cet accès, mais la sonnerie pourra être retardée.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: const Text('Continuer sans autoriser'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          child: const Text('Autoriser'),
        ),
      ],
    ),
  );
  // Retour ou fermeture : aucun achat validé ni chrono démarré.
  if (choice == null || !context.mounted) return false;
  if (choice) {
    final granted = await request();
    if (!context.mounted) return false;
    if (!granted) {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Sonnerie pouvant être retardée'),
          content: const Text(
            'L’accès aux alarmes précises n’est pas disponible. '
            'Le chrono peut démarrer, mais Android pourra retarder la sonnerie.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Compris'),
            ),
          ],
        ),
      );
    }
  }
  return context.mounted;
}
