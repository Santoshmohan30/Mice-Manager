import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../../domain/models/role.dart';
import '../../domain/models/user_account.dart';
import '../../domain/repositories/user_repository.dart';
import 'authorization_service.dart';

class AuthenticationService {
  AuthenticationService(
    this._userRepository,
    this._authorizationService,
  );

  final UserRepository _userRepository;
  final AuthorizationService _authorizationService;

  Future<void> initialize() async {
    await _userRepository.ensureOwnerSeeded();
  }

  Future<UserAccount?> currentUser() async {
    final userId = await _userRepository.currentSessionUserId();
    if (userId == null) {
      return null;
    }
    return _userRepository.findById(userId);
  }

  Future<UserAccount> signIn({
    required String username,
    required String password,
  }) async {
    final user = await _userRepository.findByUsername(username.trim());
    if (user == null || !user.isActive) {
      throw const AuthException('Invalid username or password.');
    }
    final hash = sha256.convert(utf8.encode(password)).toString();
    if (hash != user.passwordHash) {
      throw const AuthException('Invalid username or password.');
    }
    await _userRepository.setCurrentSessionUserId(user.id);
    return user;
  }

  Future<void> signOut() => _userRepository.clearCurrentSession();

  Future<List<UserAccount>> listUsers() => _userRepository.listAll();

  Future<void> createUser({
    required UserAccount actor,
    required String username,
    required String password,
    required Role role,
  }) async {
    if (!_authorizationService.canCreateUsers(actor)) {
      throw const AuthException('You do not have permission to create users.');
    }
    final existing = await _userRepository.findByUsername(username.trim());
    if (existing != null) {
      throw const AuthException('Username already exists.');
    }
    final now = DateTime.now();
    final user = UserAccount(
      id: 'user-${now.microsecondsSinceEpoch}',
      username: username.trim(),
      role: role,
      passwordHash: sha256.convert(utf8.encode(password)).toString(),
      isOwner: role == Role.owner,
      isProtected: role == Role.owner,
      isActive: true,
      createdAt: now,
      updatedAt: now,
    );
    await _userRepository.save(user);
  }

  Future<void> updateUserRole({
    required UserAccount actor,
    required UserAccount target,
    required Role role,
  }) async {
    if (!_authorizationService.canChangeRole(actor, target, role)) {
      throw const AuthException('You cannot change that user role.');
    }
    await _userRepository.save(
      target.copyWith(
        role: role,
        updatedAt: DateTime.now(),
      ),
    );
  }

  Future<void> setUserActive({
    required UserAccount actor,
    required UserAccount target,
    required bool isActive,
  }) async {
    if (!_authorizationService.canDeactivateUser(actor, target)) {
      throw const AuthException('You cannot update that user.');
    }
    await _userRepository.save(
      target.copyWith(
        isActive: isActive,
        updatedAt: DateTime.now(),
      ),
    );
  }
}

class AuthException implements Exception {
  const AuthException(this.message);

  final String message;

  @override
  String toString() => message;
}
