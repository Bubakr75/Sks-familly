import 'dart:async';

class NotificationDiagnosticResult {
  const NotificationDiagnosticResult(this.code, this.message,
      {this.registered = false});
  final String code;
  final String message;
  final bool registered;
}

/// Sépare les étapes pour ne jamais annoncer un enregistrement non confirmé.
class NotificationDiagnostic {
  NotificationDiagnostic(
      {required this.contextProblem,
      required this.permission,
      required this.token,
      required this.save,
      required this.errorCode,
      this.timeout = const Duration(seconds: 12)});
  final Future<String?> Function() contextProblem;
  final Future<bool> Function() permission;
  final Future<String?> Function() token;
  final Future<void> Function(String) save;
  final String Function(Object) errorCode;
  final Duration timeout;

  Future<NotificationDiagnosticResult> run({bool repair = false}) async {
    var stage = 'contexte';
    try {
      final problem = await contextProblem().timeout(timeout);
      if (problem != null) {
        return NotificationDiagnosticResult(
            problem,
            switch (problem) {
              'famille-absente' =>
                'Ce téléphone n’est pas rattaché à une famille.',
              'connexion-absente' =>
                'La connexion au compte familial est indisponible. Rouvre l’application puis réessaie.',
              'appareil-absent' =>
                'L’identifiant de ce téléphone est indisponible. Rouvre l’application puis réessaie.',
              'web-non-configure' =>
                'Les notifications Web ne sont pas configurées pour cette version.',
              _ => 'Le contexte de notification est indisponible.',
            });
      }
      stage = 'autorisation';
      if (!await permission().timeout(timeout)) {
        return const NotificationDiagnosticResult('notifications-refusees',
            'Les notifications sont désactivées. Autorise-les dans les paramètres du téléphone pour SKS Family.');
      }
      stage = 'adresse';
      final address = await token().timeout(timeout);
      if (address == null || address.isEmpty) {
        return const NotificationDiagnosticResult('adresse-absente',
            'Le téléphone ne fournit aucune adresse de notification. Vérifie Internet et les services Google Play.');
      }
      if (!repair) {
        return const NotificationDiagnosticResult('verification-locale-ok',
            'L’autorisation et l’adresse de notification sont disponibles. Appuie sur « Réenregistrer ce téléphone » pour vérifier son enregistrement auprès de la famille.');
      }
      stage = 'enregistrement';
      await save(address).timeout(timeout);
      return const NotificationDiagnosticResult('enregistrement-confirme',
          'Ce téléphone a été réenregistré avec succès. Renvoie maintenant la demande depuis l’iPhone pour tester la réception.',
          registered: true);
    } catch (error) {
      final code =
          error is TimeoutException ? 'delai-depasse' : errorCode(error);
      final message = stage == 'enregistrement' && code == 'permission-denied'
          ? 'Le serveur refuse l’enregistrement de ce téléphone pour cette famille. Le rattachement ou l’identité du compte doit être vérifié.'
          : stage == 'enregistrement'
              ? 'L’enregistrement n’a pas pu être confirmé. Vérifie Internet et réessaie.'
              : 'La vérification a échoué à l’étape « $stage ». Vérifie Internet et les services de notification du téléphone.';
      return NotificationDiagnosticResult('$stage/$code', message);
    }
  }
}
