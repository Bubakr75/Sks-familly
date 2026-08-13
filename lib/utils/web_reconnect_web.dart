// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:async';

class WebReconnectFactory {
  static StreamSubscription? _visibilitySub;
  static StreamSubscription? _onlineSub;
  static StreamSubscription? _focusSub;
  static Timer? _resumeDebounce;

  static void attach(
    void Function() reconnectFn, {
    void Function()? pauseFn,
  }) {
    detach();

    void scheduleResume() {
      if (html.document.visibilityState != 'visible') return;
      _resumeDebounce?.cancel();
      _resumeDebounce = Timer(const Duration(milliseconds: 700), reconnectFn);
    }

    _visibilitySub = html.document.onVisibilityChange.listen((_) {
      if (html.document.visibilityState == 'visible') {
        scheduleResume();
      } else {
        _resumeDebounce?.cancel();
        pauseFn?.call();
      }
    });

    _onlineSub = html.window.onOnline.listen((_) => scheduleResume());
    _focusSub = html.window.onFocus.listen((_) => scheduleResume());
  }

  static void detach() {
    _resumeDebounce?.cancel();
    _resumeDebounce = null;
    _visibilitySub?.cancel();
    _onlineSub?.cancel();
    _focusSub?.cancel();
    _visibilitySub = null;
    _onlineSub = null;
    _focusSub = null;
  }
}
