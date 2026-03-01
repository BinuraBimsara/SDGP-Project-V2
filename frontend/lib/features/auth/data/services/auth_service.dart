import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    clientId:
        '632998768428-th7r82as3l75umntvdh8qmgdt4vd4css.apps.googleusercontent.com',
  );

  /// The currently signed-in user, or null.
  User? get currentUser => _auth.currentUser;

  // ──────────────────── Google Sign-In ────────────────────

  /// Signs in with Google and returns the [UserCredential].
  ///
  /// Returns `null` if the user cancelled the sign-in flow.
  /// Throws on network or Firebase errors.
  Future<UserCredential?> signInWithGoogle() async {
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
  }
  // ──────────────────── Official Sign-Up ────────────────

  /// Creates a new official account with email and password.
  ///
  /// Stores the user's role as 'official' in the Firestore `users` collection.
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

    // Store the role in Firestore.
    final uid = userCredential.user!.uid;
    await _firestore.collection('users').doc(uid).set({
      'email': email.trim(),
      'role': 'official',
      'createdAt': FieldValue.serverTimestamp(),
    });

    return userCredential;
  }

  // ──────────────────── Official Sign-In ────────────────

  /// Signs in an official user with email and password.
  Future<UserCredential> signInOfficial({
    required String email,
    required String password,
  }) async {
    return await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }
  // ──────────────────── Sign Out ────────────────────

  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
  }
}
