import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class CustomerScreen extends StatefulWidget {
  final VoidCallback? onSwitchRole; // Optional callback for role switching

  const CustomerScreen({super.key, this.onSwitchRole});

  @override
  State<CustomerScreen> createState() => _CustomerScreenState();
}

class _CustomerScreenState extends State<CustomerScreen> {
  final userId = FirebaseAuth.instance.currentUser!.uid;

  // Stream of buyable fruits (delivered but not yet bought)
  Stream<QuerySnapshot> getFruitsForSale() {
    // Buyable = delivered AND customerId missing or empty
    return FirebaseFirestore.instance
        .collection('harvests')
        .where('status', isEqualTo: 'delivered')
        .where('customerId', isNull: true)
        .snapshots();
  }

  // Stream of delivered orders for this customer
  Stream<QuerySnapshot> getDeliveredOrders() {
    return FirebaseFirestore.instance
        .collection('harvests')
        .where('status', isEqualTo: 'delivered')
        .where('customerId', isEqualTo: userId)
        .orderBy('deliveredAt', descending: true)
        .snapshots();
  }

  Future<void> _onBuyPressed(DocumentSnapshot doc) async {
    try {
      await FirebaseFirestore.instance.collection('harvests').doc(doc.id).update({
        'customerId': userId,
        // Optionally set a timestamp: 'boughtAt': FieldValue.serverTimestamp(),
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Fruit bought! Check below for details.')),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not buy: $e')));
    }
  }

  void _onTrackPressed(DocumentSnapshot doc) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Tracking Info'),
        content: Text(
          'Tracking for shipment: ${doc.id}\n'
          'Fruit: ${doc['fruitType']}\n'
          'Quantity: ${doc['quantity']} kg\n'
          'Delivered on: ${_formatDeliveredAt(doc['deliveredAt'])}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  String _formatDeliveredAt(dynamic timestamp) {
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
        title: const Text('Customer Dashboard'),
        actions: [
          if (widget.onSwitchRole != null)
            IconButton(
              icon: const Icon(Icons.swap_horiz),
              tooltip: 'Switch Role',
              onPressed: widget.onSwitchRole,
            ),
        ],
      ),
      body: ListView(
        children: [
          // Section 1: Buy Fruits
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Text(
              "Buy Fruits Ready For You",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ),
          StreamBuilder<QuerySnapshot>(
            stream: getFruitsForSale(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const Center(child: Text('No fruits available to buy.'));
              }
              final docs = snapshot.data!.docs;
              return ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: docs.length,
                itemBuilder: (context, index) {
                  final data = docs[index].data()! as Map<String, dynamic>;
                  return Card(
                    margin: const EdgeInsets.symmetric(
                      vertical: 8,
                      horizontal: 12,
                    ),
                    elevation: 2,
                    child: ListTile(
                      title: Text(
                        "${data['fruitType']} - ${data['quantity']} kg",
                      ),
                      subtitle: Text(
                        "Harvest Date: ${_formatDeliveredAt(data['harvestDate'])}\n"
                        "Delivered On: ${_formatDeliveredAt(data['deliveredAt'])}\n"
                        "Status: ${data['status']}\n"
                        "Harvest ID: ${docs[index].id}",
                      ),
                      trailing: ElevatedButton(
                        onPressed: () => _onBuyPressed(docs[index]),
                        child: const Text('Buy'),
                      ),
                    ),
                  );
                },
              );
            },
          ),
          // Section 2: Already Bought / Delivered Orders
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Text(
              "Your Purchased & Delivered Fruits",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ),
          StreamBuilder<QuerySnapshot>(
            stream: getDeliveredOrders(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const Center(
                  child: Text('No delivered orders yet. Buy fruits above!'),
                );
              }
              final docs = snapshot.data!.docs;
              return ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: docs.length,
                itemBuilder: (context, index) {
                  final data = docs[index].data()! as Map<String, dynamic>;
                  return Card(
                    margin: const EdgeInsets.symmetric(
                      vertical: 8,
                      horizontal: 12,
                    ),
                    child: ListTile(
                      title: Text(
                        "${data['fruitType']} - ${data['quantity']} kg",
                      ),
                      subtitle: Text(
                        'Delivered on: ${_formatDeliveredAt(data['deliveredAt'])}\n'
                        'Product ID: ${docs[index].id}',
                      ),
                      trailing: ElevatedButton(
                        onPressed: () => _onTrackPressed(docs[index]),
                        child: const Text('Track'),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }
}
