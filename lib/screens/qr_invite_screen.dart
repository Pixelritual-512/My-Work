import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:flutter/foundation.dart';
import '../../services/auth_service.dart';

class QrInviteScreen extends StatefulWidget {
  const QrInviteScreen({super.key});

  @override
  State<QrInviteScreen> createState() => _QrInviteScreenState();
}

class _QrInviteScreenState extends State<QrInviteScreen> {
  
  @override
  Widget build(BuildContext context) {
    final user = Provider.of<AuthService>(context, listen: false).currentUser;
    if (user == null) return const SizedBox.shrink();

    final String baseUrl = kIsWeb ? Uri.base.origin : 'https://tiffin-mess-app-2e443.web.app'; 
    
    // Single Unified Link
    final String scanLink = '$baseUrl/#/scan?ownerId=${user.uid}';

    return Scaffold(
      appBar: AppBar(title: const Text('Mess QR Code')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'Scan to Connect',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Members can scan this single code to Register OR Mark Attendance.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey, fontSize: 16),
              ),
              const SizedBox(height: 40),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 20, offset: const Offset(0, 10))
                  ]
                ),
                child: QrImageView(
                  data: scanLink,
                  version: QrVersions.auto,
                  size: 280.0,
                  backgroundColor: Colors.white,
                  eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: Color(0xFF6C63FF)),
                  dataModuleStyle: const QrDataModuleStyle(dataModuleShape: QrDataModuleShape.square, color: Colors.black87),
                ),
              ),
              const SizedBox(height: 40),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300)
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.link, size: 20, color: Colors.grey),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        scanLink,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                icon: const Icon(Icons.copy),
                label: const Text('Copy Link'),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: scanLink));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Link copied to clipboard!')),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
