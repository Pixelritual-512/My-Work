import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/database_service.dart';
import '../models/student_model.dart';
import '../models/owner_model.dart';

class StudentRegistrationScreen extends StatefulWidget {
  final String ownerId;
  const StudentRegistrationScreen({super.key, required this.ownerId});

  @override
  State<StudentRegistrationScreen> createState() => _StudentRegistrationScreenState();
}

class _StudentRegistrationScreenState extends State<StudentRegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _mobileController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _mobileController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final db = DatabaseService(uid: widget.ownerId);

    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (didPop) return;
        // SystemNavigator.pop();
      },
      child: Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF6C63FF), Color(0xFF4B39EF)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(30),
              child: Card(
                elevation: 10,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                child: Padding(
                  padding: const EdgeInsets.all(30),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.person_add, size: 60, color: Color(0xFF6C63FF)),
                        const SizedBox(height: 10),
                        Text(
                          'Join TiffinMate',
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 5),
                        const Text('Register with your mess owner', style: TextStyle(color: Colors.grey)),
                        const SizedBox(height: 30),
                        TextFormField(
                          controller: _nameController,
                          decoration: const InputDecoration(labelText: 'Full Name', prefixIcon: Icon(Icons.person)),
                          validator: (v) => v!.isEmpty ? 'Please enter your name' : null,
                        ),
                        const SizedBox(height: 20),
                        TextFormField(
                          controller: _mobileController,
                          decoration: const InputDecoration(labelText: 'Mobile Number', prefixIcon: Icon(Icons.phone)),
                          keyboardType: TextInputType.phone,
                          validator: (v) => v!.length < 10 ? 'Enter valid mobile number' : null,
                        ),
                        const SizedBox(height: 40),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : () => _register(db),
                            child: _isLoading 
                              ? const CircularProgressIndicator(color: Colors.white)
                              : const Text('Register Now'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _register(DatabaseService db) async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      final existingQuery = await FirebaseFirestore.instance
          .collection('students')
          .where('ownerId', isEqualTo: widget.ownerId)
          .where('mobileNumber', isEqualTo: _mobileController.text)
          .limit(1)
          .get();

      if (existingQuery.docs.isNotEmpty) {
        if (mounted) {
           ScaffoldMessenger.of(context).showSnackBar(
             const SnackBar(
               content: Text('Member with this mobile number already exists!'),
               backgroundColor: Colors.red,
             )
           );
        }
        return;
      }

      final student = Student(
        id: '',
        ownerId: widget.ownerId,
        name: _nameController.text,
        photoUrl: '',
        mobileNumber: _mobileController.text,
        monthlyFee: 0.0,
        active: true,
        createdAt: DateTime.now(),
        messStartDate: DateTime.now(),
        messType: 'Two Time',
        plateCount: 0,
      );

      await db.addStudent(student);
      
      if (mounted) {
        _showSuccessDialog(db);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _showSuccessDialog(DatabaseService db) async {
    final ownerDoc = await FirebaseFirestore.instance.collection('owners').doc(widget.ownerId).get();
    final owner = Owner.fromDocument(ownerDoc);
    final whatsappLink = owner.whatsappGroupLink;

    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Icon(Icons.check_circle, color: Colors.green, size: 60),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Registration Successful!', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(height: 10),
            const Text('Welcome to the mess! Your account is now active.', textAlign: TextAlign.center),
            if (whatsappLink.isNotEmpty) ...[
              const SizedBox(height: 20),
              const Text('Join our WhatsApp group for updates:'),
            ],
          ],
        ),
        actions: [
          if (whatsappLink.isNotEmpty)
            TextButton(
              onPressed: () => launchUrl(Uri.parse(whatsappLink)),
              child: const Text('Join Group', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}
