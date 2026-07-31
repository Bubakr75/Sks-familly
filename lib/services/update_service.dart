import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

class AvailableUpdate {
  final String currentVersion;
  final String latestVersion;
  final String apkUrl;

  const AvailableUpdate({
    required this.currentVersion,
    required this.latestVersion,
    required this.apkUrl,
  });
}

enum UpdateInstallResult {
  launched,
  invalidUrl,
  downloadFailed,
  fileTooLarge,
  storageUnavailable,
  openFailed,
}

class UpdateService {
  static const String _repo = 'Bubakr75/Sks-familly';
  static const String officialApkName = 'app-release.apk';
  static const String _apiUrl =
      'https://api.github.com/repos/$_repo/releases/latest';
  static const int maxApkBytes = 250 * 1024 * 1024;

  static String? officialApkUrl(Map<String, dynamic> release) {
    if (release['draft'] == true || release['prerelease'] == true) return null;
    final tag = release['tag_name'] as String?;
    if (tag == null || !RegExp(r'^v\d+\.\d+\.\d+\+\d+$').hasMatch(tag)) {
      return null;
    }

    final assets = release['assets'];
    if (assets is! List) return null;
    for (final value in assets) {
      if (value is! Map) continue;
      final name = value['name'];
      final url = value['browser_download_url'];
      if (name != officialApkName || url is! String) continue;
      final uri = Uri.tryParse(url);
      if (uri == null ||
          uri.scheme != 'https' ||
          uri.host != 'github.com' ||
          uri.query.isNotEmpty ||
          uri.fragment.isNotEmpty) {
        continue;
      }
      final expectedPath = '/$_repo/releases/download/$tag/$officialApkName';
      if (Uri.decodeComponent(uri.path) == expectedPath) return url;
    }
    return null;
  }

  static AvailableUpdate? parseAvailableUpdate(
    Map<String, dynamic> release,
    String currentVersion,
  ) {
    final tag = release['tag_name'];
    if (tag is! String) return null;
    final latestVersion = tag.replaceFirst(RegExp(r'^v'), '');
    final apkUrl = officialApkUrl(release);
    if (apkUrl == null || !isNewerVersion(latestVersion, currentVersion)) {
      return null;
    }
    return AvailableUpdate(
      currentVersion: currentVersion,
      latestVersion: latestVersion,
      apkUrl: apkUrl,
    );
  }

  static Future<AvailableUpdate?> findAvailableUpdate(
    String currentVersion, {
    http.Client? client,
  }) async {
    final uri = Uri.parse(_apiUrl);
    final response = client == null
        ? await http.get(
            uri,
            headers: const {'Accept': 'application/vnd.github.v3+json'},
          ).timeout(const Duration(seconds: 10))
        : await client.get(
            uri,
            headers: const {'Accept': 'application/vnd.github.v3+json'},
          ).timeout(const Duration(seconds: 10));
    if (response.statusCode != 200) return null;
    final decoded = jsonDecode(response.body);
    if (decoded is! Map) return null;
    return parseAvailableUpdate(
      Map<String, dynamic>.from(decoded),
      currentVersion,
    );
  }

  static Future<UpdateInstallResult> downloadAndInstall(
    String url, {
    http.Client? client,
  }) async {
    if (!_isOfficialDownloadUrl(url)) {
      return UpdateInstallResult.invalidUrl;
    }
    try {
      final uri = Uri.parse(url);
      final response = client == null
          ? await http.get(uri).timeout(const Duration(minutes: 5))
          : await client.get(uri).timeout(const Duration(minutes: 5));
      if (response.statusCode != 200) {
        return UpdateInstallResult.downloadFailed;
      }
      final announcedSize = int.tryParse(
        response.headers['content-length'] ?? '',
      );
      if ((announcedSize != null && announcedSize > maxApkBytes) ||
          response.bodyBytes.length > maxApkBytes) {
        return UpdateInstallResult.fileTooLarge;
      }

      final directory = await getExternalStorageDirectory();
      if (directory == null) {
        return UpdateInstallResult.storageUnavailable;
      }
      final file = File(
        '${directory.path}/com.bubakr.sks_family-update.apk',
      );
      await file.writeAsBytes(response.bodyBytes, flush: true);
      final openResult = await OpenFilex.open(file.path);
      return openResult.type == ResultType.done
          ? UpdateInstallResult.launched
          : UpdateInstallResult.openFailed;
    } catch (_) {
      return UpdateInstallResult.downloadFailed;
    }
  }

  static bool _isOfficialDownloadUrl(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.host != 'github.com' ||
        uri.query.isNotEmpty ||
        uri.fragment.isNotEmpty) {
      return false;
    }
    return RegExp(
      r'^/Bubakr75/Sks-familly/releases/download/'
      r'v\d+\.\d+\.\d+\+\d+/app-release\.apk$',
    ).hasMatch(Uri.decodeComponent(uri.path));
  }

  static bool isNewerVersion(String latest, String current) {
    final latestVersion = _parseVersion(latest);
    final currentVersion = _parseVersion(current);

    for (var i = 0; i < 3; i++) {
      final latestPart = latestVersion.$1[i];
      final currentPart = currentVersion.$1[i];

      if (latestPart > currentPart) return true;
      if (latestPart < currentPart) return false;
    }

    return latestVersion.$2 > currentVersion.$2;
  }

  static (List<int>, int) _parseVersion(String value) {
    final normalized = value.trim().replaceFirst(RegExp(r'^v'), '');
    final sections = normalized.split('+');

    final versionParts = sections.first
        .split('.')
        .map((part) => int.tryParse(part) ?? 0)
        .toList();

    while (versionParts.length < 3) {
      versionParts.add(0);
    }

    final buildNumber =
        sections.length > 1 ? int.tryParse(sections[1]) ?? 0 : 0;

    return (versionParts.take(3).toList(), buildNumber);
  }
}
