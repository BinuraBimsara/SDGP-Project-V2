// auth_service.dart
// ─────────────────────────────────────────────────────────────
//  STUB implementation – Firebase backend is intentionally
//  skipped for GUI testing.  Replace with real implementation
//  later inside the /backend folder.
// ─────────────────────────────────────────────────────────────

enum UserRole { citizen, official }

class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  // ──────────────────── Email / Password ────────────────────

  Future<void> signInWithEmail({
    required String email,
    required String password,
    required UserRole role,
  }) async {
    // Stub: validate official email format only
    if (role == UserRole.official && !_isGovEmail(email)) {
      throw Exception('Government officials must use a .gov.lk email address.');
    }
    // Simulate a small network delay
    await Future.delayed(const Duration(milliseconds: 600));
    // In real implementation, call Firebase Auth here
  }

  Future<void> signUpWithEmail({
    required String firstName,
    required String lastName,
    required String email,
    required String password,
    required String province,
    required String cityOrTown,
  }) async {
    await Future.delayed(const Duration(milliseconds: 600));
    // In real implementation, call Firebase Auth here
  }

  // ──────────────────── Google Sign-In ────────────────────

  Future<bool> signInWithGoogle() async {
    await Future.delayed(const Duration(milliseconds: 600));
    // In real implementation, call Google Sign-In + Firebase Auth here
    return true;
  }

  // ──────────────────── Password Reset ────────────────────

  Future<void> sendPasswordResetEmail(String email) async {
    await Future.delayed(const Duration(milliseconds: 400));
    // In real implementation, call Firebase Auth here
  }

  // ──────────────────── Sign Out ────────────────────

  Future<void> signOut() async {
    // In real implementation, call Firebase Auth here
  }

  // ──────────────────── Helpers ────────────────────

  bool _isGovEmail(String email) {
    final lower = email.trim().toLowerCase();
    return lower.endsWith('.gov.lk');
  }
}
