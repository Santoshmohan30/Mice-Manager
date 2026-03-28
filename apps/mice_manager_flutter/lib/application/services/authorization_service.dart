import '../../domain/models/role.dart';
import '../../domain/models/user_account.dart';

class AuthorizationService {
  const AuthorizationService();

  bool canManageOwnerSecurity(UserAccount actor) {
    return actor.role == Role.owner && actor.isOwner && actor.isProtected;
  }

  bool canPromoteAdmin(UserAccount actor) {
    return canManageOwnerSecurity(actor);
  }

  bool canDemoteAdmin(UserAccount actor) {
    return canManageOwnerSecurity(actor);
  }

  bool canDeleteOwner(UserAccount actor, UserAccount target) {
    if (target.isOwner || target.isProtected) {
      return false;
    }
    return actor.role == Role.owner;
  }

  bool canCreateUsers(UserAccount actor) {
    return actor.role == Role.owner || actor.role == Role.admin;
  }

  bool canChangeRole(UserAccount actor, UserAccount target, Role desiredRole) {
    if (target.isOwner || target.isProtected) {
      return false;
    }
    if (actor.role == Role.owner) {
      return true;
    }
    if (actor.role == Role.admin) {
      return desiredRole == Role.staff || desiredRole == Role.viewer;
    }
    return false;
  }

  bool canDeactivateUser(UserAccount actor, UserAccount target) {
    if (target.isOwner || target.isProtected) {
      return false;
    }
    return actor.role == Role.owner || actor.role == Role.admin;
  }
}
