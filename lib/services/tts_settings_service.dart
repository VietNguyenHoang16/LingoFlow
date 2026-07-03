import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  static const String _voiceIdKey = 'tts_voice_id';
  static const String _voiceNameKey = 'tts_voice_real_name';
  static const String _voiceLocaleKey = 'tts_voice_real_locale';
  static const String _speechRateKey = 'tts_speech_rate';
  static const String _defaultVoiceId = 'en-US-female';
  static const double _defaultSpeechRate = 0.85;

  static const List<TtsVoiceOption> voices = [
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
    await flutterTts.setLanguage(voice.code);
    await flutterTts.setPitch(voice.pitch);
    await flutterTts.setVolume(1.0);

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
              const Text(
                'Choose one voice for the whole app.',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
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
                        color: isSelected ? const Color(0xFF4a40e0) : Colors.grey,
                      ),
                      title: Text(
                        voice.name,
                        style: TextStyle(
                          color: isSelected ? const Color(0xFF4a40e0) : Colors.black,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                      subtitle: Text(realVoice != null ? realVoice['name']! : voice.gender),
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
