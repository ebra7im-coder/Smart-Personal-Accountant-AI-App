import 'package:hive/hive.dart';

part 'transaction.g.dart';

/// Direction of a transaction.
@HiveType(typeId: 1)
enum TxType {
  @HiveField(0)
  income,

  @HiveField(1)
  expense,
}

/// A single money movement (income or expense).
///
/// Offline-first: written to the encrypted Hive box first, then synced to
/// Firestore `users/{uid}/transactions/{id}` when connectivity is available.
@HiveType(typeId: 0)
class Transaction extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final TxType type;

  /// Category key, e.g. `food`, `transport`, `bills` (see [CategoryX]).
  @HiveField(2)
  final String category;

  @HiveField(3)
  final double amount;

  /// Stored in UTC; displayed in local time.
  @HiveField(4)
  final DateTime date;

  @HiveField(5)
  final String note;

  /// Epoch milliseconds of creation – stable client-side ordering key.
  @HiveField(6)
  final int createdAtMs;

  /// `manual` | `voice` | `ocr` | `chat`.
  @HiveField(7)
  final String source;

  @HiveField(8)
  bool synced;

  Transaction({
    required this.id,
    required this.type,
    required this.category,
    required this.amount,
    required this.date,
    this.note = '',
    required this.createdAtMs,
    this.source = 'manual',
    this.synced = false,
  });

  int get amountMinor => (amount * 100).round();

  /// `yyyy-MM` key used by budgets, reports and monthly aggregations.
  String monthKey() =>
      '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}';

  /// `yyyy-MM-dd` key used by daily reports and streaks.
  String dayKey() =>
      '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  Transaction copyWith({
    TxType? type,
    String? category,
    double? amount,
    DateTime? date,
    String? note,
  }) =>
      Transaction(
        id: id,
        type: type ?? this.type,
        category: category ?? this.category,
        amount: amount ?? this.amount,
        date: date ?? this.date,
        note: note ?? this.note,
        createdAtMs: createdAtMs,
        source: source,
        synced: synced,
      );

  // ---------- Firestore ----------

  Map<String, dynamic> toMap() => <String, dynamic>{
        'type': type == TxType.income ? 'income' : 'expense',
        'category': category,
        'amount': amount,
        'date': date.toIso8601String(),
        'note': note,
        'createdAtMs': createdAtMs,
        'source': source,
      };

  factory Transaction.fromMap(String id, Map<String, dynamic> map) =>
      Transaction(
        id: id,
        type: (map['type'] ?? 'expense') == 'income'
            ? TxType.income
            : TxType.expense,
        category: (map['category'] ?? 'other') as String,
        amount: (map['amount'] as num? ?? 0).toDouble(),
        date: DateTime.tryParse((map['date'] ?? '') as String) ??
            DateTime.fromMillisecondsSinceEpoch(0),
        note: (map['note'] ?? '') as String,
        createdAtMs: (map['createdAtMs'] as num? ??
                DateTime.now().millisecondsSinceEpoch)
            .toInt(),
        source: (map['source'] ?? 'manual') as String,
        synced: true,
      );
}
