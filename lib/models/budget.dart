import 'package:hive/hive.dart';

import 'budget_status.dart';

part 'budget.g.dart';

/// Monthly spending budget per category.
///
/// Persisted in the encrypted Hive box (offline-first) and mirrored to
/// Firestore under `users/{uid}/budgets/{key}` where key = `yyyy-MM_category`.
@HiveType(typeId: 11)
class Budget extends HiveObject {
  @HiveField(0)
  final String category;

  @HiveField(1)
  final double limit; // monthly limit amount

  /// Month key `yyyy-MM` this budget applies to.
  @HiveField(2)
  final String monthKey;

  Budget({
    required this.category,
    required this.limit,
    required this.monthKey,
  });

  /// Stable Hive/Firestore document key.
  @override
  String get key => '${monthKey}_$category';

  Budget copyWith({double? limit}) => Budget(
        category: category,
        limit: limit ?? this.limit,
        monthKey: monthKey,
      );

  // ---------- Firestore ----------

  Map<String, dynamic> toMap() => <String, dynamic>{
        'category': category,
        'limit': limit,
        'monthKey': monthKey,
        'updatedAt': DateTime.now().toIso8601String(),
      };

  factory Budget.fromMap(Map<String, dynamic> map) => Budget(
        category: (map['category'] ?? 'other') as String,
        limit: (map['limit'] as num? ?? 0).toDouble(),
        monthKey: (map['monthKey'] ?? '') as String,
      );

  // ---------- Budget engine ----------

  /// Progress in [0..1+] (can exceed 1 when overspent).
  double progressFor(double spent) =>
      limit <= 0 ? 0 : (spent / limit).clamp(0.0, double.infinity);

  /// Threshold status used by the local notification engine (80% / 100%).
  BudgetStatus statusFor(double spent) {
    if (limit <= 0) return BudgetStatus.none;
    final double ratio = spent / limit;
    if (ratio >= 1) return BudgetStatus.exceeded;
    if (ratio >= 0.8) return BudgetStatus.warning;
    return BudgetStatus.none;
  }
}
