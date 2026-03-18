import sqlite3
import sys
from pathlib import Path


TABLES = ["mouse", "breeding", "pup", "procedure", "calendar_event", "user", "cage_transfer", "weight"]


def table_count(connection, table_name):
    cursor = connection.execute(f"SELECT COUNT(*) FROM {table_name}")
    return cursor.fetchone()[0]


def existing_ids(connection, table_name):
    try:
        cursor = connection.execute(f"SELECT id FROM {table_name} ORDER BY id")
        return {row[0] for row in cursor.fetchall()}
    except sqlite3.OperationalError:
        return set()


def main():
    if len(sys.argv) != 3:
        print("Usage: python tools/database_recovery_report.py <db_one> <db_two>")
        sys.exit(1)

    db_one = Path(sys.argv[1])
    db_two = Path(sys.argv[2])

    if not db_one.exists() or not db_two.exists():
        print("One or both database files do not exist.")
        sys.exit(1)

    with sqlite3.connect(db_one) as left, sqlite3.connect(db_two) as right:
        print(f"Comparing:\n- {db_one}\n- {db_two}\n")
        for table in TABLES:
            try:
                left_count = table_count(left, table)
                right_count = table_count(right, table)
            except sqlite3.OperationalError:
                print(f"{table}: table missing in one of the databases")
                continue

            left_ids = existing_ids(left, table)
            right_ids = existing_ids(right, table)

            only_left = sorted(left_ids - right_ids)
            only_right = sorted(right_ids - left_ids)

            print(f"{table}:")
            print(f"  left count:  {left_count}")
            print(f"  right count: {right_count}")
            print(f"  ids only in left:  {only_left[:20]}{' ...' if len(only_left) > 20 else ''}")
            print(f"  ids only in right: {only_right[:20]}{' ...' if len(only_right) > 20 else ''}")
            print()


if __name__ == "__main__":
    main()
