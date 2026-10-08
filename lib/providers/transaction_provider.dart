// Central transaction repository + derived state.
//
// Offline-first contract:
//   1. EVERY write goes to the encrypted Hive box immediately.
//   2. If online & Firebase available -> mirror to Firestore.
//   3. `synced=false` items are retried by SyncService (also on app start).
//
// Free-tier enforcement: guests/free users get 70 transactions per month;
// the 71st write is blocked (UI routes to the paywall).

import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart' show DateTimeRange;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/budget.dart';
import '../models/transaction.dart';
import '../services/hive_service.dart';
import '../services/sync_service.dart';
import '../utils/constants.dart';
import '../utils/helpers.dart';
import 'plan_provider.dart';

/// Reactive list of all transactions, newest first.
final NotifierProvider<TransactionNotifier, List<Transaction>>
    transactionListProvider =
    NotifierProvider<TransactionNotifier, List<Transaction>>(
        TransactionNotifier.new);

class TransactionNotifier extends Notifier<List<Transaction>> {
  @override
  List<Transaction> build() {
    final List<Transaction> all = HiveService.loadAllTransactions();
    _sortByRecency(all);
    return all;
  }

  void _sortByRecency(List<Transaction> list) {
    list.sort((Transaction a, Transaction b) {
      final int byDate = b.date.compareTo(a.date);
      return byDate != 0 ? byDate : b.createdAtMs.compareTo(a.createdAtMs);
    });
  }

  /// Adds a transaction locally (+ Firestore mirror). Returns false when the
  /// free-tier monthly limit blocked the write (caller opens the paywall).
  Future<bool> add(Transaction tx) async {
    if (!ref.read(isProProvider)) {
      final String mk = tx.monthKey();
      final int used =
          state.where((Transaction t) => t.monthKey() == mk).length;
      if (used >= PlanLimits.freeTransactionsPerMonth) return false;
    }
    await HiveService.saveTransaction(tx);
    state = <Transaction>[tx, ...state];
    _sortByRecency(state);
    // Fire-and-forget cloud mirror (no-ops when offline / local-only).
    unawaited(ref.read(syncServiceProvider).pushTransaction(tx));
    return true;
  }

  Future<void> update(Transaction tx) async {
    await HiveService.saveTransaction(tx);
    state = List<Transaction>.of(state);
    _sortByRecency(state);
    unawaited(ref.read(syncServiceProvider).pushTransaction(tx));
  }

  Future<void> remove(String id) async {
    await HiveService.deleteTransaction(id);
    state = state.where((Transaction t) => t.id != id).toList();
    unawaited(ref.read(syncServiceProvider).deleteTransaction(id));
  }

  /// Bulk replace (used after a successful full sync).
  void replaceAll(List<Transaction> txs) {
    state = List<Transaction>.of(txs);
    _sortByRecency(state);
  }
}

/// Transactions inside [range], newest first.
final ProviderFamily<List<Transaction>, DateTimeRange> txInRangeProvider =
    Provider.family<List<Transaction>, DateTimeRange>(
        (Ref ref, DateTimeRange r) {
  final List<Transaction> all = ref.watch(transactionListProvider);
  return all
      .where((Transaction t) =>
          !t.date.isBefore(r.start) && !t.date.isAfter(r.end))
      .toList();
});

/// Current month key (`yyyy-MM`).
final Provider<String> currentMonthKeyProvider =
    Provider<String>((Ref ref) => Helpers.monthKey(DateTime.now()));

/// Month totals for the dashboard cards.
final Provider<({double income, double expense, double balance})>
    monthTotalsProvider =
    Provider<({double income, double expense, double balance})>((Ref ref) {
  final String mk = ref.watch(currentMonthKeyProvider);
  final List<Transaction> monthTx = ref
      .watch(transactionListProvider)
      .where((Transaction t) => t.monthKey() == mk)
      .toList();
  final double income = Helpers.sumBy(monthTx, TxType.income);
  final double expense = Helpers.sumBy(monthTx, TxType.expense);
  return (income: income, expense: expense, balance: income - expense);
});

/// Expense-per-day map for the current month (dashboard chart).
final Provider<Map<int, double>> dailyExpenseChartProvider =
    Provider<Map<int, double>>((Ref ref) {
  final String mk = ref.watch(currentMonthKeyProvider);
  final Map<int, double> out = <int, double>{};
  for (final Transaction t in ref.watch(transactionListProvider)) {
    if (t.monthKey() != mk || t.type != TxType.expense) continue;
    out[t.date.day] = (out[t.date.day] ?? 0) + t.amount;
  }
  return out;
});

/// Number of days in the current month (chart width).
final Provider<int> daysInCurrentMonthProvider = Provider<int>((Ref ref) {
  final DateTime now = DateTime.now();
  return DateTime(now.year, now.month + 1, 0).day;
});

/// Active budgets for the current month.
final Provider<List<Budget>> activeBudgetsProvider = Provider<List<Budget>>(
  (Ref ref) {
    ref.watch(transactionListProvider); // re-evaluate when data changes
    return HiveService.loadBudgets(Helpers.monthKey(DateTime.now()));
  },
);

/// Connectivity watcher -> triggers a sync whenever the device comes online.
final StreamProvider<List<ConnectivityResult>> connectivityProvider =
    StreamProvider<List<ConnectivityResult>>(
  (Ref ref) => Connectivity().onConnectivityChanged,
);
