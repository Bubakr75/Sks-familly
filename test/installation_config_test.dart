import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('le manifeste PWA est installable et limité à sa portée', () {
    final manifest = jsonDecode(
      File('web/manifest.json').readAsStringSync(),
    ) as Map<String, dynamic>;

    expect(manifest['name'], 'SKS Family');
    expect(manifest['id'], '/');
    expect(manifest['start_url'], '/');
    expect(manifest['scope'], '/');
    expect(manifest['display'], 'standalone');
    expect(manifest['prefer_related_applications'], isFalse);
    expect((manifest['icons'] as List).length, greaterThanOrEqualTo(4));
  });

  test('le navigateur peut réellement déclencher l’installation PWA', () {
    final index = File('web/index.html').readAsStringSync();

    expect(index, contains("addEventListener('beforeinstallprompt'"));
    expect(index, contains('await deferredPrompt.prompt()'));
    expect(index, contains("addEventListener('appinstalled'"));
    expect(index, contains('pwa-install-button'));
    expect(
      index,
      contains("scope: '/firebase-cloud-messaging-push-scope'"),
    );
  });

  test('Android autorise les mises à jour sans permissions stockage obsolètes',
      () {
    final manifest =
        File('android/app/src/main/AndroidManifest.xml').readAsStringSync();

    expect(manifest, contains('android.permission.REQUEST_INSTALL_PACKAGES'));
    expect(manifest, isNot(contains('READ_EXTERNAL_STORAGE')));
    expect(manifest, isNot(contains('WRITE_EXTERNAL_STORAGE')));
    expect(manifest, contains('android:allowBackup="false"'));
  });
}
