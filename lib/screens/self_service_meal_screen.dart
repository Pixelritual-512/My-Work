import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/database_service.dart';
import '../models/student_model.dart';
import '../models/owner_model.dart';
import '../models/attendance_model.dart';

class SelfServiceMealScreen extends StatefulWidget {
  final String ownerId;
  const SelfServiceMealScreen({super.key, required this.ownerId});

  @override
  State<SelfServiceMealScreen> createState() => _SelfServiceMealScreenState();
}

class _SelfServiceMealScreenState extends State<SelfServiceMealScreen> {
  final _mobileController = TextEditingController();
  Student? _identifiedStudent;
  bool _isChecking = false;
  String? _pendingRequestId;
  bool _showMemberSuccess = false;
  DateTime? _memberSuccessTime;
  String _memberMealType = 'Veg';

  @override
  void dispose() {
    _mobileController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final db = DatabaseService(uid: widget.ownerId);

    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (didPop) return;
        // Try to exit the app/pwa logic
        SystemNavigator.pop(); 
      },
      child: Scaffold(
        body: _showMemberSuccess 
          ? _buildSuccessView(_memberMealType, time: _memberSuccessTime)
          : StreamBuilder<DocumentSnapshot>(
          stream: _pendingRequestId != null 
            ? FirebaseFirestore.instance.collection('guest_meals').doc(_pendingRequestId).snapshots()
            : null,
          builder: (context, snapshot) {
            if (snapshot.hasData && snapshot.data!.exists) {
              final data = snapshot.data!.data() as Map<String, dynamic>;
              if (data['status'] == 'approved') {
                final type = data['type'] as String? ?? 'Veg';
                return _buildSuccessView(type, time: DateTime.now());
              } else if (data['status'] == 'pending') {
                return _buildWaitingView();
              }
            }
  
            return _identifiedStudent != null 
              ? _buildActionView(db) 
              : _buildIdentifyView(db);
          },
        ),
      ),
    );
  }

  Widget _buildIdentifyView(DatabaseService db) {
    return Container(
      padding: const EdgeInsets.all(30),
      decoration: const BoxDecoration(
        gradient: LinearGradient(colors: [Color(0xFF6C63FF), Color(0xFF4B39EF)])
      ),
      child: Center(
        child: Card(
          elevation: 10,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          child: Padding(
            padding: const EdgeInsets.all(30),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.qr_code_2, size: 60, color: Color(0xFF6C63FF)),
                const SizedBox(height: 20),
                const Text('Identify Yourself', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 24)),
                const SizedBox(height: 10),
                const Text('Enter your mobile number to start', style: TextStyle(color: Colors.grey)),
                const SizedBox(height: 30),
                TextField(
                  controller: _mobileController,
                  decoration: const InputDecoration(labelText: 'Mobile Number', prefixIcon: Icon(Icons.phone)),
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 30),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isChecking ? null : () => _identify(db),
                    child: _isChecking ? const CircularProgressIndicator() : const Text('Continue'),
                  ),
                ),
                const SizedBox(height: 20),
                TextButton(
                  onPressed: () => _startGuestFlow(db),
                  child: const Text('I am a Guest (One-time Meal)'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _identify(DatabaseService db) async {
    setState(() => _isChecking = true);
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('students')
          .where('ownerId', isEqualTo: widget.ownerId)
          .where('mobileNumber', isEqualTo: _mobileController.text)
          .get();

      if (snapshot.docs.isNotEmpty) {
        setState(() => _identifiedStudent = Student.fromDocument(snapshot.docs.first));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Member not found. Please register first.')));
      }
    } finally {
      setState(() => _isChecking = false);
    }
  }

  Future<void> _startGuestFlow(DatabaseService db) async {
    // Check menu first
    try {
       final now = DateTime.now();
       final dateStr = DateFormat('yyyy-MM-dd').format(now);
       final menu = await db.getMenuStream(dateStr).first;
       
       if (menu != null && menu.isNonVegDay) {
          _showMealSelectionDialog(db, isGuest: true);
       } else {
          // Default to Veg if not a Non-Veg day
          _handleGuestPayment(db, 'Veg');
       }
    } catch (e) {
       // Fallback
       _showMealSelectionDialog(db, isGuest: true);
    }
  }

  Widget _buildActionView(DatabaseService db) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircleAvatar(radius: 50, child: Text(_identifiedStudent!.name[0], style: const TextStyle(fontSize: 40))),
          const SizedBox(height: 20),
          Text('Welcome, ${_identifiedStudent!.name}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 24)),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.blue.shade200),
            ),
            child: Text(
              'Plates Used: ${_identifiedStudent!.plateCount}',
              style: TextStyle(color: Colors.blue.shade800, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 40),
          ElevatedButton(
            onPressed: () => _confirmAttendance(db),
            child: const Text('Mark Attendance (Take Meal)'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmAttendance(DatabaseService db) async {
    final now = DateTime.now();
    final dateStr = DateFormat('yyyy-MM-dd').format(now);
    
    // Check menu for today to determine Veg/Non-Veg
    String mealType = 'Veg';
    bool isNonVegDay = false;
    
    try {
      final menu = await db.getMenuStream(dateStr).first;
      if (menu != null && menu.isNonVegDay) {
        isNonVegDay = true;
      }
    } catch (_) {}

    // If it's a Non-Veg day, ask the MEMBER for their choice
    if (isNonVegDay) {
      final selected = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Select Your Meal'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: const Text('Veg Meal'),
                leading: const Icon(Icons.eco, color: Colors.green),
                onTap: () => Navigator.pop(ctx, 'Veg'),
              ),
              ListTile(
                title: const Text('Non-Veg Meal'),
                leading: const Icon(Icons.kebab_dining, color: Colors.red),
                onTap: () => Navigator.pop(ctx, 'Non-Veg'),
              ),
            ],
          ),
        ),
      );
      if (selected == null) return; // Cancelled
      mealType = selected;
    }

    final isLunch = now.hour < 16;
    final isDinner = now.hour >= 16;

    final attendance = Attendance(
      id: '',
      studentId: _identifiedStudent!.id,
      ownerId: widget.ownerId,
      date: dateStr,
      lunch: isLunch,
      dinner: isDinner,
      lunchVariant: isLunch ? mealType : null,
      dinnerVariant: isDinner ? mealType : null,
      createdAt: now,
    );
    
    try {
      await db.recordAttendance(_identifiedStudent!.id, attendance);
      setState(() {
        _memberMealType = mealType;
        _memberSuccessTime = DateTime.now();
        _showMemberSuccess = true;
      });
    } catch (e) {
      if (mounted) {
        String errorMsg = e.toString().replaceAll('Exception: ', '');
        showDialog(
          context: context,
          builder: (ctx) => Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.red.shade400, Colors.red.shade900],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline, color: Colors.white, size: 48),
                  const SizedBox(height: 16),
                  const Text(
                    'Attention',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    errorMsg,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 16, color: Colors.white),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white, 
                      foregroundColor: Colors.red.shade900,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12)
                    ),
                    onPressed: () => Navigator.pop(ctx), 
                    child: const Text('OK', style: TextStyle(fontWeight: FontWeight.bold))
                  ),
                ],
              ),
            ),
          ),
        );
      }
    }
  }

  void _showMealSelectionDialog(DatabaseService db, {required bool isGuest}) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Select Meal Type'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('Veg Meal'),
              leading: const Icon(Icons.eco, color: Colors.green),
              onTap: () => _handleGuestPayment(db, 'Veg'),
            ),
            ListTile(
              title: const Text('Non-Veg Meal'),
              leading: const Icon(Icons.kebab_dining, color: Colors.red),
              onTap: () => _handleGuestPayment(db, 'Non-Veg'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleGuestPayment(DatabaseService db, String type) async {
    Navigator.pop(context); // Close selection
    
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Select Payment'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ElevatedButton.icon(
              onPressed: () => _submitGuestRequest(db, type, 'Cash'),
              icon: const Icon(Icons.money),
              label: const Text('Pay Cash'),
            ),
            const SizedBox(height: 10),
            ElevatedButton.icon(
              onPressed: () => _payOnline(db, type),
              icon: const Icon(Icons.account_balance_wallet),
              label: const Text('Pay Online (UPI)'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _payOnline(DatabaseService db, String type) async {
    final ownerDoc = await FirebaseFirestore.instance.collection('owners').doc(widget.ownerId).get();
    final owner = Owner.fromDocument(ownerDoc);
    final upi = owner.upiId;
    final amount = type == 'Veg' ? owner.guestVegPrice : owner.guestNonVegPrice;

    if (upi.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Owner hasn\'t set up UPI yet.')));
      return;
    }

    final upiUrl = 'upi://pay?pa=$upi&pn=${owner.messName}&am=$amount&cu=INR';
    if (await canLaunchUrl(Uri.parse(upiUrl))) {
      await launchUrl(Uri.parse(upiUrl));
      _submitGuestRequest(db, type, 'Online');
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not launch payment app.')));
    }
  }

  Future<void> _submitGuestRequest(DatabaseService db, String type, String method) async {
    final ref = await db.recordGuestMeal({
      'type': type,
      'paymentMethod': method,
      'status': 'pending',
    });
    setState(() => _pendingRequestId = ref.id);
    if (mounted) Navigator.pop(context); // Close payment dialog
  }

  Widget _buildWaitingView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 30),
          const Icon(Icons.hourglass_empty, size: 80, color: Colors.orange),
          const SizedBox(height: 20),
          const Text('Waiting for Approval...', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 40),
            child: Text('The owner is reviewing your meal request. Stay on this screen.', textAlign: TextAlign.center),
          ),
        ],
      ),
    );
  }

  Widget _buildSuccessView(String type, {DateTime? time}) {
    final isVeg = type == 'Veg';
    final formatter = DateFormat('dd MMM yyyy, hh:mm a');
    final timeStr = time != null ? formatter.format(time) : '';

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isVeg 
            ? [Colors.green.shade400, Colors.green.shade800]
            : [Colors.red.shade400, Colors.red.shade800],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight
        )
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.check_circle_outline, size: 120, color: Colors.white),
            const SizedBox(height: 40),
            const Text('MEAL APPROVED!', style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white)),
            const SizedBox(height: 10),
            if (timeStr.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20)
                ),
                child: Text(
                  timeStr, 
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)
                ),
              ),
            const SizedBox(height: 20),
            const Text('Kindly proceed to take your plate.', style: TextStyle(fontSize: 18, color: Colors.white)),
            const SizedBox(height: 50),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white, 
                foregroundColor: isVeg ? Colors.green : Colors.red
              ),
              onPressed: () => setState(() {
                _pendingRequestId = null;
                _identifiedStudent = null;
                _showMemberSuccess = false;
                _mobileController.clear();
              }),
              child: const Text('Back to Home'),
            ),
          ],
        ),
      ),
    );
  }
}
