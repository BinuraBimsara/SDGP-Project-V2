// Flutter and Firebase core packages
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

// App-specific imports
import 'package:spotit/firebase_options.dart';
import 'package:spotit/features/auth/presentation/pages/get_started_page.dart';
import 'package:spotit/features/auth/presentation/pages/complete_profile_page.dart';
import 'package:spotit/features/home/presentation/pages/home_controller_page.dart';
import 'package:spotit/features/gov_dashboard/presentation/pages/gov_home_controller_page.dart';
import 'package:spotit/features/complaints/data/repositories/firestore_complaint_repository.dart';
import 'package:spotit/features/complaints/domain/repositories/complaint_repository.dart';
import 'package:spotit/features/chat/data/repositories/firestore_chat_repository.dart';
import 'package:spotit/features/chat/domain/repositories/chat_repository.dart';
import 'package:spotit/core/theme/theme_switcher.dart';

// ─── Repository Providers ────────────────────────────────────────────────────
// These are InheritedWidgets — they sit at the top of the widget tree and make
// the repository objects available to any child widget that needs them.
// Instead of passing data down manually through many constructors, any widget
// can call RepositoryProvider.of(context) to get the repository it needs.

// Provides the ComplaintRepository to the whole widget tree
class RepositoryProvider extends InheritedWidget {
  final ComplaintRepository repository;

  const RepositoryProvider({
    super.key,
    required this.repository,
    required super.child,
  });

  // Any widget calls this to access the complaint repository
  static ComplaintRepository of(BuildContext context) {
    final provider =
        context.dependOnInheritedWidgetOfExactType<RepositoryProvider>();
    assert(provider != null, 'No RepositoryProvider found in context');
    return provider!.repository;
  }

  // Tells Flutter to rebuild children only if the repository object changed
  @override
  bool updateShouldNotify(RepositoryProvider oldWidget) =>
      repository != oldWidget.repository;
}

// Provides the ChatRepository to the whole widget tree (same pattern as above)
class ChatRepositoryProvider extends InheritedWidget {
  final ChatRepository chatRepository;

  const ChatRepositoryProvider({
    super.key,
    required this.chatRepository,
    required super.child,
  });

  // Any widget calls this to access the chat repository
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

// ─── Push Notifications Setup ────────────────────────────────────────────────

// The local notifications plugin lets us show a notification in Android's
// status bar even when the app is open (foreground state)
final FlutterLocalNotificationsPlugin _localNotifications =
    FlutterLocalNotificationsPlugin();

// This defines the Android notification channel — all SpotIT notifications
// go through this channel. The channel name appears in Android settings.
const AndroidNotificationChannel _channel = AndroidNotificationChannel(
  'spotit_notifications', // unique channel ID used in the app code
  'SpotIT Notifications', // display name shown in Android notification settings
  description: 'Notifications for SpotIT',
  importance: Importance.high, // high importance = shows as a heads-up banner
);

// This handler runs when a push notification arrives while the app is closed
// or in the background. It must be a top-level function (not inside a class).
// The @pragma annotation tells the Dart compiler to keep this function even
// when tree-shaking (removing unused code) is applied.
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Firebase must be re-initialized because background isolates start fresh
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  debugPrint('Background message received: ${message.messageId}');
}

// Sets up the local notifications plugin and registers the Android channel
Future<void> _initLocalNotifications() async {
  // Use the app launcher icon as the notification icon
  const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
  const initSettings = InitializationSettings(android: androidSettings);
  await _localNotifications.initialize(initSettings);

  // Create the channel on the device — this is required for Android 8.0+
  final androidPlugin =
      _localNotifications.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
  await androidPlugin?.createNotificationChannel(_channel);
}

// Shows a notification in the status bar when a push message is received
// while the app is open. Without this, foreground FCM messages are silent.
void _showLocalNotification(RemoteMessage message) {
  final notification = message.notification;
  if (notification == null) return; // skip if there's no notification payload

  _localNotifications.show(
    notification.hashCode, // unique ID so each notification is separate
    notification.title,
    notification.body,
    NotificationDetails(
      android: AndroidNotificationDetails(
        _channel.id,
        _channel.name,
        channelDescription: _channel.description,
        importance: Importance.high,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
      ),
    ),
  );
}

