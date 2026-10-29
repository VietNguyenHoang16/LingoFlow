import 'dart:js_interop';

import 'package:flutter/foundation.dart';

import 'tts_web_bridge.dart';

// Cau noi toi web/pwa.js — the <audio> duy nhat, khong qua AudioContext.
@JS('__tts.play')
external JSPromise<JSString> _jsPlay(JSString url);

@JS('__tts.unlock')
external JSPromise<JSString> _jsUnlock();

@JS('__tts.stop')
external void _jsStop();

@JS('__tts.resetSpeech')
external void _jsResetSpeech();

class _WebTtsBridge implements TtsWebBridge {
  @override
  Future<bool> unlock() async {
    try {
      final result = await _jsUnlock().toDart;
      return result.toDart == 'ok';
    } catch (e) {
      debugPrint('TtsWebBridge.unlock failed: $e');
      return false;
    }
  }

  @override
  Future<WebPlayOutcome> play(Uri uri) async {
    try {
      final result = (await _jsPlay(uri.toString().toJS).toDart).toDart;
      switch (result) {
        case 'played':
          return WebPlayOutcome.played;
        case 'blocked':
          return WebPlayOutcome.blocked;
        default:
          debugPrint('TtsWebBridge.play result: $result');
          return WebPlayOutcome.failed;
      }
    } catch (e) {
      debugPrint('TtsWebBridge.play failed: $e');
      return WebPlayOutcome.failed;
    }
  }

  @override
  Future<void> stop() async {
    try {
      _jsStop();
    } catch (e) {
      debugPrint('TtsWebBridge.stop failed: $e');
    }
  }

  @override
  void resetSpeechSynthesis() {
    try {
      _jsResetSpeech();
    } catch (e) {
      debugPrint('TtsWebBridge.resetSpeech failed: $e');
    }
  }
}

TtsWebBridge createTtsWebBridge() => _WebTtsBridge();
