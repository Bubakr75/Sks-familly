import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// Affiche la version réellement installée, sans numéro recopié à la main.
class AppVersionLabel extends StatefulWidget {
  const AppVersionLabel({super.key});

  @override
  State<AppVersionLabel> createState() => _AppVersionLabelState();
}

class _AppVersionLabelState extends State<AppVersionLabel> {
  late final Future<PackageInfo> _info = PackageInfo.fromPlatform();

  @override
  Widget build(BuildContext context) => FutureBuilder<PackageInfo>(
        future: _info,
        builder: (context, snapshot) => Text(
          snapshot.hasData
              ? 'v${snapshot.data!.version} (${snapshot.data!.buildNumber})'
              : 'SKS Family',
          style: TextStyle(
              color: Colors.white.withValues(alpha: 0.2), fontSize: 12),
        ),
      );
}
