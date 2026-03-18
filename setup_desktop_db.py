#!/usr/bin/env python3
"""
Safe database setup for desktop application
This script only creates missing tables without affecting existing data
"""

import sqlite3
import os

def setup_desktop_database():
    """Safely create missing tables for desktop app"""
    
    db_path = 'mice.db'
    
    if not os.path.exists(db_path):
        print(f"Database file {db_path} not found!")
        return
    
    # Connect to existing database
    conn = sqlite3.connect(db_path)
    cursor = conn.cursor()
    
    # Check what tables exist
    cursor.execute("SELECT name FROM sqlite_master WHERE type='table';")
    existing_tables = [row[0] for row in cursor.fetchall()]
    print(f"Existing tables: {existing_tables}")
    
    # Define missing tables (only create if they don't exist)
    tables_to_create = {
        'breeding': '''
            CREATE TABLE IF NOT EXISTS breeding (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                male_id INTEGER,
                female_id INTEGER,
                pair_date DATE,
                litter_count INTEGER,
                litter_date DATE,
                wean_date DATE,
                notes TEXT,
                FOREIGN KEY (male_id) REFERENCES mouse (id),
                FOREIGN KEY (female_id) REFERENCES mouse (id)
            )
        ''',
        
        'procedure': '''
            CREATE TABLE IF NOT EXISTS procedure (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                mouse_id INTEGER,
                type TEXT,
                date DATE,
                notes TEXT,
                FOREIGN KEY (mouse_id) REFERENCES mouse (id)
            )
        ''',
        
        'calendar_event': '''
            CREATE TABLE IF NOT EXISTS calendar_event (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                title TEXT,
                date DATE,
                category TEXT,
                notes TEXT
            )
        ''',
        
        'pup': '''
            CREATE TABLE IF NOT EXISTS pup (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                breeding_id INTEGER,
                sex TEXT,
                genotype TEXT,
                birth_date DATE,
                notes TEXT,
                FOREIGN KEY (breeding_id) REFERENCES breeding (id)
            )
        ''',
        
        'user': '''
            CREATE TABLE IF NOT EXISTS user (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                username TEXT UNIQUE,
                email TEXT,
                password_hash TEXT
            )
        ''',
        
        'weight': '''
            CREATE TABLE IF NOT EXISTS weight (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                mouse_id INTEGER,
                weight REAL,
                date DATE,
                notes TEXT,
                FOREIGN KEY (mouse_id) REFERENCES mouse (id)
            )
        ''',
        
        'cage_transfer': '''
            CREATE TABLE IF NOT EXISTS cage_transfer (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                mouse_id INTEGER,
                new_cage TEXT,
                transfer_date DATE,
                notes TEXT,
                FOREIGN KEY (mouse_id) REFERENCES mouse (id)
            )
        '''
    }
    
    # Create only missing tables
    created_tables = []
    for table_name, create_sql in tables_to_create.items():
        if table_name not in existing_tables:
            try:
                cursor.execute(create_sql)
                created_tables.append(table_name)
                print(f"Created table: {table_name}")
            except Exception as e:
                print(f"Error creating table {table_name}: {e}")
        else:
            print(f"Table {table_name} already exists - skipping")
    
    # Commit changes
    conn.commit()
    conn.close()
    
    if created_tables:
        print(f"\nSuccessfully created {len(created_tables)} new tables: {created_tables}")
        print("Your existing data is safe and unchanged!")
    else:
        print("\nAll necessary tables already exist. No changes made.")

if __name__ == "__main__":
    print("Setting up desktop database safely...")
    setup_desktop_database()
    print("Done!") 