import 'package:flutter_test/flutter_test.dart';
import 'package:family_score/services/update_service.dart';

void main() {
  group('UpdateService.isNewerVersion', () {
    test('détecte un numéro de build supérieur', () {
      expect(
        UpdateService.isNewerVersion('4.8.0+500', '4.8.0+499'),
        isTrue,
      );
    });

    test('refuse un numéro de build identique', () {
      expect(
        UpdateService.isNewerVersion('4.8.0+499', '4.8.0+499'),
        isFalse,
      );
    });

    test('refuse un numéro de build inférieur', () {
      expect(
        UpdateService.isNewerVersion('4.8.0+498', '4.8.0+499'),
        isFalse,
      );
    });

    test('détecte une version métier supérieure', () {
      expect(
        UpdateService.isNewerVersion('4.9.0+1', '4.8.0+999'),
        isTrue,
      );
    });

    test('refuse une version métier inférieure', () {
      expect(
        UpdateService.isNewerVersion('4.7.9+999', '4.8.0+1'),
        isFalse,
      );
    });

    test('accepte un préfixe v', () {
      expect(
        UpdateService.isNewerVersion('v4.8.0+500', '4.8.0+499'),
        isTrue,
      );
    });

    test('gère une version sans numéro de build', () {
      expect(
        UpdateService.isNewerVersion('4.8.1', '4.8.0+999'),
        isTrue,
      );
    });
  });

  group('UpdateService.officialApkUrl', () {
    Map<String, dynamic> release({
      bool draft = false,
      bool prerelease = false,
      String tag = 'v4.8.0+500',
      String name = 'app-release.apk',
      String? url,
    }) {
      return {
        'draft': draft,
        'prerelease': prerelease,
        'tag_name': tag,
        'assets': [
          {
            'name': name,
            'browser_download_url': url ??
                'https://github.com/Bubakr75/Sks-familly/releases/download/$tag/$name',
          },
        ],
      };
    }

    test('accepte uniquement l APK officiel de la Release publiée', () {
      expect(UpdateService.officialApkUrl(release()), isNotNull);
    });

    test('refuse brouillons, préversions et URL externes', () {
      expect(UpdateService.officialApkUrl(release(draft: true)), isNull);
      expect(UpdateService.officialApkUrl(release(prerelease: true)), isNull);
      expect(
        UpdateService.officialApkUrl(
          release(url: 'https://example.com/app-release.apk'),
        ),
        isNull,
      );
    });

    test('refuse un nom ou un tag inattendu', () {
      expect(UpdateService.officialApkUrl(release(name: 'debug.apk')), isNull);
      expect(UpdateService.officialApkUrl(release(tag: 'latest')), isNull);
    });
  });
}
