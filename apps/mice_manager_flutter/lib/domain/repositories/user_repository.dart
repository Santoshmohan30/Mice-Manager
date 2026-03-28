import '../models/user_account.dart';

abstract class UserRepository {
  Future<void> ensureOwnerSeeded();
  Future<UserAccount?> findById(String userId);
  Future<UserAccount?> findByUsername(String username);
  Future<void> save(UserAccount user);
  Future<List<UserAccount>> listAll();
  Future<String?> currentSessionUserId();
  Future<void> setCurrentSessionUserId(String userId);
  Future<void> clearCurrentSession();
}
