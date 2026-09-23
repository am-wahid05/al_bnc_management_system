import 'package:flutter/material.dart';

import '../../app/app_routes.dart';
import 'auth_models.dart';
import 'auth_repository.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({required this.authRepository, super.key});

  final AuthRepository authRepository;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _displayNameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _hasUsers = true;
  bool _loading = true;
  UserRole _selectedRole = UserRole.admin;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadUserState();
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _displayNameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _loadUserState() async {
    final hasUsers = await widget.authRepository.hasUsers();
    if (mounted) setState(() { _hasUsers = hasUsers; _loading = false; });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _loading = true; _error = null; });
    try {
      final user = _hasUsers
          ? await widget.authRepository.signIn(_usernameController.text, _passwordController.text)
          : await widget.authRepository.createUser(username: _usernameController.text, displayName: _displayNameController.text, role: UserRole.admin, password: _passwordController.text);
      if (user == null) {
        setState(() => _error = 'Invalid username or password.');
        return;
      }
      if (user.role != _selectedRole) {
        setState(() => _error = 'Choose the login option that matches this account.');
        return;
      }
      if (mounted) Navigator.pushReplacementNamed(context, user.role == UserRole.admin ? AppRoutes.adminDashboard : AppRoutes.secretaryDashboard);
    } on ArgumentError catch (error) {
      setState(() => _error = error.message);
    } on StateError catch (error) {
      setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final setup = !_hasUsers;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Form(
                    key: _formKey,
                    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      Icon(Icons.eco, size: 64, color: Theme.of(context).colorScheme.primary),
                      const SizedBox(height: 16),
                      Text('AL-BNC Ventures', textAlign: TextAlign.center, style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Text(setup ? 'Create the first owner account' : 'Sign in to continue', textAlign: TextAlign.center),
                      const SizedBox(height: 28),
                      if (!setup) ...[
                        Row(children: [
                          Expanded(child: _roleButton(context, UserRole.admin, Icons.admin_panel_settings_outlined, 'Login as Admin')),
                          const SizedBox(width: 8),
                          Expanded(child: _roleButton(context, UserRole.secretary, Icons.badge_outlined, 'Login as Secretary')),
                        ]),
                        const SizedBox(height: 20),
                      ],
                      if (setup) ...[
                        TextFormField(controller: _displayNameController, decoration: const InputDecoration(labelText: 'Owner name'), validator: (value) => value == null || value.trim().isEmpty ? 'Required' : null),
                        const SizedBox(height: 16),
                      ],
                      TextFormField(controller: _usernameController, decoration: const InputDecoration(labelText: 'Username'), validator: (value) => value == null || value.trim().length < 3 ? 'Use at least 3 characters' : null),
                      const SizedBox(height: 16),
                      TextFormField(controller: _passwordController, obscureText: true, decoration: const InputDecoration(labelText: 'Password'), validator: (value) => value == null || value.length < 8 ? 'Use at least 8 characters' : null),
                      if (!setup) ...[
                        if (!widget.authRepository.isRemote) ...[
                          const SizedBox(height: 12),
                          const Text('LOCAL TEST ADMIN: localtest / localtest123\nLOCAL TEST SECRETARY: secretarytest / secretary123', textAlign: TextAlign.center),
                        ],
                      ],
                      if (_error != null) ...[const SizedBox(height: 16), Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error))],
                      const SizedBox(height: 24),
                      SizedBox(height: 52, child: FilledButton.icon(onPressed: _loading ? null : _submit, icon: _loading ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator()) : Icon(setup ? Icons.person_add_alt_1 : Icons.login), label: Text(setup ? 'Create Owner Account' : 'Sign In'))),
                      const SizedBox(height: 16),
                      Text(setup ? 'Choose and remember your password. It will not be stored as plain text.' : 'Passwords are checked locally and never displayed.', textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodySmall),
                    ]),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _roleButton(BuildContext context, UserRole role, IconData icon, String label) {
    final selected = _selectedRole == role;
    return selected
        ? FilledButton.icon(onPressed: () {}, icon: Icon(icon), label: Text(label, textAlign: TextAlign.center))
        : OutlinedButton.icon(
            onPressed: () {
              setState(() {
                _selectedRole = role;
                _usernameController.text = role == UserRole.admin ? 'localtest' : 'secretarytest';
                _passwordController.clear();
              });
            },
            icon: Icon(icon),
            label: Text(label, textAlign: TextAlign.center),
          );
  }
}
