import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/auth_service.dart';
import '../services/database_service.dart';
import '../models/attendance_model.dart';
import '../models/payment_model.dart';
import '../models/menu_model.dart';
import '../models/student_model.dart';
import '../models/owner_model.dart';
import '../widgets/dashboard_card.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_animate/flutter_animate.dart';

import 'students/students_list_screen.dart';
import 'attendance_screen.dart';
import 'menu_screen.dart';
import 'payments_screen.dart';
import 'reports_screen.dart';
import 'qr_invite_screen.dart';
import 'settings_screen.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context, listen: false);
    final user = authService.currentUser;
    final databaseService = DatabaseService(uid: user!.uid);
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final currentMonth = DateFormat('yyyy-MM').format(DateTime.now());

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F8),
      extendBodyBehindAppBar: true, // Make AppBar transparent over gradient
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Dashboard', style: TextStyle(color: Colors.white)),
        actions: [
          // Notification Bell
          Stack(
            children: [
              InkWell(
                onTap: () => _showExpiredPlansSheet(context, databaseService),
                borderRadius: BorderRadius.circular(20),
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Image.asset(
                    'assets/images/bell_icon.png',
                    width: 22,
                    height: 22,
                    color: Colors.white,
                  ),
                ),
              ),
              Positioned(
                right: 4,
                top: 4,
                child: StreamBuilder<List<Student>>(
                  stream: databaseService.getExpiredStudentsStream(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData || snapshot.data!.isEmpty) {
                      return const SizedBox.shrink();
                    }
                    return Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                      constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                      child: Text(
                        '${snapshot.data!.length}',
                        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.qr_code_2, color: Colors.white),
            tooltip: 'Invite',
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const QrInviteScreen())),
          ),
          IconButton(
            icon: const Icon(Icons.settings, color: Colors.white),
            tooltip: 'Settings',
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const SettingsScreen())),
          ),
          IconButton(
            icon: const Icon(Icons.exit_to_app, color: Colors.white),
            tooltip: 'Logout',
            onPressed: () => authService.signOut(),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // 1. Curved Gradient Header
            Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.bottomCenter,
              children: [
                Container(
                  height: 320,
                  width: double.infinity,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFF6C63FF), Color(0xFF4834D4)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.vertical(bottom: Radius.circular(40)),
                  ),
                  padding: const EdgeInsets.fromLTRB(24, 100, 24, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      FutureBuilder<Owner?>(
                        future: databaseService.getOwner(user.uid),
                        builder: (context, snapshot) {
                          final name = snapshot.data?.name ?? user.displayName ?? "Owner";
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Welcome back,',
                                style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 16),
                              ).animate().fade(duration: 600.ms),
                              const SizedBox(height: 4),
                              Text(
                                name,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.5,
                                ),
                              ).animate().fade(duration: 600.ms).slideX(begin: 0.2, end: 0),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 24),
                      // Today's Date Badge
                      Container(
                         padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                         decoration: BoxDecoration(
                           color: Colors.white.withOpacity(0.2),
                           borderRadius: BorderRadius.circular(20),
                         ),
                         child: Row(
                           mainAxisSize: MainAxisSize.min,
                           children: [
                             const Icon(Icons.calendar_today, color: Colors.white, size: 16),
                             const SizedBox(width: 8),
                             Text(
                               DateFormat('EEEE, d MMMM').format(DateTime.now()),
                               style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                             ),
                           ],
                         ),
                      )
                    ],
                  ),
                ),
                
                // 2. Overlapping Attendance Cards
                Positioned(
                  bottom: -60,
                  left: 20,
                  right: 20,
                  child: Row(
                    children: [
                      Expanded(child: _buildAttendanceCard(databaseService, today, 'Lunch', Colors.orange)),
                      const SizedBox(width: 16),
                      Expanded(child: _buildAttendanceCard(databaseService, today, 'Dinner', Colors.indigo)),
                    ],
                  ).animate().slideY(begin: 1, end: 0, curve: Curves.easeOutBack, duration: 600.ms, delay: 200.ms),
                  ),

              ],
            ),
            
            const SizedBox(height: 80), // Spacer for overlapping cards

            // 3. Main Content
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Live Guest Requests
                  _buildPendingGuestRequests(databaseService),
                  const SizedBox(height: 16),

                  // Guest Stats
                  _buildGuestCard(databaseService).animate().fade(delay: 300.ms).slideX(begin: -0.2, end: 0),
                  const SizedBox(height: 16),
                  
                  // Revenue
                  _buildRevenueCard(databaseService, currentMonth).animate().fade(delay: 400.ms).slideX(begin: 0.2, end: 0),
                  
                  const SizedBox(height: 24),
                  const Text(
                    'Quick Actions',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  
                  GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 3, // 3 columns looks cooler
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 0.9,
                    children: [

                      _CoolAction(Icons.how_to_reg, 'Attendance', Colors.blue, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AttendanceScreen()))).animate().fade(delay: 500.ms).scale(),
                      _CoolAction(Icons.group, 'Members', Colors.orange, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const StudentsListScreen()))).animate().fade(delay: 600.ms).scale(),
                      _CoolAction(Icons.restaurant_menu, 'Menu', Colors.pink, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MenuScreen()))).animate().fade(delay: 700.ms).scale(),
                      _CoolAction(Icons.account_balance_wallet, 'Payments', Colors.deepPurple, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PaymentsScreen()))).animate().fade(delay: 800.ms).scale(),
                      _CoolAction(Icons.analytics, 'Reports', Colors.teal, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ReportsScreen()))).animate().fade(delay: 900.ms).scale(),
                      _CoolAction(Icons.qr_code_2, 'QR Codes', Colors.blueGrey, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const QrInviteScreen()))).animate().fade(delay: 1000.ms).scale(),
                      _CoolAction(Icons.settings, 'Settings', Colors.grey, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen()))).animate().fade(delay: 1100.ms).scale(),
                    ],
                  ),

                  const SizedBox(height: 24),
                  const Text(
                    'Menu Highlights',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  _buildMenuCard(databaseService, today),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPendingGuestRequests(DatabaseService db) {
    return StreamBuilder<QuerySnapshot>(
      stream: db.getPendingGuestMealsStream(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text('Error: ${snapshot.error}', style: const TextStyle(color: Colors.red)),
          );
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const SizedBox.shrink();
        }

        final docs = snapshot.data!.docs;
        // Client-side sort (newest first)
        docs.sort((a, b) {
            final da = a.data() as Map<String, dynamic>;
            final db = b.data() as Map<String, dynamic>;
            final ta = da['timestamp'] as Timestamp?;
            final tb = db['timestamp'] as Timestamp?;
            if (ta == null || tb == null) return 0;
            return tb.compareTo(ta);
        });

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.orange.shade100),
            boxShadow: [
              BoxShadow(
                color: Colors.orange.withOpacity(0.1),
                blurRadius: 12,
                offset: const Offset(0, 4),
              )
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
               Row(
                 children: [
                   const Icon(Icons.notifications_active, color: Colors.orange),
                   const SizedBox(width: 8),
                   const Text(
                     'Live Guest Requests', 
                     style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)
                   ).animate().shimmer(duration: 2000.ms),
                 ],
               ),
               const SizedBox(height: 12),
               ListView.separated(
                 shrinkWrap: true,
                 physics: const NeverScrollableScrollPhysics(),
                 itemCount: docs.length,
                 separatorBuilder: (_, __) => const Divider(),
                 itemBuilder: (context, index) {
                   final doc = docs[index];
                   final data = doc.data() as Map<String, dynamic>;
                   final price = (data['price'] ?? 0).toDouble();
                   final variant = data['variant'] ?? 'Veg';
                   final payment = data['paymentMethod'] ?? 'Cash';
                   final isOnline = payment == 'Online';

                   return ListTile(
                     contentPadding: EdgeInsets.zero,
                     leading: CircleAvatar(
                       backgroundColor: variant == 'Non-Veg' ? Colors.red.shade50 : Colors.green.shade50,
                       child: Icon(
                         variant == 'Non-Veg' ? Icons.restaurant : Icons.eco,
                         color: variant == 'Non-Veg' ? Colors.red : Colors.green,
                         size: 20,
                       ),
                     ),
                     title: Text(
                       'Guest ($variant)',
                       style: const TextStyle(fontWeight: FontWeight.bold),
                     ),
                     subtitle: Text(
                       '₹${price.toInt()} • $payment',
                       style: TextStyle(
                         color: isOnline ? Colors.purple : Colors.grey[700],
                         fontWeight: FontWeight.w500
                       ),
                     ),
                     trailing: Row(
                       mainAxisSize: MainAxisSize.min,
                       children: [
                         IconButton(
                           icon: const Icon(Icons.close, color: Colors.red),
                           onPressed: () => db.updateGuestMealStatus(doc.id, 'rejected'),
                         ),
                         IconButton(
                           icon: const Icon(Icons.check_circle, color: Colors.green, size: 32),
                           onPressed: () => db.updateGuestMealStatus(doc.id, 'approved'),
                         ),
                       ],
                     ),
                   );
                 },
               ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAttendanceCard(DatabaseService db, String date, String type, Color color) {
    return StreamBuilder<List<Attendance>>(
      stream: db.getAttendanceStream(date),
      builder: (context, snapshot) {
        int count = 0;
        if (snapshot.hasData) {
          count = snapshot.data!
              .where((a) => type == 'Lunch' ? a.lunch : a.dinner)
              .length;
        }
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(color: const Color(0xFF6C63FF).withOpacity(0.15), blurRadius: 20, offset: const Offset(0, 10))
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
               Icon(type == 'Lunch' ? Icons.wb_sunny : Icons.nights_stay, color: color, size: 28),
               const SizedBox(height: 12),
               Text(
                 count.toString(), 
                 style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, height: 1.0)
               ),
               Text(type, style: TextStyle(color: Colors.grey[600], fontWeight: FontWeight.w500)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildGuestCard(DatabaseService db) {
     return StreamBuilder<Map<String, dynamic>>(
       stream: db.getTodayGuestStats(),
       builder: (context, snapshot) {
          int count = 0;
          double revenue = 0;
          if (snapshot.hasData) {
             count = snapshot.data!['count'];
             revenue = snapshot.data!['revenue'].toDouble();
          }
          return Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFF11998e), Color(0xFF38ef7d)]),
              borderRadius: BorderRadius.circular(24),
              boxShadow: const [
                BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, 5))
              ]
            ),
            child: Row(
               mainAxisAlignment: MainAxisAlignment.spaceBetween,
               children: [
                 Column(
                   crossAxisAlignment: CrossAxisAlignment.start,
                   children: [
                     const Text('Today\'s Guests', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                     const SizedBox(height: 4),
                     Text('₹${revenue.toInt()}', style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                   ],
                 ),
                 Container(
                   padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                   decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(16)),
                   child: Text('$count Plates', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                 )
               ],
            ),
          );
       }
     );
  }

  Widget _buildRevenueCard(DatabaseService db, String currentMonth) {
    return StreamBuilder<List<Student>>(
       stream: db.studentsStream,
       builder: (context, sSnap) {
          if(!sSnap.hasData) return const SizedBox.shrink();
          double expected = sSnap.data!.fold(0, (sum, s) => sum + s.monthlyFee);
          
          return StreamBuilder<List<Payment>>(
             stream: db.getPaymentsStream(currentMonth),
             builder: (context, pSnap) {
                double collected = 0;
                if(pSnap.hasData) collected = pSnap.data!.fold(0, (sum, p) => sum + p.paidAmount);
                double pending = expected - collected;
                if(pending < 0) pending = 0;

                return Card(
                   elevation: 4,
                   shadowColor: Colors.black12,
                   shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                   child: Padding(
                     padding: const EdgeInsets.all(20),
                     child: Row(
                       children: [
                          // 3D-ish Pie Chart
                          SizedBox(
                            height: 100,
                            width: 100,
                            child: PieChart(
                               PieChartData(
                                  sectionsSpace: 4,
                                  centerSpaceRadius: 30,
                                  sections: [
                                     PieChartSectionData(
                                        value: collected > 0 ? collected : 1, // Fallback to avoid empty chart
                                        color: Colors.green,
                                        radius: 18,
                                        showTitle: false,
                                     ),
                                     PieChartSectionData(
                                        value: pending > 0 ? pending : 0.1, 
                                        color: Colors.orange,
                                        radius: 15,
                                        showTitle: false,
                                     ),
                                  ]
                               )
                            ),
                          ),
                          const SizedBox(width: 24),
                          Expanded(
                           child: Column(
                             children: [
                               Row(
                                 mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                 children: [
                                   _RevItem('Expected', expected, Colors.blue),
                                   _RevItem('Collected', collected, Colors.green),
                                 ],
                               ),
                               const SizedBox(height: 12),
                               Align(
                                 alignment: Alignment.centerRight,
                                 child: _RevItem('Pending', pending, Colors.orange),
                               )
                             ],
                           ) 
                          )
                       ],
                     ),
                   ),
                );
             },
          );
       },
    );
  }
  
  Widget _buildMenuCard(DatabaseService db, String today) {
    return StreamBuilder<MessMenu?>(
      stream: db.getMenuStream(today),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Text('Loading menu...');
        final menu = snapshot.data;
        if (menu == null) return const Text('No menu added for today.');
        return Card(
          elevation: 0,
          color: Colors.white,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(color: Colors.grey.shade200)
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                if (menu.isNonVegDay)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.red.shade200),
                          ),
                          child: Row(
                            children: const [
                              Icon(Icons.restaurant, color: Colors.red, size: 14),
                              SizedBox(width: 6),
                              Text('NON-VEG DAY', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 10)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                Row(
                  children: [
                    Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.orange.shade50, shape: BoxShape.circle), child: const Icon(Icons.wb_sunny, color: Colors.orange, size: 20)),
                    const SizedBox(width: 12),
                    Expanded(child: Text(menu.lunchMenu, style: const TextStyle(fontWeight: FontWeight.w500))),
                  ],
                ),
                const Divider(height: 24),
                Row(
                  children: [
                    Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.indigo.shade50, shape: BoxShape.circle), child: const Icon(Icons.nights_stay, color: Colors.indigo, size: 20)),
                    const SizedBox(width: 12),
                    Expanded(child: Text(menu.dinnerMenu, style: const TextStyle(fontWeight: FontWeight.w500))),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
  void _showExpiredPlansSheet(BuildContext context, DatabaseService db) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return StreamBuilder<List<Student>>(
          stream: db.getExpiredStudentsStream(),
          builder: (context, snapshot) {
            final students = snapshot.data ?? [];
            
            return Container(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                   const Text(
                     'Plan Expired Members ⚠️',
                     style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                   ),
                   const SizedBox(height: 16),
                   if (!snapshot.hasData)
                      const Expanded(child: Center(child: CircularProgressIndicator()))
                   else if (students.isEmpty)
                      const Expanded(
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.check_circle_outline, size: 60, color: Colors.green),
                              SizedBox(height: 16),
                              Text("All plans are active!", style: TextStyle(color: Colors.grey)),
                            ],
                          ),
                        )
                      )
                   else
                     Expanded(
                       child: ListView.separated(
                         itemCount: students.length,
                         separatorBuilder: (_, __) => const Divider(),
                         itemBuilder: (context, index) {
                           final student = students[index];
                           return ListTile(
                             leading: CircleAvatar(
                               backgroundImage: student.photoUrl.isNotEmpty ? NetworkImage(student.photoUrl) : null,
                               child: student.photoUrl.isEmpty ? const Icon(Icons.person) : null,
                             ),
                             title: Text(student.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                             subtitle: Text('Plates: ${student.plateCount} • ${student.mobileNumber}'),
                             trailing: ElevatedButton(
                               onPressed: () {
                                 Navigator.pop(context); // close sheet
                                 _showRenewalDialog(context, student, db);
                               },
                               style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white),
                               child: const Text('Renew'),
                             ),
                           );
                         },
                       ),
                     ),
                ],
              ),
            );
          }
        );
      },
    );
  }

  void _showRenewalDialog(BuildContext context, Student student, DatabaseService db) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Renew for ${student.name}?'),
        content: const Text(
          'Reset monthly cycle? Any extra plates consumed will be carried over.'
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              await db.renewMembership(student.id);
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Confirm Renewal'),
          )
        ],
      ),
    );
  }

}

class _RevItem extends StatelessWidget {
  final String label;
  final double amount;
  final Color color;
  const _RevItem(this.label, this.amount, this.color);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          '₹${(amount / 1000).toStringAsFixed(1)}k',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color),
        ),
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
      ],
    );
  }
}

class _CoolAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _CoolAction(this.icon, this.label, this.color, this.onTap);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
             BoxShadow(color: Colors.grey.withOpacity(0.08), blurRadius: 12, offset: const Offset(0, 6))
          ]
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [color, color.withOpacity(0.7)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(color: color.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 3))
                ]
              ),
              child: Icon(icon, color: Colors.white, size: 26),
            ),
            const SizedBox(height: 10),
            Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
          ],
        ),
      ),
    );
  }
}
