enum UserRole {
  admin,
  secretary,
}

enum AppPermission {
  receiveDeliveries,
  lookupSuppliers,
  viewTodaysRecords,
  correctDeliveries,
  viewSyncStatus,
  manageUsers,
  administerDatabase,
  configureSystem,
  unrestrictedDeletion,
}

class AppUser {
  const AppUser({
    required this.id,
    required this.username,
    required this.displayName,
    required this.role,
    required this.isActive,
  });

  final String id;
  final String username;
  final String displayName;
  final UserRole role;
  final bool isActive;

  bool can(AppPermission permission) {
    if (role == UserRole.admin) return true;
    return switch (permission) {
      AppPermission.receiveDeliveries ||
      AppPermission.lookupSuppliers ||
      AppPermission.viewTodaysRecords ||
      AppPermission.correctDeliveries ||
      AppPermission.viewSyncStatus => true,
      AppPermission.manageUsers ||
      AppPermission.administerDatabase ||
      AppPermission.configureSystem ||
      AppPermission.unrestrictedDeletion => false,
    };
  }
}