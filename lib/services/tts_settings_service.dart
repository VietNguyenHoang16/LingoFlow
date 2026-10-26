import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'google_voice_service.dart';

class TtsVoiceOption {
  final String id;
  final String code;
  final String name;
  final String gender;
  final double pitch;

  const TtsVoiceOption({
    required this.id,
    required this.code,
    required this.name,
    required this.gender,
    required this.pitch,
  });
}

class TtsSettingsService {
  TtsSettingsService({GoogleVoiceService? googleVoiceService})
      : _googleVoiceService = googleVoiceService ?? GoogleVoiceService();

  final GoogleVoiceService _googleVoiceService;

  /// Test seam: moi phong `_isWeb` trong unit test tren desktop.
  @visibleForTesting
  static bool isWebOverride = false;

  static bool get _isWeb => isWebOverride || kIsWeb;

  /// Web engine (Safari/Chrome) la uterrance bi drop im lang khi speak()
  /// duoc goi gan dung ngay sau cancel(). Phim them mot khoang nho.
  static const Duration _restartDelay = Duration(milliseconds: 120);

  static const String _voiceIdKey = 'tts_voice_id';
  static const String _voiceNameKey = 'tts_voice_real_name';
  static const String _voiceLocaleKey = 'tts_voice_real_locale';
  static const String _speechRateKey = 'tts_speech_rate';
  // Web (Safari/Chrome): speechSynthesis tren web la uterrance khong bat
  // su kien (onstart/onend) sau khi bi drop -> speak() treo, queue kiet hang.
  // Mac dinh doc bang audio Google Translate (HTML5 audio, da xac nhan hoat
  // dong tren Safari/Chrome); khi proxy/ mang chet thi fallback giong he thong.
  static const String _defaultVoiceId = 'google-translate';
  static const double _defaultSpeechRate = 0.85;

  static const TtsVoiceOption googleVoice = TtsVoiceOption(
    id: 'google-translate',
    code: 'en',
    name: 'Google Translate Voice',
    gender: 'Female',
    pitch: 1.0,
  );

  static const List<TtsVoiceOption> voices = [
    googleVoice,
    TtsVoiceOption(id: 'en-US-female', code: 'en-US', name: 'English US Female', gender: 'Female', pitch: 1.0),
    TtsVoiceOption(id: 'en-GB-female', code: 'en-GB', name: 'English UK Female', gender: 'Female', pitch: 1.0),
    TtsVoiceOption(id: 'en-AU-female', code: 'en-AU', name: 'English Australia Female', gender: 'Female', pitch: 1.0),
    TtsVoiceOption(id: 'en-CA-female', code: 'en-CA', name: 'English Canada Female', gender: 'Female', pitch: 1.0),
    TtsVoiceOption(id: 'en-IN-female', code: 'en-IN', name: 'English India Female', gender: 'Female', pitch: 1.0),
    TtsVoiceOption(id: 'en-US-male', code: 'en-US', name: 'English US Male', gender: 'Male', pitch: 0.8),
    TtsVoiceOption(id: 'en-GB-male', code: 'en-GB', name: 'English UK Male', gender: 'Male', pitch: 0.8),
    TtsVoiceOption(id: 'en-AU-male', code: 'en-AU', name: 'English Australia Male', gender: 'Male', pitch: 0.8),
    TtsVoiceOption(id: 'en-CA-male', code: 'en-CA', name: 'English Canada Male', gender: 'Male', pitch: 0.8),
    TtsVoiceOption(id: 'en-IN-male', code: 'en-IN', name: 'English India Male', gender: 'Male', pitch: 0.8),
  ];

  List<Map<String, String>>? _cachedVoices;
  bool _voicesLoaded = false;

