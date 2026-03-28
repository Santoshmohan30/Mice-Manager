import 'package:sqflite/sqflite.dart';

import '../../domain/models/sync_package.dart';
import '../../domain/models/update_manifest.dart';
import '../../domain/repositories/sync_repository.dart';
import '../database/local_database.dart';

class SqliteSyncRepository implements SyncRepository {
  SqliteSyncRepository(this._localDatabase);

  final LocalDatabase _localDatabase;

  Future<Database> get _db async => _localDatabase.database;

  @override
  Future<List<SyncPackage>> listSyncPackages() async {
    final db = await _db;
    final rows = await db.query('sync_packages', orderBy: 'created_at DESC');
    return rows.map(SyncPackage.fromMap).toList();
  }

  @override
  Future<UpdateManifest?> latestManifest() async {
    return null;
  }

  @override
  Future<void> saveSyncPackage(SyncPackage syncPackage) async {
    final db = await _db;
    await db.insert(
      'sync_packages',
      syncPackage.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<void> saveUpdateManifest(UpdateManifest manifest) async {}
}
