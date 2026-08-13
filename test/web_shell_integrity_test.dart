import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String html;

  setUpAll(() {
    final bytes = File('web/index.html').readAsBytesSync();
    html = const Utf8Decoder(allowMalformed: false).convert(bytes);
  });

  test('index web est un document UTF-8 complet', () {
    expect(html.trimLeft().startsWith('<!DOCTYPE html>'), isTrue);
    expect(html.trimRight().endsWith('</html>'), isTrue);
    expect(RegExp(r'<script(?:\s|>)').allMatches(html).length,
        RegExp(r'</script>').allMatches(html).length);
    expect(html, contains('</body>'));
  });

  test('index web ne contient aucun texte corrompu', () {
    for (final marker in ['Ã', 'Â', 'â€', 'ðŸ']) {
      expect(html, isNot(contains(marker)),
          reason: 'marqueur interdit: $marker');
    }
    expect(html, contains('récompenses'));
    expect(html, contains('écran d’accueil'));
  });

  test('aucun overlay HTML ne peut intercepter Flutter', () {
    expect(html, isNot(contains('id="intro-overlay"')));
    expect(html, isNot(contains('id="intro-video"')));
    expect(html, contains('#loading'));
    expect(html, contains('pointer-events: none'));
    expect(html, contains('flutter-first-frame'));
    expect(html, contains('removeLoading'));
  });

  test('notifications et PWA conservent des scopes séparés', () {
    expect(html, contains('firebase-messaging-sw.js'));
    expect(html, contains('/firebase-cloud-messaging-push-scope'));
    expect(html, contains('flutter_bootstrap.js'));
    expect(html, contains('manifest.json?v=3'));
  });

  test('la PWA iOS retire uniquement l’ancien cache Flutter', () {
    expect(html, contains('isIOS() && isStandalone()'));
    expect(html, contains('navigator.serviceWorker.getRegistrations()'));
    expect(html, contains('/firebase-cloud-messaging-push-scope'));
    expect(html, contains('registration.unregister()'));
  });
}
