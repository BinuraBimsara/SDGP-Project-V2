import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

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

  // ──────────────────── Sign Out ────────────────────

  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
  }
}
