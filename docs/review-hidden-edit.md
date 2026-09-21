# Review: hidden word edit (Từ + Nghĩa)

## Objective and approved interaction
Long-press the question/answer card (or Shift+F10) -> hidden bottom sheet now offers `Chỉnh sửa từ` next to `Xóa từ`. The edit dialog exposes only **Từ + Nghĩa** because in review the meaning is the question prompt on the card; the remaining fields (phát âm, chi tiết, loại từ) are fetched automatically from dictionaryapi.dev when the word text changes, while the typed meaning is always kept. Approved by user in conversation: client-side dictionary fetch, no API/backend change and no redeploy.

## Stack and conventions
Existing Flutter/Dart app. Reuses `DictionaryService` (dictionaryapi.dev, already used for bulk import / IPA backfill / word-type classification), `DatabaseService.updateVocabularyWord` + `updateVocabularyWordDetails`, `WordTypeClassifier.kPosToWordType`, `normalizeWord` and `parseFullDetails`. The 2-field dialog follows the existing `quick_meaning_edit.dart` pattern. No dependency, backend or schema changes.

## Implementation tasks
1. `lib/services/word_enrichment_service.dart`: map `getWordInfo()` -> `{pronunciation (stripSlashes), fullDetails, wordType}`; `fullDetails` built in the DB format `pos: [{definition: ..., example: ...}]` that `parseFullDetails` can read; POS not mapped to an app key (e.g. `exclamation` -> `interjection`, unknown POS dropped); braces/brackets sanitized; max 3 definitions per type. Never throws: unknown word / offline -> `null`.
2. `lib/widgets/quick_word_edit.dart`: dialog Từ + Nghĩa, both required (inline errors), no-op when nothing changed, returns `WordEditResult`.
3. `lib/pages/review_page.dart`: `_WordMenuAction {edit, delete}` in the hidden menu; `_editCurrentWord()` = meaning-only -> `updateVocabularyWordDetails` (no network), word changed -> enrichment + `updateVocabularyWord`; optimistic patch with rollback **by word id**; reset of the typed answer / diff only when the target word text changes; shared busy flag `_isWordBusy` (renamed from `_isDeletingWord`) blocks rating, second long-press, pop and shows the existing progress bar; focus restore unchanged; `_resetCardAnswerState()` extracted from the duplicated reset blocks.
4. `lib/services/dictionary_service.dart` + `word_type_classifier.dart`: `stripSlashes` made public and `kPosToWordType` exposed so both services share one rule instead of duplicating it.

## Relevant files
- lib/pages/review_page.dart: hidden menu, edit flow, session patching, busy guard.
- lib/services/word_enrichment_service.dart (new), lib/widgets/quick_word_edit.dart (new).
- test/word_enrichment_service_test.dart, test/quick_word_edit_test.dart, test/review_edit_test.dart (new).

## Commands (repository root)
- flutter test test/word_enrichment_service_test.dart
- flutter test test/quick_word_edit_test.dart
- flutter test test/review_edit_test.dart
- flutter test
- flutter analyze
- flutter build web --release

## Boundaries
Never change the delete action label/flow; never touch api/**, schema or dependencies. Preserve unrelated working-tree changes. Ask before testing against live data or deploying.

## Verification results
- New tests: word enrichment 9, dialog 4, review edit 9 = 22 passed; full Flutter suite: 120 passed.
- Simulated with http MockClient (API + `api.dictionaryapi.dev`); no production request made.
- flutter analyze: 8 pre-existing info-level findings outside the changed files; 0 findings in new/changed files.
- flutter build web --release: succeeded (`✓ Built build\web`); only the pre-existing flutter_tts WebAssembly dry-run warnings remain.
- No physical-device gesture test, no deploy.

## Acceptance
- Tap/input unchanged; long-press alone never edits or deletes.
- Menu offers both actions, reachable by long-press and Shift+F10.
- Meaning-only edit: single `updateVocabularyWordDetails` request, no dictionary call, typed answer + mismatch marks preserved.
- Word change: one dictionary call; saves word + meaning + fetched pronunciation/details/word type while keeping topic tag and synonyms; when the dictionary has nothing, the word + meaning are still saved and the snackbar says so; stale typed answer/diff reset.
- Failure: word row rolled back by id in the session, error snackbar, no crash, retry possible.
- While saving: rating keys, hint, Show answer, second long-press and back are blocked (progress bar visible).
