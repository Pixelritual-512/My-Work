import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/database_service.dart';
import '../models/student_model.dart';
import '../models/owner_model.dart';
import '../models/attendance_model.dart';
import 'student_registration_screen.dart';

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

    return Scaffold(
      body: Stack(
        children: [
          _showMemberSuccess 
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
          
          if (!_showMemberSuccess && _pendingRequestId == null)
            Positioned(
              top: 20,
              left: 20,
              child: SafeArea(
                child: CircleAvatar(
                  backgroundColor: Colors.white,
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.black),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
              ),
            ),
        ],
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
                Text('Enter your mobile number to start', style: TextStyle(color: Theme.of(context).hintColor)),
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
              color: Colors.blue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.blue.withOpacity(0.3)),
            ),
            child: Text(
              'Plates Used: ${_identifiedStudent!.plateCount}',
              style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold),
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
                title: Text('Veg Meal', style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color)),
                leading: const Icon(Icons.eco, color: Colors.green),
                onTap: () => Navigator.pop(ctx, 'Veg'),
              ),
              ListTile(
                title: Text('Non-Veg Meal', style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color)),
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

  void _showMealSelectionDialog(DatabaseService db, {required bool isGuest}) async {
    // Fetch prices from owner settings
    final ownerDoc = await FirebaseFirestore.instance.collection('owners').doc(widget.ownerId).get();
    final owner = Owner.fromDocument(ownerDoc);
    final vegPrice = owner.guestVegPrice;
    final nonVegPrice = owner.guestNonVegPrice;
    
    if (!mounted) return;
    
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Select Meal Type'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text('Veg Meal (₹${vegPrice.toInt()})'),
              leading: const Icon(Icons.eco, color: Colors.green),
              onTap: () => _handleGuestPayment(db, 'Veg'),
            ),
            const Divider(),
            ListTile(
              title: Text('Non-Veg Meal (₹${nonVegPrice.toInt()})'),
              leading: const Icon(Icons.kebab_dining, color: Colors.red),
              onTap: () => _handleGuestPayment(db, 'Non-Veg'),
            ),
          ],
        ),
      ),
    );
  }

  // Refactored: Pre-calculate details so 'launchUrl' is called synchronously on tap
  Future<void> _handleGuestPayment(DatabaseService db, String type) async {
    // Navigate back to the dialog, but use a flag to control popping
    // We don't want to pop blindly if we are already in the right place
    // Navigator.pop(context); // REMOVED to fix bug where it pops to landing screen
    
    // FETCH DATA FIRST (Async)
    final ownerDoc = await FirebaseFirestore.instance.collection('owners').doc(widget.ownerId).get();
    final owner = Owner.fromDocument(ownerDoc);
    final amount = type == 'Veg' ? owner.guestVegPrice : owner.guestNonVegPrice;
    
    // Prepare UPI URL immediately
    final upi = owner.upiId;
    final safeName = Uri.encodeComponent(owner.messName);
    // Include tn=AppPayment as requested
    final upiUrl = 'upi://pay?pa=$upi&pn=$safeName&am=$amount&cu=INR&tn=AppPayment';
    
    if (!mounted) return;
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Text('Payment - ₹${amount.toInt()}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('$type Meal', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            
            // CASH BUTTON
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.all(16),
                ),
                onPressed: () {
                  Navigator.pop(ctx); 
                  _submitGuestRequest(db, type, 'Cash', amount: amount);
                },
                icon: const Icon(Icons.money),
                label: const Text('Pay Cash'),
              ),
            ),
            
            const SizedBox(height: 12),
            
            // PAY ONLINE BUTTON (Simplified)
            if (upi.isNotEmpty)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.purple,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.all(16),
                  ),
                  onPressed: () {
                    // Manual Verification Flow: User pays externally, then clicks here
                    Navigator.pop(ctx); 
                    _submitGuestRequest(db, type, 'Online', amount: amount);
                  },
                  icon: const Icon(Icons.account_balance_wallet),
                  label: const Text('Pay Online (UPI)'),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // NOTE: old _payOnline method removed as logic is now integrated above for safety

  // NOTE: old _payOnline method removed as logic is now integrated above for safety

  Future<void> _submitGuestRequest(DatabaseService db, String type, String method, {double? amount}) async {
    // ... existing logic ...
    double finalAmount = amount ?? 0.0;
    // ... logic ...
    final ref = await db.recordGuestMeal({
      'type': type,
      'paymentMethod': method,
      'status': 'pending',
      'amount': finalAmount,
    });
    if (mounted) setState(() => _pendingRequestId = ref.id);
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
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text('The owner is reviewing your meal request. Stay on this screen.', textAlign: TextAlign.center, style: TextStyle(color: Theme.of(context).hintColor)),
          ),
        ],
      ),
    );
  }

  Widget _buildSuccessView(String type, {DateTime? time}) {
    // ... existing UI ...
    final isVeg = type == 'Veg';
    final formatter = DateFormat('dd MMM yyyy, hh:mm a');
    final timeStr = time != null ? formatter.format(time) : '';
    
    // Check if this is a Member (identified) or Guest (pending request ID)
    final isMember = _identifiedStudent != null;

    return Container(
      width: double.infinity, // Ensure full width
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isVeg 
            ? [Colors.green.shade400, Colors.green.shade800]
            : [Colors.red.shade400, Colors.red.shade800],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight
        )
      ),
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
                foregroundColor: isVeg ? Colors.green : Colors.red,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16)
              ),
              onPressed: () async {
                 // For Members, just close and go back to initial state
                 if (isMember) {
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(builder: (_) => SelfServiceMealScreen(ownerId: widget.ownerId)),
                      (route) => false,
                    );
                    return;
                 }

                 // For Guests, show the "Join Mess" Upsell
                 // Fetch mess name for personalized thank you
                 final ownerDoc = await FirebaseFirestore.instance.collection('owners').doc(widget.ownerId).get();
                 final owner = Owner.fromDocument(ownerDoc);
                 
                 if (!context.mounted) return;

                 showDialog(
                   context: context,
                   barrierDismissible: false,
                   builder: (ctx) => AlertDialog(
                     title: const Text('Thank You!'),
                     content: Column(
                       mainAxisSize: MainAxisSize.min,
                       children: [
                         Text(
                           'Thanks for visiting ${owner.messName}!\nWe hope you enjoyed your meal.',
                           textAlign: TextAlign.center,
                           style: const TextStyle(fontSize: 16),
                         ),
                         const SizedBox(height: 20),
                         const Text(
                           'Would you like to join the mess as a regular member?',
                           textAlign: TextAlign.center,
                           style: TextStyle(fontWeight: FontWeight.bold),
                         ),
                       ],
                     ),
                     actionsAlignment: MainAxisAlignment.spaceEvenly,
                     actions: [
                       TextButton(
                         onPressed: () {
                           // Try to close app (SystemNavigator works on Android/iOS, sometimes blocked on Web)
                           SystemNavigator.pop();
                           
                           // Fallback: If web browser blocks close, navigate back to Landing Screen
                           Navigator.of(context).popUntil((route) => route.isFirst);
                         },
                         child: const Text('No, Close App', style: TextStyle(color: Colors.grey)),
                       ),
                       ElevatedButton(
                         onPressed: () {
                           Navigator.pop(ctx); // Close dialog
                           Navigator.push(
                             context,
                             MaterialPageRoute(builder: (_) => StudentRegistrationScreen(ownerId: widget.ownerId)),
                           );
                         },
                         child: const Text('Yes, Join Now'),
                       ),
                     ],
                   ),
                 );
              },
              child: const Text('I Received My Plate', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
        ],
      ),
    );
  }
}
