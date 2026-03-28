# PostgreSQL Multi-User Setup

This app can now start cleanly on either SQLite or PostgreSQL.

## Why use PostgreSQL

Use PostgreSQL when:

- multiple people need to use the app at the same time
- the app will be hosted for shared lab access
- you want stronger concurrency and safer long-term scaling

## 1. Create a PostgreSQL database

Create a database with your provider or local Postgres installation.

Connection string format:

```bash
postgresql://USERNAME:PASSWORD@HOST:5432/DATABASE_NAME
```

## 2. Set the environment

Copy `.env.example` values into your own environment or export them directly:

```bash
export DATABASE_URL="postgresql://USERNAME:PASSWORD@HOST:5432/DATABASE_NAME"
export SECRET_KEY="replace-this-with-a-real-secret"
```

## 3. Migrate existing SQLite data

```bash
cd /Users/sonny03/Documents/MiceManager
source venv/bin/activate
python tools/migrate_sqlite_to_database.py instance/mice.db "$DATABASE_URL"
```

## 4. Start the app on PostgreSQL

```bash
cd /Users/sonny03/Documents/MiceManager
source venv/bin/activate
PORT=8000 DATABASE_URL="$DATABASE_URL" python app.py
```

## 5. Verify the app

```bash
python tools/verify_project.py
```

## Important notes

- The in-app backup and restore UI is SQLite-only.
- On PostgreSQL, use database-provider backups instead of the SQLite restore flow.
- For real multi-user production, use PostgreSQL plus a hosted app process instead of local-only laptop hosting.
