// Freemium plan state: PRO flag + usage counters + restore hooks.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/hive_service.dart';

/// Current PRO status (cached in Hive; BillingService updates it live).
final NotifierProvider<ProStatusNotifier, bool> isProProvider =
    NotifierProvider<ProStatusNotifier, bool>(ProStatusNotifier.new);

class ProStatusNotifier extends Notifier<bool> {
  @override
  bool build() => HiveService.isProCached();

  void set(bool value) {
    state = value;
    HiveService.setProCached(value);
  }

  /// Marks PRO until a concrete date (used by BillingService grants).
  Future<void> setUntil(DateTime until) async {
    await HiveService.setProUntil(until);
    state = true;
  }
}
