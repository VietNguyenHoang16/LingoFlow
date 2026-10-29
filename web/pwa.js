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

// ---------------------------------------------------------------------------
// tts — phat audio doc tren iOS Safari / PWA.
//
// Vi sao khong dung audioplayers tren web: audioplayers_web dinh moi
// <audio> vao mot AudioContext. iOS suspend AudioContext khi app xuong nen
// va chi cho resume() trong user gesture -> quay lai app thi audio im lang
// (chuoi audio van "dang phat" nhung khong ra loa).
//
// O day dung DUY NHAT mot the <audio> khong qua AudioContext, va "unlock"
// trong cu cham dau tien sau moi lan app bi xuong nen (iOS chi cho play()
// tu dong sau khi the audio da duoc phat boi mot user gesture).
// ---------------------------------------------------------------------------
(function () {
  var SILENT_WAV =
    'data:audio/wav;base64,UklGRkQDAABXQVZFZm10IBAAAAABAAEAQB8AAIA+AAACABAAZGF0YSADAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA==';

  var el = null;
  var unlocked = false;
  var needsUnlock = true;
  var lastUrl = null;

  function audioEl() {
    if (el) return el;
    el = new Audio();
    el.preload = 'auto';
    el.setAttribute('playsinline', 'true');
    el.setAttribute('webkit-playsinline', 'true');
    el.style.position = 'absolute';
    el.style.width = '0';
    el.style.height = '0';
    el.style.opacity = '0';
    el.style.pointerEvents = 'none';
    if (document.body) document.body.appendChild(el);
    return el;
  }

  function unlock() {
    // PHAI goi play() dong bo trong user gesture (khong await truoc do).
    try {
      var a = audioEl();
      if (unlocked && !a.paused) return Promise.resolve('ok');
      a.pause();
      a.src = SILENT_WAV;
      var p = a.play();
      return Promise.resolve(p).then(function () {
        unlocked = true;
        needsUnlock = false;
        try { a.pause(); } catch (e) {}
        return 'ok';
      }, function (err) {
        if (err && err.name === 'NotAllowedError') return 'blocked';
        // AbortError do doi src lien tuc... coi nhu the audio da duoc cap quyen.
        unlocked = true;
        needsUnlock = false;
        return 'ok';
      });
    } catch (e) {
      return Promise.resolve('fail');
    }
  }

  function play(url) {
    return new Promise(function (resolve) {
      try {
        var a = audioEl();
        lastUrl = url;
        a.pause();
        a.src = url;
        try { a.load(); } catch (e) {}
        var p = a.play();
        if (p && p.then) {
          p.then(function () {
            unlocked = true;
            needsUnlock = false;
            resolve('played');
          }, function (err) {
            if (err && err.name === 'NotAllowedError') {
              // Bi chan autoplay: cu cham ke tiep se unlock lai.
              needsUnlock = true;
              resolve('blocked');
            } else {
              resolve('failed');
            }
          });
        } else {
          resolve('played');
        }
      } catch (e) {
        resolve('failed');
      }
    });
  }

  function stop() {
    try {
      if (!el) return;
      el.pause();
      el.currentTime = 0;
    } catch (e) {}
  }

  // iOS de speechSynthesis o trang thai paused/treo sau khi xuong nen ->
  // cancel + resume de lan doc sau khong bi im lang.
  function resetSpeech() {
    try {
      if (window.speechSynthesis) {
        window.speechSynthesis.cancel();
        window.speechSynthesis.resume();
      }
    } catch (e) {}
  }

  document.addEventListener('visibilitychange', function () {
    if (document.hidden) {
      stop();
      // Quay lai app phai co mot cu cham de unlock lai audio tren iOS.
      needsUnlock = true;
    } else {
      resetSpeech();
    }
  });
  window.addEventListener('pageshow', function () { resetSpeech(); });

  window.__tts = {
    unlock: unlock,
    play: play,
    stop: stop,
    resetSpeech: resetSpeech,
    needsUnlock: function () { return needsUnlock; },
    markNeedsUnlock: function () { needsUnlock = true; },
    lastUrl: function () { return lastUrl; }
  };
})();
