import 'package:cloud_firestore/cloud_firestore.dart';

class Student {
  final String id;
  final String ownerId;
  final String name;
  final String photoUrl;
  final String mobileNumber;
  final double monthlyFee;
  final bool active;
  final DateTime createdAt;
  final DateTime? messStartDate;
  final String messType; // 'One Time' or 'Two Time'
  final int plateCount; // Current cycle plate count

  Student({
    required this.id,
    required this.ownerId,
    required this.name,
    required this.photoUrl,
    required this.mobileNumber,
    required this.monthlyFee,
    required this.active,
    required this.createdAt,
    this.messStartDate,
    this.messType = 'Two Time',
    this.plateCount = 0,
  });

  factory Student.fromDocument(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Student(
      id: doc.id,
      ownerId: data['ownerId'] ?? '',
      name: data['name'] ?? '',
      photoUrl: data['photoUrl'] ?? '',
      mobileNumber: data['mobileNumber'] ?? '',
      monthlyFee: (data['monthlyFee'] ?? 0).toDouble(),
      active: data['active'] ?? true,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      messStartDate: data['messStartDate'] != null
          ? (data['messStartDate'] as Timestamp).toDate()
          : null,
      messType: data['messType'] ?? 'Two Time',
      plateCount: data['plateCount'] ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'ownerId': ownerId,
      'name': name,
      'photoUrl': photoUrl,
      'mobileNumber': mobileNumber,
      'monthlyFee': monthlyFee,
      'active': active,
      'createdAt': Timestamp.fromDate(createdAt),
      'messStartDate': messStartDate != null ? Timestamp.fromDate(messStartDate!) : null,
      'messType': messType,
      'plateCount': plateCount,
    };
  }
}

