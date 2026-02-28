import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:spotit/firebase_options.dart';
import 'package:spotit/features/auth/presentation/pages/get_started_page.dart';
import 'package:spotit/features/home/presentation/pages/home_controller_page.dart';
import 'package:spotit/features/complaints/data/repositories/dummy_complaint_repository.dart';
import 'package:spotit/features/complaints/domain/repositories/complaint_repository.dart';

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

// ─── App Entry Point ─────────────────────────────────────────────────────────

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(
    RepositoryProvider(
      repository: DummyComplaintRepository(),
      child: const SpotItApp(),
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

          home: const AuthGate(),
        );
      },
    );
  }
}

// ─── Auth Gate ───────────────────────────────────────────────────────────────

/// Listens to Firebase Auth state and routes to [LoginPage] or
/// [HomeControllerPage] accordingly. This keeps users signed in across
/// app restarts.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

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

        // User is signed in → go straight to home.
        if (snapshot.hasData) {
          return const HomeControllerPage();
        }

        // Not signed in → show the get started page.
        return const GetStartedPage();
      },
    );
  }
}
