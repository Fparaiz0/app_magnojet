// lib/models/user_data.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class UserData {
  final String uid;
  final String email;
  final String name;
  final DateTime createdAt;

  UserData({
    required this.uid,
    required this.email,
    required this.name,
    required this.createdAt,
  });

  Map<String, dynamic> toFirestore() {
    return {
      "uid": uid,
      "email": email,
      "name": name,
      "createdAt": Timestamp.fromDate(createdAt),
    };
  }

  factory UserData.fromFirestore(Map<String, dynamic> data) {
    return UserData(
      uid: data['uid'] as String,
      email: data['email'] as String,
      name: data['name'] as String,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
    );
  }
}
