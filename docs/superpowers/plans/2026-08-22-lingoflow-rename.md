# LingoFlow Project Rename Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rename the local Flutter project and its non-breaking project/app metadata from `vocab` to `lingoflow` while preserving app identity and backend contracts.

**Architecture:** Keep platform package/bundle IDs and external service identifiers stable. Rename only the Dart package name, source imports, build/product names, and user-facing labels that identify the local app.

**Tech Stack:** Flutter/Dart, Android Gradle/Kotlin, iOS/macOS Xcode project files, Windows/Linux CMake runners.

## Global Constraints

- Keep Android/iOS/macOS/Linux identity IDs and the backend URL unchanged.
- Preserve unrelated dirty and untracked files already present in the repository.
- Use `LingoFlow` for user-facing labels and `lingoflow` for lowercase package/build identifiers.

---

### Task 1: Rename Dart package metadata and imports

**Files:**
- Modify: `pubspec.yaml:1`
- Modify: `README.md:1`
- Modify: `test/tts_settings_service_test.dart`, `test/widget_test.dart`, `test/word_type_badge_test.dart`

- [x] Change `name: vocab` to `name: lingoflow` and update only `package:vocab/...` imports to `package:lingoflow/...`.
- [x] Change the README heading to `# LingoFlow`.
- [x] Run `flutter pub get`.
- [x] Run targeted Flutter tests and confirm the package imports compile.

### Task 2: Rename platform product/display names without changing identity

**Files:**
- Modify: `ios/Runner/Info.plist`
- Modify: `macos/Runner/Configs/AppInfo.xcconfig`
- Modify: `macos/Runner.xcodeproj/project.pbxproj`
- Modify: `macos/Runner.xcodeproj/xcshareddata/xcschemes/Runner.xcscheme`
- Modify: `windows/CMakeLists.txt`, `windows/runner/Runner.rc`, `windows/runner/main.cpp`
- Modify: `linux/CMakeLists.txt`, `linux/runner/my_application.cc`

- [x] Set user-facing display/window/product names to `LingoFlow`.
- [x] Set lowercase executable names to `lingoflow` where the platform build system requires a machine name.
- [x] Preserve all `com.example.vocab` IDs and external URLs.
- [x] Run `flutter analyze` after the edits.

### Task 3: Rename local module file and project directory

**Files:**
- Rename: `vocab.iml` to `lingoflow.iml` if present.
- Rename directory: `C:\Users\ASUS\Desktop\Ung dung\vocab` to `C:\Users\ASUS\Desktop\Ung dung\lingoflow`.

- [x] Confirmed Flutter checks had finished before moving the directory.
- [x] Moved the exact directory after Tasks 1-2 passed.
- [x] From the parent directory, confirmed `lingoflow` exists and `vocab` does not.

### Task 4: Final compatibility verification

**Files:**
- Verify only; no additional source edits unless a direct rename reference is found.

- [x] Searched source/config for old project-name references and classified remaining matches as intentional stable IDs, URLs, data/schema names, or unrelated vocabulary terms.
- [x] Ran `flutter test` and `flutter analyze` from the renamed directory; existing widget-test/analyzer issues remain documented in the handoff.
- [x] Attempted `flutter build windows --debug`; the machine lacks the required Visual Studio toolchain.
- [x] Reviewed `git diff` and `git status`; unrelated user changes were preserved.
