// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:async';

class WebReconnectFactory {
  static StreamSubscription? _visibilitySub;
  static StreamSubscription? _onlineSub;
  static StreamSubscription? _focusSub;

  static void attach(void Function() reconnectFn) {
    _visibilitySub ??= html.document.onVisibilityChange.listen((_) {
      if (html.document.visibilityState == 'visible') {
        reconnectFn();
      }
    });

    _onlineSub ??= html.window.onOnline.listen((_) {
      reconnectFn();
    });

    _focusSub ??= html.window.onFocus.listen((_) {
      reconnectFn();
    });
  }
}
