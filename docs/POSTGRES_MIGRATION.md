# PostgreSQL Migration

This project can now run from either:

- SQLite
- PostgreSQL

The app reads its database connection from:

- `DATABASE_URL`

If `DATABASE_URL` is not set, it falls back to SQLite.

## Why migrate

SQLite is fine for local or lightweight single-host use.

PostgreSQL is the correct next step when you need:

- more reliable multi-user access
- cloud deployment
- better concurrency
- safer long-term operational growth

## Requirements

Add a PostgreSQL driver before deploying to a Postgres-backed host.

Recommended package:

- `psycopg2-binary`

## Migration command

Once you have a PostgreSQL database URL, run:

```bash
source venv/bin/activate
python tools/migrate_sqlite_to_database.py instance/mice.db "postgresql://USER:PASSWORD@HOST:PORT/DBNAME"
```

This script:

1. connects to the target database
2. creates tables from the current models
3. clears existing target data
4. copies all supported tables from SQLite into the target database

## Supported tables

- user
- mouse
- breeding
- pup
- weight
- cage_transfer
- procedure
- calendar_event
- audit_log

## Render note

If you decide to deploy to Render or another cloud host:

1. create the PostgreSQL database first
2. set `DATABASE_URL`
3. then deploy the web service

## Important note

The in-app backup and restore pages are currently SQLite-only.

Once running on PostgreSQL, use provider-level backup tools for the database instead of the SQLite recovery buttons.
