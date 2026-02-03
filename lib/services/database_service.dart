import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../models/student_model.dart';
import '../models/owner_model.dart';
import '../models/attendance_model.dart';
import '../models/payment_model.dart';
import '../models/menu_model.dart';

class DatabaseService {
  final String uid;
  DatabaseService({required this.uid});

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // --- Owner Methods ---
  Stream<Owner?> get ownerStream {
    return _db.collection('owners').doc(uid).snapshots().map((doc) {
      if (doc.exists) return Owner.fromDocument(doc);
      return null;
    });
  }

  Future<void> updateOwnerSettings({
    String? messName,
    double? monthlyFeeOneTime,
    double? monthlyFeeTwoTime,
    String? rules,
    String? whatsappGroupLink,
    String? upiId,
    double? guestVegPrice,
    double? guestNonVegPrice,
  }) async {
    Map<String, dynamic> data = {};
    if (messName != null) data['messName'] = messName;
    if (monthlyFeeOneTime != null) data['oneTimeFee'] = monthlyFeeOneTime;
    if (monthlyFeeTwoTime != null) data['twoTimeFee'] = monthlyFeeTwoTime;
    if (rules != null) data['rules'] = rules;
    if (whatsappGroupLink != null) data['whatsappGroupLink'] = whatsappGroupLink;
    if (upiId != null) data['upiId'] = upiId;
    if (guestVegPrice != null) data['guestVegPrice'] = guestVegPrice;
    if (guestNonVegPrice != null) data['guestNonVegPrice'] = guestNonVegPrice;

    return await _db.collection('owners').doc(uid).set(data, SetOptions(merge: true));
  }

