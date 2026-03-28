# Mice Manager Flutter App

This folder contains the offline-first Flutter version of Mice Manager for:

- macOS desktop
- Android field use

The goal of this app is straightforward:
- macOS acts as the local hub
- Android acts as the day-to-day lab device
- both stay usable offline with local SQLite storage

## Current status

This is no longer just a starter scaffold. The app now includes working feature slices for:

- local sign-in and role-aware session handling
- owner-protected account model
- mice add, edit, delete, duplicate protection, and age calculation
- `LAF` / `LAB` housing separation
- breeding and procedures
- date-based task tracking and weaning workflow support
- offline OCR intake on Android
- OCR history with archive and restore
- local CSV export
- JSON sync bundle export/import
- same-Wi-Fi Mac hub QR sync flow
- Android APK builds
- macOS `.app` builds

## Still in progress

The direction is solid, but a few areas still need another pass before this should be treated as a finished team product:

- stronger multi-user conflict handling
- secure owner recovery flow
- richer macOS hub-side sync management
- more complete analytics views
- tighter OCR tuning for real lab card layouts

## Run locally

From this folder:

```bash
flutter pub get
```

Run on macOS:

```bash
flutter run -d macos
```

Run on Android:

```bash
flutter run -d android
```

Build macOS:

```bash
flutter build macos
```

Build Android APK:

```bash
flutter build apk
```
