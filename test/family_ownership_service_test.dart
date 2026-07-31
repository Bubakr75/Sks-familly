import 'package:family_score/services/family_ownership_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('valide un transfert confirmé et idempotent', () {
    final result = FamilyOwnershipResult.fromMap({
      'familyId': 'family-1',
      'status': 'completed',
      'idempotent': true,
    });
    expect(result.familyId, 'family-1');
    expect(result.idempotent, isTrue);
  });

  test('refuse une réponse de transfert incomplète', () {
    expect(
      () => FamilyOwnershipResult.fromMap({
        'familyId': 'family-1',
        'status': 'pending',
        'idempotent': false,
      }),
      throwsFormatException,
    );
  });

  test('accepte seulement un code de récupération fort et borné', () {
    final receipt = FamilyRecoveryCodeReceipt.fromMap({
      'familyId': 'family-1',
      'recoveryCode': 'A' * 44,
      'expiresInDays': 90,
    });
    expect(receipt.code.length, 44);
    expect(
      () => FamilyRecoveryCodeReceipt.fromMap({
        'familyId': 'family-1',
        'recoveryCode': 'court',
        'expiresInDays': 90,
      }),
      throwsFormatException,
    );
  });
}
