<<<<<<< HEAD
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:spotit/features/complaints/data/repositories/dummy_complaint_repository.dart';
import 'package:spotit/features/complaints/domain/repositories/complaint_repository.dart';
import 'package:spotit/features/home/presentation/pages/home_controller_page.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    debugPrint(
      'Firebase initialization failed: $e. Make sure to run flutterfire configure.',
    );
    try {
      await Firebase.initializeApp();
    } catch (e) {
      debugPrint('Firebase initialization without options failed: $e');
    }
  }

  // ───── SWAP THIS to change database ─────
  // For Firestore:
  //   final repository = FirestoreComplaintRepository(userId: 'current_user_id');
  // For dummy/offline mode:
  final repository = DummyComplaintRepository();
  // ────────────────────────────────────────

  runApp(SpotItApp(repository: repository));
}

class SpotItApp extends StatelessWidget {
  static final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(
    ThemeMode.dark,
  );

  final ComplaintRepository repository;

  const SpotItApp({super.key, required this.repository});

  @override
  Widget build(BuildContext context) {
    return RepositoryProvider(
      repository: repository,
      child: ValueListenableBuilder<ThemeMode>(
        valueListenable: themeNotifier,
        builder: (_, mode, _) {
          return MaterialApp(
            title: 'SpotIT',
            debugShowCheckedModeBanner: false,
            themeMode: mode,
            theme: ThemeData(
              brightness: Brightness.light,
              scaffoldBackgroundColor: const Color(0xFFF5F5F5),
              primaryColor: const Color(0xFFFFC107),
              colorScheme: ColorScheme.light(
                primary: const Color(0xFFFFC107),
                secondary: const Color(0xFFFFC107),
                surface: Colors.white,
              ),
              appBarTheme: const AppBarTheme(
                backgroundColor: Colors.white,
                foregroundColor: Colors.black,
                elevation: 0,
              ),
              useMaterial3: true,
            ),
            darkTheme: ThemeData(
              brightness: Brightness.dark,
              scaffoldBackgroundColor: const Color(0xFF121212),
              primaryColor: const Color(0xFFFFC107),
              colorScheme: ColorScheme.dark(
                primary: const Color(0xFFFFC107),
                secondary: const Color(0xFFFFC107),
                surface: const Color(0xFF1E1E1E),
              ),
              appBarTheme: const AppBarTheme(
                backgroundColor: Color(0xFF1A1A1A),
                foregroundColor: Colors.white,
                elevation: 0,
              ),
              useMaterial3: true,
            ),
            home: const HomeControllerPage(),
          );
        },
      ),
    );
  }
}

/// Provides the ComplaintRepository to the widget tree.
/// Access it from any widget with: RepositoryProvider.of(context)
=======
import 'package:flutter/material.dart';
import 'package:spotit/features/auth/presentation/pages/login_page.dart';
import 'package:spotit/features/complaints/data/repositories/dummy_complaint_repository.dart';
import 'package:spotit/features/complaints/domain/repositories/complaint_repository.dart';

// ─── Repository Provider ─────────────────────────────────────────────────────

/// Simple InheritedWidget that provides a [ComplaintRepository] down the tree.
>>>>>>> a2273dd3a72b26e61d482033ab992eee3b7afd05
class RepositoryProvider extends InheritedWidget {
  final ComplaintRepository repository;

  const RepositoryProvider({
    super.key,
    required this.repository,
    required super.child,
  });

  static ComplaintRepository of(BuildContext context) {
<<<<<<< HEAD
    final provider = context
        .dependOnInheritedWidgetOfExactType<RepositoryProvider>();
=======
    final provider =
        context.dependOnInheritedWidgetOfExactType<RepositoryProvider>();
>>>>>>> a2273dd3a72b26e61d482033ab992eee3b7afd05
    assert(provider != null, 'No RepositoryProvider found in context');
    return provider!.repository;
  }

  @override
<<<<<<< HEAD
  bool updateShouldNotify(RepositoryProvider oldWidget) {
    return repository != oldWidget.repository;
=======
  bool updateShouldNotify(RepositoryProvider oldWidget) =>
      repository != oldWidget.repository;
}

// ─── App Entry Point ─────────────────────────────────────────────────────────

void main() {
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

          home: const LoginPage(),
        );
      },
    );
>>>>>>> a2273dd3a72b26e61d482033ab992eee3b7afd05
  }
}
