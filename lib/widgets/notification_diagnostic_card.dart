import 'package:flutter/material.dart';
import '../config/emerald_theme.dart';
import '../services/fcm_service.dart';
import '../services/notification_diagnostic.dart';

class NotificationDiagnosticCard extends StatefulWidget {
  const NotificationDiagnosticCard({super.key});
  @override
  State<NotificationDiagnosticCard> createState() =>
      _NotificationDiagnosticCardState();
}

class _NotificationDiagnosticCardState
    extends State<NotificationDiagnosticCard> {
  bool _busy = false;
  NotificationDiagnosticResult? _result;

  Future<void> _check({bool repair = false}) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _result = null;
    });
    try {
      final result = await FcmService().diagnoseNotifications(repair: repair);
      if (mounted) setState(() => _result = result);
    } catch (_) {
      if (mounted) {
        setState(() => _result = const NotificationDiagnosticResult(
            'service-indisponible',
            'Le service est indisponible. Rouvre l’application puis réessaie.'));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => EmeraldCard(
          child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Notifications',
              style: TextStyle(
                  color: EmeraldPalette.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          const Text(
              'Vérifier pourquoi une alerte n’arrive pas sur cet appareil.',
              style: TextStyle(color: EmeraldPalette.textSecondary)),
          const SizedBox(height: 12),
          OutlinedButton.icon(
              onPressed: _busy ? null : () => _check(),
              icon: const Icon(Icons.notifications_outlined),
              label: const Text('Vérifier les notifications')),
          TextButton.icon(
              onPressed: _busy ? null : () => _check(repair: true),
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Réenregistrer ce téléphone')),
          if (_busy)
            const Padding(
                padding: EdgeInsets.only(top: 8),
                child: LinearProgressIndicator()),
          if (_result != null) ...[
            const SizedBox(height: 10),
            Semantics(
                liveRegion: true,
                child: Text(_result!.message,
                    style: const TextStyle(color: EmeraldPalette.textPrimary))),
            const SizedBox(height: 6),
            SelectableText('Code à communiquer : ${_result!.code}',
                style: const TextStyle(
                    color: EmeraldPalette.textSecondary, fontSize: 12)),
          ],
        ],
      ));
}