// Main function to set up Firebase Cloud Messaging (push notifications)
Future<void> _initFCM() async {
  final messaging = FirebaseMessaging.instance;

  // Ask the user for permission to send notifications.
  // On Android 13+ this shows a system dialog. On older Android it's automatic.
  final settings = await messaging.requestPermission(
    alert: true,  // show notifications
    badge: true,  // show badge count on app icon
    sound: true,  // play a sound
    provisional: false, // false = show the full permission dialog
  );
  debugPrint('FCM permission status: ${settings.authorizationStatus}');

  // If the user denied permission, stop here — we can't send notifications
  if (settings.authorizationStatus == AuthorizationStatus.denied) {
    debugPrint('User denied notification permission');
    return;
  }

  // Register the background message handler defined above
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // Set up local notifications so foreground messages show in the status bar
  await _initLocalNotifications();

  // When the app is open and a push notification arrives, show it in the bar
  FirebaseMessaging.onMessage.listen((RemoteMessage message) {
    debugPrint('Foreground push received: ${message.notification?.title}');
    _showLocalNotification(message);
  });

  // When the user taps a notification that brought the app to the foreground
  FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
    debugPrint('User tapped notification: ${message.data}');
    // Future: navigate to the relevant page based on message.data['type']
  });

  // Try saving the FCM token now. This might fail if no user is logged in yet.
  await _saveFcmToken(messaging);

  // If the device generates a new token later, save it straight away
  messaging.onTokenRefresh.listen((newToken) async {
    await _updateFcmTokenInFirestore(newToken);
  });

  // Every time a user signs in, save their FCM token to Firestore.
  // This is the key fix — tokens must be saved AFTER login, not before.
  FirebaseAuth.instance.authStateChanges().listen((user) async {
    if (user != null) {
      await _saveFcmToken(messaging);
    }
  });
}

// Gets the device's FCM token and saves it to Firestore
Future<void> _saveFcmToken(FirebaseMessaging messaging) async {
  try {
    final token = await messaging.getToken(); // unique token for this device
    if (token != null) {
      await _updateFcmTokenInFirestore(token);
    }
  } catch (e) {
    debugPrint('Error getting FCM token: $e');
  }
}

// Writes the device's FCM token to the logged-in user's Firestore document.
// The Cloud Function reads this token when sending a push notification.
Future<void> _updateFcmTokenInFirestore(String token) async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return; // no point saving if nobody is logged in

  try {
    await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .update({'fcmToken': token}); // saved under the user's profile doc
    debugPrint('FCM token saved for user ${user.uid}');
  } catch (e) {
    debugPrint('Error saving FCM token: $e');
  }
}

// ─── App Entry Point ─────────────────────────────────────────────────────────

