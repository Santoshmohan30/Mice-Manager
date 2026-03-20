# Mice Manager

Mice Manager is a private colony management application for tracking mouse records, breeding activity, procedures, cage transfers, scheduling, recovery operations, and day-to-day lab administration from a single system.

The current project is built around a Flask web application with a SQLite data store for local use and a companion Android client for mobile workflows on the same network.

## Core Capabilities

- authenticated access with role-based permissions
- colony dashboard and mouse registry
- separation of genetic strains and procedure cohorts
- breeding, pups, and procedure tracking
- cage transfer logging
- calendar reminders
- CSV export
- backup and recovery tools
- audit history for administrative activity
- analytics, rack summaries, and colony cost estimates
- mobile API endpoints and Android client support
- cage-card scan workflow for faster record entry

## Stack

- Python
- Flask
- SQLAlchemy
- SQLite
- Jinja2
- Kotlin
- Jetpack Compose

## Repository Layout

```text
MiceManager/
├── app.py
├── extensions.py
├── models/
├── templates/
├── static/
├── tools/
├── docs/
├── android-app/
├── migrations/
└── requirements.txt
```

## Running Locally

For a standard foreground run:

```bash
cd /Users/sonny03/Documents/MiceManager
source venv/bin/activate
PORT=8000 python app.py
```

For the local background launcher:

```bash
cd /Users/sonny03/Documents/MiceManager
./tools/start_local_server.sh
```

This starts the application on port `8000`, opens the browser locally, and keeps the session available for up to six hours by default.

To stop the local background session:

```bash
cd /Users/sonny03/Documents/MiceManager
./tools/stop_local_server.sh
```

## Access

- local machine: `http://127.0.0.1:8000`
- phone on the same Wi-Fi: `http://<local-ip>:8000`

## Mobile Workflow

The Android project is located in `android-app/`.

The mobile client supports:

- API login
- dashboard access
- mouse list and editing
- analytics access
- cage-card scan flow for OCR-assisted entry and archive matching

Additional setup notes are available in [docs/ANDROID_SETUP.md](docs/ANDROID_SETUP.md).

## Scan Workflow

The application includes a cage-card scan flow designed to reduce manual entry time.

Current flow:

- capture a cage card photo from a phone
- upload from camera or gallery
- run OCR
- parse likely cage-card fields
- review extracted values
- prefill a new mouse record or find a matching record for update or archive

OCR is intended to accelerate entry, not replace review. Extracted values should still be confirmed before saving.

## Data and Recovery

The local app uses SQLite for private deployment and includes recovery tooling intended for local operational use.

Recovery features include:

- manual backup creation
- downloadable backup files
- restore support
- safety backup before restore

## Operational Notes

- this repository is currently optimized for private local hosting
- SQLite is suitable for local and low-concurrency use
- PostgreSQL remains the recommended path for future multi-user hosted deployment
- archived mice are soft-deleted and can be restored
- administrative actions are written to the audit log

## Documentation

- [docs/ANDROID_SETUP.md](docs/ANDROID_SETUP.md)
- [docs/LOCAL_RUN_AND_SCAN.md](docs/LOCAL_RUN_AND_SCAN.md)
- [docs/PRIVATE_FREE_DEPLOYMENT.md](docs/PRIVATE_FREE_DEPLOYMENT.md)
- [docs/PROJECT_SUMMARY_AND_INTERVIEW_GUIDE.md](docs/PROJECT_SUMMARY_AND_INTERVIEW_GUIDE.md)
- [docs/EXECUTION_CHECKLIST.md](docs/EXECUTION_CHECKLIST.md)
- [docs/POSTGRES_MIGRATION.md](docs/POSTGRES_MIGRATION.md)
- [docs/RENDER_DEPLOY.md](docs/RENDER_DEPLOY.md)
