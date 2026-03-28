# Mice Manager Flutter Scaffold

This is the Phase 1 scaffold for the offline-first cross-platform version of Mice Manager.

## Targets

- macOS desktop app (`.app`)
- Android field app (`.apk` / `.aab`)

## Current phase

Phase 1 provides:

- shared domain models
- owner-protected authorization design
- housing type separation (`LAF` / `LAB`)
- repository and service abstractions
- platform adapter interfaces for OCR and updates
- a simple Flutter shell UI

## Not finished in Phase 1

- real SQLite persistence
- Android on-device OCR integration
- macOS local OCR integration
- local/LAN sync bundle transfer
- Android update package installation
- secure owner recovery key flow

## Run

Install Flutter first, then from this folder:

```bash
flutter pub get
flutter run -d macos
```

or:

```bash
flutter run -d android
```
