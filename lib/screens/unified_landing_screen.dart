import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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
          child: Stack(
            children: [
              // Main Content
              Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: FutureBuilder<Owner?>(
                    future: DatabaseService(uid: ownerId).getOwner(ownerId),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const SizedBox(
                          height: 300, 
                          child: Center(child: CircularProgressIndicator(color: Colors.white))
                        );
                      }
    
                      final messName = snapshot.data?.messName.isNotEmpty == true 
                          ? snapshot.data!.messName 
                          : 'Tiffin Mess';
                      
                      return Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 3),
                              boxShadow: const [BoxShadow(blurRadius: 10, color: Colors.black26)]
                            ),
                            child: CircleAvatar(
                              radius: 50,
                              backgroundColor: Colors.white,
                              backgroundImage: const AssetImage('assets/icon.png'),
                              child: Container(),
                            ),
                          ),
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

              // Mess Rules Button (Top Right)
              Positioned(
                top: 40, 
                right: 20,
                child: IconButton(
                  onPressed: () async {
                    // Fetch owner data again for rules (lightweight call)
                    final ownerDoc = await FirebaseFirestore.instance.collection('owners').doc(ownerId).get();
                    final owner = Owner.fromDocument(ownerDoc);
                    if (!context.mounted) return;
                    
                    showDialog(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Mess Rules'),
                            IconButton(
                              onPressed: () => Navigator.pop(ctx), 
                              icon: const Icon(Icons.close),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                          ],
                        ),
                        content: SingleChildScrollView(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: (owner.rules.isNotEmpty ? owner.rules : 'No specific rules added by owner yet.')
                                .split('\n')
                                .where((rule) => rule.trim().isNotEmpty)
                                .map((rule) => Padding(
                                      padding: const EdgeInsets.only(bottom: 8.0),
                                      child: Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Text('• ', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                                          Expanded(
                                            child: Text(
                                              rule.trim(),
                                              style: const TextStyle(fontSize: 16),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ))
                                .toList(),
                          ),
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.info_outline, size: 28, color: Colors.white),
                  tooltip: 'View Mess Rules',
                ),
              ),
            ],
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
                      style: TextStyle(
                        fontSize: 20, 
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).textTheme.bodyLarge?.color
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 14, 
                        color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.7)
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios, color: Theme.of(context).iconTheme.color?.withOpacity(0.3), size: 16),
            ],
          ),
        ),
      ),
    );
  }
}
