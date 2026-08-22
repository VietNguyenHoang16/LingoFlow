# Auto-fill Phiên âm IPA Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Mọi card từ vựng hiển thị `/ˈleɪ.bər/` — tự điền IPA khi thêm/import từ + nút backfill trong Profile.

**Architecture:** Tái dùng `DictionaryService` (dictionaryapi.dev). Thêm 2 API actions mới cho web DB, tạo `PronunciationService` gom logic fetch+backfill, gắn vào 2 luồng import + Profile UI. Display không đổi.

**Tech Stack:** Flutter ^3.10.1, http, Vercel serverless (`api/lingoflow.js`, Postgres)

## Global Constraints

- UI copy tiếng Việt không dấu (theo hiện trạng: `'Da sua!'`, `'Loi:'`)
- Fonts Plus Jakarta Sans / Be Vietnam Pro
- Singleton services theo pattern `factory X() => _instance`
- SDK ^3.10.1

---

### Task 1: DictionaryService — lấy phonetic ĐẦU TIÊN + helper `fetchPronunciation`

**Files:**
- Modify: `lib/services/dictionary_service.dart`
- Test: `test/dictionary_service_test.dart`

**Interfaces:**
- Produces: `Future<String> fetchPronunciation(String word)` — trả `''` nếu không tìm thấy; `@visibleForTesting Map<String, dynamic>? parseWordData(dynamic entry)`

- [ ] **Step 1: Write the failing test**

```dart
// test/dictionary_service_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:lingoflow/services/dictionary_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final svc = DictionaryService();

  group('parseWordData', () {
    test('lays phonetic dau tien non-empty', () {
      final result = svc.parseWordData({
        'phonetics': [
          {'text': '', 'audio': ''},
          {'text': '/ˈleɪ.bər/', 'audio': 'https://a.mp3'},
          {'text': '/ˈleɪbə/', 'audio': ''},
        ],
        'meanings': [],
      });
      expect(result?['pronunciation'], '/ˈleɪ.bər/');
      expect(result?['audioUrl'], 'https://a.mp3');
    });

    test('tra ve null pronunciation khi khong co phonetics', () {
      final result = svc.parseWordData({'phonetics': [], 'meanings': []});
      expect(result?['pronunciation'], isNull);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails** — `flutter test test/dictionary_service_test.dart` → FAIL (`parseWordData` chưa tồn tại)

- [ ] **Step 3: Write minimal implementation** — expose `parseWordData`; vòng lặp phonetics chỉ set lần đầu:

```dart
if (pronunciation == null &&
    p['text'] != null &&
    p['text'].toString().isNotEmpty) {
  pronunciation = p['text'];
}
```

Thêm helper:

```dart
/// Lay chi phien am IPA cua [word]. Tra ve '' neu khong tim thay.
Future<String> fetchPronunciation(String word) async {
  final info = await getWordInfo(word);
  return (info?['pronunciation'] as String?) ?? '';
}
```

- [ ] **Step 4: Run test to verify it passes** — `flutter test test/dictionary_service_test.dart` → PASS

- [ ] **Step 5: Commit** — `feat(dictionary): pick first IPA phonetic, add fetchPronunciation helper`

### Task 2: API — 2 actions mới

**Files:**
- Modify: `api/lingoflow.js` (thêm sau case `getRecentWords`)
- Modify: `lib/services/database_service_web.dart` (sau method `getRecentWords`)

**Interfaces:**
- Produces: `getWordsMissingPronunciation(int userId) → List<Map>` (id, word); `updateWordPronunciation({required int wordId, required String pronunciation}) → void`

- [ ] **Step 1: Thêm JS cases**

```js
case 'getWordsMissingPronunciation': {
  const rows = await query(
    `SELECT vw.id, vw.word
     FROM vocabulary_words vw
     JOIN vocabulary_lists vl ON vw.list_id = vl.id
     WHERE vl.user_id = $1 AND (vw.pronunciation IS NULL OR vw.pronunciation = '')
     ORDER BY vw.created_at ASC`,
    [data.userId],
  );
  return rows;
}

case 'updateWordPronunciation':
  await query('UPDATE vocabulary_words SET pronunciation = $1 WHERE id = $2',
    [data.pronunciation || '', data.wordId]);
  return null;
```

- [ ] **Step 2: Thêm Dart methods** (pattern y hệt các method hiện có)

```dart
Future<List<Map<String, dynamic>>> getWordsMissingPronunciation(int userId) async {
  final rows = await _request<List<dynamic>>('getWordsMissingPronunciation', data: {'userId': userId});
  return rows.map((row) => Map<String, dynamic>.from(row as Map)).toList();
}

