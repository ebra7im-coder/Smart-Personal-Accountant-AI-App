// Offline-first sync engine.
//
//  - pushTransaction   : mirror a single local write to Firestore.
//  - syncAll           : push all unsynced rows; pull remote when local empty.
//  - notifyBudgetThreshold : fires the 80%/100% local notification (once).

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/budget.dart';
import '../models/transaction.dart';
import '../utils/helpers.dart';
import 'firebase_service.dart';
import 'hive_service.dart';
import 'notification_service.dart';

class SyncService {
  SyncService();

  /// Pushes one transaction to Firestore (no-op when offline / not signed in).
  Future<void> pushTransaction(Transaction tx) async {
    try {
      final String? uid = FirebaseAuthService.currentUid;
      if (uid == null || !FirebaseService.isReady) return;
      await FirebaseFirestoreService.upsertTransaction(uid, tx);
      await HiveService.markSynced(tx.id);
    } catch (_) {
      // Stays unsynced in Hive; retried by syncAll().
    }
  }

  Future<void> deleteTransaction(String id) async {
    try {
      final String? uid = FirebaseAuthService.currentUid;
      if (uid == null || !FirebaseService.isReady) return;
      await FirebaseFirestoreService.deleteTransaction(uid, id);
    } catch (_) {}
  }

  /// Full sync pass. Returns true when something changed.
  Future<bool> syncAll({
    void Function(List<Transaction>)? onLocalReplaced,
  }) async {
    try {
      final String? uid = FirebaseAuthService.currentUid;
      if (uid == null || !FirebaseService.isReady) return false;

      // 1) Push every unsynced local transaction.
      final List<String> pending = HiveService.unsyncedIds();
      for (final String id in pending) {
        final Transaction? tx = HiveService.getTransaction(id);
        if (tx != null) await pushTransaction(tx);
      }

      // 2) Pull remote data when local store is empty (fresh install).
      if (HiveService.loadAllTransactions().isEmpty) {
        final List<Transaction> remote =
            await FirebaseFirestoreService.fetchAllTransactions(uid);
        for (final Transaction tx in remote) {
          tx.synced = true;
          await HiveService.saveTransaction(tx);
        }
        onLocalReplaced?.call(remote);
      }

      await HiveService.setLastSyncAt(DateTime.now());
      return pending.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  /// Mirrors one budget to the cloud (best-effort).
  Future<void> pushBudget(Budget budget) async {
    try {
      final String? uid = FirebaseAuthService.currentUid;
      if (uid == null || !FirebaseService.isReady) return;
      await FirebaseFirestoreService.saveBudget(uid, budget);
    } catch (_) {}
  }

  // ------------------------------------------------------------------
  // Budget threshold notifications (80% & 100%).
  // The threshold is latched in Hive so each alert fires at most ONCE
  // per category per month — even across restarts.
  // ------------------------------------------------------------------

  static const String _latchPrefix = 'budget_alert_sent';

  static Future<void> notifyBudgetThreshold({
    required String category,
    required int percent,
  }) async {
    final String monthKey = Helpers.monthKey(DateTime.now());
    final String latchKey = '$_latchPrefix:${monthKey}_$category:$percent';
    try {
      final dynamic already = HiveService.get<dynamic>(
          HiveService.dataBox, latchKey);
      if (already == true) return;
    } catch (_) {
      return;
    }

    final String label = category.arLabel;
    await NotificationService.show(
      id: NotificationService.budgetAlertId(category, percent),
      title: percent >= 100
          ? '🚨 تجاوزت ميزانية $label!'
          : '⚠️ اقتربت من ميزانية $label',
      body: percent >= 100
          ? 'صرفت الميزانية المحددة بالكامل هذا الشهر. راجع مصروفات $label.'
          : 'استهلكت $percent٪ من ميزانية $label هذا الشهر — خلي بالك!',
    );

    try {
      await HiveService.put(HiveService.dataBox, latchKey, true);
    } catch (_) {}
  }
}

/// Riverpod provider for [SyncService].
final Provider<SyncService> syncServiceProvider =
    Provider<SyncService>((Ref ref) => SyncService());
