import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class TransporterScreen extends StatefulWidget {
  final VoidCallback? onSwitchRole; // Added optional role switch callback

  const TransporterScreen({super.key, this.onSwitchRole});

  @override
  State<TransporterScreen> createState() => _TransporterScreenState();
}

class _TransporterScreenState extends State<TransporterScreen> {
  final userId = FirebaseAuth.instance.currentUser!.uid;

  Stream<QuerySnapshot> getAcceptedOrders() {
    return FirebaseFirestore.instance
        .collection('harvests')
        .where('status', isEqualTo: 'accepted')
        .snapshots();
  }

  Stream<QuerySnapshot> getInTransitOrders() {
    return FirebaseFirestore.instance
        .collection('harvests')
        .where('status', isEqualTo: 'in_transit')
        .where('transporterId', isEqualTo: userId)
        .snapshots();
  }

  Future<void> _acceptOrder(DocumentSnapshot doc) async {
    await FirebaseFirestore.instance.collection('harvests').doc(doc.id).update({
      'status': 'in_transit',
      'transporterId': userId,
      'deliveryProgress': 0.0,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    _simulateDeliveryProgress(doc.id);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Pickup accepted, delivery started.")),
    );
  }

  void _simulateDeliveryProgress(String docId) {
    Timer.periodic(const Duration(seconds: 1), (timer) async {
      final snapshot = await FirebaseFirestore.instance
          .collection('harvests')
          .doc(docId)
          .get();

      if (!snapshot.exists) {
        timer.cancel();
        return;
      }

      final data = snapshot.data()!;
      double progress = (data['deliveryProgress'] ?? 0.0) as double;

      if (progress >= 1.0) {
        await FirebaseFirestore.instance
            .collection('harvests')
            .doc(docId)
            .update({
              'status': 'delivered',
              'deliveryProgress': 1.0,
              'deliveredAt': FieldValue.serverTimestamp(),
            });
        timer.cancel();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Order ${docId.substring(0, 7)} delivered!"),
            ),
          );
          setState(() {});
        }
      } else {
        progress += 0.2;
        if (progress > 1.0) progress = 1.0;
        await FirebaseFirestore.instance
            .collection('harvests')
            .doc(docId)
            .update({
              'deliveryProgress': progress,
              'updatedAt': FieldValue.serverTimestamp(),
            });
      }
    });
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
        title: const Text("Transporter Dashboard"),
        actions: [
          if (widget.onSwitchRole != null)
            IconButton(
              icon: const Icon(Icons.swap_horiz),
              tooltip: "Switch Role",
              onPressed: widget.onSwitchRole,
            ),
        ],
      ),
      body: Column(
        children: [
          const SizedBox(height: 10),
          const Text(
            "Pickup Requests",
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: getAcceptedOrders(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(child: Text("No pickup requests"));
                }
                final docs = snapshot.data!.docs;
                return ListView.builder(
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final data = docs[index].data()! as Map<String, dynamic>;
                    return Card(
                      margin: const EdgeInsets.all(8),
                      child: ListTile(
                        title: Text(
                          "${data['fruitType']} - ${data['quantity']} kg",
                        ),
                        subtitle: Text(
                          "Harvest Date: ${_formatHarvestDate(data['harvestDate'])}",
                        ),
                        trailing: ElevatedButton(
                          child: const Text("Pick Up"),
                          onPressed: () => _acceptOrder(docs[index]),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          const Divider(),
          const Text(
            "In Transit",
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: getInTransitOrders(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(child: Text("No orders in transit"));
                }
                final docs = snapshot.data!.docs;
                return ListView.builder(
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final data = docs[index].data()! as Map<String, dynamic>;
                    final prog = (data['deliveryProgress'] ?? 0.0) as double;
                    return Card(
                      margin: const EdgeInsets.all(8),
                      child: ListTile(
                        title: Text("${data['fruitType']}"),
                        subtitle: LinearProgressIndicator(value: prog),
                        trailing: Text("${(prog * 100).toInt()}%"),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