Future<void> updateWordPronunciation({required int wordId, required String pronunciation}) async {
  await _request<void>('updateWordPronunciation',
      data: {'wordId': wordId, 'pronunciation': pronunciation});
}
```

- [ ] **Step 3: Verify + commit** — `flutter analyze` sạch; commit `feat(api): list/update word pronunciation backfill endpoints`

### Task 3: PronunciationService (fetch + backfill)

**Files:**
- Create: `lib/services/pronunciation_service.dart`

**Interfaces:**
- Consumes: `DictionaryService.fetchPronunciation`, `DatabaseService.getWordsMissingPronunciation`, `DatabaseService.updateWordPronunciation`
- Produces: `PronunciationService().backfillUser(int userId, {void Function(int,int)? onProgress, bool Function()? isCancelled}) → Future<BackfillResult>`; `BackfillResult{updated, notFound}`

- [ ] **Step 1: Viết service** (không unit-test — phụ thuộc network/singleton DB; verify bằng Task 6)

```dart
import 'package:flutter/foundation.dart';

import 'database_service.dart';
import 'dictionary_service.dart';

class BackfillResult {
  final int updated;
  final int notFound;
  const BackfillResult({required this.updated, required this.notFound});
}

class PronunciationService {
  static final PronunciationService _instance = PronunciationService._internal();
  factory PronunciationService() => _instance;
  PronunciationService._internal();

  final DictionaryService _dict = DictionaryService();
  final DatabaseService _db = DatabaseService();

  Future<BackfillResult> backfillUser(
    int userId, {
    void Function(int done, int total)? onProgress,
    bool Function()? isCancelled,
  }) async {
    final words = await _db.getWordsMissingPronunciation(userId);
    int updated = 0;
    int notFound = 0;
    for (int i = 0; i < words.length; i++) {
      if (isCancelled?.call() ?? false) break;
      final w = words[i];
      try {
        final ipa = await _dict.fetchPronunciation(w['word'].toString());
        if (ipa.isNotEmpty) {
          await _db.updateWordPronunciation(wordId: w['id'] as int, pronunciation: ipa);
          updated++;
        } else {
          notFound++;
        }
      } catch (e) {
        debugPrint('PronunciationService: "${w['word']}" -> $e');
        notFound++;
      }
      onProgress?.call(i + 1, words.length);
    }
    return BackfillResult(updated: updated, notFound: notFound);
  }
}
```

- [ ] **Step 2:** `flutter analyze` sạch → commit `feat(pronunciation): add backfill service`

### Task 4: Hai luồng import tự fetch IPA

**Files:**
- Modify: `lib/services/bulk_word_importer.dart` (~dòng 233-242)
- Modify: `lib/pages/vocabulary_set_page.dart` (~dòng 494-508)

- [ ] **Step 1: bulk_word_importer** — thêm field `final DictionaryService _dict = DictionaryService();` + import; trong vòng insert:

```dart
final l = valid[i];
String pronunciation = '';
try {
  pronunciation = await _dict.fetchPronunciation(l.word);
} catch (_) {}
try {
  await _db.addWordToCategory(
    userId, l.wordType!, l.word, pronunciation, l.meaning,
    wordType: l.wordType,
  );
```

(fetch fail → vẫn insert với `''`)

- [ ] **Step 2: vocabulary_set_page** import-loop — trước `addVocabularyWord`:

```dart
String pronunciation = '';
try {
  pronunciation = await DictionaryService().fetchPronunciation(word);
} catch (_) {}
await _db.addVocabularyWord(
  widget.listId, word, pronunciation, meaning,
  fullDetails: fullDetails, wordType: wordType,
);
```

- [ ] **Step 3:** `flutter analyze` → commit `feat(import): auto-fetch IPA on both import flows`

### Task 5: Nút backfill trong Profile

**Files:**
- Modify: `lib/pages/profile_page.dart`

*Lệch so với thiết kế: progress bar inline trong card thay vì dialog — ít code hơn, cùng UX.*

- [ ] **Step 1: State vars** trong `_ProfilePageState`: `bool _isBackfilling = false; int _bfDone = 0; int _bfTotal = 0;`
- [ ] **Step 2: Method `_runPronunciationBackfill`** — gọi `backfillUser` với onProgress cập nhật state; snackbar tổng kết `'Cap nhat X tu, khong tim thay Y tu'`; finally reset `_isBackfilling`.
- [ ] **Step 3: Card "Du lieu"** — chèn sau voice card; `_buildSectionTitle('Du lieu', ...)`, subtitle `'Tu dong dien phien am IPA cho tu con thieu'`, `FilledButton.icon` disabled khi loading, label `'Cap nhat phien am'`; khi loading hiện LinearProgressIndicator + `Text('$_bfDone/$_bfTotal')`.
- [ ] **Step 4:** `flutter analyze` → commit `feat(profile): pronunciation backfill button with progress`

### Task 6: Verify toàn bộ

- [ ] `flutter analyze` — 0 error mới
- [ ] `flutter test` — tất cả pass
- [ ] Deploy web (Vercel auto) → smoke test: import từ mới → card hiện IPA; nút Profile backfill từ cũ; review/practice card cũng hiện
