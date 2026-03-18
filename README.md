# Mice Manager

Mice Manager is a lab colony management system built to centralize mouse records, breeding workflows, procedure tracking, cage transfers, recovery operations, and mobile access in one place.

The project is currently structured as a Flask web application with a SQLite-backed data layer, a role-based authentication system, administrative recovery tooling, and an Android starter client that connects to the backend API for mobile access on the same network.

## Current Scope

The application currently supports:

- secure login with role-based access
- colony dashboard and searchable mouse registry
- strain and procedure-cohort separation
- breeding and pup tracking
- procedure logging
- cage transfer tracking
- calendar reminders
- CSV export
- backup and restore tooling
- audit logging
- analytics and cost estimation
- Android starter app for login and colony access

## Stack

- Python
- Flask
- SQLAlchemy
- SQLite
- Jinja templates
- Kotlin
- Jetpack Compose

## Project Structure

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

## Local Development

Create and activate the virtual environment, install dependencies, and run the app:

```bash
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
python app.py
```

The web app will be available at:

- `http://127.0.0.1:8000` on the local machine
- `http://<your-local-ip>:8000` from another device on the same network

Default admin credentials:

- username: `admin`
- password: `ChangeMe123!`

These defaults should be changed immediately in real usage.

## Data Model Notes

The application distinguishes between:

- `genetic_strain`
- `procedure_cohort`

This prevents procedure or surgery labels such as AAV or implant cohorts from being mixed into core strain analytics.

Mouse records also support:

- cage
- rack location
- project
- training flag
- soft-delete/archive state

## Backup and Recovery

The app includes a recovery workflow through the admin interface.

Features include:

- manual backup creation
- downloadable backup files
- restore from backup
- automatic safety backup before restore

A helper backup script is also included:

```bash
source venv/bin/activate
python tools/create_backup.py
```

## Android App

The Android client is located in `android-app/`.

It currently includes:

- login against the Flask API
- dashboard summary access
- mouse list access

To run it:

1. open `android-app` in Android Studio
2. make sure the Flask backend is already running
3. set the backend IP in the Android app if using a real phone
4. run the app on a device or emulator

Additional Android setup details are documented in:

- [docs/ANDROID_SETUP.md](docs/ANDROID_SETUP.md)

## Documentation

Project documentation is included for operations, deployment, and planning:

- [docs/ANDROID_SETUP.md](docs/ANDROID_SETUP.md)
- [docs/PRIVATE_FREE_DEPLOYMENT.md](docs/PRIVATE_FREE_DEPLOYMENT.md)
- [docs/PROJECT_SUMMARY_AND_INTERVIEW_GUIDE.md](docs/PROJECT_SUMMARY_AND_INTERVIEW_GUIDE.md)
- [docs/EXECUTION_CHECKLIST.md](docs/EXECUTION_CHECKLIST.md)

## Operational Notes

- the project is currently optimized for private/internal deployment
- SQLite is sufficient for early-stage or single-lab use
- PostgreSQL is the recommended next step for multi-user multi-lab production scaling
- archived mice are soft-deleted and can be restored
- audit logging is available for administrative visibility

## Status

This repository contains an actively evolving internal application intended to become a more complete operational platform for colony management, analytics, recovery, and mobile workflows.
