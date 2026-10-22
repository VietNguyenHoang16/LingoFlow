# Spec: AI-generated vocabulary examples

## Goal

Every new word gets one natural, concrete example sentence plus a Vietnamese
translation, written freely by the AI with no canned template. If the AI fails,
a single word is not saved and the user sees the reason. Bulk imports keep the
words that succeeded and report the ones that failed.

The sentence must be editable before saving from the example managers in the
Flutter app and on `/example`.

## Behavior

- Adding one word: generate the example first; insert the word together with
  `example_sentence`, `example_translation`, `example_target` only on success.
- AI failure on a single word: no row is inserted; the API returns a clear
  Vietnamese message.
- Bulk import: generate examples with bounded concurrency and a time budget;
  insert only successful words; return `{ insertedCount, failed: [...] }`.
- Example managers: `AI gợi ý` fills the form; the user edits and saves.
- Saving an example writes the three example columns, not `full_details`.
- No template fallback in the add/import/generate paths.

## Prompt rules

- One sentence, 5-20 words, A2-B1, concrete scene.
- Must contain the target word exactly.
- No fixed sentence pattern; avoid clichés such as "The ___ was ...",
  "Every day ...", "Today ...".
- Natural Vietnamese translation.

## Validation

- Sentence contains the target (case-insensitive), 20-240 characters.
- Translation non-empty, at most 1000 characters.
- Duplicate sentence inside one batch is retried once, then reported as failed.

## Error messages

- Missing `GEMINI_API_KEY`: server is not configured for AI.
- Timeout/abort: AI responded too slowly.
- HTTP 429/quota: AI is overloaded.
- Invalid JSON/missing target/length: AI returned an invalid example.

## API

- `generateWordExample { wordId }` returns `{ sentence, translation, target }`
  without writing to the database.
- `updateWordExample { wordId, sentence, translation, target? }` updates the
  three columns for the owning user; an empty sentence clears the example.
- `bulkAddWords` now returns failures alongside `insertedCount`.

## Out of scope

- More than one example per word.
- Changes to the maintenance action `repairDuplicateExamples`.
- Committing to git.
