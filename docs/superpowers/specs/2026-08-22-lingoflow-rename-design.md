# LingoFlow Project Rename Design

## Goal

Rename the local Flutter project from `vocab` to `lingoflow` while keeping the installed-app identity, persisted data, and backend contracts stable.

## Scope

- Rename the project directory to `lingoflow` after source changes are verified.
- Change the Dart package name to `lingoflow` and update the test package imports.
- Change local project/build names and desktop product/window labels to `LingoFlow` or `lingoflow` as appropriate.
- Change iOS display name from `Vocab`/`vocab` to `LingoFlow`.
- Rename the ignored IntelliJ module file to `lingoflow.iml` when present.

## Compatibility constraints

- Keep Android `namespace`, `applicationId`, and Kotlin package `com.example.vocab`.
- Keep iOS/macOS bundle identifiers `com.example.vocab` and test bundle identifiers.
- Keep Linux `APPLICATION_ID` as `com.example.vocab`.
- Keep `https://vocab-virid.vercel.app`, `/api/lingoflow`, database table names, and notification channel IDs unchanged.
- Do not modify unrelated existing working-tree changes or untracked files.
- Do not mass-replace the word `vocabulary`; it describes product content, not the old project name.

## Verification

- Confirm source references use `package:lingoflow` where the package name changes.
- Confirm preserved IDs and backend URLs remain unchanged.
- Run `flutter pub get`, `flutter analyze`, and `flutter test`.
- Run a Windows build if the local Flutter toolchain supports it.
- Confirm the old directory is absent and the new directory exists after the move.
