# Repository Guidelines

## Project Structure & Module Organization

- `app/`: Flutter application (Material 3). Entry in `app/lib/main.dart`, routing in `app/lib/routing/`, feature modules in `app/lib/features/`, shared UI in `app/lib/ui/`.
- `packages/`: Reusable layers
  - `packages/domain/`: entities, use cases, repository interfaces
  - `packages/data/`: Drift database + repository implementations + backup/export/notifications
  - `packages/ai/`: OpenAI-compatible client + schemas/parsing
- `.github/workflows/`: CI (Android APK build).
- Local-only (gitignored): `docs/`, `.tooling/`, `.tmp_*/`.

## Build, Test, and Development Commands

Prereqs: Flutter `3.38.6` (Dart `3.10.7`), Android SDK, Java `17`.

From `app/`:

- `flutter pub get`: install dependencies.
- `flutter run`: run on an Android device/emulator.
- `flutter test`: run unit/widget tests.
- `flutter analyze`: run static analysis (uses `flutter_lints`).
- `flutter build apk --release`: build a release APK (`app/build/app/outputs/flutter-apk/app-release.apk`).

Codegen (when changing Drift schema/migrations):

- `cd packages/data && dart run build_runner build --delete-conflicting-outputs`

## Coding Style & Naming Conventions

- Formatting: run `dart format .` (or `flutter format .`) before pushing.
- Indentation: 2 spaces (standard Dart).
- Naming: files `snake_case.dart`, types `PascalCase`, members `lowerCamelCase`.
- Layering: keep domain logic in `packages/domain`, IO/DB in `packages/data`, AI client logic in `packages/ai`, and UI/state/routing in `app/`.

## Testing Guidelines

- Tests live in `app/test/` (and `packages/*/test/` if adding package-level tests).
- Name test files `*_test.dart`.
- Prefer pure-Dart tests for domain/data logic and small widget tests for UI behavior.

## Commit & Pull Request Guidelines

- Commit messages follow Conventional Commits (examples from history): `feat: ...`, `fix(android): ...`, `chore: ...`, `docs: ...`, `ci: ...`.
- PRs include: a clear description, linked issue (if any), and screenshots/GIFs for UI changes.
- Before opening a PR: run `flutter test` + `flutter analyze` from `app/`.
- Never commit secrets (API keys, keystores) or local artifacts (`docs/`, `.tmp_*`).
