import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';

class UpdateService {
  static const String _repo = 'Bubakr75/Sks-familly';
  static const String _apiUrl = 'https://api.github.com/repos/$_repo/releases/latest';

  static Future<void> checkForUpdate(BuildContext context) async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;

      final response = await http.get(
        Uri.parse(_apiUrl),
        headers: {'Accept': 'application/vnd.github.v3+json'},
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) return;

      final data = jsonDecode(response.body);
      final latestTag = (data['tag_name'] as String?)?.replaceFirst('v', '') ?? '';

      if (latestTag.isEmpty || latestTag == currentVersion) return;

      if (!_isNewer(latestTag, currentVersion)) return;

      final assets = data['assets'] as List<dynamic>? ?? [];
      String? apkUrl;
      for (final asset in assets) {
        final name = asset['name'] as String? ?? '';
        if (name.endsWith('.apk')) {
          apkUrl = asset['browser_download_url'] as String?;
          break;
        }
      }

      if (apkUrl == null || !context.mounted) return;

      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: const Color(0xFF1A1A2E),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.system_update, color: Color(0xFF7C4DFF)),
              SizedBox(width: 10),
              Text('Mise a jour', style: TextStyle(color: Colors.white)),
            ],
          ),
          content: Text(
            'Une nouvelle version ($latestTag) est disponible.\n\nVersion actuelle : $currentVersion\n\nVoulez-vous telecharger la mise a jour ?',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.8)),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Plus tard', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF7C4DFF)),
              onPressed: () {
                Navigator.pop(ctx);
                _downloadAndInstall(context, apkUrl!);
              },
              child: const Text('Telecharger', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
    } catch (_) {}
  }

  static bool _isNewer(String latest, String current) {
    final latestParts = latest.split('.').map(int.tryParse).toList();
    final currentParts = current.split('.').map(int.tryParse).toList();
    for (var i = 0; i < 3; i++) {
      final l = (i < latestParts.length ? latestParts[i] : 0) ?? 0;
      final c = (i < currentParts.length ? currentParts[i] : 0) ?? 0;
      if (l > c) return true;
      if (l < c) return false;
    }
    return false;
  }

  static Future<void> _downloadAndInstall(BuildContext context, String url) async {
    final messenger = ScaffoldMessenger.of(context);

    messenger.showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
            SizedBox(width: 12),
            Text('Telechargement en cours...'),
          ],
        ),
        duration: Duration(minutes: 5),
        backgroundColor: Color(0xFF7C4DFF),
      ),
    );

    try {
      final response = await http.get(Uri.parse(url)).timeout(const Duration(minutes: 5));

      if (response.statusCode != 200) {
        messenger.hideCurrentSnackBar();
        messenger.showSnackBar(
          const SnackBar(content: Text('Erreur de telechargement'), backgroundColor: Colors.red),
        );
        return;
      }

      final dir = await getExternalStorageDirectory();
      final file = File('${dir!.path}/family-score-update.apk');
      await file.writeAsBytes(response.bodyBytes);

      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        const SnackBar(content: Text('Telechargement termine ! Installation...'), backgroundColor: Colors.green),
      );

      await OpenFilex.open(file.path);
    } catch (e) {
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        SnackBar(content: Text('Erreur : $e'), backgroundColor: Colors.red),
      );
    }
  }
}
