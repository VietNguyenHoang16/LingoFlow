import 'dart:async';

import 'package:audioplayers/audioplayers.dart';

class GoogleVoiceService {
  AudioPlayer? _player;
  DateTime _lastPlayedAt = DateTime.fromMillisecondsSinceEpoch(0);

  static const Duration _minGap = Duration(milliseconds: 150);
  static const String _proxyBaseUrl = 'https://vocab-virid.vercel.app/api/tts';

  static Uri buildAudioUri(String text) {
    return Uri.parse(_proxyBaseUrl).replace(queryParameters: {
      'tl': 'en',
      'q': text,
    });
  }

  Future<bool> speak(String text) async {
    try {
      final gap = DateTime.now().difference(_lastPlayedAt);
      if (gap < _minGap) {
        await Future.delayed(_minGap - gap);
      }
      final uri = buildAudioUri(text);
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
