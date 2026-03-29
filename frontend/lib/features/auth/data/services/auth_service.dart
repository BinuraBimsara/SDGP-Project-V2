import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';

// AuthService handles all authentication operations for SpotIT.
// It is a singleton — there is only ever ONE instance of this class.
// This means calling AuthService() anywhere in the app gives you the same object.
//
// It supports two login paths:
//   1. Citizens: Google Sign-In (one tap, no password)
//   2. Officials: Email + Password (government accounts only)
class AuthService {
  // Singleton pattern: _instance is created once, the factory always returns it
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance; // calling AuthService() returns the same object
  AuthService._internal(); // private constructor — no one can use "new AuthService()"

  // ── Seeded official accounts ─────────────────────────────────────────────
  // These are pre-approved government test accounts for development/demo.
  // All accounts with these emails get the 'official' role automatically.
  static const String seededOfficialEmail = 'admintest@2026.gov.lk';
  static const List<String> seededOfficialEmails = [
    seededOfficialEmail,
    'admin.test@ict.gov.lk',
  ];
  static const String seededOfficialPassword = 'spotit2026@135'; // current approved password

  // These are the access roles that count as "government official" in the app.
  // Any user with one of these roles gets routed to GovHomeControllerPage.
  static const Set<String> allowedOfficialRoles = {
    'official',
    'government',
    'admin',
    'developer',
    'dev',
  };

  // Old passwords for the seeded accounts — used during migration
  // in case the account was created with an older password
  static const List<String> _seededOfficialLegacyPasswords = [
    'GovTest2026!',
    'admin2026@135',
    'admint.test2026',
  ];

  // Returns true if the given email is one of the pre-approved official emails
  static bool isSeededOfficialEmail(String email) {
    final normalized = email.trim().toLowerCase();
    return seededOfficialEmails.contains(normalized);
  }

  // Returns true if the password matches the current or any legacy approved password
  static bool isAcceptedSeededOfficialPassword(String password) {
    return password == seededOfficialPassword ||
        _seededOfficialLegacyPasswords.contains(password);
  }

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn(); // handles the Google picker UI

  // The currently signed-in user (null if not logged in)
  User? get currentUser => _auth.currentUser;

  // ── Google Sign-In ───────────────────────────────────────────────────────

