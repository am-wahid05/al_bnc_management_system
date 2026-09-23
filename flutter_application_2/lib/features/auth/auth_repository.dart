import 'auth_models.dart';

abstract interface class AuthRepository {
  AppUser? get currentUser;
  bool get isRemote;
  Future<bool> hasUsers();
  Future<AppUser?> signIn(String identifier, String password);
  Future<AppUser> createUser({required String username, required String displayName, required UserRole role, required String password});
  Future<List<AppUser>> allUsers();
  Future<void> signOut();
}
