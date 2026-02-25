import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Default [FirebaseOptions] for the current platform.
///
/// Values extracted from google-services.json (project: spotit-lk).
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for iOS - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyB4MOqgwYBFikqSkWjzAnU8WQ8yF4TyBbU',
    appId: '1:632998768428:web:0cd09c5d3373f157398689',
    messagingSenderId: '632998768428',
    projectId: 'spotit-lk',
    authDomain: 'spotit-lk.firebaseapp.com',
    databaseURL:
        'https://spotit-lk-default-rtdb.asia-southeast1.firebasedatabase.app',
    storageBucket: 'spotit-lk.firebasestorage.app',
    measurementId: 'G-9N3TWBE7QY',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyAfQLJypsV4YO69W9DSCwpzTVKB6SCaitI',
    appId: '1:632998768428:android:c6caf76989a18501398689',
    messagingSenderId: '632998768428',
    projectId: 'spotit-lk',
    databaseURL:
        'https://spotit-lk-default-rtdb.asia-southeast1.firebasedatabase.app',
    storageBucket: 'spotit-lk.firebasestorage.app',
  );
}
