# Review: hidden word deletion

## Objective and approved interaction
Long-press the question/answer card -> hidden bottom-sheet action `Xóa từ` -> confirmation that the word is deleted from the library, not just skipped. No permanent delete icon or hint. Approved by user in conversation.

## Stack and conventions
Existing Flutter/Dart app, Material theme (`AppTheme`), local State and DatabaseService.deleteVocabularyWord. Reuse existing HTTP API; no dependencies, backend or schema changes.

## Implementation tasks
1. Add widget tests using http/testing MockClient and shared_preferences mocks (no production requests).
2. Add hidden action, confirmation and guarded async deletion in ReviewPage. Wait for pending SRS writes; block duplicate actions/rating during deletion. On success remove every occurrence of the ID, adjust cursor, reset answer/hints and finish safely when no pending words remain. Preserve actual review statistics; deletion does not count as a review.
3. Verify cancel/dismiss, failure, successful deletion, final word, Again repeats and normal input. Review scoped diff.

## Relevant files
- lib/pages/review_page.dart: existing local state, card, SRS and completion screen.
- test/review_delete_test.dart: widget regression tests following existing *_test.dart naming and AppTheme wrappers.

## Commands (repository root)
- flutter test test/review_delete_test.dart
- flutter test
- flutter analyze
- flutter build web --release

## Boundaries
Always preserve unrelated working-tree changes and use existing API. Ask before schema/dependency changes. Never test deletion against live data or deploy without a request.

## Verification results
- 7 new widget tests passed; full Flutter suite: 61 passed.
- flutter analyze: 8 existing info-level findings outside the changed files; no findings in ReviewPage or its new test.
- flutter build web --release: succeeded; existing flutter_tts WebAssembly dry-run warnings remain.
- git diff --check: clean. No live-server deletion, deployment, or physical-device gesture testing performed.

## Acceptance
- Tap/input unchanged; long-press alone never deletes; cancel/dismiss sends no delete request.
- Only successful API deletion removes the word; failure preserves the current answer and allows retry.
- Delete all repeat occurrences without skipping the next pending word or changing review counts.
- Completion works even when every word is deleted; no RangeError or division by zero.
- Delete action also reachable through keyboard context-menu shortcut (Shift+F10) and long-press semantics without a visible control.
