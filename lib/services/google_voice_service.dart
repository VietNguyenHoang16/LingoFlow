import 'dart:async';

import 'package:audioplayers/audioplayers.dart';

class GoogleVoiceService {
  AudioPlayer? _player;
  DateTime _lastPlayedAt = DateTime.fromMillisecondsSinceEpoch(0);

  static const Duration _minGap = Duration(milliseconds: 150);

  Future<bool> speak(String text) async {
    try {
      final gap = DateTime.now().difference(_lastPlayedAt);
      if (gap < _minGap) {
        await Future.delayed(_minGap - gap);
      }
      final uri = Uri.parse('https://translate.google.com/translate_tts')
          .replace(queryParameters: {
        'ie': 'UTF-8',
        'client': 'tw-ob',
        'tl': 'en',
        'q': text,
      });
      final player = _player ??= AudioPlayer();
      await player.stop();
      await player.play(UrlSource(uri.toString()));
      _lastPlayedAt = DateTime.now();
      return true;
    } catch (_) {
      return false;
    }
  }
}