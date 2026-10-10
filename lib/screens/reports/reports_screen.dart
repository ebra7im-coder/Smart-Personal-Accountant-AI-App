// Reports screen: Daily / Weekly / Monthly / Yearly tabs with summary cards,
// category donut (fl_chart) and PDF / Excel export (PDF&Excel export is PRO,
// free plan sees the paywall; interstitial ad shown to free users).

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fluttertoast/fluttertoast.dart';

import '../../models/transaction.dart';
import '../../providers/plan_provider.dart';
import '../../providers/transaction_provider.dart';
import '../../services/ads_service.dart';
import '../../services/export_service.dart';
import '../../utils/constants.dart';
import '../../utils/helpers.dart';
import '../../widgets/chart_widget.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/pro_badge.dart';
import '../paywall/paywall_screen.dart';

class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(
    length: 4,
    vsync: this,
  )..addListener(() => setState(() {}));

  bool _exporting = false;

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  ReportPeriod get _period => ReportPeriod.values[_tabs.index];

  DateTimeRange _rangeFor(ReportPeriod p) => Helpers.rangeFor(p);

  List<Transaction> _txInRange(DateTimeRange range, List<Transaction> all) =>
      all
          .where((Transaction t) =>
              !t.date.isBefore(range.start) && !t.date.isAfter(range.end))
          .toList();

  Future<void> _export({required bool asPdf}) async {
    if (!ref.read(isProProvider)) {
      Fluttertoast.showToast(msg: 'التصدير متاح في PRO 👑');
      Navigator.of(context).pushNamed(PaywallScreen.routeName);
      return;
    }
    setState(() => _exporting = true);
    try {
      final DateTimeRange range = _rangeFor(_period);
      final List<Transaction> txs = _txInRange(
        range,
        ref.read(transactionListProvider),
      );
      if (txs.isEmpty) {
        Fluttertoast.showToast(msg: 'لا توجد معاملات في الفترة المحددة');
        return;
      }
      final double income = Helpers.sumBy(txs, TxType.income);
      final double expense = Helpers.sumBy(txs, TxType.expense);
      final String stamp = DateTime.now().millisecondsSinceEpoch.toString();

      if (asPdf) {
        final Uint8List bytes = await ExportService.generatePdf(
          transactions: txs,
          title: 'تقرير ${_period.arLabel}',
          totalIncome: income,
          totalExpense: expense,
        );
        await ExportService.shareFile(bytes, 'report_$stamp.pdf');
      } else {
        final Uint8List bytes = await ExportService.generateExcel(txs);
        await ExportService.shareFile(bytes, 'report_$stamp.xlsx');
      }
      // Free-plan pacing ad (PRO users skip this path entirely).
      await AdsService.maybeShowInterstitial(every: 2);
    } catch (_) {
      Fluttertoast.showToast(msg: 'تعذر إنشاء الملف، حاول مرة أخرى');
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final DateTimeRange range = _rangeFor(_period);
    final List<Transaction> txs = _txInRange(
      range,
      ref.watch(transactionListProvider),
    );
    final double income = Helpers.sumBy(txs, TxType.income);
    final double expense = Helpers.sumBy(txs, TxType.expense);
    final Map<String, double> byCategory = Helpers.expensesByCategory(txs);
    final bool isPro = ref.watch(isProProvider);

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: const Text('التقارير'),
        backgroundColor: AppColors.bg,
      ),
      body: Column(
        children: <Widget>[
          // ---- Period tabs ----
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(AppSizes.radiusM),
              border: Border.all(color: AppColors.line),
            ),
            child: TabBar(
              controller: _tabs,
              indicatorSize: TabBarIndicatorSize.tab,
              indicator: BoxDecoration(
                color: AppColors.navy,
                borderRadius: BorderRadius.circular(AppSizes.radiusS),
              ),
              labelColor: AppColors.white,
              unselectedLabelColor: AppColors.textGrey,
              dividerColor: Colors.transparent,
              labelStyle:
                  const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
              tabs: const <Widget>[
                Tab(text: 'يومي', height: 38),
                Tab(text: 'أسبوعي', height: 38),
                Tab(text: 'شهري', height: 38),
                Tab(text: 'سنوي', height: 38),
              ],
            ),
          ),
          const SizedBox(height: 16),

          Expanded(
            child: txs.isEmpty
                ? const EmptyState(
                    icon: Icons.insert_chart_outlined_rounded,
                    title: 'لا توجد بيانات في هذه الفترة',
                    subtitle: 'سجّل معاملات جديدة وشوف التقارير تتولد تلقائياً',
                  )
                : ListView(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                    children: <Widget>[
                      // ---- Period label + totals ----
                      Text(
                        '${Helpers.smartDate(range.start)} — ${Helpers.smartDate(range.end)}',
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.textHint),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: <Widget>[
                          _TotalCard(
                            label: 'الدخل',
                            value: income,
                            color: AppColors.green,
                          ),
                          const SizedBox(width: 10),
                          _TotalCard(
                            label: 'المصروف',
                            value: expense,
                            color: AppColors.danger,
                          ),
                          const SizedBox(width: 10),
                          _TotalCard(
                            label: 'الصافي',
                            value: income - expense,
                            color: AppColors.navy,
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // ---- Donut ----
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.white,
                          borderRadius: BorderRadius.circular(AppSizes.radiusL),
                          border: Border.all(color: AppColors.line),
                        ),
                        child: Column(
                          children: <Widget>[
                            const Align(
                              alignment: AlignmentDirectional.centerStart,
                              child: Text(
                                'المصروف حسب التصنيف',
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 14,
                                  color: AppColors.navy,
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            CategoryDonutChart(expensesByCategory: byCategory),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // ---- Export buttons ----
                      if (!isPro)
                        const Padding(
                          padding: EdgeInsets.only(bottom: 10),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: <Widget>[
                              Text('التصدير متاح لمشتركي ',
                                  style: TextStyle(
                                      fontSize: 12, color: AppColors.textGrey)),
                              ProBadge(small: true),
                            ],
                          ),
                        ),
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: SizedBox(
                              height: 50,
                              child: ElevatedButton.icon(
                                onPressed: _exporting
                                    ? null
                                    : () => _export(asPdf: true),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.navy,
                                  disabledBackgroundColor:
                                      AppColors.navy.withOpacity(0.5),
                                ),
                                icon: const Icon(Icons.picture_as_pdf_rounded,
                                    size: 20),
                                label: const Text('PDF'),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: SizedBox(
                              height: 50,
                              child: ElevatedButton.icon(
                                onPressed: _exporting
                                    ? null
                                    : () => _export(asPdf: false),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF1E7145),
                                  disabledBackgroundColor:
                                      const Color(0xFF1E7145).withOpacity(0.5),
                                ),
                                icon:
                                    const Icon(Icons.grid_on_rounded, size: 20),
                                label: const Text('Excel'),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _TotalCard extends StatelessWidget {
  const _TotalCard({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final double value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(AppSizes.radiusM),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(
          children: <Widget>[
            Text(label, style: TextStyle(fontSize: 11, color: color)),
            const SizedBox(height: 4),
            FittedBox(
              child: Text(
                Helpers.compact(value),
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  fontFamily: 'Tajawal',
                  color: color,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
