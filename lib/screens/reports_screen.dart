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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        children: [
          // Date Picker Card
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Theme.of(context).dividerColor.withOpacity(0.1)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Selected Date',
                      style: TextStyle(fontSize: 12, color: Theme.of(context).hintColor),
                    ),
                    Text(
                      DateFormat('EEE, MMM d, y').format(_selectedDate),
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.calendar_today, color: Color(0xFF6C63FF)),
                  onPressed: _pickDate,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          
          Expanded(
            child: StreamBuilder<List<Attendance>>(
              stream: db.getAttendanceStream(dateStr),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final list = snapshot.data ?? [];
                final lunchCount = list.where((a) => a.lunch).length;
                final dinnerCount = list.where((a) => a.dinner).length;
                final totalCount = lunchCount + dinnerCount;

                return Column(
                  children: [
                    _buildSummaryCard('Total Meals', totalCount, const Color(0xFF6C63FF), Icons.restaurant),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _buildSummaryCard('Lunch', lunchCount, Colors.orange, Icons.wb_sunny, isSmall: true),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildSummaryCard('Dinner', dinnerCount, Colors.indigo, Icons.nights_stay, isSmall: true),
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(String title, int count, Color color, IconData icon, {bool isSmall = false}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(isDark ? 0.05 : 0.1),
            blurRadius: 16,
            offset: const Offset(0, 8),
          )
        ],
        border: Border.all(color: color.withOpacity(0.3), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: isSmall ? 20 : 28),
          ),
          const SizedBox(height: 16),
          Text(
            '$count',
            style: TextStyle(
              fontSize: isSmall ? 32 : 48, 
              fontWeight: FontWeight.bold, 
              color: isDark ? Colors.white : Colors.black87,
              height: 1.0,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              fontSize: isSmall ? 14 : 16, 
              color: Theme.of(context).hintColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
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
                  if (attSnapshot.hasError) {
                    return Center(child: Text('Error loading data: ${attSnapshot.error}'));
                  }
                  if (attSnapshot.connectionState == ConnectionState.waiting) {
                     return const Center(child: CircularProgressIndicator());
                  }
                  
                  final allAttendance = attSnapshot.data ?? [];
                  // debug print in console (for developer)
                  print('Monthly Report: Found ${allAttendance.length} records for $monthStr');

                  if (allAttendance.isEmpty) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(20),
                        child: Text('No attendance records found for this month.'),
                      ),
                    );
                  }

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
                        leading: CircleAvatar(child: Text(student.name.isNotEmpty ? student.name[0] : '?')),
                        title: Text(student.name),
                        subtitle: Text('Lunch: $lunchDays | Dinner: $dinnerDays'),
                        trailing: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                              color: Colors.blue.shade50,
                              borderRadius: BorderRadius.circular(8)),
                          child: Text(
                            'Total: ${lunchDays + dinnerDays}',
                            style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue), // Fixed color for visibility
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
