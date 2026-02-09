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
  String _selectedMessType = 'Two Time'; // Default selection
  double _selectedFee = 0.0; // Will be set from owner settings
  
  // Payment vars
  final _paymentAmountController = TextEditingController();
  String _paymentMode = 'Online';


  @override
  void dispose() {
    _nameController.dispose();
    _mobileController.dispose();
    _paymentAmountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final db = DatabaseService(uid: widget.ownerId);

    return Scaffold(
      body: Stack(
        children: [
          Container(
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
                            'Join Mess',
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
                          const SizedBox(height: 30),
                          StreamBuilder<Owner?>(
                            stream: db.ownerStream,
                            builder: (context, snapshot) {
                              if (!snapshot.hasData) {
                                return const CircularProgressIndicator();
                              }
                              final owner = snapshot.data!;
                              
                              // Initialize fee on first build (safe way)
                              if (_selectedFee == 0.0) {
                                WidgetsBinding.instance.addPostFrameCallback((_) {
                                  if (mounted) {
                                    setState(() {
                                      _selectedFee = _selectedMessType == 'One Time' 
                                          ? owner.oneTimeFee 
                                          : owner.twoTimeFee;
                                    });
                                  }
                                });
                              }
                              
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Select Mess Plan',
                                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 12),
                                  RadioListTile<String>(
                                    title: Text('One Time - ₹${owner.oneTimeFee.toInt()}/month', style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color)),
                                    subtitle: Text('Lunch OR Dinner (choose one daily)', style: TextStyle(color: Theme.of(context).hintColor)),
                                    value: 'One Time',
                                    groupValue: _selectedMessType,
                                    onChanged: (value) {
                                      setState(() {
                                        _selectedMessType = value!;
                                        _selectedFee = owner.oneTimeFee;
                                      });
                                    },
                                  ),
                                  RadioListTile<String>(
                                    title: Text('Two Time - ₹${owner.twoTimeFee.toInt()}/month', style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color)),
                                    subtitle: Text('Lunch AND Dinner (both meals daily)', style: TextStyle(color: Theme.of(context).hintColor)),
                                    value: 'Two Time',
                                    groupValue: _selectedMessType,
                                    onChanged: (value) {
                                      setState(() {
                                        _selectedMessType = value!;
                                        _selectedFee = owner.twoTimeFee;
                                      });
                                    },
                                  ),
                                ],
                              );
                            }
                          ),
                          const SizedBox(height: 20),
                          const Divider(),
                          const Text('Payment Details (Optional)', style: TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 10),
                          TextFormField(
                            controller: _paymentAmountController,
                            decoration: const InputDecoration(labelText: 'Amount Paid (₹)', prefixIcon: Icon(Icons.currency_rupee)),
                            keyboardType: TextInputType.number,
                          ),
                          const SizedBox(height: 10),
                          DropdownButtonFormField<String>(
                            value: _paymentMode,
                            decoration: const InputDecoration(labelText: 'Payment Mode', prefixIcon: Icon(Icons.payment)),
                            items: ['Cash', 'Online', 'UPI'].map((String value) {
                              return DropdownMenuItem<String>(
                                value: value,
                                child: Text(value),
                              );
                            }).toList(),
                            onChanged: (v) => setState(() => _paymentMode = v!),
                          ),
                          const Divider(),
                          const SizedBox(height: 20),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : () => _register(db),
                              child: _isLoading 
                                ? const CircularProgressIndicator(color: Colors.white)
                                : const Text('Register Now'),
                            ),
                          ),
                          const SizedBox(height: 20),
                          TextButton(
                            onPressed: () => _showStatusCheckDialog(db),
                            child: const Text('Already applied? Check Status'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            top: 20,
            left: 20,
            child: SafeArea(
              child: CircleAvatar(
                backgroundColor: Theme.of(context).cardColor,
                child: IconButton(
                  icon: Icon(Icons.arrow_back, color: Theme.of(context).iconTheme.color),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ),
          ),
        ],
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
          .where('mobileNumber', isEqualTo: _mobileController.text.trim())
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
        name: _nameController.text.trim(),
        photoUrl: '',
        mobileNumber: _mobileController.text.trim(),
        monthlyFee: _selectedFee,
        active: false, // Pending Approval
        createdAt: DateTime.now(),
        messStartDate: DateTime.now(),
        messType: _selectedMessType,
        plateCount: 0,
        pendingPayment: double.tryParse(_paymentAmountController.text) ?? 0.0,
        pendingPaymentMode: _paymentMode,
      );

      await db.addStudent(student);
      
      if (mounted) {
        _showPendingDialog(db);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _showStatusCheckDialog(DatabaseService db) async {
    final statusMobileController = TextEditingController();
    
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Check Application Status'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Enter your registered mobile number:'),
            const SizedBox(height: 15),
            TextField(
              controller: statusMobileController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Mobile Number',
                prefixIcon: Icon(Icons.phone),
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (statusMobileController.text.length < 10) {
                 ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter valid number')));
                 return;
              }
              Navigator.pop(ctx); // Close input dialog
              _checkStatus(statusMobileController.text.trim(), db);
            },
            child: const Text('Check'),
          ),
        ],
      ),
    );
  }

  Future<void> _checkStatus(String mobile, DatabaseService db) async {
    setState(() => _isLoading = true);
    try {
      final query = await FirebaseFirestore.instance
          .collection('students')
          .where('ownerId', isEqualTo: widget.ownerId)
          .where('mobileNumber', isEqualTo: mobile)
          .limit(1)
          .get();

      if (!mounted) return;

      if (query.docs.isEmpty) {
        _showResultDialog(
          icon: Icons.error_outline,
          color: Colors.red,
          title: 'Not Found',
          message: 'No application found for this number.\nPlease register properly or contact the owner.',
        );
      } else {
        final data = query.docs.first.data();
        final bool isActive = data['active'] ?? false;
        final String name = data['name'] ?? 'Member';

        if (isActive) {
           // Fetch owner link again just in case (or reuse stream/db)
           final ownerDoc = await FirebaseFirestore.instance.collection('owners').doc(widget.ownerId).get();
           final whatsapp = ownerDoc.data()?['whatsappGroupLink'] ?? '';
           
           _showResultDialog(
             icon: Icons.check_circle,
             color: Colors.green,
             title: 'Approved!',
             message: 'Welcome, $name!\nYour registration is approved.',
             whatsappLink: whatsapp,
           );
        } else {
          _showResultDialog(
            icon: Icons.hourglass_top,
            color: Colors.orange,
            title: 'Pending',
            message: 'Hello $name,\nYour application is still under review.\nPlease wait for the owner to approve.',
          );
        }
      }

    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showResultDialog({
    required IconData icon, 
    required Color color, 
    required String title, 
    required String message, 
    String? whatsappLink
  }) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Icon(icon, color: color, size: 50),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(height: 10),
            Text(message, textAlign: TextAlign.center),
            if (whatsappLink != null && whatsappLink.isNotEmpty) ...[
               const SizedBox(height: 20),
               ElevatedButton.icon(
                 onPressed: () => launchUrl(Uri.parse(whatsappLink)),
                 icon: const Icon(Icons.chat),
                 label: const Text('Join Group Now'),
                 style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
               )
            ]
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
        ],
      ),
    );
  }

  Future<void> _showPendingDialog(DatabaseService db) async {
    if (!mounted) return;

    // Use a StreamBuilder dialog to listen for changes
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('students')
            .where('ownerId', isEqualTo: widget.ownerId)
            .where('mobileNumber', isEqualTo: _mobileController.text.trim())
            .limit(1)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
            final data = snapshot.data!.docs.first.data() as Map<String, dynamic>;
            final isActive = data['active'] ?? false;

            // If Approved, Close this dialog and show Success
            if (isActive) {
              WidgetsBinding.instance.addPostFrameCallback((_) async {
                Navigator.pop(ctx); // Close waiting dialog
                
                // Fetch whatsapp link
                final ownerDoc = await FirebaseFirestore.instance.collection('owners').doc(widget.ownerId).get();
                final whatsapp = ownerDoc.data()?['whatsappGroupLink'] ?? '';

                if (mounted) {
                  _showResultDialog(
                    icon: Icons.check_circle, 
                    color: Colors.green, 
                    title: 'Approved!', 
                    message: 'Welcome, ${data['name']}!\nYour registration is approved.',
                    whatsappLink: whatsapp
                  );
                }
              });
            }
          }

          return PopScope(
            canPop: false,
            child: AlertDialog(
              title: const Icon(Icons.hourglass_top, color: Colors.orange, size: 60),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Waiting for Approval...', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                  const SizedBox(height: 10),
                  Text('Please wait while the owner approves your request.\nDo not close this screen.', textAlign: TextAlign.center, style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color)),
                  const SizedBox(height: 20),
                  const CircularProgressIndicator(),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Close & Check Later'),
                ),
              ],
            ),
          );
        }
      ),
    );
  }
}
