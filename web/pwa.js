// pwa.js — minimal PWA install helper for LingoFlow
// Captures beforeinstallprompt and exposes helpers for Dart interop.
(function () {
  window.__deferredPrompt = null;
  window.__pwaPromptReady = false;

  window.addEventListener('beforeinstallprompt', function (e) {
    e.preventDefault();
    window.__deferredPrompt = e;
    window.__pwaPromptReady = true;
    window.dispatchEvent(new Event('pwa-prompt-ready'));
  });

  window.addEventListener('appinstalled', function () {
    window.__deferredPrompt = null;
    window.__pwaPromptReady = false;
    window.dispatchEvent(new Event('pwa-installed'));
  });

  window.__pwaCanPrompt = function () {
    return !!window.__deferredPrompt;
  };

  window.__pwaPrompt = async function () {
    if (!window.__deferredPrompt) return 'unavailable';
    var p = window.__deferredPrompt;
    try {
      await p.prompt();
      var choice = await p.userChoice;
      // Clear after use per spec (can only prompt once)
      window.__deferredPrompt = null;
      window.__pwaPromptReady = false;
      return (choice && choice.outcome) ? choice.outcome : 'dismissed';
    } catch (err) {
      return 'dismissed';
    }
  };

  window.__pwaIsIOS = function () {
    var ua = window.navigator.userAgent || '';
    var isIOSUA = /iPad|iPhone|iPod/.test(ua);
    var isIPadOS = (window.navigator.platform === 'MacIntel' && window.navigator.maxTouchPoints > 1);
    return isIOSUA || isIPadOS;
  };

  window.__pwaIsStandalone = function () {
    try {
      if (window.matchMedia('(display-mode: standalone)').matches) return true;
    } catch (e) {}
    // iOS Safari proprietary
    if (window.navigator.standalone === true) return true;
    // Android TWA / referrer hint
    try {
      if (document.referrer && document.referrer.indexOf('android-app://') === 0) return true;
    } catch (e) {}
    return false;
  };
})();
