// Stub for native platforms (no-op)
class WebReconnectFactory {
  static void attach(
    void Function() reconnectFn, {
    void Function()? pauseFn,
  }) {
    // No-op on native
  }

  static void detach() {}
}
