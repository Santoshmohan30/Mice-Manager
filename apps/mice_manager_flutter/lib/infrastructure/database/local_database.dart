import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';

class LocalDatabase {
  LocalDatabase();

  static const _databaseName = 'mice_manager.db';
  static const _databaseVersion = 6;

  Database? _database;

  Future<Database> get database async {
    if (_database != null) {
      return _database!;
    }
    _database = await _openDatabase();
    return _database!;
  }

  Future<Database> _openDatabase() async {
    final databasesPath = await getDatabasesPath();
    final dbPath = path.join(databasesPath, _databaseName);

    return openDatabase(
      dbPath,
      version: _databaseVersion,
      onCreate: (db, version) async {
        await _createSchema(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await _createBreedingTable(db);
          await _createProcedureTable(db);
        }
        if (oldVersion < 3) {
          await _createOCRDocumentsTable(db);
          await _createSyncPackagesTable(db);
        }
        if (oldVersion < 4) {
          await _createUserAccountsTable(db);
          await _createAppSessionTable(db);
        }
        if (oldVersion < 5) {
          await db.execute(
            'ALTER TABLE ocr_documents ADD COLUMN deleted_at TEXT',
          );
        }
        if (oldVersion < 6) {
          await _createCalendarTasksTable(db);
        }
      },
    );
  }

  Future<void> _createSchema(Database db) async {
    await db.execute('''
      CREATE TABLE mice (
        id TEXT PRIMARY KEY,
        housing_type TEXT NOT NULL,
        strain TEXT NOT NULL,
        gender TEXT NOT NULL,
        genotype TEXT NOT NULL,
        date_of_birth TEXT NOT NULL,
        cage_number TEXT NOT NULL,
        rack_location TEXT,
        room TEXT,
        is_alive INTEGER NOT NULL,
        status TEXT NOT NULL,
        date_of_death TEXT,
        death_reason TEXT,
        notes TEXT,
        created_at TEXT,
        updated_at TEXT
      )
    ''');
    await _createBreedingTable(db);
    await _createProcedureTable(db);
    await _createOCRDocumentsTable(db);
    await _createSyncPackagesTable(db);
    await _createUserAccountsTable(db);
    await _createAppSessionTable(db);
    await _createCalendarTasksTable(db);
  }

  Future<void> _createBreedingTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS breeding (
        id TEXT PRIMARY KEY,
        male_mouse_id TEXT NOT NULL,
        female_mouse_id TEXT NOT NULL,
        started_at TEXT NOT NULL,
        ended_at TEXT,
        notes TEXT
      )
    ''');
  }

  Future<void> _createProcedureTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS procedures (
        id TEXT PRIMARY KEY,
        mouse_id TEXT NOT NULL,
        name TEXT NOT NULL,
        performed_at TEXT NOT NULL,
        performed_by TEXT,
        notes TEXT
      )
    ''');
  }

  Future<void> _createOCRDocumentsTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS ocr_documents (
        id TEXT PRIMARY KEY,
        device_id TEXT NOT NULL,
        source_path TEXT NOT NULL,
        raw_text TEXT NOT NULL,
        parsed_fields_json TEXT,
        image_metadata_json TEXT,
        review_status TEXT NOT NULL,
        captured_at TEXT NOT NULL
        ,deleted_at TEXT
      )
    ''');
  }

  Future<void> _createSyncPackagesTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS sync_packages (
        id TEXT PRIMARY KEY,
        version TEXT NOT NULL,
        created_at TEXT NOT NULL,
        device_source_id TEXT NOT NULL,
        bundle_path TEXT NOT NULL,
        notes TEXT
      )
    ''');
  }

  Future<void> _createUserAccountsTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS user_accounts (
        id TEXT PRIMARY KEY,
        username TEXT NOT NULL UNIQUE,
        role TEXT NOT NULL,
        password_hash TEXT NOT NULL,
        is_owner INTEGER NOT NULL,
        is_protected INTEGER NOT NULL,
        is_active INTEGER NOT NULL,
        recovery_key_hint TEXT,
        created_at TEXT,
        updated_at TEXT
      )
    ''');
  }

  Future<void> _createAppSessionTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS app_session (
        id INTEGER PRIMARY KEY,
        user_id TEXT,
        updated_at TEXT
      )
    ''');
  }

  Future<void> _createCalendarTasksTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS calendar_tasks (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        task_type TEXT NOT NULL,
        due_date TEXT NOT NULL,
        is_done INTEGER NOT NULL,
        source_type TEXT,
        source_id TEXT,
        notes TEXT,
        completed_at TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');
  }
}
