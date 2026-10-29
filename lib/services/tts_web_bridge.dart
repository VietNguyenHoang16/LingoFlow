import 'tts_web_bridge_stub.dart'
    if (dart.library.js_interop) 'tts_web_bridge_web.dart' as impl;

/// Ket qua phat audio tren web.
enum WebPlayOutcome {
  /// Da bat dau phat.
  played,

  /// iOS/Safari chan autoplay: can mot cu cham (user gesture) de unlock.
  blocked,

  /// Loi khac: mang, proxy, dinh dang audio...
  failed,
}

/// Cau noi xuong lop web de phat audio doc (Google TTS proxy).
///
/// Tren native (Android/iOS) khong dung lop nay — van phat bang audioplayers.
abstract class TtsWebBridge {
  /// "Unlock" the <audio> trong user gesture. Tra true khi iOS da cho phep
  /// phat audio tu dong sau do.
  Future<bool> unlock();

  /// Phat [uri]; tra ve ket qua de lop tren biet co bi chan autoplay khong.
  Future<WebPlayOutcome> play(Uri uri);

  Future<void> stop();

  /// Don speechSynthesis (cancel + resume) khi iOS de no o trang thai treo.
  void resetSpeechSynthesis();
}

/// Platform-specific factory: ban web that, ban con lai la stub rong.
TtsWebBridge createTtsWebBridge() => impl.createTtsWebBridge();
