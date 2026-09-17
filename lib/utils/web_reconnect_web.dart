// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:js_interop';
import 'pwa_lifecycle.dart';

@JS('navigator.standalone')
external JSBoolean? get _navigatorStandalone;

class WebReconnectFactory {
  static PwaLifecycle? _lifecycle;

  static void attach(
    void Function() reconnectFn, {
    void Function()? pauseFn,
  }) {
    detach();

    _lifecycle = PwaLifecycle(
      isVisible: () => html.document.visibilityState == 'visible',
      standalone: isStandaloneMode(
        displayMode:
            html.window.matchMedia('(display-mode: standalone)').matches,
        navigatorFlag: _navigatorStandalone?.toDart == true,
      ),
      onResume: reconnectFn,
      onPause: pauseFn,
    )..attach([
        html.document.onVisibilityChange.map((_) =>
            html.document.visibilityState == 'visible'
                ? PwaEvent.visible
                : PwaEvent.hidden),
        html.window.onOnline.map((_) => PwaEvent.online),
        html.window.onFocus.map((_) => PwaEvent.focus),
        html.window.onPageShow.map((_) => PwaEvent.pageShow),
        html.window.onPageHide.map((_) => PwaEvent.pageHide),
      ]);
  }

  static void detach() {
    _lifecycle?.detach();
    _lifecycle = null;
  }
}
