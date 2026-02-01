import 'package:cloud_firestore/cloud_firestore.dart';

class MessMenu {
  final String id;
  final String ownerId;
  final String date; // YYYY-MM-DD
  final String lunchMenu;
  final String dinnerMenu;
  final bool isNonVegDay;
  final DateTime createdAt;

  MessMenu({
    required this.id,
    required this.ownerId,
    required this.date,
    required this.lunchMenu,
    required this.dinnerMenu,
    this.isNonVegDay = false,
    required this.createdAt,
  });

  factory MessMenu.fromDocument(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return MessMenu(
      id: doc.id,
      ownerId: data['ownerId'] ?? '',
      date: data['date'] ?? '',
      lunchMenu: data['lunchMenu'] ?? '',
      dinnerMenu: data['dinnerMenu'] ?? '',
      isNonVegDay: data['isNonVegDay'] ?? false,
      createdAt: data['createdAt'] != null 
          ? (data['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'ownerId': ownerId,
      'date': date,
      'lunchMenu': lunchMenu,
      'dinnerMenu': dinnerMenu,
      'isNonVegDay': isNonVegDay,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}
