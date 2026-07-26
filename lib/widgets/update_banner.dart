// lib/widgets/update_banner.dart
//
// Bannière de mise à jour affichée sur l'accueil Android uniquement.
// Vérifie la version GitHub et propose le téléchargement + installation.

import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../services/update_service.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';

class UpdateBanner extends StatefulWidget {
  const UpdateBanner({super.key});

  @override
  State<UpdateBanner> createState() => _UpdateBannerState();
}

class _UpdateBannerState extends State<UpdateBanner> {
  String? _currentVersion;
  String? _latestVersion;
  String? _apkUrl;
  bool _checking = true;
  bool _downloading = false;

  @override
  void initState() {
    super.initState();
    _checkUpdate();
  }

  Future<void> _checkUpdate() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final current = packageInfo.buildNumber.isEmpty
          ? packageInfo.version
          : '${packageInfo.version}+${packageInfo.buildNumber}';

      final response = await http.get(
        Uri.parse(
            'https://api.github.com/repos/Bubakr75/Sks-familly/releases/latest'),
        headers: {'Accept': 'application/vnd.github.v3+json'},
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        if (mounted) setState(() => _checking = false);
        return;
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final tag = (data['tag_name'] as String?).toString();
      final latest = tag.replaceFirst('v', '');

      String? apkUrl;
      final assets = data['assets'] as List?;
      if (assets != null) {
        for (final asset in assets) {
          final name = asset['name'] as String?;
          if (name != null && name.endsWith('.apk')) {
            apkUrl = asset['browser_download_url'] as String?;
            break;
          }
        }
      }

      final hasUpdate =
          UpdateService.isNewerVersion(latest, current) && apkUrl != null;

      if (mounted) {
        setState(() {
          _currentVersion = current;
          _latestVersion = hasUpdate ? latest : null;
          _apkUrl = apkUrl;
          _checking = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _checking = false);
    }
  }

  Future<void> _downloadAndInstall() async {
    if (_apkUrl == null || _downloading) return;
    setState(() => _downloading = true);
    HapticFeedback.mediumImpact();

    final messenger = ScaffoldMessenger.of(context);

    try {
      final response = await http.get(Uri.parse(_apkUrl!)).timeout(
            const Duration(minutes: 5),
          );

      if (response.statusCode != 200) {
        messenger.showSnackBar(const SnackBar(
          content: Text('Échec du téléchargement'),
          backgroundColor: Colors.redAccent,
        ));
        return;
      }

      final dir = await getExternalStorageDirectory();
      final file = File('${dir!.path}/com.bubakr.sks_family-update.apk');
      await file.writeAsBytes(response.bodyBytes);

      await OpenFilex.open(file.path);
    } catch (_) {
      messenger.showSnackBar(const SnackBar(
        content: Text('Erreur lors du téléchargement'),
        backgroundColor: Colors.redAccent,
      ));
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Masqué sur Web et iOS
    if (kIsWeb || !Platform.isAndroid) return const SizedBox.shrink();
    if (_checking || _latestVersion == null) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF7C4DFF), Color(0xFF5E35B1)],
        ),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF7C4DFF).withValues(alpha: 0.3),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.system_update_rounded,
              color: Colors.white, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Mise à jour disponible',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$_currentVersion → $_latestVersion',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.8),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          if (_downloading)
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          else
            GestureDetector(
              onTap: _downloadAndInstall,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text(
                  'Installer',
                  style: TextStyle(
                    color: Color(0xFF5E35B1),
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
