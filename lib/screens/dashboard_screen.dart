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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final headerColor = isDark ? Colors.white : Colors.black87;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
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
                  child: Stack(
                    children: [
                      // Decorative background circles for depth
                      Positioned(
                        top: -100,
                        right: -50,
                        child: Container(
                          width: 300,
                          height: 300,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withOpacity(0.05),
                          ),
                        ),
                      ),
                      Positioned(
                        top: 50,
                        left: -50,
                        child: Container(
                          width: 150,
                          height: 150,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withOpacity(0.08),
                          ),
                        ),
                      ),
                      
                      // Main Header Content
                      Padding(
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
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      name,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 28,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
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
                      Expanded(child: _buildAttendanceCard(databaseService, today, 'Lunch', Colors.orange, isDark)),
                      const SizedBox(width: 16),
                      Expanded(child: _buildAttendanceCard(databaseService, today, 'Dinner', Colors.indigo, isDark)),
                    ],
                  ),
                  ),

              ],
            ),
            
            const SizedBox(height: 80), // Spacer for overlapping cards

            // 3. Main Content with smooth fade-in
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Pending Student Approvals
                  _buildPendingStudentRequests(databaseService, isDark)
                      .animate().fadeIn(duration: 400.ms).slideY(begin: 0.2, end: 0, curve: Curves.easeOut),
                  const SizedBox(height: 16),

                  // Live Guest Requests
                  _buildPendingGuestRequests(databaseService, isDark)
                      .animate().fadeIn(duration: 400.ms, delay: 100.ms).slideY(begin: 0.2, end: 0, curve: Curves.easeOut),
                  const SizedBox(height: 16),

                  // Guest Stats
                  _buildGuestCard(databaseService)
                      .animate().fadeIn(duration: 400.ms, delay: 200.ms).slideY(begin: 0.2, end: 0, curve: Curves.easeOut),
                  const SizedBox(height: 16),

                  const SizedBox(height: 24),
                  Text(
                    'Quick Actions',
                    style: TextStyle(
                      fontSize: 20, 
                      fontWeight: FontWeight.bold,
                      color: headerColor
                    ),
                  ).animate().fadeIn(delay: 300.ms),
                  const SizedBox(height: 16),
                  
                  GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 3, // 3 columns looks cooler
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 0.9,
                    children: [
                      // Distinct, vibrant colors for easy recognition
                      _CoolAction(Icons.how_to_reg, 'Attendance', Colors.blueAccent, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AttendanceScreen())), isDark)
                          .animate().scale(delay: 400.ms, duration: 300.ms, curve: Curves.elasticOut),
                      _CoolAction(Icons.group, 'Members', Colors.orange, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const StudentsListScreen())), isDark)
                          .animate().scale(delay: 450.ms, duration: 300.ms, curve: Curves.elasticOut),
                      _CoolAction(Icons.restaurant_menu, 'Menu', Colors.pinkAccent, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MenuScreen())), isDark)
                          .animate().scale(delay: 500.ms, duration: 300.ms, curve: Curves.elasticOut),
                      _CoolAction(Icons.account_balance_wallet, 'Payments', Colors.deepPurple, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PaymentsScreen())), isDark)
                          .animate().scale(delay: 550.ms, duration: 300.ms, curve: Curves.elasticOut),
                      _CoolAction(Icons.analytics, 'Reports', Colors.teal, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ReportsScreen())), isDark)
                          .animate().scale(delay: 600.ms, duration: 300.ms, curve: Curves.elasticOut),
                    ],
                  ),

                  const SizedBox(height: 24),
                  Text(
                    'Menu Highlights',
                    style: TextStyle(
                      fontSize: 20, 
                      fontWeight: FontWeight.bold,
                      color: headerColor
                    ),
                  ).animate().fadeIn(delay: 650.ms),
                  const SizedBox(height: 16),
                  _buildMenuCard(databaseService, today, isDark)
                      .animate().fadeIn(duration: 500.ms, delay: 700.ms).slideX(begin: 0.1, end: 0, curve: Curves.easeOut),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPendingStudentRequests(DatabaseService db, bool isDark) {
    return StreamBuilder<List<Student>>(
      stream: db.getPendingStudentsStream(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Container(
            padding: const EdgeInsets.all(16),
            color: Colors.red.shade100,
            child: Text('Error: ${snapshot.error}', style: const TextStyle(color: Colors.red)),
          );
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const SizedBox.shrink();
        }

        final students = snapshot.data!;

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.blue.shade100.withOpacity(0.5)),
            boxShadow: [
              BoxShadow(
                color: Colors.blue.withOpacity(isDark ? 0.05 : 0.1),
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
                   const Icon(Icons.person_add, color: Colors.blue),
                   const SizedBox(width: 8),
                   Text(
                     'Member Approvals', 
                     style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isDark ? Colors.white : Colors.black87)
                   ),
                 ],
               ),
               const SizedBox(height: 12),
               ListView.separated(
                 shrinkWrap: true,
                 physics: const NeverScrollableScrollPhysics(),
                 itemCount: students.length,
                 separatorBuilder: (_, __) => const Divider(),
                 itemBuilder: (context, index) {
                   final student = students[index];
                   final hasPayment = student.pendingPayment > 0;

                   return ListTile(
                     contentPadding: EdgeInsets.zero,
                     leading: CircleAvatar(
                       backgroundColor: Colors.blue.shade50,
                       child: const Icon(Icons.person, color: Colors.blue, size: 20),
                     ),
                     title: Text(
                       student.name,
                       style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87),
                     ),
                     subtitle: Column(
                       crossAxisAlignment: CrossAxisAlignment.start,
                       children: [
                         Text(student.mobileNumber, style: TextStyle(color: Theme.of(context).hintColor)),
                         if (hasPayment)
                           Container(
                             margin: const EdgeInsets.only(top: 4),
                             padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                             decoration: BoxDecoration(
                               color: Colors.green.withOpacity(0.1),
                               borderRadius: BorderRadius.circular(4),
                             ),
                             child: Text(
                               'Paid: ₹${student.pendingPayment.toInt()} (${student.pendingPaymentMode})',
                               style: const TextStyle(fontSize: 12, color: Colors.green, fontWeight: FontWeight.bold),
                             ),
                           ),
                       ],
                     ),
                     trailing: Row(
                       mainAxisSize: MainAxisSize.min,
                       children: [
                         IconButton(
                           icon: const Icon(Icons.close, color: Colors.red),
                           onPressed: () => _confirmAction(context, 'Reject', student.name, () => db.rejectStudent(student.id)),
                         ),
                         IconButton(
                           icon: const Icon(Icons.check_circle, color: Colors.green, size: 32),
                           onPressed: () => _confirmAction(context, 'Approve', student.name, () => db.approveStudent(student)),
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

  void _confirmAction(BuildContext context, String action, String name, VoidCallback onConfirm) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('$action Request?'),
        content: Text('Are you sure you want to $action $name?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              onConfirm();
              Navigator.pop(ctx);
            },
            child: Text(action),
          ),
        ],
      ),
    );
  }

  Widget _buildPendingGuestRequests(DatabaseService db, bool isDark) {
    return StreamBuilder<QuerySnapshot>(
      stream: db.getPendingGuestMealsStream(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const SizedBox.shrink();
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
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.orange.shade100.withOpacity(0.5)),
            boxShadow: [
              BoxShadow(
                color: Colors.orange.withOpacity(isDark ? 0.05 : 0.1),
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
                   Text(
                     'Live Guest Requests', 
                     style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isDark ? Colors.white : Colors.black87)
                   ),
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
                   // Fix: Read 'amount' instead of 'price', and 'type' instead of 'variant'
                   final price = (data['amount'] ?? 0).toDouble();
                   final variant = data['type'] ?? 'Veg';
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
                       style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87),
                     ),
                     subtitle: Text(
                       '₹${price.toInt()} • $payment',
                       style: TextStyle(
                         color: isOnline ? Colors.purple : (isDark ? Colors.grey[400] : Colors.grey[600]),
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

  Widget _buildAttendanceCard(DatabaseService db, String date, String type, Color color, bool isDark) {
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
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF6C63FF).withOpacity(isDark ? 0.05 : 0.15), 
                blurRadius: 20, 
                offset: const Offset(0, 10)
              )
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
               Icon(type == 'Lunch' ? Icons.wb_sunny : Icons.nights_stay, color: color, size: 28),
               const SizedBox(height: 12),
               Text(
                 count.toString(), 
                 style: TextStyle(
                   fontSize: 32, 
                   fontWeight: FontWeight.bold, 
                   height: 1.0, 
                   color: isDark ? Colors.white : Colors.black87
                 )
               ),
               Text(
                 type, 
                 style: TextStyle(
                   color: isDark ? Colors.grey[400] : Colors.grey[600], 
                   fontWeight: FontWeight.w500
                 )
               ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildGuestCard(DatabaseService db) {
     return StreamBuilder<Map<String, dynamic>>(
       stream: db.getGuestAnalytics(),
       builder: (context, snapshot) {
          int count = 0;
          double todayRevenue = 0;
          double totalRevenue = 0;
          
          if (snapshot.hasData) {
             count = snapshot.data!['todayCount'];
             todayRevenue = snapshot.data!['todayRevenue'];
             totalRevenue = snapshot.data!['totalRevenue'];
          }
          
          return Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              // Deep Orange Gradient: Warm, vibrant, and maintains excellent readability
              gradient: LinearGradient(
                colors: [Colors.deepOrange.shade400, Colors.deepOrange.shade700],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              boxShadow: const [
                BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, 5))
              ]
            ),
            child: Column(
              children: [
                Row(
                   mainAxisAlignment: MainAxisAlignment.spaceBetween,
                   children: [
                     Column(
                       crossAxisAlignment: CrossAxisAlignment.start,
                       children: [
                         const Text('Today\'s Guests', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                         const SizedBox(height: 4),
                         Text('₹${todayRevenue.toInt()}', style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
                       ],
                     ),
                     Container(
                       padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                       decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(16)),
                       child: Text('$count Plates', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                     )
                   ],
                ),
                const SizedBox(height: 16),
                Container(height: 1, color: Colors.white24),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Icon(Icons.account_balance_wallet, color: Colors.white70, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      'Total Guest Revenue: ₹${totalRevenue.toInt()}',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ],
                ),
              ],
            ),
          );
       }
     );
  }

  
  Widget _buildMenuCard(DatabaseService db, String today, bool isDark) {
    return StreamBuilder<MessMenu?>(
      stream: db.getMenuStream(today),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return Text('Loading menu...', style: TextStyle(color: isDark ? Colors.grey : Colors.black54));
        final menu = snapshot.data;
        if (menu == null) return Text('No menu added for today.', style: TextStyle(color: isDark ? Colors.grey : Colors.black54));
        return Card(
          elevation: 0,
          color: Theme.of(context).cardColor,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(color: Theme.of(context).dividerColor.withOpacity(0.1))
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                if (menu.isNonVegDay)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(color: Colors.red.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.warning, color: Colors.red, size: 16),
                        SizedBox(width: 8),
                        Text('Non-Veg Day', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                const SizedBox(height: 16),
                _MenuItem('Lunch', menu.lunchMenu, Icons.wb_sunny, Colors.blue, isDark),
                const Divider(height: 30),
                _MenuItem('Dinner', menu.dinnerMenu, Icons.nights_stay, Colors.indigo, isDark),
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
              decoration: BoxDecoration(
                color: Theme.of(context).scaffoldBackgroundColor,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                   Text(
                     'Plan Expired Members ⚠️',
                     style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Theme.of(context).textTheme.bodyLarge?.color),
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
                             subtitle: Text('Plates: ${student.plateCount} • ${student.mobileNumber}', style: TextStyle(color: Theme.of(context).hintColor)),
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


class _CoolAction extends StatefulWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  final bool isDark;

  const _CoolAction(this.icon, this.label, this.color, this.onTap, this.isDark);

  @override
  State<_CoolAction> createState() => _CoolActionState();
}

class _CoolActionState extends State<_CoolAction> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _isPressed ? 0.95 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: Container(
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
               BoxShadow(
                 color: Colors.grey.withOpacity(widget.isDark ? 0.05 : 0.08), 
                 blurRadius: 12, 
                 offset: const Offset(0, 6)
               )
            ],
            // Gradient border for premium feel
            border: Border.all(color: widget.color.withOpacity(0.1), width: 1),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: widget.color.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(widget.icon, color: widget.color, size: 28),
              ),
              const SizedBox(height: 12),
              Text(
                widget.label, 
                style: TextStyle(
                  fontWeight: FontWeight.w600, 
                  fontSize: 15,
                  color: widget.isDark ? Colors.white : Colors.black87
                )
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MenuItem extends StatelessWidget {
  final String label;
  final String items;
  final IconData icon;
  final Color color;
  final bool isDark;

  const _MenuItem(this.label, this.items, this.icon, this.color, this.isDark);

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(16)
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label, 
                style: TextStyle(
                  color: isDark ? Colors.grey[400] : Colors.grey[600], 
                  fontSize: 14, 
                  fontWeight: FontWeight.w600
                )
              ),
              const SizedBox(height: 4),
              Text(
                items.isEmpty ? 'Not set yet' : items, 
                style: TextStyle(
                  fontSize: 16, 
                  fontWeight: FontWeight.w500,
                  color: isDark ? Colors.white : Colors.black87
                )
              ),
            ],
          ),
        ),
      ],
    );
  }
}
