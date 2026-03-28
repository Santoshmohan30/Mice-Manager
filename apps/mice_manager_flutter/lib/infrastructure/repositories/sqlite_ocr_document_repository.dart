import 'package:sqflite/sqflite.dart';

import '../../domain/models/ocr_document.dart';
import '../../domain/repositories/ocr_document_repository.dart';
import '../database/local_database.dart';

class SqliteOCRDocumentRepository implements OCRDocumentRepository {
  SqliteOCRDocumentRepository(this._localDatabase);

  final LocalDatabase _localDatabase;

  Future<Database> get _db async => _localDatabase.database;

  @override
  Future<List<OCRDocument>> listAll() async {
    final db = await _db;
    final rows = await db.query(
      'ocr_documents',
      where: 'deleted_at IS NULL',
      orderBy: 'captured_at DESC',
    );
    return rows.map(OCRDocument.fromMap).toList();
  }

  @override
  Future<List<OCRDocument>> listDeleted() async {
    final db = await _db;
    final rows = await db.query(
      'ocr_documents',
      where: 'deleted_at IS NOT NULL',
      orderBy: 'deleted_at DESC',
    );
    return rows.map(OCRDocument.fromMap).toList();
  }

  @override
  Future<void> save(OCRDocument document) async {
    final db = await _db;
    await db.insert(
      'ocr_documents',
      document.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<void> archive(String documentId) async {
    final db = await _db;
    await db.update(
      'ocr_documents',
      {'deleted_at': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [documentId],
    );
  }

  @override
  Future<void> restore(String documentId) async {
    final db = await _db;
    await db.update(
      'ocr_documents',
      {'deleted_at': null},
      where: 'id = ?',
      whereArgs: [documentId],
    );
  }
}
