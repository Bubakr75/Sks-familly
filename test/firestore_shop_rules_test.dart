import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Règles Firestore de la boutique', () {
    late String rules;

    setUpAll(() {
      rules = File('firestore.rules').readAsStringSync();
    });

    test('la collection rewards autorise les appareils authentifiés', () {
      expect(rules, contains('match /rewards/{rewardId}'));
      expect(
        RegExp(
          r'match /rewards/\{rewardId\}\s*\{'
          r'\s*allow read: if isSignedIn\(\);'
          r'\s*allow write: if isSignedIn\(\);',
        ).hasMatch(rules),
        isTrue,
      );
    });

    test('la collection purchases autorise les appareils authentifiés', () {
      expect(rules, contains('match /purchases/{purchaseId}'));
      expect(
        RegExp(
          r'match /purchases/\{purchaseId\}\s*\{'
          r'\s*allow read: if isSignedIn\(\);'
          r'\s*allow write: if isSignedIn\(\);',
        ).hasMatch(rules),
        isTrue,
      );
    });
  });
}
