import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:lingoflow/services/google_voice_service.dart';
import 'package:lingoflow/services/tts_settings_service.dart';

class _FakeGoogleVoice extends GoogleVoiceService {
  _FakeGoogleVoice({this.succeeds = true});

  bool succeeds;
  int calls = 0;

  @override
  Future<bool> speak(String text) async {
    calls++;
    return succeeds;
  }
}

class _FakeTts extends FlutterTts {
  final List<String> spoken = [];

  @override
  Future<dynamic> speak(String text, {bool focus = false}) async {
    spoken.add(text);
    return 1;
  }

  @override
  Future<dynamic> setLanguage(String language) async => 1;

  @override
  Future<dynamic> setPitch(double pitch) async => 1;

  @override
  Future<dynamic> setVolume(double volume) async => 1;

  @override
  Future<dynamic> setSpeechRate(double rate) async => 1;

  @override
  Future<dynamic> setVoice(Map<String, String> voice) async => 1;

  @override
  Future<dynamic> get getVoices async => <Map<String, String>>[];
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('google-translate is the default selected voice', () async {
    final settings = TtsSettingsService();
    final voice = await settings.getSelectedVoice();
    expect(voice.id, 'google-translate');
  });

  test('builds audio URLs through the production TTS proxy', () {
    final uri = GoogleVoiceService.buildAudioUri('hello & world');

    expect(uri.path, '/api/tts');
    expect(uri.queryParameters['q'], 'hello & world');
    expect(uri.queryParameters['tl'], 'en');
  });

  test('speaks via google voice when selected and google succeeds', () async {
    SharedPreferences.setMockInitialValues({
      'tts_voice_id': 'google-translate',
    });
    final google = _FakeGoogleVoice();
    final fallback = _FakeTts();
    final settings = TtsSettingsService(googleVoiceService: google);

    await settings.speakWith('hello');

    expect(google.calls, 1);
    expect(fallback.spoken, isEmpty);
  });

  test('does not fall back to system voice when google voice fails', () async {
    SharedPreferences.setMockInitialValues({
      'tts_voice_id': 'google-translate',
    });
    final google = _FakeGoogleVoice(succeeds: false);
    final fallback = _FakeTts();
    final settings = TtsSettingsService(googleVoiceService: google);

    await settings.speakWith('hello');

    expect(google.calls, 1);
    expect(fallback.spoken, isEmpty);
  });

  test('uses system voice when a system voice is selected', () async {
    SharedPreferences.setMockInitialValues({'tts_voice_id': 'en-US-female'});
    TtsEngine.testReset();
    addTearDown(TtsEngine.testReset);
    final google = _FakeGoogleVoice();
    final fallback = _FakeTts();
    TtsEngine.ttsFactory = () => fallback;
    addTearDown(() => TtsEngine.ttsFactory = null);
    final settings = TtsSettingsService(googleVoiceService: google);

    await settings.speakWith('hello');

    expect(google.calls, 0);
    expect(fallback.spoken, ['hello']);
  });

  test('reuses the shared engine without re-applying settings', () async {
    SharedPreferences.setMockInitialValues({'tts_voice_id': 'en-US-female'});
    TtsEngine.testReset();
    addTearDown(TtsEngine.testReset);
    int applies = 0;
    final fake = _CountingTts(onApply: () => applies++);
    TtsEngine.ttsFactory = () => fake;
    addTearDown(() => TtsEngine.ttsFactory = null);
    final settings = TtsSettingsService(googleVoiceService: _FakeGoogleVoice());

    await settings.speakWith('one');
    await settings.speakWith('two');
    await settings.speakWith('three');

    expect(applies, 1);
    expect(fake.spoken, ['one', 'two', 'three']);
  });
}

class _CountingTts extends _FakeTts {
  _CountingTts({required this.onApply});

  final VoidCallback onApply;

  @override
  Future<dynamic> setLanguage(String language) async {
    onApply();
    return 1;
  }
}
