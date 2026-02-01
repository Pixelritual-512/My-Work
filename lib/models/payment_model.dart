import 'package:cloud_firestore/cloud_firestore.dart';

class Payment {
  final String id;
  final String ownerId;
  final String studentId;
  final String month; // YYYY-MM
  final double amount;
  final double paidAmount;
  final bool paid;
  final DateTime updatedAt;

  Payment({
    required this.id,
    required this.ownerId,
    required this.studentId,
    required this.month,
    required this.amount,
    required this.paidAmount,
    required this.paid,
    required this.updatedAt,
  });

  factory Payment.fromDocument(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Payment(
      id: doc.id,
      ownerId: data['ownerId'] ?? '',
      studentId: data['studentId'] ?? '',
      month: data['month'] ?? '',
      amount: (data['amount'] ?? 0).toDouble(),
      paidAmount: (data['paidAmount'] ?? 0).toDouble(),
      paid: data['paid'] ?? false,
      updatedAt: (data['updatedAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'ownerId': ownerId,
      'studentId': studentId,
      'month': month,
      'amount': amount,
      'paidAmount': paidAmount,
      'paid': paid,
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }
}
