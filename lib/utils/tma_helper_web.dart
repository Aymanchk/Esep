import 'dart:js_interop';

@JS('Telegram')
external _Telegram get _telegram;

@JS()
@anonymous
extension type _Telegram(JSObject _) implements JSObject {
  @JS('WebApp')
  external _WebApp get webApp;
}

@JS()
@anonymous
extension type _WebApp(JSObject _) implements JSObject {
  external String? get initData;
}

String? getTmaInitData() {
  try {
    return _telegram.webApp.initData;
  } catch (_) {
    return null;
  }
}
