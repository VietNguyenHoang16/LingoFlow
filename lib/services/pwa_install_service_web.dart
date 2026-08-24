// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:async';
import 'dart:html' as html;
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PwaInstallService {
  static final PwaInstallService _instance = PwaInstallService._internal();
  factory PwaInstallService() => _instance;
  PwaInstallService._internal();

  static const _dismissKey = 'pwa_dismissed_until';

  bool get isSupported => kIsWeb;

  bool get canPrompt {
    try {
      final res = globalContext.callMethod('__pwaCanPrompt'.toJS);
      if (res == null) return false;
      return (res as JSBoolean).toDart;
    } catch (_) {
      return false;
    }
  }

  bool get isIOS {
    try {
      final res = globalContext.callMethod('__pwaIsIOS'.toJS);
      if (res != null) return (res as JSBoolean).toDart;
    } catch (_) {}
    try {
      final ua = html.window.navigator.userAgent.toLowerCase();
      final isIOSUA = ua.contains('iphone') || ua.contains('ipad') || ua.contains('ipod');
      final platform = html.window.navigator.platform ?? '';
      final isIPadOS = platform == 'MacIntel' && (html.window.navigator.maxTouchPoints ?? 0) > 1;
      return isIOSUA || isIPadOS;
    } catch (_) {
      return false;
    }
  }

  bool get isStandalone {
    try {
      final res = globalContext.callMethod('__pwaIsStandalone'.toJS);
      if (res != null && (res as JSBoolean).toDart) return true;
    } catch (_) {}
    try {
      final q = html.window.matchMedia('(display-mode: standalone)').matches;
      if (q) return true;
      final standalone = globalContext.getProperty('navigator'.toJS);
      if (!standalone.isUndefinedOrNull) {
        final v = (standalone as JSObject).getProperty('standalone'.toJS);
        if (!v.isUndefinedOrNull && (v as JSBoolean).toDart) return true;
      }
    } catch (_) {}
    return false;
  }

  bool get isInstalled => isStandalone;

  Future<bool> shouldShowPrompt() async {
    if (!kIsWeb) return false;
    if (isStandalone) return false;
    try {
      final prefs = await SharedPreferences.getInstance();
      final until = prefs.getInt(_dismissKey) ?? 0;
      if (DateTime.now().millisecondsSinceEpoch < until) return false;
    } catch (_) {}
    if (isIOS) return true;
    if (canPrompt) return true;
    return false;
  }

  Future<String> promptInstall() async {
    try {
      final promise = globalContext.callMethod('__pwaPrompt'.toJS) as JSPromise;
      final res = await promise.toDart;
      if (res == null) return 'dismissed';
      return (res as JSString).toDart;
    } catch (_) {
      return 'unavailable';
    }
  }

  Future<void> dismiss({int days = 7}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final until = DateTime.now().add(Duration(days: days)).millisecondsSinceEpoch;
      await prefs.setInt(_dismissKey, until);
    } catch (_) {}
  }

  Future<void> clearDismiss() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_dismissKey);
    } catch (_) {}
  }

  Stream<void> get onPromptReady {
    final c = StreamController<void>.broadcast();
    try {
      html.window.addEventListener('pwa-prompt-ready', (e) => c.add(null));
    } catch (_) {}
    return c.stream;
  }

  Stream<void> get onInstalled {
    final c = StreamController<void>.broadcast();
    try {
      html.window.addEventListener('pwa-installed', (e) => c.add(null));
      html.window.addEventListener('appinstalled', (e) => c.add(null));
    } catch (_) {}
    return c.stream;
  }
}
