import re

filepath = r'C:\Users\ASUS\Desktop\Ung dung\vocab\lib\services\tts_settings_service.dart'
with open(filepath, 'r', encoding='utf-8') as f:
    content = f.read()

old = """    await _getSystemVoices();
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
"""

new = """    if (voice.id != googleVoice.id) {
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
"""

if old in content:
    content = content.replace(old, new)
    with open(filepath, 'w', encoding='utf-8') as f:
        f.write(content)
    print('SUCCESS: Fix applied')
else:
    print('FAIL: Old string not found')