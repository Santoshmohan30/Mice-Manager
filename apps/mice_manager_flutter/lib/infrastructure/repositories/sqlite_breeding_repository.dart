import 'package:sqflite/sqflite.dart';

import '../../domain/models/breeding.dart';
import '../../domain/repositories/breeding_repository.dart';
import '../database/local_database.dart';

class SqliteBreedingRepository implements BreedingRepository {
  SqliteBreedingRepository(this._localDatabase);

  final LocalDatabase _localDatabase;

  Future<Database> get _db async => _localDatabase.database;

  @override
  Future<void> delete(String breedingId) async {
    final db = await _db;
    await db.delete('breeding', where: 'id = ?', whereArgs: [breedingId]);
  }

  @override
  Future<List<Breeding>> listAll() async {
    final db = await _db;
    final rows = await db.query('breeding', orderBy: 'started_at DESC');
    return rows.map(Breeding.fromMap).toList();
  }

  @override
  Future<void> save(Breeding breeding) async {
    final db = await _db;
    await db.insert(
      'breeding',
      breeding.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
}
