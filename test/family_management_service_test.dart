import 'package:family_score/services/family_management_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FamilyCreationResult', () {
    test('parse une création valide', () {
      final result = FamilyCreationResult.fromData({
        'familyId': 'family-1',
        'code': 'abcd12',
        'alreadyCreated': false,
      });

      expect(result.familyId, 'family-1');
      expect(result.code, 'ABCD12');
      expect(result.alreadyCreated, isFalse);
    });

    test('parse une création idempotente', () {
      final result = FamilyCreationResult.fromData({
        'familyId': 'family-1',
        'code': 'ABCD12',
        'alreadyCreated': true,
      });

      expect(result.alreadyCreated, isTrue);
    });

    test('refuse une réponse de création invalide', () {
      expect(
        () => FamilyCreationResult.fromData({
          'familyId': 'family/bad',
          'code': 'ABCD12',
          'alreadyCreated': false,
        }),
        throwsFormatException,
      );

      expect(
        () => FamilyCreationResult.fromData({
          'familyId': 'family-1',
          'code': 'bad',
          'alreadyCreated': false,
        }),
        throwsFormatException,
      );
    });
  });

  group('FamilyCodeChangeResult', () {
    test('parse un changement valide', () {
      final result = FamilyCodeChangeResult.fromData({
        'familyId': 'family-1',
        'code': 'new123',
        'unchanged': false,
      });

      expect(result.familyId, 'family-1');
      expect(result.code, 'NEW123');
      expect(result.unchanged, isFalse);
    });

    test('parse un code inchangé', () {
      final result = FamilyCodeChangeResult.fromData({
        'familyId': 'family-1',
        'code': 'ABCD12',
        'unchanged': true,
      });

      expect(result.unchanged, isTrue);
    });

    test('refuse un booléen absent', () {
      expect(
        () => FamilyCodeChangeResult.fromData({
          'familyId': 'family-1',
          'code': 'ABCD12',
        }),
        throwsFormatException,
      );
    });
  });
}
