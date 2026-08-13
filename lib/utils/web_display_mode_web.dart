// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;

class WebDisplayMode {
  static bool get isIosStandalonePwa {
    final userAgent = html.window.navigator.userAgent.toLowerCase();
    final isIos = userAgent.contains('iphone') ||
        userAgent.contains('ipad') ||
        userAgent.contains('ipod');
    final standaloneMedia =
        html.window.matchMedia('(display-mode: standalone)').matches;
    final legacyStandalone = _readStandalone(html.window.navigator) == true;
    return isIos && (standaloneMedia || legacyStandalone);
  }

  static bool? _readStandalone(Object navigator) {
    try {
      return (navigator as dynamic).standalone as bool?;
    } catch (_) {
      return null;
    }
  }
}
