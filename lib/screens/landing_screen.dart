import 'package:flutter/material.dart';
import 'auth/login_screen.dart';
import 'dashboard_screen.dart';
import 'package:flutter_animate/flutter_animate.dart';

class LandingScreen extends StatelessWidget {
  const LandingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Container(
        width: double.infinity,
        height: double.infinity,
        color: Colors.white,
        child: SafeArea(
           child: Padding(
             padding: const EdgeInsets.symmetric(horizontal: 32.0),
             child: Column(
               mainAxisAlignment: MainAxisAlignment.center,
               children: [
                 const Spacer(),
                 // Logo without background circle
                 Image.asset('assets/icon.png', width: 150, height: 150)
                   .animate().fade(duration: 600.ms).scale(delay: 200.ms),
                 const SizedBox(height: 40),
                 
                 const Text(
                   'TiffinMate',
                   style: TextStyle(
                     fontSize: 40,
                     fontWeight: FontWeight.bold,
                     color: Color(0xFF6C63FF),
                     letterSpacing: 1.2,
                   ),
                 ).animate().fade(delay: 300.ms, duration: 800.ms).slideY(begin: 0.3, end: 0),
                 const SizedBox(height: 16),
                 Text(
                   'Smart Management for\nTiffin & Mess Service Owners',
                   textAlign: TextAlign.center,
                   style: TextStyle(
                     fontSize: 18,
                     color: Colors.grey.shade600,
                     height: 1.5,
                   ),
                 ).animate().fade(delay: 500.ms, duration: 800.ms),
                 
                 const SizedBox(height: 80),
                 const CircularProgressIndicator(
                   color: Color(0xFF6C63FF),
                 ).animate().fade(delay: 1000.ms),
                 const Spacer(),
                 const SizedBox(height: 48),
               ],
             ),
           ),
        ),
      ),
    );
  }
}
