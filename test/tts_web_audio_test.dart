import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lingoflow/services/google_voice_service.dart';
import 'package:lingoflow/services/tts_web_audio.dart';
import 'package:lingoflow/services/tts_web_bridge.dart';
import 'package:lingoflow/widgets/tts_audio_unlocker.dart';

class _FakeBridge implements TtsWebBridge {
  bool unlockSucceeds = true;
  WebPlayOutcome playOutcome = WebPlayOutcome.played;

  int unlockCalls = 0;
  int playCalls = 0;
  int resetSpeechCalls = 0;
  Uri? lastUri;

  @override
  Future<bool> unlock() async {
    unlockCalls++;
    return unlockSucceeds;
  }

  @override
  Future<WebPlayOutcome> play(Uri uri) async {
    playCalls++;
    lastUri = uri;
    return playOutcome;
  }

  @override
  Future<void> stop() async {}

  @override
  void resetSpeechSynthesis() {
    resetSpeechCalls++;
  }
}

void main() {
  group('TtsWebAudio', () {
    test('unlock mot lan, cac cu cham sau khong goi lai', () async {
      final bridge = _FakeBridge();
      final audio = TtsWebAudio(bridge: bridge, isWeb: true);

      expect(audio.needsUnlock, isTrue);
      await audio.ensureUnlocked();
      await audio.ensureUnlocked();
      await audio.ensureUnlocked();

      expect(bridge.unlockCalls, 1);
      expect(audio.needsUnlock, isFalse);
    });

    test('unlock that bai thi van can unlock o cu cham sau', () async {
      final bridge = _FakeBridge()..unlockSucceeds = false;
      final audio = TtsWebAudio(bridge: bridge, isWeb: true);

      await audio.ensureUnlocked();
      expect(audio.needsUnlock, isTrue);

      bridge.unlockSucceeds = true;
      await audio.ensureUnlocked();

      expect(bridge.unlockCalls, 2);
      expect(audio.needsUnlock, isFalse);
    });

    test('app quay lai foreground -> reset speechSynthesis + can unlock lai',
        () async {
      final bridge = _FakeBridge();
      final audio = TtsWebAudio(bridge: bridge, isWeb: true);
      await audio.ensureUnlocked();

      audio.onAppResumed();

      expect(bridge.resetSpeechCalls, 1);
      expect(audio.needsUnlock, isTrue);
    });

    test('bi chan autoplay -> danh dau can unlock lai', () async {
      final bridge = _FakeBridge()..playOutcome = WebPlayOutcome.blocked;
      final audio = TtsWebAudio(bridge: bridge, isWeb: true);
      await audio.ensureUnlocked();

      final outcome = await audio.play(Uri.parse('https://x/api/tts?q=hello'));

      expect(outcome, WebPlayOutcome.blocked);
      expect(audio.needsUnlock, isTrue);
      expect(bridge.lastUri!.queryParameters['q'], 'hello');
    });

    test('phat thanh cong -> khong con can unlock', () async {
      final bridge = _FakeBridge();
      final audio = TtsWebAudio(bridge: bridge, isWeb: true);

      final outcome = await audio.play(Uri.parse('https://x/api/tts?q=hello'));

      expect(outcome, WebPlayOutcome.played);
      expect(audio.needsUnlock, isFalse);
    });

    test('native (isWeb=false) khong goi bridge', () async {
      final bridge = _FakeBridge();
      final audio = TtsWebAudio(bridge: bridge, isWeb: false);

      await audio.ensureUnlocked();
      final outcome = await audio.play(Uri.parse('https://x/api/tts?q=hello'));

      expect(outcome, WebPlayOutcome.failed);
      expect(bridge.unlockCalls, 0);
      expect(bridge.playCalls, 0);
    });
  });

  group('GoogleVoiceService tren web', () {
    test('phat duoc qua the audio web, khong dung audioplayers', () async {
      final bridge = _FakeBridge();
      final service = GoogleVoiceService(
        webAudio: TtsWebAudio(bridge: bridge, isWeb: true),
        isWebOverride: true,
      );

      final ok = await service.speak('hello');

      expect(ok, isTrue);
      expect(bridge.playCalls, 1);
      expect(bridge.lastUri!.path, '/api/tts');
      expect(bridge.lastUri!.queryParameters['q'], 'hello');
    });

    test('bi chan autoplay -> tra false de lop tren fallback giong he thong',
        () async {
      final bridge = _FakeBridge()..playOutcome = WebPlayOutcome.blocked;
      final service = GoogleVoiceService(
        webAudio: TtsWebAudio(bridge: bridge, isWeb: true),
        isWebOverride: true,
      );

      expect(await service.speak('hello'), isFalse);
    });
  });

  group('TtsAudioUnlocker', () {
    testWidgets('cham vao man hinh o bat ky dau se unlock audio',
        (tester) async {
      final bridge = _FakeBridge();
      final audio = TtsWebAudio(bridge: bridge, isWeb: true);

      await tester.pumpWidget(MaterialApp(
        home: TtsAudioUnlocker(
          audio: audio,
          child: const Scaffold(body: Center(child: Text('noi dung'))),
        ),
      ));

      await tester.tap(find.text('noi dung'));
      await tester.pump();

      expect(bridge.unlockCalls, 1);
      expect(audio.needsUnlock, isFalse);
    });

    testWidgets('app quay lai foreground se unlock lai lan cham sau',
        (tester) async {
      final bridge = _FakeBridge();
      final audio = TtsWebAudio(bridge: bridge, isWeb: true);

      await tester.pumpWidget(MaterialApp(
        home: TtsAudioUnlocker(
          audio: audio,
          child: const Scaffold(body: Center(child: Text('noi dung'))),
        ),
      ));
      await tester.tap(find.text('noi dung'));
      await tester.pump();
      expect(audio.needsUnlock, isFalse);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(bridge.resetSpeechCalls, 1);
      expect(audio.needsUnlock, isTrue);

      await tester.tap(find.text('noi dung'));
      await tester.pump();
      expect(bridge.unlockCalls, 2);
    });
  });
}
