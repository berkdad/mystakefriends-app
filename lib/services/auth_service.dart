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
      print('🔐 Attempting sign in for: $email');

      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (credential.user != null) {
        print('✅ Sign in successful. UID: ${credential.user!.uid}');

        // Update user document (non-blocking)
        _updateUserLoginStatus(credential.user!.uid).catchError((e) {
          print('⚠️ Error updating login status: $e');
        });

        // Initialize FCM in background (non-blocking)
        _initializeFCMInBackground(credential.user!.uid).catchError((e) {
          print('⚠️ FCM initialization error: $e');
        });
      }

      return credential;
    } on FirebaseAuthException catch (e) {
      print('❌ Auth error: ${e.code} - ${e.message}');
      throw _handleAuthException(e);
    } catch (e) {
      print('❌ Unexpected error during sign in: $e');
      rethrow;
    }
  }

// Non-blocking user status update
  Future<void> _updateUserLoginStatus(String uid) async {
    try {
      final userDoc = await _firestore.collection('users').doc(uid).get();

      if (userDoc.exists) {
        print('📄 User document found');
        await _firestore.collection('users').doc(uid).update({
          'hasLoggedIn': true,
          'lastLoginAt': FieldValue.serverTimestamp(),
        });
        print('✅ Updated hasLoggedIn flag');
      } else {
        print('⚠️ User document does NOT exist in users collection');
      }
    } catch (e) {
      print('❌ Error updating user status: $e');
    }
  }

// Non-blocking FCM initialization
  Future<void> _initializeFCMInBackground(String uid) async {
    try {
      print('📱 Initializing FCM...');
      await _fcmService.initialize().timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          print('⚠️ FCM initialization timeout');
        },
      );
      await _fcmService.saveTokenToFirestore(uid).timeout(
        const Duration(seconds: 3),
        onTimeout: () {
          print('⚠️ FCM token save timeout');
        },
      );
      print('✅ FCM token saved');
    } catch (e) {
      print('⚠️ FCM error (non-critical): $e');
    }
  }

  Future<void> signOut() async {
    if (currentUser != null) {
      print('🚪 Signing out user: ${currentUser!.uid}');
      await _fcmService.deleteTokenFromFirestore(currentUser!.uid);
    }
    await _auth.signOut();
    print('✅ Sign out complete');
  }

  Future<Map<String, dynamic>?> getUserData() async {
    if (currentUser == null) {
      print('⚠️ getUserData: No current user');
      return null;
    }

    try {
      print('📊 Getting user data for: ${currentUser!.uid}');
      print('   Email: ${currentUser!.email}');

      final doc = await _firestore
          .collection('users')
          .doc(currentUser!.uid)
          .get();

      if (!doc.exists) {
        print('❌ User document does NOT exist');
        return null;
      }

      final data = doc.data();
      print('✅ User data retrieved:');
      print('   stakeId: ${data?['stakeId']}');
      print('   wardId: ${data?['wardId']}');
      print('   hasLoggedIn: ${data?['hasLoggedIn']}');

      // If wardId is null, try to find it by searching for the member
      if (data?['wardId'] == null && data?['stakeId'] != null) {
        print('🔍 wardId is null, searching for member in stake...');
        final memberData = await _findMemberInStake(
          data!['stakeId'],
          currentUser!.email!,
        );

        if (memberData != null) {
          print('✅ Found member! wardId: ${memberData['wardId']}');

          // Update the user document with the found wardId
          await _firestore
              .collection('users')
              .doc(currentUser!.uid)
              .update({'wardId': memberData['wardId']});

          print('✅ Updated user document with wardId');

          // Return updated data
          data['wardId'] = memberData['wardId'];
          data['memberId'] = memberData['memberId'];
        } else {
          print('❌ Member not found in any ward in this stake');
        }
      }

      return data;
    } catch (e) {
      print('❌ Error getting user data: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> _findMemberInStake(
      String stakeId, String email) async {
    try {
      print('🔍 Searching for member with email: $email in stake: $stakeId');

      // Get all wards in the stake
      final wardsSnapshot = await _firestore
          .collection('stakes')
          .doc(stakeId)
          .collection('wards')
          .get();

      print('📋 Found ${wardsSnapshot.docs.length} wards to search');

      // Search each ward for the member
      for (final wardDoc in wardsSnapshot.docs) {
        print('   Checking ward: ${wardDoc.id}');

        final membersSnapshot = await _firestore
            .collection('stakes')
            .doc(stakeId)
            .collection('wards')
            .doc(wardDoc.id)
            .collection('members')
            .where('email', isEqualTo: email)
            .limit(1)
            .get();

        if (membersSnapshot.docs.isNotEmpty) {
          print('   ✅ Found member in ward: ${wardDoc.id}');
          return {
            'wardId': wardDoc.id,
            'memberId': membersSnapshot.docs.first.id,
          };
        }
      }

      print('❌ Member not found in any ward');
      return null;
    } catch (e) {
      print('❌ Error searching for member: $e');
      return null;
    }
  }

  Future<DocumentSnapshot?> getMemberProfile(
      String stakeId, String wardId, String email) async {
    try {
      print('👤 Getting member profile:');
      print('   stakeId: $stakeId');
      print('   wardId: $wardId');
      print('   email: $email');

      final querySnapshot = await _firestore
          .collection('stakes')
          .doc(stakeId)
          .collection('wards')
          .doc(wardId)
          .collection('members')
          .where('email', isEqualTo: email)
          .limit(1)
          .get();

      if (querySnapshot.docs.isEmpty) {
        print('❌ No member profile found');
        return null;
      }

      print('✅ Member profile found: ${querySnapshot.docs.first.id}');
      return querySnapshot.docs.first;
    } catch (e) {
      print('❌ Error getting member profile: $e');
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