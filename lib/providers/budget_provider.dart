// Budget repository: encrypted Hive store + Firestore mirror.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/budget.dart';
import '../models/budget_status.dart';
import '../models/transaction.dart';
import '../services/firebase_service.dart';
import '../services/hive_service.dart';
import '../services/sync_service.dart';
import '../utils/helpers.dart';
import 'transaction_provider.dart';

/// All budgets saved for the current month, with derived progress.
final Provider<List<Budget>> budgetsProvider = Provider<List<Budget>>(
  (Ref ref) {
    ref.watch(transactionListProvider);
    final String mk = Helpers.monthKey(DateTime.now());
    return HiveService.loadBudgets(mk);
  },
);

class BudgetActions {
  BudgetActions(this._ref);

  final Ref _ref;

  /// Saves (insert or update) a monthly budget for a category.
  Future<void> save(Budget budget) async {
    await HiveService.saveBudget(budget);
    try {
      final String? uid = FirebaseAuthService.currentUid;
      if (uid != null) {
        await FirebaseFirestoreService.saveBudget(uid, budget);
      }
    } catch (_) {/* offline: stays queued in Hive */}
    // Refresh derived providers.
    _ref.invalidate(budgetsProvider);
    _ref.invalidate(activeBudgetsProvider);
  }

  Future<void> remove(String category, String monthKey) async {
    await HiveService.deleteBudget('${monthKey}_$category');
    try {
      final String? uid = FirebaseAuthService.currentUid;
      if (uid != null) {
        await FirebaseFirestoreService.deleteBudget(
            uid, '${monthKey}_$category');
      }
    } catch (_) {}
    _ref.invalidate(budgetsProvider);
    _ref.invalidate(activeBudgetsProvider);
  }

  /// Spent amount this month for a category (expenses only).
  double spentFor(String category) {
    final String mk = Helpers.monthKey(DateTime.now());
    return _ref
        .read(transactionListProvider)
        .where((Transaction t) =>
            t.type == TxType.expense &&
            t.category == category &&
            t.monthKey() == mk)
        .fold(0.0, (double s, Transaction t) => s + t.amount);
  }

  /// Runs the 80%/100% threshold engine after every transaction change.
  /// Fires at most one local notification per category & threshold per month.
  Future<void> checkThresholds() async {
    final List<Budget> budgets = _ref.read(budgetsProvider);
    for (final Budget b in budgets) {
      final double spent = spentFor(b.category);
      final BudgetStatus status = b.statusFor(spent);
      if (status == BudgetStatus.none) continue;
      await SyncService.notifyBudgetThreshold(
        category: b.category,
        percent: status == BudgetStatus.exceeded ? 100 : 80,
      );
    }
  }
}

final Provider<BudgetActions> budgetActionsProvider =
    Provider<BudgetActions>(BudgetActions.new);
