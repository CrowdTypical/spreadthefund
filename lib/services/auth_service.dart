// Copyright (C) 2026 Jason Green. All rights reserved.
// Licensed under the PolyForm Shield License 1.0.0
// https://polyformproject.org/licenses/shield/1.0.0/

import 'dart:developer';

import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'bill_service.dart';

class AuthService {
  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn(scopes: ['email']);
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final BillService _billService;

  AuthService(this._billService);

  Stream<User?> get authStateChanges => _firebaseAuth.authStateChanges();

  User? get currentUser => _firebaseAuth.currentUser;

  Future<String?> signInWithGoogle() async {
    final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
    if (googleUser == null) return null; // User cancelled

    try {
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

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
      // The google_sign_in_android Pigeon layer can throw a type cast error
      // even though Firebase auth actually succeeded. Check if we're signed in
      // before treating this as a failure.
      if (_firebaseAuth.currentUser != null) {
        if (kDebugMode) log('Google sign-in post-auth error (ignored): $e');
        return _firebaseAuth.currentUser!.email?.toLowerCase();
      }
      rethrow;
    }
  }

  // --- Email/Password Authentication ---

  /// Validates password strength: min 8 chars, 1 number, 1 special character.
  String? validatePassword(String password) {
    if (password.length < 8) {
      return 'Password must be at least 8 characters';
    }
    if (!RegExp(r'[0-9]').hasMatch(password)) {
      return 'Password must contain at least one number';
    }
    if (!RegExp(r'[!@#$%^&*(),.?":{}|<>_\-+=\[\]\\\/~`]').hasMatch(password)) {
      return 'Password must contain at least one special character';
    }
    return null;
  }

