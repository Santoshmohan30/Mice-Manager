# Mice Manager Project Summary and Interview Guide

This document explains what was built, how it works, and how to describe it in a clear way during an interview or demonstration.

## What the application is

Mice Manager is a lab colony management system for tracking:

- Mouse records
- Breeding pairs
- Pups
- Procedures
- Calendar reminders
- User accounts
- Backup and recovery

It is built as:

- Flask web application
- SQLite database for current storage
- JSON API for mobile support
- Android starter app for mobile access

## What was fixed

The original app had several problems:

- Some buttons pointed to routes that did not exist
- Some templates called backend functions that were missing
- Calendar form fields and backend field names did not match
- Cage transfer logging was incomplete and could fail
- Export logic used wrong model fields
- The UI was inconsistent across pages
- There was no real authentication flow
- There was no backup or recovery process

## What was added

### 1. Authentication and user roles

The app now has:

- Login page
- Logout
- Separate users
- Password reset for users
- Role-based permissions

Roles:

- `admin`
- `tech`
- `viewer`

Admins can manage users and recovery.

## 2. Working web UI

The UI was rebuilt into a consistent dashboard and navigation system.

Pages now include:

- Dashboard
- Mice
- Add Mouse
- Edit Mouse
- Cage Transfer
- Breeding
- Pups
- Procedures
- Calendar
- Export
- Users
- Recovery

## 3. Backup and recovery

A recovery system was added for the live SQLite database.

How it works:

- The live database is `instance/mice.db`
- An admin can create a backup from the Recovery page
- Each backup is stored in the `backups/` folder
- A backup can be downloaded
- A backup can be restored to the live app
- Before restore, the app automatically creates a safety backup

This means if the app crashes or data gets damaged, you have a path to recover it.

## 4. Mobile API

The backend now exposes API endpoints:

- `/api/login`
- `/api/dashboard`
- `/api/mice`
- `/api/mice/<id>`
- `/api/breeding`

These endpoints are used by the Android app and can also support future integrations.

## 5. Android starter app

An Android starter app was created.

It currently:

- Logs in
- Loads dashboard summary data
- Loads mouse data

This gives the project a real mobile direction and shows that the backend is ready for phone-based workflows.

## How the system works technically

### Backend

- Flask serves the website and API
- SQLAlchemy connects the app to SQLite
- Templates render the UI pages
- Sessions handle browser login
- Signed tokens handle API login for Android

### Database

Current database:

- SQLite

Live file:

- `instance/mice.db`

Older top-level `mice.db` is not the main active application database.

### Android

- Kotlin
- Jetpack Compose UI
- Simple HTTP requests to Flask API

## How to explain the choice of SQLite

Good explanation:

> I used SQLite for the current version because it is free, simple, and easy to manage during early development. I also prepared the app structure so it can move to PostgreSQL later when we need multiple labs and heavier simultaneous usage.

That is a strong answer because it shows:

- practicality
- cost awareness
- understanding of scalability

## How to explain scaling

Good explanation:

> SQLite is good for early-stage use and smaller teams, but for larger multi-lab usage I would migrate to PostgreSQL for better concurrency, safer multi-user writes, and easier production deployment.

## Best next moves

These are the strongest next steps for the project:

1. Compare both SQLite files and recover any missing historical mice records
2. Add automated scheduled backups
3. Add import/export tools for full data migration
4. Move from SQLite to PostgreSQL when multi-lab usage starts
5. Expand the Android app to support editing records
6. Add audit logs so every important change is traceable
7. Add search, pagination, and reporting for larger colonies

## Suggested interview explanation

You can say:

> I upgraded the project from a partially wired Flask prototype into a working lab management system. I fixed broken route connections, added authentication and role-based access, rebuilt the UI, corrected SQLite interactions, added CSV export, created backup and restore workflows, exposed a mobile API, and scaffolded an Android app so colony updates can eventually be done from a phone.

That is a strong summary because it explains both engineering fixes and product direction.

## What is free and what may cost money later

Free now:

- Flask
- SQLite
- PostgreSQL
- Android Studio
- Local hosting
- Local backups
- GitHub free usage

Possible future costs:

- Cloud hosting
- Managed database hosting
- Domain name
- Google Play developer fee if you publish the Android app

## Important operating notes

### To run the web app

```bash
source venv/bin/activate
python app.py
```

### To log in

- Username: `admin`
- Password: `ChangeMe123!`

### To make a backup

1. Log in as admin
2. Open the Recovery page
3. Click create backup
4. Download the backup file and keep a second copy outside the project folder

## What to remember during your interview

Focus on these themes:

- You improved reliability
- You added security
- You made the system more maintainable
- You prepared it for mobile usage
- You added recovery protection
- You planned the path from simple local storage to scalable multi-user architecture
