import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:family_score/services/update_service.dart';

void main() {
  group('UpdateService.isNewerVersion', () {
    test('d?tecte un num?ro de build sup?rieur', () {
      expect(
        UpdateService.isNewerVersion('4.8.0+510', '4.8.0+509'),
        isTrue,
      );
    });

    test('comprend le format GitHub build', () {
      expect(
        UpdateService.isNewerVersion('v4.8.0-build510', '4.8.0+509'),
        isTrue,
      );
    });

    test('refuse un num?ro identique ou inf?rieur', () {
      expect(
        UpdateService.isNewerVersion('4.8.0+509', '4.8.0+509'),
        isFalse,
      );
      expect(
        UpdateService.isNewerVersion('4.8.0+508', '4.8.0+509'),
        isFalse,
      );
    });

    test('compare d?abord la version m?tier', () {
      expect(
        UpdateService.isNewerVersion('4.9.0+1', '4.8.0+999'),
        isTrue,
      );
      expect(
        UpdateService.isNewerVersion('4.7.9+999', '4.8.0+1'),
        isFalse,
      );
    });
  });

  test('le service ne télécharge plus directement un APK', () {
    final source = File('lib/services/update_service.dart').readAsStringSync();
    expect(source, isNot(contains('downloadAndInstall')));
  });

  test('le service ne consulte plus les APK des releases GitHub', () {
    final source = File('lib/services/update_service.dart').readAsStringSync();
    expect(source, isNot(contains('browser_download_url')));
  });

  test('l accueil n affiche plus de bannière d installation externe', () {
    final home = File('lib/screens/home_screen.dart').readAsStringSync();
    expect(home, isNot(contains('UpdateBanner')));
  });

  test('le manifeste interdit l installation directe d APK', () {
    final manifest =
        File('android/app/src/main/AndroidManifest.xml').readAsStringSync();
    expect(manifest, isNot(contains('REQUEST_INSTALL_PACKAGES')));
  });

  test('open_filex n est plus une dépendance directe', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    expect(pubspec, isNot(contains('open_filex:')));
  });

  test('le widget d installation externe a été supprimé', () {
    expect(File('lib/widgets/update_banner.dart').existsSync(), isFalse);
  });
}