  // Signs the user in with their Google account.
  // On web, uses a popup. On mobile, opens the Google account picker.
  // Returns null if the user closes the picker without choosing an account.
  Future<UserCredential?> signInWithGoogle() async {
    try {
      if (kIsWeb) {
        // Web: show the Google sign-in popup directly in the browser
        final provider = GoogleAuthProvider();
        return await _auth.signInWithPopup(provider);
      }

      // Mobile: show the Google account picker
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

      if (googleUser == null) return null; // user closed the picker

      // Get the auth tokens from Google
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      // Convert to a Firebase credential using the tokens
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken, // proves the user's identity to Firebase
        idToken: googleAuth.idToken,
      );

      // Sign in to Firebase using the Google credential
      return await _auth.signInWithCredential(credential);
    } on PlatformException catch (e) {
      if (e.code == 'sign_in_failed') {
        // This usually means the SHA-1 fingerprint wasn't registered in Firebase console
        throw Exception(
          'Google sign-in failed. This is usually Firebase OAuth config '
          'missing SHA-1/SHA-256 for Android.',
        );
      }
      rethrow;
    }
  }

  // ── Official Account Creation ────────────────────────────────────────────

  // Creates a new official account with email + password.
  // IMPORTANT: The role is intentionally set to 'citizen' on creation.
  // Escalating to 'official' must be done by a server-side admin — not the client.
  // This prevents a user from signing up as an official by manipulating the app.
  Future<UserCredential> createOfficialAccount({
    required String email,
    required String password,
  }) async {
    // 1. Create the Firebase Auth account (handles password hashing etc.)
    final userCredential = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );

    // 2. Store the basic profile in Firestore.
    // merge: true means we don't wipe existing fields if the document already exists.
    final uid = userCredential.user!.uid;
    await _firestore.collection('users').doc(uid).set({
      'email': email.trim(),
      'role': 'citizen',                       // always starts as citizen
      'createdAt': FieldValue.serverTimestamp(), // server-side timestamp
    }, SetOptions(merge: true));

    return userCredential;
  }

  // ── Official Sign-In ─────────────────────────────────────────────────────

  // Signs in an official with email + password, then verifies they have an
  // allowed role in Firestore. If their role isn't approved, they're signed out.
  Future<UserCredential> signInOfficial({
    required String email,
    required String password,
  }) async {
    final normalizedEmail = email.trim().toLowerCase(); // always compare lowercase

    // 1. Authenticate with Firebase Auth
    final credential = await _auth.signInWithEmailAndPassword(
      email: normalizedEmail,
      password: password,
    );

    final uid = credential.user?.uid;
    if (uid == null) throw Exception('Signed-in user not found.');

    // 2. Check their role in Firestore (the source of truth for access control)
    final userDoc = await _firestore.collection('users').doc(uid).get();
    final role = (userDoc.data()?['role'] as String?)?.toLowerCase();

    if (!allowedOfficialRoles.contains(role)) {
      // Role not found at the expected path (uid-based document).
      // Try to find the account by email in case it was created with a non-uid document ID.
      final byEmail = await _firestore
          .collection('users')
          .where('email', isEqualTo: normalizedEmail)
          .limit(1)
          .get();

      if (byEmail.docs.isNotEmpty) {
        final emailData = byEmail.docs.first.data();
        final emailRole = (emailData['role'] as String?)?.toLowerCase();
        if (allowedOfficialRoles.contains(emailRole)) {
          // Found an approved account by email — link it to the auth UID
          await _firestore.collection('users').doc(uid).set({
            ...emailData,
            'email': normalizedEmail,
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
          return credential; // allow login
        }
      }

      // No approved role found anywhere — block login
      await _auth.signOut();
      throw Exception('Official access not approved for this account.');
    }

    return credential;
  }

  // ── Seeded Account Bootstrap ─────────────────────────────────────────────

  // Ensures a known government test account exists and has the 'admin' role.
  // Called when a seeded official email is entered at the login screen.
  // If the account doesn't exist in Firebase Auth, it creates it.
  // If the account exists with an old password, it migrates it to the new one.
  Future<void> ensureSeededOfficialAccount({
    required String email,
    required String password,
  }) async {
    final normalizedEmail = email.trim().toLowerCase();

    // Only run for known seeded emails — exits early for all other emails
    if (!isSeededOfficialEmail(normalizedEmail)) return;

    if (!isAcceptedSeededOfficialPassword(password)) {
      throw Exception('Invalid password for the approved official account.');
    }

    try {
      // Try to sign in with the current password and update the Firestore profile
      final credential = await _auth.signInWithEmailAndPassword(
        email: normalizedEmail,
        password: password,
      );
      final uid = credential.user?.uid;
      if (uid == null) throw Exception('Signed-in user not found.');

      // Ensure the Firestore profile has the 'admin' role
      await _firestore.collection('users').doc(uid).set({
        'email': normalizedEmail,
        'displayName': 'ICT Admin Test',
        'role': 'admin',
        'approvedOfficial': true,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found') {
        // Account doesn't exist — create it from scratch
        final created = await _auth.createUserWithEmailAndPassword(
          email: normalizedEmail,
          password: password,
        );
        final uid = created.user?.uid;
        if (uid == null) throw Exception('Failed to create official account.');

        await _firestore.collection('users').doc(uid).set({
          'email': normalizedEmail,
          'displayName': 'ICT Admin Test',
          'role': 'admin',
          'approvedOfficial': true,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        // Sign out so the normal login flow re-authenticates cleanly
        await _auth.signOut();
        return;
      }

      if (e.code == 'wrong-password' || e.code == 'invalid-credential') {
        // Current password doesn't work — try each legacy password in order
        for (final legacyPassword in _seededOfficialLegacyPasswords) {
          try {
            final legacyCredential = await _auth.signInWithEmailAndPassword(
              email: normalizedEmail,
              password: legacyPassword,
            );
            final user = legacyCredential.user;
            if (user != null) {
              // Migrate to the new password and update the profile
              await user.updatePassword(seededOfficialPassword);
              await _firestore.collection('users').doc(user.uid).set({
                'email': normalizedEmail,
                'displayName': 'ICT Admin Test',
                'role': 'admin',
                'approvedOfficial': true,
                'updatedAt': FieldValue.serverTimestamp(),
              }, SetOptions(merge: true));
              await _auth.signOut(); // sign out to let the normal flow take over
              return;
            }
          } on FirebaseAuthException {
            // This legacy password didn't work — try the next one
          }
        }

        throw Exception(
          'Seeded official account exists with a different password. '
          'Please use the current approved password: $seededOfficialPassword',
        );
      }

      rethrow; // unexpected Firebase error — let it bubble up
    }
  }

  // ── Sign Out ─────────────────────────────────────────────────────────────

  // Signs the user out of both Google Sign-In and Firebase Auth.
  // Both must be signed out — Google alone would still auto-sign back in.
  Future<void> signOut() async {
    await _googleSignIn.signOut(); // revoke Google session
    await _auth.signOut();         // revoke Firebase session
  }
}
