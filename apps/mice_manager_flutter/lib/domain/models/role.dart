enum Role {
  owner,
  admin,
  staff,
  viewer,
}

extension RoleX on Role {
  String get storageValue {
    switch (this) {
      case Role.owner:
        return 'OWNER';
      case Role.admin:
        return 'ADMIN';
      case Role.staff:
        return 'STAFF';
      case Role.viewer:
        return 'VIEWER';
    }
  }

  String get label {
    switch (this) {
      case Role.owner:
        return 'Owner';
      case Role.admin:
        return 'Admin';
      case Role.staff:
        return 'Staff';
      case Role.viewer:
        return 'Viewer';
    }
  }
}

Role roleFromStorage(String value) {
  switch (value.trim().toUpperCase()) {
    case 'OWNER':
      return Role.owner;
    case 'ADMIN':
      return Role.admin;
    case 'STAFF':
      return Role.staff;
    case 'VIEWER':
      return Role.viewer;
    default:
      throw ArgumentError('Unsupported role: $value');
  }
}
