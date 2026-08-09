import 'package:family_score/services/auth_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('une famille liée interdit la création silencieuse d’un nouvel UID', () {
    expect(
      AuthService.canCreateAnonymousAccount(
        hasCurrentUser: false,
        hasLinkedFamily: true,
      ),
      isFalse,
    );
  });
  test('identifie un compte anonyme comme temporaire', () {
    final status = FirebaseAccountStatus.fromValues(
      authenticated: true,
      anonymous: true,
      providerIds: const ['anonymous'],
      emailVerified: false,
    );

    expect(status.kind, FirebaseAccountKind.temporary);
    expect(status.provider, 'anonymous');
    expect(status.emailVerified, isFalse);
  });

  test('identifie email/mot de passe comme durable', () {
    final status = FirebaseAccountStatus.fromValues(
      authenticated: true,
      anonymous: false,
      providerIds: const ['password'],
      emailVerified: true,
      email: 'parent@example.test',
    );

    expect(status.kind, FirebaseAccountKind.durable);
    expect(status.provider, 'email-password');
    expect(status.emailVerified, isTrue);
    expect(status.maskedEmail, 'p***@example.test');
  });

  test('ne révèle jamais une adresse complète dans le statut', () {
    expect(
      FirebaseAccountStatus.maskEmail('ab@example.test'),
      'a***@example.test',
    );
    expect(
      FirebaseAccountStatus.maskEmail('invalid'),
      isNull,
    );
  });
}
