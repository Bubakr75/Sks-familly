import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'le mode iOS installé est détecté sans affecter les autres plateformes',
    () {
      final web =
          File('lib/utils/web_display_mode_web.dart').readAsStringSync();
      final stub =
          File('lib/utils/web_display_mode_stub.dart').readAsStringSync();
      expect(web, contains("matchMedia('(display-mode: standalone)')"));
      expect(web, contains("userAgent.contains('iphone')"));
      expect(stub, contains('isIosStandalonePwa => false'));
    },
  );

  test('les animations permanentes sont réduites dans la PWA iPhone', () {
    final welcome = File('lib/screens/welcome_screen.dart').readAsStringSync();
    expect(welcome, contains('final reducePwaMotion = isIosStandalonePwa'));
    expect(welcome, contains('if (!reducePwaMotion) _pulseController.repeat'));
    expect(
      welcome,
      contains('if (!reducePwaMotion) _particleController.repeat'),
    );
  });
}
