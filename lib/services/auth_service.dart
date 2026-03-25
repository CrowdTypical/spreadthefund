import 'dart:developer';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'bill_service.dart';

class AuthService {
  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn(scopes: ['email']);
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final BillService _billService = BillService();

  Stream<User?> get authStateChanges => _firebaseAuth.authStateChanges();

  User? get currentUser => _firebaseAuth.currentUser;

  Future<String?> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return null;

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final UserCredential userCredential =
          await _firebaseAuth.signInWithCredential(credential);

      final uid = userCredential.user!.uid;
      final email = userCredential.user!.email?.toLowerCase();

      // Always merge user data so email/displayName stay up to date
      final userDoc = _firestore.collection('users').doc(uid);
      final exists = await userDoc.get();

      await userDoc.set({
        'uid': uid,
        'email': email,
        'displayName': userCredential.user!.displayName,
        'photoUrl': userCredential.user!.photoURL,
        if (!exists.exists) 'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (email != null) {
        // Migrate any old UID-based group memberships to email
        await _billService.migrateUidToEmail(uid, email);
        // Mark pending invites as accepted
        await _billService.processPendingInvites(email);
      }

      return email;
    } catch (e) {
      log('Error signing in with Google: $e');
      return null;
    }
  }

  Future<bool> updateUsername(String username) async {
    try {
      final user = _firebaseAuth.currentUser;
      if (user == null) return false;
      await _firestore.collection('users').doc(user.uid).set({
        'username': username,
      }, SetOptions(merge: true));
      return true;
    } catch (e) {
      log('Error updating username: $e');
      return false;
    }
  }

  // Check if the user still needs to set their name (onboarding)
  Future<bool> needsOnboarding() async {
    final user = _firebaseAuth.currentUser;
    if (user == null) return false;
    final doc = await _firestore.collection('users').doc(user.uid).get();
    if (!doc.exists) return true;
    final data = doc.data()!;
    final username = data['username'] as String?;
    return username == null || username.isEmpty;
  }

  Stream<DocumentSnapshot> get userDocStream {
    final user = _firebaseAuth.currentUser;
    if (user == null) return const Stream.empty();
    return _firestore.collection('users').doc(user.uid).snapshots();
  }

  Future<void> signOut() async {
    await Future.wait([
      _firebaseAuth.signOut(),
      _googleSignIn.signOut(),
    ]);
  }
}