  /// Creates a new account with email and password.
  /// Returns a map with 'success' bool and optional 'error' string.
  Future<Map<String, dynamic>> signUpWithEmail(String email, String password) async {
    try {
      final UserCredential userCredential =
          await _firebaseAuth.createUserWithEmailAndPassword(
        email: email.trim().toLowerCase(),
        password: password,
      );

      // Send email verification
      await userCredential.user!.sendEmailVerification();

      final uid = userCredential.user!.uid;
      final userEmail = userCredential.user!.email?.toLowerCase();

      // Create user doc in Firestore
      final userDoc = _firestore.collection('users').doc(uid);
      await userDoc.set({
        'uid': uid,
        'email': userEmail,
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (userEmail != null) {
        await _billService.migrateUidToEmail(uid, userEmail);
        await _billService.processPendingInvites(userEmail);
      }

      return {'success': true};
    } on FirebaseAuthException catch (e) {
      String message;
      switch (e.code) {
        case 'email-already-in-use':
          message = 'An account already exists with this email';
          break;
        case 'invalid-email':
          message = 'Please enter a valid email address';
          break;
        case 'weak-password':
          message = 'Password is too weak';
          break;
        default:
          message = 'Sign-up failed. Please try again.';
      }
      if (kDebugMode) log('Error signing up with email: $e');
      return {'success': false, 'error': message};
    } catch (e) {
      if (kDebugMode) log('Error signing up with email: $e');
      return {'success': false, 'error': 'Sign-up failed. Please try again.'};
    }
  }

  /// Signs in with email and password.
  /// Returns a map with 'success' bool and optional 'error' string.
  Future<Map<String, dynamic>> signInWithEmail(String email, String password) async {
    try {
      final UserCredential userCredential =
          await _firebaseAuth.signInWithEmailAndPassword(
        email: email.trim().toLowerCase(),
        password: password,
      );

      final uid = userCredential.user!.uid;
      final userEmail = userCredential.user!.email?.toLowerCase();

      // Merge user data
      final userDoc = _firestore.collection('users').doc(uid);
      final exists = await userDoc.get();
      await userDoc.set({
        'uid': uid,
        'email': userEmail,
        if (!exists.exists) 'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (userEmail != null) {
        await _billService.migrateUidToEmail(uid, userEmail);
        await _billService.processPendingInvites(userEmail);
      }

      return {'success': true};
    } on FirebaseAuthException catch (e) {
      // Use generic messages to prevent account enumeration
      String message;
      switch (e.code) {
        case 'user-not-found':
        case 'wrong-password':
        case 'invalid-credential':
          message = 'Invalid email or password';
          break;
        case 'user-disabled':
          message = 'This account has been disabled';
          break;
        case 'too-many-requests':
          message = 'Too many attempts. Please try again later.';
          break;
        default:
          message = 'Sign-in failed. Please try again.';
      }
      if (kDebugMode) log('Error signing in with email: $e');
      return {'success': false, 'error': message};
    } catch (e) {
      if (kDebugMode) log('Error signing in with email: $e');
      return {'success': false, 'error': 'Sign-in failed. Please try again.'};
    }
  }

  /// Sends a password reset email. Uses a generic success message
  /// regardless of whether the email exists (prevents enumeration).
  Future<void> sendPasswordReset(String email) async {
    try {
      await _firebaseAuth.sendPasswordResetEmail(email: email.trim().toLowerCase());
    } catch (e) {
      // Silently catch — don't reveal if email exists
      if (kDebugMode) log('Password reset error: $e');
    }
  }

  /// Resends email verification to the current user.
  Future<bool> resendVerificationEmail() async {
    try {
      final user = _firebaseAuth.currentUser;
      if (user != null && !user.emailVerified) {
        await user.sendEmailVerification();
        return true;
      }
      return false;
    } catch (e) {
      if (kDebugMode) log('Error resending verification email: $e');
      return false;
    }
  }

  /// Checks if the current user's email is verified.
  /// Reloads the user first to get the latest status.
  Future<bool> isEmailVerified() async {
    final user = _firebaseAuth.currentUser;
    if (user == null) return false;
    await user.reload();
    return _firebaseAuth.currentUser?.emailVerified ?? false;
  }

  Future<void> reloadCurrentUser() async {
    await _firebaseAuth.currentUser?.reload();
  }

  Future<bool> updateUsername(String username) async {
    try {
      final user = _firebaseAuth.currentUser;
      if (user == null) return false;
      await _firestore.collection('users').doc(user.uid).set({
        'username': username,
        'email': user.email?.toLowerCase(),
      }, SetOptions(merge: true));
      return true;
    } catch (e) {
      if (kDebugMode) log('Error updating username: $e');
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

  /// Returns true if the current user signed in with email/password.
  bool get isEmailPasswordUser {
    final user = _firebaseAuth.currentUser;
    if (user == null) return false;
    return user.providerData.any((info) => info.providerId == 'password');
  }

  /// Re-authenticates the current user so account deletion will succeed.
  /// Call this BEFORE deleting data so the UI is still stable for any prompts.
  /// For email/password users, pass the user's current [password].
  Future<bool> reauthenticate({String? password}) async {
    try {
      final user = _firebaseAuth.currentUser;
      if (user == null) return false;

      final isGoogle = user.providerData.any(
        (info) => info.providerId == 'google.com',
      );

      if (isGoogle) {
        // Try silent re-auth first, fall back to interactive
        var googleUser = await _googleSignIn.signInSilently();
        googleUser ??= await _googleSignIn.signIn();
        if (googleUser == null) return false;
        final googleAuth = await googleUser.authentication;
        final credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );
        await user.reauthenticateWithCredential(credential);
      } else if (user.email != null && password != null) {
        final credential = EmailAuthProvider.credential(
          email: user.email!,
          password: password,
        );
        await user.reauthenticateWithCredential(credential);
      } else {
        return false;
      }

      return true;
    } catch (e) {
      if (kDebugMode) log('Error re-authenticating: $e');
      return false;
    }
  }

  /// Deletes the Firebase Auth account. Call reauthenticate() first.
  Future<bool> deleteAccount() async {
    try {
      final user = _firebaseAuth.currentUser;
      if (user == null) return false;
      await user.delete();
      return true;
    } catch (e) {
      if (kDebugMode) log('Error deleting auth account: $e');
      return false;
    }
  }

  Future<void> signOut() async {
    await Future.wait([
      _firebaseAuth.signOut(),
      _googleSignIn.signOut(),
    ]);
  }
}
