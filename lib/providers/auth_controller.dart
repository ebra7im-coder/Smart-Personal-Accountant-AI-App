// Auth state: exposes Firebase user or a local guest profile.

import 'package:firebase_auth/firebase_auth.dart' as fa;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/user.dart';
import '../services/hive_service.dart';

/// Streams auth changes; emits null in local-only mode (no Firebase).
final StreamProvider<fa.User?> authStateProvider =
    StreamProvider<fa.User?>((Ref ref) {
  try {
    return fa.FirebaseAuth.instance.authStateChanges();
  } catch (_) {
    return const Stream<fa.User?>.empty();
  }
});

/// Current in-app profile (mirrors Hive `user` box, updated on login/logout).
final NotifierProvider<AppUserNotifier, User?> currentUserProvider =
    NotifierProvider<AppUserNotifier, User?>(AppUserNotifier.new);

class AppUserNotifier extends Notifier<User?> {
  @override
  User? build() {
    try {
      final dynamic cached = HiveService.get<dynamic>(
        HiveService.settingsBox,
        'cached_user',
      );
      if (cached is User) return cached;
    } catch (_) {}
    return null;
  }

  void set(User? user) {
    state = user;
    try {
      if (user == null) {
        HiveService.delete(HiveService.settingsBox, 'cached_user');
      } else {
        HiveService.put(HiveService.settingsBox, 'cached_user', user);
      }
    } catch (_) {}
  }
}
