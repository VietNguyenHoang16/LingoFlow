import 'package:flutter/foundation.dart';

import 'tts_web_bridge.dart';

/// Trang thai audio doc cua app tren web.
///
/// Van de tren iPad Safari: khi app xuong nen, iOS suspend audio; quay lai thi
/// the <audio> / AudioContext khong duoc phep phat tu dong nua cho den khi co
/// mot cu cham that (user gesture). Lop nay giu co [needsUnlock] de biet luc
/// nao can unlock lai truoc khi phat.
class TtsWebAudio {
  TtsWebAudio({TtsWebBridge? bridge, bool? isWeb})
      : _bridge = bridge ?? createTtsWebBridge(),
        _isWeb = isWeb ?? kIsWeb;

  /// Instance dung chung cho toan app (GoogleVoiceService + widget unlock).
  static final TtsWebAudio instance = TtsWebAudio();

  final TtsWebBridge _bridge;
  final bool _isWeb;

  bool _needsUnlock = true;

  bool get isWeb => _isWeb;
  bool get needsUnlock => _needsUnlock;

  /// Goi ben trong pointer-down (user gesture). iOS chi cho audio phat lai
  /// sau khi the <audio> duoc phat boi mot cu cham that.
  Future<void> ensureUnlocked() async {
    if (!_isWeb || !_needsUnlock) return;
    final ok = await _bridge.unlock();
    if (ok) _needsUnlock = false;
  }

  /// Phat audio doc. Tren native tra ve [WebPlayOutcome.failed] de lop tren
  /// tu fallback sang audioplayers.
  Future<WebPlayOutcome> play(Uri uri) async {
    if (!_isWeb) return WebPlayOutcome.failed;
    final outcome = await _bridge.play(uri);
    if (outcome == WebPlayOutcome.played) {
      _needsUnlock = false;
    } else if (outcome == WebPlayOutcome.blocked) {
      // Autoplay bi chan -> cu cham ke tiep se unlock lai.
      _needsUnlock = true;
    }
    return outcome;
  }

  Future<void> stop() => _bridge.stop();

  /// App quay lai foreground: iOS da suspend audio, can unlock lai; dong thoi
  /// don speechSynthesis dang treo de lan doc sau khong im lang.
  void onAppResumed() {
    _needsUnlock = true;
    _bridge.resetSpeechSynthesis();
  }

  /// Goi truoc moi lan doc tren web: iOS hay de speechSynthesis o trang thai
  /// paused sau khi xuong nen.
  void prepareForSpeech() {
    if (!_isWeb) return;
    _bridge.resetSpeechSynthesis();
  }
}
