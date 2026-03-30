import 'package:flutter/foundation.dart';

import '../../application/services/authentication_service.dart';
import '../../domain/models/role.dart';
import '../../domain/models/user_account.dart';

class AuthController extends ChangeNotifier {
  AuthController(this._service);

  final AuthenticationService _service;

  UserAccount? _currentUser;
  List<UserAccount> _users = const [];
  bool _isLoading = false;
  String? _error;

  UserAccount? get currentUser => _currentUser;
  List<UserAccount> get users => _users;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isAuthenticated => _currentUser != null;

  Future<void> initialize() async {
    _isLoading = true;
    notifyListeners();
    await _service.initialize();
    _currentUser = await _service.currentUser();
    _users = await _service.listUsers();
    _isLoading = false;
    notifyListeners();
  }

  Future<bool> signIn(String username, String password) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      _currentUser =
          await _service.signIn(username: username, password: password);
      _users = await _service.listUsers();
      return true;
    } catch (error) {
      _error = error.toString();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> signOut() async {
    await _service.signOut();
    _currentUser = null;
    notifyListeners();
  }

  Future<void> refreshUsers() async {
    _users = await _service.listUsers();
    notifyListeners();
  }

  Future<void> createUser({
    required String username,
    required String password,
    required Role role,
  }) async {
    final actor = _currentUser;
    if (actor == null) {
      return;
    }
    await _service.createUser(
      actor: actor,
      username: username,
      password: password,
      role: role,
    );
    await refreshUsers();
  }

  Future<void> updateRole(UserAccount target, Role role) async {
    final actor = _currentUser;
    if (actor == null) {
      return;
    }
    await _service.updateUserRole(
      actor: actor,
      target: target,
      role: role,
    );
    await refreshUsers();
  }

  Future<void> setUserActive(UserAccount target, bool isActive) async {
    final actor = _currentUser;
    if (actor == null) {
      return;
    }
    await _service.setUserActive(
      actor: actor,
      target: target,
      isActive: isActive,
    );
    await refreshUsers();
  }

  Future<void> changeOwnPassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final actor = _currentUser;
    if (actor == null) {
      return;
    }
    await _service.changeOwnPassword(
      actor: actor,
      currentPassword: currentPassword,
      newPassword: newPassword,
    );
    _currentUser = await _service.currentUser();
    await refreshUsers();
  }

  Future<void> resetUserPassword(UserAccount target, String newPassword) async {
    final actor = _currentUser;
    if (actor == null) {
      return;
    }
    await _service.resetUserPassword(
      actor: actor,
      target: target,
      newPassword: newPassword,
    );
    await refreshUsers();
  }

  Future<void> updateOwnerRecoveryHint(String recoveryHint) async {
    final actor = _currentUser;
    if (actor == null) {
      return;
    }
    await _service.updateOwnerRecoveryHint(
      actor: actor,
      recoveryHint: recoveryHint,
    );
    _currentUser = await _service.currentUser();
    await refreshUsers();
  }
}
