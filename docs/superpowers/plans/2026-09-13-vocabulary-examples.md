# Vocabulary Example Manager Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add an authenticated, dependency-free web manager and API for one example per vocabulary word.

**Architecture:** Add three nullable example columns to `vocabulary_words`. Keep the existing Flutter action API unchanged and expose focused REST endpoints through new Vercel functions. Share authentication, schema migration, validation, and database helpers under `api/_lib`. Serve `web/example_manager.html` as a standalone page that reads the existing web session token.

**Tech Stack:** Node.js Vercel functions, PostgreSQL via `pg`, vanilla HTML/CSS/JavaScript, Node built-in test runner, existing Flutter/Vercel build.

## Global Constraints

- One word has zero or one example.
- Every database query is scoped to the bearer-token user.
- Store plain text only; the browser creates highlighting with DOM nodes.
- Do not add npm dependencies.
- Preserve `full_details` and the existing Flutter API behavior.

---

### Task 1: Add the tested example contract helpers

**Files:**
- Create: `api/_lib/examples.js`
- Create: `test/api_examples.test.js`

**Interfaces:**
- Produces `validateExamplePayload(payload)` returning normalized `{ sentence, translation, target }` or throwing a validation error with `code` and `status`.
- Produces `parsePageParams(searchParams)` returning bounded `{ page, pageSize, query, hasExample }`.

- [ ] **Step 1: Write failing tests** for valid trimming, required sentence/translation, length limits, boolean filtering, and bounded pagination.
- [ ] **Step 2: Run `node --test test/api_examples.test.js`** and confirm the missing helper exports fail.
- [ ] **Step 3: Implement the smallest pure helpers and shared PostgreSQL/auth utility functions.**
- [ ] **Step 4: Run `node --test test/api_examples.test.js`** and confirm all helper tests pass.

### Task 2: Add schema migration and paginated word listing

**Files:**
- Modify: `api/_lib/examples.js`
- Create: `api/examples.js`

**Interfaces:**
- `GET /api/examples?page=1&pageSize=50&q=&hasExample=` returns `{ data: [...], pagination: {...} }`.
- Each row includes `id`, `word`, `meaning`, `pronunciation`, `topicTag`, `exampleSentence`, `exampleTranslation`, and `exampleTarget`.

- [ ] **Step 1: Add `ensureExampleSchema()`** with idempotent `ALTER TABLE ... ADD COLUMN IF NOT EXISTS` behavior.
- [ ] **Step 2: Implement bearer-token lookup** and the user-scoped paginated SQL query with parameterized filters.
- [ ] **Step 3: Return the standard success and error envelopes** from the list handler.
- [ ] **Step 4: Run the helper tests and inspect the endpoint syntax with `node --check api/examples.js`.**

### Task 3: Add single-word example CRUD

**Files:**
- Create: `api/words/[wordId]/example.js`
- Modify: `api/_lib/examples.js`

**Interfaces:**
- `GET /api/words/:wordId/example` returns the owned word and its example or HTTP 404.
- `PUT /api/words/:wordId/example` accepts `{ sentence, translation, target? }` and returns the saved record.
- `DELETE /api/words/:wordId/example` clears the three columns and returns `{ deleted: true }`.

- [ ] **Step 1: Add pure word-id and response mapping tests** to the existing Node test file.
- [ ] **Step 2: Run the tests and confirm the new behavior fails before route implementation.**
- [ ] **Step 3: Implement ownership lookup, validation, update, and delete queries.**
- [ ] **Step 4: Run `node --test test/api_examples.test.js` and `node --check api/words/[wordId]/example.js`.**

### Task 4: Replace the static prototype with the working manager page

**Files:**
- Modify: `web/example_manager.html`

**Interfaces:**
- Uses `GET /api/examples` for the word list.
- Uses the single-word CRUD endpoints for save/delete.

- [ ] **Step 1: Render a search field, paginated word list, selected-word editor, and empty/error/loading states.**
- [ ] **Step 2: Add token-aware fetch calls using the current `localStorage` session token.**
- [ ] **Step 3: Add safe target highlighting using text nodes and `<strong>`, never raw user HTML.**
- [ ] **Step 4: Add keyboard-friendly save behavior and delete confirmation without allowing multiple examples.**
- [ ] **Step 5: Run `node --check` against the extracted inline script or verify the page through the web build.**

### Task 5: Verify the vertical slice

**Files:**
- No additional production files.

- [ ] **Step 1: Run `node --test test/api_examples.test.js`.**
- [ ] **Step 2: Run `flutter test --no-pub`.**
- [ ] **Step 3: Run `npm run build:web`.**
- [ ] **Step 4: Review `git diff` and confirm the existing root prototype was not modified.**
