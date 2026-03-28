import 'package:sqflite/sqflite.dart';

import '../../domain/models/calendar_task.dart';
import '../../domain/repositories/calendar_task_repository.dart';
import '../database/local_database.dart';

class SqliteCalendarTaskRepository implements CalendarTaskRepository {
  SqliteCalendarTaskRepository(this._localDatabase);

  final LocalDatabase _localDatabase;

  Future<Database> get _db async => _localDatabase.database;

  @override
  Future<void> delete(String taskId) async {
    final db = await _db;
    await db.delete('calendar_tasks', where: 'id = ?', whereArgs: [taskId]);
  }

  @override
  Future<List<CalendarTask>> listAll() async {
    final db = await _db;
    final rows = await db.query(
      'calendar_tasks',
      orderBy: 'due_date ASC, created_at ASC',
    );
    return rows.map(CalendarTask.fromMap).toList();
  }

  @override
  Future<void> save(CalendarTask task) async {
    final db = await _db;
    await db.insert(
      'calendar_tasks',
      task.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
}
