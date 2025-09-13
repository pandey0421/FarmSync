import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// Import screens
import 'screens/auth/login_screen.dart';
import 'screens/auth/role_selection_screen.dart';
import 'screens/farmer/farmer_screen.dart';
import 'screens/retailer/retailer_screen.dart';
import 'screens/transporter/transporter_screen.dart';
import 'screens/customer/customer_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Role-Based App',
      theme: ThemeData(primarySwatch: Colors.green),
      home: const AuthGate(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  User? _user;
  String? _role;
  bool _loading = true;

  @override
  void initState() {
    super.initState();

    // Listen for auth state changes and fetch role from Firestore
    FirebaseAuth.instance.authStateChanges().listen((user) async {
      setState(() {
        _user = user;
        _role = null;
        _loading = true;
      });

      if (user != null) {
        var doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
        final data = doc.data() as Map<String, dynamic>?;
        setState(() {
          _role = doc.exists && data != null ? data['role'] as String? : null;
          _loading = false;
        });
      } else {
        setState(() {
          _loading = false;
        });
      }
    });
  }

  void _onRoleChanged(String newRole) async {
    if (_user == null) return;
    await FirebaseFirestore.instance.collection('users').doc(_user!.uid).set({
      'role': newRole,
      'email': _user!.email,
    }, SetOptions(merge: true));
    setState(() {
      _role = newRole;
    });
  }

  // Called by dashboards to switch user role
  void _switchRole() {
    setState(() {
      _role = null; // Forces showing RoleSelectionScreen
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      // Show loading spinner while checking auth and Firestore role
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_user == null) {
      // User not logged in → show LoginScreen
      return const LoginScreen();
    }

    if (_role == null) {
      // User logged in but no role → show RoleSelectionScreen
      return RoleSelectionScreen(onRoleSelected: _onRoleChanged);
    }

    // Route to role-specific dashboard with role switch callback
    switch (_role!.toLowerCase()) {
      case 'farmer':
        return FarmerScreen(onSwitchRole: _switchRole);
      case 'retailer':
        return RetailerScreen(onSwitchRole: _switchRole);
      case 'transporter':
        return TransporterScreen(onSwitchRole: _switchRole);
      case 'customer':
        return CustomerScreen(onSwitchRole: _switchRole);
      default:
        // Unknown role → show error with switch role option
        return Scaffold(
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Unknown role: $_role',
                  style: const TextStyle(fontSize: 18),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: _switchRole,
                  child: const Text('Switch Role'),
                ),
              ],
            ),
          ),
        );
    }
  }
}
