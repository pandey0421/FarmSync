import 'package:flutter/material.dart';

class RoleSelectionScreen extends StatelessWidget {
  final void Function(String) onRoleSelected;
  const RoleSelectionScreen({super.key, required this.onRoleSelected});

  @override
  Widget build(BuildContext context) {
    final roles = ['farmer', 'retailer', 'transporter', 'customer'];
    return Scaffold(
      appBar: AppBar(title: const Text('Select Role')),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Choose your role:', style: TextStyle(fontSize: 20)),
            for (var role in roles)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: ElevatedButton(
                  onPressed: () => onRoleSelected(role),
                  child: Text(role[0].toUpperCase() + role.substring(1)),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
