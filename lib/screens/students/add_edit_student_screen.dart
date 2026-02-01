import 'package:flutter/material.dart';
import '../../models/student_model.dart';
import '../../services/database_service.dart';
import '../../services/auth_service.dart';
import 'package:provider/provider.dart';

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
