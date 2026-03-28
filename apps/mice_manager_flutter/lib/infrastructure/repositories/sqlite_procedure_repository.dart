import 'package:sqflite/sqflite.dart';

import '../../domain/models/procedure.dart';
import '../../domain/repositories/procedure_repository.dart';
import '../database/local_database.dart';

class SqliteProcedureRepository implements ProcedureRepository {
  SqliteProcedureRepository(this._localDatabase);

  final LocalDatabase _localDatabase;

  Future<Database> get _db async => _localDatabase.database;

  @override
  Future<void> delete(String procedureId) async {
    final db = await _db;
    await db.delete('procedures', where: 'id = ?', whereArgs: [procedureId]);
  }

  @override
  Future<List<Procedure>> listAll() async {
    final db = await _db;
    final rows = await db.query('procedures', orderBy: 'performed_at DESC');
    return rows.map(Procedure.fromMap).toList();
  }

  @override
  Future<void> save(Procedure procedure) async {
    final db = await _db;
    await db.insert(
      'procedures',
      procedure.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
}
