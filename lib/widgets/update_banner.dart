// lib/widgets/update_banner.dart
//
// Bannière de mise à jour affichée sur l'accueil Android uniquement.
// Vérifie la version GitHub et propose le téléchargement + installation.

import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../services/update_service.dart';

class UpdateBanner extends StatefulWidget {
  const UpdateBanner({super.key});

  @override
  State<UpdateBanner> createState() => _UpdateBannerState();
}

class _UpdateBannerState extends State<UpdateBanner> {
  AvailableUpdate? _update;
  bool _checking = true;
  bool _downloading = false;

  @override
  void initState() {
    super.initState();
    if (kIsWeb || !Platform.isAndroid) {
      _checking = false;
      return;
    }
    _checkUpdate();
  }

  Future<void> _checkUpdate() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final current = packageInfo.buildNumber.isEmpty
          ? packageInfo.version
          : '${packageInfo.version}+${packageInfo.buildNumber}';

      final update = await UpdateService.findAvailableUpdate(current);

      if (mounted) {
        setState(() {
          _update = update;
          _checking = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _checking = false);
    }
  }

  Future<void> _downloadAndInstall() async {
    final update = _update;
    if (update == null || _downloading) return;
    setState(() => _downloading = true);
    HapticFeedback.mediumImpact();

    final messenger = ScaffoldMessenger.of(context);

    try {
      final result = await UpdateService.downloadAndInstall(update.apkUrl);
      if (result != UpdateInstallResult.launched) {
        final message = switch (result) {
          UpdateInstallResult.invalidUrl => 'Lien de mise à jour refusé',
          UpdateInstallResult.fileTooLarge =>
            'Fichier de mise à jour trop lourd',
          UpdateInstallResult.storageUnavailable =>
            'Stockage Android indisponible',
          UpdateInstallResult.openFailed =>
            'Impossible d’ouvrir l’installateur Android',
          _ => 'Échec du téléchargement',
        };
        messenger.showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
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
    final update = _update;
    if (_checking || update == null) return const SizedBox.shrink();

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
                  '${update.currentVersion} → ${update.latestVersion}',
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
