import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Configuration des règles Firestore de la boutique', () {
    late String rules;

    setUpAll(() {
      rules = File('firestore.rules').readAsStringSync();
    });

    test('rewards et purchases ont des règles dédiées', () {
      expect(rules, contains('match /rewards/{rewardId}'));
      expect(rules, contains('match /purchases/{purchaseId}'));
    });

    test('les écritures boutique exigent le rôle parent', () {
      final rewardsBlock = RegExp(
        r'match /rewards/\{rewardId\}\s*\{([\s\S]*?)\n\s*\}',
      ).firstMatch(rules)?.group(1);
      final purchasesBlock = RegExp(
        r'match /purchases/\{purchaseId\}\s*\{([\s\S]*?)\n\s*\}',
      ).firstMatch(rules)?.group(1);

      for (final block in [rewardsBlock, purchasesBlock]) {
        expect(block, isNotNull);
        expect(block, contains('activeFamilyMember(familyId)'));
        expect(block, contains('isFamilyParent(familyId)'));
        expect(block, isNot(contains('allow write: if isSignedIn()')));
      }
    });
  });
}
