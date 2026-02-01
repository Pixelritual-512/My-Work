import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../services/auth_service.dart';
import '../services/database_service.dart';
import '../models/attendance_model.dart';
import '../models/payment_model.dart';
import '../models/menu_model.dart';
import '../models/student_model.dart';
import '../models/owner_model.dart';

import 'students/students_list_screen.dart';
import 'attendance_screen.dart';
import 'menu_screen.dart';
import 'payments_screen.dart';
import 'reports_screen.dart';
import 'qr_invite_screen.dart';
import 'settings_screen.dart';

class DashboardScreenInspired extends StatelessWidget {
  const DashboardScreenInspired({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context, listen: false);
    final user = authService.currentUser;
    final databaseService = DatabaseService(uid: user!.uid);
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());

    // Pastel Palette
    final bgColor = const Color(0xFFF9F3EE); // Warm Cream
    final cardColors = [
      const Color(0xFFC7CEEA), // Periwinkle
      const Color(0xFFFFDAC1), // Peach
      const Color(0xFFE2F0CB), // Green
      const Color(0xFFFF9AA2), // Pink
      const Color(0xFFB5EAD7), // Mint
      const Color(0xFFFFFFD8), // Yellow
    ];

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Header (Minimalist)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                   const Icon(Icons.grid_view_rounded, size: 28),
                   CircleAvatar(
                     backgroundColor: Colors.black,
                     radius: 20,
                     child: Text(user!.displayName?[0].toUpperCase() ?? "O", style: const TextStyle(color: Colors.white)),
                   )
                ],
              ),
              const SizedBox(height: 32),
              
              // 2. Welcome Text (Serif-like)
              FutureBuilder<Owner?>(
                future: databaseService.getOwner(user.uid),
                builder: (context, snapshot) {
                  final name = snapshot.data?.name ?? user.displayName ?? "Owner";
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Good Morning,',
                        style: TextStyle(
                          fontSize: 20,
                          color: Colors.grey[600],
                          fontFamily: 'Poppins', // Fallback to Poppins
                        ),
                      ),
                      Text(
                        name,
                        style: const TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.bold,
                          height: 1.1,
                          fontFamily: 'Poppins',
                        ),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 32),

              // 3. Main Stats Card (The "Daily Reflection" equivalent)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: const Color(0xFF2D2D2D), // Dark Card
                  borderRadius: BorderRadius.circular(32),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          "Today's Overview",
                          style: TextStyle(color: Colors.white70, fontSize: 16),
                        ),
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: const BoxDecoration(
                            color: Colors.white24,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.calendar_month, color: Colors.white, size: 16),
                        )
                      ],
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                         Expanded(child: _buildDarkStat(databaseService, today, 'Lunch', Icons.wb_sunny)),
                         Container(width: 1, height: 40, color: Colors.white24),
                         Expanded(child: _buildDarkStat(databaseService, today, 'Dinner', Icons.nights_stay)),
                      ],
                    )
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // 4. "Based on your needs" -> "Manage your Mess" Grid
              const Text(
                 "Manage your Mess",
                 style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 0.9, // Taller cards
                children: [
                   _PastelCard(
                     title: "Attendance",
                     subtitle: "Mark Now",
                     color: cardColors[0],
                     icon: Icons.checklist_rtl,
                     onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AttendanceScreen())),
                   ),
                   _PastelCard(
                     title: "Members",
                     subtitle: "View All",
                     color: cardColors[1],
                     icon: Icons.group,
                     onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const StudentsListScreen())),
                   ),
                   _PastelCard(
                     title: "Menu",
                     subtitle: "Update Food",
                     color: cardColors[2],
                     icon: Icons.restaurant_menu,
                     onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MenuScreen())),
                   ),
                   _PastelCard(
                     title: "Payments",
                     subtitle: "Collect Fees",
                     color: cardColors[3],
                     icon: Icons.account_balance_wallet,
                     onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PaymentsScreen())),
                   ),
                ],
              ),
              
              const SizedBox(height: 32),
              // Bottom Floating Action Button style row for secondary items?
              Row(
                 mainAxisAlignment: MainAxisAlignment.center,
                 children: [
                    FloatingActionButton.extended(
                      heroTag: 'invite',
                      onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const QrInviteScreen())),
                      backgroundColor: Colors.black,
                      foregroundColor: Colors.white,
                      label: const Text("Invite Member"),
                      icon: const Icon(Icons.qr_code),
                      elevation: 0,
                    ),
                    const SizedBox(width: 16),
                     FloatingActionButton(
                      heroTag: 'settings',
                      onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen())),
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black,
                       elevation: 0,
                       shape: const CircleBorder(),
                      child: const Icon(Icons.settings),
                    ),
                 ],
              ),
               const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDarkStat(DatabaseService db, String date, String type, IconData icon) {
    return StreamBuilder<List<Attendance>>(
      stream: db.getAttendanceStream(date),
      builder: (context, snapshot) {
        int count = 0;
        if (snapshot.hasData) {
          count = snapshot.data!
              .where((a) => type == 'Lunch' ? a.lunch : a.dinner)
              .length;
        }
        return Column(
          children: [
            Icon(icon, color: Colors.white70, size: 24),
            const SizedBox(height: 8),
            Text(
              count.toString(),
              style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold),
            ),
            Text(type, style: const TextStyle(color: Colors.white54)),
          ],
        );
      },
    );
  }
}

class _PastelCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final Color color;
  final IconData icon;
  final VoidCallback onTap;

  const _PastelCard({
    required this.title,
    required this.subtitle,
    required this.color,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(32),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: const BoxDecoration(
                color: Colors.black12,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: Colors.black87, size: 24),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.black54,
                  ),
                ),
              ],
            ),
            const Align(
              alignment: Alignment.bottomRight,
              child: Icon(Icons.arrow_outward, size: 20, color: Colors.black45),
            )
          ],
        ),
      ),
    );
  }
}
