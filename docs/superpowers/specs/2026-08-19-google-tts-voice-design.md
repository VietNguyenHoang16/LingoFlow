# Google Translate Voice Design

Date: 2026-08-19
Status: Approved

## Problem

The app uses system TTS voices via `flutter_tts`, which sound robotic and differ from the voice users know from Google Translate.

## Goal

Play the exact Google Translate voice (en) when reading English text in the app, on all platforms (web/Vercel, Android, iOS, Windows), as the default voice — while keeping the existing Voice Settings selector so users can still pick system voices.

## Approach

Use Google's unofficial, key-less TTS endpoint:

```
https://translate.google.com/translate_tts?ie=UTF-8&client=tw-ob&tl=en&q=<url-encoded text>
```

It returns an MP3 of the Google Translate voice (this is the same endpoint the Google Translate web app uses).

### Components

1. **New `GoogleVoiceService`** (`lib/services/google_voice_service.dart`)
   - `Future<bool> speak(String text)` — builds the endpoint URL, plays the MP3 via `audioplayers` `UrlSource` (HTML5 audio on web → no CORS issue; native audio elsewhere).
   - Enforces a minimum 150 ms delay between consecutive plays to avoid rate limiting.
   - Returns `false` on any error (network failure, 429, etc.) so callers can fall back.
   - Speech rate does not apply (endpoint has no speed control) — fixed rate.

2. **`TtsSettingsService` changes** (`lib/services/tts_settings_service.dart`)
   - New `TtsVoiceOption(id: 'google-translate', code: 'en', name: 'Google Translate Voice', gender: 'Female', pitch: 1.0)` listed first.
   - `_defaultVoiceId` becomes `google-translate`.
   - `applyTo()` / `findRealVoice()` skip the google option (no system voice setup).
   - New `Future<bool> isGoogleVoiceSelected()`.
   - New helper `Future<void> speakWith(String text, FlutterTts fallbackTts)`: Google voice selected → `GoogleVoiceService.speak`; on failure (or non-Google voice) → configure `fallbackTts` via `applyTo` and speak.

3. **Pages** — replace the existing speak pattern
   (`await _ttsSettings.applyTo(_flutterTts); await _flutterTts.speak(text);`)
   with `await _ttsSettings.speakWith(text, _flutterTts);` in:
   - `category_page.dart`
   - `practice_page.dart`
   - `recent_page.dart`
   - `review_page.dart`
   - `vocabulary_set_page.dart`
   - preview in `profile_page.dart`

## Error Handling

- Google voice unreachable / 429 → fall back to the currently selected system voice (silent, no UI change).
- 150 ms gap between requests reduces risk of blocking.

## Testing

- Unit tests: google voice selected → uses `GoogleVoiceService` path; system voice selected → uses fallback path; google voice failure → fallback path.
- `flutter analyze`, `flutter test`, manual speak check on web.

## Out of Scope

- Google voice for Vietnamese text (English only).
- Speech-rate control for the Google voice.
- Official Google Cloud TTS (paid, API key).