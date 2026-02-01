import 'package:cloud_firestore/cloud_firestore.dart';

class Owner {
  final String id;
  final String name;
  final String email;
  final String messName;
  final String phone;
  final DateTime createdAt;
  final double oneTimeFee;
  final double twoTimeFee;
  final String rules;
  final double guestVegPrice;
  final double guestNonVegPrice;
  final bool isNonVegToday;
  final String whatsappGroupLink;
  final String upiId;

  Owner({
    required this.id,
    required this.name,
    required this.email,
    required this.messName,
    required this.phone,
    required this.createdAt,
    this.oneTimeFee = 0.0,
    this.twoTimeFee = 0.0,
    this.rules = '',
    this.guestVegPrice = 0.0,
    this.guestNonVegPrice = 0.0,
    this.isNonVegToday = false,
    this.whatsappGroupLink = '',
    this.upiId = '',
  });

  factory Owner.fromDocument(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Owner(
      id: doc.id,
      name: data['name'] ?? '',
      email: data['email'] ?? '',
      messName: data['messName'] ?? '',
      phone: data['phone'] ?? '',
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      oneTimeFee: (data['oneTimeFee'] ?? data['monthlyFeeOneTime'] ?? 0).toDouble(),
      twoTimeFee: (data['twoTimeFee'] ?? data['monthlyFeeTwoTime'] ?? 0).toDouble(),
      rules: data['rules'] ?? '',
      guestVegPrice: (data['guestVegPrice'] ?? 0).toDouble(),
      guestNonVegPrice: (data['guestNonVegPrice'] ?? 0).toDouble(),
      isNonVegToday: data['isNonVegToday'] ?? false,
      whatsappGroupLink: data['whatsappGroupLink'] ?? '',
      upiId: data['upiId'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'email': email,
      'messName': messName,
      'phone': phone,
      'createdAt': Timestamp.fromDate(createdAt),
      'oneTimeFee': oneTimeFee,
      'twoTimeFee': twoTimeFee,
      'rules': rules,
      'guestVegPrice': guestVegPrice,
      'guestNonVegPrice': guestNonVegPrice,
      'isNonVegToday': isNonVegToday,
      'whatsappGroupLink': whatsappGroupLink,
      'upiId': upiId,
    };
  }
}
