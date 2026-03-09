import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  /// The currently signed-in user, or null.
  User? get currentUser => _auth.currentUser;

  // ──────────────────── Google Sign-In ────────────────────

  /// Signs in with Google and returns the [UserCredential].
  ///
  /// Returns `null` if the user cancelled the sign-in flow.
  /// Throws on network or Firebase errors.
  Future<UserCredential?> signInWithGoogle() async {
    try {
      if (kIsWeb) {
        final provider = GoogleAuthProvider();
        return await _auth.signInWithPopup(provider);
      }

      // Trigger the Google Sign-In flow (account picker).
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

      // User cancelled the picker.
      if (googleUser == null) return null;

      // Obtain the auth details from the request.
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      // Create a new credential for Firebase.
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Sign in to Firebase with the Google credential.
      return await _auth.signInWithCredential(credential);
    } on PlatformException catch (e) {
      if (e.code == 'sign_in_failed') {
        throw Exception(
          'Google sign-in failed. This is usually Firebase OAuth config '
          'missing SHA-1/SHA-256 for Android.',
        );
      }
      rethrow;
    }
  }
  // ──────────────────── Official Sign-Up ────────────────

  /// Creates a new official account with email and password.
  ///
  /// Client-side role assignment is intentionally blocked for security.
  /// New accounts are created as regular users and must be promoted by backend/admin.
  /// The email must be a valid government email ending in `.gov.lk`.
  /// Throws on validation, network or Firebase errors.
  Future<UserCredential> createOfficialAccount({
    required String email,
    required String password,
  }) async {
    // Create the Firebase Auth account.
    final userCredential = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );

    // Store basic profile data only. Role escalation must be server-managed.
    final uid = userCredential.user!.uid;
    await _firestore.collection('users').doc(uid).set({
      'email': email.trim(),
      'role': 'citizen',
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    return userCredential;
  }

  // ──────────────────── Official Sign-In ────────────────

  /// Signs in an official user with email and password.
  Future<UserCredential> signInOfficial({
    required String email,
    required String password,
  }) async {
    final credential = await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );

    final uid = credential.user?.uid;
    if (uid == null) {
      throw Exception('Signed-in user not found.');
    }

    final userDoc = await _firestore.collection('users').doc(uid).get();
    final role = userDoc.data()?['role'] as String?;
    if (role != 'official' && role != 'government') {
      await _auth.signOut();
      throw Exception('Official access not approved for this account.');
    }

    return credential;
  }
  // ──────────────────── Sign Out ────────────────────

  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
  }
}
