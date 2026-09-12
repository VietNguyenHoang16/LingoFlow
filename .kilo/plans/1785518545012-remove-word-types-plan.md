# Plan: Remove 5 Word Types from LingoFlow

## Goal
Remove `collocation`, `grammar`, `phrasal_verb`, `idiom`, `interjection` from the LingoFlow app. Before removal, export existing data to a JSON file so it can be imported into a new app. After confirmed export, delete those words from the database and remove all traces from app code.

## Affected Boundaries
- **Backend**: `api/lingoflow.js` — export/delete actions, CATEGORIES array
- **Flutter app**: `lib/widgets/word_type_utils.dart`, `lib/theme/app_theme.dart`, `lib/services/word_type_classifier.dart`, `lib/pages/profile_page.dart`
- **Database**: PostgreSQL via backend — words with excluded types

## Excluded Types
`collocation`, `grammar`, `phrasal_verb`, `idiom`, `interjection`

## Implementation Tasks

### 1. Add backend export action (`api/lingoflow.js`)
- Add `exportWordsByTypes` action:
  - Query all `vocabulary_words` joined with `vocabulary_lists` where `word_type` is in the excluded types
  - Return full word rows as JSON array with all fields
  - Include `list_name` and `category` for context

### 2. Add backend delete action (`api/lingoflow.js`)
- Add `deleteWordsByTypes` action:
  - Delete all `vocabulary_words` where `word_type` is in the excluded types
  - Return `{ deletedCount: number }`

### 3. Add export/delete UI in ProfilePage (`lib/pages/profile_page.dart`)
- Add a new card/section titled "Chuyen du lieu sang app moi" (or similar)
- Button 1: "Export du lieu" — calls `exportWordsByTypes`, triggers file download
  - On web: use anchor download with base64/data URI
  - On mobile: use `dart:io` to write file and share
  - Show success/error snackbar
- Button 2: "Xoa khoi database" — calls `deleteWordsByTypes`
  - Show confirmation dialog before deleting
  - Show success snackbar with deleted count
- Add loading states during API calls

### 4. Remove 5 types from Flutter constants (`lib/widgets/word_type_utils.dart`)
- Remove from `kWordTypeKeys` list
- Remove from `kWordTypeLabel` map
- Remove from `kWordTypeShortLabel` map
- Remove from `kWordTypeIcons` map
- Remove from `kWordTypeAbbreviations` map
- Remove entries 8-12 from `kPosNumberToKey` map

### 5. Remove colors from theme (`lib/theme/app_theme.dart`)
- Remove 5 entries from `_wordTypeColorsLight`
- Remove 5 entries from `_wordTypeColorsDark`

### 6. Update classifier mapping (`lib/services/word_type_classifier.dart`)
- Remove `'interjection': 'interjection'` and `'exclamation': 'interjection'` from `_posToKey`

### 7. Update backend CATEGORIES array (`api/lingoflow.js`)
- Remove the 5 types from the `CATEGORIES` array
- Existing `NOT IN ('grammar', 'collocation')` filters can remain — they will simply match nothing after deletion

### 8. Verify no remaining hardcoded references
- After edits, grep for any remaining references to the 5 types in `.dart` and `.js` files
- Ensure no runtime errors from missing map keys

## Data Flow for Export & Delete
1. User opens **Profile** page
2. User taps **Export du lieu**
3. App calls backend `exportWordsByTypes` with `userId`
4. Backend returns JSON array of matching words
5. App triggers file download/save
6. User confirms file is saved
7. User taps **Xoa khoi database**
8. App shows confirmation dialog
9. On confirm, app calls `deleteWordsByTypes` with `userId`
10. Backend deletes rows and returns `deletedCount`
11. App shows success message

## Edge Cases
- No words of excluded types: export returns `[]`, delete returns `{ deletedCount: 0 }`
- Export fails: show error snackbar, do not allow delete
- Delete called without export: show warning but allow (user may have exported manually)

## Validation
- Run `flutter analyze` after changes
- Verify dashboard no longer shows the 5 category cards
- Verify search, review, and stats exclude removed types
- Verify export produces valid JSON and delete removes correct rows
