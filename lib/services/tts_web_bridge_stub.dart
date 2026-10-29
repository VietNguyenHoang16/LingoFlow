import 'tts_web_bridge.dart';

/// Ban native: khong co DOM/audio web nen moi thao tac la no-op.
class _StubTtsWebBridge implements TtsWebBridge {
  @override
  Future<bool> unlock() async => false;

  @override
  Future<WebPlayOutcome> play(Uri uri) async => WebPlayOutcome.failed;

  @override
  Future<void> stop() async {}

  @override
  void resetSpeechSynthesis() {}
}

TtsWebBridge createTtsWebBridge() => _StubTtsWebBridge();
