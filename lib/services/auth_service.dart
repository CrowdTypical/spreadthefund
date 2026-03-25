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

      // Create user document in Firestore if it doesn't exist
      final userDoc = _firestore.collection('users').doc(userCredential.user!.uid);
      final exists = await userDoc.get();

      if (!exists.exists) {
        await userDoc.set({
          'uid': userCredential.user!.uid,
          'email': userCredential.user!.email,
          'displayName': userCredential.user!.displayName,
          'photoUrl': userCredential.user!.photoURL,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      // Auto-join any groups this user was invited to (by email)
      final email = userCredential.user!.email;
      if (email != null) {
        await _billService.processPendingInvites(
          userCredential.user!.uid,
          email,
        );
      }

      return userCredential.user!.uid;
    } catch (e) {
      print('Error signing in with Google: $e');
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
      print('Error updating username: $e');
      return false;
    }
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
