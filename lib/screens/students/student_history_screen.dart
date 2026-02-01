import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/student_model.dart';
import '../../models/attendance_model.dart';
import '../../services/database_service.dart';
import '../../services/auth_service.dart';

class StudentHistoryScreen extends StatefulWidget {
  final Student student;

  const StudentHistoryScreen({super.key, required this.student});

  @override
  State<StudentHistoryScreen> createState() => _StudentHistoryScreenState();
}

class _StudentHistoryScreenState extends State<StudentHistoryScreen> {
  @override
  Widget build(BuildContext context) {
    final user = Provider.of<AuthService>(context, listen: false).currentUser;
    if (user == null) return const Scaffold(body: Center(child: Text('Error: No User')));
    
    final db = DatabaseService(uid: user.uid);

    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.student.name}\'s History'),
      ),
      body: StreamBuilder<Student?>(
        stream: db.getStudentStream(widget.student.id),
        builder: (context, studentSnapshot) {
          if (!studentSnapshot.hasData) return const Center(child: CircularProgressIndicator());
          
          final student = studentSnapshot.data!;
          final int plateCount = student.plateCount;
          final DateTime? startDate = student.messStartDate;
          final String startDateStr = startDate != null ? DateFormat('dd MMM').format(startDate) : '-';

          return Column(
            children: [
               // Cycle Card
               Card(
                 margin: const EdgeInsets.all(16),
                 color: plateCount >= 28 ? Colors.red.shade100 : Colors.blue.shade50,
                 child: Padding(
                   padding: const EdgeInsets.all(16.0),
                   child: Column(
                     children: [
                       Row(
                         mainAxisAlignment: MainAxisAlignment.spaceBetween,
                         children: [
                           const Text('Current Cycle Usage', style: TextStyle(fontWeight: FontWeight.bold)),
                           Text('Started: $startDateStr', style: const TextStyle(color: Colors.grey)),
                         ],
                       ),
                       const SizedBox(height: 16),
                       Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Text(
                              '$plateCount', 
                              style: TextStyle(
                                fontSize: 48, 
                                fontWeight: FontWeight.bold,
                                color: plateCount >= 28 ? Colors.red : Colors.blue
                              )
                            ),
                            const Text('/28 Plates', style: TextStyle(fontSize: 20, color: Colors.grey)),
                          ],
                       ),
                       const SizedBox(height: 16),
                       if (plateCount >= 28)
                          const Text(
                            '⚠ Limit Reached! Excess plates will carry over.',
                            style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                          ),
                       const SizedBox(height: 16),
                       ElevatedButton.icon(
                         icon: const Icon(Icons.refresh),
                         label: const Text('Renew / Reset Cycle'),
                         style: ElevatedButton.styleFrom(
                           backgroundColor: Colors.white,
                           foregroundColor: Colors.blue,
                         ),
                         onPressed: () async {
                            final confirm = await showDialog<bool>(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: const Text('Renew Membership?'),
                                content: const Text(
                                  'This will reset the cycle start date to TODAY.\n'
                                  'Any plates above 28 will be carried over.\n\n'
                                  'Proceed only if payment is received.'
                                ),
                                actions: [
                                  TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                                  ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Confirm Renew')),
                                ],
                              ),
                            );
                            
                            if (confirm == true) {
                               await db.renewMembership(widget.student.id);
                               if (context.mounted) {
                                 ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Membership Renewed!')));
                               }
                            }
                         },
                       ),
                     ],
                   ),
                 ),
               ),

              Expanded(
                child: StreamBuilder<List<Attendance>>(
                  stream: db.getStudentAttendanceHistory(widget.student.id), 
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    
                    if (!snapshot.hasData || snapshot.data!.isEmpty) {
                       return const Center(child: Text('No attendance records found.'));
                    }

                    final records = snapshot.data!;
                    
                    // Calculate Stats
                    int totalLunch = 0;
                    int totalDinner = 0;
                    int vegCount = 0;
                    int nonVegCount = 0;

                    for (var r in records) {
                       if (r.lunch) {
                         totalLunch++;
                         if (r.lunchVariant == 'Non-Veg') nonVegCount++;
                         else vegCount++; 
                       }
                       if (r.dinner) {
                         totalDinner++;
                         if (r.dinnerVariant == 'Non-Veg') nonVegCount++;
                         else vegCount++;
                       }
                    }

                    return Column(
                      children: [
                        // Stats Cards
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Row(
                            children: [
                               _buildStatCard('Lunch', totalLunch.toString(), Colors.orange),
                               const SizedBox(width: 8),
                               _buildStatCard('Dinner', totalDinner.toString(), Colors.indigo),
                               const SizedBox(width: 8),
                               _buildStatCard('Veg', vegCount.toString(), Colors.green),
                               const SizedBox(width: 8),
                               _buildStatCard('Non-Veg', nonVegCount.toString(), Colors.red),
                            ],
                          ),
                        ),
                        const Divider(),
                        
                        // List
                        Expanded(
                          child: ListView.builder(
                            itemCount: records.length,
                            itemBuilder: (context, index) {
                              final record = records[index];
                              return ListTile(
                                title: Text(record.date),
                                subtitle: Text(
                                  (record.lunch ? 'Lunch (${record.lunchVariant ?? "Veg"}) ' : '') +
                                  (record.dinner ? 'Dinner (${record.dinnerVariant ?? "Veg"})' : '')
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildStatCard(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color),
        ),
        child: Column(
          children: [
            Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
            Text(label, style: TextStyle(fontSize: 12, color: color)),
          ],
        ),
      ),
    );
  }
}
