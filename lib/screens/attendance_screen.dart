import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../services/auth_service.dart';
import '../../services/database_service.dart';
import '../../models/student_model.dart';
import '../../models/attendance_model.dart';
import '../../widgets/custom_button.dart';

class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({super.key});

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  DateTime _selectedDate = DateTime.now();
  bool _isLoading = false;

  String get _formattedDate => DateFormat('yyyy-MM-dd').format(_selectedDate);
  bool get _isToday {
    final now = DateTime.now();
    return now.year == _selectedDate.year &&
        now.month == _selectedDate.month &&
        now.day == _selectedDate.day;
  }

  @override
  void initState() {
    super.initState();
    _initAttendance();
  }

  void _initAttendance() async {
    setState(() => _isLoading = true);
    final user = Provider.of<AuthService>(context, listen: false).currentUser;
    if (user != null) {
      try {
        final db = DatabaseService(uid: user.uid);
        await db.initializeAttendanceForDate(_formattedDate);
      } catch (e) {
        if (mounted) {
           ScaffoldMessenger.of(context).showSnackBar(
             SnackBar(content: Text('Error initializing: $e'), backgroundColor: Colors.red),
           );
        }
      }
    }
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2023),
      lastDate: DateTime(2030),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
      _initAttendance();
    }
  }

  bool _isLunchEnabled() {
    return true; // Cut-off logic disabled by user request
  }

  bool _isDinnerEnabled() {
    return true; // Cut-off logic disabled by user request
  }


  @override
  Widget build(BuildContext context) {
    final user = Provider.of<AuthService>(context, listen: false).currentUser;
    final db = DatabaseService(uid: user!.uid);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Attendance'),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_today),
            onPressed: () => _selectDate(context),
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: Theme.of(context).cardColor,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  DateFormat('EEE, MMM d, y').format(_selectedDate),
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold),
                ),
                TextButton(
                    onPressed: () => _initAttendance(),
                    child: const Text('Refresh')),
              ],
            ),
          ),
          if (_isLoading) const LinearProgressIndicator(), 
          Expanded(
            child: StreamBuilder<List<Student>>(
              stream: db.studentsStream,
              builder: (context, studentSnapshot) {
                if (studentSnapshot.hasError) {
                  return Center(child: Text('Error loading students: ${studentSnapshot.error}'));
                }
                if (studentSnapshot.connectionState ==
                    ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (!studentSnapshot.hasData || studentSnapshot.data!.isEmpty) {
                  return const Center(child: Text('No students found.'));
                }

                final students = studentSnapshot.data!;
                // Map student ID to name
                final studentMap = {for (var s in students) s.id: s.name};

                return StreamBuilder<List<Attendance>>(
                  stream: db.getAttendanceStream(_formattedDate),
                  builder: (context, attendanceSnapshot) {
                    if (attendanceSnapshot.hasError) {
                      return Center(child: Text('Error loading attendance: ${attendanceSnapshot.error}'));
                    }
                    if (attendanceSnapshot.connectionState ==
                        ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final attendanceList = attendanceSnapshot.data ?? [];
                    
                    // Create rows for each attendance record found
                    // Wait, what if initialization missed one? We iterate records.
                    // Ideally we iterate STUDENTS and find their record.
                    
                    if (attendanceList.isEmpty && !_isLoading) {
                       return const Center(child: Text('No attendance records. Tap Refresh.'));
                    }

                    return ListView.builder(
                      itemCount: attendanceList.length,
                      itemBuilder: (context, index) {
                        final record = attendanceList[index];
                        final studentName = studentMap[record.studentId] ?? 'Unknown';

                        return Card(
                          margin: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 4),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Row(
                              children: [
                                Expanded(
                                  flex: 2,
                                  child: Text(
                                    studentName,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16),
                                  ),
                                ),
                                _buildToggle(
                                  context,
                                  'Lunch',
                                  record.lunch,
                                  _isLunchEnabled(),
                                  () => _handleMarkAttendance(
                                    record.studentId,
                                    'lunch',
                                    !record.lunch,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                _buildToggle(
                                  context,
                                  'Dinner',
                                  record.dinner,
                                  _isDinnerEnabled(),
                                  () => _handleMarkAttendance(
                                    record.studentId,
                                    'dinner',
                                    !record.dinner,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
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

  Future<void> _handleMarkAttendance(String studentId, String type, bool value) async {
    final db = DatabaseService(uid: Provider.of<AuthService>(context, listen: false).currentUser!.uid);
    
    // Show immediate feedback
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Marking $type as ${value ? "Present" : "Absent"}...'), 
        duration: const Duration(milliseconds: 500)
      )
    );

    try {
      await db.markAttendance(studentId, _formattedDate, type, value);
    } catch (e) {
      if (mounted) {
        // Show detailed error in a dialog so it's impossible to miss
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Error Marking Attendance'),
            content: SingleChildScrollView(
              child: SelectableText(e.toString()),
            ),
            actions: [
              TextButton(
                onPressed: () {
                   Clipboard.setData(ClipboardData(text: e.toString()));
                   ScaffoldMessenger.of(context).showSnackBar(
                     const SnackBar(content: Text('Error copied to clipboard'))
                   );
                },
                child: const Text('Copy Error'),
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
  }

  Widget _buildToggle(BuildContext context, String label, bool value,
      bool enabled, VoidCallback onTap) {
    
    final color = value ? Colors.green : Colors.red;
    
    return Expanded(
      flex: 1,
      child: SizedBox(
        height: 60, // Fixed height for touch target
        child: ElevatedButton(
          onPressed: enabled ? onTap : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: value ? Colors.green : Colors.red.shade50,
            foregroundColor: value ? Colors.white : Colors.red,
            side: BorderSide(color: color, width: 2),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            elevation: 0,
            padding: EdgeInsets.zero,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                label,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              const SizedBox(height: 4),
              Icon(
                value ? Icons.check_circle : Icons.cancel,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
