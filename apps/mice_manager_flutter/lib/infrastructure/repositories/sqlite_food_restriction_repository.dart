import 'package:sqflite/sqflite.dart';

import '../../domain/models/food_restriction_entry.dart';
import '../../domain/models/food_restriction_experiment.dart';
import '../../domain/models/food_restriction_mouse.dart';
import '../../domain/repositories/food_restriction_repository.dart';
import '../database/local_database.dart';

class SqliteFoodRestrictionRepository implements FoodRestrictionRepository {
  SqliteFoodRestrictionRepository(this._localDatabase);

  final LocalDatabase _localDatabase;

  Future<Database> get _db async => _localDatabase.database;

  @override
  Future<void> deleteEntry(String entryId) async {
    final db = await _db;
    await db.delete(
      'food_restriction_entries',
      where: 'id = ?',
      whereArgs: [entryId],
    );
  }

  @override
  Future<void> deleteExperiment(String experimentId) async {
    final db = await _db;
    await db.transaction((txn) async {
      final mouseRows = await txn.query(
        'food_restriction_mice',
        columns: ['id'],
        where: 'experiment_id = ?',
        whereArgs: [experimentId],
      );
      final mouseIds = mouseRows.map((row) => row['id'] as String).toList();
      if (mouseIds.isNotEmpty) {
        final placeholders = List.filled(mouseIds.length, '?').join(', ');
        await txn.delete(
          'food_restriction_entries',
          where: 'experiment_mouse_id IN ($placeholders)',
          whereArgs: mouseIds,
        );
      }
      await txn.delete(
        'food_restriction_mice',
        where: 'experiment_id = ?',
        whereArgs: [experimentId],
      );
      await txn.delete(
        'food_restriction_experiments',
        where: 'id = ?',
        whereArgs: [experimentId],
      );
    });
  }

  @override
  Future<void> deleteExperimentMouse(String mouseId) async {
    final db = await _db;
    await db.transaction((txn) async {
      await txn.delete(
        'food_restriction_entries',
        where: 'experiment_mouse_id = ?',
        whereArgs: [mouseId],
      );
      await txn.delete(
        'food_restriction_mice',
        where: 'id = ?',
        whereArgs: [mouseId],
      );
    });
  }

  @override
  Future<List<FoodRestrictionEntry>> listEntries() async {
    final db = await _db;
    final rows = await db.query(
      'food_restriction_entries',
      orderBy: 'entry_date ASC, created_at ASC',
    );
    return rows.map(FoodRestrictionEntry.fromMap).toList();
  }

  @override
  Future<List<FoodRestrictionExperiment>> listExperiments() async {
    final db = await _db;
    final rows = await db.query(
      'food_restriction_experiments',
      orderBy: 'started_at DESC, created_at DESC',
    );
    return rows.map(FoodRestrictionExperiment.fromMap).toList();
  }

  @override
  Future<List<FoodRestrictionMouse>> listExperimentMice() async {
    final db = await _db;
    final rows = await db.query(
      'food_restriction_mice',
      orderBy: 'created_at DESC',
    );
    return rows.map(FoodRestrictionMouse.fromMap).toList();
  }

  @override
  Future<void> saveEntry(FoodRestrictionEntry entry) async {
    final db = await _db;
    await db.insert(
      'food_restriction_entries',
      entry.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<void> saveExperiment(FoodRestrictionExperiment experiment) async {
    final db = await _db;
    await db.insert(
      'food_restriction_experiments',
      experiment.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<void> saveExperimentMouse(FoodRestrictionMouse mouse) async {
    final db = await _db;
    await db.insert(
      'food_restriction_mice',
      mouse.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
}
