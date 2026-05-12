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
  static const String _defaultVoiceId = 'en-US-female';

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

Future<void> applyTo(FlutterTts flutterTts) async {
    final voice = await getSelectedVoice();
    // Set language, voice, and speech parameters.
    await flutterTts.setLanguage(voice.code);
    // Use the voice's unique identifier if supported by the platform.
    try {
      await flutterTts.setVoice({'name': voice.id});
    } catch (_) {
      // Some platforms ignore setVoice; continue without failing.
    }
    await flutterTts.setPitch(voice.pitch);
    await flutterTts.setSpeechRate(0.5);
    await flutterTts.setVolume(1.0);
  }

  Future<TtsVoiceOption?> showVoiceSelector(BuildContext context) async {
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
                      subtitle: Text(voice.gender),
                      selected: isSelected,
                      onTap: () async {
                        await saveSelectedVoice(voice.id);
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
