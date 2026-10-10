// Main entry point of the Smart Personal Accountant AI App.
//
// Bootstrap order:
//   1. Splash frame while services initialize (Hive, Firebase, Ads).
//   2. Encrypted Hive boxes (offline-first local DB).
//   3. Firebase (defensive: missing config never crashes the app).
//   4. Google Mobile Ads.
//   5. Biometric gate -> SplashScreen -> Root (Auth or Home).

import 'package:firebase_auth/firebase_auth.dart' as fa_auth;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'models/budget.dart';
import 'models/chat_message.dart';
import 'models/transaction.dart';
import 'models/user.dart';
import 'providers/prefs_provider.dart';
import 'services/firebase_service.dart';
import 'services/hive_service.dart';
import 'utils/constants.dart';

Future<void> main() async {
  // Ensure bindings before any plugin work; keep splash until ready.
  final WidgetsBinding binding = WidgetsFlutterBinding.ensureInitialized();
  binding.deferFirstFrame();

  // Portrait-only, edge-to-edge, Android-style overlays (RTL app).
  await SystemChrome.setPreferredOrientations(<DeviceOrientation>[
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: AppColors.navy,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  // ---- Local storage: Hive (unencrypted settings + encrypted data boxes) ----
  await Hive.initFlutter();
  Hive.registerAdapter(TransactionAdapter());
  Hive.registerAdapter(TxTypeAdapter());
  Hive.registerAdapter(UserAdapter());
  Hive.registerAdapter(BudgetAdapter());
  Hive.registerAdapter(ChatMessageAdapter());

  final SharedPreferences prefs = await SharedPreferences.getInstance();

  try {
    // Settings box is plaintext (no sensitive data).
    await Hive.openBox<dynamic>(HiveService.settingsBox);
    // All financial data lives in an AES-256 encrypted box. The key is
    // generated once and stored in Android Keystore-backed secure storage.
    await HiveService.openEncryptedBox<dynamic>(HiveService.dataBox);
    debugPrint('✅ Hive boxes opened (data box encrypted).');
  } catch (e) {
    debugPrint('⚠️ Hive init issue: $e — continuing with defaults.');
  }

  // ---- Firebase: defensive init; absence never blocks offline use ----
  Object? firebaseError;
  try {
    await FirebaseService.ensureInitialized();
  } catch (e) {
    firebaseError = e;
    debugPrint('⚠️ Firebase unavailable (${e.runtimeType}) '
        '— running in local-only mode. '
        'Add google-services.json + real firebase_options to enable sync.');
  }

  // ---- Google Mobile Ads (safe no-op when not configured) ----
  try {
    await MobileAds.instance.initialize();
    debugPrint('✅ Google Mobile Ads ready.');
  } catch (e) {
    debugPrint('⚠️ MobileAds not ready: $e '
        '(add the AdMob App ID to the manifest for real ads).');
  }

  // ---- Decide the first route ----
  String initialRoute = AppRoutes.splash;
  if (firebaseError == null) {
    try {
      await fa_auth.FirebaseAuth.instance.authStateChanges().first;
      if (fa_auth.FirebaseAuth.instance.currentUser != null) {
        initialRoute = AppRoutes.home;
      }
    } catch (_) {/* local-only mode */}
  }
  final bool biometricEnabled =
      prefs.getBool(PrefKeys.biometricEnabled) ?? false;

  binding.allowFirstFrame();

  runApp(
    ProviderScope(
      overrides: <Override>[
        sharedPrefsProvider.overrideWithValue(prefs),
      ],
      child: SmartAccountantApp(
        initialRoute: initialRoute,
        biometricEnabled: biometricEnabled,
      ),
    ),
  );
}