Future<void> main() async {
  // Must be called before any Flutter or plugin code
  WidgetsFlutterBinding.ensureInitialized();

  // Connect the app to the correct Firebase project
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Read the saved theme (dark/light) from local storage and apply it
  // before the first frame renders, so there's no flash of wrong theme
  final prefs = await SharedPreferences.getInstance();
  final savedTheme = prefs.getString('themeMode');
  if (savedTheme == 'dark') {
    SpotItApp.themeNotifier.value = ThemeMode.dark;
  }

  // Firebase App Check protects backend resources from abuse.
  // On web we use reCAPTCHA. On mobile we use Play Integrity (Android)
  // or App Attest (iOS). In debug mode, use the debug provider instead.
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

  // Enable Firestore offline caching — data loads instantly from local cache
  // even when there's no internet connection
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
    cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
  );

  // Set up push notifications and request permission from the user
  await _initFCM();

  // Start the app, wrapping it in repository providers so that any widget
  // in the tree can access these data sources without being passed them manually
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

  // A global value notifier so any widget can switch between dark and light mode
  static final themeNotifier = ValueNotifier<ThemeMode>(ThemeMode.light);

  @override
  Widget build(BuildContext context) {
    // Rebuild the MaterialApp whenever the theme changes
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (context, themeMode, _) {
        return MaterialApp(
          title: 'SpotIT LK',
          debugShowCheckedModeBanner: false, // hide the red debug banner
          themeMode: themeMode, // switches between light and dark
          themeAnimationDuration: const Duration(milliseconds: 500),
          themeAnimationCurve: Curves.easeInOut,

          // Light theme — green primary color, light background
          theme: ThemeData(
            brightness: Brightness.light,
            scaffoldBackgroundColor: const Color(0xFFEEF7EE), // light green-white
            primaryColor: const Color(0xFF2EAA5E),
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF2EAA5E),
              secondary: Color(0xFF2EAA5E),
              surface: Colors.white,
            ),
            appBarTheme: const AppBarTheme(
              backgroundColor: Color(0xFFEEF7EE),
              elevation: 0, // no shadow under the app bar
            ),
            useMaterial3: true,
          ),

          // Dark theme — darker greens, dark backgrounds
          darkTheme: ThemeData(
            brightness: Brightness.dark,
            scaffoldBackgroundColor: const Color(0xFF121212), // near-black
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

          // ThemeSwitcher wraps the app so we can animate the theme transition
          builder: (context, child) {
            return ThemeSwitcher(
              key: ThemeSwitcher.instanceKey,
              child: child ?? const SizedBox.shrink(),
            );
          },

          home: const AuthGate(), // decide which page to show based on auth state
        );
      },
    );
  }
}

// ─── Auth Gate ───────────────────────────────────────────────────────────────
// This widget is the first thing the user sees. It listens to Firebase Auth
// in real-time and decides which page to route to:
//   - Not logged in          → GetStartedPage (login / signup)
//   - Logged in, no profile  → CompleteProfilePage
//   - Citizen with profile   → HomeControllerPage
//   - Government role        → GovHomeControllerPage

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  // All the role names that count as "government/official" side
  static const Set<String> _govRoles = {
    'official',
    'government',
    'admin',
    'developer',
    'dev',
  };

  // Looks up the role field from the user's Firestore document
  Future<String?> _getUserRole(String uid) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();
      if (!doc.exists) return null;
      final raw = doc.data()?['role'];
      if (raw is String) return raw.toLowerCase();
      return null;
    } catch (_) {
      return null;
    }
  }

  // Checks if the citizen filled in their profile details
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
    // StreamBuilder keeps listening to auth state changes in real-time.
    // If the user logs out, it will instantly redirect to GetStartedPage.
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // Auth state is still loading — show a spinner
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        // A user is logged in — now figure out their role
        if (snapshot.hasData) {
          final user = snapshot.data!;

          // FutureBuilder fetches the role from Firestore once
          return FutureBuilder<String?>(
            future: _getUserRole(user.uid),
            builder: (context, roleSnapshot) {
              if (roleSnapshot.connectionState == ConnectionState.waiting) {
                return const Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                );
              }

              // If the user is a government official, go to the gov dashboard
              if (_govRoles.contains(roleSnapshot.data)) {
                return const GovHomeControllerPage();
              }

              // For citizens, also check if their profile is complete
              return FutureBuilder<bool>(
                future: _isProfileComplete(user.uid),
                builder: (context, profileSnapshot) {
                  if (profileSnapshot.connectionState == ConnectionState.waiting) {
                    return const Scaffold(
                      body: Center(child: CircularProgressIndicator()),
                    );
                  }

                  // Profile is done — go to the main citizen home page
                  if (profileSnapshot.data == true) {
                    return const HomeControllerPage();
                  }

                  // Profile is not filled in — ask them to complete it
                  return const CompleteProfilePage();
                },
              );
            },
          );
        }

        // No user is logged in — show the welcome / login page
        return const GetStartedPage();
      },
    );
  }
}
