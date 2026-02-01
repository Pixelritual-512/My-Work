import 'package:cloud_firestore/cloud_firestore.dart';

class Attendance {
  final String id;
  final String ownerId;
  final String studentId;
  final String date; // YYYY-MM-DD
  final bool lunch;
  final bool dinner;
  final DateTime createdAt;
  final String? lunchVariant;
  final String? dinnerVariant;

  Attendance({
    required this.id,
    required this.ownerId,
    required this.studentId,
    required this.date,
    required this.lunch,
    required this.dinner,
    required this.createdAt,
    this.lunchVariant,
    this.dinnerVariant,
  });

  factory Attendance.fromDocument(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Attendance(
      id: doc.id,
      ownerId: data['ownerId'] ?? '',
      studentId: data['studentId'] ?? '',
      date: data['date'] ?? '',
      lunch: data['lunch'] ?? false,
      dinner: data['dinner'] ?? false,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      lunchVariant: data['lunchVariant'],
      dinnerVariant: data['dinnerVariant'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'ownerId': ownerId,
      'studentId': studentId,
      'date': date,
      'lunch': lunch,
      'dinner': dinner,
      'createdAt': Timestamp.fromDate(createdAt),
      'lunchVariant': lunchVariant,
      'dinnerVariant': dinnerVariant,
    };
  }
}
