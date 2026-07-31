import 'package:family_score/services/family_manager_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('valide un gestionnaire durable sans exposer son UID à l’écran', () {
    final member = FamilyManagerMember.fromMap({
      'memberId': 'firebase-member-id',
      'displayName': 'Parent',
      'role': 'manager',
      'durable': true,
    });

    expect(member.role, 'manager');
    expect(member.durable, isTrue);
    expect(member.displayName, 'Parent');
  });

  test('le code est absent pour un parent ordinaire', () {
    final access = FamilyAccessContext.fromMap({
      'familyId': 'family-1',
      'role': 'parent',
      'canManageCode': false,
      'code': null,
    });

    expect(access.canManageCode, isFalse);
    expect(access.code, isNull);
  });

  test('refuse une réponse qui expose un code à un rôle non autorisé', () {
    expect(
      () => FamilyAccessContext.fromMap({
        'familyId': 'family-1',
        'role': 'parent',
        'canManageCode': false,
        'code': 'ABCD12',
      }),
      throwsFormatException,
    );
  });
}
