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

  group('UpdateService.officialApkUrl', () {
    Map<String, dynamic> release({
      bool draft = false,
      bool prerelease = false,
      String tag = 'v4.8.0-build510',
      String name = 'SKS-Family-build-510.apk',
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
                'https://github.com/Bubakr75/Sks-familly/'
                    'releases/download/$tag/$name',
          },
        ],
      };
    }

    test('accepte l APK officiel du format build', () {
      expect(UpdateService.officialApkUrl(release()), isNotNull);
    });

    test('conserve la compatibilit? avec l ancien format', () {
      expect(
        UpdateService.officialApkUrl(
          release(
            tag: 'v4.8.0+510',
            name: 'app-release.apk',
          ),
        ),
        isNotNull,
      );
    });

    test('refuse brouillons, pr?versions et URL externes', () {
      expect(UpdateService.officialApkUrl(release(draft: true)), isNull);
      expect(
        UpdateService.officialApkUrl(release(prerelease: true)),
        isNull,
      );
      expect(
        UpdateService.officialApkUrl(
          release(url: 'https://example.com/SKS-Family-build-510.apk'),
        ),
        isNull,
      );
    });

    test('refuse un APK dont le build ne correspond pas au tag', () {
      expect(
        UpdateService.officialApkUrl(
          release(name: 'SKS-Family-build-509.apk'),
        ),
        isNull,
      );
      expect(
        UpdateService.officialApkUrl(release(tag: 'latest')),
        isNull,
      );
    });

    test('construit la mise ? jour affich?e sur l accueil', () {
      final update = UpdateService.parseAvailableUpdate(
        release(),
        '4.8.0+509',
      );

      expect(update, isNotNull);
      expect(update!.currentVersion, '4.8.0+509');
      expect(update.latestVersion, '4.8.0+510');
      expect(update.apkUrl, contains('/SKS-Family-build-510.apk'));

      expect(
        UpdateService.parseAvailableUpdate(release(), '4.8.0+510'),
        isNull,
      );
    });

    test('refuse un t?l?chargement externe avant tout appel r?seau', () async {
      expect(
        await UpdateService.downloadAndInstall(
          'https://example.com/SKS-Family-build-510.apk',
        ),
        UpdateInstallResult.invalidUrl,
      );
    });
  });
}
