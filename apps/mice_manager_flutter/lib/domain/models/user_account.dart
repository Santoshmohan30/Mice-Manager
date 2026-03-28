import 'role.dart';

class UserAccount {
  const UserAccount({
    required this.id,
    required this.username,
    required this.role,
    required this.passwordHash,
    required this.isOwner,
    required this.isProtected,
    required this.isActive,
    this.recoveryKeyHint,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String username;
  final Role role;
  final String passwordHash;
  final bool isOwner;
  final bool isProtected;
  final bool isActive;
  final String? recoveryKeyHint;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'username': username,
      'role': role.storageValue,
      'password_hash': passwordHash,
      'is_owner': isOwner ? 1 : 0,
      'is_protected': isProtected ? 1 : 0,
      'is_active': isActive ? 1 : 0,
      'recovery_key_hint': recoveryKeyHint,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  factory UserAccount.fromMap(Map<String, Object?> map) {
    return UserAccount(
      id: map['id'] as String,
      username: map['username'] as String,
      role: roleFromStorage(map['role'] as String),
      passwordHash: map['password_hash'] as String,
      isOwner: (map['is_owner'] as int) == 1,
      isProtected: (map['is_protected'] as int) == 1,
      isActive: (map['is_active'] as int) == 1,
      recoveryKeyHint: map['recovery_key_hint'] as String?,
      createdAt: map['created_at'] == null
          ? null
          : DateTime.parse(map['created_at'] as String),
      updatedAt: map['updated_at'] == null
          ? null
          : DateTime.parse(map['updated_at'] as String),
    );
  }

  UserAccount copyWith({
    String? id,
    String? username,
    Role? role,
    String? passwordHash,
    bool? isOwner,
    bool? isProtected,
    bool? isActive,
    String? recoveryKeyHint,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return UserAccount(
      id: id ?? this.id,
      username: username ?? this.username,
      role: role ?? this.role,
      passwordHash: passwordHash ?? this.passwordHash,
      isOwner: isOwner ?? this.isOwner,
      isProtected: isProtected ?? this.isProtected,
      isActive: isActive ?? this.isActive,
      recoveryKeyHint: recoveryKeyHint ?? this.recoveryKeyHint,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
