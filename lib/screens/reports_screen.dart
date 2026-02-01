import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../services/auth_service.dart';
import '../../services/database_service.dart';
import '../../models/student_model.dart';
import '../../models/attendance_model.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  DateTime _selectedDate = DateTime.now();
  DateTime _selectedMonth = DateTime.now();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2023),
      lastDate: DateTime(2030),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  void _pickMonth() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedMonth,
      firstDate: DateTime(2023),
      lastDate: DateTime(2030),
      helpText: 'SELECT MONTH',
    );
    if (picked != null) setState(() => _selectedMonth = picked);
  }

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<AuthService>(context, listen: false).currentUser;
    final db = DatabaseService(uid: user!.uid);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Reports'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Daily Summary'),
            Tab(text: 'Monthly Attendance'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildDailyTab(db),
          _buildMonthlyTab(db),
        ],
      ),
    );
  }

  Widget _buildDailyTab(DatabaseService db) {
    final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                DateFormat('EEE, MMM d, y').format(_selectedDate),
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              IconButton(
                icon: const Icon(Icons.calendar_today),
                onPressed: _pickDate,
              ),
            ],
          ),
          const SizedBox(height: 20),
          StreamBuilder<List<Attendance>>(
            stream: db.getAttendanceStream(dateStr),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const CircularProgressIndicator();
              }
              final list = snapshot.data ?? [];
              final lunchCount = list.where((a) => a.lunch).length;
              final dinnerCount = list.where((a) => a.dinner).length;
              final totalCount = lunchCount + dinnerCount;

              return Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                          child: _statCard('Lunch', lunchCount, Colors.orange)),
                      const SizedBox(width: 16),
                      Expanded(
                          child: _statCard('Dinner', dinnerCount, Colors.indigo)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _statCard('Total', totalCount, const Color(0xFF6C63FF), isTotal: true),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _statCard(String title, int count, Color color, {bool isTotal = false}) {
    return Card(
      elevation: isTotal ? 8 : 4,
      color: color,
      child: Padding(
        padding: EdgeInsets.all(isTotal ? 32.0 : 24.0),
        child: Column(
          children: [
            Text(
              '$count',
              style: TextStyle(
                  fontSize: isTotal ? 56 : 36, 
                  fontWeight: FontWeight.bold, 
                  color: Colors.white),
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: isTotal ? 20 : 16, 
                color: Colors.white70,
                fontWeight: isTotal ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMonthlyTab(DatabaseService db) {
    final monthStr = DateFormat('yyyy-MM').format(_selectedMonth);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                DateFormat('MMMM yyyy').format(_selectedMonth),
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              IconButton(
                icon: const Icon(Icons.calendar_month),
                onPressed: _pickMonth,
              ),
            ],
          ),
        ),
        Expanded(
          child: StreamBuilder<List<Student>>(
            stream: db.studentsStream,
            builder: (context, studentSnapshot) {
              if (!studentSnapshot.hasData) return const SizedBox();
              final students = studentSnapshot.data!;

              return StreamBuilder<List<Attendance>>(
                stream: db.getMonthlyAttendanceStream(monthStr),
                builder: (context, attSnapshot) {
                  if (attSnapshot.connectionState == ConnectionState.waiting) {
                     return const Center(child: CircularProgressIndicator());
                  }
                  final allAttendance = attSnapshot.data ?? [];

                  return ListView.separated(
                    itemCount: students.length,
                    separatorBuilder: (_, __) => const Divider(),
                    itemBuilder: (context, index) {
                      final student = students[index];
                      // Filter attendance for this student
                      final studentAtt = allAttendance
                          .where((a) => a.studentId == student.id)
                          .toList();
                      
                      final lunchDays = studentAtt.where((a) => a.lunch).length;
                      final dinnerDays = studentAtt.where((a) => a.dinner).length;

                      return ListTile(
                        leading: CircleAvatar(child: Text(student.name[0])),
                        title: Text(student.name),
                        subtitle: Text('Lunch: $lunchDays | Dinner: $dinnerDays'),
                        trailing: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                              color: Colors.blue.shade50,
                              borderRadius: BorderRadius.circular(8)),
                          child: Text(
                            'Total: ${lunchDays + dinnerDays}',
                            style: const TextStyle(fontWeight: FontWeight.bold),
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
    );
  }
}
