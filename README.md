# Mice Manager

I built Mice Manager as an offline-first lab management project for tracking mice, breeding, procedures, cage-card intake, calendar tasks, food restriction workflows, and day-to-day colony operations.

This repository currently contains two working paths:
- a Flask web app for local browser-based use
- a Flutter app for Android and macOS, which I use as the longer-term desktop hub and field-device workflow

## Project Summary

I started this project as a practical tool for lab work and kept extending it toward a more complete cross-platform system. My goal has been to make it useful in the actual daily flow of a mouse colony, not just as a demo app.

The current version includes:
- a modular Flask backend and browser-based interface
- an offline-first Flutter app for Android and macOS
- local SQLite storage on-device
- role-aware access with protected owner controls
- mice registry, breeding, procedures, OCR intake, task tracking, food restriction, and export workflows

I have been treating this as both a working lab product and a serious systems design project, so I have focused on modular data models, shared cross-platform architecture, offline-first behavior, and clean feature boundaries.

## Current Capabilities

- authenticated access with role-based permissions
- Owner / Admin / Staff / Viewer role separation
- mouse registry with add, edit, delete, duplicate protection, age calculation, cage-card search, rack number, and rack location
- required housing separation for `LAF` and `LAB`
- breeding and procedure tracking
- date-based task tracking with weaning support
- OCR-assisted cage-card intake
- cage-card archive and restore
- food restriction and body weight tracking by experiment
- CSV export and Excel export
- local JSON sync bundles
- same-Wi-Fi reviewed sync flow between macOS and Android
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

From the Flutter project:

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

The current cage-card flow is review-first, which is intentional:

1. capture from camera or choose an image
2. run offline OCR
3. parse likely structured fields
4. review and correct values if needed
5. save into the local mice database

I treat OCR as an assistant for data entry, not as a source of truth.

## Sync Direction

The sync model is local-first:

- Android works as the day-to-day field device
- macOS acts as the desktop hub
- sync works through local export/import bundles and same-Wi-Fi hub QR pairing
- incoming phone syncs can be reviewed on the Mac side before they are applied

For a small lab team, this is a practical offline-first starting point. My next architecture priority is stronger conflict-safe multi-user sync and clearer review flows at the hub.

## Documentation

- [docs/ANDROID_SETUP.md](docs/ANDROID_SETUP.md)
- [docs/CROSS_PLATFORM_MVP_ARCHITECTURE.md](docs/CROSS_PLATFORM_MVP_ARCHITECTURE.md)
- [docs/LOCAL_RUN_AND_SCAN.md](docs/LOCAL_RUN_AND_SCAN.md)
- [docs/POSTGRES_MULTI_USER_SETUP.md](docs/POSTGRES_MULTI_USER_SETUP.md)
- [docs/PROJECT_SUMMARY_AND_INTERVIEW_GUIDE.md](docs/PROJECT_SUMMARY_AND_INTERVIEW_GUIDE.md)
- [docs/SYSTEM_DESIGN_NEXT_STEPS.md](docs/SYSTEM_DESIGN_NEXT_STEPS.md)
