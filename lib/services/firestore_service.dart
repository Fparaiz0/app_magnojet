// lib/services/firestore_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_data.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final String _userCollection = 'users';

  Future<void> saveUserData({
    required String uid,
    required String email,
    required String name,
  }) async {
    final newUserData = UserData(
      uid: uid,
      email: email,
      name: name,
      createdAt: DateTime.now(),
    );

    await _db
        .collection(_userCollection)
        .doc(uid)
        .set(newUserData.toFirestore());
  }

  Future<UserData?> getUserData(String uid) async {
    try {
      final docSnapshot = await _db.collection(_userCollection).doc(uid).get();

      if (docSnapshot.exists && docSnapshot.data() != null) {
        return UserData.fromFirestore(docSnapshot.data()!);
      }
      return null;
    } catch (e) {
      print("Erro ao buscar dados do usuário: $e");
      return null;
    }
  }
}
