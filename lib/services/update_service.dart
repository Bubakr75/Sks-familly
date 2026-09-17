class UpdateService {
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
    final normalized =
        value.trim().replaceFirst(RegExp(r'^v'), '').replaceFirstMapped(
              RegExp(r'-build(\d+)$'),
              (match) => '+${match.group(1)}',
            );

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