  Future<List<Map<String, String>>> _getSystemVoices() async {
    if (_voicesLoaded && _cachedVoices != null) return _cachedVoices!;
    try {
      final flutterTts = FlutterTts();
      final raw = await flutterTts.getVoices;
      if (raw is List) {
        _cachedVoices = raw
            .whereType<Map>()
            .map((v) => {
                  'name': (v['name'] ?? '').toString(),
                  'locale': (v['locale'] ?? v['lang'] ?? '').toString(),
                })
            .toList();
      } else {
        _cachedVoices = [];
      }
    } catch (_) {
      _cachedVoices = [];
    }
    _voicesLoaded = true;
    return _cachedVoices!;
  }

  Map<String, String>? findRealVoice(String localeCode, String gender) {
    if (_cachedVoices == null || _cachedVoices!.isEmpty) return null;
    final normalizedLocale = localeCode.toLowerCase().replaceAll('_', '-');

    var matches = _cachedVoices!.where((v) {
      final vLocale = (v['locale'] ?? '').toLowerCase().replaceAll('_', '-');
      return vLocale.startsWith(normalizedLocale);
    }).toList();

    if (matches.isEmpty) {
      matches = _cachedVoices!.where((v) {
        final vLocale = (v['locale'] ?? '').toLowerCase().replaceAll('_', '-');
        return vLocale.startsWith('en');
      }).toList();
    }

    if (matches.isEmpty) return null;

    final genderLower = gender.toLowerCase();
    for (final v in matches) {
      final nameLower = (v['name'] ?? '').toLowerCase();
      if (genderLower == 'female' && _isFemaleName(nameLower)) return v;
      if (genderLower == 'male' && !_isFemaleName(nameLower)) return v;
    }

    return matches.first;
  }

  bool _isFemaleName(String name) {
    final femaleMarkers = [
      'female', 'woman', 'girl', 'zira', 'samantha', 'karen', 'catherine',
      'susan', 'linda', 'mary', 'patricia', 'jennifer', 'lisa', 'nancy',
      'betty', 'sandra', 'dorothy', 'helen', 'donna', 'carol', 'ruth',
      'sharon', 'michelle', 'laura', 'sarah', 'kimberly', 'deborah',
      'jessica', 'cynthia', 'angela', 'melissa', 'brenda', 'amy',
      'anna', 'rebecca', 'virginia', 'kathleen', 'pamela', 'martha',
      'debra', 'amanda', 'stephanie', 'carolyn', 'christine', 'marie',
      'janet', 'fiona', 'moira', 'veena', 'tessa', 'alice', 'emma',
    ];
    return femaleMarkers.any((m) => name.contains(m));
  }

  Future<TtsVoiceOption> getSelectedVoice() async {
    final prefs = await SharedPreferences.getInstance();
    final savedId = prefs.getString(_voiceIdKey) ?? _defaultVoiceId;
    return voices.firstWhere(
      (voice) => voice.id == savedId,
      orElse: () => voices.first,
    );
  }

