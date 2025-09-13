import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class RetailerScreen extends StatefulWidget {
  final VoidCallback? onSwitchRole; // Added optional role switch callback

  const RetailerScreen({super.key, this.onSwitchRole});

  @override
  State<RetailerScreen> createState() => _RetailerScreenState();
}

class _RetailerScreenState extends State<RetailerScreen> {
  final userId = FirebaseAuth.instance.currentUser!.uid;

  Stream<QuerySnapshot> getPendingOrders() {
    return FirebaseFirestore.instance
        .collection('harvests')
        .where('status', isEqualTo: 'pending')
        .snapshots();
  }

  Future<void> _acceptOrder(DocumentSnapshot doc) async {
    await FirebaseFirestore.instance.collection('harvests').doc(doc.id).update({
      'status': 'accepted',
      'retailerId': userId,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Order accepted and assigned to you.")),
    );
  }

  Future<void> _rejectOrder(DocumentSnapshot doc) async {
    await FirebaseFirestore.instance.collection('harvests').doc(doc.id).update({
      'status': 'rejected',
      'retailerId': userId,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text("Order rejected.")));
  }

  String _formatHarvestDate(dynamic timestamp) {
    if (timestamp == null) return 'Unknown date';
    DateTime date;
    if (timestamp is Timestamp) {
      date = timestamp.toDate();
    } else if (timestamp is DateTime) {
      date = timestamp;
    } else {
      return 'Unknown date';
    }
    return '${date.day}/${date.month}/${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Retailer Order Management"),
        actions: [
          if (widget.onSwitchRole != null)
            IconButton(
              icon: const Icon(Icons.swap_horiz),
              tooltip: "Switch Role",
              onPressed: widget.onSwitchRole,
            ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: getPendingOrders(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text("No pending orders"));
          }
          final docs = snapshot.data!.docs;
          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final data = docs[index].data() as Map<String, dynamic>;
              return Card(
                margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                child: ListTile(
                  title: Text("${data['fruitType']} - ${data['quantity']} kg"),
                  subtitle: Text(
                    "Harvest Date: ${_formatHarvestDate(data['harvestDate'])}",
                  ),
                  trailing: Wrap(
                    spacing: 8,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.check, color: Colors.green),
                        tooltip: "Accept",
                        onPressed: () => _acceptOrder(docs[index]),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.red),
                        tooltip: "Reject",
                        onPressed: () => _rejectOrder(docs[index]),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
