import sqlite3
import sys
from pathlib import Path

from sqlalchemy import create_engine, delete
from sqlalchemy.orm import sessionmaker

ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from app import app
from extensions import db
from models import AuditLog, Breeding, CalendarEvent, CageTransfer, Mouse, Procedure, Pup, User, Weight


TABLE_MODELS = [
    ("user", User),
    ("mouse", Mouse),
    ("breeding", Breeding),
    ("pup", Pup),
    ("weight", Weight),
    ("cage_transfer", CageTransfer),
    ("procedure", Procedure),
    ("calendar_event", CalendarEvent),
    ("audit_log", AuditLog),
]


def normalize_database_url(url):
    if url.startswith("postgres://"):
        return url.replace("postgres://", "postgresql://", 1)
    return url


def fetch_rows(connection, table_name):
    connection.row_factory = sqlite3.Row
    cursor = connection.execute(f"SELECT * FROM {table_name}")
    return [dict(row) for row in cursor.fetchall()]


def clear_target_tables(session):
    for _, model in reversed(TABLE_MODELS):
        session.execute(delete(model))
    session.commit()


def insert_rows(session, table_name, model, rows):
    if not rows:
        return 0
    objects = [model(**row) for row in rows]
    session.add_all(objects)
    session.commit()
    print(f"Migrated {len(rows)} rows into {table_name}")
    return len(rows)


def main():
    if len(sys.argv) != 3:
        print("Usage: python tools/migrate_sqlite_to_database.py <sqlite_path> <target_database_url>")
        sys.exit(1)

    sqlite_path = Path(sys.argv[1])
    target_database_url = normalize_database_url(sys.argv[2])

    if not sqlite_path.exists():
        print(f"SQLite file not found: {sqlite_path}")
        sys.exit(1)

    target_engine = create_engine(target_database_url)
    with app.app_context():
        db.metadata.create_all(bind=target_engine)

    Session = sessionmaker(bind=target_engine)
    target_session = Session()

    with sqlite3.connect(sqlite_path) as source:
        clear_target_tables(target_session)
        total = 0
        for table_name, model in TABLE_MODELS:
            rows = fetch_rows(source, table_name)
            total += insert_rows(target_session, table_name, model, rows)

    print(f"Migration complete. Total rows migrated: {total}")


if __name__ == "__main__":
    main()
