// Dashboard: balance card, month bar chart (fl_chart), budgets snapshot,
// recent transactions, AI saving tip, PRO upsell + banner ads (free plan).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/transaction.dart';
import '../../providers/plan_provider.dart';
import '../../providers/transaction_provider.dart';
import '../../services/ads_service.dart';
import '../../services/ai_service.dart';
import '../../utils/constants.dart';
import '../../utils/helpers.dart';
import '../../widgets/balance_card.dart';
import '../../widgets/chart_widget.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/pro_badge.dart';
import '../../widgets/transaction_card.dart';
import '../add_transaction/add_transaction_sheet.dart';
import '../paywall/paywall_screen.dart';
import '../transactions/transactions_screen.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  String? _aiTip;
  bool _tipLoading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadAiTip());
  }

  Future<void> _loadAiTip() async {
    if (_tipLoading) return;
    _tipLoading = true;
    try {
      final (double income, double expense) = (
        ref.read(monthTotalsProvider).income,
        ref.read(monthTotalsProvider).expense,
      );
      final String tip = await AiService.instance.savingTip(
        monthIncome: income,
        monthExpense: expense,
      );
      if (mounted) setState(() => _aiTip = tip);
    } catch (_) {
      // AI disabled / offline — the tip card simply hides itself.
    } finally {
      _tipLoading = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final (double income, double expense, double balance) = (
      ref.watch(monthTotalsProvider).income,
      ref.watch(monthTotalsProvider).expense,
      ref.watch(monthTotalsProvider).balance,
    );
    final Map<int, double> daily = ref.watch(dailyExpenseChartProvider);
    final int daysInMonth = ref.watch(daysInCurrentMonthProvider);
    final List<Transaction> all = ref.watch(transactionListProvider);
    final bool isPro = ref.watch(isProProvider);

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: all.isEmpty
            ? EmptyState(
                icon: Icons.receipt_long_outlined,
                title: 'لا توجد معاملات بعد',
                subtitle: 'اضغط زر الميكروفون وقول «صرفت ٥٠ جنيه مطعم» '
                    'أو أضف معاملة يدوياً',
                actionLabel: 'إضافة معاملة',
                onAction: () => AddTransactionSheet.maybeShow(context, ref),
              )
            : RefreshIndicator(
                onRefresh: () async => _loadAiTip(),
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  children: <Widget>[
                    // ---- Balance ----
                    BalanceCard(
                      balance: balance,
                      income: income,
                      expense: expense,
                    ),
                    const SizedBox(height: 16),

                    // ---- PRO upsell (free users) ----
                    if (!isPro) ...<Widget>[
                      ProUpsellBanner(
                        onTap: () =>
                            Navigator.of(context).pushNamed(PaywallScreen.routeName),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // ---- Monthly chart ----
                    _SectionCard(
                      title: 'نظرة شهرية',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            Helpers.monthName(DateTime.now()),
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textHint,
                            ),
                          ),
                          const SizedBox(height: 8),
                          MonthlyBarChart(
                            dailyExpenses: daily,
                            daysInMonth: daysInMonth,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // ---- AI tip ----
                    if (_aiTip != null) _AiTipCard(tip: _aiTip!),

                    // ---- Recent transactions ----
                    _SectionCard(
                      title: 'أحدث المعاملات',
                      action: TextButton(
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                              builder: (_) => const TransactionsScreen()),
                        ),
                        child: const Text('عرض الكل',
                            style: TextStyle(fontSize: 12)),
                      ),
                      child: Column(
                        children: all
                            .take(6)
                            .map((Transaction t) => TransactionCard(
                                  transaction: t,
                                  onTap: () =>
                                      AddTransactionSheet.showWithPrefill(
                                    context,
                                    _prefillFrom(t),
                                    existing: t,
                                  ),
                                  onDelete: () => ref
                                      .read(transactionListProvider.notifier)
                                      .remove(t.id),
                                ))
                            .toList(),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // ---- Free plan banner ad ----
                    if (!isPro) ...<Widget>[
                      const Center(child: ProBadge()),
                      const SizedBox(height: 8),
                      AdsService.bannerAdWidget(),
                    ],
                  ],
                ),
              ),
      ),
    );
  }

  /// Converts an existing transaction into an AI-prefill for the edit sheet.
  static AiParsedTransaction _prefillFrom(Transaction t) => AiParsedTransaction(
        type: t.type == TxType.income ? 'income' : 'expense',
        amount: t.amount,
        category: t.category,
        date: t.date,
        note: t.note,
      );
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.child, this.action});

  final String title;
  final Widget child;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppSizes.radiusL),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                  color: AppColors.navy,
                ),
              ),
              const Spacer(),
              if (action != null) action!,
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _AiTipCard extends StatelessWidget {
  const _AiTipCard({required this.tip});

  final String tip;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: <Color>[Color(0xFFE0F9F1), Color(0xFFF0FDF9)],
        ),
        borderRadius: BorderRadius.circular(AppSizes.radiusL),
        border: Border.all(color: AppColors.green.withOpacity(0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const CircleAvatar(
            radius: 16,
            backgroundColor: AppColors.green,
            child: Icon(Icons.auto_awesome, size: 16, color: AppColors.white),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Text(
                  'نصيحة محاسبك الآلي',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                    color: Color(0xFF00805F),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  tip,
                  style: const TextStyle(
                    fontSize: 13,
                    height: 1.6,
                    color: AppColors.textDark,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
