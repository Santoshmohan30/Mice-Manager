import 'package:sqflite/sqflite.dart';

import '../../domain/models/housing_type.dart';
import '../../domain/models/mouse.dart';
import '../../domain/models/mouse_archive_snapshot.dart';
import '../../domain/repositories/mouse_repository.dart';
import '../database/local_database.dart';

class SqliteMouseRepository implements MouseRepository {
  SqliteMouseRepository(this._localDatabase);

  final LocalDatabase _localDatabase;

  Future<Database> get _db async => _localDatabase.database;

  @override
  Future<void> delete(String mouseId) async {
    final db = await _db;
    await db.delete(
      'mice',
      where: 'id = ?',
      whereArgs: [mouseId],
    );
  }

  @override
  Future<List<Mouse>> listAll() async {
    final db = await _db;
    final rows = await db.query(
      'mice',
      orderBy: 'created_at DESC',
    );
    return rows.map(Mouse.fromMap).toList();
  }

  @override
  Future<List<Mouse>> listByHousingType(HousingType housingType) async {
    final db = await _db;
    final rows = await db.query(
      'mice',
      where: 'housing_type = ?',
      whereArgs: [housingType.storageValue],
      orderBy: 'created_at DESC',
    );
    return rows.map(Mouse.fromMap).toList();
  }

  @override
  Future<void> save(Mouse mouse) async {
    final db = await _db;
    await db.insert(
      'mice',
      mouse.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<Mouse?> findById(String mouseId) async {
    final db = await _db;
    final rows = await db.query(
      'mice',
      where: 'id = ?',
      whereArgs: [mouseId],
      limit: 1,
    );
    if (rows.isEmpty) {
      return null;
    }
    return Mouse.fromMap(rows.first);
  }

  @override
  Future<void> saveArchiveSnapshot(MouseArchiveSnapshot snapshot) async {
    final db = await _db;
    await db.insert(
      'mouse_archive_snapshots',
      snapshot.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<List<MouseArchiveSnapshot>> listArchiveSnapshots() async {
    final db = await _db;
    final rows = await db.query(
      'mouse_archive_snapshots',
      orderBy: 'archived_at DESC',
    );
    return rows.map(MouseArchiveSnapshot.fromMap).toList();
  }

  @override
  Future<void> markSnapshotRestored(
    String snapshotId, {
    String? restoredBy,
  }) async {
    final db = await _db;
    await db.update(
      'mouse_archive_snapshots',
      {
        'restored_at': DateTime.now().toIso8601String(),
        'restored_by': restoredBy,
      },
      where: 'id = ?',
      whereArgs: [snapshotId],
    );
  }
}
