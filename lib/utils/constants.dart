// App-wide constants: brand palette, sizes, routes of storage & prefs.

import 'package:flutter/material.dart';

/// Brand colors (see DESIGN SYSTEM spec).
abstract final class AppColors {
  static const Color navy = Color(0xFF0F2A54); // Royal Blue
  static const Color green = Color(0xFF00C896); // Money Green
  static const Color white = Color(0xFFFFFFFF);
  static const Color bg = Color(0xFFF5F7FB); // Light Grey background
  static const Color line = Color(0xFFE4E9F2);
  static const Color textDark = Color(0xFF152444);
  static const Color textGrey = Color(0xFF6B7A99);
  static const Color textHint = Color(0xFF9AA7BF);
  static const Color danger = Color(0xFFE5484D);
  static const Color error = Color(0xFFE5484D);
  static const Color warning = Color(0xFFF5A524);
  static const Color info = Color(0xFF3E7BFA);
  static const Color greenSoft = Color(0xFFE0F9F1);
  static const Color redSoft = Color(0xFFFDECEC);
}

/// Reusable metrics.
abstract final class AppSizes {
  static const double radiusS = 10;
  static const double radiusM = 14;
  static const double radiusL = 20;
  static const double buttonH = 52;
  static const double fieldH = 52;
  static const double padding = 16;
}

/// SharedPreferences keys.
abstract final class PrefKeys {
  static const String onboardingSeen = 'onboarding_seen';
  static const String biometricEnabled = 'biometric_enabled';
  static const String currency = 'currency';
  static const String keepListening = 'keep_listening';
}

/// Hive box names (see HiveService).
abstract final class HiveBoxes {
  static const String settings = 'settings';
  static const String data = 'data';
}

/// Free-tier limits & pricing.
abstract final class PlanLimits {
  static const int freeTransactionsPerMonth = 70;
  static const double monthlyPriceSar = 15;
  static const double yearlyPriceSar = 120;
}

/// Ad unit IDs — replace with your own AdMob IDs for production.
/// Google's official TEST IDs are used by default so the app never
/// violates AdMob policy during development.
abstract final class AdIds {
  static const String banner = 'ca-app-pub-3940256099942544/6300978111';
  static const String interstitial = 'ca-app-pub-3940256099942544/1033173712';
}

/// In-app purchase product IDs (configure identically in Play Console).
abstract final class IapIds {
  static const String monthly = 'pro_monthly';
  static const String yearly = 'pro_yearly';
  static const Set<String> all = <String>{monthly, yearly};
}
