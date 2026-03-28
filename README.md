# Mice Manager

Mice Manager is an offline-first lab management project for tracking mice, breeding, procedures, cage-card intake, calendar tasks, and day-to-day colony operations.

This repository now contains two working paths:
- a Flask web app for local browser-based use
- a Flutter app for Android and macOS, designed as the longer-term desktop hub and field-device workflow

## What I Worked On Today

Today I pushed Mice Manager closer to the version I actually want to use in a lab instead of just a demo.

I finished the first real offline cross-platform setup:
- built the Android app as an APK
- built the macOS app as a `.app`
- kept local SQLite on-device so the app still works offline
- added local roles with an Owner-protected account flow
- improved mice entry, breeding, procedures, OCR history, and recovery behavior

I also pushed the mobile workflow forward:
- added offline OCR for cage cards
- added review-before-save instead of blind auto-fill
- added archive and restore for cage-card scans
- added CSV export and JSON sync bundles
- added a same-Wi-Fi Mac hub flow so the phone can scan a QR and import data from the Mac on the local network

On the product side, I cleaned up the UI and made it more usable:
- glass-style visual polish
- icon-based bottom navigation
- better dashboard summaries
- breeding-related calendar tasks like litter checks and weaning dates
- strain analytics split across LAF and LAB

There is still more to do, especially around stronger multi-user conflict handling, but the project is now in a much more real and testable place.

## Current Capabilities

- authenticated access with role-based permissions
- Owner / Admin / Staff / Viewer role separation
- mouse registry with add, edit, delete, duplicate protection, and age calculation
- required housing separation for `LAF` and `LAB`
- breeding and procedure tracking
- date-based task tracking with weaning support
- OCR-assisted cage-card intake
- cage-card archive and restore
- CSV export
- local JSON sync bundles
- same-Wi-Fi hub import flow between macOS and Android
- local backup, restore, and recovery tooling in the Flask app
- analytics and strain summaries

## Stack

- Python
- Flask
- SQLAlchemy
- SQLite
- Jinja2
- Dart
- Flutter
- Android ML Kit OCR
- Kotlin / Android platform tooling

## Repository Layout

```text
MiceManager/
├── app.py
├── config.py
├── extensions.py
├── models/
├── routes/
├── services/
├── templates/
├── static/
├── tests/
├── tools/
├── docs/
├── android-app/
├── apps/
│   └── mice_manager_flutter/
├── migrations/
└── requirements.txt
```

## Running The Flask App Locally

Foreground run:

```bash
cd /Users/sonny03/Documents/MiceManager
source venv/bin/activate
PORT=8000 python app.py
```

Background local launcher:

```bash
cd /Users/sonny03/Documents/MiceManager
./tools/start_local_server.sh
```

Stop the background session:

```bash
cd /Users/sonny03/Documents/MiceManager
./tools/stop_local_server.sh
```

## Running The Flutter App

Flutter project:

```bash
cd /Users/sonny03/Documents/MiceManager/apps/mice_manager_flutter
flutter pub get
```

Run on macOS:

```bash
flutter run -d macos
```

Build the macOS app:

```bash
flutter build macos
```

Run on Android:

```bash
flutter run -d android
```

Build the Android APK:

```bash
flutter build apk
```

## Local Access

- Flask app on local machine: `http://127.0.0.1:8000`
- Flask app on phone on the same Wi-Fi: `http://<local-ip>:8000`

## OCR Workflow

The current cage-card flow is review-first:

1. capture from camera or choose an image
2. run offline OCR
3. parse likely structured fields
4. review and correct values if needed
5. save into the local mice database

OCR is meant to reduce typing, not silently invent data.

## Sync Direction

The current sync model is local-first:

- Android works as the day-to-day field device
- macOS acts as the desktop hub
- sync works through local export/import bundles and same-Wi-Fi hub QR pairing

For a small lab team, this is a practical offline-first starting point. Future work should focus on stronger conflict-safe multi-user sync.

## Documentation

- [docs/ANDROID_SETUP.md](docs/ANDROID_SETUP.md)
- [docs/CROSS_PLATFORM_MVP_ARCHITECTURE.md](docs/CROSS_PLATFORM_MVP_ARCHITECTURE.md)
- [docs/LOCAL_RUN_AND_SCAN.md](docs/LOCAL_RUN_AND_SCAN.md)
- [docs/POSTGRES_MULTI_USER_SETUP.md](docs/POSTGRES_MULTI_USER_SETUP.md)
- [docs/PROJECT_SUMMARY_AND_INTERVIEW_GUIDE.md](docs/PROJECT_SUMMARY_AND_INTERVIEW_GUIDE.md)
- [docs/SYSTEM_DESIGN_NEXT_STEPS.md](docs/SYSTEM_DESIGN_NEXT_STEPS.md)
