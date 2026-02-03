import 'package:flutter/material.dart';
import '../../models/student_model.dart';
import '../../services/database_service.dart';
import '../../services/auth_service.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AddEditStudentScreen extends StatefulWidget {
  final Student? student;
  const AddEditStudentScreen({super.key, this.student});

  @override
  State<AddEditStudentScreen> createState() => _AddEditStudentScreenState();
}

class _AddEditStudentScreenState extends State<AddEditStudentScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _mobileController;
  late String _messType;
  bool _isLoading = false;
  
  // Payment variables
  bool _markInitialPayment = false;
  final TextEditingController _paymentAmountController = TextEditingController();
  String _paymentMode = 'Cash';

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.student?.name ?? '');
    _mobileController = TextEditingController(text: widget.student?.mobileNumber ?? '');
    _messType = widget.student?.messType ?? 'Two Time';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _mobileController.dispose();
    _paymentAmountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context, listen: false);
    final db = DatabaseService(uid: authService.currentUser!.uid);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.student == null ? 'Add Member' : 'Edit Member'),
        actions: widget.student != null ? [
          IconButton(
            icon: const Icon(Icons.delete, color: Colors.red),
            onPressed: () => _confirmDelete(context, db),
          )
        ] : null,
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(labelText: 'Name', prefixIcon: Icon(Icons.person)),
                  validator: (v) => v!.isEmpty ? 'Enter name' : null,
                ),
                const SizedBox(height: 15),
                TextFormField(
                  controller: _mobileController,
                  decoration: const InputDecoration(labelText: 'Mobile Number', prefixIcon: Icon(Icons.phone)),
                  keyboardType: TextInputType.phone,
                  validator: (v) => v!.length < 10 ? 'Enter valid number' : null,
                ),
                const SizedBox(height: 20),
                const Text('Mess Plan Type', style: TextStyle(fontWeight: FontWeight.bold)),
                RadioListTile<String>(
                  title: const Text('One Time (Only Lunch/Dinner)'),
                  value: 'One Time',
                  groupValue: _messType,
                  onChanged: (v) => setState(() => _messType = v!),
                ),
                RadioListTile<String>(
                  title: const Text('Two Time (Lunch & Dinner)'),
                  value: 'Two Time',
                  groupValue: _messType,
                  onChanged: (v) => setState(() => _messType = v!),
                ),
                const SizedBox(height: 30),
                const SizedBox(height: 15),
                // Payment Section (Only for new students)
                if (widget.student == null) ...[
                  const Divider(),
                  CheckboxListTile(
                    title: const Text('Mark Initial Payment (e.g. Advance/Full)'),
                    value: _markInitialPayment,
                    onChanged: (v) => setState(() => _markInitialPayment = v!),
                  ),
                  if (_markInitialPayment) ...[
                    TextFormField(
                       controller: _paymentAmountController,
                       decoration: const InputDecoration(labelText: 'Amount Paid', prefixIcon: Icon(Icons.currency_rupee)),
                       keyboardType: TextInputType.number,
                       validator: (v) => _markInitialPayment && v!.isEmpty ? 'Enter amount' : null,
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
                  ],
                  const Divider(),
                ],
                const SizedBox(height: 30),
                ElevatedButton(
                  onPressed: () => _save(db),
                  child: Text(widget.student == null ? 'Add Member' : 'Update Member'),
                ),
              ],
            ),
          ),
    );
  }

  Future<void> _save(DatabaseService db) async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      double fee = widget.student?.monthlyFee ?? 0;

      // If adding new student, fetch current pricing from Owner settings
      if (widget.student == null) {
        final owner = await db.getOwner(db.uid);
        if (owner != null) {
          fee = _messType == 'One Time' ? owner.oneTimeFee : owner.twoTimeFee;
        }
      }

      final student = Student(
        id: widget.student?.id ?? '',
        ownerId: db.uid,
        name: _nameController.text,
        photoUrl: widget.student?.photoUrl ?? '',
        mobileNumber: _mobileController.text,
        monthlyFee: fee, 
        active: widget.student?.active ?? true,
        createdAt: widget.student?.createdAt ?? DateTime.now(),
        messStartDate: widget.student?.messStartDate ?? DateTime.now(),
        messType: _messType,
        plateCount: widget.student?.plateCount ?? 0,
      );

      if (widget.student == null) {
        await db.addStudent(student);
        
        // --- 1. Record Initial Payment ---
        if (_markInitialPayment) {
           double amount = double.tryParse(_paymentAmountController.text) ?? 0;
           if (amount > 0) {
             final now = DateTime.now();
             // Assuming monthly payment logic, or just a one-off
             // We'll mark it for the current month
             final monthStr = "${now.year}-${now.month.toString().padLeft(2,'0')}";
             
             // We need the student ID. addStudent doesn't return ID directly easily without fetching 
             // BUT `db.addStudent` in our service uses .add(). Let's fetch the student by mobile to get ID
             // Optimally we should refactor addStudent to return ID. 
             // For now, let's fetch by mobile.
             try {
                final addedStudentSnap = await FirebaseFirestore.instance
                  .collection('students')
                  .where('ownerId', isEqualTo: db.uid)
                  .where('mobileNumber', isEqualTo: student.mobileNumber)
                  .limit(1)
                  .get();
                  
                if (addedStudentSnap.docs.isNotEmpty) {
                  final addedId = addedStudentSnap.docs.first.id;
                  await db.markPayment(addedId, monthStr, student.monthlyFee, amount);
                }
             } catch (e) {
               print('Error marking payment: $e');
             }
           }
        }
        
        // --- 2. WhatsApp Invite Logic ---
        try {
          final owner = await db.getOwner(db.uid);
          if (owner != null && owner.whatsappGroupLink.isNotEmpty) {
            final link = owner.whatsappGroupLink;
            final mess = owner.messName;
            final msg = 'Hello ${student.name}, Welcome to $mess! Please join our WhatsApp group: $link';
            final encodedMsg = Uri.encodeComponent(msg);
            final url = Uri.parse('https://wa.me/${student.mobileNumber}?text=$encodedMsg');
            
            // Launch WhatsApp
            if (await canLaunchUrl(url)) {
              await launchUrl(url, mode: LaunchMode.externalApplication);
            }
          }
        } catch (e) {
          print('Error launching WhatsApp: $e');
        }
        // -----------------------------

      } else {
        await db.updateStudent(student);
      }
      
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _confirmDelete(BuildContext context, DatabaseService db) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Member?'),
        content: const Text('This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              await db.deleteStudent(widget.student!.id);
              if (mounted) {
                Navigator.pop(ctx);
                Navigator.pop(context);
              }
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
