import 'package:flutter/material.dart';
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
      final db = DatabaseService(uid: user.uid);
      await db.initializeAttendanceForDate(_formattedDate);
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
            color: Colors.white,
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
          Expanded(
            child: StreamBuilder<List<Student>>(
              stream: db.studentsStream,
              builder: (context, studentSnapshot) {
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
                                  () => db.markAttendance(
                                    record.studentId,
                                    _formattedDate,
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
                                  () => db.markAttendance(
                                    record.studentId,
                                    _formattedDate,
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

  Widget _buildToggle(BuildContext context, String label, bool value,
      bool enabled, VoidCallback onTap) {
    // Green = Present, Red = Absent/Unpaid? 
    // Requirement: Green = Paid / Present, Red = Unpaid / Absent
    
    // Logic: If 'value' (present), show Green. If not, show Red? 
    // Or Red means "Absent explicitly"? 
    // Toggles usually are On/Off. 
    // I'll make the active color Green and inactive Red (or Grey?).
    // Requirement says "Big buttons... Green = Paid / Present".
    
    return Expanded(
      flex: 1,
      child: GestureDetector(
        onTap: enabled ? onTap : null,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: value ? Colors.green : Colors.red.withOpacity(0.2), 
            // If absent, maybe light red or grey? User said "Red = Unpaid / Absent".
            // So if value is false, it should be Red?
            // "Green = Paid / Present, Red = Unpaid / Absent"
            // Let's make it SOLID Green if True, SOLID Red if False.
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
               color: value ? Colors.green.shade700 : Colors.red.shade700,
               width: 2 
            ),
          ),
          child: Column(
            children: [
              Text(
                label,
                style: TextStyle(
                  color: value ? Colors.white : Colors.red.shade900,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 4),
              Icon(
                value ? Icons.check_circle : Icons.cancel,
                color: value ? Colors.white : Colors.red,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
