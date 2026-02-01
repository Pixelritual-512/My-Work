import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/database_service.dart';
import '../models/owner_model.dart';
import 'student_registration_screen.dart';
import 'self_service_meal_screen.dart';

class UnifiedLandingScreen extends StatelessWidget {
  final String ownerId;
  const UnifiedLandingScreen({super.key, required this.ownerId});

  @override
  Widget build(BuildContext context) {
    // Prevent back navigation to login
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (didPop) return;
        SystemNavigator.pop();
      },
      child: Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF6C63FF), Color(0xFF4B39EF)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: FutureBuilder<Owner?>(
                future: DatabaseService(uid: ownerId).getOwner(ownerId),
                builder: (context, snapshot) {
                  final messName = snapshot.data?.messName ?? 'Tiffin Mess';
                  
                  return Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.storefront, size: 80, color: Colors.white),
                      const SizedBox(height: 20),
                      Text(
                        'Welcome to\n$messName',
                        style: const TextStyle(
                          fontSize: 28, 
                          fontWeight: FontWeight.bold, 
                          color: Colors.white,
                          height: 1.2
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'Please select an option to proceed',
                        style: TextStyle(color: Colors.white70, fontSize: 16),
                      ),
                      const SizedBox(height: 50),
                      
                      _buildOptionCard(
                        context,
                        title: 'Join Mess',
                        subtitle: 'New Member Registration',
                        icon: Icons.person_add,
                        color: Colors.orange,
                        onTap: () {
                          Navigator.push(
                            context, 
                            MaterialPageRoute(builder: (_) => StudentRegistrationScreen(ownerId: ownerId))
                          );
                        },
                      ),
                      
                      const SizedBox(height: 20),
                      
                      _buildOptionCard(
                        context,
                        title: 'Take Meal',
                        subtitle: 'Mark Attendance / Guest Meal',
                        icon: Icons.restaurant,
                        color: Colors.green,
                        onTap: () {
                          Navigator.push(
                            context, 
                            MaterialPageRoute(builder: (_) => SelfServiceMealScreen(ownerId: ownerId))
                          );
                        },
                      ),
                    ],
                  );
                }
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOptionCard(BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 32),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 20, 
                        fontWeight: FontWeight.bold,
                        color: Colors.black87
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 14, 
                        color: Colors.grey[600]
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios, color: Colors.grey[400], size: 16),
            ],
          ),
        ),
      ),
    );
  }
}