  Future<void> saveSelectedVoice(String voiceId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_voiceIdKey, voiceId);
  }

  Future<bool> isGoogleVoiceSelected() async {
    return (await getSelectedVoice()).id == googleVoice.id;
  }

  /// [speakTimeout] chi co tac dung tren web: gioi han thoi gian cho mot
  /// chunk de khong treo vinh vien khi engine khong bat su kien (test seam).
  Future<bool> speakWith(String text, {Duration? speakTimeout}) async {
    final clean = sanitizeForSpeech(text);
    if (clean.isEmpty) return false;
    // Chuyen doc thanh hang doi: tap don chi doc cau moi nhat, tranh
    // chong lenh / cat tieng khi bam lien tiep tren Safari iPad.
    _speakSeq++;
    final token = _speakSeq;
    final queued = _speakQueue.then((_) async {
      if (token != _speakSeq) return false;
      return _speakNow(clean, token, speakTimeout: speakTimeout);
    });
    _speakQueue = queued.then((_) {});
    return queued;
  }

  int _speakSeq = 0;
  Future<void> _speakQueue = Future.value();

  /// Gioi han thoi gian cho mot chunk tren web, theo do dai chu voi
  /// speech rate hien tai. Engine khong bat su kien -> timeout de khoi treo
  /// queue vinh vien.
  static Duration _speakTimeoutFor(String chunk, double rate) {
    final safeRate = rate < 0.5 ? 0.5 : rate;
    const baseMs = 2000;
    final perCharMs = (chunk.length * 130 / safeRate).round();
    return Duration(milliseconds: baseMs + perCharMs);
  }

  Future<bool> _speakNow(String clean, int token, {Duration? speakTimeout}) async {
    if (await isGoogleVoiceSelected()) {
      if (await _googleVoiceService.speak(clean)) return true;
      // Google fail (mat mang/proxy chan) -> fallback giong he thong
      // thay vi im lang.
    }
    final tts = await TtsEngine().sharedTts;
    try {
      await tts.stop();
    } catch (_) {}
    if (_isWeb) {
      await Future<void>.delayed(_restartDelay);
    }
    final rate = await getSpeechRate();
    var spoke = false;
    for (final chunk in chunkForSpeech(clean)) {
      if (token != _speakSeq) return spoke;
      try {
        if (_isWeb) {
          await tts.speak(chunk).timeout(
                speakTimeout ?? _speakTimeoutFor(chunk, rate),
              );
        } else {
          await tts.speak(chunk);
        }
        spoke = true;
      } catch (e) {
        debugPrint('TTS system speak failed (chunk=$chunk): $e');
        if (_isWeb) {
          // Chong kiet hang: giai phong engine truoc khi cho luot doc ke tiep.
          try {
            await tts.stop();
          } catch (_) {}
          try {
            await Future<void>.delayed(_restartDelay);
          } catch (_) {}
        }
        return spoke;
      }
    }
    return spoke;
  }

  /// Chuan hoa text truoc khi doc: trim, gop whitespace. Tra '' neu rong.
  @visibleForTesting
  static String sanitizeForSpeech(String text) {
    return text.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  /// Cat cau dai thanh chunk <= [maxLen] theo bien cau de Safari iPad
  /// (speechSynthesis hay cut cau > ~15s) doc du, khong bo sot.
  @visibleForTesting
  static List<String> chunkForSpeech(String text, [int maxLen = 180]) {
    final clean = sanitizeForSpeech(text);
    if (clean.isEmpty) return const [];
    if (clean.length <= maxLen) return [clean];
    final parts = clean.split(RegExp(r'(?<=[.!?;:])\s+'));
    final chunks = <String>[];
    final buf = StringBuffer();
    void flush() {
      final s = buf.toString().trim();
      if (s.isNotEmpty) chunks.add(s);
      buf.clear();
    }

    for (final p in parts) {
      if (p.length > maxLen) {
        flush();
        var rest = p;
        while (rest.length > maxLen) {
          var cut = rest.lastIndexOf(' ', maxLen);
          if (cut <= 0) cut = maxLen;
          chunks.add(rest.substring(0, cut).trim());
          rest = rest.substring(cut).trim();
        }
        if (rest.isNotEmpty) chunks.add(rest);
      } else if (buf.length + p.length + 1 > maxLen) {
        flush();
        buf.write(p);
      } else {
        if (buf.isNotEmpty) buf.write(' ');
        buf.write(p);
      }
    }
    flush();
    return chunks;
  }

  Future<double> getSpeechRate() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble(_speechRateKey) ?? _defaultSpeechRate;
  }

  Future<void> saveSpeechRate(double rate) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_speechRateKey, rate);
  }

  Future<String?> getSavedRealVoiceName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_voiceNameKey);
  }

  Future<String?> getSavedRealVoiceLocale() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_voiceLocaleKey);
  }

  Future<void> saveRealVoice(String name, String locale) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_voiceNameKey, name);
    await prefs.setString(_voiceLocaleKey, locale);
  }

  Future<void> applyTo(FlutterTts flutterTts) async {
    final voice = await getSelectedVoice();
    final speechRate = await getSpeechRate();
    try {
      await flutterTts.awaitSpeakCompletion(true);
    } catch (_) {}
    await flutterTts.setLanguage(voice.code);
    await flutterTts.setPitch(voice.pitch);
    await flutterTts.setVolume(1.0);

    if (voice.id != googleVoice.id) {
      await _getSystemVoices();
      final realVoice = findRealVoice(voice.code, voice.gender);

      if (realVoice != null) {
        await flutterTts.setVoice({
          'name': realVoice['name']!,
          'locale': realVoice['locale']!,
        });
      } else if (_cachedVoices != null && _cachedVoices!.isNotEmpty) {
        var englishVoice = _cachedVoices!.firstWhere(
          (v) {
            final vLocale = (v['locale'] ?? '').toLowerCase().replaceAll('_', '-');
            return vLocale.startsWith('en');
          },
          orElse: () => _cachedVoices!.first,
        );
        await flutterTts.setVoice({
          'name': englishVoice['name']!,
          'locale': englishVoice['locale']!,
        });
      }
    }

    await flutterTts.setSpeechRate(speechRate);
  }

  Future<TtsVoiceOption?> showVoiceSelector(BuildContext context) async {
    await _getSystemVoices();
    final selectedVoice = await getSelectedVoice();
    if (!context.mounted) return null;

    return showModalBottomSheet<TtsVoiceOption>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Voice Settings',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Choose one voice for the whole app.',
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(sheetContext).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 360,
                child: ListView.builder(
                  itemCount: voices.length,
                  itemBuilder: (context, index) {
                    final voice = voices[index];
                    final isSelected = voice.id == selectedVoice.id;
                    final realVoice = findRealVoice(voice.code, voice.gender);
                    return ListTile(
                      leading: Icon(
                        Icons.record_voice_over,
                        color: isSelected
                            ? Theme.of(sheetContext).colorScheme.primary
                            : Theme.of(sheetContext).colorScheme.onSurfaceVariant,
                      ),
                      title: Text(
                        voice.name,
                        style: TextStyle(
                          color: isSelected
                              ? Theme.of(sheetContext).colorScheme.primary
                              : Theme.of(sheetContext).colorScheme.onSurface,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                      subtitle: Text(
                        realVoice != null
                            ? realVoice['name']!
                            : voice.id == googleVoice.id
                                ? 'Google Translate'
                                : voice.gender,
                      ),
                      selected: isSelected,
                      onTap: () async {
                        await saveSelectedVoice(voice.id);
                        if (realVoice != null) {
                          await saveRealVoice(realVoice['name']!, realVoice['locale']!);
                        }
                        if (!context.mounted) return;
                        Navigator.pop(context, voice);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Engine TTS dung chung cho ca app: mot FlutterTts duy nhat,
/// chi apply lai settings khi voice / speech rate thay doi.
class TtsEngine {
  TtsEngine._internal();
  static final TtsEngine _instance = TtsEngine._internal();
  factory TtsEngine() => _instance;

  /// Test seam: thay the FlutterTts that trong unit test.
  @visibleForTesting
  // ignore: library_private_types_in_public_api
  static FlutterTts Function()? ttsFactory;

  @visibleForTesting
  static void testReset() {
    _instance._tts = null;
    _instance._appliedSignature = null;
  }

  final TtsSettingsService _settings = TtsSettingsService();
  FlutterTts? _tts;
  String? _appliedSignature;

  /// Goi sau khi thay doi voice / speech rate de buoc apply moi.
  Future<void> invalidate() async {
    _appliedSignature = null;
  }

  Future<FlutterTts> get sharedTts async {
    final tts = _tts ??= (ttsFactory?.call() ?? FlutterTts());
    if (_appliedSignature == null) {
      await _settings.applyTo(tts);
      final voice = await _settings.getSelectedVoice();
      final rate = await _settings.getSpeechRate();
      final realName = await _settings.getSavedRealVoiceName();
      _appliedSignature = '${voice.id}|$rate|$realName';
    }
    return tts;
  }

  Future<void> stop() async {
    try {
      await _tts?.stop();
    } catch (_) {}
  }
}
