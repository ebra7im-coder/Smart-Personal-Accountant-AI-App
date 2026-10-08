# ProGuard rules — keep classes touched by reflection.

# Flutter
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# google_mobile_ads
-keep class com.google.android.gms.ads.** { *; }

# ML Kit text recognition
-keep class com.google.mlkit.** { *; }
-dontwarn com.google.mlkit.**

# firebase
-keep class com.google.firebase.** { *; }
-dontwarn com.google.firebase.**

# local_auth (biometric)
-keep class androidx.biometric.** { *; }

# Flutter deferred components: Play Core classes are referenced by the
# embedding but unused (no deferred components) — safe to ignore for R8.
-dontwarn com.google.android.play.core.**

# Hive / Dart VM snapshot unaffected; keep JDBC-free generic rules minimal.
