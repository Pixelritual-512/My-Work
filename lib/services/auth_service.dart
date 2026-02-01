import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/owner_model.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  User? get currentUser => _auth.currentUser;

  // Sign Up
  Future<User?> signUp({
    required String email,
    required String password,
    required String name,
    required String messName,
    required String phone,
  }) async {
    try {
      UserCredential result = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      User? user = result.user;

      if (user != null) {
        // Create Owner Document
        Owner owner = Owner(
          id: user.uid,
          name: name,
          email: email,
          messName: messName,
          phone: phone,
          createdAt: DateTime.now(),
        );

        await _firestore.collection('owners').doc(user.uid).set(owner.toMap());
      }
      return user;
    } catch (e) {
      print("Error signing up: $e");
      rethrow;
    }
  }

  // Sign In
  Future<User?> signIn({required String email, required String password}) async {
    try {
      UserCredential result = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return result.user;
    } catch (e) {
      print("Error signing in: $e");
      rethrow;
    }
  }

  // Sign Out
  Future<void> signOut() async {
    await _auth.signOut();
  }

  // Delete Account
  Future<void> deleteAccount() async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        await user.delete();
      }
    } catch (e) {
      print("Error deleting account: $e");
      rethrow;
    }
  }
}
