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

    test(
        'les récompenses sont écrites par un parent et les achats par le serveur',
        () {
      final rewardsBlock = RegExp(
        r'match /rewards/\{rewardId\}\s*\{([\s\S]*?)\n\s*\}',
      ).firstMatch(rules)?.group(1);
      final purchasesBlock = RegExp(
        r'match /purchases/\{purchaseId\}\s*\{([\s\S]*?)\n\s*\}',
      ).firstMatch(rules)?.group(1);

      expect(rewardsBlock, isNotNull);
      expect(rewardsBlock, contains('activeFamilyMember(familyId)'));
      expect(rewardsBlock, contains('isFamilyParent(familyId)'));
      expect(purchasesBlock, isNotNull);
      expect(purchasesBlock, contains('allow write: if false'));
      expect(purchasesBlock, contains('activeFamilyMember(familyId)'));
    });
  });
}
