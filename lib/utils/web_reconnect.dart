// Web Reconnect Helper
import 'web_reconnect_factory.dart';

void attachWebReconnectHandlers(void Function() reconnectFn) {
  WebReconnectFactory.attach(reconnectFn);
}
