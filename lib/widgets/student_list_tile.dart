import 'package:flutter/material.dart';
import '../models/student_model.dart';
import '../services/database_service.dart';
import 'package:url_launcher/url_launcher.dart';
import '../screens/students/student_history_screen.dart';
import 'package:qr_flutter/qr_flutter.dart';

class StudentListTile extends StatelessWidget {
  final Student student;
  final VoidCallback onTap;
  final DatabaseService db;

  const StudentListTile({
    super.key,
    required this.student,
    required this.onTap,
    required this.db,
  });

  Future<void> _makeCall(String number) async {
    final Uri launchUri = Uri(
      scheme: 'tel',
      path: number,
    );
    if (!await launchUrl(launchUri)) {
      debugPrint('Could not launch call to $number');
    }
  }

  Future<void> _openWhatsApp(String number) async {
    // Basic cleaning of number if needed, assuming user enters clean number or pure digits
    var cleanNumber = number.replaceAll(RegExp(r'\D'), '');
    // If number doesn't have country code (e.g. 10 digits), assume +91 (India)
    if (cleanNumber.length == 10) {
      cleanNumber = '91$cleanNumber';
    }
    
    final Uri launchUri = Uri.parse('https://wa.me/$cleanNumber');
    if (!await launchUrl(launchUri, mode: LaunchMode.externalApplication)) {
      debugPrint('Could not launch WhatsApp to $number');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ListTile(
        contentPadding: const EdgeInsets.all(12),
        leading: CircleAvatar(
          radius: 25,
          backgroundColor: Colors.orange.shade100,
          backgroundImage: student.photoUrl.isNotEmpty
              ? NetworkImage(student.photoUrl)
              : null,
          child: student.photoUrl.isEmpty
              ? Text(
                  student.name[0].toUpperCase(),
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, color: Colors.deepOrange),
                )
              : null,
        ),
        title: Text(
          student.name,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(student.mobileNumber, style: const TextStyle(color: Colors.black87)),
            Text(
              'Fee: ₹${student.monthlyFee.toInt()}',
              style: const TextStyle(color: Colors.grey),
            ),
            Text(
              'Used: ${student.plateCount} / 28',
              style: TextStyle(
                color: student.plateCount >= 28 ? Colors.red : Colors.blue,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.history, color: Colors.blue),
              tooltip: 'View History',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => StudentHistoryScreen(student: student)),
                );
              },
            ),
            if (student.mobileNumber.isNotEmpty) ...[
              IconButton(
                icon: const Icon(Icons.phone, color: Colors.green),
                onPressed: () => _makeCall(student.mobileNumber),
              ),
              IconButton(
                icon: const Icon(Icons.message, color: Colors.teal), // WhatsApp colorish
                onPressed: () => _openWhatsApp(student.mobileNumber),
              ),
            ],
            const Icon(Icons.arrow_forward_ios, size: 16),
          ],
        ),
        onTap: onTap,
      ),
    );
  }

  void _showQrDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(student.name),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Member Identification QR', style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: QrImageView(
                data: student.id,
                version: QrVersions.auto,
                size: 200.0,
              ),
            ),
            const SizedBox(height: 16),
            Text('ID: ${student.id}', style: const TextStyle(fontSize: 10, fontFamily: 'monospace')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('CLOSE')),
        ],
      ),
    );
  }
}
