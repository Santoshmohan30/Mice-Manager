import 'package:crypto/crypto.dart';

import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../../core/constants/app_constants.dart';
import '../../domain/models/role.dart';
import '../../domain/models/user_account.dart';
import '../../domain/repositories/user_repository.dart';
import '../database/local_database.dart';

class SqliteUserRepository implements UserRepository {
  SqliteUserRepository(this._localDatabase);

  final LocalDatabase _localDatabase;

  Future<Database> get _db async => _localDatabase.database;

  @override
  Future<void> clearCurrentSession() async {
    final db = await _db;
    await db.delete('app_session');
  }

  @override
  Future<String?> currentSessionUserId() async {
    final db = await _db;
    final rows = await db.query('app_session', limit: 1);
    if (rows.isEmpty) {
      return null;
    }
    return rows.first['user_id'] as String?;
  }

  @override
  Future<void> ensureOwnerSeeded() async {
    final db = await _db;
    final result =
        await db.rawQuery('SELECT COUNT(*) AS count FROM user_accounts');
    final count = (result.first['count'] as int?) ?? 0;
    if (count > 0) {
      return;
    }
    final now = DateTime.now();
    final owner = UserAccount(
      id: 'owner-1',
      username: 'owner',
      role: Role.owner,
      passwordHash: sha256.convert(utf8.encode('Owner123!')).toString(),
      isOwner: true,
      isProtected: true,
      isActive: true,
      recoveryKeyHint: AppConstants.ownerRecoveryPlaceholder,
      createdAt: now,
      updatedAt: now,
    );
    await save(owner);
  }

  @override
  Future<UserAccount?> findById(String userId) async {
    final db = await _db;
    final rows = await db.query(
      'user_accounts',
      where: 'id = ?',
      whereArgs: [userId],
      limit: 1,
    );
    if (rows.isEmpty) {
      return null;
    }
    return UserAccount.fromMap(rows.first);
  }

  @override
  Future<UserAccount?> findByUsername(String username) async {
    final db = await _db;
    final rows = await db.query(
      'user_accounts',
      where: 'username = ?',
      whereArgs: [username.trim()],
      limit: 1,
    );
    if (rows.isEmpty) {
      return null;
    }
    return UserAccount.fromMap(rows.first);
  }

  @override
  Future<List<UserAccount>> listAll() async {
    final db = await _db;
    final rows = await db.query('user_accounts', orderBy: 'username ASC');
    return rows.map(UserAccount.fromMap).toList();
  }

  @override
  Future<void> save(UserAccount user) async {
    final db = await _db;
    await db.insert(
      'user_accounts',
      user.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<void> setCurrentSessionUserId(String userId) async {
    final db = await _db;
    await db.delete('app_session');
    await db.insert('app_session', {
      'id': 1,
      'user_id': userId,
      'updated_at': DateTime.now().toIso8601String(),
    });
  }
}
