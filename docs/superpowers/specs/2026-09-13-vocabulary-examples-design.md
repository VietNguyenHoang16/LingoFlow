# Spec: Vocabulary Example Manager

## Objective

Build a lightweight web page and authenticated API for managing one example per vocabulary word. Each example has an English sentence, a Vietnamese translation, and an optional target phrase to highlight.

Success means a logged-in user can search their words, select a word, create or update its example, delete it, and see the result without a full-page reload.

## Tech Stack

- Existing Vercel Node function and PostgreSQL database.
- Vanilla HTML, CSS, and JavaScript for the web page; no new frontend dependency.
- Existing bearer token stored by the LingoFlow web app in `localStorage`.

## API Contract

- `GET /api/examples?page=1&pageSize=50&q=&hasExample=` lists the authenticated user's words with pagination.
- `GET /api/words/:wordId/example` returns one word and its example.
- `PUT /api/words/:wordId/example` accepts `{ sentence, translation, target? }` and creates or updates the example.
- `DELETE /api/words/:wordId/example` clears the example for the word.
- All endpoints require `Authorization: Bearer <token>`.
- Success responses use `{ data: ... }`.
- Errors use `{ error: { code, message } }` with HTTP 401, 404, 422, or 500.

## Data Model

Add nullable columns to `vocabulary_words`:

- `example_sentence TEXT`
- `example_translation TEXT`
- `example_target VARCHAR(255)`

The existing `full_details` field remains unchanged. The new fields are deliberately separate so the manager does not parse or rewrite legacy word details.

## Web Behavior

- Load words in pages, defaulting to 50 rows.
- Search by word, meaning, or topic tag.
- Show whether a word has an example.
- Edit one selected example with sentence, translation, and optional target phrase fields.
- Save and delete through the API without reloading the page.
- Render user text with DOM text nodes; do not inject it as HTML.
- Highlight the target phrase in the preview when it is present.

## Commands

- Unit tests: `node --test test/api_examples.test.js`
- Flutter tests: `flutter test --no-pub`
- Web build: `npm run build:web`

## Project Structure

- `api/_lib/examples.js` — shared validation, authentication, schema, and query helpers.
- `api/examples.js` — paginated word list endpoint.
- `api/words/[wordId]/example.js` — single-word example CRUD endpoint.
- `web/example_manager.html` — standalone lightweight manager page.
- `test/api_examples.test.js` — pure validation and pagination tests.

## Boundaries

- Always: scope every query to the authenticated user, validate request bodies, use parameterized SQL, preserve `full_details`, and keep the page dependency-free.
- Ask first: changing the existing Flutter word editor, changing authentication, or adding a new npm dependency.
- Never: accept a client-provided user ID as authorization, expose another user's words, store raw HTML, or remove existing tests.

## Success Criteria

- Schema initialization adds the three columns without destroying existing data.
- A word can have zero or one example.
- Valid create/update/delete requests work for the authenticated owner.
- Invalid payloads return HTTP 422 with the standard error shape.
- Missing/invalid tokens return HTTP 401.
- A word owned by another user behaves as not found.
- The manager page searches, edits, saves, and deletes without page reload.
- The new unit tests pass and the production web build completes.

## Open Questions

None for this MVP.
