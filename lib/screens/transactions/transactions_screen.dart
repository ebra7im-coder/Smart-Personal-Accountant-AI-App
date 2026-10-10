// All-transactions list with search + type filter (opened from dashboard).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fluttertoast/fluttertoast.dart';

import '../../models/transaction.dart';
import '../../providers/transaction_provider.dart';
import '../../utils/constants.dart';
import '../../utils/helpers.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/transaction_card.dart';
import '../add_transaction/add_transaction_sheet.dart';

class TransactionsScreen extends ConsumerStatefulWidget {
  const TransactionsScreen({super.key});

  @override
  ConsumerState<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends ConsumerState<TransactionsScreen> {
  String _query = '';
  String _filter = 'all'; // all | income | expense

  @override
  Widget build(BuildContext context) {
    final List<Transaction> all = ref.watch(transactionListProvider);
    List<Transaction> filtered = all;
    if (_filter == 'income') {
      filtered =
          filtered.where((Transaction t) => t.type == TxType.income).toList();
    } else if (_filter == 'expense') {
      filtered =
          filtered.where((Transaction t) => t.type == TxType.expense).toList();
    }
    if (_query.isNotEmpty) {
      filtered = filtered
          .where((Transaction t) =>
              t.note.contains(_query) ||
              t.category.arLabel.contains(_query) ||
              t.amount.toString().contains(_query))
          .toList();
    }

    // Group by day for sticky-ish headers.
    final Map<String, List<Transaction>> grouped =
        <String, List<Transaction>>{};
    for (final Transaction t in filtered) {
      grouped.putIfAbsent(Helpers.dayKey(t.date), () => <Transaction>[]).add(t);
    }

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: const Text('كل المعاملات'),
        backgroundColor: AppColors.bg,
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.green,
        onPressed: () => AddTransactionSheet.maybeShow(context, ref),
        child: const Icon(Icons.add, color: AppColors.white),
      ),
      body: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: TextField(
                    onChanged: (String v) => setState(() => _query = v.trim()),
                    decoration: const InputDecoration(
                      hintText: 'ابحث في المعاملات...',
                      prefixIcon: Icon(Icons.search, size: 20),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SegmentedButton<String>(
                  segments: const <ButtonSegment<String>>[
                    ButtonSegment<String>(value: 'all', label: Text('الكل')),
                    ButtonSegment<String>(value: 'income', label: Text('دخل')),
                    ButtonSegment<String>(value: 'expense', label: Text('صرف')),
                  ],
                  selected: <String>{_filter},
                  showSelectedIcon: false,
                  onSelectionChanged: (Set<String> s) =>
                      setState(() => _filter = s.first),
                  style: const ButtonStyle(
                    visualDensity: VisualDensity.compact,
                    textStyle: WidgetStatePropertyAll<TextStyle>(
                      TextStyle(fontSize: 11),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: filtered.isEmpty
                ? const EmptyState(
                    icon: Icons.search_off_rounded,
                    title: 'مفيش نتائج',
                    subtitle: 'جرّب كلمة بحث تانية أو غيّر الفلتر',
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 90),
                    itemCount: grouped.length,
                    itemBuilder: (BuildContext ctx, int i) {
                      final String day = grouped.keys.elementAt(i);
                      final List<Transaction> txs = grouped[day]!;
                      final DateTime d = txs.first.date;
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Row(
                              children: <Widget>[
                                Text(
                                  Helpers.smartDate(d),
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textHint,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                const Expanded(child: Divider()),
                                Text(
                                  Helpers.money(
                                      Helpers.sumBy(txs, TxType.expense)),
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: AppColors.textHint,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          ...txs.map((Transaction t) => TransactionCard(
                                transaction: t,
                                showDate: false,
                                onTap: () =>
                                    AddTransactionSheet.showWithPrefill(
                                  context,
                                  null,
                                  existing: t,
                                ),
                                onDelete: () async {
                                  await ref
                                      .read(transactionListProvider.notifier)
                                      .remove(t.id);
                                  Fluttertoast.showToast(msg: 'تم الحذف');
                                },
                              )),
                        ],
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
