import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class FarmerScreen extends StatefulWidget {
  final VoidCallback? onSwitchRole; // Callback for switching role

  const FarmerScreen({super.key, this.onSwitchRole});

  @override
  State<FarmerScreen> createState() => _FarmerScreenState();
}

class _FarmerScreenState extends State<FarmerScreen> {
  final _formKey = GlobalKey<FormState>();
  String? _fruitType;
  String? _quantity;
  DateTime? _harvestDate;
  File? _imageFile;
  bool _isLoading = false;

  final fruitOptions = ['Mango', 'Banana', 'Grapes'];
  final ImagePicker _picker = ImagePicker();

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2023),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        _harvestDate = picked;
      });
    }
  }

  Future<void> _pickImage() async {
    final pickedFile = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 70,
    );
    if (pickedFile != null) {
      setState(() {
        _imageFile = File(pickedFile.path);
      });
    }
  }

  Future<String?> _uploadImage(File image) async {
    try {
      final userId = FirebaseAuth.instance.currentUser!.uid;
      final ref = FirebaseStorage.instance
          .ref()
          .child('harvest_images')
          .child(userId)
          .child('${DateTime.now().millisecondsSinceEpoch}.jpg');
      await ref.putFile(image);
      final url = await ref.getDownloadURL();
      return url;
    } catch (e) {
      return null;
    }
  }

  Future<void> _submitHarvest() async {
    if (!_formKey.currentState!.validate() || _harvestDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please complete all fields")),
      );
      return;
    }
    setState(() => _isLoading = true);
    String? imageUrl;
    if (_imageFile != null) {
      imageUrl = await _uploadImage(_imageFile!);
      if (imageUrl == null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("Image upload failed")));
        setState(() => _isLoading = false);
        return;
      }
    }
    final userId = FirebaseAuth.instance.currentUser!.uid;

    await FirebaseFirestore.instance.collection('harvests').add({
      'farmerId': userId,
      'fruitType': _fruitType,
      'quantity': double.parse(_quantity!),
      'harvestDate': Timestamp.fromDate(_harvestDate!),
      'imageUrl': imageUrl,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
    });

    setState(() {
      _formKey.currentState!.reset();
      _fruitType = null;
      _quantity = null;
      _harvestDate = null;
      _imageFile = null;
      _isLoading = false;
    });
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text("Harvest logged!")));
  }

  Stream<QuerySnapshot> _fetchMyHarvests() {
    final userId = FirebaseAuth.instance.currentUser!.uid;
    return FirebaseFirestore.instance
        .collection('harvests')
        .where('farmerId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots();
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

  Future<bool> _onWillPop() async {
    final shouldExit = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Exit App?'),
        content: const Text('Do you want to exit the app?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Yes'),
          ),
        ],
      ),
    );
    return shouldExit ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        appBar: AppBar(
          title: const Text("Farmer Harvest Logging"),
          actions: [
            if (widget.onSwitchRole != null)
              IconButton(
                icon: const Icon(Icons.swap_horiz),
                tooltip: "Switch Role",
                onPressed: widget.onSwitchRole,
              ),
          ],
        ),
        body: Padding(
          padding: const EdgeInsets.all(12.0),
          child: ListView(
            children: [
              Form(
                key: _formKey,
                child: Column(
                  children: [
                    DropdownButtonFormField<String>(
                      decoration: const InputDecoration(
                        labelText: "Select Fruit Type",
                        border: OutlineInputBorder(),
                      ),
                      value: _fruitType,
                      onChanged: (val) => setState(() => _fruitType = val),
                      items: fruitOptions
                          .map(
                            (f) => DropdownMenuItem(value: f, child: Text(f)),
                          )
                          .toList(),
                      validator: (v) =>
                          v == null ? 'Please select a fruit type' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      decoration: const InputDecoration(
                        labelText: "Quantity (kg)",
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                      onChanged: (val) => _quantity = val,
                      validator: (val) {
                        if (val == null || val.isEmpty) {
                          return 'Please enter quantity';
                        }
                        if (double.tryParse(val) == null) {
                          return 'Enter a valid number';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            _harvestDate == null
                                ? 'No date chosen'
                                : 'Date: ${_harvestDate!.day}/${_harvestDate!.month}/${_harvestDate!.year}',
                          ),
                        ),
                        ElevatedButton(
                          onPressed: _pickDate,
                          child: const Text('Select Date'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (_imageFile != null)
                      SizedBox(
                        height: 150,
                        child: Image.file(_imageFile!, fit: BoxFit.cover),
                      ),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.photo_library),
                      label: const Text("Upload Photo"),
                      onPressed: _pickImage,
                    ),
                    const SizedBox(height: 12),
                    _isLoading
                        ? const CircularProgressIndicator()
                        : ElevatedButton(
                            onPressed: _submitHarvest,
                            child: const Text("Log Harvest"),
                          ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              const Divider(),
              const Text(
                "My Harvests",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              StreamBuilder<QuerySnapshot>(
                stream: _fetchMyHarvests(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return const Center(child: Text("No harvests logged yet."));
                  }
                  final docs = snapshot.data!.docs;
                  return ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: docs.length,
                    itemBuilder: (context, index) {
                      final data = docs[index].data() as Map<String, dynamic>;
                      return Card(
                        child: ListTile(
                          leading: data['imageUrl'] != null
                              ? Image.network(
                                  data['imageUrl'],
                                  width: 50,
                                  fit: BoxFit.cover,
                                )
                              : const Icon(Icons.local_florist),
                          title: Text(
                            "${data['fruitType']} - ${data['quantity']} kg",
                          ),
                          subtitle: Text(
                            "Harvest Date: ${_formatHarvestDate(data['harvestDate'])}",
                          ),
                          trailing: Text("Status: ${data['status']}"),
                        ),
                      );
                    },
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
