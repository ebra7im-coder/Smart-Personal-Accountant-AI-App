// firebase_options.dart — generated-style Firebase configuration.
//
// These values come from the Firebase console (Project settings).
// They are PUBLIC client identifiers — safe to commit (API restrictions are
// enforced server-side by Firebase Security Rules + SHA certificates).
// Replace them with your own project's values before releasing.
//
// To re-generate with your project:
//   dart pub global activate flutterfire_cli
//   flutterfire configure
//
// IMPORTANT: even with placeholder values this file COMPILES and the app runs
// 100% offline-first (Hive-only mode). Firebase is initialized defensively in
// main.dart: if Firebase fails (missing config / no services file), the app
// automatically continues in local-only mode.

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Default (placeholder) configuration used for Android.
const FirebaseOptions androidOptions = FirebaseOptions(
  apiKey: 'AIzaSyREPLACE-WITH-YOUR-ANDROID-KEY000000000',
  appId: '1:000000000000:android:0000000000000000000000',
  messagingSenderId: '000000000000',
  projectId: 'smart-personal-accountant',
  storageBucket: 'smart-personal-accountant.appspot.com',
);

/// Placeholder configuration for non-Android platforms.
FirebaseOptions platformOptions() {
  if (kIsWeb) {
    return const FirebaseOptions(
      apiKey: 'AIzaSyREPLACE-WITH-YOUR-WEB-KEY0000000000000',
      appId: '1:000000000000:web:0000000000000000000000',
      messagingSenderId: '000000000000',
      projectId: 'smart-personal-accountant',
      storageBucket: 'smart-personal-accountant.appspot.com',
      authDomain: 'smart-personal-accountant.firebaseapp.com',
    );
  }
  switch (defaultTargetPlatform) {
    case TargetPlatform.android:
      return androidOptions;
    case TargetPlatform.iOS:
    case TargetPlatform.macOS:
      return const FirebaseOptions(
        apiKey: 'AIzaSyREPLACE-WITH-YOUR-IOS-KEY00000000000000',
        appId: '1:000000000000:ios:0000000000000000000000',
        messagingSenderId: '000000000000',
        projectId: 'smart-personal-accountant',
        storageBucket: 'smart-personal-accountant.appspot.com',
        iosBundleId: 'com.smartaccountant.ai',
      );
    default:
      return androidOptions;
  }
}

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform => platformOptions();
}
