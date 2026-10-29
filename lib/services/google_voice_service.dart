import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

import 'tts_web_audio.dart';
import 'tts_web_bridge.dart';

class GoogleVoiceService {
  GoogleVoiceService({TtsWebAudio? webAudio, bool? isWebOverride})
      : _webAudio = webAudio ?? TtsWebAudio.instance,
        _isWebOverride = isWebOverride;

  final TtsWebAudio _webAudio;
  final bool? _isWebOverride;

  bool get _isWeb => _isWebOverride ?? kIsWeb;

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

      // Web: phat bang the <audio> duy nhat (xem web/pwa.js). audioplayers_web
      // dinh audio vao AudioContext, ma iOS suspend AudioContext khi app xuong
      // nen -> quay lai app la im lang du van "dang phat".
      if (_isWeb) {
        final outcome = await _webAudio.play(uri);
        if (outcome != WebPlayOutcome.played) {
          debugPrint('GoogleVoiceService: web play -> $outcome');
          return false;
        }
        _lastPlayedAt = DateTime.now();
        return true;
      }

      final player = _player ??= AudioPlayer();
      await player.stop();
      await player.play(UrlSource(uri.toString()));
      _lastPlayedAt = DateTime.now();
      return true;
    } catch (e) {
      // Log loi de phan biet: proxy chet, mang le (network TLS), autoplay
      // bi chan boi browser... thay vi im lang khong co dau vet.
      debugPrint('GoogleVoiceService.speak failed: $e');
      return false;
    }
  }
}
