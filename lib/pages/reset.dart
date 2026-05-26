import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'admin_register.dart';

class ResetPage extends StatefulWidget {
  const ResetPage({super.key});

  @override
  State<ResetPage> createState() => _ResetPageState();
}

class _ResetPageState extends State<ResetPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  bool _isLoading = true;
  String _status = "Resetting admin...";

  @override
  void initState() {
    super.initState();
    _resetAdmin();
  }

  Future<void> _resetAdmin() async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        // Delete Firestore user doc
        await _firestore.collection('users').doc(user.uid).delete();

        // Delete Firebase Auth user
        await user.delete();
      }

      // Unlock system admin_lock
      final systemDoc = _firestore.collection('system').doc('admin_lock');
      await systemDoc.set({'locked': false, 'adminId': null});

      setState(() => _status = "Admin reset successful!");

      // Delay a bit and navigate to AdminRegisterPage
      Future.delayed(const Duration(seconds: 1), () {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const AdminRegisterPage()),
              (route) => false,
        );
      });
    } catch (e) {
      setState(() => _status = "Error: ${e.toString()}");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Reset Admin"), backgroundColor: Colors.red),
      body: Center(
        child: _isLoading
            ? Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(color: Colors.red),
            const SizedBox(height: 20),
            Text(_status, style: const TextStyle(fontSize: 16)),
          ],
        )
            : Text(_status, style: const TextStyle(fontSize: 16)),
      ),
    );
  }
}
