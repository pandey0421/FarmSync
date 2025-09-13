import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class LoginScreen extends StatefulWidget {
  final void Function(String)?
  onRoleSelected; // Add this for parent to receive chosen role

  const LoginScreen({super.key, this.onRoleSelected});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  String email = '', password = '';
  bool isLogin = true;
  String error = '';
  final _formKey = GlobalKey<FormState>();
  String? _selectedRole;
  final List<String> roles = ['farmer', 'retailer', 'transporter', 'customer'];

  // Login or sign up function
  void _submit() async {
    setState(() => error = '');
    if (!_formKey.currentState!.validate()) return;
    if (_selectedRole == null) {
      setState(() => error = "Select a role to continue.");
      return;
    }
    try {
      final auth = FirebaseAuth.instance;
      if (isLogin) {
        await auth.signInWithEmailAndPassword(email: email, password: password);
      } else {
        await auth.createUserWithEmailAndPassword(
          email: email,
          password: password,
        );
      }
      // Inform parent about selected role (Parent saves it to Firestore if needed)
      if (widget.onRoleSelected != null && _selectedRole != null) {
        widget.onRoleSelected!(_selectedRole!);
      }
    } catch (e) {
      setState(() => error = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(isLogin ? 'Login' : 'Sign Up')),
      body: Center(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  // Email field
                  TextFormField(
                    key: const ValueKey('email'),
                    decoration: const InputDecoration(labelText: "Email"),
                    onChanged: (v) => email = v,
                    validator: (v) => v == null || !v.contains('@')
                        ? 'Enter valid email'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  // Password field
                  TextFormField(
                    key: const ValueKey('password'),
                    decoration: const InputDecoration(labelText: "Password"),
                    obscureText: true,
                    onChanged: (v) => password = v,
                    validator: (v) =>
                        v == null || v.length < 6 ? '6+ char password' : null,
                  ),
                  const SizedBox(height: 18),
                  // Role selection dropdown
                  DropdownButtonFormField<String>(
                    decoration: const InputDecoration(
                      labelText: "Choose role to access",
                      border: OutlineInputBorder(),
                    ),
                    value: _selectedRole,
                    items: roles
                        .map(
                          (role) => DropdownMenuItem(
                            value: role,
                            child: Text(
                              role[0].toUpperCase() + role.substring(1),
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (v) => setState(() => _selectedRole = v),
                    validator: (v) =>
                        v == null ? 'Select a role to continue' : null,
                  ),
                  const SizedBox(height: 18),
                  if (error.isNotEmpty)
                    Text(error, style: const TextStyle(color: Colors.red)),
                  ElevatedButton(
                    onPressed: _submit,
                    child: Text(isLogin ? 'LOGIN' : 'SIGN UP'),
                  ),
                  TextButton(
                    onPressed: () => setState(() => isLogin = !isLogin),
                    child: Text(
                      isLogin
                          ? "Don't have an account? SIGN UP"
                          : "Already registered? LOGIN",
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
