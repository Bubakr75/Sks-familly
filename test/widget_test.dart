// Test minimal d'instantiation pour SKS Family.
//
// On vérifie uniquement que SKSFamilyApp peut être instancié avec son
// paramètre obligatoire showOnboarding, sans initialiser Firebase, Hive
// ou les notifications (qui nécessiteraient des mocks complexes).

import 'package:flutter_test/flutter_test.dart';

import 'package:family_score/main.dart';

void main() {
  test('SKSFamilyApp peut être instancié avec showOnboarding=true', () {
    const app = SKSFamilyApp(showOnboarding: true);
    expect(app.showOnboarding, isTrue);
    expect(app, isA<SKSFamilyApp>());
  });

  test('SKSFamilyApp peut être instancié avec showOnboarding=false', () {
    const app = SKSFamilyApp(showOnboarding: false);
    expect(app.showOnboarding, isFalse);
    expect(app, isA<SKSFamilyApp>());
  });
}