  // --- Student/Member Methods ---
  Stream<List<Student>> get studentsStream {
    return _db
        .collection('students')
        .where('ownerId', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => Student.fromDocument(doc)).toList());
  }

  Stream<Student?> getStudentStream(String studentId) {
    return _db.collection('students').doc(studentId).snapshots().map((doc) {
      if (doc.exists) return Student.fromDocument(doc);
      return null;
    });
  }

  Stream<List<Student>> getExpiredStudentsStream() {
    return _db
        .collection('students')
        .where('ownerId', isEqualTo: uid)
        .where('active', isEqualTo: true)
        .snapshots()
        .map((snapshot) {
      final students = snapshot.docs.map((doc) => Student.fromDocument(doc)).toList();
      return students.where((s) => s.plateCount >= 28).toList();
    });
  }

  Future<void> renewMembership(String studentId) async {
    final doc = await _db.collection('students').doc(studentId).get();
    if (!doc.exists) return;

    final currentCount = (doc.data()?['plateCount'] ?? 0) as int;
    final newCount = currentCount > 28 ? currentCount - 28 : 0;

    await _db.collection('students').doc(studentId).update({
      'plateCount': newCount,
      'messStartDate': FieldValue.serverTimestamp(),
    });
  }

  Future<void> addStudent(Student student) async {
    final existing = await _db
        .collection('students')
        .where('ownerId', isEqualTo: uid)
        .where('mobileNumber', isEqualTo: student.mobileNumber)
        .get();

    if (existing.docs.isNotEmpty) {
      throw Exception('A member with this mobile number already exists.');
    }

    await _db.collection('students').add(student.toMap());
  }

  Future<void> updateStudent(Student student) async {
    await _db.collection('students').doc(student.id).update(student.toMap());
  }

  Future<void> deleteStudent(String studentId) async {
    // Cascade delete: Remove student's attendance records
    final attendanceDocs = await _db.collection('attendance')
        .where('studentId', isEqualTo: studentId)
        .get();
    for (var doc in attendanceDocs.docs) {
      await doc.reference.delete();
    }
    
    // Cascade delete: Remove student's payment records
    final paymentDocs = await _db.collection('payments')
        .where('studentId', isEqualTo: studentId)
        .get();
    for (var doc in paymentDocs.docs) {
      await doc.reference.delete();
    }
    
    // Finally, delete the student
    await _db.collection('students').doc(studentId).delete();
  }

  Future<void> deleteAllOwnerData() async {
    // Delete all students (includes cascade delete for attendance/payments)
    final students = await _db.collection('students')
        .where('ownerId', isEqualTo: uid)
        .get();
    for (var doc in students.docs) {
      await deleteStudent(doc.id);
    }
    
    // Delete remaining attendance records
    final attendance = await _db.collection('attendance')
        .where('ownerId', isEqualTo: uid)
        .get();
    for (var doc in attendance.docs) {
      await doc.reference.delete();
    }
    
    // Delete remaining payments
    final payments = await _db.collection('payments')
        .where('ownerId', isEqualTo: uid)
        .get();
    for (var doc in payments.docs) {
      await doc.reference.delete();
    }
    
    // Delete all menu items
    final menus = await _db.collection('menus')
        .where('ownerId', isEqualTo: uid)
        .get();
    for (var doc in menus.docs) {
      await doc.reference.delete();
    }
    
    // Delete all guest meals
    final guestMeals = await _db.collection('guest_meals')
        .where('ownerId', isEqualTo: uid)
        .get();
    for (var doc in guestMeals.docs) {
      await doc.reference.delete();
    }
    
    // Finally, delete owner profile
    await _db.collection('owners').doc(uid).delete();
  }
  
  // --- Student Approval Methods ---
  Stream<List<Student>> getPendingStudentsStream() {
    return _db
        .collection('students')
        .where('ownerId', isEqualTo: uid)
        .where('active', isEqualTo: false)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => Student.fromDocument(doc)).toList());
  }

  Future<void> approveStudent(Student student) async {
    final batch = _db.batch();
    
    // 1. If there's a pending payment, record it
    if (student.pendingPayment > 0) {
       final now = DateTime.now();
       final monthStr = "${now.year}-${now.month.toString().padLeft(2,'0')}";
       
       final paymentRef = _db.collection('payments').doc();
       batch.set(paymentRef, {
        'ownerId': uid,
        'studentId': student.id,
        'month': monthStr,
        'amount': student.monthlyFee,
        'paidAmount': student.pendingPayment,
        'paid': student.pendingPayment >= student.monthlyFee,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }

    // 2. Activate student and clear pending fields
    final studentRef = _db.collection('students').doc(student.id);
    batch.update(studentRef, {
      'active': true,
      'messStartDate': FieldValue.serverTimestamp(),
      'pendingPayment': 0.0,
      'pendingPaymentMode': '',
    });

    await batch.commit();
  }

  Future<void> rejectStudent(String studentId) async {
    await deleteStudent(studentId);
  }


  // --- Attendance Methods ---
  Future<void> initializeAttendanceForDate(String date) async {
    // Step 1: Get all active students
    final students = await _db.collection('students')
        .where('ownerId', isEqualTo: uid)
        .where('active', isEqualTo: true)
        .get();

    final validStudentIds = students.docs.map((doc) => doc.id).toSet();
    
    // Step 2: Clean up orphaned attendance records (students that no longer exist)
    final allAttendance = await _db.collection('attendance')
        .where('ownerId', isEqualTo: uid)
        .where('date', isEqualTo: date)
        .get();
    
    final batch = _db.batch();
    
    for (var attendanceDoc in allAttendance.docs) {
      final studentId = attendanceDoc.data()['studentId'];
      if (!validStudentIds.contains(studentId)) {
        // This attendance record references a deleted student - remove it
        batch.delete(attendanceDoc.reference);
      }
    }
    
    // Step 3: Create missing attendance records for active students
    for (var doc in students.docs) {
      final existing = await _db.collection('attendance')
          .where('ownerId', isEqualTo: uid)
          .where('studentId', isEqualTo: doc.id)
          .where('date', isEqualTo: date)
          .limit(1)
          .get();
      
      if (existing.docs.isEmpty) {
        final ref = _db.collection('attendance').doc();
        batch.set(ref, {
          'ownerId': uid,
          'studentId': doc.id,
          'date': date,
          'lunch': false,
          'dinner': false,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
    }
    
    await batch.commit();
  }

  Future<void> markAttendance(String studentId, String date, String type, bool value) async {
    final query = await _db.collection('attendance')
        .where('ownerId', isEqualTo: uid)
        .where('studentId', isEqualTo: studentId)
        .where('date', isEqualTo: date)
        .limit(1)
        .get();

    final batch = _db.batch();
    
    if (query.docs.isEmpty) {
      final ref = _db.collection('attendance').doc();
      batch.set(ref, {
        'ownerId': uid,
        'studentId': studentId,
        'date': date,
        'lunch': type == 'lunch' ? value : false,
        'dinner': type == 'dinner' ? value : false,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } else {
      batch.update(query.docs.first.reference, {
        type: value,
      });
    }

    if (value == true) {
      batch.update(_db.collection('students').doc(studentId), {
        'plateCount': FieldValue.increment(1),
      });
    } else {
      batch.update(_db.collection('students').doc(studentId), {
        'plateCount': FieldValue.increment(-1),
      });
    }

    await batch.commit();
  }

  Future<void> recordAttendance(String studentId, Attendance attendance) async {
    // Check for existing record for today
    final existingQuery = await _db.collection('attendance')
        .where('studentId', isEqualTo: studentId)
        .where('date', isEqualTo: attendance.date)
        .limit(1)
        .get();

    final batch = _db.batch();
    
    if (existingQuery.docs.isNotEmpty) {
      final doc = existingQuery.docs.first;
      final data = doc.data();
      
      // If trying to mark Lunch but it's already marked
      if (attendance.lunch && (data['lunch'] == true)) {
        throw Exception('Lunch already used today!');
      }
      // If trying to mark Dinner but it's already marked
      if (attendance.dinner && (data['dinner'] == true)) {
        throw Exception('Dinner already used today!');
      }

      // Update existing record
      batch.update(doc.reference, {
        if (attendance.lunch) 'lunch': true,
        if (attendance.dinner) 'dinner': true,
        if (attendance.lunch && attendance.lunchVariant != null) 'lunchVariant': attendance.lunchVariant,
        if (attendance.dinner && attendance.dinnerVariant != null) 'dinnerVariant': attendance.dinnerVariant,
      });
    } else {
      // Create new record
      final attRef = _db.collection('attendance').doc();
      batch.set(attRef, attendance.toMap());
    }

    final studentRef = _db.collection('students').doc(studentId);
    batch.update(studentRef, {
      'plateCount': FieldValue.increment(1),
    });

    await batch.commit();
  }

  Stream<List<Attendance>> getAttendanceStream(String date) {
    return _db
        .collection('attendance')
        .where('ownerId', isEqualTo: uid)
        .where('date', isEqualTo: date)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => Attendance.fromDocument(doc)).toList());
  }

  Stream<List<Attendance>> getMonthlyAttendanceStream(String monthStr) {
    // format: yyyy-MM
    return _db
        .collection('attendance')
        .where('ownerId', isEqualTo: uid)
        .where('date', isGreaterThanOrEqualTo: '$monthStr-01')
        .where('date', isLessThanOrEqualTo: '$monthStr-31')
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => Attendance.fromDocument(doc)).toList());
  }

  Stream<List<Attendance>> getStudentAttendanceHistory(String studentId) {
    return _db
        .collection('attendance')
        .where('studentId', isEqualTo: studentId)
        .orderBy('date', descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => Attendance.fromDocument(doc)).toList());
  }

  // --- Payment Methods ---
  Future<void> markPayment(String studentId, String month, double amount, double paidAmount) async {
    final query = await _db.collection('payments')
        .where('ownerId', isEqualTo: uid)
        .where('studentId', isEqualTo: studentId)
        .where('month', isEqualTo: month)
        .limit(1)
        .get();

    final batch = _db.batch();
    final isPaid = paidAmount >= amount;

    if (query.docs.isEmpty) {
      final ref = _db.collection('payments').doc();
      batch.set(ref, {
        'ownerId': uid,
        'studentId': studentId,
        'month': month,
        'amount': amount,
        'paidAmount': paidAmount,
        'paid': isPaid,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } else {
      batch.update(query.docs.first.reference, {
        'amount': amount,
        'paidAmount': paidAmount,
        'paid': isPaid,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();
  }

  Future<void> addPayment(Payment payment) async {
    await _db.collection('payments').add(payment.toMap());
  }

  Stream<List<Payment>> getPaymentsStream(String month) {
    return _db
        .collection('payments')
        .where('ownerId', isEqualTo: uid)
        .where('month', isEqualTo: month)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => Payment.fromDocument(doc)).toList());
  }

  Stream<List<Payment>> get paymentsStream {
    return _db
        .collection('payments')
        .where('ownerId', isEqualTo: uid)
        .orderBy('updatedAt', descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => Payment.fromDocument(doc)).toList());
  }

  // --- Menu Methods ---
  Future<void> saveMenu(String date, String lunch, String dinner, {bool isNonVeg = false}) async {
    return await _db.collection('menu').doc('${uid}_$date').set({
      'ownerId': uid,
      'date': date,
      'lunchMenu': lunch,
      'dinnerMenu': dinner,
      'isNonVegDay': isNonVeg,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateMenu(DateTime date, MessMenu menu) async {
    final dateStr = DateFormat('yyyy-MM-dd').format(date);
    await _db.collection('menu').doc('${uid}_$dateStr').set(menu.toMap());
  }

  Stream<MessMenu?> getMenuStream(String date) {
    return _db.collection('menu').doc('${uid}_$date').snapshots().map((doc) {
      if (doc.exists) return MessMenu.fromDocument(doc);
      return null;
    });
  }

  Future<Owner?> getOwner(String id) async {
    final doc = await _db.collection('owners').doc(id).get();
    if (doc.exists) return Owner.fromDocument(doc);
    return null;
  }

  Stream<QuerySnapshot> getPendingGuestMealsStream() {
    return _db
        .collection('guest_meals')
        .where('ownerId', isEqualTo: uid)
        .where('status', isEqualTo: 'pending')
        .snapshots();
  }

  Stream<Map<String, dynamic>> getGuestAnalytics() {
     return _db.collection('guest_meals')
        .where('ownerId', isEqualTo: uid)
        .where('status', isEqualTo: 'approved')
        .snapshots().map((snapshot) {
          int todayCount = 0;
          double todayRevenue = 0.0;
          double totalRevenue = 0.0;
          
          final now = DateTime.now();
          final today = DateFormat('yyyy-MM-dd').format(now);
          
          for (var doc in snapshot.docs) {
             final data = doc.data();
             final amount = (data['amount'] ?? 0).toDouble(); // Ensure double
             totalRevenue += amount;
             
             // Check if today
             final ts = data['timestamp'] as Timestamp?;
             if (ts != null) {
               final date = ts.toDate();
               if (DateFormat('yyyy-MM-dd').format(date) == today) {
                 todayCount++;
                 todayRevenue += amount;
               }
             }
          }
          return {
            'todayCount': todayCount,
            'todayRevenue': todayRevenue,
            'totalRevenue': totalRevenue,
          };
        });
  }



  // --- Guest Methods ---
  Stream<List<Map<String, dynamic>>> get pendingGuestRequestsStream {
    return _db
        .collection('guest_meals')
        .where('ownerId', isEqualTo: uid)
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) {
              final data = doc.data();
              data['id'] = doc.id;
              return data;
            }).toList());
  }

  Future<DocumentReference> recordGuestMeal(Map<String, dynamic> data) async {
    data['ownerId'] = uid;
    data['timestamp'] = FieldValue.serverTimestamp();
    return await _db.collection('guest_meals').add(data);
  }

  Future<void> updateGuestMealStatus(String id, String status) async {
    return await _db.collection('guest_meals').doc(id).update({'status': status});
  }
}

