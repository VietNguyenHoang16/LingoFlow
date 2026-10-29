import 'dart:async';

import 'package:flutter/material.dart';

import '../services/tts_web_audio.dart';

/// Bat lai audio doc sau khi iOS suspend (app xuong nen roi quay lai).
///
/// Tren iOS/Safari, sau khi app bi xuong nen, audio chi duoc phep phat lai khi
/// the <audio> duoc "unlock" bang mot cu cham that. Listener duoi day nhan
/// pointer-down truoc khi onTap cua nut loa chay, nen chi can nguoi dung cham
/// bat ky dau tren man hinh la tieng doc hoat dong lai.
class TtsAudioUnlocker extends StatefulWidget {
  const TtsAudioUnlocker({super.key, required this.child, this.audio});

  final Widget child;

  /// Test seam: mac dinh dung [TtsWebAudio.instance].
  final TtsWebAudio? audio;

  @override
  State<TtsAudioUnlocker> createState() => _TtsAudioUnlockerState();
}

class _TtsAudioUnlockerState extends State<TtsAudioUnlocker>
    with WidgetsBindingObserver {
  TtsWebAudio get _audio => widget.audio ?? TtsWebAudio.instance;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // iOS da suspend audio khi app xuong nen -> danh dau lai can unlock.
    if (state == AppLifecycleState.resumed) {
      _audio.onAppResumed();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) {
        unawaited(_audio.ensureUnlocked());
      },
      child: widget.child,
    );
  }
}
