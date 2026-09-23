import 'package:supabase_flutter/supabase_flutter.dart';

import 'auth_models.dart';
import 'auth_repository.dart';

class SupabaseAuthRepository implements AuthRepository {
  SupabaseAuthRepository(this.client);

  final SupabaseClient client;
  AppUser? _currentUser;

  @override
  bool get isRemote => true;

  @override
  AppUser? get currentUser => _currentUser;

  @override
  Future<bool> hasUsers() async {
    final row = await client.from('profiles').select('id').limit(1).maybeSingle();
    return row != null;
  }

  @override
  Future<AppUser?> signIn(String identifier, String password) async {
    try {
      final response = await client.auth.signInWithPassword(email: identifier.trim(), password: password);
      final sessionUser = response.user;
      if (sessionUser == null) return null;
      final row = await client.from('profiles').select('id, display_name, role, is_active').eq('id', sessionUser.id).maybeSingle();
      if (row == null || row['is_active'] != true) {
        await client.auth.signOut();
        return null;
      }
      final role = UserRole.values.byName(row['role'] as String);
      return _currentUser = AppUser(id: sessionUser.id, username: sessionUser.email ?? identifier.trim(), displayName: row['display_name'] as String, role: role, isActive: true);
    } on AuthException catch (error) {
      throw StateError(error.message);
    }
  }

  @override
  Future<AppUser> createUser({required String username, required String displayName, required UserRole role, required String password}) async {
    if (role != UserRole.secretary) {
      throw StateError('Admin accounts must be provisioned by a trusted server operation.');
    }
    try {
      final response = await client.auth.signUp(
        email: username.trim(),
        password: password,
        data: {'display_name': displayName.trim()},
      );
      final sessionUser = response.user;
      if (sessionUser == null) {
        throw StateError('Registration succeeded. Confirm the email address before signing in.');
      }
      final row = await client.from('profiles').select('display_name, role, is_active').eq('id', sessionUser.id).single();
      if (row['is_active'] != true) throw StateError('This account is inactive.');
      return _currentUser = AppUser(id: sessionUser.id, username: sessionUser.email ?? username.trim(), displayName: row['display_name'] as String, role: UserRole.values.byName(row['role'] as String), isActive: true);
    } on AuthException catch (error) {
      throw StateError(error.message);
    }
  }

  @override
  Future<List<AppUser>> allUsers() async {
    final rows = await client.from('profiles').select('id, email, display_name, role, is_active').order('display_name');
    return (rows as List).map((row) => AppUser(id: row['id'] as String, username: (row['email'] as String?) ?? '', displayName: row['display_name'] as String, role: UserRole.values.byName(row['role'] as String), isActive: row['is_active'] as bool)).toList(growable: false);
  }

  @override
  Future<void> signOut() async {
    await client.auth.signOut();
    _currentUser = null;
  }
}
