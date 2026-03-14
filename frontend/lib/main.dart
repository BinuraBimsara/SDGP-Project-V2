import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:spotit/firebase_options.dart';
import 'package:spotit/features/auth/presentation/pages/get_started_page.dart';
import 'package:spotit/features/auth/presentation/pages/complete_profile_page.dart';
import 'package:spotit/features/home/presentation/pages/home_controller_page.dart';
import 'package:spotit/features/complaints/data/repositories/firestore_complaint_repository.dart';
import 'package:spotit/features/complaints/domain/repositories/complaint_repository.dart';
import 'package:spotit/features/chat/data/repositories/firestore_chat_repository.dart';
import 'package:spotit/features/chat/domain/repositories/chat_repository.dart';
import 'package:spotit/core/theme/theme_switcher.dart';

// ─── Repository Provider ─────────────────────────────────────────────────────

/// Simple InheritedWidget that provides a [ComplaintRepository] down the tree.
class RepositoryProvider extends InheritedWidget {
  final ComplaintRepository repository;

  const RepositoryProvider({
    super.key,
    required this.repository,
    required super.child,
  });

  static ComplaintRepository of(BuildContext context) {
    final provider =
        context.dependOnInheritedWidgetOfExactType<RepositoryProvider>();
    assert(provider != null, 'No RepositoryProvider found in context');
    return provider!.repository;
  }

  @override
  bool updateShouldNotify(RepositoryProvider oldWidget) =>
      repository != oldWidget.repository;
}

/// InheritedWidget that provides a [ChatRepository] down the tree.
class ChatRepositoryProvider extends InheritedWidget {
  final ChatRepository chatRepository;

  const ChatRepositoryProvider({
    super.key,
    required this.chatRepository,
    required super.child,
  });

  static ChatRepository of(BuildContext context) {
    final provider =
        context.dependOnInheritedWidgetOfExactType<ChatRepositoryProvider>();
    assert(provider != null, 'No ChatRepositoryProvider found in context');
    return provider!.chatRepository;
  }

  @override
  bool updateShouldNotify(ChatRepositoryProvider oldWidget) =>
      chatRepository != oldWidget.chatRepository;
}

// ─── App Entry Point ─────────────────────────────────────────────────────────

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  if (kIsWeb) {
    const recaptchaSiteKey = String.fromEnvironment('RECAPTCHA_SITE_KEY');
    if (recaptchaSiteKey.isNotEmpty) {
      await FirebaseAppCheck.instance.activate(
        webProvider: ReCaptchaV3Provider(recaptchaSiteKey),
      );
    }
  } else {
    await FirebaseAppCheck.instance.activate(
      androidProvider:
          kDebugMode ? AndroidProvider.debug : AndroidProvider.playIntegrity,
      appleProvider: kDebugMode
          ? AppleProvider.debug
          : AppleProvider.appAttestWithDeviceCheckFallback,
    );
  }

  // Enable Firestore offline persistence for instant data loading
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
    cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
  );
  runApp(
    RepositoryProvider(
      repository: FirestoreComplaintRepository(),
      child: ChatRepositoryProvider(
        chatRepository: FirestoreChatRepository(),
        child: const SpotItApp(),
      ),
    ),
  );
}

// ─── Root App Widget ─────────────────────────────────────────────────────────

class SpotItApp extends StatelessWidget {
  const SpotItApp({super.key});

  /// Global notifier for light / dark mode toggle (used by HomeControllerPage).
  static final themeNotifier = ValueNotifier<ThemeMode>(ThemeMode.light);

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (context, themeMode, _) {
        return MaterialApp(
          title: 'SpotIT LK',
          debugShowCheckedModeBanner: false,
          themeMode: themeMode,
          themeAnimationDuration: const Duration(milliseconds: 500),
          themeAnimationCurve: Curves.easeInOut,

          // ── Light Theme ──
          theme: ThemeData(
            brightness: Brightness.light,
            scaffoldBackgroundColor: const Color(0xFFEEF7EE),
            primaryColor: const Color(0xFF2EAA5E),
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF2EAA5E),
              secondary: Color(0xFF2EAA5E),
              surface: Colors.white,
            ),
            appBarTheme: const AppBarTheme(
              backgroundColor: Color(0xFFEEF7EE),
              elevation: 0,
            ),
            useMaterial3: true,
          ),

          // ── Dark Theme ──
          darkTheme: ThemeData(
            brightness: Brightness.dark,
            scaffoldBackgroundColor: const Color(0xFF121212),
            primaryColor: const Color(0xFF4CAF50),
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFF4CAF50),
              secondary: Color(0xFF4CAF50),
              surface: Color(0xFF1E1E1E),
            ),
            appBarTheme: const AppBarTheme(
              backgroundColor: Color(0xFF121212),
              elevation: 0,
            ),
            useMaterial3: true,
          ),

          builder: (context, child) {
            return ThemeSwitcher(
              key: ThemeSwitcher.instanceKey,
              child: child ?? const SizedBox.shrink(),
            );
          },

          home: const AuthGate(),
        );
      },
    );
  }
}

// ─── Auth Gate ───────────────────────────────────────────────────────────────

/// Listens to Firebase Auth state and routes accordingly:
/// - Not signed in → [GetStartedPage]
/// - Signed in but profile incomplete → [CompleteProfilePage]
/// - Signed in with completed profile → [HomeControllerPage]
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  /// Checks if the citizen's profile has been completed in Firestore.
  Future<bool> _isProfileComplete(String uid) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();
      if (!doc.exists) return false;
      final data = doc.data();
      return data != null && data['profileCompleted'] == true;
    } catch (_) {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // Still waiting for auth state — show a loading indicator.
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        // User is signed in → check if profile is complete.
        if (snapshot.hasData) {
          final user = snapshot.data!;
          return FutureBuilder<bool>(
            future: _isProfileComplete(user.uid),
            builder: (context, profileSnapshot) {
              if (profileSnapshot.connectionState == ConnectionState.waiting) {
                return const Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                );
              }

              // Profile is complete → go to home.
              if (profileSnapshot.data == true) {
                return const HomeControllerPage();
              }

              // Profile not complete → show complete profile page.
              return const CompleteProfilePage();
            },
          );
        }

        // Not signed in → show the get started page.
        return const GetStartedPage();
      },
    );
  }
}
