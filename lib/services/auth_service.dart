import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'fcm_service.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FCMService _fcmService = FCMService();

  User? get currentUser => _auth.currentUser;
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  Future<UserCredential?> signIn(String email, String password) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (credential.user != null) {
        // Update hasLoggedIn flag
        await _firestore
            .collection('users')
            .doc(credential.user!.uid)
            .update({
          'hasLoggedIn': true,
          'lastLoginAt': FieldValue.serverTimestamp(),
        });

        // Initialize FCM and save token
        await _fcmService.initialize();
        await _fcmService.saveTokenToFirestore(credential.user!.uid);
      }

      return credential;
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    }
  }

  Future<void> signOut() async {
    if (currentUser != null) {
      await _fcmService.deleteTokenFromFirestore(currentUser!.uid);
    }
    await _auth.signOut();
  }

  Future<Map<String, dynamic>?> getUserData() async {
    if (currentUser == null) return null;

    try {
      final doc = await _firestore
          .collection('users')
          .doc(currentUser!.uid)
          .get();

      if (!doc.exists) return null;

      return doc.data();
    } catch (e) {
      print('Error getting user data: $e');
      return null;
    }
  }

  Future<DocumentSnapshot?> getMemberProfile(
      String stakeId, String wardId, String email) async {
    try {
      final querySnapshot = await _firestore
          .collection('stakes')
          .doc(stakeId)
          .collection('wards')
          .doc(wardId)
          .collection('members')
          .where('email', isEqualTo: email)
          .limit(1)
          .get();

      if (querySnapshot.docs.isEmpty) return null;

      return querySnapshot.docs.first;
    } catch (e) {
      print('Error getting member profile: $e');
      return null;
    }
  }

  String _handleAuthException(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return 'No user found with this email.';
      case 'wrong-password':
        return 'Wrong password provided.';
      case 'invalid-email':
        return 'The email address is invalid.';
      case 'user-disabled':
        return 'This user account has been disabled.';
      case 'too-many-requests':
        return 'Too many failed attempts. Please try again later.';
      case 'network-request-failed':
        return 'Network error. Please check your connection.';
      default:
        return 'An error occurred. Please try again.';
    }
  }
}