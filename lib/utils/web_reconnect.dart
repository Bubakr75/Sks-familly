// Web Reconnect Helper
import 'web_reconnect_factory.dart';

void attachWebReconnectHandlers(
  void Function() reconnectFn, {
  void Function()? pauseFn,
}) {
  WebReconnectFactory.attach(reconnectFn, pauseFn: pauseFn);
}

void detachWebReconnectHandlers() {
  WebReconnectFactory.detach();
}
